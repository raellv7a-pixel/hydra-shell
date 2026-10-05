pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Power

/*
Hydra is not strictly a Material Design project, it supports both some predefined
color schemes and dynamic color generation from the wallpaper.

We ultimately decided to use a restricted set of colors that follows the
Material Design 3 naming convention.

NOTE: All color names are prefixed with 'm' (e.g., mPrimary) to prevent QML from
misinterpreting them as signals (e.g., the 'onPrimary' property name).
*/
Singleton {
  id: root

  property bool reloadColors: false

  // Debounce external reload requests (file watcher + directory watcher)
  // so atomic replacements only trigger one reload.
  Timer {
    id: externalColorReloadTimer
    running: false
    interval: 200
    onTriggered: {
      if (!root.isPreviewing && customColorsFile.path !== undefined) {
        Logger.d("Color", "Reloading colors from disk");
        reloadColors = true;
        customColorsFile.reload();
      }
    }
  }

  function scheduleExternalColorReload() {
    if (root.isPreviewing || !Settings.directoriesCreated || customColorsFile.path === undefined) {
      return;
    }
    externalColorReloadTimer.restart();
  }

  // Suppress transition animations until the first colors.json load completes
  property bool skipTransition: true

  // Flag indicating theme colors are currently transitioning (for widgets to disable their own animations)
  property bool isTransitioning: false

  // Timer to reset isTransitioning after animation completes
  Timer {
    id: transitionTimer
    interval: Style.animationSlowest + 50 // Small buffer after animation
    onTriggered: root.isTransitioning = false
  }

  // --- Key Colors: These are the main accent colors that define your app's style
  property color mPrimary: defaultColors.mPrimary
  property color mOnPrimary: defaultColors.mOnPrimary
  property color mSecondary: defaultColors.mSecondary
  property color mOnSecondary: defaultColors.mOnSecondary
  property color mTertiary: defaultColors.mTertiary
  property color mOnTertiary: defaultColors.mOnTertiary

  // --- Utility Colors: These colors serve specific, universal purposes like indicating errors
  property color mError: defaultColors.mError
  property color mOnError: defaultColors.mOnError

  // --- Surface and Variant Colors: These provide additional options for surfaces and their contents, creating visual hierarchy
  property color mSurface: defaultColors.mSurface
  property color mOnSurface: defaultColors.mOnSurface

  property color mSurfaceVariant: defaultColors.mSurfaceVariant
  property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant

  property color mOutline: defaultColors.mOutline
  property color mShadow: defaultColors.mShadow

  property color mHover: defaultColors.mHover
  property color mOnHover: defaultColors.mOnHover

  // Optional engine roles. Replaced on EVERY load so a later legacy/predefined
  // file cannot retain containers from the previous wallpaper palette.
  property var surfaceContainerRoles: ({
    "mSurfaceContainerLowest": defaultColors.mSurfaceContainerLowest,
    "mSurfaceContainerLow": defaultColors.mSurfaceContainerLow,
    "mSurfaceContainer": defaultColors.mSurfaceContainer,
    "mSurfaceContainerHigh": defaultColors.mSurfaceContainerHigh,
    "mSurfaceContainerHighest": defaultColors.mSurfaceContainerHighest,
    "mPrimaryContainer": defaultColors.mPrimaryContainer,
    "mOnPrimaryContainer": defaultColors.mOnPrimaryContainer,
    "mSecondaryContainer": defaultColors.mSecondaryContainer,
    "mOnSecondaryContainer": defaultColors.mOnSecondaryContainer,
    "mTertiaryContainer": defaultColors.mTertiaryContainer,
    "mOnTertiaryContainer": defaultColors.mOnTertiaryContainer
  })
  property color _surfaceContainerLowest: surfaceContainerRoles.mSurfaceContainerLowest ?? mSurface
  property color _surfaceContainerLow: surfaceContainerRoles.mSurfaceContainerLow ?? blend(mSurface, mSurfaceVariant, 0.18)
  property color _surfaceContainer: surfaceContainerRoles.mSurfaceContainer ?? blend(mSurface, mSurfaceVariant, 0.36)
  property color _surfaceContainerHigh: surfaceContainerRoles.mSurfaceContainerHigh ?? blend(mSurface, mSurfaceVariant, 0.56)
  property color _surfaceContainerHighest: surfaceContainerRoles.mSurfaceContainerHighest ?? blend(mSurface, mSurfaceVariant, 0.76)
  readonly property color mSurfaceContainerLowest: _surfaceContainerLowest
  readonly property color mSurfaceContainerLow: _surfaceContainerLow
  readonly property color mSurfaceContainer: _surfaceContainer
  readonly property color mSurfaceContainerHigh: _surfaceContainerHigh
  readonly property color mSurfaceContainerHighest: _surfaceContainerHighest
  property color _primaryContainer: surfaceContainerRoles.mPrimaryContainer ?? blend(mSurfaceContainerHigh, mPrimary, 0.22)
  property color _onPrimaryContainer: surfaceContainerRoles.mOnPrimaryContainer ?? mOnSurface
  property color _secondaryContainer: surfaceContainerRoles.mSecondaryContainer ?? blend(mSurfaceContainerHigh, mSecondary, 0.20)
  property color _onSecondaryContainer: surfaceContainerRoles.mOnSecondaryContainer ?? mOnSurface
  property color _tertiaryContainer: surfaceContainerRoles.mTertiaryContainer ?? blend(mSurfaceContainerHigh, mTertiary, 0.20)
  property color _onTertiaryContainer: surfaceContainerRoles.mOnTertiaryContainer ?? mOnSurface
  readonly property color mPrimaryContainer: _primaryContainer
  readonly property color mOnPrimaryContainer: _onPrimaryContainer
  readonly property color mSecondaryContainer: _secondaryContainer
  readonly property color mOnSecondaryContainer: _onSecondaryContainer
  readonly property color mTertiaryContainer: _tertiaryContainer
  readonly property color mOnTertiaryContainer: _onTertiaryContainer
  readonly property color mErrorContainer: blend(mSurfaceContainerHigh, mError, 0.22)
  readonly property color mOnErrorContainer: mOnSurface

  function blend(base, accent, amount) {
    const ratio = Math.max(0, Math.min(1, Number(amount || 0)));
    return Qt.rgba(base.r + (accent.r - base.r) * ratio, base.g + (accent.g - base.g) * ratio, base.b + (accent.b - base.b) * ratio, base.a + (accent.a - base.a) * ratio);
  }

  Behavior on _surfaceContainerLowest {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _surfaceContainerLow {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _surfaceContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _surfaceContainerHigh {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _surfaceContainerHighest {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }

  Behavior on _primaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onPrimaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _secondaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onSecondaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _tertiaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on _onTertiaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }

  // --- Color transition animations ---
  Behavior on mPrimary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnPrimary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSecondary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSecondary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mTertiary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnTertiary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOutline {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mShadow {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mHover {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnHover {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }

  // Helper to start transition and update a color
  function startTransition() {
    root.isTransitioning = true;
    transitionTimer.restart();
  }

  // Update colors when customColorsData changes (imperative assignment enables Behavior animations)
  Connections {
    target: customColorsData
    enabled: !root.isPreviewing
    function onMPrimaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mPrimary = customColorsData.mPrimary;
    }
    function onMOnPrimaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnPrimary = customColorsData.mOnPrimary;
    }
    function onMSecondaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSecondary = customColorsData.mSecondary;
    }
    function onMOnSecondaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSecondary = customColorsData.mOnSecondary;
    }
    function onMTertiaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mTertiary = customColorsData.mTertiary;
    }
    function onMOnTertiaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnTertiary = customColorsData.mOnTertiary;
    }
    function onMErrorChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mError = customColorsData.mError;
    }
    function onMOnErrorChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnError = customColorsData.mOnError;
    }
    function onMSurfaceChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSurface = customColorsData.mSurface;
    }
    function onMOnSurfaceChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSurface = customColorsData.mOnSurface;
    }
    function onMSurfaceVariantChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSurfaceVariant = customColorsData.mSurfaceVariant;
    }
    function onMOnSurfaceVariantChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSurfaceVariant = customColorsData.mOnSurfaceVariant;
    }
    function onMOutlineChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOutline = customColorsData.mOutline;
    }
    function onMShadowChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mShadow = customColorsData.mShadow;
    }
    function onMHoverChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mHover = customColorsData.mHover;
    }
    function onMOnHoverChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnHover = customColorsData.mOnHover;
    }
  }
  // ----------------------------------------------------------------
  // Palette snapshot and in-memory live preview support
  property bool isPreviewing: false
  property var _snapshotColors: null
  property var previewDarkMode: null
  function takeSnapshot() {
    const snapshot = {};
    const baseKeys = [
      "mPrimary", "mOnPrimary", "mSecondary", "mOnSecondary",
      "mTertiary", "mOnTertiary", "mError", "mOnError",
      "mSurface", "mOnSurface", "mSurfaceVariant", "mOnSurfaceVariant",
      "mOutline", "mShadow", "mHover", "mOnHover"
    ];
    for (let i = 0; i < baseKeys.length; i++) {
      const key = baseKeys[i];
      snapshot[key] = root[key].toString();
    }
    const containerKeys = [
      "mSurfaceContainerLowest", "mSurfaceContainerLow", "mSurfaceContainer",
      "mSurfaceContainerHigh", "mSurfaceContainerHighest", "mPrimaryContainer",
      "mOnPrimaryContainer", "mSecondaryContainer", "mOnSecondaryContainer",
      "mTertiaryContainer", "mOnTertiaryContainer"
    ];
    for (let i = 0; i < containerKeys.length; i++) {
      const key = containerKeys[i];
      snapshot[key] = (root.surfaceContainerRoles[key] !== undefined ? root.surfaceContainerRoles[key] : root[key]).toString();
    }
    return snapshot;
  }

  function applySnapshot(snapshot) {
    if (!snapshot)
      return;
    previewPalette(snapshot);
    isPreviewing = false;
    _snapshotColors = null;
    previewDarkMode = null;
  }

  function previewPalette(paletteObj) {
    if (!paletteObj)
      return;
    if (!isPreviewing && !_snapshotColors) {
      _snapshotColors = takeSnapshot();
    }
    isPreviewing = true;
    if (!root.skipTransition) {
      startTransition();
    }
    const baseKeys = [
      "mPrimary", "mOnPrimary", "mSecondary", "mOnSecondary",
      "mTertiary", "mOnTertiary", "mError", "mOnError",
      "mSurface", "mOnSurface", "mSurfaceVariant", "mOnSurfaceVariant",
      "mOutline", "mShadow", "mHover", "mOnHover"
    ];
    for (let i = 0; i < baseKeys.length; i++) {
      const key = baseKeys[i];
      if (paletteObj[key] !== undefined) {
        root[key] = paletteObj[key];
      }
    }
    const containerKeys = [
      "mSurfaceContainerLowest", "mSurfaceContainerLow", "mSurfaceContainer",
      "mSurfaceContainerHigh", "mSurfaceContainerHighest", "mPrimaryContainer",
      "mOnPrimaryContainer", "mSecondaryContainer", "mOnSecondaryContainer",
      "mTertiaryContainer", "mOnTertiaryContainer"
    ];
    const nextContainers = {};
    for (let i = 0; i < containerKeys.length; i++) {
      const key = containerKeys[i];
      if (paletteObj[key] !== undefined) {
        nextContainers[key] = paletteObj[key];
      }
    }
    root.surfaceContainerRoles = nextContainers;
  }

  function clearPreview() {
    if (_snapshotColors) {
      applySnapshot(_snapshotColors);
    }
    isPreviewing = false;
    _snapshotColors = null;
    previewDarkMode = null;
  }

  function commitPreview() {
    isPreviewing = false;
    _snapshotColors = null;
    previewDarkMode = null;
    // Reload every role after releasing the read-only preview, including base
    // values whose JsonAdapter fields may have changed while signals were gated.
    customColorsFile.reload();
  }

  function resolveColorKey(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return root.mOnSurface;
    }
  }

  function resolveOnColorKey(key) {
    switch (key) {
    case "primary":
      return root.mOnPrimary;
    case "secondary":
      return root.mOnSecondary;
    case "tertiary":
      return root.mOnTertiary;
    case "error":
      return root.mOnError;
    default:
      return root.mSurface;
    }
  }

  function resolveColorKeyOptional(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return "transparent";
    }
  }

  // Adaptive opacity calculation: automatically makes light mode more transparent
  function adaptiveOpacity(baseOpacity) {
    if (PowerProfileService.hydraPerformanceMode)
      return 1.0;
    const isDark = previewDarkMode !== null ? !!previewDarkMode : Settings.data.colorSchemes.darkMode;
    return isDark ? baseOpacity : Math.pow(baseOpacity, 1.5);
  }

  function smartAlpha(baseColor, minAlpha = 0.4) {
    if (PowerProfileService.hydraPerformanceMode)
      return baseColor;

    if (!Settings.data.ui.translucentWidgets)
      return baseColor;

    let alpha = Math.max(adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity), minAlpha);

    // Combine with the base color's existing alpha
    let resultAlpha = Math.max(0, baseColor.a - (1.0 - alpha));
    return Qt.alpha(baseColor, resultAlpha);
  }

  readonly property var colorKeyModel: [
    {
      "key": "none",
      "name": I18n.tr("common.none")
    },
    {
      "key": "primary",
      "name": I18n.tr("common.primary")
    },
    {
      "key": "secondary",
      "name": I18n.tr("common.secondary")
    },
    {
      "key": "tertiary",
      "name": I18n.tr("common.tertiary")
    },
    {
      "key": "error",
      "name": I18n.tr("common.error")
    }
  ]

  // --------------------------------
  // Default colors: Hydra Glacier dark — must match Assets/ColorScheme/Hydra-Glacier
  QtObject {
    id: defaultColors

    readonly property color mPrimary: "#7DD3E8"
    readonly property color mOnPrimary: "#001f26"

    readonly property color mSecondary: "#A9C7D2"
    readonly property color mOnSecondary: "#001f27"

    readonly property color mTertiary: "#8BDDBA"
    readonly property color mOnTertiary: "#002116"

    readonly property color mError: "#fa746f"
    readonly property color mOnError: "#410005"

    readonly property color mSurface: "#10181D"
    readonly property color mOnSurface: "#E4EDF1"

    readonly property color mSurfaceVariant: "#172228"
    readonly property color mOnSurfaceVariant: "#a3adb0"

    readonly property color mSurfaceContainerLowest: "#0B1115"
    readonly property color mSurfaceContainerLow: "#121d23"
    readonly property color mSurfaceContainer: "#172228"
    readonly property color mSurfaceContainerHigh: "#1E2C33"
    readonly property color mSurfaceContainerHighest: "#28363d"

    readonly property color mPrimaryContainer: "#184E5A"
    readonly property color mOnPrimaryContainer: "#d8f6ff"
    readonly property color mSecondaryContainer: "#203d46"
    readonly property color mOnSecondaryContainer: "#dbf5ff"
    readonly property color mTertiaryContainer: "#00422f"
    readonly property color mOnTertiaryContainer: "#c2fee2"

    readonly property color mOutline: "#6d777a"
    readonly property color mShadow: "#0B1115"

    readonly property color mHover: "#8BDDBA"
    readonly property color mOnHover: "#002116"
  }
  // ----------------------------------------------------------------
  // FileView to load custom colors data from colors.json
  FileView {
    id: customColorsFile
    path: Settings.directoriesCreated ? (Settings.configDir + "colors.json") : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()

    onLoaded: {
      if (root.isPreviewing)
        return;
      // Keep optional keys out of JsonAdapter: absent fields must reset, not
      // stick across loads. This FileView is read-only except ENOENT defaults.
      try {
        const next = JSON.parse(text());
        for (const key of ["mPrimary", "mOnPrimary", "mSecondary", "mOnSecondary", "mTertiary", "mOnTertiary", "mError", "mOnError", "mSurface", "mOnSurface", "mSurfaceVariant", "mOnSurfaceVariant", "mOutline", "mShadow", "mHover", "mOnHover"])
          root[key] = next[key] ?? defaultColors[key];
        const optionalKeys = ["mSurfaceContainerLowest", "mSurfaceContainerLow", "mSurfaceContainer", "mSurfaceContainerHigh", "mSurfaceContainerHighest", "mPrimaryContainer", "mOnPrimaryContainer", "mSecondaryContainer", "mOnSecondaryContainer", "mTertiaryContainer", "mOnTertiaryContainer"];
        const containersChanged = optionalKeys.some(key => next[key] !== root.surfaceContainerRoles[key]);
        root.surfaceContainerRoles = next;
        if (!root.skipTransition && containersChanged)
        root.startTransition();
      } catch (error) {
        Logger.w("Color", "Failed to parse surface container roles:", error);
      }
      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }
    }

    // Trigger initial load when path changes from empty to actual path
    onPathChanged: {
      if (path !== undefined) {
        reload();
      }
    }
    onLoadFailed: function (error) {
      if (reloadColors) {
        reloadColors = false;
        return;
      }

      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }

      // Error code 2 = ENOENT (No such file or directory)
      if (error === 2 || error.toString().includes("No such file")) {
        // Include modern roles on first write, not just the legacy JsonAdapter,
        // so factory Glacier containers stay exact throughout bootstrap.
        customColorsFile.setText(JSON.stringify(root.takeSnapshot()));
      }
    }
    JsonAdapter {
      id: customColorsData

      property color mPrimary: defaultColors.mPrimary
      property color mOnPrimary: defaultColors.mOnPrimary

      property color mSecondary: defaultColors.mSecondary
      property color mOnSecondary: defaultColors.mOnSecondary

      property color mTertiary: defaultColors.mTertiary
      property color mOnTertiary: defaultColors.mOnTertiary

      property color mError: defaultColors.mError
      property color mOnError: defaultColors.mOnError

      property color mSurface: defaultColors.mSurface
      property color mOnSurface: defaultColors.mOnSurface

      property color mSurfaceVariant: defaultColors.mSurfaceVariant
      property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant

      property color mOutline: defaultColors.mOutline
      property color mShadow: defaultColors.mShadow

      property color mHover: defaultColors.mHover
      property color mOnHover: defaultColors.mOnHover
    }
  }

  // Watch parent config directory as a fallback for declarative setups where
  // colors.json may be replaced atomically (e.g., symlink/store-path swap).
  FileView {
    id: colorsDirWatcher
    path: Settings.directoriesCreated ? Settings.configDir : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
  }
}
