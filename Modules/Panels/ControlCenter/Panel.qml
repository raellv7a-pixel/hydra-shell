import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Modules.Cards
import qs.Modules.Panels.Settings
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Location
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Noctalia
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: ControlCenterService.provider
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property var activeScreen: pluginApi?.panelOpenScreen
  readonly property bool panelDetached: cfg.panelDetached ?? defaults.panelDetached ?? true
  readonly property string panelPosition: cfg.panelPosition ?? defaults.panelPosition ?? "center"
  readonly property bool followBarEdge: cfg.followBarEdge ?? defaults.followBarEdge ?? true
  readonly property string barPosition: Settings.getBarPositionForScreen(activeScreen?.name)
  readonly property string resolvedPanelPosition: (!panelDetached && followBarEdge) ? barPosition : panelPosition
  readonly property real localScale: cfg.panelScale ?? defaults.panelScale ?? 1
  readonly property real panelBaseWidth: cfg.panelWidth ?? defaults.panelWidth ?? 1120
  readonly property real panelBaseHeight: cfg.panelHeight ?? defaults.panelHeight ?? 700
  readonly property string configuredAvatar: cfg.avatarPath ?? defaults.avatarPath ?? ""
  readonly property string avatarPath: configuredAvatar !== "" ? configuredAvatar : Settings.data.general.avatarImage
  readonly property string profileDanceGifPath: cfg.profileDanceGifPath ?? defaults.profileDanceGifPath ?? ""
  readonly property string resolvedProfileDanceGifPath: profileDanceGifPath !== "" ? Settings.preprocessPath(profileDanceGifPath) : ""
  readonly property bool showProfileDanceGif: cfg.showProfileDanceGif ?? defaults.showProfileDanceGif ?? true
  readonly property bool showProfileWallpaper: cfg.showProfileWallpaper ?? defaults.showProfileWallpaper ?? true
  readonly property string profileCoverMode: showProfileWallpaper ? (cfg.profileCoverMode ?? defaults.profileCoverMode ?? "auto") : "none"
  readonly property string profileCoverPath: cfg.profileCoverPath ?? defaults.profileCoverPath ?? ""
  readonly property string profileCoverFolder: cfg.profileCoverFolder ?? defaults.profileCoverFolder ?? ""
  readonly property bool profileCoverOverlayEnabled: cfg.profileCoverOverlayEnabled ?? defaults.profileCoverOverlayEnabled ?? true
  readonly property real profileCoverOverlay: cfg.profileCoverOverlay ?? defaults.profileCoverOverlay ?? 0.58
  readonly property bool profileCoverBlurEnabled: cfg.profileCoverBlurEnabled ?? defaults.profileCoverBlurEnabled ?? false
  readonly property real profileCoverBlur: cfg.profileCoverBlur ?? defaults.profileCoverBlur ?? 0
  readonly property bool profileCoverBorder: cfg.profileCoverBorder ?? defaults.profileCoverBorder ?? true
  readonly property real profileCoverBorderWidth: cfg.profileCoverBorderWidth ?? defaults.profileCoverBorderWidth ?? 2
  readonly property string profileCoverBorderEffect: cfg.profileCoverBorderEffect ?? defaults.profileCoverBorderEffect ?? "primary"
  readonly property string profileCoverBorderColorMode: cfg.profileCoverBorderColorMode ?? defaults.profileCoverBorderColorMode ?? "auto"
  readonly property string profileCoverBorderAnimation: cfg.profileCoverBorderAnimation ?? legacyProfileCoverBorderAnimation()
  readonly property real profileCoverBorderSpeed: cfg.profileCoverBorderSpeed ?? defaults.profileCoverBorderSpeed ?? 1
  readonly property int profileCoverBorderColorCount: cfg.profileCoverBorderColorCount ?? defaults.profileCoverBorderColorCount ?? 3
  readonly property string profileCoverBorderColor1: cfg.profileCoverBorderColor1 ?? defaults.profileCoverBorderColor1 ?? "#fff59b"
  readonly property string profileCoverBorderColor2: cfg.profileCoverBorderColor2 ?? defaults.profileCoverBorderColor2 ?? "#8bd5ff"
  readonly property string profileCoverBorderColor3: cfg.profileCoverBorderColor3 ?? defaults.profileCoverBorderColor3 ?? "#cba6f7"
  readonly property string profileCoverBorderColor4: cfg.profileCoverBorderColor4 ?? defaults.profileCoverBorderColor4 ?? "#f38ba8"
  readonly property string profileCoverBorderColor5: cfg.profileCoverBorderColor5 ?? defaults.profileCoverBorderColor5 ?? "#a6e3a1"
  readonly property var componentStyles: cfg.componentStyles ?? ({})
  property string randomProfileCoverPath: ""
  readonly property string profileWallpaperPath: {
    if (profileCoverMode === "none")
      return "";
    if (profileCoverMode === "custom")
      return profileCoverPath !== "" ? Settings.preprocessPath(profileCoverPath) : "";
    if (profileCoverMode === "random")
      return randomProfileCoverPath;
    return WallpaperService.getWallpaper(activeScreen?.name ?? "") || "";
  }
  readonly property string mediaVisualizerEffect: cfg.mediaVisualizerEffect ?? defaults.mediaVisualizerEffect ?? "bars"
  readonly property string audioSliderEffect: cfg.audioSliderEffect ?? defaults.audioSliderEffect ?? "wave"
  readonly property string microphoneSliderEffect: cfg.microphoneSliderEffect ?? defaults.microphoneSliderEffect ?? "pulse"
  readonly property string avatarMusicEffect: cfg.avatarMusicEffect ?? defaults.avatarMusicEffect ?? "ring"
  readonly property string avatarShape: cfg.avatarShape ?? defaults.avatarShape ?? "circle"
  readonly property string profileCardShape: cfg.profileCardShape ?? defaults.profileCardShape ?? "rounded"
  readonly property bool followNoctaliaPerformanceMode: cfg.followNoctaliaPerformanceMode ?? defaults.followNoctaliaPerformanceMode ?? true
  readonly property bool powerSaverPerformanceMode: cfg.powerSaverPerformanceMode ?? defaults.powerSaverPerformanceMode ?? true
  readonly property bool dashboardPerformanceMode: (followNoctaliaPerformanceMode && PowerProfileService.noctaliaPerformanceMode) || (powerSaverPerformanceMode && PowerProfileService.available && PowerProfileService.profile === 0)
  readonly property bool musicActive: MediaService.currentPlayer !== null && MediaService.isPlaying
  readonly property string panelSpectrumComponentId: "plugin:raell-dashboard:panel:" + (activeScreen?.name ?? "unknown")
  readonly property bool needsMediaSpectrum: activeDetailView === "media" || (mediaVisualizerEffect !== "" && mediaVisualizerEffect !== "none")
  readonly property bool needsPanelSpectrum: !dashboardPerformanceMode && musicActive && needsMediaSpectrum
  readonly property real maxPanelWidth: Math.max(760, (activeScreen?.width ?? 1280) - Style.marginXL * 4)
  readonly property real maxPanelHeight: Math.max(560, (activeScreen?.height ?? 760) - Style.marginXL * 4)
  readonly property real requestedPanelWidth: panelBaseWidth * Style.uiScaleRatio * localScale
  readonly property real requestedPanelHeight: panelBaseHeight * Style.uiScaleRatio * localScale
  readonly property real autoFitScale: Math.min(1, Math.min(maxPanelWidth / Math.max(1, requestedPanelWidth), maxPanelHeight / Math.max(1, requestedPanelHeight)))
  readonly property real panelUnit: Style.uiScaleRatio * localScale * autoFitScale

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: !panelDetached
  property bool panelAnchorRight: resolvedPanelPosition === "right"
  property bool panelAnchorLeft: resolvedPanelPosition === "left"
  property bool panelAnchorHorizontalCenter: resolvedPanelPosition === "center" || resolvedPanelPosition === "top" || resolvedPanelPosition === "bottom"
  property bool panelAnchorVerticalCenter: resolvedPanelPosition === "center" || resolvedPanelPosition === "left" || resolvedPanelPosition === "right"
  property bool panelAnchorTop: resolvedPanelPosition === "top"
  property bool panelAnchorBottom: resolvedPanelPosition === "bottom"
  property real contentPreferredWidth: Math.min(panelBaseWidth * panelUnit, maxPanelWidth)
  property real contentPreferredHeight: Math.min(panelBaseHeight * panelUnit, maxPanelHeight)
  property string expandedNotificationId: ""
  property string activeDetailView: ""
  readonly property bool centerDetailOpen: activeDetailView === "performance" || activeDetailView === "audio"
  readonly property bool rightDetailOpen: activeDetailView === "media" || activeDetailView === "notifications" || activeDetailView === "weather" || activeDetailView === "calendar" || activeDetailView === "screenUsage"
  property var pendingIpcCommand: []
  property string pendingNativePanelName: ""
  property string pendingCaptureAction: ""
  property string pendingScreenshotMode: ""
  property string pendingRecordFormat: "gif"
  property string lastRecordStatus: ""
  property string lastRecordOutputPath: ""
  property string lastRecordFormat: ""
  property string toolkitRecordState: ""
  property real localGpuUsage: -1
  property string localGpuName: ""
  readonly property string screenUsageDirPath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/raell-dashboard"
  readonly property string screenUsageFilePath: screenUsageDirPath + "/screen-usage.json"
  property var screenUsageDays: ({})
  property string usageCurrentAppId: ""
  property string usageCurrentAppName: ""
  property string usageCurrentAppTitle: ""
  property double usageLastSampleMs: 0
  property int screenUsageRangeDays: 1
  property real sliderEffectPhase: 0
  property var microphoneSpectrumValues: []
  property bool microphoneSpectrumIdle: true
  property real microphoneSignalLevel: 0
  property var easyEffectsPresets: []
  property string activeEasyEffectsPreset: ""
  property bool easyEffectsAvailable: false
  property string easyEffectsStatus: ""
  readonly property var easyEffectsRunningCheckCommand: ["bash", "-c", "pgrep -x easyeffects >/dev/null || pgrep -f '(^|/)easyeffects($| )' >/dev/null"]
  readonly property bool audioDetailActive: activeDetailView === "audio"
  readonly property bool screenUsageDetailActive: activeDetailView === "screenUsage"
  readonly property bool recordStatusPolling: toolkitRecordState !== "" || lastRecordStatus === "selecting" || lastRecordStatus === "recording" || lastRecordStatus === "converting"
  readonly property bool microphoneSignalActive: AudioService.hasInput && !AudioService.inputMuted && !microphoneSpectrumIdle && microphoneSignalLevel > 0.035
  readonly property bool toolkitRecording: toolkitRecordState === "recording"
  readonly property string captureScriptPath: {
    const url = Qt.resolvedUrl("scripts/capture.sh").toString();
    return url.startsWith("file://") ? url.slice(7) : url;
  }
  readonly property string screenshotScriptPath: {
    const url = Qt.resolvedUrl("scripts/screenshot.sh").toString();
    return url.startsWith("file://") ? url.slice(7) : url;
  }

  anchors.fill: parent

  Component.onCompleted: {
    SystemStatService.registerComponent("raell-dashboard");
    if (root.needsPanelSpectrum)
      SpectrumService.registerComponent(root.panelSpectrumComponentId);
    root.resetScreenUsageTracker();
    root.pickRandomProfileCover();
  }

  Component.onDestruction: {
    root.sampleScreenUsage();
    root.saveScreenUsage();
    SystemStatService.unregisterComponent("raell-dashboard");
    SpectrumService.unregisterComponent(root.panelSpectrumComponentId);
  }

  onNeedsPanelSpectrumChanged: {
    if (root.needsPanelSpectrum)
      SpectrumService.registerComponent(root.panelSpectrumComponentId);
    else
      SpectrumService.unregisterComponent(root.panelSpectrumComponentId);
  }

  onActiveDetailViewChanged: {
    if (activeDetailView === "media")
      root.refreshEasyEffects();
  }

  onProfileCoverModeChanged: root.pickRandomProfileCover()
  onProfileCoverFolderChanged: root.pickRandomProfileCover()

  function tr(key) {
    return pluginApi?.tr("panel." + key);
  }

  function updateAvatar(path) {
    if (!pluginApi || !path || path.length === 0) {
      return;
    }
    pluginApi.pluginSettings.avatarPath = path;
    pluginApi.saveSettings();
  }

  function openDashboardSettings() {
    if (!pluginApi?.manifest) {
      return;
    }
    BarService.openPluginSettings(pluginApi?.panelOpenScreen, pluginApi.manifest);
  }

  function compositorName() {
    if (CompositorService.isHyprland)
      return "Hyprland";
    if (CompositorService.isNiri)
      return "Niri";
    if (CompositorService.isSway)
      return "Sway";
    if (CompositorService.isLabwc)
      return "Labwc";
    if (CompositorService.isMango)
      return "MangoWC";
    return "Wayland";
  }

  function formatBytes(value) {
    const n = Number(value || 0);
    if (n < 1024)
      return n.toFixed(0) + " B/s";
    if (n < 1024 * 1024)
      return (n / 1024).toFixed(1) + " KB/s";
    return (n / 1024 / 1024).toFixed(1) + " MB/s";
  }

  function formatGb(value, digits) {
    const n = Number(value || 0);
    return n.toFixed(digits ?? 1) + " GiB";
  }

  function percentText(value) {
    return Math.round(Number(value || 0)) + "%";
  }

  function pickRandomProfileCover() {
    if (root.profileCoverMode !== "random" || root.profileCoverFolder === "") {
      root.randomProfileCoverPath = "";
      return;
    }

    randomCoverProcess.exec({
                              command: ["bash", "-c", "dir=$1; find \"$dir\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | shuf -n 1", "raell-dashboard", Settings.preprocessPath(root.profileCoverFolder)]
                            });
  }

  function profileTextColor(strong) {
    return root.profileWallpaperPath !== "" ? "white" : (strong ? Color.mOnSurface : Color.mOnSurfaceVariant);
  }

  function profileCardRadius(width, height) {
    const shape = String(root.profileCardShape || "rounded");
    if (shape === "sharp")
      return Math.max(2, Math.round(4 * root.panelUnit));
    if (shape === "soft")
      return Math.round(Style.radiusS * root.panelUnit);
    if (shape === "pill")
      return Math.min(width, height) / 2;
    return Style.radiusM;
  }

  function innerProfileCardRadius(width, height) {
    return Math.max(0, root.profileCardRadius(width, height) - Math.max(1, Style.borderS));
  }

  function legacyProfileCoverBorderAnimation() {
    if (profileCoverBorderEffect === "pulse")
      return "pulse";
    if (profileCoverBorderEffect === "rainbow")
      return "flow";
    if (profileCoverBorderEffect === "reactive")
      return "reactivePulse";
    return "static";
  }

  function automaticProfileBorderColors() {
    if (profileCoverBorderEffect === "secondary")
      return [Color.mSecondary, Color.mTertiary, Color.mPrimary];
    return [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mPrimary];
  }

  function customProfileBorderColors() {
    const source = [
      root.profileCoverBorderColor1,
      root.profileCoverBorderColor2,
      root.profileCoverBorderColor3,
      root.profileCoverBorderColor4,
      root.profileCoverBorderColor5
    ];
    const count = root.clamp(root.profileCoverBorderColorCount, 3, 5);
    const colors = [];
    for (let i = 0; i < count; i++) {
      const value = String(source[i] || "").trim();
      colors.push(value !== "" ? value : Color.mPrimary);
    }
    return colors;
  }

  function profileBorderColors() {
    return root.profileCoverBorderColorMode === "custom" ? root.customProfileBorderColors() : root.automaticProfileBorderColors();
  }

  function profileBorderAnimationActive() {
    if (root.dashboardPerformanceMode)
      return false;
    if (root.profileCoverBorderAnimation.indexOf("reactive") === 0)
      return root.musicActive;
    return root.profileCoverBorderAnimation !== "static";
  }

  function profileBorderColor() {
    const colors = root.profileBorderColors();
    const speed = root.profileCoverBorderAnimation.indexOf("reactive") === 0 ? 0.55 : 0.18;
    const phase = root.profileBorderAnimationActive() ? root.sliderEffectPhase * speed * root.profileCoverBorderSpeed : 0;
    const index = Math.floor(Math.abs(phase)) % colors.length;
    return colors[index];
  }

  function componentStyle(componentKey) {
    const styles = root.componentStyles || {};
    const globalStyle = styles.__global || {};
    const localStyle = styles[componentKey] || {};
    const merged = {};
    root.mergeComponentStyle(merged, globalStyle);
    root.mergeComponentStyle(merged, localStyle);

    return merged;
  }

  function mergeComponentStyle(target, source) {
    if (!source)
      return;

    const colorFields = ["background", "text", "subtext", "accent", "buttonBackground", "buttonText"];
    if (source.enabled === true) {
      target.enabled = true;
      for (let i = 0; i < colorFields.length; i++) {
        const field = colorFields[i];
        if (source[field] !== undefined)
          target[field] = source[field];
      }
    }

    const borderFields = [
      "borderWidth",
      "borderScope",
      "borderColorMode",
      "borderColorCount",
      "borderColor1",
      "borderColor2",
      "borderColor3",
      "borderColor4",
      "borderColor5",
      "borderAnimation",
      "borderSpeed"
    ];
    if (source.borderEnabled === true) {
      target.borderEnabled = true;
      for (let i = 0; i < borderFields.length; i++) {
        const field = borderFields[i];
        if (source[field] !== undefined)
          target[field] = source[field];
      }
    }
  }

  function componentColor(componentKey, field, fallback) {
    const style = root.componentStyle(componentKey);
    if (!style || style.enabled !== true)
      return fallback;
    const value = String(style[field] || "").trim();
    return value !== "" ? value : fallback;
  }

  function componentBackground(componentKey) {
    return root.componentColor(componentKey, "background", Qt.alpha(Color.mSurfaceVariant, 0.82));
  }

  function componentText(componentKey, strong) {
    return root.componentColor(componentKey, strong ? "text" : "subtext", strong ? Color.mOnSurface : Color.mOnSurfaceVariant);
  }

  function componentAccent(componentKey) {
    return root.componentColor(componentKey, "accent", Color.mPrimary);
  }

  function componentButtonBackground(componentKey) {
    return root.componentColor(componentKey, "buttonBackground", Color.mPrimary);
  }

  function componentButtonText(componentKey) {
    return root.componentColor(componentKey, "buttonText", Color.mOnPrimary);
  }

  function inheritedStyleKey(item) {
    let current = item;
    while (current) {
      if ("styleKey" in current && current.styleKey !== "")
        return current.styleKey;
      current = current.parent;
    }
    return "";
  }

  function componentBorderEnabled(componentKey) {
    const style = root.componentStyle(componentKey);
    return style && style.borderEnabled === true;
  }

  function componentBorderAnimation(componentKey) {
    const style = root.componentStyle(componentKey);
    return String(style.borderAnimation || "static");
  }

  function anyComponentBorderAnimationActive() {
    if (root.dashboardPerformanceMode)
      return false;
    const styles = root.componentStyles || {};
    const keys = Object.keys(styles);
    for (let i = 0; i < keys.length; i++) {
      const style = styles[keys[i]] || {};
      const animation = String(style.borderAnimation || "static");
      if (style.borderEnabled === true && animation !== "static" && animation.indexOf("reactive") !== 0)
        return true;
      if (style.borderEnabled === true && animation.indexOf("reactive") === 0 && root.musicActive)
        return true;
    }
    return false;
  }

  function componentBorderSpeed(componentKey) {
    const style = root.componentStyle(componentKey);
    return Number(style.borderSpeed || 1);
  }

  function componentBorderScope(componentKey) {
    const style = root.componentStyle(componentKey);
    const value = String(style.borderScope || "all");
    return value === "container" || value === "children" ? value : "all";
  }

  function componentBorderVisible(componentKey, styleRoot) {
    if (root.dashboardPerformanceMode)
      return false;
    if (!root.componentBorderEnabled(componentKey))
      return false;
    const scope = root.componentBorderScope(componentKey);
    if (scope === "container")
      return styleRoot === true;
    if (scope === "children")
      return styleRoot !== true;
    return true;
  }

  function componentBorderWidth(componentKey) {
    const style = root.componentStyle(componentKey);
    return Number(style.borderWidth || 2);
  }

  function componentBorderColors(componentKey) {
    const style = root.componentStyle(componentKey);
    if (!style)
      return [Color.mPrimary, Color.mSecondary, Color.mTertiary];

    if (String(style.borderColorMode || "auto") !== "custom")
      return [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError];

    const source = [
      style.borderColor1,
      style.borderColor2,
      style.borderColor3,
      style.borderColor4,
      style.borderColor5
    ];
    const count = root.clamp(Number(style.borderColorCount || 3), 3, 5);
    const colors = [];
    for (let i = 0; i < count; i++) {
      const value = String(source[i] || "").trim();
      colors.push(value !== "" ? value : root.componentAccent(componentKey));
    }
    return colors;
  }

  function dateKey(date) {
    const d = date || new Date();
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return year + "-" + month + "-" + day;
  }

  function durationText(seconds) {
    const total = Math.max(0, Math.round(Number(seconds || 0)));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    if (hours > 0)
      return hours + "h " + String(minutes).padStart(2, "0") + "m";
    if (minutes > 0)
      return minutes + "m";
    return total + "s";
  }

  function focusedUsageApp() {
    const window = CompositorService.getFocusedWindow();
    if (!window)
      return null;

    const rawId = String(window.appId || "").trim();
    const title = String(window.title || "").replace(/(\r\n|\n|\r)/g, "").trim();
    const appId = rawId !== "" ? rawId.toLowerCase() : (title !== "" ? title.toLowerCase() : "");
    if (appId === "")
      return null;
    if (root.isScreenUsageExcludedApp(appId))
      return null;

    return {
      "id": appId,
      "name": CompositorService.getCleanAppName(rawId, title),
      "title": title
    };
  }

  function isScreenUsageExcludedApp(appId) {
    const id = String(appId || "").toLowerCase();
    if (id === "" || id === "unknown")
      return true;
    if (id.indexOf("dev.noctalia.") === 0 || id === "noctalia" || id.indexOf("quickshell") >= 0)
      return true;

    const compact = id.replace(/[._\\-\\s]/g, "");
    const patterns = ["xdg-desktop-portal", "xdgdesktopportal", "org.freedesktop.portal", "org.freedesktop.policykit", "polkit", "gcr-prompter", "kwallet", "zenity"];
    for (let i = 0; i < patterns.length; i++) {
      const pattern = patterns[i];
      if (id.indexOf(pattern) >= 0 || compact.indexOf(pattern.replace(/[._\\-\\s]/g, "")) >= 0)
        return true;
    }
    return false;
  }

  function resetScreenUsageTracker() {
    const app = root.focusedUsageApp();
    root.usageCurrentAppId = app ? app.id : "";
    root.usageCurrentAppName = app ? app.name : "";
    root.usageCurrentAppTitle = app ? app.title : "";
    root.usageLastSampleMs = Date.now();
  }

  function sampleScreenUsage() {
    const now = Date.now();
    const elapsed = root.usageLastSampleMs > 0 ? Math.round((now - root.usageLastSampleMs) / 1000) : 0;

    if (elapsed > 0 && elapsed <= 300 && root.usageCurrentAppId !== "")
      root.addScreenUsage(root.usageCurrentAppId, root.usageCurrentAppName, root.usageCurrentAppTitle, elapsed);

    const app = root.focusedUsageApp();
    root.usageCurrentAppId = app ? app.id : "";
    root.usageCurrentAppName = app ? app.name : "";
    root.usageCurrentAppTitle = app ? app.title : "";
    root.usageLastSampleMs = now;
  }

  function addScreenUsage(appId, appName, appTitle, seconds) {
    const key = root.dateKey(new Date());
    const days = Object.assign({}, root.screenUsageDays || {});
    const day = Object.assign({
                                "total": 0,
                                "apps": {}
                              }, days[key] || {});
    const apps = Object.assign({}, day.apps || {});
    const hourly = (day.hourly || new Array(24).fill(0)).slice(0, 24);
    while (hourly.length < 24)
      hourly.push(0);
    const appHourly = Object.assign({}, day.appHourly || {});
    const appBuckets = (appHourly[appId] || new Array(24).fill(0)).slice(0, 24);
    while (appBuckets.length < 24)
      appBuckets.push(0);
    const app = Object.assign({
                                "name": appName || appId,
                                "title": appTitle || "",
                                "seconds": 0
                              }, apps[appId] || {});

    app.name = appName || app.name || appId;
    app.title = appTitle || app.title || "";
    app.seconds = Math.max(0, Math.round(Number(app.seconds || 0) + Number(seconds || 0)));
    apps[appId] = app;
    const hour = new Date().getHours();
    hourly[hour] = Math.max(0, Math.round(Number(hourly[hour] || 0) + Number(seconds || 0)));
    appBuckets[hour] = Math.max(0, Math.round(Number(appBuckets[hour] || 0) + Number(seconds || 0)));
    appHourly[appId] = appBuckets;
    day.apps = apps;
    day.hourly = hourly;
    day.appHourly = appHourly;
    day.total = Math.max(0, Math.round(Number(day.total || 0) + Number(seconds || 0)));
    days[key] = day;
    root.screenUsageDays = root.prunedScreenUsageDays(days);
    screenUsageSaveTimer.restart();
  }

  function prunedScreenUsageDays(days) {
    const entries = Object.keys(days || {}).sort();
    while (entries.length > 14) {
      const key = entries.shift();
      delete days[key];
    }
    return days;
  }

  function screenUsageDay(key) {
    const days = root.screenUsageDays || {};
    return days[key || root.dateKey(new Date())] || {
      "total": 0,
      "apps": {}
    };
  }

  function screenUsageTodayTotal() {
    return root.screenUsageDay(root.dateKey(new Date())).total || 0;
  }

  function screenUsageTotalForRange(rangeDays) {
    const days = Math.max(1, Math.min(14, Number(rangeDays || 1)));
    let total = 0;
    for (let i = 0; i < days; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      total += Number(root.screenUsageDay(root.dateKey(date)).total || 0);
    }
    return total;
  }

  function screenUsageMergedApps(rangeDays) {
    const days = Math.max(1, Math.min(14, Number(rangeDays || 1)));
    const merged = {};
    for (let i = 0; i < days; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const apps = root.screenUsageDay(root.dateKey(date)).apps || {};
      for (const appId in apps) {
        if (root.isScreenUsageExcludedApp(appId))
          continue;
        const source = apps[appId];
        const current = merged[appId] || {
          "id": appId,
          "name": source.name || appId,
          "title": source.title || "",
          "seconds": 0
        };
        current.seconds += Number(source.seconds || 0);
        current.name = source.name || current.name;
        current.title = source.title || current.title;
        merged[appId] = current;
      }
    }
    return merged;
  }

  function screenUsageTopApps(limit, rangeDays) {
    const apps = root.screenUsageMergedApps(rangeDays || 1);
    const rows = [];
    for (const appId in apps) {
      const app = apps[appId];
      rows.push({
                  "id": appId,
                  "name": app.name || appId,
                  "title": app.title || "",
                  "seconds": Number(app.seconds || 0)
                });
    }
    rows.sort((a, b) => b.seconds - a.seconds);
    return limit === undefined || limit < 0 ? rows : rows.slice(0, limit);
  }

  function screenUsageWeekModel() {
    const rows = [];
    let maxSeconds = 1;
    for (let i = 6; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const total = Number(root.screenUsageDay(root.dateKey(date)).total || 0);
      maxSeconds = Math.max(maxSeconds, total);
      rows.push({
                  "label": I18n.locale.dayName(date.getDay(), Locale.ShortFormat).substring(0, 3),
                  "seconds": total
                });
    }
    for (let j = 0; j < rows.length; j++)
      rows[j].ratio = Math.max(0.08, rows[j].seconds / maxSeconds);
    return rows;
  }

  function screenUsageMaxAppSeconds(apps) {
    let maxSeconds = 1;
    for (let i = 0; i < apps.length; i++)
      maxSeconds = Math.max(maxSeconds, Number(apps[i].seconds || 0));
    return maxSeconds;
  }

  function saveScreenUsage() {
    try {
      var dir = root.screenUsageDirPath;
      var file = root.screenUsageFilePath;
      var dataStr = JSON.stringify({ "days": root.screenUsageDays }, null, 2);
      Quickshell.execDetached(["bash", "-c", "mkdir -p " + dir + " && cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch(e) {
      Logger.e("ControlCenterPanel", "Failed to save screen usage:", e);
    }
  }

  function nodeLabel(node) {
    if (!node)
      return "--";
    const props = node.properties || {};
    return props["node.nick"] || props["node.description"] || props["media.name"] || props["application.name"] || node.description || node.name || "--";
  }

  function nodeKey(node) {
    if (!node)
      return "";
    if (node.id !== undefined && node.id !== null)
      return String(node.id);
    return node.name || root.nodeLabel(node);
  }

  function bluetoothDeviceName(device) {
    if (!device)
      return I18n.tr("common.bluetooth");
    return device.name || device.deviceName || device.alias || I18n.tr("common.unknown");
  }

  function bluetoothBatteryText(device) {
    if (!device || !device.batteryAvailable)
      return "-";
    const battery = BluetoothService.getBatteryPercent(device);
    return battery === null ? "-" : battery + "%";
  }

  function bluetoothDetailText() {
    if (!BluetoothService.bluetoothAvailable)
      return I18n.tr("common.not-found");
    if (!BluetoothService.enabled)
      return I18n.tr("common.disabled");

    const devices = BluetoothService.connectedDevices || [];
    if (devices.length === 0)
      return root.tr("openPanel");

    const firstName = root.bluetoothDeviceName(devices[0]);
    return devices.length === 1 ? firstName : firstName + " +" + (devices.length - 1);
  }

  function bluetoothTooltipRows() {
    if (!BluetoothService.bluetoothAvailable)
      return [[I18n.tr("common.bluetooth"), I18n.tr("common.not-found")]];
    if (!BluetoothService.enabled)
      return [[I18n.tr("common.bluetooth"), I18n.tr("common.disabled")]];

    const devices = BluetoothService.connectedDevices || [];
    if (devices.length === 0)
      return [[I18n.tr("bluetooth.panel.connected-devices"), I18n.tr("common.none")]];

    const rows = [[I18n.tr("bluetooth.panel.connected-devices"), String(devices.length)]];
    const maxDevices = Math.min(devices.length, 2);
    for (let i = 0; i < maxDevices; i++) {
      const device = devices[i];
      rows.push([root.bluetoothDeviceName(device), BluetoothService.getSignalStrength(device)]);
      rows.push([I18n.tr("common.battery"), root.bluetoothBatteryText(device)]);
      rows.push([I18n.tr("common.paired"), device.paired ? I18n.tr("common.yes") : I18n.tr("common.no")]);
      rows.push([I18n.tr("common.trusted"), device.trusted ? I18n.tr("common.yes") : I18n.tr("common.no")]);
      if (device.address)
        rows.push([I18n.tr("bluetooth.panel.device-address"), device.address]);
    }
    if (devices.length > maxDevices)
      rows.push(["+", String(devices.length - maxDevices)]);
    return rows;
  }

  function audioDeviceOptions(nodes) {
    const options = [];
    if (!nodes)
      return options;
    const count = nodes.length !== undefined ? nodes.length : nodes.count ?? 0;
    for (let i = 0; i < count; i++) {
      const node = nodes.get ? nodes.get(i) : nodes[i];
      if (node) {
        options.push({
                       "key": root.nodeKey(node),
                       "name": root.nodeLabel(node)
                     });
      }
    }
    return options;
  }

  function audioNodeByKey(nodes, key) {
    if (!nodes || key === "")
      return null;
    const count = nodes.length !== undefined ? nodes.length : nodes.count ?? 0;
    for (let i = 0; i < count; i++) {
      const node = nodes.get ? nodes.get(i) : nodes[i];
      if (node && root.nodeKey(node) === key)
        return node;
    }
    return null;
  }

  function playerLabel(player) {
    if (!player)
      return "--";
    return player.identity || player.desktopEntry || root.tr("player");
  }

  function mediaProgressRatio() {
    if (!MediaService.currentPlayer || MediaService.trackLength <= 0)
      return 0;
    const ratio = MediaService.currentPosition / MediaService.trackLength;
    if (isNaN(ratio) || !isFinite(ratio))
      return 0;
    return root.clamp(ratio, 0, 1);
  }

  function weatherTemperature(value) {
    if (value === undefined || value === null || isNaN(Number(value)))
      return "--";
    let temp = Number(value);
    let suffix = "C";
    if (Settings.data.location.useFahrenheit) {
      temp = LocationService.celsiusToFahrenheit(temp);
      suffix = "F";
    }
    return Math.round(temp) + "°" + suffix;
  }

  function weatherDayLabel(dateText) {
    if (!dateText)
      return "--";
    const date = new Date(String(dateText).replace(/-/g, "/"));
    return I18n.locale.toString(date, "ddd");
  }

  function weatherTimeLabel(dateText) {
    if (!dateText)
      return "--";
    const date = new Date(String(dateText).replace(/-/g, "/"));
    const format = Settings.data.location.use12hourFormat ? "hh:mm AP" : "HH:mm";
    return I18n.locale.toString(date, format);
  }

  function primaryDiskPercent() {
    const path = Settings.data.controlCenter.diskPath || "/";
    if (SystemStatService.diskPercents[path] !== undefined)
      return SystemStatService.diskPercents[path];
    const keys = Object.keys(SystemStatService.diskPercents);
    return keys.length > 0 ? SystemStatService.diskPercents[keys[0]] : 0;
  }

  function diskPaths() {
    const all = Object.keys(SystemStatService.diskPercents || {});
    const useful = all.filter(path => {
                                const size = Number(SystemStatService.diskSizeGb[path] || 0);
                                if (size > 0 && size < 2)
                                  return false;
                                if (path === "/" || path === "/home")
                                  return true;
                                if (path.startsWith("/run/media/") || path.startsWith("/media/") || path.startsWith("/mnt/"))
                                  return true;
                                if (path === "/boot" || path.startsWith("/boot/") || path === "/efi" || path.startsWith("/efi/"))
                                  return false;
                                if (path === "/tmp" || path.startsWith("/tmp/") || path === "/var/tmp" || path.startsWith("/var/tmp/"))
                                  return false;
                                if (path.startsWith("/run") || path.startsWith("/dev") || path.startsWith("/proc") || path.startsWith("/sys"))
                                  return false;

                                const parts = path.split("/").filter(part => part.length > 0);
                                const reservedTopLevel = ["bin", "etc", "nix", "opt", "root", "srv", "usr", "var"];
                                return parts.length === 1 && !reservedTopLevel.includes(parts[0]);
                              });
    const paths = useful.length > 0 ? useful : all;
    const preferred = Settings.data.controlCenter.diskPath || "/";
    paths.sort((a, b) => {
                 if (a === preferred)
                   return -1;
                 if (b === preferred)
                   return 1;
                 if (a === "/")
                   return -1;
                 if (b === "/")
                   return 1;
                 return a.localeCompare(b);
               });
    return paths;
  }

  function diskPathAt(index) {
    const paths = diskPaths();
    if (paths.length === 0)
      return "/";
    return paths[root.clamp(index, 0, paths.length - 1)];
  }

  function diskLabel(path) {
    if (!path || path === "/")
      return root.tr("disk");
    const parts = path.split("/").filter(part => part.length > 0);
    return parts.length > 0 ? parts[parts.length - 1] : path;
  }

  function currentBrightness() {
    const monitors = BrightnessService.monitors || [];
    if (monitors.length === 0)
      return 0;
    return monitors[0].brightness || 0;
  }

  function gpuUsagePercent() {
    const serviceUsage = Number(SystemStatService.gpuUsage);
    if (!isNaN(serviceUsage) && isFinite(serviceUsage))
      return root.clamp(serviceUsage, 0, 100);
    return root.localGpuUsage >= 0 ? root.clamp(root.localGpuUsage, 0, 100) : -1;
  }

  function gpuUsageRatio() {
    const usage = root.gpuUsagePercent();
    return usage >= 0 ? usage / 100 : 0;
  }

  function gpuUsageText() {
    const usage = root.gpuUsagePercent();
    return usage >= 0 ? root.percentText(usage) : "--";
  }

  function gpuTemperatureText() {
    if (!SystemStatService.gpuAvailable)
      return "--";
    return Math.round(SystemStatService.gpuTemp) + "°C";
  }

  function gpuCompactText() {
    if (!SystemStatService.gpuAvailable)
      return "--";
    const usage = root.gpuUsageText();
    const temp = root.gpuTemperatureText();
    if (usage === "--")
      return temp;
    return usage + " · " + temp;
  }

  function gpuNameText() {
    if (!SystemStatService.gpuAvailable)
      return root.tr("disabled");
    if (root.localGpuName !== "")
      return root.localGpuName;
    if (SystemStatService.gpuType === "nvidia")
      return "NVIDIA GPU";
    if (SystemStatService.gpuType === "amd")
      return "AMD GPU";
    if (SystemStatService.gpuType === "intel")
      return "Intel GPU";
    return SystemStatService.gpuType || root.tr("enabled");
  }

  function gpuUsageFilePath() {
    if (!SystemStatService.gpuAvailable)
      return "";
    const hwmonPath = SystemStatService.gpuTempHwmonPath || "";
    const devicePath = hwmonPath !== "" ? hwmonPath + "/device" : "";

    if (SystemStatService.gpuType === "amd" && devicePath !== "")
      return devicePath + "/gpu_busy_percent";
    if (SystemStatService.gpuType === "intel" && devicePath !== "")
      return devicePath + "/gt/gt0/busy_percent";
    return "";
  }

  function activePanelScreen() {
    return pluginApi?.panelOpenScreen || activeScreen;
  }

  function toggleNativePanel(panelName) {
    const panel = PanelService.getPanel(panelName, activePanelScreen());
    panel?.toggle(null);
  }

  function closeDashboardPanel() {
    if (PanelService.openedPanel && !PanelService.openedPanel.isClosing) {
      PanelService.openedPanel.close();
    }
  }

  function runNoctaliaIpc(target, action, args, closeFirst) {
    const command = ["qs", "-c", "noctalia-shell", "ipc", "call", target, action];
    const extraArgs = args || [];
    for (let i = 0; i < extraArgs.length; i++) {
      command.push(String(extraArgs[i]));
    }

    if (closeFirst === false) {
      Quickshell.execDetached(command);
      return;
    }

    pendingIpcCommand = command;
    closeDashboardPanel();
    deferredIpcTimer.restart();
  }

  function showCaptureNotice(message, detail, icon) {
    const body = detail && String(detail).length > 0 ? message + "\n" + detail : message;
    ToastService.showNotice(root.tr("screenTools"), body, icon || "camera", 3000);
  }

  function showCaptureError(message) {
    ToastService.showError(root.tr("screenTools"), message, 3000);
  }

  function openWallpaperSelector() {
    root.pendingNativePanelName = "wallpaperPanel";
    root.closeDashboardPanel();
    deferredNativePanelTimer.restart();
  }

  function takeDashboardScreenshot(mode) {
    root.pendingScreenshotMode = mode;
    root.pendingCaptureAction = "screenshot";
    root.closeDashboardPanel();
    deferredCaptureTimer.restart();
  }

  function startDashboardRecording(format) {
    if (root.toolkitRecordState !== "" || root.lastRecordStatus === "selecting" || root.lastRecordStatus === "recording" || root.lastRecordStatus === "converting")
      return;

    root.pendingRecordFormat = format === "mp4" ? "mp4" : "gif";
    root.pendingCaptureAction = "record-area";
    root.closeDashboardPanel();
    deferredCaptureTimer.restart();
  }

  function stopDashboardRecording() {
    if (!root.toolkitRecording)
      return;

    Quickshell.execDetached(["bash", root.captureScriptPath, "stop"]);
    root.toolkitRecordState = "converting";
  }

  function runPendingScreenshot() {
    Quickshell.execDetached(["bash", root.screenshotScriptPath, root.pendingScreenshotMode]);
  }

  function parseNotificationActions(actions) {
    try {
      const parsed = JSON.parse(actions || "[]");
      return parsed.filter(action => (action.identifier || "").length > 0);
    } catch (e) {
      return [];
    }
  }

  function notificationCanExpand(notificationData) {
    return String(notificationData.body || "").length > 0 || parseNotificationActions(notificationData.actionsJson).length > 0;
  }

  function activateNotification(notificationData) {
    const actions = parseNotificationActions(notificationData.actionsJson);
    const hasDefault = actions.some(action => action.identifier === "default");
    if (hasDefault && NotificationService.invokeAction(notificationData.id, "default"))
      return;
    NotificationService.focusSenderWindow(notificationData.appName || "");
  }

  function notificationTimeText(timestamp) {
    if (!timestamp)
      return "";
    return Time.formatRelativeTime(timestamp);
  }

  function clamp(value, minValue, maxValue) {
    return Math.max(minValue, Math.min(maxValue, value));
  }

  function spectrumSignal(values) {
    if (!values || values.length === undefined || values.length === 0)
      return 0;
    let peak = 0;
    let total = 0;
    for (let i = 0; i < values.length; i++) {
      const value = root.clamp(Number(values[i] || 0), 0, 1);
      peak = Math.max(peak, value);
      total += value;
    }
    const average = total / values.length;
    return root.clamp(peak * 0.68 + average * 0.32, 0, 1);
  }

  function spectrumAverage() {
    return root.spectrumSignal(SpectrumService.values);
  }

  function parseEasyEffectsPresets(text) {
    const lines = String(text || "").split("\n");
    const presets = [];
    let inOutputSection = false;
    let sawSection = false;

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i].trim();
      if (line === "")
        continue;

      const lower = line.toLowerCase();
      if (lower.indexOf("no output presets") >= 0)
        return [];
      if (lower.indexOf("output") >= 0 && lower.indexOf("preset") >= 0) {
        inOutputSection = true;
        sawSection = true;
        continue;
      }
      if (lower.indexOf("input") >= 0 && lower.indexOf("preset") >= 0) {
        inOutputSection = false;
        sawSection = true;
        continue;
      }
      if (sawSection && !inOutputSection)
        continue;

      line = line.replace(/^\d+\s+/, "").replace(/^[-*]+\s*/, "");
      if (line !== "" && presets.indexOf(line) === -1)
        presets.push(line);
    }

    return presets;
  }

  function parseEasyEffectsActivePreset(text) {
    const lines = String(text || "").split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line === "")
        continue;
      const lower = line.toLowerCase();
      if (lower.indexOf("output:") === 0)
        return line.slice(line.indexOf(":") + 1).trim();
      return line;
    }
    return "";
  }

  function easyEffectsPresetOptions() {
    const options = [];
    const presets = root.easyEffectsPresets || [];
    for (let i = 0; i < presets.length; i++) {
      const preset = String(presets[i] || "");
      if (preset !== "") {
        options.push({
                       "key": preset,
                       "name": preset
                     });
      }
    }
    return options;
  }

  function refreshEasyEffects() {
    if (!easyEffectsStateProcess.running)
      easyEffectsStateProcess.exec({ command: root.easyEffectsRunningCheckCommand });
  }

  function applyEasyEffectsPreset(preset) {
    if (!root.easyEffectsAvailable || !preset || preset === "")
      return;
    root.activeEasyEffectsPreset = preset;
    root.easyEffectsStatus = root.tr("easyEffectsApplying");
    Quickshell.execDetached(["easyeffects", "--load-preset", preset]);
    easyEffectsRefreshTimer.restart();
  }

  function equalizerBandLevel(index, count) {
    const values = SpectrumService.values || [];
    const length = values.length || 0;
    if (length === 0)
      return 0.18 + ((index % 3) * 0.08);

    const start = Math.floor(index * length / count);
    const end = Math.max(start + 1, Math.floor((index + 1) * length / count));
    let peak = 0;
    let total = 0;
    let samples = 0;
    for (let i = start; i < Math.min(end, length); i++) {
      const value = root.clamp(Number(values[i] || 0), 0, 1);
      peak = Math.max(peak, value);
      total += value;
      samples++;
    }
    const average = samples > 0 ? total / samples : 0;
    const signal = root.clamp(peak * 0.72 + average * 0.28, 0, 1);
    return root.musicActive ? root.clamp(0.16 + signal * 0.84, 0.12, 1) : 0.22;
  }

  Timer {
    id: deferredIpcTimer
    interval: 180
    repeat: false
    onTriggered: {
      if (root.pendingIpcCommand.length > 0) {
        Quickshell.execDetached(root.pendingIpcCommand);
        root.pendingIpcCommand = [];
      }
    }
  }

  Timer {
    interval: 50
    running: !root.dashboardPerformanceMode && (root.musicActive || root.microphoneSignalActive || (root.profileCoverBorder && root.profileBorderAnimationActive()) || root.anyComponentBorderAnimationActive())
    repeat: true
    onTriggered: root.sliderEffectPhase += 0.16
  }

  PwAudioSpectrum {
    id: microphoneSpectrum
    node: Pipewire.defaultAudioSource
    enabled: root.audioDetailActive && AudioService.hasInput && !AudioService.inputMuted
    frameRate: Settings.data.audio.spectrumFrameRate
    lowerCutoff: 80
    upperCutoff: 8000
    noiseReduction: 0.84
    smoothing: true

    onValuesChanged: {
      root.microphoneSpectrumValues = microphoneSpectrum.values;
      root.microphoneSignalLevel = microphoneSpectrum.idle ? 0 : root.spectrumSignal(microphoneSpectrum.values);
    }

    onIdleChanged: {
      root.microphoneSpectrumIdle = microphoneSpectrum.idle;
      if (microphoneSpectrum.idle)
        root.microphoneSignalLevel = 0;
    }
  }

  Timer {
    id: deferredNativePanelTimer
    interval: 180
    repeat: false
    onTriggered: {
      if (root.pendingNativePanelName.length > 0) {
        root.toggleNativePanel(root.pendingNativePanelName);
        root.pendingNativePanelName = "";
      }
    }
  }

  Timer {
    id: deferredCaptureTimer
    interval: 220
    repeat: false
    onTriggered: {
      if (root.pendingCaptureAction === "screenshot") {
        root.runPendingScreenshot();
      } else if (root.pendingCaptureAction === "record-area") {
        root.toolkitRecordState = "selecting";
        Quickshell.execDetached(["bash", root.captureScriptPath, "start", root.pendingRecordFormat]);
      }
      root.pendingCaptureAction = "";
    }
  }

  Timer {
    interval: 700
    repeat: true
    running: root.recordStatusPolling
    triggeredOnStart: true
    onTriggered: {
      if (!recordStatusProcess.running)
        recordStatusProcess.exec({ command: ["bash", root.captureScriptPath, "status"] });
    }
  }

  Process {
    id: recordStatusProcess
    stdout: StdioCollector {}
    onExited: code => {
      if (code !== 0)
        return;

      const text = String(stdout.text || "").trim();
      const parts = text.split("|");
      const state = parts[0] || "";
      const outputPath = parts[1] || "";
      const format = parts[2] || "";
      const changed = state !== root.lastRecordStatus || outputPath !== root.lastRecordOutputPath;

      if (changed && state === "done") {
        root.showCaptureNotice(root.tr("captureSaved"), outputPath, format === "mp4" ? "video" : "movie");
      } else if (changed && state === "failed") {
        root.showCaptureError(root.tr("captureFailed"));
      }

      root.toolkitRecordState = (state === "recording" || state === "converting") ? state : "";
      root.lastRecordStatus = state;
      root.lastRecordOutputPath = outputPath;
      root.lastRecordFormat = format;
    }
  }

  Timer {
    interval: SystemStatService.gpuIntervalMs || 5000
    repeat: true
    running: root.visible && SystemStatService.gpuAvailable
    triggeredOnStart: true
    onTriggered: {
      if (SystemStatService.gpuUsage !== undefined)
        return;

      if (SystemStatService.gpuType === "nvidia") {
        if (!gpuUsageNvidiaProcess.running)
          gpuUsageNvidiaProcess.running = true;
        return;
      }

      const path = root.gpuUsageFilePath();
      if (path !== "") {
        gpuUsageFile.path = path;
        gpuUsageFile.reload();
      }
    }
  }

  FileView {
    id: gpuUsageFile
    printErrors: false
    onLoaded: {
      const value = Number(text().trim());
      root.localGpuUsage = !isNaN(value) && isFinite(value) ? root.clamp(value, 0, 100) : -1;
    }
    onLoadFailed: function (error) {
      root.localGpuUsage = -1;
    }
  }

  Process {
    id: gpuUsageNvidiaProcess
    command: ["nvidia-smi", "--query-gpu=name,utilization.gpu", "--format=csv,noheader,nounits"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const line = text.trim().split("\n")[0] || "";
        const parts = line.split(",");
        if (parts.length > 1)
          root.localGpuName = parts[0].trim();
        const rawValue = parts.length > 1 ? parts[1] : parts[0];
        const value = Number(String(rawValue || "").trim());
        root.localGpuUsage = !isNaN(value) && isFinite(value) ? root.clamp(value, 0, 100) : -1;
      }
    }
  }

  Process {
    id: randomCoverProcess
    stdout: StdioCollector {}
    onExited: code => {
      if (code !== 0) {
        root.randomProfileCoverPath = "";
        return;
      }
      root.randomProfileCoverPath = String(stdout.text || "").trim();
    }
  }

  Timer {
    id: easyEffectsRefreshTimer
    interval: 900
    repeat: false
    onTriggered: root.refreshEasyEffects()
  }

  Process {
    id: easyEffectsStateProcess
    onExited: code => {
      root.easyEffectsAvailable = code === 0;
      if (code !== 0) {
        root.easyEffectsPresets = [];
        root.activeEasyEffectsPreset = "";
        root.easyEffectsStatus = root.tr("easyEffectsInactive");
        return;
      }

      root.easyEffectsStatus = "";
      if (!easyEffectsPresetsProcess.running)
        easyEffectsPresetsProcess.exec({ command: ["easyeffects", "--presets"] });
      if (!easyEffectsActiveProcess.running)
        easyEffectsActiveProcess.exec({ command: ["easyeffects", "--last-loaded-preset", "output"] });
    }
  }

  Process {
    id: easyEffectsPresetsProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: code => {
      root.easyEffectsAvailable = code === 0;
      if (code !== 0) {
        root.easyEffectsStatus = root.tr("easyEffectsUnavailable");
        return;
      }

      root.easyEffectsPresets = root.parseEasyEffectsPresets(stdout.text);
      root.easyEffectsStatus = root.easyEffectsPresets.length > 0 ? "" : root.tr("easyEffectsNoPresets");
    }
  }

  Process {
    id: easyEffectsActiveProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: code => {
      if (code !== 0)
        return;
      root.activeEasyEffectsPreset = root.parseEasyEffectsActivePreset(stdout.text);
    }
  }

  Process {
    id: screenUsageInitProcess
    running: true
    command: ["bash", "-c", "mkdir -p '" + root.screenUsageDirPath + "' && if [ ! -f '" + root.screenUsageFilePath + "' ]; then printf '{\"days\":{}}' > '" + root.screenUsageFilePath + "'; fi"]
    onExited: code => {
      if (code === 0)
        screenUsageFileView.reload();
    }
  }

  FileView {
    id: screenUsageFileView
    path: root.screenUsageFilePath
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text());
        if (parsed && parsed.days) {
          root.screenUsageDays = parsed.days;
        }
      } catch(e) {}
    }
    onLoadFailed: error => {
      if (!screenUsageInitProcess.running)
        screenUsageInitProcess.running = true;
    }
  }

  Timer {
    id: screenUsageSampleTimer
    interval: root.screenUsageDetailActive ? 5000 : 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.sampleScreenUsage()
  }

  Timer {
    id: screenUsageSaveTimer
    interval: 1200
    repeat: false
    onTriggered: root.saveScreenUsage()
  }

  Connections {
    target: CompositorService
    function onActiveWindowChanged() {
      root.sampleScreenUsage();
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    clip: true

    Flickable {
      id: contentFlick
      anchors.fill: parent
      contentWidth: Math.max(width, dashboardLayout.implicitWidth + Style.margin2L)
      contentHeight: Math.max(height, dashboardLayout.implicitHeight + Style.margin2L)
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      RowLayout {
        id: dashboardLayout
        x: Style.marginL
        y: Style.marginL
        width: Math.max(contentFlick.width - Style.margin2L, implicitWidth)
        height: Math.max(contentFlick.height - Style.margin2L, implicitHeight)
        spacing: Style.marginL

        ColumnLayout {
          Layout.preferredWidth: Math.round(300 * root.panelUnit)
          Layout.fillHeight: true
          spacing: Style.marginL

          ProfileCard {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(132 * root.panelUnit)
          }

          QuickActionsCard {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(332 * root.panelUnit)
          }

          RecordingCard {
            visible: root.cfg.showRecordingCard ?? root.defaults.showRecordingCard ?? true
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round((root.toolkitRecording ? 194 : 164) * root.panelUnit)

            Behavior on Layout.preferredHeight {
              NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
            }
          }
        }

        ColumnLayout {
          Layout.preferredWidth: Math.round(386 * root.panelUnit)
          Layout.fillHeight: true
          spacing: Style.marginL

          PerformanceCard {
            visible: !root.centerDetailOpen
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(388 * root.panelUnit)
          }

          SystemControlsCard {
            visible: !root.centerDetailOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          PerformanceDetailsCard {
            visible: root.activeDetailView === "performance"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          AudioDetailsCard {
            visible: root.activeDetailView === "audio"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }
        }

        ColumnLayout {
          Layout.preferredWidth: Math.round(392 * root.panelUnit)
          Layout.fillHeight: true
          spacing: Style.marginL

          NotificationsCard {
            visible: !root.rightDetailOpen && (root.cfg.showNotifications ?? root.defaults.showNotifications ?? true)
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(272 * root.panelUnit)
          }

          MediaCard {
            visible: !root.rightDetailOpen && (root.cfg.showMedia ?? root.defaults.showMedia ?? true)
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.round(132 * root.panelUnit) : 0
          }

          CalendarShell {
            visible: !root.rightDetailOpen && (root.cfg.showCalendar ?? root.defaults.showCalendar ?? true)
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          MediaDetailsCard {
            visible: root.activeDetailView === "media"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          NotificationsDetailsCard {
            visible: root.activeDetailView === "notifications"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          WeatherDetailsCard {
            visible: root.activeDetailView === "weather"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          CalendarDetailsCard {
            visible: root.activeDetailView === "calendar"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          ScreenUsageDetailsCard {
            visible: root.activeDetailView === "screenUsage"
            Layout.fillWidth: true
            Layout.fillHeight: true
          }
        }
      }
    }
  }

  NFilePicker {
    id: avatarPicker
    title: root.tr("changeAvatar")
    initialPath: Quickshell.env("HOME") || "/home"
    nameFilters: ["*.gif", "*.png", "*.jpg", "*.jpeg", "*.webp"]
    onAccepted: paths => {
      if (paths && paths.length > 0) {
        root.updateAvatar(paths[0]);
      }
    }
  }

  component DashboardCard: NBox {
    id: dashboardCard

    property string styleKey: root.inheritedStyleKey(parent)
    property bool styleRoot: false
    property bool detailTransition: false
    property string detailTransitionDirection: "right"
    property real detailOffset: 0
    readonly property bool borderEffectVisible: root.componentBorderVisible(styleKey, styleRoot)

    color: styleKey !== "" ? root.componentBackground(styleKey) : Qt.alpha(Color.mSurfaceVariant, 0.82)
    radius: Style.radiusM
    border.color: borderEffectVisible ? Qt.alpha(root.componentAccent(styleKey), 0.42) : Qt.alpha(Color.mOutline, 0.16)
    border.width: borderEffectVisible ? Math.max(1, Style.borderS) : Style.borderS

    transform: Translate {
      x: dashboardCard.detailOffset
    }

    onVisibleChanged: {
      if (visible && detailTransition && !root.dashboardPerformanceMode) {
        detailEnterAnimation.restart();
      } else if (visible && detailTransition) {
        opacity = 1;
        scale = 1;
        detailOffset = 0;
      }
    }

    ParallelAnimation {
      id: detailEnterAnimation

      NumberAnimation {
        target: dashboardCard
        property: "opacity"
        from: 0
        to: 1
        duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: dashboardCard
        property: "scale"
        from: 0.985
        to: 1
        duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: dashboardCard
        property: "detailOffset"
        from: dashboardCard.detailTransitionDirection === "left" ? -Math.round(22 * root.panelUnit) : Math.round(22 * root.panelUnit)
        to: 0
        duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    ComponentBorderCanvas {
      anchors.fill: parent
      styleKey: parent.styleKey
      styleRoot: parent.styleRoot
      z: 20
    }
  }

  component ComponentBorderCanvas: Canvas {
    id: componentBorderCanvas

    property string styleKey: ""
    property bool styleRoot: false

    visible: root.componentBorderVisible(styleKey, styleRoot) && width > 0 && height > 0
    opacity: 0.86
    antialiasing: true

    readonly property string animation: root.componentBorderAnimation(styleKey)
    readonly property var borderColors: root.componentBorderColors(styleKey)
    readonly property real animationSpeed: root.clamp(root.componentBorderSpeed(styleKey), 0.15, 3)
    readonly property real borderWidth: Math.max(1, Math.round(root.componentBorderWidth(styleKey) * root.panelUnit))
    readonly property bool reactive: animation.indexOf("reactive") === 0
    readonly property bool animationActive: reactive ? root.musicActive : animation !== "static"
    readonly property real phase: animationActive ? root.sliderEffectPhase : 0

    onAnimationChanged: requestPaint()
    onAnimationSpeedChanged: requestPaint()
    onBorderColorsChanged: requestPaint()
    onBorderWidthChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onVisibleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function rgba(c, alpha) {
      const color = typeof c === "string" ? Qt.color(c) : c;
      return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
    }

    function roundedRect(ctx, x, y, w, h, r) {
      const rr = Math.min(r, w / 2, h / 2);
      ctx.beginPath();
      ctx.moveTo(x + rr, y);
      ctx.lineTo(x + w - rr, y);
      ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
      ctx.lineTo(x + w, y + h - rr);
      ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
      ctx.lineTo(x + rr, y + h);
      ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
      ctx.lineTo(x, y + rr);
      ctx.quadraticCurveTo(x, y, x + rr, y);
    }

    function borderPoint(t, inset, radius) {
      const x = inset;
      const y = inset;
      const w = width - inset * 2;
      const h = height - inset * 2;
      const r = Math.min(radius, w / 2, h / 2);
      const top = Math.max(1, w - r * 2);
      const side = Math.max(1, h - r * 2);
      const arc = Math.PI * r / 2;
      const perimeter = top * 2 + side * 2 + arc * 4;
      let d = ((t % 1) + 1) % 1 * perimeter;

      if (d < top)
        return { x: x + r + d, y: y, angle: 0 };
      d -= top;
      if (d < arc) {
        const a = -Math.PI / 2 + d / arc * Math.PI / 2;
        return { x: x + w - r + Math.cos(a) * r, y: y + r + Math.sin(a) * r, angle: a + Math.PI / 2 };
      }
      d -= arc;
      if (d < side)
        return { x: x + w, y: y + r + d, angle: Math.PI / 2 };
      d -= side;
      if (d < arc) {
        const a = d / arc * Math.PI / 2;
        return { x: x + w - r + Math.cos(a) * r, y: y + h - r + Math.sin(a) * r, angle: a + Math.PI / 2 };
      }
      d -= arc;
      if (d < top)
        return { x: x + w - r - d, y: y + h, angle: Math.PI };
      d -= top;
      if (d < arc) {
        const a = Math.PI / 2 + d / arc * Math.PI / 2;
        return { x: x + r + Math.cos(a) * r, y: y + h - r + Math.sin(a) * r, angle: a + Math.PI / 2 };
      }
      d -= arc;
      if (d < side)
        return { x: x, y: y + h - r - d, angle: -Math.PI / 2 };

      d -= side;
      const a = Math.PI + d / arc * Math.PI / 2;
      return { x: x + r + Math.cos(a) * r, y: y + r + Math.sin(a) * r, angle: a + Math.PI / 2 };
    }

    function drawSpark(ctx, t, size, color, alpha, inset, radius) {
      const p = borderPoint(t, inset, radius);
      const nx = Math.cos(p.angle + Math.PI / 2);
      const ny = Math.sin(p.angle + Math.PI / 2);
      const tx = Math.cos(p.angle);
      const ty = Math.sin(p.angle);
      ctx.fillStyle = rgba(color, alpha);
      ctx.beginPath();
      ctx.moveTo(p.x + nx * size * 0.25, p.y + ny * size * 0.25);
      ctx.lineTo(p.x - tx * size * 0.55 - nx * size * 0.8, p.y - ty * size * 0.55 - ny * size * 0.8);
      ctx.lineTo(p.x + tx * size * 1.25 - nx * size * 0.25, p.y + ty * size * 1.25 - ny * size * 0.25);
      ctx.closePath();
      ctx.fill();
    }

    function applyDash(ctx, pattern, offset) {
      if (typeof ctx.setLineDash !== "function")
        return;
      ctx.setLineDash(pattern);
      ctx.lineDashOffset = offset || 0;
    }

    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      if (!visible || width <= 0 || height <= 0)
        return;

      const lineWidth = borderWidth;
      const inset = lineWidth / 2;
      const colors = borderColors && borderColors.length > 0 ? borderColors : [Color.mPrimary];
      const energy = reactive ? root.spectrumAverage() : 0;
      const alpha = reactive ? root.clamp(0.48 + energy * 0.46, 0.48, 0.94) : 0.86;
      const flow = animation === "flow" || animation === "flowEase" || animation === "spark" || animation === "reactiveFlow" || animation === "reactiveSpark" || animation === "scan" || animation === "profileAurora" || animation === "profileSpotlight";
      const fade = animation === "fade" || animation === "reactivePulse";
      const raw = phase * (flow ? 0.035 : 0.16) * animationSpeed;
      const eased = raw + Math.sin(raw * 1.6) * 0.42;
      const p = animation === "flowEase" ? eased : raw;
      const radius = Math.max(0, Number(parent?.radius || Style.radiusM) - lineWidth / 2);
      const pulse = 0.5 + Math.sin(p * 2.4) * 0.5;
      const pathWidth = Math.max(1, (width - lineWidth) * 2 + (height - lineWidth) * 2);
      const movingDash = animation === "chase";
      const comet = animation === "comet";
      const neon = animation === "neon";
      const corners = animation === "corners";
      const orbitDots = animation === "orbitDots";
      const scan = animation === "scan";

      if (neon) {
        ctx.shadowColor = rgba(colors[0], 0.45 + pulse * 0.28);
        ctx.shadowBlur = Math.max(6, lineWidth * (2.6 + pulse * 2.2));
      }

      if (scan && colors.length > 1) {
        const sweep = ((p * 0.22) % 1 + 1) % 1;
        const gradient = ctx.createLinearGradient(width * (sweep - 0.45), 0, width * (sweep + 0.45), height);
        gradient.addColorStop(0, rgba(colors[0], 0.08));
        gradient.addColorStop(0.46, rgba(colors[1 % colors.length], alpha));
        gradient.addColorStop(0.54, rgba(colors[2 % colors.length], alpha));
        gradient.addColorStop(1, rgba(colors[0], 0.08));
        ctx.strokeStyle = gradient;
      } else if (flow && colors.length > 1) {
        const angle = p % (Math.PI * 2);
        const cx = width / 2;
        const cy = height / 2;
        const dx = Math.cos(angle) * width / 2;
        const dy = Math.sin(angle) * height / 2;
        const gradient = ctx.createLinearGradient(cx - dx, cy - dy, cx + dx, cy + dy);
        for (let i = 0; i < colors.length; i++)
          gradient.addColorStop(i / Math.max(1, colors.length - 1), rgba(colors[i], alpha));
        ctx.strokeStyle = gradient;
      } else if (fade && colors.length > 1) {
        const index = Math.floor(Math.abs(p)) % colors.length;
        ctx.strokeStyle = rgba(colors[index], alpha);
      } else {
        ctx.strokeStyle = rgba(colors[0], alpha);
      }

      ctx.lineWidth = lineWidth;
      if (animation === "reactivePulse")
        applyDash(ctx, [Math.max(8, lineWidth * 4), Math.max(5, lineWidth * 2)], -(p * 52));
      else if (movingDash)
        applyDash(ctx, [Math.max(10, lineWidth * 5), Math.max(8, lineWidth * 4)], -(p * 52));
      else if (comet)
        applyDash(ctx, [Math.max(24, pathWidth * 0.12), Math.max(36, pathWidth * 0.68)], -(p * 52));
      else
        applyDash(ctx, [], 0);
      roundedRect(ctx, inset, inset, width - lineWidth, height - lineWidth, radius);
      ctx.stroke();
      ctx.shadowBlur = 0;
      applyDash(ctx, [], 0);

      if (corners) {
        const corner = Math.min(width, height) * 0.22;
        ctx.strokeStyle = rgba(colors[1 % colors.length], 0.48 + pulse * 0.32);
        ctx.lineWidth = lineWidth + 1;
        ctx.lineCap = "round";
        for (let i = 0; i < 4; i++) {
          const left = i === 0 || i === 3;
          const topSide = i < 2;
          const sx = left ? inset + radius * 0.55 : width - inset - radius * 0.55;
          const sy = topSide ? inset : height - inset;
          ctx.beginPath();
          ctx.moveTo(sx, sy);
          ctx.lineTo(left ? Math.min(sx + corner, width - inset) : Math.max(sx - corner, inset), sy);
          ctx.stroke();
          ctx.beginPath();
          ctx.moveTo(left ? inset : width - inset, topSide ? inset + radius * 0.55 : height - inset - radius * 0.55);
          ctx.lineTo(left ? inset : width - inset, topSide ? Math.min(inset + radius * 0.55 + corner, height - inset) : Math.max(height - inset - radius * 0.55 - corner, inset));
          ctx.stroke();
        }
      }

      if (animation === "spark" || animation === "reactiveSpark" || orbitDots) {
        const sparkCount = animation === "reactiveSpark" ? 5 : 7;
        const boost = animation === "reactiveSpark" ? root.clamp(0.45 + energy * 0.9, 0.45, 1.15) : 0.85;
        for (let i = 0; i < sparkCount; i++) {
          const local = (p * 0.16 + i / sparkCount) % 1;
          const flicker = 0.45 + 0.55 * Math.abs(Math.sin((p + i * 1.71) * 2.4));
          if (orbitDots) {
            const point = borderPoint(local, inset + lineWidth * 0.35, radius);
            ctx.fillStyle = rgba(colors[i % colors.length], 0.26 + flicker * 0.5);
            ctx.beginPath();
            ctx.arc(point.x, point.y, Math.max(2, lineWidth * (0.75 + flicker * 0.6)), 0, Math.PI * 2);
            ctx.fill();
          } else {
            drawSpark(ctx, local, Math.max(3, lineWidth * (1.4 + flicker)) * boost, colors[i % colors.length], 0.18 + flicker * 0.42, inset + lineWidth * 0.4, radius);
          }
        }
      }
    }
  }

  component SubmoduleButton: Item {
    id: submoduleButton

    property string styleKey: root.inheritedStyleKey(parent)
    property string labelText: root.tr("openDetails")
    property string iconName: "chevron-right"
    property string targetView: ""
    property var tooltipText: root.tr("details")

    Layout.preferredWidth: Math.max(Math.round(78 * root.panelUnit), contentRow.implicitWidth + Style.marginM * 2)
    Layout.preferredHeight: Math.round(30 * root.panelUnit)
    implicitWidth: Layout.preferredWidth
    implicitHeight: Layout.preferredHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: submoduleHover.hovered ? root.componentButtonBackground(submoduleButton.styleKey) : Qt.alpha(root.componentButtonBackground(submoduleButton.styleKey), 0.13)
      border.width: Style.borderS
      border.color: submoduleHover.hovered ? root.componentButtonBackground(submoduleButton.styleKey) : Qt.alpha(root.componentButtonBackground(submoduleButton.styleKey), 0.34)

      Behavior on color {
        ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast; easing.type: Easing.OutCubic }
      }

      RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Style.marginXXS

        NText {
          text: submoduleButton.labelText
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightSemiBold
          color: submoduleHover.hovered ? root.componentButtonText(submoduleButton.styleKey) : root.componentAccent(submoduleButton.styleKey)
        }

        NIcon {
          icon: submoduleButton.iconName
          pointSize: Style.fontSizeS
          color: submoduleHover.hovered ? root.componentButtonText(submoduleButton.styleKey) : root.componentAccent(submoduleButton.styleKey)
        }
      }
    }

    HoverHandler {
      id: submoduleHover
    }

    TapHandler {
      onTapped: root.activeDetailView = submoduleButton.targetView
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.NoButton
      onEntered: TooltipService.show(parent, submoduleButton.tooltipText)
      onExited: TooltipService.hide()
    }
  }

  component ProfileCard: DashboardCard {
    id: profileCard
    styleKey: "profile"
    styleRoot: true
    clip: true
    radius: root.profileCardRadius(width, height)
    readonly property bool coverIsAnimated: root.profileWallpaperPath.toLowerCase().endsWith(".gif")
    readonly property bool coverBlurActive: root.profileCoverBlurEnabled && root.profileCoverBlur > 0
    readonly property real coverRadius: root.innerProfileCardRadius(width, height)

    ReactiveRoundedImage {
      id: profileCoverImage
      anchors.fill: parent
      anchors.margins: Math.max(1, Style.borderS)
      visible: root.profileWallpaperPath !== ""
      radius: profileCard.coverRadius
      imagePath: root.profileWallpaperPath
      fallbackIcon: ""
    }

    Item {
      id: profileCoverBlurLayer
      anchors.fill: parent
      anchors.margins: Math.max(1, Style.borderS)
      visible: root.profileWallpaperPath !== "" && profileCard.coverBlurActive
      layer.enabled: visible
      layer.smooth: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: root.clamp(root.profileCoverBlur, 0, 1)
        blurMax: 48
        maskEnabled: true
        maskThresholdMin: 0.95
        maskSpreadAtMin: 0.15
        maskSource: ShaderEffectSource {
          sourceItem: Rectangle {
            width: profileCoverBlurLayer.width
            height: profileCoverBlurLayer.height
            radius: profileCard.coverRadius
            color: "white"
          }
        }
      }

      Loader {
        anchors.fill: parent
        active: profileCoverBlurLayer.visible
        sourceComponent: profileCard.coverIsAnimated ? animatedCoverSource : staticCoverSource
      }

      Component {
        id: staticCoverSource
        Image {
          source: root.profileWallpaperPath
          fillMode: Image.PreserveAspectCrop
          smooth: true
          mipmap: true
          asynchronous: true
          antialiasing: true
        }
      }

      Component {
        id: animatedCoverSource
        AnimatedImage {
          source: root.profileWallpaperPath
          fillMode: Image.PreserveAspectCrop
          playing: !root.dashboardPerformanceMode
          smooth: true
          mipmap: true
          asynchronous: true
          antialiasing: true
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Math.max(1, Style.borderS)
      visible: root.profileWallpaperPath !== "" && root.profileCoverOverlayEnabled && root.profileCoverOverlay > 0
      radius: profileCard.coverRadius
      color: Qt.rgba(0, 0, 0, root.clamp(root.profileCoverOverlay, 0, 0.88))
    }

    Canvas {
      id: profileCoverBorderCanvas
      anchors.fill: parent
      visible: !root.dashboardPerformanceMode && root.profileCoverBorder && root.profileCoverBorderWidth > 0
      opacity: 0.84
      z: 20
      antialiasing: true

      readonly property var borderColors: root.profileBorderColors()
      readonly property real phase: root.profileBorderAnimationActive() ? root.sliderEffectPhase : 0

      onBorderColorsChanged: requestPaint()
      onPhaseChanged: requestPaint()
      onVisibleChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      function rgba(c, alpha) {
        const color = typeof c === "string" ? Qt.color(c) : c;
        return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
      }

      function roundedRect(ctx, x, y, w, h, r) {
        const rr = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + rr, y);
        ctx.lineTo(x + w - rr, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
        ctx.lineTo(x + w, y + h - rr);
        ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
        ctx.lineTo(x + rr, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
        ctx.lineTo(x, y + rr);
        ctx.quadraticCurveTo(x, y, x + rr, y);
      }

      function borderPoint(t, inset, radius) {
        const x = inset;
        const y = inset;
        const w = width - inset * 2;
        const h = height - inset * 2;
        const r = Math.min(radius, w / 2, h / 2);
        const top = Math.max(1, w - r * 2);
        const side = Math.max(1, h - r * 2);
        const arc = Math.PI * r / 2;
        const perimeter = top * 2 + side * 2 + arc * 4;
        let d = ((t % 1) + 1) % 1 * perimeter;

        if (d < top)
          return { x: x + r + d, y: y, angle: 0 };
        d -= top;
        if (d < arc) {
          const a = -Math.PI / 2 + d / arc * Math.PI / 2;
          return { x: x + w - r + Math.cos(a) * r, y: y + r + Math.sin(a) * r, angle: a + Math.PI / 2 };
        }
        d -= arc;
        if (d < side)
          return { x: x + w, y: y + r + d, angle: Math.PI / 2 };
        d -= side;
        if (d < arc) {
          const a = d / arc * Math.PI / 2;
          return { x: x + w - r + Math.cos(a) * r, y: y + h - r + Math.sin(a) * r, angle: a + Math.PI / 2 };
        }
        d -= arc;
        if (d < top)
          return { x: x + w - r - d, y: y + h, angle: Math.PI };
        d -= top;
        if (d < arc) {
          const a = Math.PI / 2 + d / arc * Math.PI / 2;
          return { x: x + r + Math.cos(a) * r, y: y + h - r + Math.sin(a) * r, angle: a + Math.PI / 2 };
        }
        d -= arc;
        if (d < side)
          return { x: x, y: y + h - r - d, angle: -Math.PI / 2 };

        d -= side;
        const a = Math.PI + d / arc * Math.PI / 2;
        return { x: x + r + Math.cos(a) * r, y: y + r + Math.sin(a) * r, angle: a + Math.PI / 2 };
      }

      function drawSpark(ctx, t, size, color, alpha, inset, radius) {
        const p = borderPoint(t, inset, radius);
        const nx = Math.cos(p.angle + Math.PI / 2);
        const ny = Math.sin(p.angle + Math.PI / 2);
        const tx = Math.cos(p.angle);
        const ty = Math.sin(p.angle);
        ctx.fillStyle = rgba(color, alpha);
        ctx.beginPath();
        ctx.moveTo(p.x + nx * size * 0.25, p.y + ny * size * 0.25);
        ctx.lineTo(p.x - tx * size * 0.55 - nx * size * 0.8, p.y - ty * size * 0.55 - ny * size * 0.8);
        ctx.lineTo(p.x + tx * size * 1.25 - nx * size * 0.25, p.y + ty * size * 1.25 - ny * size * 0.25);
        ctx.closePath();
        ctx.fill();
      }

      function applyDash(ctx, pattern, offset) {
        if (typeof ctx.setLineDash !== "function")
          return;
        ctx.setLineDash(pattern);
        ctx.lineDashOffset = offset || 0;
      }

      onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (width <= 0 || height <= 0)
          return;

        const lineWidth = Math.max(1, Math.round(root.profileCoverBorderWidth * root.panelUnit));
        const inset = lineWidth / 2;
        const colors = borderColors && borderColors.length > 0 ? borderColors : [Color.mPrimary];
        const animation = root.profileCoverBorderAnimation;
        const reactive = animation.indexOf("reactive") === 0;
        const energy = reactive ? root.spectrumAverage() : 0;
        const alpha = reactive ? root.clamp(0.48 + energy * 0.46, 0.48, 0.94) : 0.86;
        const flow = animation === "flow" || animation === "flowEase" || animation === "spark" || animation === "reactiveFlow" || animation === "reactiveSpark" || animation === "scan" || animation === "profileAurora" || animation === "profileSpotlight";
        const fade = animation === "fade" || animation === "reactivePulse";
        const speed = root.clamp(root.profileCoverBorderSpeed, 0.15, 3);
        const raw = phase * (flow ? 0.035 : 0.16) * speed;
        const eased = raw + Math.sin(raw * 1.6) * 0.42;
        const p = animation === "flowEase" ? eased : raw;
        const radius = Math.max(0, root.profileCardRadius(width, height) - lineWidth / 2);
        const pulse = 0.5 + Math.sin(p * 2.4) * 0.5;
        const pathWidth = Math.max(1, (width - lineWidth) * 2 + (height - lineWidth) * 2);
        const movingDash = animation === "chase";
        const comet = animation === "comet";
        const neon = animation === "neon";
        const corners = animation === "corners";
        const orbitDots = animation === "orbitDots";
        const scan = animation === "scan";
        const aurora = animation === "profileAurora";
        const halo = animation === "profileHalo";
        const heartbeat = animation === "profileHeartbeat";
        const spotlight = animation === "profileSpotlight";

        if (neon || heartbeat) {
          ctx.shadowColor = rgba(colors[0], heartbeat ? 0.52 + pulse * 0.32 : 0.45 + pulse * 0.28);
          ctx.shadowBlur = Math.max(7, lineWidth * (heartbeat ? 4.4 + pulse * 2.4 : 2.6 + pulse * 2.2));
        }

        if ((scan || spotlight) && colors.length > 1) {
          const sweep = ((p * 0.22) % 1 + 1) % 1;
          const gradient = ctx.createLinearGradient(width * (sweep - 0.45), 0, width * (sweep + 0.45), height);
          gradient.addColorStop(0, rgba(colors[0], spotlight ? 0.04 : 0.08));
          gradient.addColorStop(0.46, rgba(colors[1 % colors.length], spotlight ? 0.82 : alpha));
          gradient.addColorStop(0.54, rgba(colors[2 % colors.length], spotlight ? 0.96 : alpha));
          gradient.addColorStop(1, rgba(colors[0], spotlight ? 0.04 : 0.08));
          ctx.strokeStyle = gradient;
        } else if (aurora && colors.length > 1) {
          const gradient = ctx.createLinearGradient(0, height * (0.18 + pulse * 0.14), width, height * (0.82 - pulse * 0.14));
          for (let i = 0; i < colors.length; i++)
            gradient.addColorStop(i / Math.max(1, colors.length - 1), rgba(colors[(i + Math.floor(Math.abs(p))) % colors.length], 0.48 + pulse * 0.28));
          ctx.strokeStyle = gradient;
        } else if (flow && colors.length > 1) {
          const angle = p % (Math.PI * 2);
          const cx = width / 2;
          const cy = height / 2;
          const dx = Math.cos(angle) * width / 2;
          const dy = Math.sin(angle) * height / 2;
          const gradient = ctx.createLinearGradient(cx - dx, cy - dy, cx + dx, cy + dy);
          for (let i = 0; i < colors.length; i++)
            gradient.addColorStop(i / Math.max(1, colors.length - 1), rgba(colors[i], alpha));
          ctx.strokeStyle = gradient;
        } else if (fade && colors.length > 1) {
          const index = Math.floor(Math.abs(p)) % colors.length;
          ctx.strokeStyle = rgba(colors[index], alpha);
        } else {
          ctx.strokeStyle = rgba(root.profileBorderColor(), alpha);
        }

        ctx.lineWidth = lineWidth;
        if (animation === "reactivePulse")
          applyDash(ctx, [Math.max(8, lineWidth * 4), Math.max(5, lineWidth * 2)], -(p * 52));
        else if (movingDash)
          applyDash(ctx, [Math.max(10, lineWidth * 5), Math.max(8, lineWidth * 4)], -(p * 52));
        else if (comet)
          applyDash(ctx, [Math.max(24, pathWidth * 0.12), Math.max(36, pathWidth * 0.68)], -(p * 52));
        else
          applyDash(ctx, [], 0);
        roundedRect(ctx, inset, inset, width - lineWidth, height - lineWidth, radius);
        ctx.stroke();
        ctx.shadowBlur = 0;
        applyDash(ctx, [], 0);

        if (halo) {
          const haloGradient = ctx.createRadialGradient(width / 2, height / 2, Math.min(width, height) * 0.18, width / 2, height / 2, Math.max(width, height) * 0.58);
          haloGradient.addColorStop(0, rgba(colors[0], 0));
          haloGradient.addColorStop(0.72, rgba(colors[1 % colors.length], 0.06 + pulse * 0.08));
          haloGradient.addColorStop(1, rgba(colors[2 % colors.length], 0.18 + pulse * 0.12));
          ctx.fillStyle = haloGradient;
          roundedRect(ctx, inset + lineWidth, inset + lineWidth, width - lineWidth * 3, height - lineWidth * 3, Math.max(0, radius - lineWidth));
          ctx.fill();
        }

        if (corners) {
          const corner = Math.min(width, height) * 0.22;
          ctx.strokeStyle = rgba(colors[1 % colors.length], 0.48 + pulse * 0.32);
          ctx.lineWidth = lineWidth + 1;
          ctx.lineCap = "round";
          for (let i = 0; i < 4; i++) {
            const left = i === 0 || i === 3;
            const topSide = i < 2;
            const sx = left ? inset + radius * 0.55 : width - inset - radius * 0.55;
            const sy = topSide ? inset : height - inset;
            ctx.beginPath();
            ctx.moveTo(sx, sy);
            ctx.lineTo(left ? Math.min(sx + corner, width - inset) : Math.max(sx - corner, inset), sy);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(left ? inset : width - inset, topSide ? inset + radius * 0.55 : height - inset - radius * 0.55);
            ctx.lineTo(left ? inset : width - inset, topSide ? Math.min(inset + radius * 0.55 + corner, height - inset) : Math.max(height - inset - radius * 0.55 - corner, inset));
            ctx.stroke();
          }
        }

        if (animation === "spark" || animation === "reactiveSpark" || orbitDots) {
          const sparkCount = animation === "reactiveSpark" ? 5 : 7;
          const boost = animation === "reactiveSpark" ? root.clamp(0.45 + energy * 0.9, 0.45, 1.15) : 0.85;
          for (let i = 0; i < sparkCount; i++) {
            const local = (p * 0.16 + i / sparkCount) % 1;
            const flicker = 0.45 + 0.55 * Math.abs(Math.sin((p + i * 1.71) * 2.4));
            const color = colors[i % colors.length];
            if (orbitDots) {
              const point = borderPoint(local, inset + lineWidth * 0.35, radius);
              ctx.fillStyle = rgba(color, 0.26 + flicker * 0.5);
              ctx.beginPath();
              ctx.arc(point.x, point.y, Math.max(2, lineWidth * (0.75 + flicker * 0.6)), 0, Math.PI * 2);
              ctx.fill();
            } else {
              drawSpark(ctx, local, Math.max(3, lineWidth * (1.4 + flicker)) * boost, color, 0.18 + flicker * 0.42, inset + lineWidth * 0.4, radius);
            }
          }
        }
      }

      SequentialAnimation on scale {
        running: !root.dashboardPerformanceMode && (root.profileCoverBorderAnimation === "pulse" || root.profileCoverBorderAnimation === "reactivePulse" || root.profileCoverBorderAnimation === "profileHeartbeat")
        loops: Animation.Infinite
        NumberAnimation { to: root.profileCoverBorderAnimation === "profileHeartbeat" ? 1.018 : 1.012; duration: root.profileCoverBorderAnimation === "profileHeartbeat" ? 340 : 760; easing.type: Easing.OutCubic }
        NumberAnimation { to: 1.0; duration: root.profileCoverBorderAnimation === "profileHeartbeat" ? 620 : 820; easing.type: Easing.InOutSine }
      }
    }

    Item {
      id: profileContent

      anchors.fill: parent
      anchors.margins: Style.marginL

      readonly property bool showDanceGif: root.showProfileDanceGif && root.resolvedProfileDanceGifPath !== ""
      readonly property real avatarSize: Math.round((showDanceGif ? 70 : 78) * root.panelUnit)

      RowLayout {
        anchors.fill: parent
        spacing: Style.marginM

        Item {
          id: avatarStage

          Layout.preferredWidth: profileContent.avatarSize
          Layout.preferredHeight: profileContent.avatarSize

          readonly property bool circleAvatar: root.avatarShape !== "rounded"
          readonly property real avatarRadius: circleAvatar ? width / 2 : Math.round(Style.radiusL * root.panelUnit)
          readonly property bool effectsAllowed: root.musicActive && !root.dashboardPerformanceMode
          readonly property bool ringEffect: effectsAllowed && (root.avatarMusicEffect === "ring" || root.avatarMusicEffect === "both" || root.avatarMusicEffect === "studio")
          readonly property bool morphEffect: effectsAllowed && (root.avatarMusicEffect === "morph" || root.avatarMusicEffect === "both" || root.avatarMusicEffect === "studio")
          readonly property bool glowEffect: effectsAllowed && (root.avatarMusicEffect === "glow" || root.avatarMusicEffect === "studio")
          readonly property bool orbitEffect: effectsAllowed && (root.avatarMusicEffect === "orbit" || root.avatarMusicEffect === "studio")

          Rectangle {
            anchors.centerIn: parent
            width: parent.width + Math.round(20 * root.panelUnit)
            height: parent.height + Math.round(20 * root.panelUnit)
            radius: avatarStage.circleAvatar ? width / 2 : Style.radiusL
            color: Color.mPrimary
            opacity: avatarStage.glowEffect ? 0.12 : 0

            SequentialAnimation on scale {
              running: avatarStage.glowEffect
              loops: Animation.Infinite
              NumberAnimation { to: 1.08; duration: 900; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.96; duration: 820; easing.type: Easing.InOutSine }
            }

            Behavior on opacity {
              NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
            }
          }

          Rectangle {
            anchors.centerIn: parent
            width: parent.width + Math.round(6 * root.panelUnit)
            height: parent.height + Math.round(6 * root.panelUnit)
            radius: avatarStage.circleAvatar ? width / 2 : Style.radiusL
            color: "transparent"
            border.width: Math.round(2 * root.panelUnit)
            border.color: Color.mPrimary
            opacity: avatarStage.ringEffect ? 0.55 : 0

            SequentialAnimation on scale {
              running: avatarStage.ringEffect
              loops: Animation.Infinite
              NumberAnimation { to: 1.08; duration: 420; easing.type: Easing.OutCubic }
              NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
            }
          }

          Rectangle {
            anchors.centerIn: parent
            width: parent.width + Math.round(12 * root.panelUnit)
            height: parent.height + Math.round(12 * root.panelUnit)
            radius: avatarStage.circleAvatar ? width / 2 : Style.radiusL
            color: "transparent"
            border.width: Math.round(1 * root.panelUnit)
            border.color: Color.mSecondary
            opacity: avatarStage.ringEffect ? 0.22 : 0

            SequentialAnimation on scale {
              running: avatarStage.ringEffect
              loops: Animation.Infinite
              NumberAnimation { to: 1.12; duration: 640; easing.type: Easing.OutCubic }
              NumberAnimation { to: 0.98; duration: 500; easing.type: Easing.InOutSine }
            }
          }

          Item {
            anchors.centerIn: parent
            width: parent.width + Math.round(18 * root.panelUnit)
            height: width
            visible: avatarStage.orbitEffect
            opacity: avatarStage.orbitEffect ? 1 : 0

            RotationAnimator on rotation {
              running: avatarStage.orbitEffect
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 4400
            }

            Rectangle {
              width: Math.round(7 * root.panelUnit)
              height: width
              radius: width / 2
              x: (parent.width - width) / 2
              y: -height / 2
              color: Color.mPrimary
            }

            Rectangle {
              width: Math.round(5 * root.panelUnit)
              height: width
              radius: width / 2
              x: (parent.width - width) / 2
              y: parent.height - height / 2
              color: Color.mSecondary
            }
          }

          Item {
            id: avatarWarp
            anchors.fill: parent

            transform: Scale {
              id: avatarWarpScale
              origin.x: avatarWarp.width / 2
              origin.y: avatarWarp.height / 2
              xScale: 1
              yScale: 1
            }

            SequentialAnimation {
              running: avatarStage.morphEffect
              loops: Animation.Infinite
              ParallelAnimation {
                NumberAnimation { target: avatarWarpScale; property: "xScale"; to: 1.05; duration: 260; easing.type: Easing.InOutSine }
                NumberAnimation { target: avatarWarpScale; property: "yScale"; to: 0.96; duration: 260; easing.type: Easing.InOutSine }
              }
              ParallelAnimation {
                NumberAnimation { target: avatarWarpScale; property: "xScale"; to: 0.98; duration: 300; easing.type: Easing.InOutSine }
                NumberAnimation { target: avatarWarpScale; property: "yScale"; to: 1.04; duration: 300; easing.type: Easing.InOutSine }
              }
              ParallelAnimation {
                NumberAnimation { target: avatarWarpScale; property: "xScale"; to: 1.0; duration: 260; easing.type: Easing.InOutSine }
                NumberAnimation { target: avatarWarpScale; property: "yScale"; to: 1.0; duration: 260; easing.type: Easing.InOutSine }
              }
            }

            NImageRounded {
              anchors.fill: parent
              radius: avatarStage.avatarRadius
              imagePath: Settings.preprocessPath(root.avatarPath)
              fallbackIcon: "user"
              fallbackIconSize: Style.fontSizeXXXL
              borderColor: root.musicActive && avatarStage.ringEffect ? Color.mSecondary : Color.mPrimary
              borderWidth: Style.borderM
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: TooltipService.show(parent, root.tr("profileTooltip"))
            onExited: TooltipService.hide()
            onClicked: avatarPicker.openFilePicker()
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: HostService.displayName
            pointSize: Style.fontSizeXXL
            font.weight: Style.fontWeightSemiBold
            color: root.profileTextColor(true)
            elide: Text.ElideRight
          }

          InfoLine {
            iconName: "device-desktop"
            labelText: HostService.osPretty || "Linux"
            coverMode: root.profileWallpaperPath !== ""
          }

          InfoLine {
            iconName: "layout-dashboard"
            labelText: root.compositorName()
            coverMode: root.profileWallpaperPath !== ""
          }

          InfoLine {
            iconName: "clock"
            labelText: Qt.formatTime(Time.now, "HH:mm")
            coverMode: root.profileWallpaperPath !== ""
          }
        }

        ReactiveRoundedImage {
          visible: profileContent.showDanceGif
          Layout.preferredWidth: Math.round(54 * root.panelUnit)
          Layout.preferredHeight: Math.round(82 * root.panelUnit)
          radius: Style.radiusS
          framed: false
          imagePath: root.resolvedProfileDanceGifPath
          animatedPlaying: root.musicActive
          fallbackIcon: ""
          opacity: root.musicActive ? 1 : 0.32
        }
      }
    }
  }

  component InfoLine: RowLayout {
    property string iconName: ""
    property string labelText: ""
    property bool coverMode: false
    spacing: Style.marginS

    NIcon {
      icon: iconName
      pointSize: Style.fontSizeM
      color: coverMode ? Qt.alpha("white", 0.92) : Color.mPrimary
    }

    NText {
      Layout.fillWidth: true
      text: labelText
      color: coverMode ? Qt.alpha("white", 0.82) : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      elide: Text.ElideRight
    }
  }

  component QuickActionsCard: DashboardCard {
    styleKey: "quickActions"
    styleRoot: true
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      HeaderRow {
        title: root.tr("controls")
        subtitle: root.tr("quick")
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginS
        rowSpacing: Style.marginS

        ActionTile {
          labelText: root.tr("network")
          detailText: NetworkService.wifiConnected ? (NetworkService.activeWifiDetails.connectionName || NetworkService.activeWifiIf || root.tr("openPanel")) : root.tr("openPanel")
          secondaryIcon: "settings"
          secondaryTooltip: root.tr("networkDetails")
          iconName: NetworkService.wifiEnabled ? "wifi" : "wifi-off"
          active: NetworkService.wifiEnabled
          onTriggered: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
          onSecondaryTriggered: root.toggleNativePanel("networkPanel")
        }

        ActionTile {
          labelText: root.tr("bluetooth")
          detailText: root.bluetoothDetailText()
          secondaryIcon: "settings"
          secondaryTooltip: root.tr("bluetoothDetails")
          hoverTooltip: root.bluetoothTooltipRows()
          iconName: !BluetoothService.enabled ? "bluetooth-off" : ((BluetoothService.connectedDevices && BluetoothService.connectedDevices.length > 0) ? "bluetooth-connected" : "bluetooth")
          active: BluetoothService.enabled
          onTriggered: BluetoothService.setBluetoothEnabled(!BluetoothService.enabled)
          onSecondaryTriggered: root.toggleNativePanel("bluetoothPanel")
        }

        ActionTile {
          labelText: root.tr("dnd")
          detailText: root.tr("clearNotifications")
          secondaryIcon: "trash"
          secondaryTooltip: root.tr("clearNotifications")
          iconName: NotificationService.doNotDisturb ? "bell-off" : "bell"
          active: NotificationService.doNotDisturb
          onTriggered: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
          onSecondaryTriggered: NotificationService.clearHistory()
        }

        ActionTile {
          labelText: root.tr("microphone")
          detailText: Math.round(AudioService.inputVolume * 100) + "%"
          secondaryIcon: "adjustments-horizontal"
          secondaryTooltip: root.tr("audioDetails")
          iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
          active: !AudioService.inputMuted
          onTriggered: AudioService.setInputMuted(!AudioService.inputMuted)
          onSecondaryTriggered: root.toggleNativePanel("audioPanel")
        }

        ActionTile {
          labelText: root.tr("game")
          detailText: PowerProfileService.available ? PowerProfileService.getName() : root.tr("disabled")
          secondaryIcon: PowerProfileService.available ? PowerProfileService.getIcon() : "battery-off"
          secondaryTooltip: root.tr("cyclePowerProfile")
          iconName: "device-gamepad-2"
          active: PowerProfileService.noctaliaPerformanceMode
          onTriggered: PowerProfileService.toggleNoctaliaPerformance()
          onSecondaryTriggered: PowerProfileService.cycleProfile()
        }

        ActionTile {
          labelText: root.tr("awake")
          detailText: IdleInhibitorService.isInhibited ? root.tr("enabled") : root.tr("disabled")
          secondaryIcon: "power"
          secondaryTooltip: root.tr("sessionMenu")
          iconName: "moon"
          active: IdleInhibitorService.isInhibited
          onTriggered: IdleInhibitorService.manualToggle()
          onSecondaryTriggered: root.toggleNativePanel("sessionMenuPanel")
        }

        ActionTile {
          labelText: root.tr("settings")
          detailText: root.tr("openPanel")
          iconName: "settings"
          secondaryIcon: "adjustments-horizontal"
          secondaryTooltip: root.tr("dashboardSettings")
          onTriggered: {
            const panel = PanelService.getPanel("settingsPanel", pluginApi?.panelOpenScreen);
            if (panel) {
              panel.requestedTab = SettingsPanel.Tab.General;
              panel.open();
            }
          }
          onSecondaryTriggered: root.openDashboardSettings()
        }

        ActionTile {
          labelText: root.tr("wallpapers")
          detailText: root.tr("openPanel")
          iconName: "wallpaper-selector"
          secondaryIcon: Settings.data.colorSchemes.darkMode ? "sun" : "moon"
          secondaryTooltip: Settings.data.colorSchemes.darkMode ? root.tr("switchToLightMode") : root.tr("switchToDarkMode")
          onTriggered: root.openWallpaperSelector()
          onSecondaryTriggered: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode
        }
      }
    }
  }

  component ActionTile: DashboardCard {
    id: actionTile

    styleKey: "quickActions"

    property string labelText: ""
    property string detailText: ""
    property string iconName: ""
    property string secondaryIcon: ""
    property string secondaryTooltip: ""
    property var hoverTooltip: null
    property string hoverTooltipDirection: "right"
    property bool active: false
    signal triggered
    signal secondaryTriggered

    Layout.fillWidth: true
    Layout.preferredHeight: hoverHandler.hovered ? Math.round(86 * root.panelUnit) : Math.round(58 * root.panelUnit)
    color: active ? Qt.alpha(root.componentAccent(styleKey), 0.18) : root.componentColor(styleKey, "buttonBackground", Qt.alpha(Color.mSurface, 0.45))
    radius: Style.radiusS
    border.color: borderEffectVisible ? Qt.alpha(root.componentAccent(styleKey), 0.48) : (active ? Qt.alpha(root.componentAccent(styleKey), 0.45) : "transparent")

    Behavior on Layout.preferredHeight {
      NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    Behavior on color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    HoverHandler {
      id: hoverHandler

      onHoveredChanged: {
        const hasTooltip = actionTile.hoverTooltip !== null && actionTile.hoverTooltip !== "" && actionTile.hoverTooltip.length !== 0;
        if (hovered && hasTooltip)
          TooltipService.show(actionTile, actionTile.hoverTooltip, actionTile.hoverTooltipDirection);
        else
          TooltipService.hide(actionTile);
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: iconName
          color: active ? root.componentAccent(actionTile.styleKey) : root.componentText(actionTile.styleKey, false)
          pointSize: Style.fontSizeXL
        }

        NText {
          Layout.fillWidth: true
          text: labelText
          color: active ? root.componentText(actionTile.styleKey, true) : root.componentText(actionTile.styleKey, false)
          pointSize: Style.fontSizeM
          elide: Text.ElideRight
        }
      }

      RowLayout {
        Layout.fillWidth: true
        opacity: hoverHandler.hovered ? 1 : 0
        enabled: hoverHandler.hovered
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: detailText
          pointSize: Style.fontSizeS
          color: root.componentText(actionTile.styleKey, false)
          elide: Text.ElideRight
        }

        NIconButton {
          visible: secondaryIcon !== ""
          icon: secondaryIcon
          baseSize: Math.round(24 * root.panelUnit)
          tooltipText: secondaryTooltip
          colorBg: Qt.alpha(root.componentButtonBackground(actionTile.styleKey), 0.18)
          colorBgHover: root.componentButtonBackground(actionTile.styleKey)
          colorFg: root.componentText(actionTile.styleKey, true)
          colorFgHover: root.componentButtonText(actionTile.styleKey)
          colorBorder: Qt.alpha(root.componentButtonBackground(actionTile.styleKey), 0.32)
          colorBorderHover: root.componentButtonBackground(actionTile.styleKey)
          onClicked: actionTile.secondaryTriggered()
        }
      }
    }

    TapHandler {
      onTapped: parent.triggered()
    }
  }

  component RecordingCard: DashboardCard {
    styleKey: "recording"
    styleRoot: true
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "crosshair"
          pointSize: Style.fontSizeXL
          color: root.componentAccent("recording")
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS

          NText {
            text: root.tr("screenTools")
            font.weight: Style.fontWeightSemiBold
            color: root.componentText("recording", true)
          }

          NText {
            text: root.toolkitRecordState === "recording" ? root.tr("recordingNow") : (root.toolkitRecordState === "converting" ? root.tr("recordingConverting") : root.tr("screenToolsSubtitle"))
            pointSize: Style.fontSizeS
            color: root.toolkitRecording ? Color.mError : root.componentText("recording", false)
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginS
        rowSpacing: Style.marginS

        ToolkitButton {
          labelText: root.tr("recordGif")
          iconName: "movie"
          active: true
          onTriggered: root.startDashboardRecording("gif")
        }

        ToolkitButton {
          labelText: root.tr("recordMp4")
          iconName: "video"
          active: true
          onTriggered: root.startDashboardRecording("mp4")
        }

        ToolkitButton {
          labelText: root.tr("screenshotArea")
          iconName: "crop"
          onTriggered: root.takeDashboardScreenshot("region")
        }

        ToolkitButton {
          labelText: root.tr("screenshotScreen")
          iconName: "camera"
          onTriggered: root.takeDashboardScreenshot("active-screen")
        }

        ToolkitButton {
          Layout.columnSpan: 2
          labelText: root.tr("stopRecording")
          iconName: "square"
          visible: root.toolkitRecording
          destructive: true
          onTriggered: root.stopDashboardRecording()
        }

      }
    }
  }

  component ToolkitButton: DashboardCard {
    id: toolkitButton

    styleKey: root.inheritedStyleKey(parent)

    property string labelText: ""
    property string iconName: ""
    property bool active: false
    property bool destructive: false
    signal triggered

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(32 * root.panelUnit)
    color: destructive ? Qt.alpha(Color.mError, 0.14) : (active ? Qt.alpha(root.componentAccent(styleKey), 0.16) : root.componentColor(styleKey, "buttonBackground", Qt.alpha(Color.mSurface, 0.42)))
    radius: Style.radiusS
    border.color: borderEffectVisible ? Qt.alpha(destructive ? Color.mError : root.componentAccent(styleKey), 0.5) : (mouseArea.containsMouse ? (destructive ? Color.mError : root.componentAccent(styleKey)) : "transparent")
    scale: mouseArea.containsMouse ? 1.02 : 1.0

    Behavior on border.color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast; easing.type: Easing.OutCubic }
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginS

      NIcon {
        icon: iconName
        pointSize: Style.fontSizeM
        color: destructive ? Color.mError : root.componentAccent(toolkitButton.styleKey)
      }

      NText {
        Layout.fillWidth: true
        text: labelText
        color: root.componentText(toolkitButton.styleKey, true)
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toolkitButton.triggered()
    }
  }

  component PerformanceCard: DashboardCard {
    styleKey: "performance"
    styleRoot: true
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          Layout.fillWidth: true
          text: root.tr("performance")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: root.componentText("performance", true)
          elide: Text.ElideRight
        }

        SubmoduleButton {
          targetView: "performance"
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        StatTile {
          Layout.fillWidth: true
          labelText: root.tr("cpu")
          valueText: Math.round(SystemStatService.cpuUsage) + "%"
          detailText: Math.round(SystemStatService.cpuTemp) + "°C"
          iconName: "cpu"
          ratio: SystemStatService.cpuUsage / 100
          fillColor: SystemStatService.cpuColor
        }

        StatTile {
          Layout.fillWidth: true
          labelText: root.tr("ram")
          valueText: Math.round(SystemStatService.memPercent) + "%"
          detailText: SystemStatService.memGb.toFixed(1) + " / " + SystemStatService.memTotalGb.toFixed(1) + " GiB"
          iconName: "device-desktop-analytics"
          ratio: SystemStatService.memPercent / 100
          fillColor: SystemStatService.memColor
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        DiskPager {
          Layout.fillWidth: true
        }

        MiniMeter {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(76 * root.panelUnit)
          labelText: root.tr("gpu")
          iconName: "device-desktop"
          valueText: root.gpuCompactText()
          detailText: root.gpuNameText()
          ratio: root.gpuUsageRatio()
          fillColor: SystemStatService.gpuColor
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NText {
            text: root.tr("networkTraffic")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            TrafficTile {
              Layout.fillWidth: true
              iconName: "download"
              titleText: root.tr("down")
              valueText: root.formatBytes(SystemStatService.rxSpeed)
            }

            TrafficTile {
              Layout.fillWidth: true
              iconName: "upload"
              titleText: root.tr("up")
              valueText: root.formatBytes(SystemStatService.txSpeed)
            }
          }
        }
      }
    }

  }

  component PerformanceDetailsCard: DashboardCard {
    styleKey: "performance"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        NText {
          Layout.fillWidth: true
          text: root.tr("performance")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: root.tr("live")
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          color: Color.mPrimary
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginM
        rowSpacing: Style.marginM

        DetailMetricTile {
          Layout.fillWidth: true
          titleText: root.tr("cpu")
          valueText: root.percentText(SystemStatService.cpuUsage)
          detailText: Math.round(SystemStatService.cpuTemp) + "°C · " + SystemStatService.cpuFreq
          iconName: "cpu"
          ratio: SystemStatService.cpuUsage / 100
          fillColor: SystemStatService.cpuColor
        }

        DetailMetricTile {
          Layout.fillWidth: true
          titleText: root.tr("ram")
          valueText: root.percentText(SystemStatService.memPercent)
          detailText: root.formatGb(SystemStatService.memGb) + " / " + root.formatGb(SystemStatService.memTotalGb)
          iconName: "device-desktop-analytics"
          ratio: SystemStatService.memPercent / 100
          fillColor: SystemStatService.memColor
        }

        DetailMetricTile {
          Layout.fillWidth: true
          titleText: root.tr("disk")
          valueText: root.percentText(root.primaryDiskPercent())
          detailText: root.diskLabel(Settings.data.controlCenter.diskPath || "/")
          iconName: "database"
          ratio: root.primaryDiskPercent() / 100
          fillColor: SystemStatService.getDiskColor(Settings.data.controlCenter.diskPath || "/")
        }

        DetailMetricTile {
          Layout.fillWidth: true
          titleText: root.tr("gpu")
          valueText: root.gpuCompactText()
          detailText: root.gpuNameText()
          iconName: "device-desktop"
          ratio: root.gpuUsageRatio()
          fillColor: SystemStatService.gpuColor
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(148 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: root.tr("usageHistory")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginM

            HistoryGraph {
              Layout.fillWidth: true
              Layout.fillHeight: true
              titleText: root.tr("cpu")
              valueText: root.percentText(SystemStatService.cpuUsage)
              values: SystemStatService.cpuHistory
              maxValue: 100
              lineColor: SystemStatService.cpuColor
            }

            HistoryGraph {
              Layout.fillWidth: true
              Layout.fillHeight: true
              titleText: root.tr("ram")
              valueText: root.percentText(SystemStatService.memPercent)
              values: SystemStatService.memHistory
              maxValue: 100
              lineColor: SystemStatService.memColor
            }
          }
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(120 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: root.tr("networkTraffic")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginM

            TrafficTile {
              Layout.fillWidth: true
              iconName: "download"
              titleText: root.tr("down")
              valueText: root.formatBytes(SystemStatService.rxSpeed)
            }

            TrafficTile {
              Layout.fillWidth: true
              iconName: "upload"
              titleText: root.tr("up")
              valueText: root.formatBytes(SystemStatService.txSpeed)
            }
          }
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: root.tr("resources")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          ResourceLine {
            iconName: "cpu"
            labelText: root.tr("cores")
            valueText: String(SystemStatService.nproc || "--")
          }

          ResourceLine {
            iconName: "activity"
            labelText: root.tr("loadAverage")
            valueText: SystemStatService.loadAvg1.toFixed(2) + " / " + SystemStatService.loadAvg5.toFixed(2) + " / " + SystemStatService.loadAvg15.toFixed(2)
          }

          ResourceLine {
            iconName: "database"
            labelText: root.tr("swap")
            valueText: root.formatGb(SystemStatService.swapGb) + " / " + root.formatGb(SystemStatService.swapTotalGb)
          }

          ResourceLine {
            iconName: "device-desktop"
            labelText: root.tr("system")
            valueText: HostService.osPretty || "Linux"
          }
        }
      }
    }
  }

  component DetailMetricTile: DashboardCard {
    id: detailMetric

    styleKey: root.inheritedStyleKey(parent)

    property string titleText: ""
    property string valueText: ""
    property string detailText: ""
    property string iconName: ""
    property real ratio: 0
    property color fillColor: root.componentAccent(styleKey)

    Layout.preferredHeight: Math.round(86 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NCircleStat {
        ratio: detailMetric.ratio
        icon: detailMetric.iconName
        fillColor: detailMetric.fillColor
        contentScale: 0.68 * root.localScale
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: detailMetric.titleText
          color: root.componentText(detailMetric.styleKey, false)
          pointSize: Style.fontSizeS
        }

        NText {
          text: detailMetric.valueText
          color: root.componentText(detailMetric.styleKey, true)
          pointSize: Style.fontSizeXL
          font.weight: Style.fontWeightSemiBold
        }

        NText {
          Layout.fillWidth: true
          text: detailMetric.detailText
          color: root.componentText(detailMetric.styleKey, false)
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }
      }
    }
  }

  component HeaderRow: RowLayout {
    property string title: ""
    property string subtitle: ""
    property string styleKey: root.inheritedStyleKey(parent)
    Layout.fillWidth: true
    spacing: Style.marginM

    NText {
      Layout.fillWidth: true
      text: title
      pointSize: Style.fontSizeL
      font.weight: Style.fontWeightSemiBold
      color: root.componentText(styleKey, true)
      elide: Text.ElideRight
    }

    NText {
      text: subtitle
      pointSize: Style.fontSizeS
      font.family: Settings.data.ui.fontFixed
      color: root.componentText(styleKey, false)
    }
  }

  component PageDots: Row {
    id: pageDots

    property int count: 0
    property int currentIndex: 0
    signal selected(int index)

    spacing: Math.round(5 * root.panelUnit)
    visible: count > 1

    Repeater {
      model: pageDots.count

      Rectangle {
        width: Math.round((index === pageDots.currentIndex ? 16 : 6) * root.panelUnit)
        height: Math.round(6 * root.panelUnit)
        radius: height / 2
        color: index === pageDots.currentIndex ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.36)

        Behavior on width {
          NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast; easing.type: Easing.OutCubic }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: pageDots.selected(index)
        }
      }
    }
  }

  component StatTile: DashboardCard {
    id: statTile

    styleKey: root.inheritedStyleKey(parent)

    property string labelText: ""
    property string valueText: ""
    property string detailText: ""
    property string iconName: ""
    property real ratio: 0
    property color fillColor: Color.mPrimary

    Layout.preferredHeight: Math.round(104 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NCircleStat {
        ratio: statTile.ratio
        icon: statTile.iconName
        fillColor: statTile.fillColor
        contentScale: 0.78 * root.localScale
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: labelText
          color: root.componentText(statTile.styleKey, false)
          pointSize: Style.fontSizeS
        }

        NText {
          text: valueText
          pointSize: Style.fontSizeXXL
          color: root.componentText(statTile.styleKey, true)
          font.weight: Style.fontWeightSemiBold
        }

        NText {
          Layout.fillWidth: true
          text: detailText
          color: root.componentText(statTile.styleKey, false)
          pointSize: Style.fontSizeS
          elide: Text.ElideRight
        }
      }
    }
  }

  component MiniMeter: DashboardCard {
    id: miniMeter

    styleKey: root.inheritedStyleKey(parent)

    property string labelText: ""
    property string iconName: ""
    property string valueText: ""
    property string detailText: ""
    property real ratio: 0
    property color fillColor: root.componentAccent(styleKey)
    readonly property real safeRatio: Math.max(0, Math.min(1, ratio))

    Layout.preferredHeight: Math.round(62 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS
    border.color: borderEffectVisible ? Qt.alpha(fillColor, 0.36) : Qt.alpha(fillColor, 0.08 + safeRatio * 0.16)

    Behavior on border.color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: detailText !== "" ? Style.marginXS : Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: iconName
          pointSize: Style.fontSizeM
          color: miniMeter.fillColor
        }

        NText {
          Layout.fillWidth: true
          text: labelText
          color: root.componentText(miniMeter.styleKey, false)
          pointSize: Style.fontSizeS
        }

        NText {
          text: valueText
          color: root.componentText(miniMeter.styleKey, true)
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightSemiBold
        }
      }

      NText {
        Layout.fillWidth: true
        visible: detailText !== ""
        text: detailText
        color: Qt.alpha(root.componentText(miniMeter.styleKey, false), 0.74)
        pointSize: Style.fontSizeXXS
        elide: Text.ElideRight
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(5, Math.round(6 * root.panelUnit))
        radius: height / 2
        color: Qt.alpha(Color.mOutline, 0.16)
        clip: true

        Rectangle {
          width: parent.width * miniMeter.safeRatio
          height: parent.height
          radius: parent.radius
          color: miniMeter.fillColor

          Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.12
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
              GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.16) }
              GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
          }

          Behavior on width {
            NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
          }
        }

        Rectangle {
          width: Math.max(6, Math.round(7 * root.panelUnit))
          height: width
          radius: width / 2
          x: Math.max(0, Math.min(parent.width - width, parent.width * miniMeter.safeRatio - width / 2))
          y: (parent.height - height) / 2
          visible: miniMeter.safeRatio > 0.02
          color: miniMeter.fillColor
          opacity: 0.78

          Behavior on x {
            NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }

  component DiskPager: DashboardCard {
    id: diskPager

    property int currentIndex: 0
    readonly property var paths: root.diskPaths()
    readonly property int pageCount: paths.length
    readonly property int safeIndex: Math.min(currentIndex, Math.max(0, pageCount - 1))
    readonly property string currentPath: pageCount > 0 ? paths[safeIndex] : "/"
    readonly property real percent: Number(SystemStatService.diskPercents[currentPath] || 0)
    readonly property real usedGb: Number(SystemStatService.diskUsedGb[currentPath] || 0)
    readonly property real sizeGb: Number(SystemStatService.diskSizeGb[currentPath] || 0)

    Layout.preferredHeight: Math.round(76 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS

    onPageCountChanged: currentIndex = Math.min(currentIndex, Math.max(0, pageCount - 1))

    function previous() {
      if (pageCount <= 1)
        return;
      currentIndex = (safeIndex + pageCount - 1) % pageCount;
    }

    function next() {
      if (pageCount <= 1)
        return;
      currentIndex = (safeIndex + 1) % pageCount;
    }

    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => {
                 if (event.angleDelta.y > 0)
                   diskPager.previous();
                 else if (event.angleDelta.y < 0)
                   diskPager.next();
                 event.accepted = diskPager.pageCount > 1;
               }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "database"
          pointSize: Style.fontSizeM
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            text: root.diskLabel(diskPager.currentPath)
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: diskPager.currentPath
            color: Qt.alpha(Color.mOnSurfaceVariant, 0.72)
            pointSize: Style.fontSizeXXS
            elide: Text.ElideMiddle
            visible: diskPager.pageCount > 1
          }
        }

        NText {
          text: Math.round(diskPager.percent) + "%"
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightSemiBold
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(4, Math.round(5 * root.panelUnit))
        radius: height / 2
        color: Qt.alpha(Color.mOutline, 0.22)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, diskPager.percent / 100))
          height: parent.height
          radius: parent.radius
          color: SystemStatService.getDiskColor(diskPager.currentPath)

          Behavior on width {
            NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: diskPager.pageCount > 1

        NText {
          Layout.fillWidth: true
          text: diskPager.sizeGb > 0 ? (diskPager.usedGb.toFixed(1) + " / " + diskPager.sizeGb.toFixed(1) + " GB") : ""
          color: Qt.alpha(Color.mOnSurfaceVariant, 0.72)
          pointSize: Style.fontSizeXXS
          elide: Text.ElideRight
        }

        PageDots {
          count: diskPager.pageCount
          currentIndex: diskPager.safeIndex
          onSelected: index => diskPager.currentIndex = index
        }
      }

      TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: diskPager.pageCount > 1
        onTapped: diskPager.next()
      }
    }
  }

  component TrafficTile: DashboardCard {
    property string iconName: ""
    property string titleText: ""
    property string valueText: ""

    Layout.preferredHeight: Math.round(64 * root.panelUnit)
    color: Qt.alpha(Color.mPrimary, 0.09)
    radius: Style.radiusS

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NIcon {
        icon: iconName
        pointSize: Style.fontSizeM
        color: Color.mPrimary
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: titleText
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
        }

        NText {
          text: valueText
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }
      }
    }
  }

  component HistoryGraph: DashboardCard {
    id: historyGraph

    property string titleText: ""
    property string valueText: ""
    property var values: []
    property real maxValue: 100
    property color lineColor: Color.mPrimary
    property real pulsePhase: 0

    color: Qt.alpha(Color.mSurface, 0.32)
    radius: Style.radiusS
    clip: true

    onValuesChanged: graphCanvas.requestPaint()
    onLineColorChanged: graphCanvas.requestPaint()
    onMaxValueChanged: graphCanvas.requestPaint()
    onPulsePhaseChanged: graphCanvas.requestPaint()

    function colorToRgba(c, alpha) {
      return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + alpha + ")";
    }

    Timer {
      interval: 80
      repeat: true
      running: historyGraph.visible && !root.dashboardPerformanceMode && !Settings.data.general.animationDisabled
      onTriggered: historyGraph.pulsePhase = (historyGraph.pulsePhase + 0.055) % 1
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginXXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: historyGraph.titleText
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }

        NText {
          text: historyGraph.valueText
          color: Color.mOnSurface
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightSemiBold
        }
      }

      Canvas {
        id: graphCanvas
        Layout.fillWidth: true
        Layout.fillHeight: true
        antialiasing: true

        onPaint: {
          const ctx = getContext("2d");
          ctx.clearRect(0, 0, width, height);
          if (width <= 0 || height <= 0)
            return;

          const vals = historyGraph.values || [];
          const count = vals.length;
          if (count < 2)
            return;

          const pad = Math.max(2, Math.round(3 * root.panelUnit));
          const graphW = Math.max(1, width - pad * 2);
          const graphH = Math.max(1, height - pad * 2);
          const points = [];
          const max = Math.max(1, historyGraph.maxValue);
          for (let i = 0; i < count; i++) {
            const value = root.clamp(Number(vals[i] || 0) / max, 0, 1);
            points.push({
                          x: pad + (count === 1 ? 0 : (graphW * i / (count - 1))),
                          y: pad + graphH - (graphH * value)
                        });
          }

          ctx.strokeStyle = historyGraph.colorToRgba(Color.mOutline, 0.11);
          ctx.lineWidth = 1;
          for (let i = 1; i < 3; i++) {
            const y = pad + graphH * i / 3;
            ctx.beginPath();
            ctx.moveTo(pad, y);
            ctx.lineTo(width - pad, y);
            ctx.stroke();
          }

          const areaGradient = ctx.createLinearGradient(0, pad, 0, height - pad);
          areaGradient.addColorStop(0, historyGraph.colorToRgba(historyGraph.lineColor, 0.28));
          areaGradient.addColorStop(0.62, historyGraph.colorToRgba(historyGraph.lineColor, 0.08));
          areaGradient.addColorStop(1, historyGraph.colorToRgba(historyGraph.lineColor, 0.0));

          ctx.beginPath();
          ctx.moveTo(points[0].x, height - pad);
          ctx.lineTo(points[0].x, points[0].y);
          for (let i = 1; i < points.length; i++) {
            const prev = points[i - 1];
            const cur = points[i];
            const midX = (prev.x + cur.x) / 2;
            ctx.quadraticCurveTo(prev.x, prev.y, midX, (prev.y + cur.y) / 2);
            ctx.quadraticCurveTo(cur.x, cur.y, cur.x, cur.y);
          }
          ctx.lineTo(points[points.length - 1].x, height - pad);
          ctx.closePath();
          ctx.fillStyle = areaGradient;
          ctx.fill();

          ctx.shadowColor = historyGraph.colorToRgba(historyGraph.lineColor, 0.22);
          ctx.shadowBlur = Math.round(8 * root.panelUnit);
          ctx.strokeStyle = historyGraph.colorToRgba(historyGraph.lineColor, 0.96);
          ctx.lineWidth = Math.max(1.6, 2.2 * root.panelUnit);
          ctx.lineCap = "round";
          ctx.lineJoin = "round";
          ctx.beginPath();
          ctx.moveTo(points[0].x, points[0].y);
          for (let i = 1; i < points.length; i++) {
            const prev = points[i - 1];
            const cur = points[i];
            const midX = (prev.x + cur.x) / 2;
            ctx.quadraticCurveTo(prev.x, prev.y, midX, (prev.y + cur.y) / 2);
            ctx.quadraticCurveTo(cur.x, cur.y, cur.x, cur.y);
          }
          ctx.stroke();
          ctx.shadowBlur = 0;

          const last = points[points.length - 1];
          const pulse = 0.5 + Math.sin(historyGraph.pulsePhase * Math.PI * 2) * 0.5;
          ctx.fillStyle = historyGraph.colorToRgba(historyGraph.lineColor, 0.18 + pulse * 0.12);
          ctx.beginPath();
          ctx.arc(last.x, last.y, Math.max(4, 6 * root.panelUnit + pulse * 2), 0, Math.PI * 2);
          ctx.fill();

          ctx.fillStyle = historyGraph.colorToRgba(historyGraph.lineColor, 1);
          ctx.beginPath();
          ctx.arc(last.x, last.y, Math.max(2.2, 3 * root.panelUnit), 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }
  }

  component ResourceLine: RowLayout {
    property string iconName: ""
    property string labelText: ""
    property string valueText: ""

    Layout.fillWidth: true
    spacing: Style.marginS

    NIcon {
      icon: iconName
      pointSize: Style.fontSizeM
      color: Color.mPrimary
    }

    NText {
      Layout.fillWidth: true
      text: labelText
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      elide: Text.ElideRight
    }

    NText {
      text: valueText
      color: Color.mOnSurface
      pointSize: Style.fontSizeS
      font.family: Settings.data.ui.fontFixed
      horizontalAlignment: Text.AlignRight
    }
  }

  component AudioDetailsCard: DashboardCard {
    styleKey: "systemControls"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        NText {
          Layout.fillWidth: true
          text: root.tr("audio")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: root.tr("live")
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          color: Color.mPrimary
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(150 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          ControlSlider {
            iconName: AudioService.muted ? "volume-off" : "volume"
            labelText: root.tr("outputVolume")
            valueText: Math.round(AudioService.volume * 100) + "%"
            value: AudioService.volume
            reactiveEffect: root.audioSliderEffect
            reactiveActive: root.musicActive
            reactiveLevel: root.musicActive ? root.spectrumAverage() : 0
            reactiveValues: SpectrumService.values
            enabled: AudioService.sink !== null || AudioService.wpctlAvailable
            onMoved: value => AudioService.setVolume(value)
          }

          ControlSlider {
            iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
            labelText: root.tr("inputVolume")
            valueText: Math.round(AudioService.inputVolume * 100) + "%"
            value: AudioService.inputVolume
            reactiveEffect: root.microphoneSliderEffect
            reactiveActive: root.microphoneSignalActive
            reactiveLevel: root.microphoneSignalLevel
            reactiveValues: root.microphoneSpectrumValues
            enabled: AudioService.hasInput || AudioService.wpctlAvailable
            onMoved: value => AudioService.setInputVolume(value)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        AudioDeviceTile {
          Layout.fillWidth: true
          titleText: root.tr("outputDevice")
          valueText: root.nodeLabel(AudioService.sink)
          iconName: AudioService.muted ? "volume-off" : "volume"
          muted: AudioService.muted
          devices: root.audioDeviceOptions(AudioService.sinks)
          currentDeviceKey: root.nodeKey(AudioService.sink)
          onToggleMuted: AudioService.setOutputMuted(!AudioService.muted)
          onDeviceSelected: key => {
            const node = root.audioNodeByKey(AudioService.sinks, key);
            if (node)
              AudioService.setAudioSink(node);
          }
        }

        AudioDeviceTile {
          Layout.fillWidth: true
          titleText: root.tr("inputDevice")
          valueText: root.nodeLabel(AudioService.source)
          iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
          muted: AudioService.inputMuted
          devices: root.audioDeviceOptions(AudioService.sources)
          currentDeviceKey: root.nodeKey(AudioService.source)
          onToggleMuted: AudioService.setInputMuted(!AudioService.inputMuted)
          onDeviceSelected: key => {
            const node = root.audioNodeByKey(AudioService.sources, key);
            if (node)
              AudioService.setAudioSource(node);
          }
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              Layout.fillWidth: true
              text: root.tr("applicationVolumes")
              color: Color.mOnSurface
              font.weight: Style.fontWeightSemiBold
            }

            NText {
              text: AudioService.appStreams.length
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
            }
          }

          NText {
            visible: AudioService.appStreams.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.tr("noApplications")
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          Flickable {
            visible: AudioService.appStreams.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: appStreamsColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
              id: appStreamsColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: AudioService.appStreams

                AppVolumeRow {
                  Layout.fillWidth: true
                  streamNode: modelData
                }
              }
            }
          }
        }
      }
    }
  }

  component AudioDeviceTile: DashboardCard {
    id: audioDeviceTile

    property string titleText: ""
    property string valueText: ""
    property string iconName: ""
    property bool muted: false
    property var devices: []
    property string currentDeviceKey: ""
    signal toggleMuted
    signal deviceSelected(string key)

    Layout.preferredHeight: Math.round(102 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: audioDeviceTile.iconName
          pointSize: Style.fontSizeL
          color: audioDeviceTile.muted ? Color.mError : Color.mPrimary
        }

        NText {
          Layout.fillWidth: true
          text: audioDeviceTile.titleText
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          elide: Text.ElideRight
        }

        NIconButton {
          icon: audioDeviceTile.muted ? "volume-off" : "volume"
          baseSize: Math.round(26 * root.panelUnit)
          tooltipText: audioDeviceTile.muted ? I18n.tr("tooltips.unmute") : I18n.tr("tooltips.mute")
          onClicked: audioDeviceTile.toggleMuted()
        }
      }

      NComboBox {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(34 * root.panelUnit)
        model: audioDeviceTile.devices
        currentKey: audioDeviceTile.currentDeviceKey
        placeholder: audioDeviceTile.valueText
        minimumWidth: Math.max(88, audioDeviceTile.width - Style.marginM * 2)
        popupHeight: 240
        enabled: audioDeviceTile.devices.length > 0
        onSelected: key => audioDeviceTile.deviceSelected(key)
      }
    }
  }

  component AppVolumeRow: DashboardCard {
    id: appVolumeRow

    property var streamNode: null
    readonly property bool streamMuted: streamNode?.audio?.muted ?? false
    readonly property real streamVolume: streamNode?.audio?.volume ?? 0

    Layout.preferredHeight: Math.round(72 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.34)
    radius: Style.radiusS

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: appVolumeRow.streamMuted ? "volume-off" : "volume"
          pointSize: Style.fontSizeM
          color: appVolumeRow.streamMuted ? Color.mError : Color.mPrimary
        }

        NText {
          Layout.fillWidth: true
          text: root.nodeLabel(appVolumeRow.streamNode)
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }

        NText {
          text: Math.round(appVolumeRow.streamVolume * 100) + "%"
          color: Color.mOnSurfaceVariant
          font.family: Settings.data.ui.fontFixed
        }

        NIconButton {
          icon: appVolumeRow.streamMuted ? "volume-off" : "volume"
          baseSize: Math.round(26 * root.panelUnit)
          onClicked: AudioService.setPanelAppStreamMuted(appVolumeRow.streamNode, !appVolumeRow.streamMuted)
        }
      }

      NSlider {
        Layout.fillWidth: true
        from: 0
        to: AudioService.maxVolume
        stepSize: 0.01
        value: appVolumeRow.streamVolume
        enabled: appVolumeRow.streamNode !== null && appVolumeRow.streamNode.audio !== undefined
        onMoved: AudioService.setPanelAppStreamVolume(appVolumeRow.streamNode, value)
      }
    }
  }

  component MediaDetailsCard: DashboardCard {
    styleKey: "media"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        NText {
          Layout.fillWidth: true
          text: root.tr("media")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: MediaService.isPlaying ? root.tr("playing") : root.tr("idle")
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          color: MediaService.isPlaying ? Color.mPrimary : Color.mOnSurfaceVariant
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(178 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS
        clip: true

        MusicVisualizer {
          anchors.fill: parent
          anchors.margins: Math.round(4 * root.panelUnit)
          effect: root.mediaVisualizerEffect
          active: root.musicActive
          clipRadius: Math.max(0, Style.radiusS - Math.round(4 * root.panelUnit))
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NImageRounded {
            Layout.preferredWidth: Math.round(132 * root.panelUnit)
            Layout.preferredHeight: Math.round(132 * root.panelUnit)
            radius: Style.radiusS
            imagePath: MediaService.trackArtUrl
            fallbackIcon: "music"
            fallbackIconSize: Style.fontSizeXXXL
            borderColor: Qt.alpha(Color.mOutline, 0.18)
            borderWidth: Style.borderS
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginS

            NText {
              Layout.fillWidth: true
              text: MediaService.trackTitle || root.tr("nothingPlaying")
              color: Color.mOnSurface
              pointSize: Style.fontSizeXL
              font.weight: Style.fontWeightSemiBold
              elide: Text.ElideRight
            }

            NText {
              Layout.fillWidth: true
              text: MediaService.trackArtist || MediaService.playerIdentity || ""
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
              elide: Text.ElideRight
            }

            NText {
              Layout.fillWidth: true
              visible: MediaService.trackAlbum !== ""
              text: MediaService.trackAlbum
              color: Qt.alpha(Color.mOnSurfaceVariant, 0.78)
              pointSize: Style.fontSizeXS
              elide: Text.ElideRight
            }

            Item {
              Layout.fillHeight: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NIconButton {
                icon: "player-track-prev"
                baseSize: Math.round(34 * root.panelUnit)
                enabled: MediaService.canGoPrevious
                onClicked: MediaService.previous()
              }

              NIconButton {
                icon: MediaService.isPlaying ? "player-pause" : "player-play"
                baseSize: Math.round(42 * root.panelUnit)
                enabled: MediaService.currentPlayer !== null
                onClicked: MediaService.playPause()
              }

              NIconButton {
                icon: "player-track-next"
                baseSize: Math.round(34 * root.panelUnit)
                enabled: MediaService.canGoNext
                onClicked: MediaService.next()
              }
            }
          }
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(84 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          NSlider {
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0
            snapAlways: false
            enabled: MediaService.trackLength > 0 && MediaService.canSeek
            value: root.mediaProgressRatio()
            onMoved: MediaService.seekByRatio(value)
          }

          RowLayout {
            Layout.fillWidth: true

            NText {
              text: MediaService.positionString || "0:00"
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              font.family: Settings.data.ui.fontFixed
            }

            Item {
              Layout.fillWidth: true
            }

            NText {
              text: MediaService.lengthString || "0:00"
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              font.family: Settings.data.ui.fontFixed
            }
          }
        }
      }

      EasyEffectsCard {
        Layout.fillWidth: true
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: root.tr("players")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: playersColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
              id: playersColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: MediaService.getAvailablePlayers()

                PlayerRow {
                  Layout.fillWidth: true
                  playerData: modelData
                  playerIndex: index
                }
              }
            }
          }
        }
      }
    }
  }

  component EasyEffectsCard: DashboardCard {
    id: easyEffectsCard

    Layout.preferredHeight: Math.round(158 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "adjustments-horizontal"
          pointSize: Style.fontSizeL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            text: root.tr("easyEffects")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: root.activeEasyEffectsPreset !== "" ? root.activeEasyEffectsPreset : root.tr("easyEffectsNoActive")
            color: root.activeEasyEffectsPreset !== "" ? Color.mPrimary : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            elide: Text.ElideRight
          }
        }

        NIconButton {
          icon: "refresh"
          baseSize: Math.round(24 * root.panelUnit)
          tooltipText: root.tr("refresh")
          onClicked: root.refreshEasyEffects()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(54 * root.panelUnit)
        spacing: Style.marginS

        Repeater {
          model: 10

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real bandLevel: root.equalizerBandLevel(index, 10)

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              width: Math.max(4, Math.round(7 * root.panelUnit))
              height: Math.max(Math.round(8 * root.panelUnit), parent.height * bandLevel)
              radius: width / 2
              color: index % 2 === 0 ? Color.mPrimary : Color.mSecondary
              opacity: root.musicActive ? 0.86 : 0.42

              Behavior on height {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
              }

              Behavior on opacity {
                NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast }
              }
            }
          }
        }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: root.easyEffectsPresets.length > 0
        baseSize: 0.78
        model: root.easyEffectsPresetOptions()
        currentKey: root.activeEasyEffectsPreset
        placeholder: root.tr("easyEffectsPreset")
        minimumWidth: Math.max(180, easyEffectsCard.width - Style.marginM * 2)
        popupHeight: 220
        onSelected: key => root.applyEasyEffectsPreset(key)
      }

      NText {
        Layout.fillWidth: true
        visible: root.easyEffectsPresets.length === 0
        Layout.preferredHeight: Math.round(32 * root.panelUnit)
        text: root.easyEffectsStatus !== "" ? root.easyEffectsStatus : root.tr("easyEffectsNoPresets")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
    }
  }

  component PlayerRow: DashboardCard {
    id: playerRow

    property var playerData: null
    property int playerIndex: 0
    readonly property bool selected: playerIndex === MediaService.selectedPlayerIndex

    Layout.preferredHeight: Math.round(52 * root.panelUnit)
    color: selected ? Qt.alpha(Color.mPrimary, 0.14) : Qt.alpha(Color.mSurface, 0.32)
    radius: Style.radiusS
    border.color: selected ? Qt.alpha(Color.mPrimary, 0.38) : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NIcon {
        icon: selected ? "circle-filled" : "music"
        pointSize: Style.fontSizeM
        color: selected ? Color.mPrimary : Color.mOnSurfaceVariant
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: root.playerLabel(playerRow.playerData)
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: (playerRow.playerData?.trackTitle || root.tr("nothingPlaying"))
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }
      }
    }

    TapHandler {
      onTapped: MediaService.switchToPlayer(playerRow.playerIndex)
    }
  }

  component SystemControlsCard: DashboardCard {
    styleKey: "systemControls"
    styleRoot: true
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          Layout.fillWidth: true
          text: root.tr("system")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: root.componentText("systemControls", true)
          elide: Text.ElideRight
        }

        SubmoduleButton {
          targetView: "audio"
          tooltipText: root.tr("audioDetails")
        }
      }

      ControlSlider {
        iconName: AudioService.muted ? "volume-off" : "volume"
        labelText: root.tr("volume")
        valueText: Math.round(AudioService.volume * 100) + "%"
        value: AudioService.volume
        reactiveEffect: root.audioSliderEffect
        reactiveActive: root.musicActive
        reactiveLevel: root.musicActive ? root.spectrumAverage() : 0
        reactiveValues: SpectrumService.values
        enabled: AudioService.sink !== null || AudioService.wpctlAvailable
        onMoved: value => AudioService.setVolume(value)
      }

      ControlSlider {
        iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
        labelText: root.tr("microphone")
        valueText: Math.round(AudioService.inputVolume * 100) + "%"
        value: AudioService.inputVolume
        reactiveEffect: root.microphoneSliderEffect
        reactiveActive: root.microphoneSignalActive
        reactiveLevel: root.microphoneSignalLevel
        reactiveValues: root.microphoneSpectrumValues
        enabled: AudioService.hasInput || AudioService.wpctlAvailable
        onMoved: value => AudioService.setInputVolume(value)
      }

      ControlSlider {
        iconName: "brightness-up"
        labelText: root.tr("brightness")
        valueText: Math.round(root.currentBrightness() * 100) + "%"
        value: root.currentBrightness()
        enabled: BrightnessService.monitors.length > 0
        onMoved: value => BrightnessService.setBrightness(value)
      }

      Item {
        Layout.fillHeight: true
      }
    }

    TapHandler {
      acceptedButtons: Qt.RightButton
      onTapped: root.activeDetailView = "audio"
    }
  }

  component ControlSlider: ColumnLayout {
    id: controlSlider

    property string iconName: ""
    property string labelText: ""
    property string valueText: ""
    property real value: 0
    property string reactiveEffect: "none"
    property bool reactiveActive: false
    property real reactiveLevel: 0
    property var reactiveValues: []
    signal moved(real value)

    Layout.fillWidth: true
    spacing: Style.marginS
    opacity: enabled ? 1 : 0.45

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIcon {
        icon: iconName
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        text: labelText
        color: Color.mOnSurface
        font.weight: Style.fontWeightMedium
      }

      NText {
        text: valueText
        color: Color.mOnSurfaceVariant
        font.family: Settings.data.ui.fontFixed
      }
    }

    ReactiveSlider {
      Layout.fillWidth: true
      from: 0
      to: 1
      stepSize: 0.01
      value: controlSlider.value
      effect: controlSlider.reactiveEffect
      effectActive: controlSlider.reactiveActive
      effectLevel: controlSlider.reactiveLevel
      effectValues: controlSlider.reactiveValues
      onMoved: controlSlider.moved(value)
    }
  }

  component ReactiveSlider: Slider {
    id: reactiveSlider

    property string effect: "none"
    property bool effectActive: false
    property real effectLevel: 0
    property var effectValues: []

    readonly property real knobDiameter: Math.round((20 * root.panelUnit) / 2) * 2
    readonly property real baseTrackHeight: Math.max(6, Math.round(7 * root.panelUnit))
    readonly property real activeTrackHeight: Math.max(baseTrackHeight, Math.round((8 + root.clamp(effectLevel, 0, 1) * 8) * root.panelUnit))
    readonly property real visualTrackHeight: effectActive && effect !== "none" ? activeTrackHeight : baseTrackHeight
    readonly property real trackCanvasHeight: Math.max(knobDiameter, Math.round(26 * root.panelUnit))
    readonly property real fillRatio: root.clamp(visualPosition, 0, 1)

    Layout.preferredHeight: trackCanvasHeight
    padding: Math.round(3 * root.panelUnit)
    snapMode: Slider.SnapAlways
    implicitHeight: trackCanvasHeight

    onValueChanged: trackCanvas.requestPaint()
    onVisualPositionChanged: trackCanvas.requestPaint()
    onEffectChanged: trackCanvas.requestPaint()
    onEffectActiveChanged: trackCanvas.requestPaint()
    onEffectLevelChanged: trackCanvas.requestPaint()
    onEffectValuesChanged: trackCanvas.requestPaint()
    onEnabledChanged: trackCanvas.requestPaint()
    onWidthChanged: trackCanvas.requestPaint()
    onHeightChanged: trackCanvas.requestPaint()

    Connections {
      target: root
      function onSliderEffectPhaseChanged() {
        trackCanvas.requestPaint();
      }
    }

    background: Canvas {
      id: trackCanvas

      x: reactiveSlider.leftPadding
      y: reactiveSlider.topPadding + Style.pixelAlignCenter(reactiveSlider.availableHeight, reactiveSlider.trackCanvasHeight)
      width: reactiveSlider.availableWidth
      height: reactiveSlider.trackCanvasHeight
      antialiasing: true

      onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (width <= 0 || height <= 0)
          return;

        const centerY = height / 2;
        const inactiveAlpha = reactiveSlider.enabled ? 1 : 0.55;
        const active = reactiveSlider.effectActive && reactiveSlider.effect !== "none" && reactiveSlider.enabled;
        const activeW = width * reactiveSlider.fillRatio;
        const baseH = reactiveSlider.baseTrackHeight;
        const effectH = reactiveSlider.visualTrackHeight;
        const level = root.clamp(Number(reactiveSlider.effectLevel || 0), 0, 1);
        const values = reactiveSlider.effectValues || [];
        const valuesLen = values.length || 0;
        const phase = root.sliderEffectPhase;

        function rgba(c, alpha) {
          return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + alpha + ")";
        }

        function sample(position) {
          if (valuesLen <= 0)
            return 0;
          const index = Math.max(0, Math.min(valuesLen - 1, Math.round(position * (valuesLen - 1))));
          return root.clamp(Number(values[index] || 0), 0, 1);
        }

        function roundedRect(x, y, w, h, r) {
          const radius = Math.max(0, Math.min(r, w / 2, h / 2));
          ctx.moveTo(x + radius, y);
          ctx.lineTo(x + w - radius, y);
          ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
          ctx.lineTo(x + w, y + h - radius);
          ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
          ctx.lineTo(x + radius, y + h);
          ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
          ctx.lineTo(x, y + radius);
          ctx.quadraticCurveTo(x, y, x + radius, y);
        }

        function fillRoundedTrack(x, y, w, h, color) {
          ctx.fillStyle = color;
          ctx.beginPath();
          roundedRect(x, y, w, h, h / 2);
          ctx.fill();
        }

        fillRoundedTrack(0, centerY - baseH / 2, width, baseH, rgba(Color.mSurface, 0.54 * inactiveAlpha));
        ctx.strokeStyle = rgba(Color.mOutline, 0.46 * inactiveAlpha);
        ctx.lineWidth = Style.borderS;
        ctx.beginPath();
        roundedRect(0, centerY - baseH / 2, width, baseH, baseH / 2);
        ctx.stroke();

        const grad = ctx.createLinearGradient(0, 0, width, 0);
        grad.addColorStop(0, rgba(Color.mPrimary, active ? 0.84 : 0.9));
        grad.addColorStop(0.62, rgba(Color.mSecondary, active ? 0.78 : 0.86));
        grad.addColorStop(1, rgba(Color.mPrimary, active ? 0.92 : 1));

        if (activeW <= 0)
          return;

        if (!active) {
          fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, grad);
          return;
        }

        ctx.save();
        ctx.beginPath();
        roundedRect(0, centerY - effectH / 2, activeW, effectH, effectH / 2);
        ctx.clip();

        if (reactiveSlider.effect === "bars") {
          fillRoundedTrack(0, centerY - baseH / 2, activeW, baseH, rgba(Color.mPrimary, 0.24 + level * 0.16));
          const bars = 30;
          const slot = width / bars;
          for (let i = 0; i < bars; i++) {
            const p = i / Math.max(1, bars - 1);
            const amp = sample(p);
            const h = Math.max(baseH, baseH + amp * effectH * 1.25);
            const barW = Math.max(2, slot * 0.46);
            const x = i * slot + slot * 0.27;
            ctx.fillStyle = rgba(i % 2 === 0 ? Color.mPrimary : Color.mSecondary, 0.28 + amp * 0.56);
            ctx.beginPath();
            roundedRect(x, centerY - h / 2, barW, h, barW / 2);
            ctx.fill();
          }
        } else if (reactiveSlider.effect === "zigzag") {
          ctx.lineCap = "round";
          ctx.lineJoin = "round";
          ctx.lineWidth = Math.max(baseH, effectH * 0.62);
          ctx.strokeStyle = grad;
          ctx.beginPath();
          const steps = 18;
          const amp = Math.max(2, effectH * (0.28 + level * 0.5));
          for (let i = 0; i <= steps; i++) {
            const x = (i / steps) * width;
            const y = centerY + (i % 2 === 0 ? -amp : amp);
            if (i === 0)
              ctx.moveTo(x, y);
            else
              ctx.lineTo(x, y);
          }
          ctx.stroke();
        } else if (reactiveSlider.effect === "pulse") {
          const pulse = 0.5 + Math.sin(phase * 2.1) * 0.5;
          const h = root.clamp(baseH + effectH * (0.18 + level * 0.66 + pulse * 0.18), baseH, effectH * 1.22);
          fillRoundedTrack(0, centerY - h / 2, activeW, h, grad);
          ctx.fillStyle = rgba(Color.mSecondary, 0.1 + pulse * 0.16 + level * 0.14);
          ctx.beginPath();
          roundedRect(0, centerY - h / 2, activeW, h * 0.48, h * 0.24);
          ctx.fill();
        } else {
          ctx.lineCap = "round";
          ctx.lineJoin = "round";
          ctx.lineWidth = Math.max(baseH, effectH * 0.7);
          ctx.strokeStyle = grad;
          ctx.beginPath();
          const step = Math.max(3, width / 64);
          for (let x = 0; x <= width + step; x += step) {
            const p = x / Math.max(1, width);
            const amp = sample(p);
            const y = centerY + Math.sin(p * Math.PI * 4 + phase * 1.2) * (effectH * (0.12 + amp * 0.42 + level * 0.18));
            if (x === 0)
              ctx.moveTo(x, y);
            else
              ctx.lineTo(x, y);
          }
          ctx.stroke();
        }

        ctx.restore();

        ctx.fillStyle = rgba(Color.mPrimary, 0.1 + level * 0.12);
        ctx.beginPath();
        roundedRect(0, centerY - effectH / 2, activeW, effectH, effectH / 2);
        ctx.fill();
      }
    }

    handle: Item {
      implicitWidth: reactiveSlider.knobDiameter
      implicitHeight: reactiveSlider.knobDiameter
      x: reactiveSlider.leftPadding + reactiveSlider.visualPosition * (reactiveSlider.availableWidth - width)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: Math.min(Style.iRadiusL, width / 2)
        color: reactiveSlider.pressed ? Color.mHover : Color.mSurface
        border.color: reactiveSlider.enabled ? Color.mPrimary : Color.mOutline
        border.width: Style.borderL

        Behavior on color {
          ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast }
        }
      }
    }
  }

  component NotificationsCard: DashboardCard {
    styleKey: "notifications"
    styleRoot: true
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          Layout.fillWidth: true
          text: root.tr("notifications")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: root.componentText("notifications", true)
          elide: Text.ElideRight
        }

        NIconButton {
          icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
          tooltipText: root.tr("dnd")
          baseSize: Math.round(30 * root.panelUnit)
          colorBgHover: root.componentButtonBackground("notifications")
          colorFg: root.componentText("notifications", true)
          colorFgHover: root.componentButtonText("notifications")
          colorBorderHover: root.componentButtonBackground("notifications")
          onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
        }

        NIconButton {
          icon: "trash"
          tooltipText: root.tr("clearNotifications")
          baseSize: Math.round(30 * root.panelUnit)
          enabled: NotificationService.historyModel.count > 0
          colorBgHover: root.componentButtonBackground("notifications")
          colorFg: root.componentText("notifications", true)
          colorFgHover: root.componentButtonText("notifications")
          colorBorderHover: root.componentButtonBackground("notifications")
          onClicked: NotificationService.clearHistory()
        }

        SubmoduleButton {
          targetView: "notifications"
          tooltipText: root.tr("details")
        }
      }

      NText {
        visible: NotificationService.historyModel.count === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        text: root.tr("noNotifications")
        color: root.componentText("notifications", false)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: notificationsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: notificationsColumn
          width: parent.width
          spacing: Style.marginS

          Repeater {
            model: NotificationService.historyModel.count

            NotificationRow {
              Layout.fillWidth: true
              notificationData: NotificationService.historyModel.get(index)
            }
          }
        }
      }
    }
  }

  component NotificationsDetailsCard: DashboardCard {
    styleKey: "notifications"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        NText {
          Layout.fillWidth: true
          text: root.tr("notifications")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: NotificationService.historyModel.count
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          color: NotificationService.historyModel.count > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        DashboardCard {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(72 * root.panelUnit)
          color: Qt.alpha(Color.mSurface, 0.42)
          radius: Style.radiusS

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.preferredWidth: Math.round(24 * root.panelUnit)
              Layout.fillHeight: true

              NIcon {
                anchors.centerIn: parent
                icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
                pointSize: Style.fontSizeL
                color: NotificationService.doNotDisturb ? Color.mError : Color.mPrimary
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: Style.marginXXS

              NText {
                Layout.fillWidth: true
                text: root.tr("dnd")
                color: Color.mOnSurface
                font.weight: Style.fontWeightSemiBold
                elide: Text.ElideRight
              }

              NText {
                text: NotificationService.doNotDisturb ? root.tr("enabled") : root.tr("disabled")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
              }
            }

            NIconButton {
              icon: NotificationService.doNotDisturb ? "toggle-right" : "toggle-left"
              baseSize: Math.round(30 * root.panelUnit)
              onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
            }
          }
        }

        DashboardCard {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(72 * root.panelUnit)
          color: Qt.alpha(Color.mSurface, 0.42)
          radius: Style.radiusS

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: "trash"
              pointSize: Style.fontSizeXL
              color: NotificationService.historyModel.count > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXS

              NText {
                text: root.tr("clear")
                color: Color.mOnSurface
                font.weight: Style.fontWeightSemiBold
                elide: Text.ElideRight
              }

              NText {
                text: root.tr("openHistory")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
              }
            }

            NIconButton {
              icon: "x"
              baseSize: Math.round(30 * root.panelUnit)
              enabled: NotificationService.historyModel.count > 0
              onClicked: NotificationService.clearHistory()
            }
          }
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              Layout.fillWidth: true
              text: root.tr("openHistory")
              color: Color.mOnSurface
              font.weight: Style.fontWeightSemiBold
              elide: Text.ElideRight
            }

            NText {
              text: NotificationService.historyModel.count
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
            }
          }

          NText {
            visible: NotificationService.historyModel.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.tr("noNotifications")
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          Flickable {
            visible: NotificationService.historyModel.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: notificationDetailsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: notificationDetailsColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: NotificationService.historyModel.count

                NotificationRow {
                  Layout.fillWidth: true
                  notificationData: NotificationService.historyModel.get(index)
                }
              }
            }
          }
        }
      }
    }
  }

  component NotificationRow: DashboardCard {
    id: notificationRow

    property var notificationData: ({})
    readonly property bool isExpanded: root.expandedNotificationId === notificationData.id
    readonly property var actionsList: root.parseNotificationActions(notificationData.actionsJson)
    readonly property bool canExpand: root.notificationCanExpand(notificationData)

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(Math.round(66 * root.panelUnit), contentColumn.implicitHeight + Style.marginS * 2)
    color: isExpanded ? Qt.alpha(Color.mSurface, 0.52) : Qt.alpha(Color.mSurface, 0.28)
    radius: Style.radiusS
    border.color: isExpanded ? Qt.alpha(Color.mPrimary, 0.22) : Qt.alpha(Color.mOutline, 0.10)
    border.width: Style.borderS
    clip: true

    Behavior on Layout.preferredHeight {
      NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    Behavior on color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationFast; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NImageRounded {
          Layout.preferredWidth: Math.round(42 * root.panelUnit)
          Layout.preferredHeight: Math.round(42 * root.panelUnit)
          Layout.alignment: Qt.AlignTop
          radius: Math.min(Style.radiusL, width / 2)
          imagePath: notificationData.cachedImage || notificationData.originalImage || ""
          fallbackIcon: "bell"
          fallbackIconSize: Style.fontSizeXL
          borderColor: Qt.alpha(Color.mOutline, 0.12)
          borderWidth: Style.borderS
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.marginXXS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              Layout.preferredWidth: Math.round(6 * root.panelUnit)
              Layout.preferredHeight: Math.round(6 * root.panelUnit)
              Layout.alignment: Qt.AlignVCenter
              radius: width / 2
              visible: notificationData.urgency !== 1
              color: notificationData.urgency === 2 ? Color.mError : Color.mOnSurfaceVariant
            }

            NText {
              Layout.fillWidth: true
              text: notificationData.appName || "Unknown"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              font.weight: Style.fontWeightSemiBold
              elide: Text.ElideRight
            }

            NText {
              text: root.notificationTimeText(notificationData.timestamp)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
              horizontalAlignment: Text.AlignRight
            }
          }

          NText {
            Layout.fillWidth: true
            text: notificationData.summary || notificationData.body || ""
            color: Color.mOnSurface
            textFormat: Text.StyledText
            wrapMode: isExpanded ? Text.WordWrap : Text.NoWrap
            maximumLineCount: isExpanded ? 3 : 1
            elide: Text.ElideRight
            pointSize: Style.fontSizeS
          }

          TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
              if (notificationRow.isExpanded) {
                root.activateNotification(notificationData);
              } else if (notificationRow.canExpand) {
                root.expandedNotificationId = notificationData.id;
              } else {
                root.activateNotification(notificationData);
              }
            }
          }
        }

        NIconButton {
          icon: isExpanded ? "chevron-up" : "chevron-down"
          baseSize: Math.round(26 * root.panelUnit)
          tooltipText: isExpanded ? root.tr("collapseNotification") : root.tr("expandNotification")
          enabled: canExpand
          opacity: canExpand ? 1 : 0.35
          onClicked: root.expandedNotificationId = isExpanded ? "" : notificationData.id
        }

        NIconButton {
          icon: "x"
          baseSize: Math.round(26 * root.panelUnit)
          tooltipText: root.tr("removeNotification")
          onClicked: NotificationService.removeFromHistory(notificationData.id)
        }
      }

      NText {
        visible: isExpanded && String(notificationData.body || "").length > 0
        Layout.fillWidth: true
        text: notificationData.body || ""
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        textFormat: Text.StyledText
        wrapMode: Text.WordWrap
        maximumLineCount: 8
        onLinkActivated: link => Qt.openUrlExternally(link)
      }

      Flow {
        visible: isExpanded && actionsList.length > 0
        Layout.fillWidth: true
        spacing: Style.marginS

        Repeater {
          model: actionsList

          NButton {
            text: modelData.text || root.tr("notificationAction")
            icon: modelData.identifier === "default" ? "external-link" : ""
            fontSize: Style.fontSizeS
            implicitHeight: Math.round(26 * root.panelUnit)
            backgroundColor: Qt.alpha(Color.mPrimary, 0.16)
            textColor: Color.mOnSurface
            hoverColor: Color.mHover
            textHoverColor: Color.mOnHover
            onClicked: NotificationService.invokeAction(notificationData.id, modelData.identifier)
          }
        }
      }
    }
  }

  component MediaCard: DashboardCard {
    styleKey: "media"
    styleRoot: true
    id: mediaCard

    color: root.componentColor("media", "background", root.musicActive ? Qt.alpha(Color.mSurfaceVariant, 0.9) : Qt.alpha(Color.mSurfaceVariant, 0.82))
    border.color: borderEffectVisible ? Qt.alpha(root.componentAccent("media"), 0.42) : (root.musicActive ? Qt.alpha(root.componentAccent("media"), 0.32) : Qt.alpha(Color.mOutline, 0.16))
    clip: true

    Behavior on color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
      ColorAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    Rectangle {
      anchors.fill: parent
      radius: mediaCard.radius
      color: root.componentAccent("media")
      opacity: root.musicActive ? 0.04 : 0
      Behavior on opacity {
        NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
      }
    }

    MusicVisualizer {
      anchors.fill: parent
      anchors.margins: Math.round(4 * root.panelUnit)
      effect: root.mediaVisualizerEffect
      active: !root.dashboardPerformanceMode && root.musicActive
      clipRadius: Math.max(0, mediaCard.radius - Math.round(4 * root.panelUnit))
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginM

        NImageRounded {
          id: coverArt
          Layout.preferredWidth: Math.round(70 * root.panelUnit)
          Layout.preferredHeight: Math.round(70 * root.panelUnit)
          radius: Style.radiusS
          imagePath: MediaService.trackArtUrl
          fallbackIcon: "music"
          fallbackIconSize: Style.fontSizeXXL
          borderColor: Qt.alpha(Color.mOutline, 0.18)
          borderWidth: Style.borderS

          property string _lastTitle: MediaService.trackTitle
          on_LastTitleChanged: coverBounce.restart()

          SequentialAnimation on scale {
            id: coverBounce
            running: false
            NumberAnimation { to: 1.04; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.OutBounce }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.marginXXS

          NText {
            text: root.tr("media")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            font.weight: Style.fontWeightSemiBold
          }

          NText {
            Layout.fillWidth: true
            text: MediaService.trackTitle || root.tr("nothingPlaying")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: MediaService.trackArtist || MediaService.playerIdentity || ""
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            elide: Text.ElideRight
          }
        }

        RowLayout {
          spacing: Style.marginXS
          Layout.alignment: Qt.AlignVCenter

          NIconButton {
            icon: "player-track-prev"
            baseSize: Math.round(30 * root.panelUnit)
            enabled: MediaService.canGoPrevious
            onClicked: MediaService.previous()
          }

          NIconButton {
            icon: MediaService.isPlaying ? "player-pause" : "player-play"
            baseSize: Math.round(34 * root.panelUnit)
            enabled: MediaService.currentPlayer !== null
            onClicked: MediaService.playPause()
          }

          NIconButton {
            icon: "player-track-next"
            baseSize: Math.round(30 * root.panelUnit)
            enabled: MediaService.canGoNext
            onClicked: MediaService.next()
          }

          SubmoduleButton {
            targetView: "media"
            tooltipText: root.tr("details")
          }
        }
      }

      Item {
        id: mediaProgressWrapper

        visible: MediaService.currentPlayer !== null && MediaService.trackLength > 0
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.round(28 * root.panelUnit) : 0

        property real localSeekRatio: -1
        property real lastSentSeekRatio: -1
        property real seekEpsilon: 0.01
        property real progressRatio: {
          if (!MediaService.currentPlayer || MediaService.trackLength <= 0)
            return 0;
          const r = MediaService.currentPosition / MediaService.trackLength;
          if (isNaN(r) || !isFinite(r))
            return 0;
          return Math.max(0, Math.min(1, r));
        }

        Timer {
          id: mediaSeekDebounce
          interval: 75
          repeat: false
          onTriggered: {
            if (MediaService.isSeeking && mediaProgressWrapper.localSeekRatio >= 0) {
              const next = Math.max(0, Math.min(1, mediaProgressWrapper.localSeekRatio));
              if (mediaProgressWrapper.lastSentSeekRatio < 0 || Math.abs(next - mediaProgressWrapper.lastSentSeekRatio) >= mediaProgressWrapper.seekEpsilon) {
                MediaService.seekByRatio(next);
                mediaProgressWrapper.lastSentSeekRatio = next;
              }
            }
          }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          NSlider {
            id: mediaProgressSlider
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(16 * root.panelUnit)
            from: 0
            to: 1
            stepSize: 0
            snapAlways: false
            enabled: MediaService.trackLength > 0 && MediaService.canSeek
            heightRatio: 0.36
            value: (!MediaService.isSeeking) ? mediaProgressWrapper.progressRatio : (mediaProgressWrapper.localSeekRatio >= 0 ? mediaProgressWrapper.localSeekRatio : 0)

            onMoved: {
              mediaProgressWrapper.localSeekRatio = value;
              mediaSeekDebounce.restart();
            }

            onPressedChanged: {
              if (pressed) {
                MediaService.isSeeking = true;
                mediaProgressWrapper.localSeekRatio = value;
                MediaService.seekByRatio(value);
                mediaProgressWrapper.lastSentSeekRatio = value;
              } else {
                mediaSeekDebounce.stop();
                MediaService.seekByRatio(value);
                MediaService.isSeeking = false;
                mediaProgressWrapper.localSeekRatio = -1;
                mediaProgressWrapper.lastSentSeekRatio = -1;
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
              text: MediaService.positionString || "0:00"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
            }

            Item {
              Layout.fillWidth: true
            }

            NText {
              text: MediaService.lengthString || "0:00"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              font.family: Settings.data.ui.fontFixed
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }
    }
  }

  component MusicVisualizer: Item {
    id: visualizer

    property string effect: "bars"
    property bool active: false
    property var values: SpectrumService.values
    property real phase: 0
    property real clipRadius: 0

    visible: effect !== "none"
    opacity: active ? 1 : 0.24

    Behavior on opacity {
      NumberAnimation { duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal; easing.type: Easing.OutCubic }
    }

    onValuesChanged: {
      visualizer.phase += 0.18;
      visualCanvas.requestPaint();
    }

    onEffectChanged: visualCanvas.requestPaint()
    onActiveChanged: visualCanvas.requestPaint()

    function sample(index, fallback) {
      if (!values)
        return fallback;
      const len = values.length;
      if (len === undefined || len === 0)
        return fallback;
      const safeIndex = Math.max(0, Math.min(len - 1, Math.round(index)));
      const value = Number(values[safeIndex] || 0);
      return root.clamp(value, 0, 1);
    }

    function average() {
      if (!values)
        return 0;
      const len = values.length;
      if (len === undefined || len === 0)
        return 0;
      let total = 0;
      for (let i = 0; i < len; i++)
        total += Number(values[i] || 0);
      return root.clamp(total / len, 0, 1);
    }

    function colorToRgba(c, alpha) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + alpha + ")";
    }

    function roundedRect(ctx, x, y, w, h, r) {
      const radius = Math.max(0, Math.min(r, w / 2, h / 2));
      ctx.moveTo(x + radius, y);
      ctx.lineTo(x + w - radius, y);
      ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
      ctx.lineTo(x + w, y + h - radius);
      ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
      ctx.lineTo(x + radius, y + h);
      ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
      ctx.lineTo(x, y + radius);
      ctx.quadraticCurveTo(x, y, x + radius, y);
    }

    Canvas {
      id: visualCanvas
      anchors.fill: parent
      antialiasing: true

      onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (visualizer.effect === "none" || width <= 0 || height <= 0)
          return;

        ctx.save();
        try {
        if (visualizer.clipRadius > 0) {
          ctx.beginPath();
          visualizer.roundedRect(ctx, 0, 0, width, height, visualizer.clipRadius);
          ctx.clip();
        }

        const t = visualizer.phase;
        const avg = visualizer.average();
        const beat = visualizer.active ? root.clamp(0.25 + avg * 1.8, 0.25, 1.35) : 0.16;
        
        const primary = Color.mPrimary;
        const secondary = Color.mSecondary;
        const tertiary = Color.mTertiary;

        if (visualizer.effect === "bars") {
          const bars = 24;
          const gap = 4;
          const barWidth = Math.max(2, (width - gap * (bars - 1)) / bars);
          for (let i = 0; i < bars; i++) {
            const sampleIndex = (i / Math.max(1, bars - 1)) * ((visualizer.values?.length ?? 1) - 1);
            const level = root.clamp(0.08 + visualizer.sample(sampleIndex, 0) * beat, 0.06, 0.92);
            const h = height * level;
            const x = i * (barWidth + gap);
            const y = height - h;
            
            const grad = ctx.createLinearGradient(x, y, x, height);
            grad.addColorStop(0, visualizer.colorToRgba(primary, 0.08 + level * 0.4));
            grad.addColorStop(1, visualizer.colorToRgba(secondary, 0.08 + level * 0.2));
            ctx.fillStyle = grad;
            
            ctx.beginPath();
            visualizer.roundedRect(ctx, x, y, barWidth, h, barWidth / 2);
            ctx.fill();
            
            ctx.fillStyle = visualizer.colorToRgba(primary, 0.2 + level * 0.5);
            ctx.beginPath();
            ctx.arc(x + barWidth/2, y + barWidth/2, barWidth/2, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }

        if (visualizer.effect === "wave") {
          ctx.lineWidth = Math.max(1.5, 2.5 * root.panelUnit);
          
          ctx.strokeStyle = visualizer.colorToRgba(secondary, visualizer.active ? 0.2 : 0.1);
          ctx.beginPath();
          for (let x = 0; x <= width; x += 4) {
            const p = x / width;
            const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
            const amp = height * (0.03 + visualizer.sample(sampleIndex, 0) * 0.25 * beat);
            const y = height * 0.5 + Math.sin(p * Math.PI * 3 + t * 0.8) * amp;
            if (x === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
          }
          ctx.stroke();

          ctx.strokeStyle = visualizer.colorToRgba(primary, visualizer.active ? 0.45 : 0.2);
          ctx.beginPath();
          for (let x = 0; x <= width; x += 4) {
            const p = x / width;
            const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
            const amp = height * (0.05 + visualizer.sample(sampleIndex, 0) * 0.36 * beat);
            const y = height * 0.5 + Math.sin(p * Math.PI * 4 + t) * amp;
            if (x === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
          }
          ctx.stroke();
          
          ctx.lineTo(width, height);
          ctx.lineTo(0, height);
          ctx.closePath();
          const grad = ctx.createLinearGradient(0, height * 0.5, 0, height);
          grad.addColorStop(0, visualizer.colorToRgba(primary, 0.1));
          grad.addColorStop(1, visualizer.colorToRgba(primary, 0.0));
          ctx.fillStyle = grad;
          ctx.fill();
          
          return;
        }

        if (visualizer.effect === "shock") {
          const cx = width * 0.5;
          const cy = height * 0.5;
          const maxR = Math.max(width, height) * 0.9;
          
          for (let i = 0; i < 5; i++) {
            const progress = (t * (0.06 + avg * 0.16) + i * 0.2) % 1;
            const radius = 16 + progress * maxR;
            const colors = [primary, secondary, tertiary];
            const color = colors[i % 3];
            
            ctx.lineWidth = Math.max(1, (1.4 + beat * 2 * (1-progress)) * root.panelUnit);
            
            ctx.strokeStyle = visualizer.colorToRgba(color, (1 - progress) * (visualizer.active ? 0.42 : 0.12));
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.stroke();
          }
          return;
        }

        if (visualizer.effect === "pulse") {
          for (let i = 0; i < 38; i++) {
            const sampleIndex = (i / 37) * ((visualizer.values?.length ?? 1) - 1);
            const amp = visualizer.sample(sampleIndex, 0);
            const p = (i * 0.618 + t * 0.03) % 1;
            const x = width * ((i * 37 % 101) / 100);
            const y = height * ((Math.sin(i * 7.3 + t) + 1) / 2);
            const r = 1.2 + 7 * amp * beat;
            
            const colors = [primary, secondary, tertiary];
            const color = colors[i % 3];
            
            if (amp > 0.4 && visualizer.active) {
                for(let j=0; j<5; j++) {
                    const jx = width * (((i+j) * 37 % 101) / 100);
                    const jy = height * ((Math.sin((i+j) * 7.3 + t) + 1) / 2);
                    const dist = Math.sqrt(Math.pow(x-jx, 2) + Math.pow(y-jy, 2));
                    if(dist < 50) {
                        ctx.strokeStyle = visualizer.colorToRgba(color, 0.05 + amp*0.1);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(x, y);
                        ctx.lineTo(jx, jy);
                        ctx.stroke();
                    }
                }
            }

            ctx.fillStyle = visualizer.colorToRgba(color, 0.04 + p * 0.1);
            ctx.beginPath();
            ctx.arc(x, y, r * 2.5, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = visualizer.colorToRgba(color, 0.2 + p * 0.3);
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.fill();
          }
          return;
        }
        
        if (visualizer.effect === "nebula") {
           for (let i = 0; i < 6; i++) {
               const sampleIndex = (i / 5) * ((visualizer.values?.length ?? 1) - 1);
               const amp = visualizer.sample(sampleIndex, 0.2);
               const x = width * (0.2 + 0.6 * ((i * 1.618 + t * 0.02) % 1));
               const y = height * (0.2 + 0.6 * ((i * 2.718 + Math.sin(t * 0.05)) % 1));
               const r = Math.max(width, height) * 0.3 * (1 + amp * beat * 0.5);
               
               const colors = [primary, secondary, tertiary];
               const color = colors[i % 3];
               
               const grad = ctx.createRadialGradient(x, y, 0, x, y, r);
               grad.addColorStop(0, visualizer.colorToRgba(color, 0.15 + amp * 0.15));
               grad.addColorStop(1, visualizer.colorToRgba(color, 0));
               
               ctx.fillStyle = grad;
               ctx.beginPath();
               ctx.arc(x, y, r, 0, Math.PI * 2);
               ctx.fill();
           }
           return;
        }
        
        if (visualizer.effect === "aurora") {
            const bands = 3;
            for(let b=0; b<bands; b++) {
                const colors = [primary, secondary, tertiary];
                const color = colors[b % 3];
                
                ctx.beginPath();
                ctx.moveTo(0, height);
                
                for(let x=0; x<=width; x+=10) {
                    const p = x / width;
                    const sampleIndex = p * ((visualizer.values?.length ?? 1) - 1);
                    const amp = visualizer.sample(sampleIndex, 0);
                    
                    const wave1 = Math.sin(p * Math.PI * 2 + t * 0.5 + b * 2);
                    const wave2 = Math.sin(p * Math.PI * 4 - t * 0.3 + b);
                    const y = height * 0.5 + (wave1 * 0.3 + wave2 * 0.2) * height * (1 + amp * beat);
                    
                    ctx.lineTo(x, y);
                }
                
                ctx.lineTo(width, height);
                ctx.closePath();
                
                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, visualizer.colorToRgba(color, 0));
                grad.addColorStop(0.5, visualizer.colorToRgba(color, 0.1 + b * 0.05 + beat * 0.05));
                grad.addColorStop(1, visualizer.colorToRgba(color, 0.02));
                
                ctx.fillStyle = grad;
                ctx.fill();
            }
            return;
        }
        
        if (visualizer.effect === "constellation") {
            const nodes = 30;
            const points = [];
            for(let i=0; i<nodes; i++) {
                const px = ((i * 137.5) % 100) / 100 * width;
                const py = ((i * 93.1) % 100) / 100 * height;
                points.push({x: px, y: py, i: i});
            }
            
            ctx.lineWidth = 1;
            for(let i=0; i<nodes; i++) {
                const p1 = points[i];
                for(let j=i+1; j<nodes; j++) {
                    const p2 = points[j];
                    const dist = Math.sqrt(Math.pow(p1.x-p2.x, 2) + Math.pow(p1.y-p2.y, 2));
                    if(dist < width * 0.3) {
                        const sampleIndex = ((i+j) / (nodes*2)) * ((visualizer.values?.length ?? 1) - 1);
                        const amp = visualizer.sample(sampleIndex, 0);
                        
                        if(amp > 0.3) {
                            ctx.strokeStyle = visualizer.colorToRgba(secondary, (1 - dist/(width*0.3)) * amp * beat * 0.5);
                            ctx.beginPath();
                            ctx.moveTo(p1.x, p1.y);
                            ctx.lineTo(p2.x, p2.y);
                            ctx.stroke();
                        }
                    }
                }
            }
            
            for(let i=0; i<nodes; i++) {
                const p = points[i];
                const sampleIndex = (i / nodes) * ((visualizer.values?.length ?? 1) - 1);
                const amp = visualizer.sample(sampleIndex, 0);
                
                const r = 1 + amp * 4 * beat;
                ctx.fillStyle = visualizer.colorToRgba(primary, 0.3 + amp * 0.7);
                ctx.beginPath();
                ctx.arc(p.x, p.y, r, 0, Math.PI*2);
                ctx.fill();
            }
            return;
        }
        
        if (visualizer.effect === "radar") {
            const cx = width / 2;
            const cy = height + 10;
            const r = Math.max(width, height);
            
            const sweepAngle = Math.PI + (t * 0.8) % Math.PI;
            
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.arc(cx, cy, r, sweepAngle - 0.5, sweepAngle);
            ctx.closePath();
            
            ctx.fillStyle = visualizer.colorToRgba(primary, 0.15);
            ctx.fill();
            
            for(let i=0; i<30; i++) {
                const sampleIndex = (i / 30) * ((visualizer.values?.length ?? 1) - 1);
                const amp = visualizer.sample(sampleIndex, 0);
                
                if(amp > 0.4) {
                    const blipAngle = Math.PI + (i / 30) * Math.PI;
                    const blipDist = amp * r * 0.9;
                    const bx = cx + Math.cos(blipAngle) * blipDist;
                    const by = cy + Math.sin(blipAngle) * blipDist;
                    
                    const age = (sweepAngle - blipAngle + Math.PI*2) % (Math.PI*2);
                    if(age < Math.PI) {
                        const alpha = Math.max(0, 1 - age/Math.PI);
                        ctx.fillStyle = visualizer.colorToRgba(tertiary, alpha * beat);
                        ctx.beginPath();
                        ctx.arc(bx, by, 3 + amp*3, 0, Math.PI*2);
                        ctx.fill();
                    }
                }
            }
            
            ctx.strokeStyle = visualizer.colorToRgba(primary, 0.1);
            ctx.lineWidth = 1;
            for(let i=1; i<=3; i++) {
                ctx.beginPath();
                ctx.arc(cx, cy, r * (i/3), Math.PI, Math.PI*2);
                ctx.stroke();
            }
            return;
        }
        } finally {
          ctx.restore();
        }
      }
    }
  }

  component ReactiveRoundedImage: Item {
    id: reactiveImage

    property real radius: 0
    property string imagePath: ""
    property string fallbackIcon: ""
    property real fallbackIconSize: Style.fontSizeXXL
    property bool animatedPlaying: true
    property bool framed: true
    property int imageFillMode: Image.PreserveAspectCrop

    readonly property bool isAnimated: imagePath.toLowerCase().endsWith(".gif")
    readonly property Item imageSource: imageSourceLoader.item
    readonly property bool showFallback: fallbackIcon !== "" && (imagePath === "" || (imageSource && imageSource.status === Image.Error))
    readonly property int status: imageSource ? imageSource.status : Image.Null

    Rectangle {
      anchors.fill: parent
      radius: reactiveImage.radius
      color: (reactiveImage.framed || reactiveImage.showFallback) ? Qt.alpha(Color.mSurface, 0.28) : "transparent"
      border.width: (reactiveImage.framed || reactiveImage.showFallback) ? Style.borderS : 0
      border.color: Qt.alpha(Color.mOutline, 0.18)

      Loader {
        id: imageSourceLoader
        anchors.fill: parent
        active: reactiveImage.imagePath !== ""
        sourceComponent: reactiveImage.isAnimated ? animatedImageComponent : staticImageComponent
      }

      Component {
        id: staticImageComponent
        Image {
          visible: false
          source: reactiveImage.imagePath
          mipmap: true
          smooth: true
          asynchronous: true
          antialiasing: true
          fillMode: reactiveImage.imageFillMode
        }
      }

      Component {
        id: animatedImageComponent
        AnimatedImage {
          visible: false
          source: reactiveImage.imagePath
          playing: reactiveImage.animatedPlaying
          mipmap: true
          smooth: true
          asynchronous: true
          antialiasing: true
          fillMode: reactiveImage.imageFillMode
        }
      }

      ShaderEffectSource {
        id: safeFallback
        sourceItem: Rectangle {
          width: 1
          height: 1
          color: "transparent"
        }
        visible: false
        live: false
      }

      ShaderEffect {
        anchors.fill: parent
        visible: !reactiveImage.showFallback && reactiveImage.imageSource !== null && reactiveImage.status === Image.Ready
        property var source: reactiveImage.imageSource ?? safeFallback
        property real itemWidth: width
        property real itemHeight: height
        property real sourceWidth: reactiveImage.imageSource?.sourceSize.width ?? 0
        property real sourceHeight: reactiveImage.imageSource?.sourceSize.height ?? 0
        property real cornerRadius: reactiveImage.radius
        property real imageOpacity: 1.0
        property int fillMode: reactiveImage.imageFillMode

        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/rounded_image.frag.qsb")
        supportsAtlasTextures: false
        blending: true
      }

      NIcon {
        anchors.fill: parent
        visible: reactiveImage.showFallback
        icon: reactiveImage.fallbackIcon
        pointSize: reactiveImage.fallbackIconSize
        color: Color.mOnSurfaceVariant
      }
    }
  }

  component WeatherDetailsCard: DashboardCard {
    styleKey: "calendar"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"
    clip: true

    readonly property bool weatherReady: Settings.data.location.weatherEnabled && LocationService.data.weather !== null
    readonly property var weatherData: weatherReady ? LocationService.data.weather : null
    readonly property var currentWeather: weatherReady ? weatherData.current_weather : null
    readonly property var currentDetails: weatherReady ? weatherData.current : null
    readonly property var dailyWeather: weatherReady ? weatherData.daily : null

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        NText {
          Layout.fillWidth: true
          text: root.tr("weather")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: weatherReady ? root.tr("live") : root.tr("idle")
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          color: weatherReady ? Color.mPrimary : Color.mOnSurfaceVariant
        }
      }

      WeatherCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(218 * root.panelUnit)
        forecastDays: 5
        showLocation: true
        radius: Style.radiusS
        color: Qt.alpha(Color.mSurface, 0.42)
        border.color: "transparent"
      }

      NText {
        visible: !weatherReady
        Layout.fillWidth: true
        Layout.fillHeight: true
        text: root.tr("noWeather")
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      GridLayout {
        visible: weatherReady
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginM
        rowSpacing: Style.marginM

        WeatherInfoTile {
          Layout.fillWidth: true
          iconName: "temperature"
          titleText: root.tr("temperature")
          valueText: root.weatherTemperature(currentWeather?.temperature)
        }

        WeatherInfoTile {
          Layout.fillWidth: true
          iconName: "wind"
          titleText: root.tr("wind")
          valueText: Math.round(Number(currentWeather?.windspeed || 0)) + " km/h"
        }

        WeatherInfoTile {
          Layout.fillWidth: true
          iconName: "droplet"
          titleText: root.tr("humidity")
          valueText: currentDetails?.relativehumidity_2m !== undefined ? Math.round(Number(currentDetails.relativehumidity_2m)) + "%" : "--"
        }

        WeatherInfoTile {
          Layout.fillWidth: true
          iconName: "clock"
          titleText: root.tr("timezone")
          valueText: weatherData?.timezone_abbreviation || "--"
        }

        WeatherInfoTile {
          Layout.fillWidth: true
          iconName: "sunrise"
          titleText: root.tr("sunrise")
          valueText: root.weatherTimeLabel(dailyWeather?.sunrise?.[0])
        }

        WeatherInfoTile {
          Layout.fillWidth: true
          iconName: "sunset"
          titleText: root.tr("sunset")
          valueText: root.weatherTimeLabel(dailyWeather?.sunset?.[0])
        }
      }

      DashboardCard {
        visible: weatherReady
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: root.tr("forecast")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: forecastColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: forecastColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: dailyWeather?.time ? Math.min(7, dailyWeather.time.length) : 0

                WeatherForecastRow {
                  Layout.fillWidth: true
                  dayIndex: index
                  dailyData: dailyWeather
                }
              }
            }
          }
        }
      }
    }
  }

  component WeatherInfoTile: DashboardCard {
    id: weatherInfoTile

    property string iconName: ""
    property string titleText: ""
    property string valueText: ""

    Layout.preferredHeight: Math.round(62 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NIcon {
        icon: weatherInfoTile.iconName
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: weatherInfoTile.titleText
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: weatherInfoTile.valueText
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }
      }
    }
  }

  component WeatherForecastRow: DashboardCard {
    id: forecastRow

    property int dayIndex: 0
    property var dailyData: null

    Layout.preferredHeight: Math.round(54 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.32)
    radius: Style.radiusS

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        Layout.preferredWidth: Math.round(48 * root.panelUnit)
        text: root.weatherDayLabel(forecastRow.dailyData?.time?.[forecastRow.dayIndex])
        color: Color.mOnSurface
        font.weight: Style.fontWeightSemiBold
      }

      NIcon {
        icon: LocationService.weatherSymbolFromCode(forecastRow.dailyData?.weathercode?.[forecastRow.dayIndex] || 0)
        pointSize: Style.fontSizeXL
        color: Color.mPrimary
      }

      Item {
        Layout.fillWidth: true
      }

      NText {
        text: root.weatherTemperature(forecastRow.dailyData?.temperature_2m_max?.[forecastRow.dayIndex])
        color: Color.mOnSurface
        font.weight: Style.fontWeightSemiBold
      }

      NText {
        text: root.weatherTemperature(forecastRow.dailyData?.temperature_2m_min?.[forecastRow.dayIndex])
        color: Color.mOnSurfaceVariant
      }
    }
  }

  component CalendarDetailsCard: DashboardCard {
    styleKey: "calendar"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        NText {
          Layout.fillWidth: true
          text: root.tr("calendar")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          text: I18n.locale.toString(Time.now, "ddd, dd")
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          color: Color.mPrimary
        }
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: calendarDetailsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: calendarDetailsColumn
          width: parent.width
          spacing: Style.marginM

          CalendarHeaderCard {
            Layout.fillWidth: true
          }

          CalendarMonthCard {
            Layout.fillWidth: true
          }
        }
      }
    }
  }

  component CalendarShell: DashboardCard {
    id: calendarShell
    styleKey: "calendar"
    styleRoot: true

    clip: true

    SwipeView {
      id: calendarSwipe
      anchors.fill: parent
      anchors.margins: Style.marginS
      anchors.bottomMargin: Math.round(18 * root.panelUnit)
      currentIndex: 0
      clip: true
      interactive: true

      Item {
        WeatherCard {
          anchors.fill: parent
          forecastDays: 5
          showLocation: false
          radius: Style.radiusS
          color: Qt.alpha(Color.mSurface, 0.42)
          border.color: "transparent"
        }

        SubmoduleButton {
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: Style.marginM
          anchors.rightMargin: Style.marginM
          targetView: "weather"
          tooltipText: root.tr("details")
        }
      }

      Item {
        CompactCalendarPage {
          anchors.fill: parent
        }
      }

      Item {
        ScreenUsagePage {
          anchors.fill: parent
        }
      }
    }

    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => {
                 if (event.angleDelta.y > 0)
                   calendarSwipe.currentIndex = Math.max(0, calendarSwipe.currentIndex - 1);
                 else if (event.angleDelta.y < 0)
                   calendarSwipe.currentIndex = Math.min(calendarSwipe.count - 1, calendarSwipe.currentIndex + 1);
                 event.accepted = calendarSwipe.count > 1;
               }
    }

    PageDots {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.marginS
      count: calendarSwipe.count
      currentIndex: calendarSwipe.currentIndex
      onSelected: index => calendarSwipe.currentIndex = index
    }
  }

  component ScreenUsageDetailsCard: DashboardCard {
    id: screenUsageDetails
    styleKey: "screenUsage"
    styleRoot: true
    detailTransition: true
    detailTransitionDirection: "right"

    readonly property var allApps: root.screenUsageTopApps(-1, root.screenUsageRangeDays)
    readonly property int maxAppSeconds: root.screenUsageMaxAppSeconds(allApps)

    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(30 * root.panelUnit)
          tooltipText: root.tr("back")
          onClicked: root.activeDetailView = ""
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            text: root.tr("screenUsage")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: root.tr("trackedToday")
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
          }
        }

        NText {
          text: root.durationText(root.screenUsageTotalForRange(root.screenUsageRangeDays))
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          font.family: Settings.data.ui.fontFixed
          color: Color.mPrimary
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        ScreenUsageRangeButton {
          Layout.fillWidth: true
          labelText: root.tr("today")
          days: 1
        }

        ScreenUsageRangeButton {
          Layout.fillWidth: true
          labelText: root.tr("threeDays")
          days: 3
        }

        ScreenUsageRangeButton {
          Layout.fillWidth: true
          labelText: root.tr("fourteenDays")
          days: 14
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(94 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: root.screenUsageRangeDays === 1 ? root.tr("totalToday") : root.tr("totalRange")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
            }

            NText {
              text: root.durationText(root.screenUsageTotalForRange(root.screenUsageRangeDays))
              color: Color.mOnSurface
              pointSize: Style.fontSizeXXL
              font.weight: Style.fontWeightBold
              font.family: Settings.data.ui.fontFixed
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: root.tr("appsTracked")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              horizontalAlignment: Text.AlignRight
              Layout.alignment: Qt.AlignRight
            }

            NText {
              text: String(screenUsageDetails.allApps.length)
              color: Color.mOnSurface
              pointSize: Style.fontSizeXXL
              font.weight: Style.fontWeightBold
              font.family: Settings.data.ui.fontFixed
              horizontalAlignment: Text.AlignRight
              Layout.alignment: Qt.AlignRight
            }
          }
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(Color.mSurface, 0.42)
        radius: Style.radiusS

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            text: root.tr("allApps")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: screenUsageDetailsColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
              id: screenUsageDetailsColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: screenUsageDetails.allApps

                ScreenUsageDetailRow {
                  Layout.fillWidth: true
                  appData: modelData
                  maxSeconds: screenUsageDetails.maxAppSeconds
                }
              }
            }
          }

          NText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: screenUsageDetails.allApps.length === 0
            text: root.tr("screenUsageEmpty")
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component CompactCalendarPage: Item {
    id: compactCalendar

    readonly property var now: Time.now
    property int calendarMonth: now.getMonth()
    property int calendarYear: now.getFullYear()
    readonly property int firstDayOfWeek: Settings.data.location.firstDayOfWeek === -1 ? I18n.locale.firstDayOfWeek : Settings.data.location.firstDayOfWeek

    function navigate(delta) {
      const date = new Date(calendarYear, calendarMonth + delta, 1);
      calendarMonth = date.getMonth();
      calendarYear = date.getFullYear();
    }

    function today() {
      calendarMonth = now.getMonth();
      calendarYear = now.getFullYear();
    }

    function daysModel() {
      const firstOfMonth = new Date(calendarYear, calendarMonth, 1);
      const lastOfMonth = new Date(calendarYear, calendarMonth + 1, 0);
      const daysInMonth = lastOfMonth.getDate();
      const firstOfMonthDayOfWeek = firstOfMonth.getDay();
      const daysBefore = (firstOfMonthDayOfWeek - firstDayOfWeek + 7) % 7;
      const days = [];
      const todayDate = new Date();
      const prevMonth = new Date(calendarYear, calendarMonth, 0);

      for (let i = daysBefore - 1; i >= 0; i--) {
        days.push({
                    "day": prevMonth.getDate() - i,
                    "month": calendarMonth - 1,
                    "year": calendarMonth === 0 ? calendarYear - 1 : calendarYear,
                    "today": false,
                    "currentMonth": false
                  });
      }

      for (let day = 1; day <= daysInMonth; day++) {
        const date = new Date(calendarYear, calendarMonth, day);
        days.push({
                    "day": day,
                    "month": calendarMonth,
                    "year": calendarYear,
                    "today": date.getFullYear() === todayDate.getFullYear() && date.getMonth() === todayDate.getMonth() && date.getDate() === todayDate.getDate(),
                    "currentMonth": true
                  });
      }

      for (let day = 1; days.length < 42; day++) {
        days.push({
                    "day": day,
                    "month": calendarMonth + 1,
                    "year": calendarMonth === 11 ? calendarYear + 1 : calendarYear,
                    "today": false,
                    "currentMonth": false
                  });
      }

      return days;
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(30 * root.panelUnit)
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: I18n.locale.monthName(compactCalendar.calendarMonth, Locale.LongFormat).toUpperCase() + " " + compactCalendar.calendarYear
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: root.componentText("calendar", true)
          elide: Text.ElideRight
        }

        NIconButton {
          icon: "chevron-left"
          baseSize: Math.round(28 * root.panelUnit)
          colorBgHover: root.componentButtonBackground("calendar")
          colorFg: root.componentText("calendar", true)
          colorFgHover: root.componentButtonText("calendar")
          colorBorderHover: root.componentButtonBackground("calendar")
          onClicked: compactCalendar.navigate(-1)
        }

        NIconButton {
          icon: "calendar"
          baseSize: Math.round(28 * root.panelUnit)
          colorBgHover: root.componentButtonBackground("calendar")
          colorFg: root.componentText("calendar", true)
          colorFgHover: root.componentButtonText("calendar")
          colorBorderHover: root.componentButtonBackground("calendar")
          onClicked: compactCalendar.today()
        }

        NIconButton {
          icon: "chevron-right"
          baseSize: Math.round(28 * root.panelUnit)
          colorBgHover: root.componentButtonBackground("calendar")
          colorFg: root.componentText("calendar", true)
          colorFgHover: root.componentButtonText("calendar")
          colorBorderHover: root.componentButtonBackground("calendar")
          onClicked: compactCalendar.navigate(1)
        }

        SubmoduleButton {
          targetView: "calendar"
          tooltipText: root.tr("details")
        }
      }

      GridLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(20 * root.panelUnit)
        columns: 7
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
          model: 7

          NText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: I18n.locale.dayName((compactCalendar.firstDayOfWeek + index) % 7, Locale.ShortFormat).substring(0, 2).toUpperCase()
            color: root.componentAccent("calendar")
            pointSize: Style.fontSizeXS
            font.weight: Style.fontWeightBold
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rows: 6
        columnSpacing: Style.marginXXS
        rowSpacing: Style.marginXXS

        Repeater {
          model: compactCalendar.daysModel()

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0

            Rectangle {
              anchors.centerIn: parent
              width: Math.min(parent.width, parent.height, Math.round(28 * root.panelUnit))
              height: width
              radius: width / 2
              color: modelData.today ? root.componentButtonBackground("calendar") : "transparent"

              NText {
                anchors.centerIn: parent
                text: modelData.day
                color: modelData.today ? root.componentButtonText("calendar") : (modelData.currentMonth ? root.componentText("calendar", true) : root.componentText("calendar", false))
                opacity: modelData.currentMonth ? 1 : 0.36
                pointSize: Style.fontSizeS
                font.weight: modelData.today ? Style.fontWeightBold : Style.fontWeightMedium
              }
            }
          }
        }
      }
    }
  }

  component ScreenUsagePage: Item {
    id: screenUsagePage

    readonly property var topApps: root.screenUsageTopApps(4)
    readonly property int maxAppSeconds: root.screenUsageMaxAppSeconds(topApps)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "device-desktop"
          pointSize: Style.fontSizeXL
          color: root.componentAccent("screenUsage")
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            text: root.tr("screenUsage")
            color: root.componentText("screenUsage", true)
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: root.tr("trackedToday")
            color: root.componentText("screenUsage", false)
            pointSize: Style.fontSizeXS
            elide: Text.ElideRight
          }
        }

        NText {
          text: root.durationText(root.screenUsageTodayTotal())
          color: root.componentAccent("screenUsage")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          font.family: Settings.data.ui.fontFixed
        }

        SubmoduleButton {
          labelText: root.tr("details")
          targetView: "screenUsage"
          tooltipText: root.tr("details")
        }
      }

      DashboardCard {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(76 * root.panelUnit)
        color: Qt.alpha(Color.mSurface, 0.34)
        radius: Style.radiusS

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginS

          Repeater {
            model: root.screenUsageWeekModel()

            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.marginXXS

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  width: Math.max(14, Math.round(18 * root.panelUnit))
                  height: Math.max(Math.round(8 * root.panelUnit), parent.height * modelData.ratio)
                  radius: Style.radiusXS
                  color: index === 6 ? root.componentAccent("screenUsage") : Qt.alpha(root.componentText("screenUsage", false), 0.38)
                }
              }

              NText {
                Layout.fillWidth: true
                text: modelData.label
                color: index === 6 ? root.componentAccent("screenUsage") : root.componentText("screenUsage", false)
                pointSize: Style.fontSizeXXS
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: root.tr("topApps")
          color: root.componentText("screenUsage", true)
          font.weight: Style.fontWeightSemiBold
          pointSize: Style.fontSizeS
          elide: Text.ElideRight
        }

        Repeater {
          model: screenUsagePage.topApps

          ScreenUsageAppRow {
            Layout.fillWidth: true
            appData: modelData
            maxSeconds: screenUsagePage.maxAppSeconds
          }
        }

        NText {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: screenUsagePage.topApps.length === 0
          text: root.tr("screenUsageEmpty")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  component ScreenUsageAppRow: Item {
    id: screenUsageAppRow

    property var appData: null
    property int maxSeconds: 1

    Layout.preferredHeight: Math.round(34 * root.panelUnit)

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginXXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "apps"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: screenUsageAppRow.appData?.name || "--"
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightMedium
          elide: Text.ElideRight
        }

        NText {
          text: root.durationText(screenUsageAppRow.appData?.seconds || 0)
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          font.family: Settings.data.ui.fontFixed
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(4, Math.round(5 * root.panelUnit))
        radius: height / 2
        color: Qt.alpha(Color.mSurface, 0.5)

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: parent.width * Math.max(0.02, Math.min(1, Number(screenUsageAppRow.appData?.seconds || 0) / Math.max(1, screenUsageAppRow.maxSeconds)))
          radius: parent.radius
          color: Color.mPrimary
          opacity: 0.82
        }
      }
    }
  }

  component ScreenUsageRangeButton: DashboardCard {
    id: screenUsageRangeButton

    property string labelText: ""
    property int days: 1
    readonly property bool selected: root.screenUsageRangeDays === days

    Layout.preferredHeight: Math.round(32 * root.panelUnit)
    color: selected ? Color.mPrimary : Qt.alpha(Color.mSurface, 0.42)
    radius: Style.radiusS
    border.color: selected ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.18)

    NText {
      anchors.centerIn: parent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.marginS
      anchors.rightMargin: Style.marginS
      text: screenUsageRangeButton.labelText
      color: screenUsageRangeButton.selected ? Color.mOnPrimary : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      font.weight: screenUsageRangeButton.selected ? Style.fontWeightSemiBold : Style.fontWeightMedium
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }

    TapHandler {
      onTapped: root.screenUsageRangeDays = screenUsageRangeButton.days
    }
  }

  component ScreenUsageDetailRow: DashboardCard {
    id: screenUsageDetailRow

    property var appData: null
    property int maxSeconds: 1

    Layout.preferredHeight: Math.round(66 * root.panelUnit)
    color: Qt.alpha(Color.mSurface, 0.34)
    radius: Style.radiusS

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "apps"
          pointSize: Style.fontSizeL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            text: screenUsageDetailRow.appData?.name || "--"
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: screenUsageDetailRow.appData?.title || screenUsageDetailRow.appData?.id || ""
            visible: text !== ""
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXXS
            elide: Text.ElideRight
          }
        }

        NText {
          text: root.durationText(screenUsageDetailRow.appData?.seconds || 0)
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightSemiBold
          font.family: Settings.data.ui.fontFixed
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(5, Math.round(6 * root.panelUnit))
        radius: height / 2
        color: Qt.alpha(Color.mSurfaceVariant, 0.24)

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: parent.width * Math.max(0.025, Math.min(1, Number(screenUsageDetailRow.appData?.seconds || 0) / Math.max(1, screenUsageDetailRow.maxSeconds)))
          radius: parent.radius
          color: Color.mPrimary
          opacity: 0.88
        }
      }
    }
  }
}
