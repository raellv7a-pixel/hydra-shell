.pragma library

// Adapted from iNiR (GPL-3.0), modules/iris/settings/IrisThemes.qml and
// modules/iris/style/IrisStyle.qml, d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c.
// Only material parameters are ported: Hydra keeps its layout and navigation.
function recipe(values) {
    const p = Object.assign({
        iris: true, language: "iris", preset: "iris", surface: "black",
        glass: false, glassTint: 0.58, glassBlur: 1,
        edgeLight: 0.34, edgeLine: 0.10, edgeWidth: 1.5,
        tint: 0, fill: 1, lines: 1, contrast: 1, shadow: 1,
        shape: 1, melt: 0, glow: 0, rim: true,
        aura: "subtle", lightReach: 1, adaptive: 0,
        accent: "blue", accentHue: 212, highlight: "orange", highlightHue: 32,
        afterglow: false, grade: "dusk", atmosphere: 0.60,
        chrome: 0.65, bloom: 0.50, signal: 0.35,
    }, values);
    if (!p.afterglow) { p.chrome = 0; p.bloom = 0; }
    return Object.freeze(p);
}

var profiles = Object.freeze({
    "material3": recipe({ iris: false, aura: "off", rim: false }),
    "tinted-glass": recipe({ iris: false, glass: true, surface: "theme", accent: "theme", highlight: "theme", glassTint: 0.56, rim: false }),
    "liquid-glass": recipe({ glass: true, glassTint: 0.42, preset: "round", shape: 1.15, melt: 0.55, lines: 0, shadow: 1.10, glow: 0.20, rim: false, aura: "vivid", lightReach: 1.70, accent: "wallpaper", highlight: "wallpaper" }),
    "frost": recipe({ glass: true, glassTint: 0.56, surface: "graphite", preset: "soft", lines: 0.35, shadow: 0.80, melt: 0.15, rim: false, accent: "custom", accentHue: 196, highlight: "custom", highlightHue: 188 }),
    "aurora": recipe({ glass: true, glassTint: 0.44, surface: "wallpaper", tint: 0.60, preset: "soft", shape: 1.25, melt: 0.60, lines: 0, glow: 0.20, rim: false, aura: "vivid", lightReach: 2.60, accent: "wallpaper", highlight: "wallpaper" }),
    "obsidian": recipe({ preset: "angular", shape: 0.70, lines: 1.30, shadow: 1.50, fill: 1.15, rim: false, aura: "off", accent: "lilac", highlight: "accent" }),
    "lume": recipe({ glass: true, glassTint: 0.40, surface: "wallpaper", tint: 0.20, preset: "soft", lines: 0.20, rim: false, adaptive: 0.60, accent: "wallpaper", highlight: "wallpaper" }),
    "afterglow": recipe({ afterglow: true, grade: "dusk", atmosphere: 0.75, chrome: 0.70, bloom: 0.60, signal: 0.40, preset: "crisp", shape: 0.85, lines: 0.60, glow: 0.40, shadow: 1.20, aura: "vivid", lightReach: 1.90, accent: "custom", accentHue: 32, highlight: "custom", highlightHue: 170 }),
    "y2k": recipe({ afterglow: true, grade: "cyber", atmosphere: 0.65, chrome: 0.90, bloom: 0.55, signal: 0.25, glass: true, glassTint: 0.64, surface: "midnight", preset: "round", shape: 1.20, lines: 0.40, glow: 0.50, lightReach: 1.60, accent: "custom", accentHue: 198, highlight: "custom", highlightHue: 86 }),
    // Washi is the original palette language (OKLCH paper/sumi/pigment solver),
    // not a noise texture. Both schemes are solved by the same original engine.
    "washi": recipe({ language: "washi" })
});

var ids = Object.freeze(Object.keys(profiles));

function resolveId(id) {
    return Object.prototype.hasOwnProperty.call(profiles, id) ? id : "material3";
}

function resolve(id) {
    return profiles[resolveId(id)];
}

