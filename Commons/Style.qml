pragma Singleton

import QtQuick
import Quickshell
import qs.Services.Power

Singleton {
  id: root

  // Font size
  readonly property real fontSizeXXS: 8
  readonly property real fontSizeXS: 9
  readonly property real fontSizeS: 10
  readonly property real fontSizeM: 11
  readonly property real fontSizeL: 13
  readonly property real fontSizeXL: 16
  readonly property real fontSizeXXL: 18
  readonly property real fontSizeXXXL: 24

  // Font weight
  readonly property int fontWeightRegular: 400
  readonly property int fontWeightMedium: 500
  readonly property int fontWeightSemiBold: 600
  readonly property int fontWeightBold: 700

  // Hydra Expressive semantic typography. Existing fontSize* tokens remain
  // available during migration; new and refactored surfaces use these names.
  readonly property real fontSizeLabelSmall: 9
  readonly property real fontSizeLabelMedium: 10
  readonly property real fontSizeLabelLarge: 11
  readonly property real fontSizeBodySmall: 11
  readonly property real fontSizeBodyMedium: 13
  readonly property real fontSizeBodyLarge: 16
  readonly property real fontSizeTitleSmall: 14
  readonly property real fontSizeTitleMedium: 16
  readonly property real fontSizeTitleLarge: 22
  readonly property real fontSizeHeadlineSmall: 24
  readonly property real fontSizeHeadlineMedium: 28
  readonly property real fontSizeHeadlineLarge: 32
  readonly property real fontSizeDisplaySmall: 36
  readonly property real fontSizeDisplayMedium: 45
  readonly property real fontSizeDisplayLarge: 57

  // Hydra Expressive spatial scale. All geometry follows the existing global
  // UI scale so per-monitor/device scaling behavior remains unchanged.
  readonly property int spaceNone: 0
  readonly property int spaceXXS: Math.round(4 * uiScaleRatio)
  readonly property int spaceXS: Math.round(8 * uiScaleRatio)
  readonly property int spaceS: Math.round(12 * uiScaleRatio)
  readonly property int spaceM: Math.round(16 * uiScaleRatio)
  readonly property int spaceL: Math.round(20 * uiScaleRatio)
  readonly property int spaceXL: Math.round(28 * uiScaleRatio)
  readonly property int spaceXXL: Math.round(32 * uiScaleRatio)
  readonly property int spaceXXXL: Math.round(48 * uiScaleRatio)

  readonly property int paddingControl: spaceXS
  readonly property int paddingCard: spaceM
  readonly property int paddingPanel: spaceL

  // Semantic shape roles. Containers and controls preserve their independent
  // user-configurable radius ratios.
  readonly property int radiusPanel: Math.round(28 * Settings.data.general.radiusRatio)
  readonly property int radiusCard: Math.round(16 * Settings.data.general.radiusRatio)
  readonly property int radiusPopover: Math.round(20 * Settings.data.general.radiusRatio)
  readonly property int radiusControl: Math.round(16 * Settings.data.general.iRadiusRatio)
  readonly property int radiusControlPressed: Math.round(8 * Settings.data.general.iRadiusRatio)
  readonly property int radiusControlChecked: Math.round(12 * Settings.data.general.iRadiusRatio)
  readonly property int radiusCapsule: 9999

  // Container Radii: major layout sections (sidebars, cards, content panels)
  readonly property int radiusXXXS: Math.round(3 * Settings.data.general.radiusRatio)
  readonly property int radiusXXS: Math.round(4 * Settings.data.general.radiusRatio)
  readonly property int radiusXS: Math.round(8 * Settings.data.general.radiusRatio)
  readonly property int radiusS: Math.round(12 * Settings.data.general.radiusRatio)
  readonly property int radiusM: Math.round(16 * Settings.data.general.radiusRatio)
  readonly property int radiusL: Math.round(20 * Settings.data.general.radiusRatio)

  // Input radii: interactive elements (buttons, toggles, text fields)
  readonly property int iRadiusXXXS: Math.round(3 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusXXS: Math.round(4 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusXS: Math.round(8 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusS: Math.round(12 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusM: Math.round(16 * Settings.data.general.iRadiusRatio)
  readonly property int iRadiusL: Math.round(20 * Settings.data.general.iRadiusRatio)

  readonly property int screenRadius: Math.round(20 * Settings.data.general.screenRadiusRatio)

  // Border
  readonly property int borderS: Math.max(1, Math.round(1 * uiScaleRatio))
  readonly property int borderM: Math.max(1, Math.round(2 * uiScaleRatio))
  readonly property int borderL: Math.max(1, Math.round(3 * uiScaleRatio))

  // Margins (for margins and spacing)
  readonly property int marginXXXS: Math.round(1 * uiScaleRatio)
  readonly property int marginXXS: Math.round(2 * uiScaleRatio)
  readonly property int marginXS: Math.round(4 * uiScaleRatio)
  readonly property int marginS: Math.round(6 * uiScaleRatio)
  readonly property int marginM: Math.round(9 * uiScaleRatio)
  readonly property int marginL: Math.round(13 * uiScaleRatio)
  readonly property int marginXL: Math.round(18 * uiScaleRatio)

  // Double margins, for proper container sizing only (e.g. height: id.implicitHeight + Style.margin2M)
  readonly property int margin2XXXS: marginXXXS * 2
  readonly property int margin2XXS: marginXXS * 2
  readonly property int margin2XS: marginXS * 2
  readonly property int margin2S: marginS * 2
  readonly property int margin2M: marginM * 2
  readonly property int margin2L: marginL * 2
  readonly property int margin2XL: marginXL * 2

  // Opacity
  readonly property real opacityNone: 0.0
  readonly property real opacityLight: 0.25
  readonly property real opacityMedium: 0.5
  readonly property real opacityHeavy: 0.75
  readonly property real opacityAlmost: 0.95
  readonly property real opacityFull: 1.0
  readonly property real disabledContentOpacity: 0.38
  readonly property real disabledContainerOpacity: 0.12

  readonly property real effectivePanelOpacity: PowerProfileService.noctaliaPerformanceMode ? 1.0 : Color.adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity)
  readonly property real effectiveBarOpacity: PowerProfileService.noctaliaPerformanceMode ? 1.0 : Settings.data.bar.backgroundOpacity

  // Shadows
  readonly property real shadowOpacity: 0.85
  readonly property real shadowBlur: 1.0
  readonly property int shadowBlurMax: 22
  readonly property real shadowHorizontalOffset: Settings.data.general.shadowOffsetX
  readonly property real shadowVerticalOffset: Settings.data.general.shadowOffsetY

  // Interaction state, focus and shape morph
  readonly property real stateHoverOpacity: 0.08
  readonly property real stateFocusOpacity: 0.12
  readonly property real statePressedOpacity: 0.12
  readonly property real stateDraggedOpacity: 0.16
  readonly property real stateSelectedOpacity: 0.10
  readonly property int focusRingWidth: borderM
  readonly property int focusRingOffset: Math.max(2, spaceXXS / 2)
  readonly property real morphHoverScale: 1.02
  readonly property real morphPressedScale: 0.96

  // Elevation levels map to MultiEffect's normalized blur and pixel offset.
  // Level 0 keeps the legacy NDropShadow values for backwards compatibility.
  function elevationBlur(level) {
    switch (Math.max(0, Math.min(5, Math.round(level)))) {
    case 1:
      return 0.18;
    case 2:
      return 0.30;
    case 3:
      return 0.44;
    case 4:
      return 0.60;
    case 5:
      return 0.78;
    default:
      return 0.0;
    }
  }

  function elevationOpacity(level) {
    switch (Math.max(0, Math.min(5, Math.round(level)))) {
    case 1:
      return 0.20;
    case 2:
      return 0.22;
    case 3:
      return 0.24;
    case 4:
      return 0.26;
    case 5:
      return 0.28;
    default:
      return 0.0;
    }
  }

  function elevationVerticalOffset(level) {
    switch (Math.max(0, Math.min(5, Math.round(level)))) {
    case 1:
      return 1;
    case 2:
      return 2;
    case 3:
      return 4;
    case 4:
      return 6;
    case 5:
      return 8;
    default:
      return 0;
    }
  }

  // Animation duration (ms)
  readonly property int animationFaster: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(75 / Settings.data.general.animationSpeed)
  readonly property int animationFast: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(150 / Settings.data.general.animationSpeed)
  readonly property int animationNormal: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(300 / Settings.data.general.animationSpeed)
  readonly property int animationSlow: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(450 / Settings.data.general.animationSpeed)
  readonly property int animationSlowest: (Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode) ? 0 : Math.round(750 / Settings.data.general.animationSpeed)

  // Material 3 Expressive motion. Spatial curves may overshoot and are only
  // for geometry; effects curves are bounded for color and opacity.
  readonly property bool motionEnabled: !(Settings.data.general.animationDisabled || PowerProfileService.noctaliaPerformanceMode)
  readonly property int motionDurationFastSpatial: motionEnabled ? Math.round(350 / Settings.data.general.animationSpeed) : 0
  readonly property int motionDurationDefaultSpatial: motionEnabled ? Math.round(500 / Settings.data.general.animationSpeed) : 0
  readonly property int motionDurationSlowSpatial: motionEnabled ? Math.round(650 / Settings.data.general.animationSpeed) : 0
  readonly property int motionDurationFastEffects: motionEnabled ? Math.round(150 / Settings.data.general.animationSpeed) : 0
  readonly property int motionDurationDefaultEffects: motionEnabled ? Math.round(200 / Settings.data.general.animationSpeed) : 0
  readonly property int motionDurationSlowEffects: motionEnabled ? Math.round(300 / Settings.data.general.animationSpeed) : 0

  readonly property list<real> motionCurveStandardSpatial: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
  readonly property list<real> motionCurveEmphasizedSpatial: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
  readonly property list<real> motionCurveExpressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1.0, 1.0]
  readonly property list<real> motionCurveExpressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
  readonly property list<real> motionCurveExpressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1.0, 1.0]
  readonly property list<real> motionCurveStandardEffects: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
  readonly property list<real> motionCurveEmphasizedEffects: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
  readonly property list<real> motionCurveExpressiveEffects: [0.1, 0.7, 0.1, 1.0, 1.0, 1.0]

  // Delays
  readonly property int tooltipDelay: 300
  readonly property int tooltipDelayLong: 1200
  readonly property int pillDelay: 500

  // Widgets base size
  readonly property real baseWidgetSize: 33
  readonly property real sliderWidth: 200

  readonly property real uiScaleRatio: Settings.data.general.scaleRatio

  // Bar Height
  readonly property real barHeight: {
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 23 : 21;
      break;
      case "compact":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 27 : 25;
      break;
      case "comfortable":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 39 : 37;
      break;
      case "spacious":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 49 : 47;
      break;
      default:
      case "default":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 33 : 31;
    }
    return toOdd(h);
  }

  // Capsule Height
  // Note: capsule must always be smaller than barHeight to account for border rendering
  // Qt Quick Rectangle borders are drawn centered on edges (half inside, half outside)
  readonly property real capsuleHeight: {
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = Math.round(barHeight * 0.90);
      break;
      case "compact":
      h = Math.round(barHeight * 0.85);
      break;
      case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
      case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
      default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  // The base/default font size for all texts in the bar
  readonly property real _barBaseFontSize: Math.max(1, (Style.barHeight / Style.capsuleHeight) * Style.fontSizeXXS)
  readonly property real barFontSize: (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? _barBaseFontSize * 0.9 * Settings.data.bar.fontScale : _barBaseFontSize * Settings.data.bar.fontScale

  readonly property color capsuleColor: Settings.data.bar.showCapsule ? Qt.alpha(Settings.data.bar.capsuleColorKey !== "none" ? Color.resolveColorKey(Settings.data.bar.capsuleColorKey) : Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity) : "transparent"

  readonly property color capsuleBorderColor: Settings.data.bar.showOutline ? Color.mPrimary : "transparent"
  readonly property int capsuleBorderWidth: Settings.data.bar.showOutline ? Style.borderS : 0

  readonly property color boxBorderColor: Settings.data.ui.boxBorderEnabled ? Color.mOutline : "transparent"

  // Pixel-perfect utility for centering content without subpixel positioning
  function pixelAlignCenter(containerSize, contentSize) {
    return Math.round((containerSize - contentSize) / 2);
  }

  // Ensures a number is always odd (rounds down to nearest odd)
  function toOdd(n) {
    return Math.floor(n / 2) * 2 + 1;
  }

  // Ensures a number is always even (rounds down to nearest even)
  function toEven(n) {
    return Math.floor(n / 2) * 2;
  }

  // Get bar height for a specific density and orientation
  function getBarHeightForDensity(density, isVertical) {
    let h;
    switch (density) {
    case "mini":
      h = isVertical ? 23 : 21;
      break;
    case "compact":
      h = isVertical ? 27 : 25;
      break;
    case "comfortable":
      h = isVertical ? 39 : 37;
      break;
    case "spacious":
      h = isVertical ? 49 : 47;
      break;
    default:
    case "default":
      h = isVertical ? 33 : 31;
    }
    return toOdd(h);
  }

  // Get capsule height for a specific density and bar height
  function getCapsuleHeightForDensity(density, barHeight) {
    let h;
    switch (density) {
    case "mini":
      h = Math.round(barHeight * 0.90);
      break;
    case "compact":
      h = Math.round(barHeight * 0.85);
      break;
    case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
    case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
    default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  // Get bar font size for a specific bar height, capsule height, and orientation
  function getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical) {
    const baseFontSize = Math.max(1, (barHeight / capsuleHeight) * Style.fontSizeXXS);
    return isVertical ? baseFontSize * 0.9 * Settings.data.bar.fontScale : baseFontSize * Settings.data.bar.fontScale;
  }

  // Convenience functions for per-screen bar sizing
  function getBarHeightForScreen(screenName) {
    var density = Settings.getBarDensityForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarHeightForDensity(density, isVertical);
  }

  function getCapsuleHeightForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var density = Settings.getBarDensityForScreen(screenName);
    return getCapsuleHeightForDensity(density, barHeight);
  }

  function getBarFontSizeForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var capsuleHeight = getCapsuleHeightForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical);
  }
}
