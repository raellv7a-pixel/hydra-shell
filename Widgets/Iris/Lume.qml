// Adapted from iNiR services/Lume.qml and ColorUtils.qml (GPL-3.0),
// d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c. Original veil/frost/mark/plate equations.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor

// Lume: how iNiR keeps content readable over whatever is behind it. Three steps, each usable alone:
//
// 1. Read what sits behind a rect (`read`): the wallpaper that output shows (preview included, a video's
//    still), summed from WallpaperLuma's grid: gamma level, spread and mean colour, instant and live. When
//    windows cover the output (`covered`), what shows through compositor blur is unknown: treat it as bright.
// 2. Decide the ink (`lightAfter`): dark ink once the backdrop is clearly light, light ink once it is
//    clearly dark, with a gap between the two thresholds so a moving surface never flickers.
// 3. Solve the material (`veil`, `frost`): the least alpha of a dark veil (light ink) or a light frost
//    (dark ink) that holds a contrast ratio over the worst part of the backdrop (mean ± weighted spread).
//
// 4. Plate a panel (`plateOver`, `stack`): a translucent body keeps its tint for the look and puts a plate
//    only under what holds text, as thick as the backdrop needs and no thicker.
//
// Consumers: desktop widgets (AbstractBackgroundWidget, iRiS faces via IrisStyle.legibleVeil/legibleFrost),
// Waffle's desktop clock, iRiS Places (IrisStyle.placePlate/readingCard: Settings sidebar and cards).
// Family tokens decide the colours; Lume decides how much of them.
Singleton {
    id: root

    readonly property int revision: WallpaperLuma.revision + root.wallpaperRevision
    property int wallpaperRevision: 0
    Connections {
        target: WallpaperService
        function onWallpaperChanged() { root.wallpaperRevision++ }
        function onIsInitializedChanged() { root.wallpaperRevision++ }
    }
    function screenNamed(name: string): var {
        return Quickshell.screens.find(screen => screen?.name === name) ?? null
    }
    function wallpaperOf(output: string): string {
        void root.wallpaperRevision
        return WallpaperLuma.imagePath(WallpaperService.getWallpaperPathForSlot(output, Settings.data.colorSchemes.darkMode ? "dark" : "light") || WallpaperService.defaultWallpaper || "")
    }
    // Hydra owns wallpaper selection and scaling; original grid/sRGB solves follow.
    function read(output: string, x: real, y: real, w: real, h: real): var {
        if (Settings.data.wallpaper.useSolidColor) {
            const c = Qt.color(Settings.data.wallpaper.solidColor)
            return { level: 0.299 * c.r + 0.587 * c.g + 0.114 * c.b, spread: 0, color: c, luminance: root.relativeLuminance(c) }
        }
        return root.readFrom(root.wallpaperOf(output), output, x, y, w, h)
    }
    function readFrom(path: string, output: string, x: real, y: real, w: real, h: real): var {
        void root.revision
        const screen = root.screenNamed(output)
        if (!screen || !path || /\.(webm|mp4|mkv|mov)$/i.test(path)) return null
        const mode = ({ crop: "fill", repeat: "tile" })[Settings.data.wallpaper.fillMode] ?? Settings.data.wallpaper.fillMode
        return WallpaperLuma.sample(path, Math.round(screen.width), Math.round(screen.height), x, y, w, h, mode)
    }
    function covered(output: string): bool {
        const workspace = CompositorService.getActiveWorkspaces().find(item => item.output === output)
        return workspace ? CompositorService.backend.windows.some(w => w.workspaceId === workspace.id && !w.scratchpad && !w.tabHidden && w.mapped !== false) : false
    }
    // Original root.relativeLuminance (the same threshold and exponents).
    function relativeLuminance(c: color): real {
        const r = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4)
        const g = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4)
        const b = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    function lightAfter(luminance: real, wasLight: bool, enter: real, leave: real): bool {
        if (luminance < 0) return false
        return wasLight ? luminance > (leave ?? 0.21) : luminance > (enter ?? 0.30)
    }

    // Qt and Niri blend in sRGB, not linear light, so veils and frosts are solved in gamma levels: in linear light a frost
    // over a dark region read far darker than planned, and a veil came out thicker than needed.
    // Alpha of a veil of `surface` over the backdrop so `ink` keeps `contrast` on its brightest part.
    function veil(level: real, spread: real, spreadWeight: real, surface: color, ink: color, contrast: real, floor: real, cap: real): real {
        if (level < 0) return Math.max(floor, 0.42)
        const worst = Math.min(1, level + spread * spreadWeight)
        const base = Math.pow(root.relativeLuminance(surface), 1 / 2.2)
        const allowed = Math.pow(Math.max(0, (root.relativeLuminance(ink) + 0.05) / contrast - 0.05), 1 / 2.2)
        const needed = worst > allowed ? (worst - allowed) / Math.max(0.001, worst - base) : 0
        return Math.max(floor, Math.min(cap, needed))
    }

    // Alpha of a frost of `surface` so dark `ink` keeps `contrast` on the backdrop's darkest part.
    function frost(level: real, spread: real, spreadWeight: real, surface: color, ink: color, contrast: real, floor: real, cap: real): real {
        if (level < 0) return Math.max(floor, 0.42)
        const darkest = Math.max(0, level - spread * spreadWeight)
        const needed = Math.pow(Math.max(0, (root.relativeLuminance(ink) + 0.05) * contrast - 0.05), 1 / 2.2)
        const surfaceLevel = Math.pow(root.relativeLuminance(surface), 1 / 2.2)
        const alpha = darkest < needed ? (needed - darkest) / Math.max(0.001, surfaceLevel - darkest) : 0
        return Math.max(floor, Math.min(cap, alpha))
    }

    // `seed`'s own hue at the lightness that keeps `contrast` on the worst part of a backdrop: deeper for dark ink,
    // brighter for light ink. Warm hues lean toward red as they deepen, where darkening alone turns them brown.
    function mark(seed: color, level: real, spread: real, darkInk: bool, contrast: real): color {
        const c = Qt.color(seed)
        if (level < 0 || c.hslSaturation < 0.08) return c
        const worst = Math.pow(darkInk ? Math.max(0, level - spread) : Math.min(1, level + spread), 2.2)
        const hue = Math.max(0, c.hslHue)
        let l = c.hslLightness
        let out = c
        for (let i = 0; i < 48; i++) {
            const lean = darkInk && hue > 0.05 && hue < 0.17 ? Math.min(1, (c.hslLightness - l) * 2.5) : 0
            out = Qt.hsla(hue - (hue - 0.04) * lean, c.hslSaturation, l, 1)
            const own = root.relativeLuminance(out)
            const ratio = darkInk ? (worst + 0.05) / (own + 0.05) : (own + 0.05) / (worst + 0.05)
            if (ratio >= contrast || l <= 0.08 || l >= 0.94) break
            l += darkInk ? -0.02 : 0.02
        }
        return out
    }

    // A plate inside a body that already veils its backdrop by `tint`: the alpha it adds to reach `needed`.
    // Two veils of one surface stack as 1 - (1 - a)(1 - b).
    function plateOver(tint: real, needed: real): real {
        return needed <= tint ? 0 : Math.min(1, (needed - tint) / Math.max(0.001, 1 - tint))
    }
    // `top` over `bottom`, both translucent, as one colour: a fill on a plate painted by one Rectangle.
    function stack(bottom: color, top: color): color {
        const a = top.a + bottom.a * (1 - top.a)
        if (a <= 0) return Qt.rgba(0, 0, 0, 0)
        const mixed = (t, b) => (t * top.a + b * bottom.a * (1 - top.a)) / a
        return Qt.rgba(mixed(top.r, bottom.r), mixed(top.g, bottom.g), mixed(top.b, bottom.b), a)
    }
}
