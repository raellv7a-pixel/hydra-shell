"""Filesystem boundaries for guarded native/Flatpak template outputs."""
import json
import os
from pathlib import Path
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch

THEMING = Path(__file__).resolve().parents[1] / 'src' / 'theming'
sys.path.insert(0, str(THEMING))
from lib.renderer import TemplateRenderer, resolve_template_path


class TemplatePathTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = patch.dict(os.environ, {'HOME': str(self.home)}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.input = self.home / 'input'
        self.input.write_text('{{colors.primary.default.hex}}')
        self.renderer = TemplateRenderer({'dark': {'primary': '#123456'}})

    def process(self, entries):
        config = self.home / 'templates.toml'
        lines = []
        for name, entry in entries.items():
            lines.append(f'[templates.{name}]')
            for key, value in dict(input_path=str(self.input), **entry).items():
                lines.append(f'{key} = {json.dumps(value)}')
        config.write_text('\n'.join(lines))
        self.renderer.process_config_file(config)

    def test_missing_guard_skips_writes_and_both_hooks(self):
        marker = self.home / 'hook-ran'
        hook = f'touch {shlex.quote(str(marker))}'
        self.process({'missing': {
            'output_path': '~/not-installed/themes/color',
            'requires_path': '~/not-installed',
            'pre_hook': hook, 'post_hook': hook,
        }})
        self.assertFalse((self.home / 'not-installed').exists())
        self.assertFalse(marker.exists())

    def test_native_flatpak_outputs_are_independently_guarded(self):
        for native, flatpak in ((False, False), (True, False), (False, True), (True, True)):
            with self.subTest(native=native, flatpak=flatpak), tempfile.TemporaryDirectory(dir=self.home) as d:
                root = Path(d)
                os.environ['XDG_CONFIG_HOME'] = str(root / 'config')
                native_root = root / 'config' / 'app'
                flatpak_root = root / 'sandbox' / 'app'
                for exists, path in ((native, native_root), (flatpak, flatpak_root)):
                    if exists:
                        path.mkdir(parents=True)
                self.process({
                    'native': {'output_path': '$XDG_CONFIG_HOME/app/themes/color',
                               'requires_path': '$XDG_CONFIG_HOME/app'},
                    'flatpak': {'output_path': str(flatpak_root / 'themes/color'),
                                'requires_path': str(flatpak_root)},
                })
                for exists, path in ((native, native_root), (flatpak, flatpak_root)):
                    if exists:
                        self.assertEqual((path / 'themes/color').read_text(), '#123456')
                    else:
                        self.assertFalse(path.exists())

    def test_unguarded_output_preserves_directory_creation(self):
        self.process({'legacy': {'output_path': '~/new/themes/color'}})
        self.assertEqual((self.home / 'new/themes/color').read_text(), '#123456')

    def test_all_xdg_roots_defined_unset_empty_and_relative(self):
        defaults = {'CONFIG': '.config', 'DATA': '.local/share',
                    'STATE': '.local/state', 'CACHE': '.cache'}
        for kind, fallback in defaults.items():
            key = f'XDG_{kind}_HOME'
            for value in (None, '', 'relative', str(self.home / f'relocated {kind}')):
                with self.subTest(kind=kind, value=value):
                    if value is None:
                        os.environ.pop(key, None)
                    else:
                        os.environ[key] = value
                    expected = Path(value) if value and value.startswith('/') else self.home / fallback
                    self.assertEqual(resolve_template_path(f'${key}/app'), expected / 'app')
                    self.assertEqual(resolve_template_path(f'${key}'), expected)
            os.environ.pop(key, None)
        self.assertEqual(resolve_template_path('~'), self.home)
        self.assertEqual(resolve_template_path('~/app'), self.home / 'app')

    def test_input_output_and_guard_use_same_resolution(self):
        os.environ['XDG_DATA_HOME'] = str(self.home / 'data with spaces')
        root = resolve_template_path('$XDG_DATA_HOME/app')
        root.mkdir(parents=True)
        (root / 'input').write_text('{{mode}}:{{colors.primary.default.hex}}')
        config = self.home / '.config/templates.toml'
        config.parent.mkdir()
        config.write_text('[templates.app]\ninput_path = "$XDG_DATA_HOME/app/input"\n'
                          'output_path = "$XDG_DATA_HOME/app/out"\n'
                          'requires_path = "$XDG_DATA_HOME/app"\n')
        self.renderer.process_config_file(Path('$XDG_CONFIG_HOME/templates.toml'))
        self.assertEqual((root / 'out').read_text(), 'dark:#123456')

    def test_guard_can_be_file_and_unchanged_output_does_not_rerun_hook(self):
        marker = self.home / 'hook-count'
        entries = {'app': {'output_path': '~/out', 'requires_path': str(self.input),
                          'post_hook': f'printf x >> {shlex.quote(str(marker))}'}}
        self.process(entries)
        mtime = (self.home / 'out').stat().st_mtime_ns
        self.process(entries)
        self.assertEqual(marker.read_text(), 'x')
        self.assertEqual((self.home / 'out').stat().st_mtime_ns, mtime)

    def test_only_leading_whole_xdg_token_is_expanded_without_shell_evaluation(self):
        for text in ('$XDG_CONFIG_HOME_suffix/app', 'literal/$XDG_CONFIG_HOME/app',
                     '$(touch should-not-exist)', '$UNRECOGNIZED/app'):
            with self.subTest(text=text):
                self.assertEqual(resolve_template_path(text), Path(text))


if __name__ == '__main__':
    unittest.main()
