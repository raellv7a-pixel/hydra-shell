"""Material spec dispatch after Hydra's existing seed extraction.

2021 and unsupported 2025 variants deliberately retain Hydra's historical engine.
The optional import is only needed when a real 2025 palette is requested.
"""
import re

from .color import Color
from .theme import generate_theme

SPEC_2025_SCHEMES = frozenset(("tonal-spot", "m3-vibrant", "expressive", "neutral"))


class MaterialSpecError(RuntimeError):
    """The requested real Material backend is unavailable."""


def effective_material_spec(scheme_type: str, material_spec: str) -> str:
    return "2025" if material_spec == "2025" and scheme_type in SPEC_2025_SCHEMES else "2021"


def generate_spec_palette(
    palette: list[Color], mode: str, scheme_type: str,
    material_spec: str = "2025", contrast: float = 0.0,
) -> dict[str, str]:
    if effective_material_spec(scheme_type, material_spec) == "2021":
        return generate_theme(palette, mode, scheme_type)

    try:
        from materialyoucolor.dynamiccolor.dynamic_scheme import DynamicScheme
        from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
        from materialyoucolor.dynamiccolor.variant import Variant
        from materialyoucolor.hct.hct import Hct
    except ImportError as error:
        raise MaterialSpecError(
            "Material 2025 requires materialyoucolor >=3.0.2,<4 "
            "(Arch: python-materialyoucolor3). Install it before generating 2025 palettes."
        ) from error

    variants = {
        "tonal-spot": Variant.TONAL_SPOT,
        "m3-vibrant": Variant.VIBRANT,
        "expressive": Variant.EXPRESSIVE,
        "neutral": Variant.NEUTRAL,
    }
    source = palette[0]
    argb = 0xff000000 | (source.r << 16) | (source.g << 8) | source.b
    # 2025 has no reduced-contrast schemes. Explicit phone platform matches DMS.
    scheme = DynamicScheme(
        Hct.from_int(argb), variants[scheme_type], max(0.0, contrast), mode == "dark",
        platform="phone", spec_version="2025",
    )
    roles = MaterialDynamicColors(spec="2025")
    return {
        re.sub(r"(?<!^)(?=[A-Z])", "_", color.name).lower():
            f"#{color.get_argb(scheme) & 0xffffff:06x}"
        for color in roles.all_colors
    }
