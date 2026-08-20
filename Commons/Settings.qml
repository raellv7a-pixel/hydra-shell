pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/QtObj2JS.js" as QtObj2JS
import qs.Commons
import qs.Commons.Migrations
import qs.Modules.OSD
import qs.Services.Hydra
import qs.Services.UI

Singleton {
  id: root

  property bool isLoaded: false
  property bool reloadSettings: false
  property bool directoriesCreated: false
  property bool shouldOpenSetupWizard: false
  property bool isFreshInstall: false

  /*
  Shell directories.
  - Default config directory: ~/.config/hydra
  - Default cache directory: ~/.cache/hydra
  */
  readonly property alias data: adapter  // Used to access via Settings.data.xxx.yyy
  readonly property int settingsVersion: 60
  property bool isDebug: Quickshell.env("HYDRA_DEBUG") === "1"
  readonly property string shellName: "hydra"
  readonly property string configDir: ensureTrailingSlash(Quickshell.env("HYDRA_CONFIG_DIR") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/" + shellName + "/")
  readonly property string cacheDir: ensureTrailingSlash(Quickshell.env("HYDRA_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/")

  readonly property string settingsFile: Quickshell.env("HYDRA_SETTINGS_FILE") || (configDir + "settings.json")
  readonly property string defaultAvatar: Quickshell.env("HOME") + "/.face"
  readonly property string defaultVideosDirectory: Quickshell.env("HOME") + "/Videos"
  readonly property string defaultWallpapersDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"

  signal settingsLoaded
  signal settingsSaved
  signal settingsReloaded

  // Debounce external reload requests (file watcher + directory watcher)
  // so atomic replacements only trigger one reload.
  Timer {
    id: externalReloadTimer
    running: false
    interval: 200
    onTriggered: {
      if (settingsFileView.path !== undefined) {
        Logger.d("Settings", "Reloading settings after external change detection");
        reloadSettings = true;
        settingsFileView.reload();
      }
    }
  }

  function scheduleExternalReload() {
    if (!directoriesCreated || settingsFileView.path === undefined) {
      return;
    }
    externalReloadTimer.restart();
  }

  // -----------------------------------------------------
  // -----------------------------------------------------
  // Ensure directories exist before FileView tries to read files
  Component.onCompleted: {
    // ensure settings dir exists
    Quickshell.execDetached(["mkdir", "-p", configDir]);
    Quickshell.execDetached(["mkdir", "-p", cacheDir]);

    // Mark directories as created and trigger file loading
    directoriesCreated = true;

    // This should only be activated once when the settings structure has changed
    // Then it should be commented out again, regular users don't need to generate
    // default settings on every start
    if (isDebug) {
      generateDefaultSettings();
      generateWidgetDefaultSettings();
    }

    // Patch-in the local default, resolved to user's home
    adapter.general.avatarImage = defaultAvatar;
    adapter.wallpaper.directory = defaultWallpapersDirectory;
    adapter.ui.fontDefault = Qt.application.font.family;
    adapter.ui.fontFixed = "monospace";

    // Set the adapter to the settingsFileView to trigger the real settings load
    settingsFileView.adapter = adapter;
  }

  // Don't write settings to disk immediately
  // This avoid excessive IO when a variable changes rapidly (ex: sliders)
  Timer {
    id: saveTimer
    running: false
    interval: 500
    onTriggered: {
      root.saveImmediate();
    }
  }

  FileView {
    id: settingsFileView
    path: directoriesCreated ? settingsFile : undefined
    printErrors: false
    watchChanges: true
    onAdapterUpdated: saveTimer.start()

    onFileChanged: scheduleExternalReload()

    // Trigger initial load when path changes from empty to actual path
    onPathChanged: {
      if (path !== undefined) {
        reload();
      }
    }
    onLoaded: function () {
      if (!isLoaded) {
        Logger.i("Settings", "Settings loaded");

        // Load raw JSON for migrations (adapter doesn't expose removed properties)
        var rawJson = null;
        try {
          rawJson = JSON.parse(settingsFileView.text());
        } catch (e) {
          Logger.w("Settings", "Could not parse raw JSON for migrations");
        }

        // Run versioned migrations immediately, don't move it in upgradeSettings
        runVersionedMigrations(rawJson);

        // Finally, update our local settings version
        adapter.settingsVersion = settingsVersion;

        // Emit the signal
        root.isLoaded = true;
        root.settingsLoaded();

        upgradeSettings();
      } else {
        Logger.d("Settings", "Settings reloaded from external file change");
        root.settingsReloaded();
      }
    }
    onLoadFailed: function (error) {
      if (reloadSettings) {
        reloadSettings = false;
        return;
      }
      if (error.toString().includes("No such file") || error === 2) {
        // File doesn't exist, create it with default values
        root.isFreshInstall = true;
        writeAdapter();

        // We started without settings, we should open the setupWizard
        root.shouldOpenSetupWizard = true;
      }
    }
  }

  // Watch parent config directory as a fallback for declarative setups where
  // settings.json may be replaced atomically (e.g., symlink/store-path swap).
  FileView {
    id: settingsDirWatcher
    path: directoriesCreated ? configDir : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalReload()
  }

  // FileView to load default settings for comparison
  FileView {
    id: defaultSettingsFileView
    path: Quickshell.shellDir + "/Assets/settings-default.json"
    printErrors: false
    watchChanges: false
  }

  // Cached default settings object
  property var _defaultSettings: null

  // Load default settings when file is loaded
  Connections {
    target: defaultSettingsFileView
    function onLoaded() {
      try {
        root._defaultSettings = JSON.parse(defaultSettingsFileView.text());
      } catch (e) {
        Logger.w("Settings", "Failed to parse default settings file: " + e);
        root._defaultSettings = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // One-shot import of the pre-native dashboard store (control-center.json),
  // which the Raell Dashboard wrote while it was still a plugin. It lives here
  // rather than in a Migration because migrations only receive settings.json's
  // parsed contents and cannot read a second file. Gated on isLoaded so the
  // import never lands on a not-yet-populated adapter.
  // ---------------------------------------------------------------------------
  FileView {
    id: legacyControlCenterFileView
    // path is a QString, so the "not ready yet" sentinel must be "" and not
    // undefined, which the scene graph rejects with a type warning.
    path: isLoaded ? (configDir + "control-center.json") : ""
    printErrors: false
    watchChanges: false
    onPathChanged: {
      if (path !== "") {
        reload();
      }
    }
    onLoaded: {
      if (root.data.controlCenter.legacyStoreImported)
        return;
      try {
        var legacy = JSON.parse(legacyControlCenterFileView.text());
        if (legacy && typeof legacy === "object") {
          root.importLegacyControlCenter(legacy);
          Logger.i("Settings", "Imported legacy control-center.json into controlCenter settings");
        }
      } catch (e) {
        Logger.w("Settings", "Ignoring malformed legacy control-center.json: " + e);
      }
      root.data.controlCenter.legacyStoreImported = true;
      // Flush now instead of letting saveTimer coalesce it: settingsFileView
      // watches the file, and its external-reload pass would otherwise re-read
      // the pre-import contents over the values we just set.
      root.saveImmediate();
    }
  }

  readonly property var _legacyControlCenterStringKeys: ["diskPath", "avatarPath", "avatarShape", "avatarMusicEffect", "profileCardShape", "profileDanceGifPath", "profileCoverMode", "profileCoverPath", "profileCoverFolder", "profileCoverBorderEffect", "profileCoverBorderColorMode", "profileCoverBorderAnimation", "profileCoverBorderColor1", "profileCoverBorderColor2", "profileCoverBorderColor3", "profileCoverBorderColor4", "profileCoverBorderColor5", "mediaVisualizerEffect", "audioSliderEffect", "microphoneSliderEffect"]
  readonly property var _legacyControlCenterIntKeys: ["panelWidth", "panelHeight", "profileCoverBlur", "profileCoverBorderWidth", "profileCoverBorderColorCount"]
  readonly property var _legacyControlCenterRealKeys: ["panelScale", "profileCoverOverlay", "profileCoverBorderSpeed"]
  readonly property var _legacyControlCenterBoolKeys: ["showProfileDanceGif", "showProfileWallpaper", "profileCoverOverlayEnabled", "profileCoverBlurEnabled", "profileCoverBorder", "followHydraPerformanceMode", "powerSaverPerformanceMode", "showNotifications", "showMedia", "showCalendar", "showRecordingCard"]

  // Legacy panelPosition vocabulary -> native controlCenter.position enum.
  // The legacy "left"/"right" meant vertically centred against that edge.
  readonly property var _legacyControlCenterPositions: ({
                                                          "center": "center",
                                                          "top_left": "top_left",
                                                          "top_right": "top_right",
                                                          "bottom_left": "bottom_left",
                                                          "bottom_right": "bottom_right",
                                                          "left": "center_left",
                                                          "right": "center_right"
                                                        })

  function _legacyBool(value) {
    if (typeof value === "string")
      return value !== "" && value !== "false" && value !== "0";
    return !!value;
  }

  function importLegacyControlCenter(legacy) {
    var cc = root.data.controlCenter;
    var i;
    var key;
    var value;

    // Coerce on the way in: a stringly-typed legacy file must not poison a
    // typed JsonObject property.
    for (i = 0; i < _legacyControlCenterStringKeys.length; i++) {
      key = _legacyControlCenterStringKeys[i];
      value = legacy[key];
      if (value !== undefined && value !== null)
        cc[key] = String(value);
    }

    for (i = 0; i < _legacyControlCenterIntKeys.length; i++) {
      key = _legacyControlCenterIntKeys[i];
      value = parseInt(legacy[key], 10);
      if (!isNaN(value))
        cc[key] = value;
    }

    for (i = 0; i < _legacyControlCenterRealKeys.length; i++) {
      key = _legacyControlCenterRealKeys[i];
      value = parseFloat(legacy[key]);
      if (!isNaN(value))
        cc[key] = value;
    }

    for (i = 0; i < _legacyControlCenterBoolKeys.length; i++) {
      key = _legacyControlCenterBoolKeys[i];
      if (legacy[key] !== undefined)
        cc[key] = _legacyBool(legacy[key]);
    }

    // The legacy store keyed styles by styleKey; the native store is a list of
    // entries carrying that styleKey in a "key" field.
    if (legacy.componentStyles && typeof legacy.componentStyles === "object") {
      var entries = [];
      var styleKeys = Object.keys(legacy.componentStyles);
      for (i = 0; i < styleKeys.length; i++) {
        var style = legacy.componentStyles[styleKeys[i]];
        if (style && typeof style === "object") {
          var entry = Object.assign({}, style);
          entry.key = styleKeys[i];
          entries.push(entry);
        }
      }
      cc.componentStyles = entries;
    }

    // Legacy panelDetached maps straight onto detached; followBarEdge only ever
    // meant "sit on the bar's edge", which is now position=close_to_bar_button.
    if (legacy.panelDetached !== undefined)
      cc.detached = _legacyBool(legacy.panelDetached);

    if (legacy.panelDetached !== undefined || legacy.followBarEdge !== undefined || legacy.panelPosition !== undefined) {
      var detached = legacy.panelDetached !== undefined ? _legacyBool(legacy.panelDetached) : true;
      if (!detached && _legacyBool(legacy.followBarEdge)) {
        cc.position = "close_to_bar_button";
      } else {
        var mapped = _legacyControlCenterPositions[String(legacy.panelPosition)];
        if (mapped !== undefined)
          cc.position = mapped;
      }
    }
  }

  JsonAdapter {
    id: adapter

    property int settingsVersion: 0

    // bar
    property JsonObject bar: JsonObject {
      property string barType: "simple" // "simple", "floating", "framed"
      property string position: "top" // "top", "bottom", "left", or "right"
      property list<string> monitors: [] // holds bar visibility per monitor
      property string density: "default" // "compact", "default", "comfortable"
      property bool showOutline: false
      property bool showCapsule: true
      property real capsuleOpacity: 1.0
      property string capsuleColorKey: "none"
      property int widgetSpacing: 6
      property int contentPadding: 2
      property real fontScale: 1.0
      property bool enableExclusionZoneInset: true

      // Bar background opacity settings
      property real backgroundOpacity: 0.93
      property bool useSeparateOpacity: false

      // Floating bar settings
      property int marginVertical: 4
      property int marginHorizontal: 4

      // Framed bar settings
      property int frameThickness: 8
      property int frameRadius: 12

      // Bar outer corners (inverted/concave corners at bar edges when not floating)
      property bool outerCorners: true

      // Hide bar/panels when compositor overview is active
      property bool hideOnOverview: false

      // Auto-hide settings
      property string displayMode: "always_visible"
      property int autoHideDelay: 500 // ms before hiding after mouse leaves
      property int autoShowDelay: 150 // ms before showing when mouse enters
      property bool showOnWorkspaceSwitch: true // show bar briefly on workspace switch

      // Widget configuration for modular bar system
      property JsonObject widgets
      widgets: JsonObject {
        property list<var> left: [
          {
            "id": "Launcher"
          },
          {
            "id": "Clock"
          },
          {
            "id": "SystemMonitor"
          },
          {
            "id": "ActiveWindow"
          },
          {
            "id": "MediaMini"
          }
        ]
        property list<var> center: [
          {
            "id": "Workspace"
          }
        ]
        property list<var> right: [
          {
            "id": "Tray"
          },
          {
            "id": "NotificationHistory"
          },
          {
            "id": "Battery"
          },
          {
            "id": "Volume"
          },
          {
            "id": "Brightness"
          },
          {
            "id": "ControlCenter"
          }
        ]
      }
      property string mouseWheelAction: "none"
      property bool reverseScroll: false
      property bool mouseWheelWrap: true
      property string middleClickAction: "none"
      property bool middleClickFollowMouse: false
      property string middleClickCommand: ""
      property string rightClickAction: "controlCenter"
      property bool rightClickFollowMouse: true
      property string rightClickCommand: ""
      // Per-screen overrides for position and widgets
      // Format: [{ "name": "HDMI-1", "position": "left" }, { "name": "DP-1", "position": "bottom", "widgets": {...} }]
      property list<var> screenOverrides: []
    }

    property JsonObject workspaceManager: JsonObject {
      property string presentationMode: "adaptive" // "adaptive" or "floating"
      property bool livePreviews: true
      property bool dimBackground: true
      property list<string> privateWorkspaces: []
      property list<string> customOrder: []
      property list<string> pinnedSpecials: []
      property bool gameMode: false
      property bool hideSpecials: false
      property bool showOnlyActiveSpecial: false
      property bool borderOnlyPrivacy: false
      property JsonObject presentationModePerMonitor: JsonObject {}
    }

    // general
    property JsonObject general: JsonObject {
      property string sddmTheme: ""
      property string avatarImage: ""
      property real dimmerOpacity: 0.2
      property bool showScreenCorners: false
      property bool forceBlackScreenCorners: false
      property real scaleRatio: 1.0
      property real radiusRatio: 1.0
      property real iRadiusRatio: 1.0
      property real boxRadiusRatio: 1.0
      property real screenRadiusRatio: 1.0
      property real animationSpeed: 1.0
      property bool animationDisabled: false
      property bool compactLockScreen: false
      property bool lockScreenAnimations: false
      property bool lockOnSuspend: true
      property bool showSessionButtonsOnLockScreen: true
      property bool showHibernateOnLockScreen: false
      property bool enableLockScreenMediaControls: false
      property bool enableShadows: true
      property bool enableBlurBehind: true
      property string shadowDirection: "bottom_right"
      property int shadowOffsetX: 2
      property int shadowOffsetY: 3
      property string language: ""
      property bool allowPanelsOnScreenWithoutBar: true
      property bool showChangelogOnStartup: true
      property bool telemetryEnabled: false
      property bool enableLockScreenCountdown: true
      property int lockScreenCountdownDuration: 10000
      property bool autoStartAuth: false
      property bool allowPasswordWithFprintd: false
      property string clockStyle: "custom"
      property string clockFormat: "hh\\nmm"
      property bool passwordChars: false
      property list<string> lockScreenMonitors: [] // holds lock screen visibility per monitor
      property real lockScreenBlur: 0.0
      property real lockScreenTint: 0.0
      property JsonObject keybinds: JsonObject {
        property list<string> keyUp: ["Up"]
        property list<string> keyDown: ["Down"]
        property list<string> keyLeft: ["Left"]
        property list<string> keyRight: ["Right"]
        property list<string> keyEnter: ["Return", "Enter"]
        property list<string> keyEscape: ["Esc"]
        property list<string> keyRemove: ["Del"]
      }
      property bool reverseScroll: false
      property bool smoothScrollEnabled: true
    }

    // ui
    property JsonObject ui: JsonObject {
      property string fontDefault: ""
      property string fontFixed: ""
      property real fontDefaultScale: 1.0
      property real fontFixedScale: 1.0
      property bool tooltipsEnabled: true
      property bool scrollbarAlwaysVisible: true
      property bool boxBorderEnabled: false
      property real panelBackgroundOpacity: 0.93
      property bool translucentWidgets: false
      property bool panelsAttachedToBar: true
      property string settingsPanelMode: "window" // "centered", "attached", "window"
      property bool settingsPanelSideBarCardStyle: false
    }

    // location
    property JsonObject location: JsonObject {
      property string name: ""
      property bool weatherEnabled: true
      property bool weatherShowEffects: true
      property bool weatherTaliaMascotAlways: false
      property bool useFahrenheit: false
      property bool use12hourFormat: false
      property bool showWeekNumberInCalendar: false
      property bool showCalendarEvents: true
      property bool showCalendarWeather: true
      property bool analogClockInCalendar: false
      property int firstDayOfWeek: -1 // -1 = auto (use locale), 0 = Sunday, 1 = Monday, 6 = Saturday
      property bool hideWeatherTimezone: false
      property bool hideWeatherCityName: false
      property bool autoLocate: false
    }

    // calendar
    property JsonObject calendar: JsonObject {
      property list<var> cards: [
        {
          "id": "calendar-header-card",
          "enabled": true
        },
        {
          "id": "calendar-month-card",
          "enabled": true
        },
        {
          "id": "weather-card",
          "enabled": true
        }
      ]
    }

    // wallpaper
    property JsonObject wallpaper: JsonObject {
      property bool enabled: true
      property bool overviewEnabled: false
      property string directory: ""
      property list<var> monitorDirectories: []
      property bool enableMultiMonitorDirectories: false
      property bool showHiddenFiles: false
      property string viewMode: "single" // "single" | "recursive" | "browse"
      property bool setWallpaperOnAllMonitors: true
      property bool linkLightAndDarkWallpapers: true
      property string fillMode: "crop"
      property color fillColor: "#000000"
      property bool useSolidColor: false
      property color solidColor: "#1a1a2e"
      property bool automationEnabled: false
      property string wallpaperChangeMode: "random" // "random" or "alphabetical"
      property int randomIntervalSec: 300 // 5 min
      property int transitionDuration: 1500 // 1500 ms
      property list<string> transitionType: ["fade", "disc", "stripes", "wipe", "pixelate", "honeycomb"]
      property bool skipStartupTransition: false
      property real transitionEdgeSmoothness: 0.05
      property string panelPosition: "follow_bar"
      // Active source tab of the wallpaper panel: "local" | "wallhaven" | "moewalls" | "motionbgs"
      property string wallpaperSource: "local"
      property bool hideWallpaperFilenames: false
      property bool useOriginalImages: false
      property real overviewBlur: 0.4
      property real overviewTint: 0.6
      // Wallhaven settings
      property bool useWallhaven: false
      property string wallhavenQuery: ""
      property string wallhavenSorting: "relevance"
      property string wallhavenOrder: "desc"
      property string wallhavenCategories: "111" // general,anime,people
      property string wallhavenPurity: "100" // sfw only
      property string wallhavenRatios: ""
      property string wallhavenApiKey: ""
      property string wallhavenResolutionMode: "atleast" // "atleast" or "exact"
      property string wallhavenResolutionWidth: ""
      property string wallhavenResolutionHeight: ""
      property string wallhavenTopRange: "1M" // 1d, 3d, 1w, 1M, 3M, 6M, 1y
      property string wallhavenColors: "" // Hex color without #
      property string sortOrder: "name" // "name", "name_desc", "date", "date_desc", "random"
      property list<var> favorites: []
      // Format: [{ "path": "...", "appearance": "light"|"dark", "colorScheme": "...", "darkMode": bool, "useWallpaperColors": bool, "generationMethod": "...", "paletteColors": [...] }]
      // Legacy entries omit "appearance" and use darkMode to infer light vs dark slot.
    }

    // applauncher
    property JsonObject appLauncher: JsonObject {
      property bool enableClipboardHistory: false
      property bool autoPasteClipboard: false
      property bool enableClipPreview: true
      property bool clipboardWrapText: true
      property bool enableClipboardSmartIcons: true
      property bool enableClipboardChips: true
      property string clipboardWatchTextCommand: "wl-paste --type text --watch cliphist store"
      property string clipboardWatchImageCommand: "wl-paste --type image --watch cliphist store"
      property list<string> pinnedClipboardIds: []
      // Persistent author-created notes: [{ id, text, createdAt }]
      property list<var> clipboardNotes: []
      property string position: "center"  // Position: center, top_left, top_right, bottom_left, bottom_right, bottom_center, top_center
      property list<string> pinnedApps: []
      property list<string> hiddenApps: []
      property bool sortByMostUsed: true
      property string terminalCommand: "alacritty -e"
      property bool customLaunchPrefixEnabled: false
      property string customLaunchPrefix: ""
      // View mode: "list", "columns", or "grid"
      property string viewMode: "columns"
      property string coverMode: "auto"
      property string coverPath: ""
      property string coverFolder: ""
      property int coverHeight: 160
      property real coverOverlay: 0.40
      property bool coverBlurEnabled: false
      property bool showCategories: true
      // Icon mode: "tabler" or "native"
      property string iconMode: "tabler"
      property bool showIconBackground: false
      property bool enableSettingsSearch: true
      property bool enableWindowsSearch: true
      property bool enableSessionSearch: true
      property bool ignoreMouseInput: false
      property string screenshotAnnotationTool: ""
      property bool overviewLayer: false
      property string density: "default" // "compact", "default", "comfortable"
    }

    // control center
    property JsonObject controlCenter: JsonObject {
      // Where the panel appears. "close_to_bar_button" makes it track the bar
      // widget; every other value pins it to a screen edge or corner.
      // close_to_bar_button, center, top_center, top_left, top_right,
      // center_left, center_right, bottom_center, bottom_left, bottom_right
      property string position: "close_to_bar_button"

      // Orthogonal to position: false glues the panel flush against the bar
      // (SmartPanel's allowAttach path), true floats it with a screen margin.
      // Any position can be either, e.g. top_left attached vs top_left floating.
      property bool detached: true

      property string diskPath: "/"

      // Panel geometry
      property int panelWidth: 1120
      property int panelHeight: 700
      property real panelScale: 1

      // Profile card
      property string avatarPath: ""
      property string avatarShape: "circle"
      property string avatarMusicEffect: "ring"
      property string profileCardShape: "rounded"
      property bool showProfileDanceGif: true
      property string profileDanceGifPath: ""
      property bool showProfileWallpaper: true
      property string profileCoverMode: "auto"
      property string profileCoverPath: ""
      property string profileCoverFolder: ""
      property bool profileCoverOverlayEnabled: true
      property real profileCoverOverlay: 0.58
      property bool profileCoverBlurEnabled: false
      property int profileCoverBlur: 0
      property bool profileCoverBorder: true
      property int profileCoverBorderWidth: 2
      property string profileCoverBorderEffect: "primary"
      property string profileCoverBorderColorMode: "auto"
      property string profileCoverBorderAnimation: "static"
      property real profileCoverBorderSpeed: 1
      property int profileCoverBorderColorCount: 3
      property string profileCoverBorderColor1: "#fff59b"
      property string profileCoverBorderColor2: "#8bd5ff"
      property string profileCoverBorderColor3: "#cba6f7"
      property string profileCoverBorderColor4: "#f38ba8"
      property string profileCoverBorderColor5: "#a6e3a1"

      // Visualizer / slider effects
      property string mediaVisualizerEffect: "bars"
      property string audioSliderEffect: "wave"
      property string microphoneSliderEffect: "pulse"

      // Performance
      property bool followHydraPerformanceMode: true
      property bool powerSaverPerformanceMode: true

      // Card visibility
      property bool showNotifications: true
      property bool showMedia: true
      property bool showCalendar: true
      property bool showRecordingCard: true

      // Per-card style overrides. Each entry is an object carrying a "key"
      // field naming the card's styleKey; the reserved key "__global" applies to
      // every card. Edited through the config file only; there is no UI for it.
      // A list rather than a keyed map because Quickshell's JsonObject supports
      // list<var> but segfaults on a bare `var` map property.
      property list<var> componentStyles: []

      // One-shot import marker for the pre-native control-center.json store.
      property bool legacyStoreImported: false

      property JsonObject shortcuts
      shortcuts: JsonObject {
        property list<var> left: [
          {
            "id": "Network"
          },
          {
            "id": "Bluetooth"
          },
          {
            "id": "WallpaperSelector"
          },
          {
            "id": "HydraPerformance"
          }
        ]
        property list<var> right: [
          {
            "id": "Notifications"
          },
          {
            "id": "PowerProfile"
          },
          {
            "id": "KeepAwake"
          },
          {
            "id": "NightLight"
          }
        ]
      }
      property list<var> cards: [
        {
          "id": "profile-card",
          "enabled": true
        },
        {
          "id": "shortcuts-card",
          "enabled": true
        },
        {
          "id": "audio-card",
          "enabled": true
        },
        {
          "id": "brightness-card",
          "enabled": false
        },
        {
          "id": "weather-card",
          "enabled": true
        },
        {
          "id": "media-sysmon-card",
          "enabled": true
        }
      ]
    }

    // system monitor
    property JsonObject systemMonitor: JsonObject {
      property int cpuWarningThreshold: 80
      property int cpuCriticalThreshold: 90
      property int tempWarningThreshold: 80
      property int tempCriticalThreshold: 90
      property int gpuWarningThreshold: 80
      property int gpuCriticalThreshold: 90
      property int memWarningThreshold: 80
      property int memCriticalThreshold: 90
      property int swapWarningThreshold: 80
      property int swapCriticalThreshold: 90
      property int diskWarningThreshold: 80
      property int diskCriticalThreshold: 90
      property int diskAvailWarningThreshold: 20
      property int diskAvailCriticalThreshold: 10
      property int batteryWarningThreshold: 20
      property int batteryCriticalThreshold: 5
      property bool enableDgpuMonitoring: false // Opt-in: reading dGPU sysfs/nvidia-smi wakes it from D3cold, draining battery
      property bool useCustomColors: false
      property string warningColor: ""
      property string criticalColor: ""
      property string externalMonitor: "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor"
    }

    // performance
    property JsonObject hydraPerformance: JsonObject {
      property bool disableWallpaper: true
      property bool disableDesktopWidgets: true
    }

    // dock
    property JsonObject dock: JsonObject {
      property bool enabled: true
      property string position: "bottom" // "top", "bottom", "left", "right"
      property string displayMode: "auto_hide" // "always_visible", "auto_hide", "exclusive"
      property string dockType: "floating" // "floating", "attached"
      property real backgroundOpacity: 1.0
      property real floatingRatio: 1.0
      property real size: 1
      property bool onlySameOutput: true
      property list<string> monitors: [] // holds dock visibility per monitor
      property list<string> pinnedApps: [] // Desktop entry IDs pinned to the dock (e.g., "org.kde.konsole", "firefox.desktop")
      property bool colorizeIcons: false
      property bool showLauncherIcon: false
      property string launcherPosition: "end" // "start", "end"
      property bool launcherUseDistroLogo: false
      property string launcherIcon: ""
      property string launcherIconColor: "none"
      property bool pinnedStatic: false
      property bool inactiveIndicators: false
      property bool groupApps: false
      property string groupContextMenuMode: "extended" // "list", "extended"
      property string groupClickAction: "cycle" // "cycle", "list"
      property string groupIndicatorStyle: "dots" // "number", "dots"
      property double deadOpacity: 0.6
      property real animationSpeed: 1.0 // Speed multiplier for hide/show animations (0.1 = slowest, 2.0 = fastest)
      property bool sitOnFrame: false
      property bool showDockIndicator: false
      property int indicatorThickness: 3
      property string indicatorColor: "primary"
      property real indicatorOpacity: 0.6
    }

    // network
    property JsonObject network: JsonObject {
      property bool bluetoothRssiPollingEnabled: false  // Opt-in Bluetooth RSSI polling (uses bluetoothctl)
      property int bluetoothRssiPollIntervalMs: 60000 // Polling interval in milliseconds for RSSI queries
      property string networkPanelView: "wifi"
      property string wifiDetailsViewMode: "grid"   // "grid" or "list"
      property string bluetoothDetailsViewMode: "grid" // "grid" or "list"
      property bool bluetoothHideUnnamedDevices: false
      property bool disableDiscoverability: false
      property bool bluetoothAutoConnect: true
    }

    // session menu
    property JsonObject sessionMenu: JsonObject {
      property bool enableCountdown: true
      property int countdownDuration: 10000
      property string position: "center"
      property bool showHeader: true
      property bool showKeybinds: true
      property bool showProfileBadge: true
      property bool showUptimeBadge: true
      property string coverCardMode: "auto"
      property string coverCardPath: ""
      property bool largeButtonsStyle: true
      property string largeButtonsLayout: "single-row"
      property list<var> powerOptions: [
        {
          "action": "lock",
          "enabled": true,
          "keybind": "1"
        },
        {
          "action": "suspend",
          "enabled": true,
          "keybind": "2"
        },
        {
          "action": "hibernate",
          "enabled": true,
          "keybind": "3"
        },
        {
          "action": "reboot",
          "enabled": true,
          "keybind": "4"
        },
        {
          "action": "logout",
          "enabled": true,
          "keybind": "5"
        },
        {
          "action": "shutdown",
          "enabled": true,
          "keybind": "6"
        },
        {
          "action": "rebootToUefi",
          "enabled": true,
          "keybind": "7"
        }
      ]
    }

    // notifications
    property JsonObject notifications: JsonObject {
      property bool enabled: true
      property bool enableMarkdown: false
      property string density: "default" // "default", "compact"
      property list<string> monitors: [] // holds notifications visibility per monitor
      property string location: "top_right"
      property bool overlayLayer: true
      property real backgroundOpacity: 1.0
      property bool respectExpireTimeout: false
      property int lowUrgencyDuration: 3
      property int normalUrgencyDuration: 8
      property int criticalUrgencyDuration: 15
      property bool clearDismissed: true
      property JsonObject saveToHistory: JsonObject {
        property bool low: true
        property bool normal: true
        property bool critical: true
      }
      property JsonObject sounds: JsonObject {
        property bool enabled: false
        property real volume: 0.5
        property bool separateSounds: false
        property string criticalSoundFile: ""
        property string normalSoundFile: ""
        property string lowSoundFile: ""
        property string excludedApps: "discord,firefox,chrome,chromium,edge"
      }
      property bool enableMediaToast: false
      property bool enableKeyboardLayoutToast: true
      property bool enableBatteryToast: true
    }

    // on-screen display
    property JsonObject osd: JsonObject {
      property bool enabled: true
      property string location: "top_right"
      property int autoHideMs: 2000
      property bool overlayLayer: true
      property real backgroundOpacity: 1.0
      property list<var> enabledTypes: [OSD.Type.Volume, OSD.Type.InputVolume, OSD.Type.Brightness]
      property list<string> monitors: [] // holds osd visibility per monitor
    }

    // show keys (evtest-based real-time key display OSD)
    property JsonObject showKeys: JsonObject {
      // Off by default: reads raw /dev/input/eventN, a deliberate opt-in security tradeoff (see README).
      property bool captureEnabled: false
      property string evtestDevice: "/dev/input/event3"
      property bool useCustomColors: false
      property string pillColor: ""
      property string pillBg: ""
      property string position: "bottom" // "top", "bottom"
      property int marginPx: 60
      property int hideDelaySec: 2
      property list<string> disabledScreens: []
    }

    // audio
    property JsonObject audio: JsonObject {
      property int volumeStep: 5
      property bool volumeOverdrive: false
      property int spectrumFrameRate: 30
      property string visualizerType: "linear"
      property bool spectrumMirrored: true
      property list<string> mprisBlacklist: []
      property string preferredPlayer: ""
      property bool volumeFeedback: false
      property string volumeFeedbackSoundFile: ""
    }

    // brightness
    property JsonObject brightness: JsonObject {
      property int brightnessStep: 5
      property bool enforceMinimum: true
      property bool enableDdcSupport: false
      property list<var> backlightDeviceMappings: []
      // Format: [{ "output": "eDP-1", "device": "/sys/class/backlight/intel_backlight" }]
    }

    property JsonObject colorSchemes: JsonObject {
      property bool useWallpaperColors: false
      property string predefinedScheme: "Hydra (default)"
      property bool darkMode: true
      // Valid values: "off", "manual" (fixed sunrise/sunset), "location" (weather API
      // sunrise/sunset), "wallpaper" (derived from the active wallpaper's luminance).
      property string schedulingMode: "off"
      property string manualSunrise: "06:30"
      property string manualSunset: "18:30"
      property string generationMethod: "tonal-spot"
      property string monitorForColors: ""
      property bool syncGsettings: true
    }

    // templates toggles
    property JsonObject templates: JsonObject {
      property list<var> activeTemplates: []
      // Format: [{ "id": "gtk", "enabled": true }, { "id": "qt", "enabled": true }, ...]
      property bool enableUserTheming: false
      // Xcursor/hyprcursor pixel size for the adaptive "Cursor" template (id "cursor")
      property int cursorSize: 24
    }

    // night light
    property JsonObject nightLight: JsonObject {
      property bool enabled: false
      property bool forced: false
      property bool autoSchedule: true
      property string nightTemp: "4000"
      property string dayTemp: "6500"
      property string manualSunrise: "06:30"
      property string manualSunset: "18:30"
    }

    // NVIDIA digital vibrance (nvibrant)
    property JsonObject nvibrant: JsonObject {
      property bool enabled: false
      property int vibranceValue: 512
      // stored 1-based (1 = port 0), converted on use
      property int displayIndex: 1
    }

    // persistent virtual pet state
    property JsonObject tamagotchi: JsonObject {
      property real hunger: 100
      property real happiness: 100
      property real cleanliness: 100
      property real energy: 100
      property bool sleeping: false
      property double lastDecayTimestamp: 0
      property int difficulty: 50
      property real volume: 0.5
    }

    // removable USB drive manager
    property JsonObject usbDriveManager: JsonObject {
      property bool autoMount: false
      property bool showNotifications: true
      property string fileBrowser: "xdg-open"
      property string terminal: "kitty"
    }

    // hooks
    property JsonObject hooks: JsonObject {
      property bool enabled: false
      property string wallpaperChange: ""
      property string darkModeChange: ""
      property string screenLock: ""
      property string screenUnlock: ""
      property string performanceModeEnabled: ""
      property string performanceModeDisabled: ""
      property string startup: ""
      property string session: ""
      property string colorGeneration: ""
    }

    // plugins
    property JsonObject plugins: JsonObject {
      property bool autoUpdate: false
      property bool notifyUpdates: true
    }

    // idle management
    property JsonObject idle: JsonObject {
      property bool enabled: false
      property int screenOffTimeout: 600    // seconds, 0 = disabled
      property int lockTimeout: 660         // seconds, 0 = disabled
      property int suspendTimeout: 1800     // seconds, 0 = disabled
      property int fadeDuration: 5       // seconds of fade-to-black before action fires
      property string screenOffCommand: ""
      property string lockCommand: ""
      property string suspendCommand: ""
      property string resumeScreenOffCommand: ""
      property string resumeLockCommand: ""
      property string resumeSuspendCommand: ""
      property string customCommands: "[]" // JSON array of {timeout, command, resumeCommand}
    }

    // desktop widgets
    property JsonObject desktopWidgets: JsonObject {
      property bool enabled: false
      property bool overviewEnabled: true
      property bool gridSnap: false
      property bool gridSnapScale: false
      property list<var> monitorWidgets: []
      // Format: [{ "name": "DP-1", "widgets": [...] }, { "name": "HDMI-1", "widgets": [...] }]
    }

    // hyprland ownership + Settings-panel-managed overrides (see
    // PLANO_INTEGRACAO_HYPRMOD.md). Only the fields a user actually changed
    // matter for what gets written to hydra-shell/settings.lua — the
    // generator (Helpers/HyprlandLuaGen.js) diffs every value here against
    // the shipped modules/*.lua defaults and only emits the divergence.
    property JsonObject hyprland: JsonObject {
      // { "SUPER + T": "SUPER + Y" } — consulted by modules/binds.lua's K()
      // helper; written to hydra-shell/rebinds.lua, never to settings.lua.
      // NOTE: must stay the FIRST property declared in this JsonObject.
      // Quickshell's JsonAdapter segfaults in QQmlVMEMetaObject::writeProperty
      // while reloading (FileView watchChanges) this JsonObject if a
      // `property var` holding an object-literal default is preceded by any
      // sibling property — repro'd and bisected 2026-08-11.
      property var rebinds: ({})

      // Adoption state, written by SetupHyprlandStep.qml.
      property bool ownershipAdopted: false
      property bool ownershipDeclined: false
      property string adoptedModulesVersion: ""

      // Mirrors modules/decoration.lua + modules/animations.lua's hl.config
      // leaves. Defaults below match the shipped modules exactly so an
      // untouched install never emits an override.
      property JsonObject appearance: JsonObject {
        property int gapsIn: 5
        property int gapsOut: 10
        property int borderSize: 2
        property string layout: "dwindle"
        property bool resizeOnBorder: true
        property bool allowTearing: false
        property int rounding: 10
        property int roundingPower: 2
        property real activeOpacity: 1.0
        property real inactiveOpacity: 1.0
        property bool shadowEnabled: true
        property int shadowRange: 4
        property int shadowRenderPower: 3
        property bool blurEnabled: true
        property int blurSize: 8
        property int blurPasses: 2
        property bool blurXray: false
        property bool animationsEnabled: true
      }

      // [{ name, value }] -> hl.env(name, value)
      property list<var> envVars: []
      // [{ command, enabled }] -> hl.exec_cmd(command) inside hl.on("hyprland.start", ...)
      property list<var> autostart: []
      // [{ name, match: {class, title, ...}, action, value }] -> hl.window_rule({...})
      property list<var> windowRules: []
      // [{ name, match: {namespace}, action, value }] -> hl.layer_rule({...})
      property list<var> layerRules: []
      // [{ name, x0, y0, x1, y1 }] -> hl.curve(name, {...})
      property list<var> animCurves: []
      // [{ leaf, enabled, speed, bezier, style }] -> hl.animation({...})
      property list<var> animItems: []
      // [{ combo, dispatcher, args, description }] custom binds ADDED on top
      // of modules/binds.lua (distinct from rebinds above, which remap a
      // shipped combo instead of adding a new one) -> hl.bind({...})
      property list<var> keybinds: []
      // { theme, size } -> env override + live `hyprctl setcursor`
      property JsonObject cursor: JsonObject {
        property string theme: ""
        property int size: 24
      }
    }
  }

  // -----------------------------------------------------
  // Preprocess paths by adding trailing "/"
  function ensureTrailingSlash(path) {
    return path.endsWith("/") ? path : path + "/";
  }

  // -----------------------------------------------------
  // Preprocess paths by expanding "~" to user's home directory
  function preprocessPath(path) {
    if (typeof path !== "string" || path === "") {
      return path;
    }

    // Expand "~" to user's home directory
    if (path.startsWith("~/")) {
      return Quickshell.env("HOME") + path.substring(1);
    } else if (path === "~") {
      return Quickshell.env("HOME");
    }

    return path;
  }

  // -----------------------------------------------------
  // Get default value for a setting path (e.g., "general.scaleRatio" or "bar.position")
  // Returns undefined if not found
  function getDefaultValue(path) {
    if (!root._defaultSettings) {
      return undefined;
    }

    var parts = path.split(".");
    var current = root._defaultSettings;

    for (var i = 0; i < parts.length; i++) {
      if (current === undefined || current === null) {
        return undefined;
      }
      current = current[parts[i]];
    }

    return current;
  }

  // -----------------------------------------------------
  // Compare current value with default value
  // Returns true if values differ, false if they match or default is not found
  function isValueChanged(path, currentValue) {
    var defaultValue = getDefaultValue(path);
    if (defaultValue === undefined) {
      return false; // Can't compare if default not found
    }

    // Deep comparison for objects and arrays
    if (typeof currentValue === "object" && typeof defaultValue === "object") {
      return JSON.stringify(currentValue) !== JSON.stringify(defaultValue);
    }

    // Simple comparison for primitives
    return currentValue !== defaultValue;
  }

  // -----------------------------------------------------
  // Format default value for tooltip display
  // Returns a human-readable string representation of the default value
  function formatDefaultValueForTooltip(path) {
    var defaultValue = getDefaultValue(path);
    if (defaultValue === undefined) {
      return "";
    }

    // Format based on type
    if (typeof defaultValue === "boolean") {
      return defaultValue ? "true" : "false";
    } else if (typeof defaultValue === "number") {
      return defaultValue.toString();
    } else if (typeof defaultValue === "string") {
      return defaultValue === "" ? "(empty)" : defaultValue;
    } else if (Array.isArray(defaultValue)) {
      return defaultValue.length === 0 ? "(empty)" : "[" + defaultValue.length + " items]";
    } else if (typeof defaultValue === "object") {
      return "(object)";
    }

    return String(defaultValue);
  }

  // -----------------------------------------------------
  // Helper to find a screen override entry by name in the array
  // Format: [{ "name": "HDMI-A-1", "position": "left" }, ...]
  // Note: QML's list<var> is not a true JS array, so we check for .length instead of Array.isArray()
  function _findScreenOverride(screenName) {
    var overrides = data.bar.screenOverrides;
    if (!screenName || !overrides || overrides.length === undefined) {
      return null;
    }
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        return overrides[i];
      }
    }
    return null;
  }

  // Helper to find index of a screen override entry
  function _findScreenOverrideIndex(screenName) {
    var overrides = data.bar.screenOverrides;
    if (!screenName || !overrides || overrides.length === undefined) {
      return -1;
    }
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        return i;
      }
    }
    return -1;
  }

  // -----------------------------------------------------
  // Check if a screen's overrides are enabled
  // Returns true if enabled flag is true or undefined (backward compat)
  // Returns false only if enabled is explicitly false
  function isScreenOverrideEnabled(screenName) {
    var override = _findScreenOverride(screenName);
    if (!override) {
      return false;
    }
    return override.enabled !== false;
  }

  // -----------------------------------------------------
  // Get effective bar position for a screen (with inheritance)
  // If the screen has a position override and overrides are enabled, use it; otherwise use global default
  function getBarPositionForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.position !== undefined) {
      return override.position;
    }
    return data.bar.position || "top";
  }

  // -----------------------------------------------------
  // Get effective bar widgets for a screen (with inheritance)
  // If the screen has widget overrides and overrides are enabled, use them; otherwise use global defaults
  function getBarWidgetsForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.widgets !== undefined) {
      return override.widgets;
    }
    return data.bar.widgets;
  }

  // -----------------------------------------------------
  // Get effective bar density for a screen (with inheritance)
  // If the screen has a density override and overrides are enabled, use it; otherwise use global default
  function getBarDensityForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.density !== undefined) {
      return override.density;
    }
    return data.bar.density || "default";
  }

  // -----------------------------------------------------
  // Get effective bar display mode for a screen (with inheritance)
  // If the screen has a displayMode override and overrides are enabled, use it; otherwise use global default
  function getBarDisplayModeForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.displayMode !== undefined) {
      return override.displayMode;
    }
    return data.bar.displayMode || "always_visible";
  }

  // -----------------------------------------------------
  // Check if a screen has any overrides, optionally for a specific property
  function hasScreenOverride(screenName, property) {
    var override = _findScreenOverride(screenName);
    if (!override) {
      return false;
    }
    if (property) {
      return override[property] !== undefined;
    }
    // Check if screen has any override property (besides "name")
    var keys = Object.keys(override);
    return keys.length > 1 || (keys.length === 1 && keys[0] !== "name");
  }

  // -----------------------------------------------------
  // Get the screen override entry directly (for in-place modifications)
  // Returns the actual entry object from the array, not a copy
  function getScreenOverrideEntry(screenName) {
    return _findScreenOverride(screenName);
  }

  // -----------------------------------------------------
  // Set a per-screen override
  function setScreenOverride(screenName, property, value) {
    if (!screenName)
      return;

    var overrides = JSON.parse(JSON.stringify(data.bar.screenOverrides || []));
    if (overrides.length === undefined) {
      overrides = [];
    }

    var index = -1;
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        index = i;
        break;
      }
    }

    if (index === -1) {
      // Create new entry
      var newEntry = {
        "name": screenName
      };
      newEntry[property] = value;
      overrides.push(newEntry);
    } else {
      // Update existing entry
      overrides[index][property] = value;
    }
    data.bar.screenOverrides = overrides;
  }

  // -----------------------------------------------------
  // Clear a per-screen override (revert to global default)
  // If property is null, clears all overrides for that screen
  function clearScreenOverride(screenName, property) {
    if (!screenName)
      return;

    var overrides = data.bar.screenOverrides;
    if (!overrides || overrides.length === undefined) {
      return;
    }

    overrides = JSON.parse(JSON.stringify(overrides));

    var index = -1;
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        index = i;
        break;
      }
    }

    if (index === -1) {
      return;
    }

    if (property) {
      delete overrides[index][property];
      // Remove screen entry if only "name" remains
      var keys = Object.keys(overrides[index]);
      if (keys.length <= 1 && (keys.length === 0 || keys[0] === "name")) {
        overrides.splice(index, 1);
      }
    } else {
      overrides.splice(index, 1);
    }
    data.bar.screenOverrides = overrides;
  }

  // -----------------------------------------------------
  // Public function to trigger immediate settings saving
  function saveImmediate() {
    settingsFileView.writeAdapter();
    root.settingsSaved(); // Emit signal after saving
  }

  // -----------------------------------------------------
  // Generate default settings: for reference only, not used by the shell
  function generateDefaultSettings() {
    try {
      Logger.d("Settings", "Generating settings-default.json");

      // Prepare a clean JSON
      var plainAdapter = QtObj2JS.qtObjectToPlainObject(adapter);
      var jsonData = JSON.stringify(plainAdapter, null, 2);

      var defaultPath = Quickshell.shellDir + "/Assets/settings-default.json";

      Quickshell.execDetached(["sh", "-c", `cat > "${defaultPath}" << 'HYDRA_EOF'\n${jsonData}\nHYDRA_EOF`]);
    } catch (error) {
      Logger.e("Settings", "Failed to generate default settings file: " + error);
    }
  }

  // -----------------------------------------------------
  // Generate default widget settings: for reference only, not used by the shell
  function generateWidgetDefaultSettings() {
    try {
      Logger.d("Settings", "Generating settings-widgets-default.json");

      var output = {
        "bar": QtObj2JS.qtObjectToPlainObject(BarWidgetRegistry.widgetMetadata),
        "controlCenter": QtObj2JS.qtObjectToPlainObject(ControlCenterWidgetRegistry.widgetMetadata),
        "desktop": QtObj2JS.qtObjectToPlainObject(DesktopWidgetRegistry.widgetMetadata)
      };
      var jsonData = JSON.stringify(output, null, 2);

      var defaultPath = Quickshell.shellDir + "/Assets/settings-widgets-default.json";

      Quickshell.execDetached(["sh", "-c", `cat > "${defaultPath}" << 'HYDRA_EOF'\n${jsonData}\nHYDRA_EOF`]);
    } catch (error) {
      Logger.e("Settings", "Failed to generate widget default settings file: " + error);
    }
  }

  // -----------------------------------------------------
  // Run versioned migrations using MigrationRegistry
  // rawJson is the parsed JSON file content (before adapter filtering)
  function runVersionedMigrations(rawJson) {
    // Skip migrations on fresh installs (no prior settings file)
    if (!rawJson || root.isFreshInstall) {
      Logger.i("Settings", "Fresh install detected, skipping migrations");
      return;
    }

    const currentVersion = adapter.settingsVersion;
    const migrations = MigrationRegistry.migrations;

    Logger.i("Settings", "adapter.settingsVersion:", adapter.settingsVersion);

    // Get all migration versions and sort them
    const versions = Object.keys(migrations).map(v => parseInt(v)).sort((a, b) => a - b);

    // Run migrations in order for versions newer than current
    for (var i = 0; i < versions.length; i++) {
      const version = versions[i];

      if (currentVersion < version) {
        // Create migration instance and run it
        const migrationComponent = migrations[version];
        const migration = migrationComponent.createObject(root);

        if (migration && typeof migration.migrate === "function") {
          const success = migration.migrate(adapter, Logger, rawJson);
          if (!success) {
            Logger.e("Settings", "Migration to v" + version + " failed");
          }
        } else {
          Logger.e("Settings", "Invalid migration for v" + version);
        }

        // Clean up migration instance
        if (migration) {
          migration.destroy();
        }
      }
    }
  }

  // -----------------------------------------------------
  // If the settings structure has changed, ensure
  // backward compatibility by upgrading the settings
  function upgradeSettings() {
    // Wait for PluginService to finish loading plugins first
    // This prevents deleting plugin widgets during reload before plugins are registered
    if (!PluginService.initialized || !PluginService.pluginsFullyLoaded) {
      Logger.d("Settings", "Plugins not fully loaded yet, deferring upgrade");
      Qt.callLater(upgradeSettings);
      return;
    }

    // Wait for BarWidgetRegistry to be ready
    if (!BarWidgetRegistry.widgets || Object.keys(BarWidgetRegistry.widgets).length === 0) {
      Logger.d("Settings", "BarWidgetRegistry not ready, deferring upgrade");
      Qt.callLater(upgradeSettings);
      return;
    }

    // -----------------
    const sections = ["left", "center", "right"];

    // 1. remove any non existing bar widget type
    var removedWidget = false;
    for (var s = 0; s < sections.length; s++) {
      const sectionName = sections[s];
      const widgets = adapter.bar.widgets[sectionName];
      // Iterate backward through the widgets array, so it does not break when removing a widget
      for (var i = widgets.length - 1; i >= 0; i--) {
        var widget = widgets[i];
        if (!BarWidgetRegistry.hasWidget(widget.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid bar widget ${widget.id} !!!`);
          widgets.splice(i, 1);
          removedWidget = true;
        }
      }
    }

    // -----------------
    // 2. remove any non existing control center widget type
    const ccSections = ["left", "right"];
    for (var s = 0; s < ccSections.length; s++) {
      const sectionName = ccSections[s];
      const shortcuts = adapter.controlCenter.shortcuts[sectionName];
      for (var i = shortcuts.length - 1; i >= 0; i--) {
        var shortcut = shortcuts[i];
        if (!ControlCenterWidgetRegistry.hasWidget(shortcut.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid control center widget ${shortcut.id} !!!`);
          shortcuts.splice(i, 1);
          removedWidget = true;
        }
      }
    }

    // -----------------
    // 3. remove any non existing desktop widget type
    const monitorWidgets = adapter.desktopWidgets.monitorWidgets;
    for (var m = 0; m < monitorWidgets.length; m++) {
      const monitor = monitorWidgets[m];
      if (!monitor.widgets)
        continue;
      for (var i = monitor.widgets.length - 1; i >= 0; i--) {
        var desktopWidget = monitor.widgets[i];
        if (!DesktopWidgetRegistry.hasWidget(desktopWidget.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid desktop widget ${desktopWidget.id} !!!`);
          monitor.widgets.splice(i, 1);
          removedWidget = true;
        }
      }
    }

    // -----------------
    // 4. upgrade user widget settings
    for (var s = 0; s < sections.length; s++) {
      const sectionName = sections[s];
      for (var i = 0; i < adapter.bar.widgets[sectionName].length; i++) {
        var widget = adapter.bar.widgets[sectionName][i];

        // Check if widget registry supports user settings, if it does not, then there is nothing to do
        if (BarWidgetRegistry.widgetMetadata[widget.id] === undefined) {
          continue;
        }

        if (upgradeWidget(widget)) {
          Logger.d("Settings", `Upgraded ${widget.id} widget:`, JSON.stringify(widget));
        }
      }
    }
  }

  // -----------------------------------------------------
  // Function to clean up deprecated user/custom bar widgets settings
  function upgradeWidget(widget) {
    // Backup the widget definition before altering
    const widgetBefore = JSON.stringify(widget);

    // Get all existing custom settings keys
    const keys = Object.keys(BarWidgetRegistry.widgetMetadata[widget.id]);

    // Delete deprecated user settings from the wiget
    for (const k of Object.keys(widget)) {
      if (k === "id") {
        continue;
      }
      if (!keys.includes(k)) {
        delete widget[k];
      }
    }

    // Inject missing default setting (metaData) from BarWidgetRegistry
    for (var i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k === "id") {
        continue;
      }

      if (widget[k] === undefined) {
        widget[k] = BarWidgetRegistry.widgetMetadata[widget.id][k];
      }
    }

    // Compare settings, to detect if something has been upgraded
    const widgetAfter = JSON.stringify(widget);
    return (widgetAfter !== widgetBefore);
  }
}
