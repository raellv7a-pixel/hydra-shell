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
  readonly property int settingsVersion: 61
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
      if (!root._bootstrapComplete) {
        root._pendingExternalReload = true;
        return;
      }
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
    if (!root._bootstrapComplete) {
      root._pendingExternalReload = true;
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
      if (!root._bootstrapComplete) {
        return;
      }
      root.saveImmediate();
    }
  }

  FileView {
    id: settingsFileView
    path: directoriesCreated ? settingsFile : undefined
    printErrors: false
    watchChanges: true
    onAdapterUpdated: {
      if (!root._bootstrapComplete) {
        return;
      }
      saveTimer.start();
    }

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
        var rawParsed = false;
        try {
          rawJson = JSON.parse(settingsFileView.text());
          rawParsed = true;
        } catch (e) {
          Logger.w("Settings", "Could not parse raw JSON for migrations");
        }

        root._rawInitialPersistedJson = rawJson;
        root._rawInitialSettingsParsed = rawParsed;
        if (rawParsed && rawJson && typeof rawJson === "object" && rawJson.controlCenter && typeof rawJson.controlCenter === "object") {
          root._rawInitialControlCenter = JSON.parse(JSON.stringify(rawJson.controlCenter));
        } else if (rawParsed) {
          root._rawInitialControlCenter = {};
        } else {
          root._rawInitialControlCenter = null;
        }

        // Run versioned migrations immediately, don't move it in upgradeSettings
        runVersionedMigrations(rawJson);

        // Finally, update our local settings version
        adapter.settingsVersion = root.settingsVersion;

        // Emit the signal
        root.isLoaded = true;
        root.settingsLoaded();

        upgradeSettings(rawJson);
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
        root._rawInitialPersistedJson = {};
        root._rawInitialSettingsParsed = true;
        root._rawInitialControlCenter = {};
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
  property var _rawInitialPersistedJson: null
  property var _rawInitialControlCenter: null
  property bool _rawInitialSettingsParsed: false
  property var _stagedLegacyControlCenter: null
  property bool _legacyControlCenterLoadAttempted: false
  property bool _bootstrapInProgress: false
  property bool _bootstrapComplete: false
  property bool _pendingExternalReload: false
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
    // Path is available once config directories exist so legacy store
    // can load concurrently with native settings.
    path: directoriesCreated ? (configDir + "control-center.json") : ""
    printErrors: false
    watchChanges: false
    onPathChanged: {
      if (path !== "") {
        reload();
      }
    }
    onLoaded: {
      try {
        var parsed = JSON.parse(legacyControlCenterFileView.text());
        if (parsed && typeof parsed === "object") {
          root._stagedLegacyControlCenter = parsed;
        } else {
          root._stagedLegacyControlCenter = null;
        }
      } catch (e) {
        Logger.w("Settings", "Failed to parse legacy control-center.json: " + e);
        root._stagedLegacyControlCenter = null;
      }
      root._legacyControlCenterLoadAttempted = true;
      root._checkAndRunBootstrapTransaction();
    }
    onLoadFailed: function (error) {
      root._stagedLegacyControlCenter = null;
      root._legacyControlCenterLoadAttempted = true;
      root._checkAndRunBootstrapTransaction();
    }
  }

  function _checkAndRunBootstrapTransaction() {
    if (!root.isLoaded || root._bootstrapComplete || root._bootstrapInProgress) {
      return;
    }
    upgradeSettings(root._rawInitialPersistedJson);
  }

  function _applyStagedLegacyControlCenter() {
    if (root.data.controlCenter.legacyStoreImported) {
      return;
    }

    if (!root._rawInitialSettingsParsed) {
      Logger.w("Settings", "Raw native settings could not be reliably parsed; skipping legacy control-center import to prevent overwriting native settings");
      root.data.controlCenter.legacyStoreImported = true;
      return;
    }

    if (root._stagedLegacyControlCenter && typeof root._stagedLegacyControlCenter === "object") {
      try {
        root.importLegacyControlCenter(root._stagedLegacyControlCenter, root._rawInitialControlCenter);
        Logger.i("Settings", "Imported legacy control-center.json into controlCenter settings");
      } catch (e) {
        Logger.w("Settings", "Failed to import legacy control-center.json: " + e);
      }
    }
    root.data.controlCenter.legacyStoreImported = true;
  }

  readonly property var _legacyControlCenterStringKeys: ["diskPath", "avatarPath", "avatarShape", "avatarMusicEffect", "profileCardShape", "profileDanceGifPath", "profileCoverMode", "profileCoverPath", "profileCoverFolder", "profileCoverBorderEffect", "profileCoverBorderColorMode", "profileCoverBorderAnimation", "profileCoverBorderColor1",
    "profileCoverBorderColor2", "profileCoverBorderColor3", "profileCoverBorderColor4", "profileCoverBorderColor5", "mediaVisualizerEffect", "audioSliderEffect", "microphoneSliderEffect"]
  readonly property var _legacyControlCenterIntKeys: ["panelWidth", "panelHeight", "profileCoverBlur", "profileCoverBorderWidth", "profileCoverBorderColorCount"]
  readonly property var _legacyControlCenterRealKeys: ["panelScale", "profileCoverOverlay", "profileCoverBorderSpeed"]
  readonly property var _legacyControlCenterBoolKeys: ["showProfileDanceGif", "showProfileWallpaper", "profileCoverOverlayEnabled", "profileCoverBlurEnabled", "profileCoverBorder", "followHydraPerformanceMode", "powerSaverPerformanceMode", "showNotifications", "showMedia", "showCalendar", "showRecordingCard"]

  // Legacy panelPosition vocabulary -> native controlCenter.position enum.
  // The legacy "left"/"right" meant vertically centred against that edge.
  readonly property var _legacyControlCenterPositions: ({
                                                          "center": "center",
                                                          "top_center": "top_center",
                                                          "top": "top_center",
                                                          "top_left": "top_left",
                                                          "top_right": "top_right",
                                                          "bottom_center": "bottom_center",
                                                          "bottom": "bottom_center",
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

  function importLegacyControlCenter(legacy, rawSnapshot) {
    var snapshot = rawSnapshot !== undefined && rawSnapshot !== null ? rawSnapshot : (root._rawInitialControlCenter || {});
    var cc = root.data.controlCenter;
    var i;
    var key;

    // Coerce on the way in: a stringly-typed legacy file must not poison a
    // typed JsonObject property.
    for (i = 0; i < _legacyControlCenterStringKeys.length; i++) {
      key = _legacyControlCenterStringKeys[i];
      if (snapshot[key] === undefined && legacy[key] !== undefined && legacy[key] !== null) {
        cc[key] = String(legacy[key]);
      }
    }

    for (i = 0; i < _legacyControlCenterIntKeys.length; i++) {
      key = _legacyControlCenterIntKeys[i];
      if (snapshot[key] === undefined && legacy[key] !== undefined && legacy[key] !== null) {
        var intVal = parseInt(legacy[key], 10);
        if (!isNaN(intVal))
          cc[key] = intVal;
      }
    }

    for (i = 0; i < _legacyControlCenterRealKeys.length; i++) {
      key = _legacyControlCenterRealKeys[i];
      if (snapshot[key] === undefined && legacy[key] !== undefined && legacy[key] !== null) {
        var realVal = parseFloat(legacy[key]);
        if (!isNaN(realVal))
          cc[key] = realVal;
      }
    }

    var nonVisibilityBools = ["showProfileDanceGif", "showProfileWallpaper", "profileCoverOverlayEnabled", "profileCoverBlurEnabled", "profileCoverBorder", "followHydraPerformanceMode", "powerSaverPerformanceMode"];
    for (i = 0; i < nonVisibilityBools.length; i++) {
      key = nonVisibilityBools[i];
      if (snapshot[key] === undefined && legacy[key] !== undefined && legacy[key] !== null) {
        cc[key] = _legacyBool(legacy[key]);
      }
    }

    // The legacy store keyed styles by styleKey; the native store is a list of
    // entries carrying that styleKey in a "key" field.
    // Preserve explicit empty list or map in native snapshot.
    if (snapshot.componentStyles === undefined && legacy.componentStyles && typeof legacy.componentStyles === "object") {
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
    if (snapshot.detached === undefined && legacy.panelDetached !== undefined) {
      cc.detached = _legacyBool(legacy.panelDetached);
    }

    if (snapshot.position === undefined) {
      if (legacy.panelDetached !== undefined || legacy.followBarEdge !== undefined || legacy.panelPosition !== undefined) {
        var detached = snapshot.detached !== undefined ? snapshot.detached : (legacy.panelDetached !== undefined ? _legacyBool(legacy.panelDetached) : true);
        if (!detached && _legacyBool(legacy.followBarEdge)) {
          cc.position = "close_to_bar_button";
        } else if (legacy.panelPosition !== undefined) {
          var mapped = _legacyControlCenterPositions[String(legacy.panelPosition)];
          if (mapped !== undefined)
            cc.position = mapped;
        }
      }
    }

    // Subcontrols: only import if absent from native snapshot
    if (snapshot.audioControlsEnabled === undefined && legacy.audioControlsEnabled !== undefined) {
      cc.audioControlsEnabled = _legacyBool(legacy.audioControlsEnabled);
    }
    if (snapshot.brightnessControlEnabled === undefined && legacy.brightnessControlEnabled !== undefined) {
      cc.brightnessControlEnabled = _legacyBool(legacy.brightnessControlEnabled);
    }

    // Visibility precedence and cards:
    // 1. Explicit native cards catalog in snapshot (authoritative; legacy cards/flags do not touch)
    var hasNativeCards = Array.isArray(snapshot.cards) && snapshot.cards.length > 0;
    if (hasNativeCards) {
      // Legacy card rows already in settings.json win over conflicting plugin store values.
      return;
    }

    // 2. If no native catalog:
    // Visibility precedence:
    //   explicit native visibility flags in snapshot,
    //   then legacy store flags / legacy card states,
    //   then defaults.
    var legacyCardsById = Object.create(null);
    if (Array.isArray(legacy.cards)) {
      for (var lc = 0; lc < legacy.cards.length; lc++) {
        var lcard = legacy.cards[lc];
        if (lcard && typeof lcard === "object" && typeof lcard.id === "string") {
          var normId = lcard.id.endsWith("-card") ? lcard.id.slice(0, -5) : lcard.id;
          legacyCardsById[normId] = lcard;
        }
      }
    }

    function resolveVisibility(flagKey, legacyCardId, defaultVal) {
      if (snapshot[flagKey] !== undefined)
        return _legacyBool(snapshot[flagKey]);
      if (legacy[flagKey] !== undefined)
        return _legacyBool(legacy[flagKey]);
      if (legacyCardId && legacyCardsById[legacyCardId] && legacyCardsById[legacyCardId].enabled !== undefined)
        return _legacyBool(legacyCardsById[legacyCardId].enabled);
      return defaultVal;
    }

    var showNotifs = resolveVisibility("showNotifications", "notifications", true);
    var showMed = resolveVisibility("showMedia", "media", true);
    var showCal = resolveVisibility("showCalendar", "calendar", true);
    var showRec = resolveVisibility("showRecordingCard", "recording", true);

    var audioSub = snapshot.audioControlsEnabled !== undefined ? _legacyBool(snapshot.audioControlsEnabled) : (legacy.audioControlsEnabled !== undefined ? _legacyBool(legacy.audioControlsEnabled) : (legacyCardsById.audio ? _legacyBool(legacyCardsById.audio.enabled) : true));
    var brightSub = snapshot.brightnessControlEnabled !== undefined ? _legacyBool(snapshot.brightnessControlEnabled) : (legacy.brightnessControlEnabled !== undefined ? _legacyBool(legacy.brightnessControlEnabled) : (legacyCardsById.brightness ? _legacyBool(legacyCardsById.brightness.enabled) : true));

    cc.audioControlsEnabled = audioSub;
    cc.brightnessControlEnabled = brightSub;
    cc.showNotifications = showNotifs;
    cc.showMedia = showMed;
    cc.showCalendar = showCal;
    cc.showRecordingCard = showRec;

    var perfEnabled = true;
    if (legacyCardsById.performance && legacyCardsById.performance.enabled !== undefined) {
      perfEnabled = _legacyBool(legacyCardsById.performance.enabled);
    } else if (legacyCardsById["media-sysmon"] && legacyCardsById["media-sysmon"].enabled !== undefined) {
      perfEnabled = _legacyBool(legacyCardsById["media-sysmon"].enabled);
    }

    var sysControlsEnabled = audioSub || brightSub;
    var quickActionsEnabled = legacyCardsById["quick-actions"] && legacyCardsById["quick-actions"].enabled !== undefined ? _legacyBool(legacyCardsById["quick-actions"].enabled) : true;
    var shortcutsCardEnabled = legacyCardsById.shortcuts && legacyCardsById.shortcuts.enabled !== undefined ? _legacyBool(legacyCardsById.shortcuts.enabled) : false;

    var materializedCards = [
          {
            "id": "profile",
            "zone": "left",
            "enabled": true,
            "locked": true
          },
          {
            "id": "quick-actions",
            "zone": "left",
            "enabled": quickActionsEnabled,
            "locked": false
          },
          {
            "id": "recording",
            "zone": "left",
            "enabled": showRec,
            "locked": false
          },
          {
            "id": "shortcuts",
            "zone": "left",
            "enabled": shortcutsCardEnabled,
            "locked": false
          },
          {
            "id": "performance",
            "zone": "center",
            "enabled": perfEnabled,
            "locked": false
          },
          {
            "id": "system-controls",
            "zone": "center",
            "enabled": sysControlsEnabled,
            "locked": false
          },
          {
            "id": "notifications",
            "zone": "right",
            "enabled": showNotifs,
            "locked": false
          },
          {
            "id": "media",
            "zone": "right",
            "enabled": showMed,
            "locked": false
          },
          {
            "id": "calendar",
            "zone": "right",
            "enabled": showCal,
            "locked": false
          }
        ];

    replaceControlCenterCards(materializedCards);
  }

  JsonAdapter {
    id: adapter

    property int settingsVersion: 0

    // bar
    property JsonObject bar: JsonObject {
      property string barType: "framed" // "simple", "floating", "framed"
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

    // edge shelf
    property JsonObject edgeShelf: JsonObject {
      property bool enabled: false
      property list<string> pinnedApps: []
    }

    // Hydra-side presentation and input integration, not compositor TOML.
    property JsonObject umbriel: JsonObject {
      property bool typeToLaunch: true
      property bool showSubmapIndicator: true
      property bool showSharingControls: true
      property JsonObject windowSwitcher: JsonObject {
        property string style: "compact"
        property bool mru: true
        property bool currentWorkspaceOnly: false
        property bool showAllOutputs: true
        property bool showTitle: true
        property bool showIcon: true
        property bool showCount: true
      }
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

      // System controls subcontrols
      property bool audioControlsEnabled: true
      property bool brightnessControlEnabled: true

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
          "id": "profile",
          "zone": "left",
          "enabled": true,
          "locked": true
        },
        {
          "id": "quick-actions",
          "zone": "left",
          "enabled": true,
          "locked": false
        },
        {
          "id": "recording",
          "zone": "left",
          "enabled": true,
          "locked": false
        },
        {
          "id": "shortcuts",
          "zone": "left",
          "enabled": false,
          "locked": false
        },
        {
          "id": "performance",
          "zone": "center",
          "enabled": true,
          "locked": false
        },
        {
          "id": "system-controls",
          "zone": "center",
          "enabled": true,
          "locked": false
        },
        {
          "id": "notifications",
          "zone": "right",
          "enabled": true,
          "locked": false
        },
        {
          "id": "media",
          "zone": "right",
          "enabled": true,
          "locked": false
        },
        {
          "id": "calendar",
          "zone": "right",
          "enabled": true,
          "locked": false
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
      property string surfaceStyle: "classic"
      property int seedIndex: 0
      property string materialSpec: "2025"
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

    const persistedVersion = rawJson?.settingsVersion;
    // Invalid values cannot identify an upgrade; preserve explicit native settings.
    const currentVersion = Number.isInteger(persistedVersion) && persistedVersion >= 0 && persistedVersion <= root.settingsVersion ? persistedVersion : root.settingsVersion;
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
  function upgradeSettings(persistedJson) {
    if (root._bootstrapComplete || root._bootstrapInProgress) {
      return;
    }

    // Wait for legacy control center store to load or finish attempt if pending
    if (!root.data.controlCenter.legacyStoreImported && !root._legacyControlCenterLoadAttempted) {
      Logger.d("Settings", "Legacy control center store load pending, deferring upgrade");
      Qt.callLater(() => upgradeSettings(persistedJson));
      return;
    }

    // Wait for PluginService to finish loading plugins first
    // This prevents deleting plugin widgets during reload before plugins are registered
    if (!PluginService.initialized || !PluginService.pluginsFullyLoaded) {
      Logger.d("Settings", "Plugins not fully loaded yet, deferring upgrade");
      Qt.callLater(() => upgradeSettings(persistedJson));
      return;
    }

    // Wait for BarWidgetRegistry to be ready
    if (!BarWidgetRegistry.widgets || Object.keys(BarWidgetRegistry.widgets).length === 0) {
      Logger.d("Settings", "BarWidgetRegistry not ready, deferring upgrade");
      Qt.callLater(() => upgradeSettings(persistedJson));
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
        if (shortcut.id && shortcut.id.startsWith("plugin:")) {
          continue;
        }
        if (!ControlCenterWidgetRegistry.hasWidget(shortcut.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid control center widget ${shortcut.id} !!!`);
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

    root._bootstrapInProgress = true;
    try {
      // -----------------
      // 5. legacy control-center import:
      // Synchronously apply staged legacy preferences if not already imported
      root._applyStagedLegacyControlCenter();

      // -----------------
      // 6. normalize and migrate control center cards
      // JsonAdapter may retain schema defaults for values written by the old Dashboard.
      // Reapply raw persisted values after registry readiness, before normalizing cards.
      var rawCC = persistedJson && persistedJson.controlCenter ? persistedJson.controlCenter : (root._rawInitialControlCenter || {});
      var hasPersistedCards = rawCC && Array.isArray(rawCC.cards) && rawCC.cards.length > 0;

      if (!hasPersistedCards && rawCC) {
        if (rawCC.audioControlsEnabled !== undefined)
          adapter.controlCenter.audioControlsEnabled = rawCC.audioControlsEnabled;
        if (rawCC.brightnessControlEnabled !== undefined)
          adapter.controlCenter.brightnessControlEnabled = rawCC.brightnessControlEnabled;
        var legacyVisibilityKeys = ["showNotifications", "showMedia", "showCalendar", "showRecordingCard"];
        for (var v = 0; v < legacyVisibilityKeys.length; v++) {
          var key = legacyVisibilityKeys[v];
          if (rawCC[key] !== undefined)
            adapter.controlCenter[key] = rawCC[key];
        }
      }

      normalizeControlCenterCards(hasPersistedCards ? rawCC.cards : (rawCC && rawCC.cards !== undefined ? rawCC.cards : undefined));

      // -----------------
      // 7. Persist one final normalized adapter without yielding
      root.saveImmediate();
    } finally {
      root._bootstrapInProgress = false;
      root._bootstrapComplete = true;
      if (root._pendingExternalReload) {
        root._pendingExternalReload = false;
        externalReloadTimer.restart();
      }
    }
  }

  // -----------------------------------------------------
  // Control Center Cards helpers and migration

  function getDefaultControlCenterCards() {
    return [
          {
            "id": "profile",
            "zone": "left",
            "enabled": true,
            "locked": true
          },
          {
            "id": "quick-actions",
            "zone": "left",
            "enabled": true,
            "locked": false
          },
          {
            "id": "recording",
            "zone": "left",
            "enabled": true,
            "locked": false
          },
          {
            "id": "shortcuts",
            "zone": "left",
            "enabled": false,
            "locked": false
          },
          {
            "id": "performance",
            "zone": "center",
            "enabled": true,
            "locked": false
          },
          {
            "id": "system-controls",
            "zone": "center",
            "enabled": true,
            "locked": false
          },
          {
            "id": "notifications",
            "zone": "right",
            "enabled": true,
            "locked": false
          },
          {
            "id": "media",
            "zone": "right",
            "enabled": true,
            "locked": false
          },
          {
            "id": "calendar",
            "zone": "right",
            "enabled": true,
            "locked": false
          }
        ];
  }

  function replaceControlCenterCards(nextCards) {
    adapter.controlCenter.cards.length = 0;
    for (var i = 0; i < nextCards.length; i++)
      adapter.controlCenter.cards.push(nextCards[i]);
  }

  function normalizeControlCenterCards(rawCardsOverride) {
    var blurValue = Number(adapter.controlCenter.profileCoverBlur);
    if (!isFinite(blurValue))
      blurValue = 0;
    var normalizedBlur = Math.max(0, Math.min(48, Math.round(blurValue)));
    var blurChanged = adapter.controlCenter.profileCoverBlur !== normalizedBlur;
    if (blurChanged)
      adapter.controlCenter.profileCoverBlur = normalizedBlur;

    var rawCards = [];
    if (Array.isArray(rawCardsOverride)) {
      rawCards = rawCardsOverride.slice();
    } else {
      var currentCards = adapter.controlCenter.cards;
      for (var c = 0; c < currentCards.length; c++)
        rawCards.push(currentCards[c]);
    }

    var defaultCards = [
          {
            "id": "profile",
            "zone": "left",
            "enabled": true,
            "locked": true
          },
          {
            "id": "quick-actions",
            "zone": "left",
            "enabled": true,
            "locked": false
          },
          {
            "id": "recording",
            "zone": "left",
            "enabled": adapter.controlCenter.showRecordingCard !== undefined ? adapter.controlCenter.showRecordingCard : true,
            "locked": false
          },
          {
            "id": "shortcuts",
            "zone": "left",
            "enabled": false,
            "locked": false
          },
          {
            "id": "performance",
            "zone": "center",
            "enabled": true,
            "locked": false
          },
          {
            "id": "system-controls",
            "zone": "center",
            "enabled": true,
            "locked": false
          },
          {
            "id": "notifications",
            "zone": "right",
            "enabled": adapter.controlCenter.showNotifications !== undefined ? adapter.controlCenter.showNotifications : true,
            "locked": false
          },
          {
            "id": "media",
            "zone": "right",
            "enabled": adapter.controlCenter.showMedia !== undefined ? adapter.controlCenter.showMedia : true,
            "locked": false
          },
          {
            "id": "calendar",
            "zone": "right",
            "enabled": adapter.controlCenter.showCalendar !== undefined ? adapter.controlCenter.showCalendar : true,
            "locked": false
          }
        ];

    var isLegacy = false;
    if (rawCards.length === 0) {
      isLegacy = true;
    } else {
      for (var i = 0; i < rawCards.length; i++) {
        var c = rawCards[i];
        if (!c || typeof c !== "object" || !c.zone || (typeof c.id === "string" && c.id.endsWith("-card"))) {
          isLegacy = true;
          break;
        }
      }
    }

    if (isLegacy) {
      Logger.i("Settings", "Migrating legacy Control Center card configuration (" + rawCards.length + " entries)");

      var migrated = [];
      var nativeCardsById = Object.create(null);
      var explicitlyConfigured = Object.create(null);
      for (var d = 0; d < defaultCards.length; d++) {
        var defaultCard = Object.assign({}, defaultCards[d]);
        migrated.push(defaultCard);
        nativeCardsById[defaultCard.id] = defaultCard;
      }

      var hasLegacyAudio = false;
      var legacyAudioEnabled = true;
      var hasLegacyBrightness = false;
      var legacyBrightnessEnabled = true;
      var hasLegacyMediaSysmon = false;
      var legacyMediaSysmonEnabled = true;

      for (var r = 0; r < rawCards.length; r++) {
        var rc = rawCards[r];
        if (!rc || typeof rc !== "object" || !rc.id)
          continue;

        var rawId = String(rc.id);
        if (nativeCardsById[rawId]) {
          if (rc.enabled !== undefined) {
            nativeCardsById[rawId].enabled = rc.enabled !== false;
            explicitlyConfigured[rawId] = true;
          }
          continue;
        }

        if (rawId === "shortcuts-card") {
          if (!explicitlyConfigured.shortcuts)
            nativeCardsById.shortcuts.enabled = rc.enabled !== false;
        } else if (rawId === "audio-card") {
          hasLegacyAudio = true;
          legacyAudioEnabled = rc.enabled !== false;
        } else if (rawId === "brightness-card") {
          hasLegacyBrightness = true;
          legacyBrightnessEnabled = rc.enabled !== false;
        } else if (rawId === "media-sysmon-card") {
          hasLegacyMediaSysmon = true;
          legacyMediaSysmonEnabled = rc.enabled !== false;
        } else if (rawId !== "profile-card" && rawId !== "weather-card") {
          migrated.push({
                          "id": rawId,
                          "zone": (rc.zone === "center" || rc.zone === "right") ? rc.zone : "left",
                          "enabled": rc.enabled !== false,
                          "locked": false
                        });
        }
      }

      // The old audio/brightness cards are now subcontrols of the System Controls card.
      // Map each legacy child preference individually.
      if (hasLegacyAudio) {
        adapter.controlCenter.audioControlsEnabled = legacyAudioEnabled;
      }
      if (hasLegacyBrightness) {
        adapter.controlCenter.brightnessControlEnabled = legacyBrightnessEnabled;
      }

      var finalAudio = hasLegacyAudio ? legacyAudioEnabled : (adapter.controlCenter.audioControlsEnabled !== undefined ? adapter.controlCenter.audioControlsEnabled : true);
      var finalBrightness = hasLegacyBrightness ? legacyBrightnessEnabled : (adapter.controlCenter.brightnessControlEnabled !== undefined ? adapter.controlCenter.brightnessControlEnabled : true);
      var bothLegacySubcontrolsDisabled = !finalAudio && !finalBrightness;

      if (explicitlyConfigured["system-controls"]) {
        // Explicit state wins, but if both subcontrols are disabled normalize parent disabled
        if (bothLegacySubcontrolsDisabled) {
          nativeCardsById["system-controls"].enabled = false;
        }
      } else {
        nativeCardsById["system-controls"].enabled = finalAudio || finalBrightness;
      }

      // The former combined Media/System Monitor card became two real overview
      // cards. Carry its enabled state to each unless a native card entry wins.
      if (hasLegacyMediaSysmon) {
        if (!explicitlyConfigured.media)
          nativeCardsById.media.enabled = legacyMediaSysmonEnabled;
        if (!explicitlyConfigured.performance)
          nativeCardsById.performance.enabled = legacyMediaSysmonEnabled;
      }

      // Enforce nonempty center-zone invariant before replace/save:
      // If no enabled center card, enable performance even if legacy media-sysmon disabled;
      // do not re-enable system-controls when both children false.
      var centerHasEnabled = false;
      for (var ci = 0; ci < migrated.length; ci++) {
        if (migrated[ci].zone === "center" && migrated[ci].enabled) {
          centerHasEnabled = true;
          break;
        }
      }
      if (!centerHasEnabled) {
        if (nativeCardsById.performance) {
          nativeCardsById.performance.enabled = true;
        } else {
          var centerCandidate = migrated.find(function (c) {
            return c.zone === "center" && (c.id !== "system-controls" || !bothLegacySubcontrolsDisabled);
          });
          if (centerCandidate) {
            centerCandidate.enabled = true;
          } else {
            var anyCenter = migrated.find(function (c) {
              return c.zone === "center";
            });
            if (anyCenter)
              anyCenter.enabled = true;
          }
        }
      }

      // Enforce nonempty right-zone invariant:
      var rightHasEnabled = false;
      for (var ri = 0; ri < migrated.length; ri++) {
        if (migrated[ri].zone === "right" && migrated[ri].enabled) {
          rightHasEnabled = true;
          break;
        }
      }
      if (!rightHasEnabled) {
        if (nativeCardsById.notifications) {
          nativeCardsById.notifications.enabled = true;
        } else {
          var firstRight = migrated.find(function (c) {
            return c.zone === "right";
          });
          if (firstRight)
            firstRight.enabled = true;
        }
      }

      // Profile card is mandatory, unique, and strictly anchored at index 0 left, enabled and locked
      var otherMigrated = migrated.filter(function (c) {
        return c.id !== "profile";
      });
      var finalMigrated = [
            {
              "id": "profile",
              "zone": "left",
              "enabled": true,
              "locked": true
            }
          ].concat(otherMigrated);

      replaceControlCenterCards(finalMigrated);
      adapter.controlCenter.showNotifications = isControlCenterCardEnabled("notifications", true);
      adapter.controlCenter.showMedia = isControlCenterCardEnabled("media", true);
      adapter.controlCenter.showCalendar = isControlCenterCardEnabled("calendar", true);
      adapter.controlCenter.showRecordingCard = isControlCenterCardEnabled("recording", true);
      root.saveImmediate();
      return;
    }

    // Modern / zone-based catalog normalization
    var seenIds = Object.create(null);
    seenIds.profile = true;
    var leftCards = [];
    var centerCards = [];
    var rightCards = [];

    for (var k = 0; k < rawCards.length; k++) {
      var card = rawCards[k];
      if (!card || typeof card !== "object" || typeof card.id !== "string" || !card.id)
        continue;
      if (card.id === "profile")
        continue;
      if (seenIds[card.id])
        continue;
      seenIds[card.id] = true;

      var defaultEnabled = true;
      for (var di = 0; di < defaultCards.length; di++) {
        if (defaultCards[di].id === card.id) {
          defaultEnabled = defaultCards[di].enabled;
          break;
        }
      }

      var normCard = {
        "id": String(card.id),
        "zone": (card.zone === "center" || card.zone === "right") ? card.zone : "left",
        "enabled": card.enabled !== undefined ? (card.enabled !== false) : defaultEnabled,
        "locked": false
      };

      if (normCard.zone === "center") {
        centerCards.push(normCard);
      } else if (normCard.zone === "right") {
        rightCards.push(normCard);
      } else {
        leftCards.push(normCard);
      }
    }

    // Ensure all canonical cards exist in their respective zones
    for (var m = 0; m < defaultCards.length; m++) {
      var defCard = defaultCards[m];
      if (!seenIds[defCard.id]) {
        var missingCard = {
          "id": defCard.id,
          "zone": defCard.zone,
          "enabled": defCard.enabled,
          "locked": false
        };
        seenIds[defCard.id] = true;
        if (missingCard.zone === "center") {
          centerCards.push(missingCard);
        } else if (missingCard.zone === "right") {
          rightCards.push(missingCard);
        } else {
          leftCards.push(missingCard);
        }
      }
    }

    // If parent system-controls is present but both subcontrols are false,
    // normalize parent disabled without forcing either child back on.
    var audioSubEnabled = adapter.controlCenter.audioControlsEnabled !== false;
    var brightnessSubEnabled = adapter.controlCenter.brightnessControlEnabled !== false;
    var bothSubcontrolsDisabled = !audioSubEnabled && !brightnessSubEnabled;

    if (bothSubcontrolsDisabled) {
      for (var sc = 0; sc < centerCards.length; sc++) {
        if (centerCards[sc].id === "system-controls") {
          centerCards[sc].enabled = false;
          break;
        }
      }
    }

    // Invariant: At least one card must remain enabled in each zone.
    // Deterministic single-zone fallback without unnecessary preference loss:
    // Left: profile is always enabled and locked.
    // Center: if no card is enabled, re-enable the first available center card
    // (preference: performance, then system-controls if subcontrols permitted).
    var centerEnabledCount = centerCards.filter(function (c) {
      return c.enabled;
    }).length;
    if (centerEnabledCount === 0 && centerCards.length > 0) {
      var candidate = centerCards.find(function (c) {
        return c.id !== "system-controls" || (!bothSubcontrolsDisabled);
      });
      if (candidate) {
        candidate.enabled = true;
      } else {
        centerCards[0].enabled = true;
      }
    }
    // Right: if no card is enabled, re-enable the first available right card (preference: notifications).
    var rightEnabledCount = rightCards.filter(function (c) {
      return c.enabled;
    }).length;
    if (rightEnabledCount === 0 && rightCards.length > 0) {
      rightCards[0].enabled = true;
    }

    // Profile card is mandatory, unique, and strictly anchored at index 0 left, enabled and locked
    var profileCard = {
      "id": "profile",
      "zone": "left",
      "enabled": true,
      "locked": true
    };
    var normalized = [profileCard].concat(leftCards, centerCards, rightCards);
    var changed = JSON.stringify(normalized) !== JSON.stringify(rawCards);
    if (changed) {
      Logger.i("Settings", "Normalized Control Center cards catalog");
      replaceControlCenterCards(normalized);
    }

    var showNotifs = isControlCenterCardEnabled("notifications", true);
    var showMed = isControlCenterCardEnabled("media", true);
    var showCal = isControlCenterCardEnabled("calendar", true);
    var showRec = isControlCenterCardEnabled("recording", true);

    var flagsChanged = false;
    if (adapter.controlCenter.showNotifications !== showNotifs) {
      adapter.controlCenter.showNotifications = showNotifs;
      flagsChanged = true;
    }
    if (adapter.controlCenter.showMedia !== showMed) {
      adapter.controlCenter.showMedia = showMed;
      flagsChanged = true;
    }
    if (adapter.controlCenter.showCalendar !== showCal) {
      adapter.controlCenter.showCalendar = showCal;
      flagsChanged = true;
    }
    if (adapter.controlCenter.showRecordingCard !== showRec) {
      adapter.controlCenter.showRecordingCard = showRec;
      flagsChanged = true;
    }

    if (changed || flagsChanged || blurChanged) {
      root.saveImmediate();
    }
  }

  function isControlCenterCardEnabled(cardId, defaultValue) {
    var cards = adapter.controlCenter.cards;
    if (!cards || cards.length === 0)
      return defaultValue !== undefined ? defaultValue : true;
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].id === cardId) {
        return cards[i].enabled !== false;
      }
    }
    return defaultValue !== undefined ? defaultValue : true;
  }

  function setControlCenterCardEnabled(cardId, enabled) {
    var cards = [];
    for (var c = 0; c < adapter.controlCenter.cards.length; c++)
      cards.push(adapter.controlCenter.cards[c]);
    var found = false;
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].id === cardId) {
        if (cards[i].locked)
          return;
        // Cannot enable system-controls when both subordinate controls are disabled
        if (cardId === "system-controls" && enabled) {
          var audioOn = adapter.controlCenter.audioControlsEnabled !== false;
          var brightnessOn = adapter.controlCenter.brightnessControlEnabled !== false;
          if (!audioOn && !brightnessOn) {
            return;
          }
        }
        // Enforce invariant: at least one card in the zone must remain enabled
        if (!enabled) {
          var targetZone = cards[i].zone;
          var enabledInZone = 0;
          for (var zi = 0; zi < cards.length; zi++) {
            if (cards[zi].zone === targetZone && cards[zi].enabled) {
              enabledInZone++;
            }
          }
          if (enabledInZone <= 1) {
            // Cannot disable the last remaining active card in this zone
            return;
          }
        }
        cards[i] = Object.assign({}, cards[i], {
                                   "enabled": enabled
                                 });
        found = true;
        break;
      }
    }
    if (found) {
      replaceControlCenterCards(cards);
      if (cardId === "notifications")
        adapter.controlCenter.showNotifications = enabled;
      else if (cardId === "media")
        adapter.controlCenter.showMedia = enabled;
      else if (cardId === "calendar")
        adapter.controlCenter.showCalendar = enabled;
      else if (cardId === "recording")
        adapter.controlCenter.showRecordingCard = enabled;
      root.save();
    }
  }

  function getControlCenterCardsForZone(zone) {
    var cards = adapter.controlCenter.cards || [];
    var result = [];
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].zone === zone) {
        result.push(cards[i]);
      }
    }
    return result;
  }

  function reorderControlCenterCards(zone, fromIndex, toIndex) {
    var cards = [];
    for (var c = 0; c < adapter.controlCenter.cards.length; c++)
      cards.push(adapter.controlCenter.cards[c]);
    var zoneIndices = [];
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].zone === zone) {
        zoneIndices.push(i);
      }
    }
    if (fromIndex < 0 || fromIndex >= zoneIndices.length || toIndex < 0 || toIndex >= zoneIndices.length)
      return;
    var fromGlobal = zoneIndices[fromIndex];
    var toGlobal = zoneIndices[toIndex];
    if (cards[fromGlobal].locked || cards[toGlobal].locked)
      return;

    var item = cards.splice(fromGlobal, 1)[0];
    cards.splice(toGlobal, 0, item);
    replaceControlCenterCards(cards);
    root.save();
  }

  function setControlCenterAudioControlsEnabled(enabled) {
    var parentEnabled = isControlCenterCardEnabled("system-controls", true);
    var brightnessOn = adapter.controlCenter.brightnessControlEnabled !== false;
    if (parentEnabled && !enabled && !brightnessOn) {
      // At least one subordinate control must stay enabled while parent card is active
      return;
    }
    adapter.controlCenter.audioControlsEnabled = enabled;
    root.save();
  }

  function setControlCenterBrightnessControlEnabled(enabled) {
    var parentEnabled = isControlCenterCardEnabled("system-controls", true);
    var audioOn = adapter.controlCenter.audioControlsEnabled !== false;
    if (parentEnabled && !enabled && !audioOn) {
      // At least one subordinate control must stay enabled while parent card is active
      return;
    }
    adapter.controlCenter.brightnessControlEnabled = enabled;
    root.save();
  }

  function resetControlCenterCards() {
    replaceControlCenterCards(getDefaultControlCenterCards());
    adapter.controlCenter.audioControlsEnabled = true;
    adapter.controlCenter.brightnessControlEnabled = true;
    adapter.controlCenter.showNotifications = true;
    adapter.controlCenter.showMedia = true;
    adapter.controlCenter.showCalendar = true;
    adapter.controlCenter.showRecordingCard = true;
    root.save();
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
