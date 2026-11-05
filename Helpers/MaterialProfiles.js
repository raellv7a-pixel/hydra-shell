.pragma library

// Material recipes, independent of palette generation, layout and persisted tweaks.
// Concepts informed by iNiR/iRiS; all rendering stays in Hydra's shared pipeline.
function recipe(values) {
    return Object.freeze(Object.assign({
        glass: false, opacity: 1, blur: 0, edge: 0, innerAlpha: 1,
        tint: 0, saturation: 1, radius: 1, motion: 1, shadow: 1,
        light: 0, chrome: 0, texture: 0, bloom: 0, refraction: 0,
        aurora: 0, paper: 0, depth: 0, warmth: 0
    }, values));
}

var profiles = Object.freeze({
    "material3": recipe({}),
    "tinted-glass": recipe({ glass: true, opacity: 0.56, blur: 0.85, edge: 0.4, innerAlpha: 0.48, tint: 0.0648 }),
    "liquid-glass": recipe({ glass: true, opacity: 0.34, blur: 0.66, edge: 0.72, innerAlpha: 0.3, tint: 0.04, radius: 1.25, motion: 1.15, light: 0.62, bloom: 0.08, refraction: 0.8, shadow: 1.12 }),
    "frost": recipe({ glass: true, opacity: 0.72, blur: 0.94, edge: 0.07 / 0.3, innerAlpha: 0.64, saturation: 0.45, radius: 1.05, motion: 1.1, light: 0.12, texture: 0.12, shadow: 0.65 }),
    "aurora": recipe({ glass: true, opacity: 0.43, blur: 0.9, edge: 0.46, innerAlpha: 0.4, tint: 0.12, saturation: 1.3, radius: 1.2, motion: 1.2, light: 0.38, aurora: 0.92, bloom: 0.28, shadow: 0.85 }),
    "obsidian": recipe({ edge: 0.07 / 0.3, saturation: 0.35, radius: 0.45, motion: 0.8, shadow: 1.15, light: 0.12, chrome: 0.08, depth: 0.12 }),
    "lume": recipe({ glass: true, opacity: 0.3, blur: 0.6, edge: 0.1, innerAlpha: 0.42, tint: 0.025, saturation: 0.85, radius: 1.1, light: 0.4, bloom: 0.16, shadow: 0.55 }),
    "afterglow": recipe({ opacity: 1, edge: 0.38, tint: 0.08, radius: 0.8, motion: 0.95, shadow: 1.08, light: 0.58, chrome: 0.38, bloom: 0.72, texture: 0.5, depth: 0.06, warmth: 0.8 }),
    "y2k": recipe({ glass: true, opacity: 0.58, blur: 0.7, edge: 0.86, innerAlpha: 0.5, tint: 0.08, saturation: 1.15, radius: 1.3, motion: 1.1, light: 0.78, chrome: 0.98, bloom: 0.12, texture: 0.035, refraction: 0.55, shadow: 1.15 }),
    "washi": recipe({ opacity: 1, saturation: 0.4, radius: 0.85, motion: 1.1, shadow: 0.45, light: 0.1, texture: 0.65, paper: 0.8, tint: 0.025 })
});

var ids = Object.freeze(Object.keys(profiles));

function resolveId(id) {
    return Object.prototype.hasOwnProperty.call(profiles, id) ? id : "material3";
}

function resolve(id) {
    return profiles[resolveId(id)];
}

// Preserve the recipe at the existing default, with useful travel on both sides.
// Zero recipe values stay absent; no effect reaches its maximum prematurely.
function calibrated(value, adjustment, reference, maximum) {
    const input = Number(adjustment);
    const amount = Math.max(0, Math.min(1, isFinite(input) ? input : reference));
    if (value <= 0 || amount === 0)
        return 0;
    if (amount <= reference)
        return value * amount / reference;
    return value + (Math.max(value, maximum) - value) * (amount - reference) / (1 - reference);
}
