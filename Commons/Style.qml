pragma Singleton

import QtQuick
import Quickshell
import "../Helpers/ColorsConvert.js" as ColorsConvert
import "../Helpers/MaterialProfiles.js" as MaterialProfiles
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

  // Container Radii: major layout sections (sidebars, cards, content panels)
  readonly property int radiusXXXS: Math.round(3 * Settings.data.general.radiusRatio * materialRadiusScale)
  readonly property int radiusXXS: Math.round(4 * Settings.data.general.radiusRatio * materialRadiusScale)
  readonly property int radiusXS: Math.round(8 * Settings.data.general.radiusRatio * materialRadiusScale)
  readonly property int radiusS: Math.round(12 * Settings.data.general.radiusRatio * materialRadiusScale)
  readonly property int radiusM: Math.round(16 * Settings.data.general.radiusRatio * materialRadiusScale)
  readonly property int radiusL: Math.round(20 * Settings.data.general.radiusRatio * materialRadiusScale)

  // Input radii follow the material without changing control sizes or hit targets.
  readonly property int iRadiusXXXS: Math.round(3 * Settings.data.general.iRadiusRatio * materialRadiusScale)
  readonly property int iRadiusXXS: Math.round(4 * Settings.data.general.iRadiusRatio * materialRadiusScale)
  readonly property int iRadiusXS: Math.round(8 * Settings.data.general.iRadiusRatio * materialRadiusScale)
  readonly property int iRadiusS: Math.round(12 * Settings.data.general.iRadiusRatio * materialRadiusScale)
  readonly property int iRadiusM: Math.round(16 * Settings.data.general.iRadiusRatio * materialRadiusScale)
  readonly property int iRadiusL: Math.round(20 * Settings.data.general.iRadiusRatio * materialRadiusScale)

  readonly property int screenRadius: Math.round(20 * Settings.data.general.screenRadiusRatio * materialRadiusScale)

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

  readonly property var visualProfileIds: MaterialProfiles.ids
  readonly property string visualVariant: MaterialProfiles.resolveId(Settings.data.ui.visualVariant)
  readonly property var materialProfile: MaterialProfiles.resolve(visualVariant)
  readonly property bool customMaterial: visualVariant !== "material3"
  readonly property bool profileUsesGlass: materialProfile.glass
  readonly property bool materialEffectsEnabled: customMaterial && Settings.data.general.enableBlurBehind && !PowerProfileService.hydraPerformanceMode
  readonly property bool glassEffectsEnabled: profileUsesGlass && materialEffectsEnabled
  readonly property real materialRadiusScale: materialProfile.radius
  readonly property real materialMotionScale: materialProfile.motion
  readonly property real materialLightAmount: materialProfile.light * Math.max(0, Math.min(1, Settings.data.ui.materialLighting))
  readonly property real materialChromeAmount: materialProfile.chrome * Math.max(0, Math.min(1, Settings.data.ui.materialLighting))
  readonly property real materialBloomAmount: materialProfile.bloom * Math.max(0, Math.min(1, Settings.data.ui.materialLighting))
  readonly property real materialAuroraAmount: materialProfile.aurora * Math.max(0, Math.min(1, Settings.data.ui.materialLighting))
  readonly property real materialTextureAmount: materialProfile.texture * Math.max(0, Math.min(1, Settings.data.ui.materialTexture))
  readonly property real materialRefractionAmount: materialProfile.refraction * Math.max(0, Math.min(1, Settings.data.ui.materialRefraction))
  readonly property real materialPaperAmount: materialProfile.paper * Math.max(0, Math.min(1, Settings.data.ui.materialTexture))
  readonly property real materialSaturation: materialProfile.saturation
  readonly property color materialHighlightColor: visualVariant === "afterglow" ? HydraColor.blend(HydraColor.mPrimary, Qt.hsla(0.09, Math.min(0.65, HydraColor.mPrimary.hslSaturation + 0.15), HydraColor.mPrimary.hslLightness, 1), 0.8) : HydraColor.mPrimary
  readonly property real glassBlurAmount: MaterialProfiles.scaled(materialProfile.blur, Settings.data.ui.glassBlur, 0.85, 0, 1)
  readonly property real materialEdgeAmount: MaterialProfiles.scaled(materialProfile.edge, Settings.data.ui.glassEdgeLight, 0.12, 0, 0.3)
  readonly property color materialEdgeColor: materialEffectsEnabled ? Qt.alpha(HydraColor.mOnSurface, materialEdgeAmount) : "transparent"
  readonly property real glassRequestedOpacity: MaterialProfiles.scaled(materialProfile.opacity, Settings.data.ui.glassTint, 0.56, 0.12, 0.96)
  readonly property real glassBodyOpacity: glassSurfaceOpacity(materialColor(HydraColor.mSurfaceContainer))
  readonly property real effectivePanelOpacity: materialOpacity(PowerProfileService.hydraPerformanceMode ? 1.0 : HydraColor.adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity))
  readonly property real effectiveBarOpacity: materialOpacity(PowerProfileService.hydraPerformanceMode ? 1.0 : Settings.data.bar.backgroundOpacity)

  function materialColor(baseColor) {
    if (!customMaterial || baseColor.a === 0)
      return baseColor;
    const base = Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 1);
    const strength = visualVariant === "tinted-glass" ? 0.02 + 0.08 * Math.max(0, Math.min(1, Settings.data.ui.glassTint)) : MaterialProfiles.scaled(materialProfile.tint, Settings.data.ui.glassTint, 0.56, 0, 0.3);
    let tinted = HydraColor.blend(base, HydraColor.mPrimary, strength);
    if (visualVariant === "tinted-glass")
      return ColorsConvert.getContrastRatio(tinted.toString(), HydraColor.mOnSurfaceVariant.toString()) >= Math.min(4.5, ColorsConvert.getContrastRatio(base.toString(), HydraColor.mOnSurfaceVariant.toString())) ? tinted : base;
    if (visualVariant !== "tinted-glass") {
      const muted = Qt.hsla(Math.max(0, tinted.hslHue), tinted.hslSaturation * Math.min(1, materialProfile.saturation), tinted.hslLightness, 1);
      tinted = HydraColor.blend(tinted, muted, 0.65);
      if (materialProfile.paper > 0) {
        const pigment = Qt.hsla(Math.max(0, HydraColor.mTertiary.hslHue), Math.min(0.12, HydraColor.mTertiary.hslSaturation), tinted.hslLightness, 1);
        tinted = HydraColor.blend(tinted, pigment, materialProfile.paper * 0.3);
      }
      if (materialProfile.depth > 0)
        tinted = Settings.data.colorSchemes.darkMode ? Qt.darker(tinted, 1 + materialProfile.depth) : Qt.lighter(tinted, 1 + materialProfile.depth * 0.25);
    }
    // Keep authored/dynamic ink pairs readable; never force a dark surface under dark ink.
    for (const ink of [HydraColor.mOnSurface, HydraColor.mOnSurfaceVariant]) {
      if (ColorsConvert.getContrastRatio(tinted.toString(), ink.toString()) < Math.min(4.5, ColorsConvert.getContrastRatio(base.toString(), ink.toString())))
        return base;
    }
    return tinted;
  }

  function materialFill(baseColor) {
    if (!customMaterial || baseColor.a === 0)
      return baseColor;
    return Qt.alpha(materialColor(baseColor), glassEffectsEnabled ? materialProfile.innerAlpha : (visualVariant === "tinted-glass" ? 1 : baseColor.a));
  }
  function materialRelief(baseColor, amount) {
    if (baseColor.a === 0)
      return baseColor;
    const relief = HydraColor.blend(baseColor, amount > 0 ? HydraColor.mOnSurface : HydraColor.mSurface, Math.abs(amount));
    for (const ink of [HydraColor.mOnSurface, HydraColor.mOnSurfaceVariant]) {
      if (ColorsConvert.getContrastRatio(relief.toString(), ink.toString()) < Math.min(4.5, ColorsConvert.getContrastRatio(baseColor.toString(), ink.toString())))
        return baseColor;
    }
    return Qt.alpha(relief, baseColor.a);
  }


  function materialOpacity(legacyOpacity) {
    return customMaterial ? (legacyOpacity === 0 ? 0 : glassBodyOpacity) : legacyOpacity;
  }

  function glassSurfaceOpacity(surface) {
    if (!glassEffectsEnabled)
      return 1;
    const bounds = glassBackdropBounds(surface, glassRequestedOpacity);
    return bounds.x <= bounds.y ? glassRequestedOpacity : 1;
  }

  function glassBackdropBounds(surface, alpha) {
    if (alpha >= 1)
      return Qt.vector2d(0, 1);
    const surfaceLuminance = ColorsConvert.getLuminance(surface.toString());
    let minimum = 0;
    let maximum = 1;
    for (const ink of [HydraColor.mOnSurface, HydraColor.mOnSurfaceVariant]) {
      const inkLuminance = ColorsConvert.getLuminance(ink.toString());
      const target = Math.min(4.5, (Math.max(surfaceLuminance, inkLuminance) + 0.05) / (Math.min(surfaceLuminance, inkLuminance) + 0.05));
      if (inkLuminance > surfaceLuminance)
        maximum = Math.min(maximum, (inkLuminance + 0.05) / target - 0.05);
      else
        minimum = Math.max(minimum, (inkLuminance + 0.05) * target - 0.05);
    }
    const toSrgb = value => value <= 0.0031308 ? 12.92 * value : 1.055 * Math.pow(value, 1 / 2.4) - 0.055;
    // Bound the composited RGB channels, so even a white/black wallpaper
    // preserves both reading roles. The shader only compresses outlying tones;
    // the chosen tint and the wallpaper's hue remain visible.
    const floor = (toSrgb(minimum) - alpha * Math.min(surface.r, surface.g, surface.b)) / (1 - alpha);
    const ceiling = (toSrgb(maximum) - alpha * Math.max(surface.r, surface.g, surface.b)) / (1 - alpha);
    return Qt.vector2d(Math.max(0, floor), Math.min(1, ceiling));
  }

  // Shadows
  readonly property real shadowOpacity: Math.min(1, 0.85 * materialProfile.shadow)
  readonly property real shadowBlur: 1.0
  readonly property int shadowBlurMax: 22
  readonly property real shadowHorizontalOffset: Settings.data.general.shadowOffsetX
  readonly property real shadowVerticalOffset: Settings.data.general.shadowOffsetY

  // Animation duration (ms).
  //
  // Easing convention (keep new animations on one of these three so panels
  // feel consistent — see SmartPanel.qml/ControlCenterPanel.qml for the
  // reference implementation):
  //   - Easing.OutCubic (open/show) + Easing.InCubic (close/hide): panel and
  //     surface open/close, size and position changes.
  //   - Easing.OutBack: interactive press/settle feedback (buttons, pills,
  //     toggles) — a small controlled overshoot, not OutBounce/OutElastic.
  //   - Easing.InOutQuad: passive state changes (hover/color fades) that
  //     aren't a direct response to a press.
  readonly property int animationFaster: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(75 * materialMotionScale / Settings.data.general.animationSpeed)
  readonly property int animationFast: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(150 * materialMotionScale / Settings.data.general.animationSpeed)
  readonly property int animationNormal: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(300 * materialMotionScale / Settings.data.general.animationSpeed)
  readonly property int animationSlow: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(450 * materialMotionScale / Settings.data.general.animationSpeed)
  readonly property int animationSlowest: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(750 * materialMotionScale / Settings.data.general.animationSpeed)
  // Pointer feedback settles quickly on leave so rapid traversal never trails.
  readonly property int hoverEnterDuration: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(100 / Settings.data.general.animationSpeed)
  readonly property int hoverLeaveDuration: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(30 / Settings.data.general.animationSpeed)

  // Material state layers tint the existing surface; they never replace selection.
  readonly property real stateHoverOpacity: 0.08
  readonly property real statePressedOpacity: 0.12

  function interactionContrast(backgroundColor, foregroundColor) {
    const surface = Qt.rgba(HydraColor.mSurface.r, HydraColor.mSurface.g, HydraColor.mSurface.b, 1);
    const background = Qt.tint(surface, backgroundColor);
    const foreground = Qt.tint(background, foregroundColor);
    return ColorsConvert.getContrastRatio(background.toString(), foreground.toString());
  }

  function interactionTint(baseColor, inkColor, opacity) {
    const base = typeof baseColor === "string" ? Qt.color(baseColor) : baseColor;
    const ink = typeof inkColor === "string" ? Qt.color(inkColor) : inkColor;
    if (base.a === 1)
      return Qt.tint(base, Qt.alpha(ink, opacity));
    // Qt.tint blends straight RGB; transparent bases need source-over weights
    // or the state ink is multiplied by its opacity twice when rendered.
    const baseWeight = base.a * (1 - opacity);
    const alpha = baseWeight + opacity;
    return Qt.rgba((base.r * baseWeight + ink.r * opacity) / alpha, (base.g * baseWeight + ink.g * opacity) / alpha, (base.b * baseWeight + ink.b * opacity) / alpha, alpha);
  }

  function interactionColor(baseColor, foregroundColor, hovered, pressed) {
    if (!hovered && !pressed)
      return baseColor;

    // Pick one ink for both states so hover -> press never reverses direction.
    // Legacy/custom roles may already be below 4.5: do not worsen them.
    const minimumContrast = Math.min(4.5, interactionContrast(baseColor, foregroundColor));
    const strongest = interactionTint(baseColor, foregroundColor, statePressedOpacity);
    let ink = foregroundColor;
    if (interactionContrast(strongest, foregroundColor) < minimumContrast) {
      const surfaceTint = interactionTint(baseColor, HydraColor.mSurface, statePressedOpacity);
      const contentTint = interactionTint(baseColor, HydraColor.mOnSurface, statePressedOpacity);
      ink = interactionContrast(surfaceTint, foregroundColor) >= interactionContrast(contentTint, foregroundColor) ? HydraColor.mSurface : HydraColor.mOnSurface;
    }
    return interactionTint(baseColor, ink, pressed ? statePressedOpacity : stateHoverOpacity);
  }

  function focusOutlineColor(baseColor, foregroundColor, preferredColor) {
    const pressedColor = interactionColor(baseColor, foregroundColor, false, true);
    if (Math.min(interactionContrast(baseColor, preferredColor), interactionContrast(pressedColor, preferredColor)) >= 3)
      return preferredColor;
    const surfaceContrast = Math.min(interactionContrast(baseColor, HydraColor.mSurface), interactionContrast(pressedColor, HydraColor.mSurface));
    const contentContrast = Math.min(interactionContrast(baseColor, HydraColor.mOnSurface), interactionContrast(pressedColor, HydraColor.mOnSurface));
    if (Math.max(surfaceContrast, contentContrast) >= 3)
      return contentContrast >= surfaceContrast ? HydraColor.mOnSurface : HydraColor.mSurface;
    // Legacy palettes can put both neutral roles too close to a filled action.
    // Adjust their tones only for the stroke; never rewrite the authored roles.
    let darkInk = HydraColor.mOnSurface;
    let lightInk = HydraColor.mSurface;
    for (let step = 0; step < 8; ++step) {
      darkInk = Qt.darker(darkInk, 1.25);
      if (Math.min(interactionContrast(baseColor, darkInk), interactionContrast(pressedColor, darkInk)) >= 3)
        return darkInk;
      lightInk = Qt.lighter(lightInk, 1.25);
      if (Math.min(interactionContrast(baseColor, lightInk), interactionContrast(pressedColor, lightInk)) >= 3)
        return lightInk;
    }
    return contentContrast >= surfaceContrast ? HydraColor.mOnSurface : HydraColor.mSurface;
  }

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

  readonly property color capsuleColor: Settings.data.bar.showCapsule ? Qt.alpha(Settings.data.bar.capsuleColorKey !== "none" ? HydraColor.resolveColorKey(Settings.data.bar.capsuleColorKey) : HydraColor.mSurfaceVariant, Settings.data.bar.capsuleOpacity) : "transparent"

  readonly property color capsuleBorderColor: Settings.data.bar.showOutline ? HydraColor.mPrimary : "transparent"
  readonly property int capsuleBorderWidth: Settings.data.bar.showOutline ? Style.borderS : 0

  readonly property color boxBorderColor: Settings.data.ui.boxBorderEnabled ? HydraColor.mOutline : "transparent"

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
