"""App-format and dark/light regressions using Hydra's real palette engines."""
import configparser
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'Scripts/python/src/theming'))
from lib.color import Color
from lib.material_spec import generate_spec_palette
from lib.renderer import TemplateRenderer
from lib.tinted import apply_surface_tint
from lib.scheme import expand_predefined_scheme, inject_terminal_colors


class AppTemplateTests(unittest.TestCase):
    def palettes(self):
        for spec in ('2021', '2025'):
            for style in ('classic', 'tinted'):
                roles = {mode: generate_spec_palette([Color.from_hex('#1e88e5')], mode,
                                                     'tonal-spot', spec)
                         for mode in ('dark', 'light')}
                for mode in roles:
                    apply_surface_tint(roles[mode], 'tonal-spot', style)
                yield spec, style, roles

    def render(self, filename, roles, mode):
        renderer = TemplateRenderer(roles, default_mode=mode)
        output = renderer.render((ROOT / 'Assets/Templates' / filename).read_text())
        self.assertEqual(renderer._error_count, 0, filename)
        self.assertNotRegex(output, r'\{\{|<\*', filename)
        return output

    def test_new_json_formats_and_mode_boundaries(self):
        for spec, style, roles in self.palettes():
            for mode in ('dark', 'light'):
                with self.subTest(spec=spec, style=style, mode=mode):
                    prism = json.loads(self.render('prismlauncher.json', roles, mode))
                    self.assertEqual(prism['widgets'], 'Fusion')
                    self.assertTrue(0 <= prism['colors']['fadeAmount'] <= 1)
                    for value in (v for k, v in prism['colors'].items() if k != 'fadeAmount'):
                        self.assertRegex(value, r'^#[0-9a-fA-F]{6}$')
                    claude = json.loads(self.render('claude-code.json', roles, mode))
                    self.assertEqual(claude['base'], mode)
                    for value in claude['overrides'].values():
                        self.assertRegex(value, r'^#[0-9a-fA-F]{6}$')
                    fastfetch = json.loads(self.render('fastfetch-colors.jsonc', roles, mode))
                    self.assertRegex(fastfetch['display']['color']['keys'], r'^#[0-9a-fA-F]{6}$')
                    opencode = json.loads(self.render('opencode.json', roles, mode))
                    for variants in opencode['theme'].values():
                        self.assertEqual(set(variants), {'dark', 'light'})
                        for value in variants.values():
                            self.assertRegex(value, r'^#[0-9a-fA-F]{6}$')
                    self.assertNotEqual(opencode['theme']['background']['dark'],
                                        opencode['theme']['background']['light'])

    def test_fcitx_native_ini_values_and_selection_contrast(self):
        for spec, style, roles in self.palettes():
            for mode in ('dark', 'light'):
                with self.subTest(spec=spec, style=style, mode=mode):
                    config = configparser.ConfigParser(interpolation=None)
                    config.read_string(self.render('fcitx5.conf', roles, mode))
                    self.assertEqual(config.getint('Metadata', 'Version'), 1)
                    for section in config.sections():
                        for key, value in config.items(section):
                            if 'color' in key:
                                self.assertRegex(value, r'^#[0-9a-fA-F]{6}$')
                    self.assertNotEqual(config['InputPanel']['HighlightCandidateColor'],
                                        config['InputPanel/Highlight']['Color'])

    def test_css_and_tmux_have_resolved_colors_in_both_modes(self):
        for spec, style, roles in self.palettes():
            for mode in ('dark', 'light'):
                with self.subTest(spec=spec, style=style, mode=mode):
                    for filename in ('discord-system24.css', 'tmux.conf'):
                        self.render(filename, roles, mode)

    def test_existing_apps_and_wallpaper_terminals_still_render(self):
        files = ('heroic.css', 'discord-midnight.css', 'discord-material.css',
                 'steam.css', 'matugen.obt', 'hydra.json', 'terminal/foot',
                 'terminal/ghostty', 'terminal/kitty.conf', 'terminal/alacritty.toml',
                 'terminal/wezterm.toml', 'terminal/starship.toml')
        for spec, style, roles in self.palettes():
            for mode in ('dark', 'light'):
                for filename in files:
                    with self.subTest(spec=spec, style=style, mode=mode, filename=filename):
                        output = self.render(filename, roles, mode)
                        if filename.endswith('.json'):
                            json.loads(output)
                        if filename.endswith('.toml'):
                            import tomllib
                            tomllib.loads(output)

    def test_predefined_terminals_keep_authored_backgrounds(self):
        scheme = json.loads((ROOT / 'Assets/ColorScheme/Hydra-default/Hydra-default.json').read_text())
        roles = {mode: inject_terminal_colors(expand_predefined_scheme(scheme[mode], mode), scheme[mode])
                 for mode in ('dark', 'light')}
        files = ('terminal/foot-predefined', 'terminal/ghostty-predefined',
                 'terminal/kitty-predefined.conf', 'terminal/alacritty-predefined.toml',
                 'terminal/wezterm-predefined.toml', 'terminal/starship-predefined.toml')
        for mode, background in (('dark', '070722'), ('light', 'e6e8fa')):
            for filename in files:
                with self.subTest(mode=mode, filename=filename):
                    output = self.render(filename, roles, mode)
                    if filename.endswith('.toml'):
                        import tomllib
                        tomllib.loads(output)
                    if filename == 'terminal/foot-predefined':
                        config = configparser.ConfigParser(interpolation=None)
                        config.read_string(output)
                        backgrounds = [config[s]['background'].lower() for s in config.sections()
                                       if 'background' in config[s]]
                        self.assertEqual(backgrounds, [background])


if __name__ == '__main__':
    unittest.main()
