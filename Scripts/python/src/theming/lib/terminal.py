"""Derived terminal roles. Run after surfaces; never modify Material roles.

ANSI hues retain their semantic color families. Each family is harmonized by
12% of the shortest hue distance to a Material accent (red uses error), with
accent chroma and contrast-adjusted tones. Bright colors are more emphatic:
lighter on dark backgrounds, darker on light backgrounds. Authored terminal
roles in predefined schemes always win.
"""
from typing import Dict

from .color import Color
from .hct import Hct
from .theme import ensure_contrast

ANSI_NAMES = ('black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white')


def derive_terminal_roles(roles: Dict[str, str], mode: str) -> Dict[str, str]:
    result = dict(roles)
    required = ('surface', 'on_surface', 'on_surface_variant', 'primary',
                'primary_container', 'on_primary_container', 'secondary', 'tertiary', 'error')
    if not all(role in roles for role in required):
        # Generic JSON palettes remain valid inputs; don't invent missing Material colors.
        # Templates requesting synthetic roles without this context get normal renderer errors.
        return result
    background = Color.from_hex(roles.get('terminal_background', roles['surface']))
    foreground = Color.from_hex(roles.get('terminal_foreground', roles['on_surface']))
    dark = mode == 'dark'

    def put(name: str, color: Color, against=background, contrast=4.5):
        result.setdefault('terminal_' + name, ensure_contrast(color, against, contrast).to_hex())

    result.setdefault('terminal_background', background.to_hex())
    put('foreground', foreground)
    put('cursor', Color.from_hex(roles['primary']), contrast=3.0)
    selection = Color.from_hex(roles['primary_container'])
    result.setdefault('terminal_selection_background', selection.to_hex())
    put('selection_foreground', Color.from_hex(roles['on_primary_container']), selection)

    neutral = Color.from_hex(roles['on_surface_variant']).to_hct()
    put('normal_black', Color.from_hct(Hct(neutral.hue, neutral.chroma, 50 if dark else 45)))
    put('bright_black', Color.from_hct(Hct(neutral.hue, neutral.chroma, 65 if dark else 30)))
    put('normal_white', foreground)
    put('bright_white', Color.from_hct(foreground.to_hct().set_tone(95 if dark else 10)))

    families = {
        'red': (None, 'error'), 'green': (140, 'tertiary'),
        'yellow': (90, 'secondary'), 'blue': (260, 'primary'),
        'magenta': (320, 'tertiary'), 'cyan': (200, 'secondary'),
    }
    for name, target in families.items():
        canonical, role = target
        accent = Color.from_hex(roles[role]).to_hct()
        hue = accent.hue if canonical is None else canonical + ((accent.hue - canonical + 180) % 360 - 180) * 0.12
        chroma = max(24, min(64, accent.chroma * 1.5))
        for variant, tone in (('normal', 72 if dark else 32), ('bright', 84 if dark else 22)):
            put(f'{variant}_{name}', Color.from_hct(Hct(hue, chroma, tone)))
    return result
