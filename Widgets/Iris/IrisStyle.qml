// Material subset adapted from iNiR modules/iris/style/IrisStyle.qml (GPL-3.0),
// d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c. Original field/light equations;
// Hydra replaces Config/Appearance, not the renderer or its material grades.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Services.Compositor
import "../../Helpers/MaterialProfiles.js" as MaterialProfiles

Singleton {
    id: root

    readonly property string visualVariant: MaterialProfiles.resolveId(Settings.data.ui.visualVariant)
    readonly property var profile: MaterialProfiles.resolve(root.visualVariant)
    readonly property bool enabled: root.visualVariant !== "material3"
    readonly property bool effectsEnabled: root.enabled && !PowerProfileService.hydraPerformanceMode && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property string scheme: Settings.data.colorSchemes.darkMode ? "dark" : "light"
    readonly property bool light: root.scheme !== "dark"
    readonly property bool ink: root.scheme === "ink"
    readonly property real density: Math.max(0.8, Math.min(1.35, Settings.data.general.scaleRatio))
    readonly property var washi: IrisWashi.palette(root.scheme)
    readonly property var washiDark: IrisWashi.palette("dark")
    readonly property var washiLight: IrisWashi.palette("light")
    function role(name: string, fallback: color): color {
        return root.profile.iris ? Qt.color(root.washi?.[name] ?? fallback) : fallback
    }
    function amount(value: real): real { return Math.max(0, Math.min(1, value)) }
    // Original ColorUtils.mix weights the first colour, unlike HydraColor.blend.
    function mix(first: color, second: color, weight: real): color {
        return Qt.rgba(weight * first.r + (1 - weight) * second.r,
            weight * first.g + (1 - weight) * second.g,
            weight * first.b + (1 - weight) * second.b,
            weight * first.a + (1 - weight) * second.a)
    }
    readonly property real lighting: root.effectsEnabled ? root.amount(Settings.data.ui.materialLighting) : 0
    readonly property real signalAmount: root.effectsEnabled ? root.amount(Settings.data.ui.materialTexture) : 0
    function tweak(name: string, low: real, high: real): real {
        const value = name === "lightReach" ? root.profile.lightReach : (root.profile[name] ?? 1)
        return Math.max(low, Math.min(high, value * IrisMood.factor(name)))
    }
    readonly property var presets: ({
        iris: { fill: 1, shape: 1 }, soft: { fill: 0.78, shape: 1.22 },
        crisp: { fill: 1.12, shape: 0.7 }, round: { fill: 0.9, shape: 1.5 },
        angular: { fill: 1.08, shape: 0.42 }
    })
    readonly property var preset: root.presets[root.profile.preset] ?? root.presets.iris
    readonly property color surfaceOpaque: root.role("surface", HydraColor.sourceSurface)
    readonly property color surfaceHighOpaque: root.role("surfaceHigh", HydraColor.surfaceContainerRoles.mSurfaceContainerHigh ?? HydraColor.sourceSurface)
    readonly property color surfaceHighestOpaque: root.role("surfaceHighest", HydraColor.surfaceContainerRoles.mSurfaceContainerHighest ?? HydraColor.sourceSurface)
    readonly property color darkSurfaceOpaque: Qt.color(root.washiDark?.materials?.[root.profile.surface] ?? "#000000")
    readonly property color surface: root.surfaceOpaque
    readonly property color bodySurface: root.surfaceOpaque
    readonly property color text: root.role("text", HydraColor.sourceColors.mOnSurface)
    readonly property color accent: root.role("accent", HydraColor.sourcePrimary)
    readonly property color secondaryAccent: root.role("highlight", HydraColor.sourceSecondary)
    readonly property real tintAmount: root.profile.tint * root.amount(Settings.data.ui.glassTint)
    function tinted(base: color, strength: real): color {
        return root.tintAmount <= 0 ? base : root.mix(base, root.accent, 1 - strength * root.tintAmount)
    }
    function fillAlpha(level: real): real { return Math.min(0.5, level * root.preset.fill * root.tweak("fill", 0.3, 2)) }
    readonly property bool glassy: root.profile.glass && root.effectsEnabled && Settings.data.general.enableBlurBehind
    // These presets request wallpaper glass. Hydra has no compositor-backdrop
    // protocol: retain the original wallpaper fallback rather than simulate one.
    readonly property bool glassCompositor: false
    readonly property bool glassWallpaper: root.glassy && !root.glassCompositor
    readonly property string glassRequested: root.profile.glass ? "wallpaper" : "off"
    readonly property real glassBlurAmount: root.profile.glassBlur * root.amount(Settings.data.ui.glassBlur)
    readonly property int glassBlurMax: 48
    readonly property real glassSaturation: 0.3
    // Hydra's sliders are 0..1 strengths of the curated material. Unlike the
    // original global 0.12 floor, zero is truly clear. Lume protects reading
    // surfaces separately (readingPlate/Card/Sidebar), as the original Places do.
    readonly property real wallpaperGlassTint: root.profile.glassTint * root.amount(Settings.data.ui.glassTint)
    readonly property real glassTint: root.wallpaperGlassTint
    readonly property real glassLip: 0
    readonly property color bodyTint: root.glassy ? Qt.alpha(root.surfaceOpaque, root.glassTint) : root.bodySurface
    readonly property color bodyFill: root.glassy ? Qt.color("transparent") : root.bodySurface
    readonly property color bodyScrim: root.bodyTint
    readonly property color bodyClip: Qt.rgba(0, 0, 0, 0.004)

    // Fixed photographic grades, never palette approximations (original lines 337–365).
    readonly property bool afterglow: root.profile.afterglow && root.effectsEnabled
    readonly property var afterglowGrades: ({
        dusk: { shadow: "#0f4a42", light: "#ffbe73", bloom: "#ff9442" },
        cyber: { shadow: "#0d2f66", light: "#cfefff", bloom: "#55c8ff" },
        fog: { shadow: "#33402a", light: "#e6efc4", bloom: "#bcd98c" }
    })
    readonly property string afterglowGrade: root.profile.grade
    readonly property var afterglowPalette: root.afterglowGrades[root.afterglowGrade] ?? root.afterglowGrades.dusk
    readonly property real afterglowAtmosphere: root.profile.atmosphere * root.lighting
    readonly property real afterglowChrome: root.profile.chrome * root.lighting * root.amount(Settings.data.ui.glassEdgeLight)
    readonly property real afterglowBloom: root.profile.bloom * root.lighting
    readonly property real afterglowSignal: root.profile.signal * root.signalAmount
    readonly property real afterglowBloomRadius: Math.round(9 * root.density)
    readonly property real afterglowReach: root.afterglow && !root.light && root.afterglowBloom > 0 ? 3.5 * root.afterglowBloomRadius : 0
    readonly property bool afterglowTreatment: root.afterglow && (root.lighting > 0 || root.afterglowSignal > 0)
    readonly property bool afterglowWallpaper: root.afterglowTreatment
    function colourVector(c: color, w: real): vector4d { return Qt.vector4d(c.r, c.g, c.b, w) }
    readonly property vector4d afterglowMix: Qt.vector4d(root.afterglowTreatment ? 1 : 0, root.afterglowChrome, root.afterglowBloom, root.afterglowSignal)
    readonly property vector4d afterglowShadow: root.colourVector(Qt.color(root.afterglowPalette.shadow), root.light ? 1 : 0)
    readonly property vector4d afterglowLight: root.colourVector(Qt.color(root.afterglowPalette.light), root.afterglowAtmosphere)
    readonly property vector4d afterglowBloomInk: root.colourVector(Qt.color(root.afterglowPalette.bloom), root.afterglowBloomRadius)
    readonly property vector4d afterglowShape: Qt.vector4d(Math.round(8 * root.density), 3, 1.25 * root.density, 0)
    readonly property bool textured: root.afterglow
    readonly property color fillInk: root.afterglow && !root.light
        ? root.mix(Qt.color(root.afterglowPalette.light), root.text, 0.5 * root.afterglowAtmosphere)
        : root.tinted(root.role("fillInk", root.text), 0.22)
    readonly property color surfaceHigh: root.glassy || root.textured
        ? Qt.alpha(root.light ? root.text : root.fillInk, root.fillAlpha(root.light ? 0.06 : 0.07)) : root.tinted(root.surfaceHighOpaque, 0.16)
    readonly property color surfaceHighest: root.glassy || root.textured
        ? Qt.alpha(root.light ? root.text : root.fillInk, root.fillAlpha(root.light ? 0.1 : 0.12)) : root.tinted(root.surfaceHighestOpaque, 0.2)

    function vividHighlight(seed: color, fallback: color): color {
        const c = Qt.color(seed)
        if (!c.valid || c.hslHue < 0 || c.hslSaturation < 0.1) return fallback
        return Qt.hsla(c.hslHue, Math.max(0.62, Math.min(0.95, c.hslSaturation + 0.2)), Math.max(0.54, Math.min(0.66, c.hslLightness)), 1)
    }
    readonly property color wallpaperLight: root.afterglow
        ? root.vividHighlight(Qt.color(root.afterglowPalette.bloom), root.accent)
        : root.vividHighlight(IrisMood.seed, root.vividHighlight(HydraColor.sourcePrimary, root.accent))
    readonly property string auraName: root.profile.aura
    readonly property real auraStrength: ({ off: 0, subtle: 0.2, vivid: 0.36 })[root.auraName] * root.lighting
    readonly property int lightContour: Math.max(4, Math.round(6 * root.density))
    readonly property int lightJoinContour: root.lightContour + Math.round(Math.min(root.fuseDeep, 30 * root.density) / 3)
    readonly property int lightReach: Math.round(92 * root.density * root.tweak("lightReach", 0.5, 3))
    function aura(light: color): color { return Qt.alpha(light, root.auraStrength * light.a) }
    function auraFading(light: color): color { return Qt.alpha(light, root.auraStrength * light.a * 0.35) }
    readonly property real glassEdgeLight: root.effectsEnabled ? root.profile.edgeLight * root.amount(Settings.data.ui.glassEdgeLight) : 0
    readonly property real glassEdgeLine: root.effectsEnabled ? root.profile.edgeLine * root.amount(Settings.data.ui.glassEdgeLight) : 0
    readonly property real glassEdgeWidth: root.profile.edgeWidth
    readonly property color glassEdgeColour: {
        const l = root.wallpaperLight
        return Qt.rgba(l.r * 0.45 + 0.55, l.g * 0.45 + 0.55, l.b * 0.45 + 0.55, 1)
    }
    readonly property color border: Qt.alpha(root.text, Math.min(0.5, 0.14 * root.preset.fill * root.tweak("lines", 0, 2)) * root.amount(Settings.data.ui.glassEdgeLight))
    readonly property string edgeStyle: !root.profile.rim || root.afterglow ? "none" : "line"
    readonly property bool edgeLit: root.edgeStyle === "light" && (root.glassEdgeLight > 0 || root.glassEdgeLine > 0)
    readonly property color rim: root.edgeStyle === "line" ? root.border : Qt.color("transparent")
    readonly property int rimWidth: Math.max(1, Math.round(root.density))
    readonly property color sheen: root.glassEdgeColour
    readonly property real glow: root.profile.glow
    function glowing(alpha: real): color {
        const ink = root.mix(root.accent, Qt.color("black"), root.glow)
        return Qt.alpha(ink, Math.min(0.9, alpha * (1 + 0.4 * root.glow)))
    }
    readonly property real shadowThrough: root.glassy ? 0.4 : 1
    readonly property real shadowLight: root.ink ? 0.5 : root.light ? 0.55 : 1
    readonly property color shadow: root.effectsEnabled && Settings.data.general.enableShadows
        ? root.glowing(Math.min(0.9, 0.55 * root.tweak("shadow", 0, 1.6)) * root.shadowThrough * root.shadowLight) : Qt.color("transparent")
    readonly property real meltDepth: {
        const t = root.tweak("melt", 0, 2)
        return t <= 1 ? t : 1 + (t - 1) * 0.5
    }
    readonly property int fuse: Math.max(2, Math.round(8 * root.density * root.meltDepth))
    readonly property int fuseDeep: Math.max(4, Math.round(30 * root.density * root.meltDepth))
    readonly property real shapeScale: root.preset.shape * root.tweak("shape", 0.3, 1.6)
    function corner(px: real): int {
        const cap = px >= 18 ? 1.3 : px >= 10 ? 1.4 : 1.6
        return Math.max(2, Math.round(px * Math.min(root.shapeScale, cap) * root.density))
    }

    // Original Lume material targets and Places reading-plate composition.
    readonly property var materialVeil: ({ glass: 0.3, clear: 0.04, panel: 0.3 })
    readonly property var materialContrast: ({ glass: 4.5, clear: 3, panel: 7 })
    readonly property var materialSpread: ({ glass: 1, clear: 1.2, panel: 1.2 })
    readonly property real paperGlass: 0.66
    function paperFloor(paper: color, level: real, strength: real): real {
        const paperLevel = Math.pow(Lume.relativeLuminance(paper), 1 / 2.2)
        const target = (paperLevel - 0.06) * Math.min(1, strength)
        return level < target ? Math.min(0.86, (target - level) / Math.max(0.001, paperLevel - level)) : 0
    }
    function legibleVeil(material: string, level: real, spread: real, strength: real): real {
        const contrast = root.materialContrast[material] ?? 4.5
        const floor = (root.materialVeil[material] ?? 0.3) * strength
        return root.light ? Math.max(Lume.frost(level, spread, root.materialSpread[material] ?? 1, root.surfaceOpaque, root.text, contrast, floor, 0.86),
                level < 0 || strength <= 0 || material === "clear" ? 0 : root.paperFloor(root.surfaceOpaque, Math.max(0, level - spread), strength),
                material === "clear" || strength <= 0 ? 0 : root.paperGlass * strength)
            : Lume.veil(level, spread, root.materialSpread[material] ?? 1, root.surfaceOpaque, root.text, contrast, floor, 0.86)
    }
    readonly property real wallpaperVeil: IrisMood.sampled
        ? Math.max(0.22, Math.min(0.72, root.legibleVeil("glass", IrisMood.luminance, IrisMood.contrast * 0.5, 0.6))) : 0.22
    readonly property string placeOutput: CompositorService.focusedOutputName || Quickshell.screens[0]?.name || ""
    readonly property bool placeCovered: root.glassCompositor && Lume.covered(root.placeOutput)
    readonly property real placePlate: {
        void Lume.revision
        if (!root.glassy) return 0
        let level = 0.72, spread = 0.18
        if (!root.placeCovered) {
            const screen = Lume.screenNamed(root.placeOutput)
            const sample = screen ? Lume.read(root.placeOutput, screen.width * 0.2, screen.height * 0.12, screen.width * 0.6, screen.height * 0.76) : null
            if (!sample) return 1
            level = sample.level
            spread = sample.spread
        }
        return Lume.plateOver(root.glassTint, root.legibleVeil("glass", level, spread, 0))
    }
    readonly property color readingPlate: Qt.alpha(root.surfaceOpaque, root.placePlate)
    readonly property color readingCard: root.glassy ? Lume.stack(root.readingPlate, root.surfaceHigh) : root.surfaceHigh
    readonly property color readingSidebar: root.glassy ? Qt.alpha(root.surfaceOpaque, Math.max(root.wallpaperVeil, root.placePlate)) : root.surfaceHigh

    // Same original plateOver + veil/frost solve, evaluated for a Hydra card's
    // actual output-space rect rather than the original fixed Places rectangle.
    function readingFill(output: string, x: real, y: real, width: real, height: real, highest: bool): color {
        void Lume.revision
        const top = highest ? root.surfaceHighest : root.surfaceHigh
        if (!root.glassy) return top
        const sample = Lume.read(output, x, y, width, height)
        // Never expose reading ink over an unanalysed image during first load.
        if (!sample) return root.surfaceOpaque
        // Hydra reading cards use secondary ink, unlike the upstream Places
        // primary-only plate. Keep the original veil/frost solve and account for
        // the translucent top fill before solving, rather than veil twice.
        const ink = HydraColor.mOnSurfaceVariant
        const topLevel = Math.pow(Lume.relativeLuminance(top), 1 / 2.2)
        const level = sample.level * (1 - top.a) + topLevel * top.a
        const spread = sample.spread * (1 - top.a)
        const base = Lume.stack(root.surfaceOpaque, top)
        const needed = root.light
            ? Lume.frost(level, spread, 1, base, ink, 4.5, 0, 0.86)
            : Lume.veil(level, spread, 1, base, ink, 4.5, 0, 0.86)
        return Lume.stack(Qt.alpha(root.surfaceOpaque, Lume.plateOver(root.glassTint, needed)), top)
    }

    // Original prism/lens defaults remain well-formed for the unchanged field
    // shader. No requested profile enables the light-leak material.
    readonly property bool leak: false
    readonly property real leakReach: 0
    readonly property vector4d leakMix: Qt.vector4d(0, 0.6, 0.55, 0.5)
    readonly property vector4d leakFilm: Qt.vector4d(0.55, 0.15, Math.max(1, 1.6 * root.density), Math.round(14 * root.density))
    readonly property vector4d leakBody: Qt.vector4d(Math.round(6 * root.density), 0.6, 1, 0)
    readonly property vector4d leakStop0: root.colourVector(Qt.color("#ff5a3c"), root.light ? 1 : 0)
    readonly property vector4d leakStop1: root.colourVector(Qt.color("#ffcf6b"), 0)
    readonly property vector4d leakStop2: root.colourVector(Qt.color("#d8fbff"), 0)
    readonly property vector4d leakStop3: root.colourVector(Qt.color("#4f86ff"), 0)
    readonly property vector4d leakStop4: root.colourVector(Qt.color("#a35dff"), 0)
    readonly property vector4d leakCore: root.colourVector(Qt.color("#fff6ea"), 0)
    readonly property vector4d leakAt0: Qt.vector4d(0.5, 0.47, 0.6, 0.3)
    readonly property vector4d leakAt1: Qt.vector4d(0.5, 0.53, 0.72, 0.022)
    readonly property vector4d leakAt2: Qt.vector4d(0.5, 0.5, 0.95, 0.55)
    readonly property vector4d leakForm0: Qt.vector4d(0, 0.95, 0, 0.2)
    readonly property vector4d leakForm1: Qt.vector4d(0, 1.4, 0, 0)
    readonly property vector4d leakForm2: Qt.vector4d(0, 0.22, 0, 0)
    readonly property vector4d leakHue0: Qt.vector4d(0.22, 0.62, 0.18, 0)
    readonly property vector4d leakHue1: Qt.vector4d(0.06, 0.14, 0, 0)
    readonly property vector4d leakHue2: Qt.vector4d(0.85, 0, 0, 0)
}
