import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
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
import "Cards"

Item {
  id: root

  property var cfg: ControlCenterService.settings

  readonly property var activeScreen: PanelService.findScreenForPanels()
  readonly property bool panelDetached: cfg.panelDetached ?? true
  readonly property string panelPosition: cfg.panelPosition ?? "center"
  readonly property bool followBarEdge: cfg.followBarEdge ?? true
  readonly property string barPosition: Settings.getBarPositionForScreen(activeScreen?.name)
  readonly property string resolvedPanelPosition: (!panelDetached && followBarEdge) ? barPosition : panelPosition
  readonly property real localScale: cfg.panelScale ?? 1
  readonly property real panelBaseWidth: cfg.panelWidth ?? 1120
  readonly property real panelBaseHeight: cfg.panelHeight ?? 700
  readonly property string configuredAvatar: cfg.avatarPath ?? ""
  readonly property string avatarPath: configuredAvatar !== "" ? configuredAvatar : Settings.data.general.avatarImage
  readonly property string profileDanceGifPath: cfg.profileDanceGifPath ?? ""
  readonly property string resolvedProfileDanceGifPath: profileDanceGifPath !== "" ? Settings.preprocessPath(profileDanceGifPath) : ""
  readonly property bool showProfileDanceGif: cfg.showProfileDanceGif ?? true
  readonly property bool showProfileWallpaper: cfg.showProfileWallpaper ?? true
  readonly property string profileCoverMode: showProfileWallpaper ? (cfg.profileCoverMode ?? "auto") : "none"
  readonly property string profileCoverPath: cfg.profileCoverPath ?? ""
  readonly property string profileCoverFolder: cfg.profileCoverFolder ?? ""
  readonly property bool profileCoverOverlayEnabled: cfg.profileCoverOverlayEnabled ?? true
  readonly property real profileCoverOverlay: cfg.profileCoverOverlay ?? 0.58
  readonly property bool profileCoverBlurEnabled: cfg.profileCoverBlurEnabled ?? false
  readonly property real profileCoverBlur: cfg.profileCoverBlur ?? 0
  readonly property bool profileCoverBorder: cfg.profileCoverBorder ?? true
  readonly property real profileCoverBorderWidth: cfg.profileCoverBorderWidth ?? 2
  readonly property string profileCoverBorderEffect: cfg.profileCoverBorderEffect ?? "primary"
  readonly property string profileCoverBorderColorMode: cfg.profileCoverBorderColorMode ?? "auto"
  readonly property string profileCoverBorderAnimation: cfg.profileCoverBorderAnimation ?? legacyProfileCoverBorderAnimation()
  readonly property real profileCoverBorderSpeed: cfg.profileCoverBorderSpeed ?? 1
  readonly property int profileCoverBorderColorCount: cfg.profileCoverBorderColorCount ?? 3
  readonly property string profileCoverBorderColor1: cfg.profileCoverBorderColor1 ?? "#fff59b"
  readonly property string profileCoverBorderColor2: cfg.profileCoverBorderColor2 ?? "#8bd5ff"
  readonly property string profileCoverBorderColor3: cfg.profileCoverBorderColor3 ?? "#cba6f7"
  readonly property string profileCoverBorderColor4: cfg.profileCoverBorderColor4 ?? "#f38ba8"
  readonly property string profileCoverBorderColor5: cfg.profileCoverBorderColor5 ?? "#a6e3a1"
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
  readonly property string mediaVisualizerEffect: cfg.mediaVisualizerEffect ?? "bars"
  readonly property string audioSliderEffect: cfg.audioSliderEffect ?? "wave"
  readonly property string microphoneSliderEffect: cfg.microphoneSliderEffect ?? "pulse"
  readonly property string avatarMusicEffect: cfg.avatarMusicEffect ?? "ring"
  readonly property string avatarShape: cfg.avatarShape ?? "circle"
  readonly property string profileCardShape: cfg.profileCardShape ?? "rounded"
  readonly property bool followNoctaliaPerformanceMode: cfg.followNoctaliaPerformanceMode ?? true
  readonly property bool powerSaverPerformanceMode: cfg.powerSaverPerformanceMode ?? true
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
  readonly property color m3SurfaceContainerLow: Color.mSurfaceContainerLow
  readonly property color m3SurfaceContainer: Color.mSurfaceContainer
  readonly property color m3SurfaceContainerHigh: Color.mSurfaceContainerHigh
  readonly property color m3SurfaceContainerHighest: Color.mSurfaceContainerHighest
  readonly property color m3PrimaryContainer: Color.mPrimaryContainer

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: !panelDetached
  property bool panelAnchorRight: resolvedPanelPosition === "right"
  property bool panelAnchorLeft: resolvedPanelPosition === "left"
  property bool panelAnchorHorizontalCenter: resolvedPanelPosition === "center" || resolvedPanelPosition === "top" || resolvedPanelPosition === "bottom"
  property bool panelAnchorVerticalCenter: resolvedPanelPosition === "center" || resolvedPanelPosition === "left" || resolvedPanelPosition === "right"
  property bool panelAnchorTop: resolvedPanelPosition === "top"
  property bool panelAnchorBottom: resolvedPanelPosition === "bottom"
  // Outer panel size: at least what the fixed-width card columns actually
  // need (implicitWidth/Height of dashboardLayout, see panelContainer
  // below), so the content is never cramped into a Flickable. panelWidth/
  // panelHeight/panelScale can still make the panel bigger than that; the
  // extra space is distributed as centered margin, not a lopsided gap.
  property real contentPreferredWidth: Math.min(Math.max(panelBaseWidth * panelUnit, dashboardLayout.implicitWidth + Style.margin2L), maxPanelWidth)
  property real contentPreferredHeight: Math.min(Math.max(panelBaseHeight * panelUnit, dashboardLayout.implicitHeight + Style.margin2L), maxPanelHeight)
  property string expandedNotificationId: ""
  property string activeDetailView: ""
  property string processUsageMetric: "cpu"
  property var processUsageRows: []
  property var processAppMetadataCache: ({})
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
    return I18n.tr("panels.dashboard." + key);
  }

  function updateAvatar(path) {
    if (!path || path.length === 0) {
      return;
    }
    ControlCenterService.settings.avatarPath = path;
    ControlCenterService.saveSettings();
  }

  function openDashboardSettings() {
    const panel = PanelService.getPanel("settingsPanel", activeScreen);
    if (!panel) {
      return;
    }
    panel.requestedTab = SettingsPanel.Tab.ControlCenter;
    panel.open();
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
    const source = [root.profileCoverBorderColor1, root.profileCoverBorderColor2, root.profileCoverBorderColor3, root.profileCoverBorderColor4, root.profileCoverBorderColor5];
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

    const borderFields = ["borderWidth", "borderScope", "borderColorMode", "borderColorCount", "borderColor1", "borderColor2", "borderColor3", "borderColor4", "borderColor5", "borderAnimation", "borderSpeed"];
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
    return root.componentColor(componentKey, "background", root.m3SurfaceContainerLow);
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

    const source = [style.borderColor1, style.borderColor2, style.borderColor3, style.borderColor4, style.borderColor5];
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
      var dataStr = JSON.stringify({
                                     "days": root.screenUsageDays
                                   }, null, 2);
      Quickshell.execDetached(["bash", "-c", "mkdir -p " + dir + " && cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch (e) {
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
      return "GPU NVIDIA";
    if (SystemStatService.gpuType === "amd")
      return "GPU AMD";
    if (SystemStatService.gpuType === "intel")
      return "GPU Intel";
    return SystemStatService.gpuType || root.tr("enabled");
  }

  function processAppMetadata(processName) {
    if (root.processAppMetadataCache[processName])
      return root.processAppMetadataCache[processName];

    let entry = null;
    try {
      entry = ThemeIcons.findAppEntry(processName);
    } catch (error) {}

    const metadata = {
      "displayName": entry?.name || CompositorService.getCleanAppName(processName, "") || processName,
      "icon": entry?.icon || "application-x-executable"
    };
    root.processAppMetadataCache[processName] = metadata;
    return metadata;
  }

  function parseProcessUsage(output) {
    const grouped = {};
    const lines = String(output || "").trim().split("\n");
    const totalMemoryKiB = Math.max(1, Number(SystemStatService.memTotalGb || 0) * 1024 * 1024);

    for (let i = 0; i < lines.length; i++) {
      const fields = lines[i].split("\t");
      if (fields.length < 6)
        continue;

      const processName = String(fields[1] || "").trim();
      if (processName === "")
        continue;

      const processTicks = Math.max(0, Number(fields[2]) || 0);
      const totalTicks = Math.max(1, Number(fields[3]) || 1);
      const rssKiB = Math.max(0, Number(fields[4]) || 0);
      const gpu = root.clamp(Number(fields[5]) || 0, 0, 100);
      const current = grouped[processName] || {
        "processName": processName,
        "cpu": 0,
        "rssKiB": 0,
        "gpu": 0
      };

      current.cpu += processTicks / totalTicks * 100;
      current.rssKiB += rssKiB;
      current.gpu = root.clamp(current.gpu + gpu, 0, 100);
      grouped[processName] = current;
    }

    const rows = [];
    const names = Object.keys(grouped);
    for (let i = 0; i < names.length; i++) {
      const row = grouped[names[i]];
      if (row.cpu < 0.02 && row.rssKiB < 4096 && row.gpu <= 0)
        continue;

      row.ram = root.clamp(row.rssKiB / totalMemoryKiB * 100, 0, 100);
      rows.push(row);
    }

    root.processUsageRows = rows;
  }

  function rankedProcessUsageRows() {
    const metric = root.processUsageMetric;
    const rows = (root.processUsageRows || []).filter(row => Number(row[metric] || 0) > 0.01).slice();
    rows.sort((left, right) => Number(right[metric] || 0) - Number(left[metric] || 0));
    return rows.slice(0, 4).map(row => {
                                  const rankedRow = Object.assign({}, row);
                                  const metadata = root.processAppMetadata(rankedRow.processName);
                                  rankedRow.displayName = metadata.displayName;
                                  rankedRow.icon = metadata.icon;
                                  return rankedRow;
                                });
  }

  function processUsageValue(row, metric) {
    if (!row)
      return "--";
    if (metric === "ram") {
      const gib = Number(row.rssKiB || 0) / 1024 / 1024;
      return gib >= 1 ? gib.toFixed(1) + " GiB" : Math.round(Number(row.rssKiB || 0) / 1024) + " MiB";
    }
    const value = Number(row[metric] || 0);
    return value.toFixed(value < 10 ? 1 : 0) + "%";
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
    return activeScreen;
  }

  property var pendingNativePanelScreen: null

  function toggleNativePanel(panelName, targetScreen) {
    const scr = targetScreen || root.pendingNativePanelScreen || activePanelScreen();
    const panel = PanelService.getPanel(panelName, scr);
    if (panel) {
      panel.open();
    }
  }

  function closeDashboardPanel() {
    PanelService.closePanel();
    if (PanelService.openedPanel && !PanelService.openedPanel.isClosing) {
      PanelService.openedPanel.close();
    }
  }


  function showCaptureNotice(message, detail, icon) {
    const body = detail && String(detail).length > 0 ? message + "\n" + detail : message;
    ToastService.showNotice(root.tr("screenTools"), body, icon || "camera", 3000);
  }

  function showCaptureError(message) {
    ToastService.showError(root.tr("screenTools"), message, 3000);
  }

  function openWallpaperSelector() {
    root.toggleNativePanel("wallpaperPanel");
  }

  function takeDashboardScreenshot(mode) {
    root.pendingScreenshotMode = mode;
    root.pendingCaptureAction = "screenshot";
    deferredCaptureTimer.restart();
  }

  function startDashboardRecording(format) {
    if (root.toolkitRecordState !== "" || root.lastRecordStatus === "selecting" || root.lastRecordStatus === "recording" || root.lastRecordStatus === "converting")
      return;

    root.pendingRecordFormat = format === "mp4" ? "mp4" : "gif";
    root.pendingCaptureAction = "record-area";
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
      easyEffectsStateProcess.exec({
                                     command: root.easyEffectsRunningCheckCommand
                                   });
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
        root.toggleNativePanel(root.pendingNativePanelName, root.pendingNativePanelScreen);
        root.pendingNativePanelName = "";
        root.pendingNativePanelScreen = null;
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
        recordStatusProcess.exec({
                                   command: ["bash", root.captureScriptPath, "status"]
                                 });
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

  Timer {
    interval: root.dashboardPerformanceMode ? 6000 : 3000
    repeat: true
    running: root.visible && root.activeDetailView === "performance"
    triggeredOnStart: true
    onTriggered: {
      if (!processUsageProcess.running)
        processUsageProcess.running = true;
    }
  }

  Process {
    id: processUsageProcess
    command: ["bash", Quickshell.shellDir + "/Modules/Panels/ControlCenter/scripts/process-usage.sh", SystemStatService.gpuType === "nvidia" && Settings.data.systemMonitor.enableDgpuMonitoring ? "nvidia" : "none"]
    running: false
    stdout: StdioCollector {}
    onExited: code => {
                if (code === 0)
                root.parseProcessUsage(stdout.text);
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
                easyEffectsPresetsProcess.exec({
                                                 command: ["easyeffects", "--presets"]
                                               });
                if (!easyEffectsActiveProcess.running)
                easyEffectsActiveProcess.exec({
                                                command: ["easyeffects", "--last-loaded-preset", "output"]
                                              });
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
    running: false
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
      } catch (e) {}
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
    triggeredOnStart: false
    onTriggered: root.sampleScreenUsage()
  }

  Timer {
    id: screenUsageSaveTimer
    interval: 1200
    repeat: false
    onTriggered: root.saveScreenUsage()
  }
  Timer {
    id: deferredInitTimer
    interval: 250
    repeat: false
    running: true
    onTriggered: {
      if (!screenUsageInitProcess.running)
        screenUsageInitProcess.running = true;
    }
  }

  Connections {
    target: CompositorService
    function onActiveWindowChanged() {
      root.sampleScreenUsage();
    }
  }

  Item {
    id: panelContainer
    anchors.fill: parent
    clip: true

    // Fixed-size card columns, centered — no scrolling. contentPreferredWidth/
    // Height above guarantee the outer panel is never smaller than this
    // layout's implicit size, so it never needs to pan.
    RowLayout {
      id: dashboardLayout
      anchors.centerIn: parent
      spacing: Style.marginL

        ColumnLayout {
          Layout.preferredWidth: Math.round(300 * root.panelUnit)
          Layout.fillHeight: true
          spacing: Style.marginL

          ProfileCard {
            panelRoot: root
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(132 * root.panelUnit)
          }

          QuickActionsCard {
            panelRoot: root
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(368 * root.panelUnit)
          }

          RecordingCard {
            panelRoot: root
            visible: root.cfg.showRecordingCard ?? true
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round((root.toolkitRecording ? 194 : 164) * root.panelUnit)

            Behavior on Layout.preferredHeight {
              NumberAnimation {
                duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        ColumnLayout {
          Layout.preferredWidth: Math.round(386 * root.panelUnit)
          Layout.fillHeight: true
          spacing: Style.marginL

          PerformanceCard {
            panelRoot: root
            visible: !root.centerDetailOpen
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(388 * root.panelUnit)
          }

          SystemControlsCard {
            panelRoot: root
            visible: !root.centerDetailOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          Loader {
            active: root.activeDetailView === "performance"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              PerformanceDetailsCard {
                panelRoot: root
              }
            }
          }

          Loader {
            active: root.activeDetailView === "audio"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              AudioDetailsCard {
                panelRoot: root
              }
            }
          }
        }

        ColumnLayout {
          Layout.preferredWidth: Math.round(392 * root.panelUnit)
          Layout.fillHeight: true
          spacing: Style.marginL

          NotificationsCard {
            panelRoot: root
            visible: !root.rightDetailOpen && (root.cfg.showNotifications ?? true)
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(272 * root.panelUnit)
          }

          MediaCard {
            panelRoot: root
            visible: !root.rightDetailOpen && (root.cfg.showMedia ?? true)
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.round(132 * root.panelUnit) : 0
          }

          CalendarShell {
            panelRoot: root
            visible: !root.rightDetailOpen && (root.cfg.showCalendar ?? true)
            Layout.fillWidth: true
            Layout.fillHeight: true
          }

          Loader {
            active: root.activeDetailView === "media"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              MediaDetailsCard {
                panelRoot: root
              }
            }
          }

          Loader {
            active: root.activeDetailView === "notifications"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              NotificationsDetailsCard {
                panelRoot: root
              }
            }
          }

          Loader {
            active: root.activeDetailView === "weather"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              WeatherDetailsCard {
                panelRoot: root
              }
            }
          }

          Loader {
            active: root.activeDetailView === "calendar"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              CalendarDetailsCard {
                panelRoot: root
              }
            }
          }

          Loader {
            active: root.activeDetailView === "screenUsage"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: Component {
              ScreenUsageDetailsCard {
                panelRoot: root
              }
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







































}
