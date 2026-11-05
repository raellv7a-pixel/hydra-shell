.pragma library

// Material recipes, independent of palette generation, layout and persisted tweaks.
// Concepts informed by iNiR/iRiS; all rendering stays in Hydra's shared pipeline.
function recipe(values) {
    return Object.freeze(Object.assign({
        glass: false, opacity: 1, blur: 0, edge: 0, innerAlpha: 1,
        tint: 0, saturation: 1, radius: 1, motion: 1, shadow: 1,
        light: 0, chrome: 0, texture: 0, bloom: 0, refraction: 0,
        aurora: 0, paper: 0, depth: 0
    }, values));
}

var profiles = Object.freeze({
    "material3": recipe({}),
    "tinted-glass": recipe({ glass: true, opacity: 0.56, blur: 0.85, edge: 0.12, innerAlpha: 0.48, tint: 0.065 }),
    "liquid-glass": recipe({ glass: true, opacity: 0.36, blur: 0.72, edge: 0.22, innerAlpha: 0.32, tint: 0.045, radius: 1.25, motion: 1.15, light: 0.65, refraction: 0.65, shadow: 1.12 }),
    "frost": recipe({ glass: true, opacity: 0.72, blur: 1, edge: 0.07, innerAlpha: 0.64, saturation: 0.45, radius: 1.05, motion: 1.1, light: 0.12, texture: 0.12, shadow: 0.65 }),
    "aurora": recipe({ glass: true, opacity: 0.43, blur: 0.9, edge: 0.16, innerAlpha: 0.4, tint: 0.12, saturation: 1.35, radius: 1.2, motion: 1.2, light: 0.65, aurora: 0.85, bloom: 0.22, shadow: 0.85 }),
    "obsidian": recipe({ edge: 0.07, saturation: 0.35, radius: 0.45, motion: 0.8, shadow: 1.15, light: 0.12, chrome: 0.08, depth: 0.12 }),
    "lume": recipe({ glass: true, opacity: 0.3, blur: 0.6, edge: 0.035, innerAlpha: 0.42, tint: 0.025, saturation: 0.85, radius: 1.1, light: 0.08, shadow: 0.55 }),
    "afterglow": recipe({ opacity: 1, edge: 0.18, tint: 0.08, radius: 0.8, motion: 0.95, shadow: 1.1, light: 0.7, chrome: 0.7, bloom: 0.65, texture: 0.45, depth: 0.06 }),
    "y2k": recipe({ glass: true, opacity: 0.58, blur: 0.8, edge: 0.26, innerAlpha: 0.5, tint: 0.08, saturation: 1.15, radius: 1.3, motion: 1.1, light: 0.75, chrome: 0.95, bloom: 0.4, texture: 0.12, refraction: 0.35 }),
    "washi": recipe({ opacity: 1, saturation: 0.4, radius: 0.85, motion: 1.1, shadow: 0.45, light: 0.1, texture: 0.65, paper: 0.8, tint: 0.025 })
});

var ids = Object.freeze(Object.keys(profiles));

function resolveId(id) {
    return Object.prototype.hasOwnProperty.call(profiles, id) ? id : "material3";
}

function resolve(id) {
    return profiles[resolveId(id)];
}

function scaled(value, adjustment, reference, low, high) {
    const amount = Number(adjustment);
    return Math.max(low, Math.min(high, value * (isFinite(amount) ? amount : reference) / reference));
}
