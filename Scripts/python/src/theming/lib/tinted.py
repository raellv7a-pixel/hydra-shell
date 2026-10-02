# SPDX-License-Identifier: GPL-2.0-or-later
# Port of Matugen Studio's src-tauri/src/commands/color.rs, raellx22.
# Reference: cad6db3b178ee73c73bbd1facb869e3aaa16e49a
"""Tinted surface finishing, independent of palette generation and output format."""

import math
from collections.abc import Iterable

MAX_TINT = 0.18
MONOCHROME_THRESHOLD = 0.035

# Hydra's wallust-like vibrant is NOT Material's SchemeVibrant.
MATERIAL_SCHEMES = {
    "tonal-spot": "Tonal Spot",
    "content": "Content",
    "fruit-salad": "Fruit Salad",
    "rainbow": "Rainbow",
    "monochrome": "Monochrome",
    "expressive": "Expressive",
    "fidelity": "Fidelity",
    "neutral": "Neutral",
    "m3-vibrant": "Vibrant",
}

_STRENGTHS = {
    "Monochrome": 0.0,
    "Neutral": 0.025,
    "Tonal Spot": 0.045,
    "Content": 0.075,
    "Fidelity": 0.09,
    "Expressive": 0.105,
    "Fruit Salad": 0.12,
    "Rainbow": 0.12,
    "Vibrant": 0.14,
}

SURFACE_MULTIPLIERS = {
    "background": 0.55,
    "surface": 0.72,
    "surface_dim": 0.64,
    "surface_bright": 0.68,
    "surface_container_lowest": 0.56,
    "surface_container_low": 0.76,
    "surface_container": 0.92,
    "surface_container_high": 1.05,
    "surface_container_highest": 1.16,
    "surface_variant": 0.48,
}


def surface_tint_strength(scheme_type: str) -> float:
    """Resolve actual M3 aliases; unknown/non-Material engines stay classic."""
    return _STRENGTHS.get(MATERIAL_SCHEMES.get(scheme_type, scheme_type), 0.0)


def grayscale_score(pixels: Iterable[tuple[int, ...]]) -> float:
    """Studio's average RGB channel spread, skipping fully transparent pixels."""
    total = 0.0
    count = 0
    for pixel in pixels:
        if len(pixel) == 4 and pixel[3] == 0:
            continue
        r, g, b = pixel[:3]
        total += max(r / 255.0, g / 255.0, b / 255.0) - min(r / 255.0, g / 255.0, b / 255.0)
        count += 1
    return total / count if count else 0.0


def mix_hex(base: str, tint: str, amount: float) -> str:
    """Encoded-sRGB interpolation with Rust's positive half-up rounding.

    Studio's output is opaque #RRGGBB (input alpha is not part of the blend).
    """
    base = base.removeprefix("#")
    tint = tint.removeprefix("#")
    channels = (
        math.floor(int(base[i:i + 2], 16) * (1.0 - amount)
                   + int(tint[i:i + 2], 16) * amount + 0.5)
        for i in (0, 2, 4)
    )
    return "#" + "".join(f"{channel:02X}" for channel in channels)


def apply_surface_tint(
    roles: dict[str, str],
    scheme_type: str,
    surface_style: str = "classic",
    wallpaper_grayscale_score: float | None = None,
) -> bool:
    """Finish one normalized mode in place; return whether tint was applied.

    Smart Monochrome suppresses tint only: it does not replace Hydra's engine
    or its accents. Caller applies this only to generated wallpaper palettes,
    never authored predefined schemes or imported JSON snapshots.
    """
    if surface_style != "tinted":
        return False
    strength = surface_tint_strength(scheme_type)
    if strength <= 0.0 or (
        wallpaper_grayscale_score is not None
        and wallpaper_grayscale_score <= MONOCHROME_THRESHOLD
    ):
        return False
    primary = roles.get("primary")
    if primary is None:
        return False
    for role, multiplier in SURFACE_MULTIPLIERS.items():
        if role in roles:
            amount = min(MAX_TINT, max(0.0, strength * multiplier))
            roles[role] = mix_hex(roles[role], primary, amount)
    return True
