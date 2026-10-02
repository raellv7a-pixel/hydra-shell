import copy
import os
from pathlib import Path
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'Scripts/python/src/theming'))
sys.path.insert(0, str(ROOT / 'Scripts/python'))
from lib.color import Color
from lib.material_spec import generate_spec_palette
from lib.renderer import TemplateRenderer
from lib.terminal import derive_terminal_roles
from lib.tinted import apply_surface_tint
from umbriel_config import commit


class UmbrielThemeTests(unittest.TestCase):
    def check_theme(self, spec, style, mode):
        colors = generate_spec_palette([Color.from_hex('#7d52b0')], mode, 'tonal-spot', spec)
        apply_surface_tint(colors, 'tonal-spot', style)
        colors = derive_terminal_roles(colors, mode)
        before = copy.deepcopy(colors)
        renderer = TemplateRenderer({mode: colors}, default_mode=mode, verbose=False)
        text = renderer.render((ROOT / 'Assets/Templates/umbriel.toml').read_text())
        self.assertEqual(renderer._error_count, 0)
        roles = tomllib.loads(text)['colors']
        self.assertEqual(int(roles['accent_primary'][1:], 16), int(colors['primary'][1:] + 'ff', 16))
        self.assertEqual(int(roles['background'][1:], 16), int(colors['surface_container'][1:] + 'ff', 16))
        self.assertEqual(int(roles['text_primary'][1:], 16), int(colors['on_surface'][1:] + 'ff', 16))
        self.assertEqual(int(roles['border']['outer'][1:], 16), int(colors['terminal_background'][1:] + 'ff', 16))
        self.assertEqual(colors, before)
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'HOME':directory, 'XDG_CONFIG_HOME':directory + '/config'}):
            commit('theme', text, reload=False)
            self.assertEqual((Path(directory) / 'config/umbriel/hydra/theme.toml').read_text(), text)

    def test_representative_native_palettes(self):
        for spec, style, mode in [('2025','tinted','dark'),('2021','classic','light')]:
            with self.subTest(spec=spec,style=style,mode=mode):
                self.check_theme(spec,style,mode)

    def test_final_palette_matrix(self):
        for spec in ('2021','2025'):
            for style in ('classic','tinted'):
                for mode in ('dark','light'):
                    with self.subTest(spec=spec,style=style,mode=mode):
                        self.check_theme(spec,style,mode)


if __name__ == '__main__':
    unittest.main()
