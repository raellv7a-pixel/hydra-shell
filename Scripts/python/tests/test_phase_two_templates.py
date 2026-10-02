"""Public app formats and generated syntax across both color modes/specs."""
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'Scripts/python/src/theming'))
from lib.color import Color
from lib.material_spec import generate_spec_palette
from lib.renderer import TemplateRenderer
from lib.terminal import derive_terminal_roles
from lib.contrast import contrast_ratio
from lib.tinted import apply_surface_tint


class PhaseTwoTemplateTests(unittest.TestCase):
    def test_public_formats_all_specs_surfaces_and_modes(self):
        files = ('neovim.lua', 'zellij.kdl', 'antigravity.json', 'syntax.tmTheme',
                 'obsidian.css', 'fzf.sh', 'fzf.fish', 'gtk-app.css')
        with tempfile.TemporaryDirectory() as d:
            temporary = Path(d)
            env = dict(PATH=os.environ.get('PATH', os.defpath), HOME=d, XDG_CONFIG_HOME=d + '/config', XDG_DATA_HOME=d + '/data',
                       XDG_CACHE_HOME=d + '/cache', XDG_STATE_HOME=d + '/state', XDG_RUNTIME_DIR=d + '/runtime')
            for spec in ('2021', '2025'):
                for style in ('classic', 'tinted'):
                    roles = {}
                    for mode in ('dark', 'light'):
                        colors = generate_spec_palette([Color.from_hex('#7d52b0')], mode, 'tonal-spot', spec)
                        apply_surface_tint(colors, 'tonal-spot', style)
                        roles[mode] = derive_terminal_roles(colors, mode)
                    for mode in ('dark', 'light'):
                        renderer = TemplateRenderer(roles, default_mode=mode, verbose=False)
                        for filename in files:
                            with self.subTest(spec=spec, style=style, mode=mode, file=filename):
                                output = renderer.render((ROOT / 'Assets/Templates' / filename).read_text())
                                self.assertEqual(renderer._error_count, 0)
                                self.assertNotRegex(output, r'\{\{|<\*')
                                if filename.endswith('.json'):
                                    self.assertEqual(json.loads(output), {'colorScheme': 'terminal'})
                                if filename.endswith('.tmTheme'):
                                    settings = plistlib.loads(output.encode())['settings']
                                    base = settings[0]['settings']
                                    self.assertGreaterEqual(contrast_ratio(Color.from_hex(base['foreground']),
                                                                          Color.from_hex(base['background'])), 4.49)
                                    for item in settings:
                                        for key, value in item['settings'].items():
                                            if key != 'fontStyle':
                                                self.assertRegex(value, r'^#[0-9a-fA-F]{6}$')
                                path = temporary / filename; path.write_text(output)
                                command = None
                                if filename.endswith('.sh'):
                                    command = ['bash', '-n', str(path)]
                                if filename.endswith('.fish') and shutil.which('fish'):
                                    command = ['fish', '--no-config', '-n', str(path)]
                                if filename.endswith('.lua') and shutil.which('luac'):
                                    command = ['luac', '-p', str(path)]
                                if command:
                                    result = subprocess.run(command, env=env, capture_output=True, text=True, cwd=d)
                                    self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which('fzf'), 'fzf is optional')
    def test_shell_fragment_keeps_unrelated_options_and_runs_real_fzf(self):
        roles = {mode: derive_terminal_roles(generate_spec_palette([Color.from_hex('#7d52b0')], mode,
                                                                   'tonal-spot', '2021'), mode)
                 for mode in ('dark', 'light')}
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'hydra.sh'
            output = TemplateRenderer(roles).render((ROOT / 'Assets/Templates/fzf.sh').read_text())
            path.write_text(output)
            env = dict(PATH=os.environ.get('PATH', os.defpath), HOME=d, XDG_CONFIG_HOME=d + '/config', XDG_DATA_HOME=d + '/data',
                       XDG_CACHE_HOME=d + '/cache', XDG_STATE_HOME=d + '/state',
                       FZF_DEFAULT_OPTS='--exact --no-sort')
            command = 'source "$1"; printf "%s\\n" "$FZF_DEFAULT_OPTS"; printf "Hydra\\nHydraulic\\n" | fzf --filter=Hydra'
            result = subprocess.run(['bash', '--noprofile', '--norc', '-c', command, 'test', str(path)],
                                    env=env, capture_output=True, text=True, cwd=d)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = result.stdout.splitlines()
            self.assertIn('--exact --no-sort', lines[0])
            self.assertEqual(lines[1:], ['Hydra', 'Hydraulic'])

    def test_single_mode_cli_keeps_theme_base_consistent_with_palette(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            image = root / 'wallpaper.ppm'
            image.write_bytes(b'P6\n8 8\n255\n' + bytes((91, 54, 173)) * 64)
            env = dict(PATH=os.environ.get('PATH', os.defpath), HOME=d,
                       XDG_CONFIG_HOME=d + '/config', XDG_DATA_HOME=d + '/data',
                       XDG_STATE_HOME=d + '/state', XDG_CACHE_HOME=d + '/cache')
            processor = ROOT / 'Scripts/python/src/theming/template-processor.py'
            source = ROOT / 'Assets/Templates/claude-code.json'
            for mode in ('dark', 'light'):
                with self.subTest(mode=mode):
                    theme = root / 'theme.json'; palette = root / 'palette.json'
                    result = subprocess.run(
                        [sys.executable, str(processor), str(image), '--mode', mode,
                         '--render', str(source) + ':' + str(theme), '--output', str(palette)],
                        env=env, capture_output=True, text=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(mode, json.loads(palette.read_text()))
                    self.assertEqual(json.loads(theme.read_text())['base'], mode)

    def test_generic_json_palette_does_not_require_material_fields(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            palette = root / 'input.json'; palette.write_text('{"primary":"#123456"}')
            source = root / 'template'; source.write_text('{{colors.primary.default.rgb}}')
            output = root / 'rendered'; metadata = root / 'output.json'
            env = dict(PATH=os.environ.get('PATH', os.defpath), HOME=d,
                       XDG_CONFIG_HOME=d + '/config', XDG_DATA_HOME=d + '/data',
                       XDG_STATE_HOME=d + '/state', XDG_CACHE_HOME=d + '/cache')
            result = subprocess.run(
                [sys.executable, str(ROOT / 'Scripts/python/src/theming/template-processor.py'),
                 str(palette), '--render', str(source) + ':' + str(output), '--output', str(metadata)],
                env=env, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            rgb = re.fullmatch(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)', output.read_text())
            self.assertIsNotNone(rgb)
            self.assertEqual(tuple(map(int, rgb.groups())), (18, 52, 86))


if __name__ == '__main__':
    unittest.main()
