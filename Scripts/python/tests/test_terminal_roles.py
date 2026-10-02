"""Derived ANSI invariants, renderer formats, hue semantics and hook ordering."""
import contextlib
import io
import json
import os
from pathlib import Path
import select
import shlex
import sys
import tempfile
import threading
import unittest

THEMING = Path(__file__).resolve().parents[1] / 'src/theming'
sys.path.insert(0, str(THEMING))
from lib.color import Color
from lib.material_spec import generate_spec_palette
from lib.renderer import TemplateRenderer
from lib.terminal import ANSI_NAMES, derive_terminal_roles
from lib.contrast import contrast_ratio
from lib.tinted import apply_surface_tint


class TerminalRoleTests(unittest.TestCase):
    def test_all_specs_modes_surfaces_contrast_formats_and_immutability(self):
        for spec in ('2021', '2025'):
            for style in ('classic', 'tinted'):
                originals = {mode: generate_spec_palette([Color.from_hex('#1e88e5')], mode,
                                                         'tonal-spot', spec)
                             for mode in ('dark', 'light')}
                for mode in originals:
                    apply_surface_tint(originals[mode], 'tonal-spot', style)
                snapshot = {mode: dict(roles) for mode, roles in originals.items()}
                derived = {mode: derive_terminal_roles(roles, mode) for mode, roles in originals.items()}
                self.assertEqual(originals, snapshot)
                renderer = TemplateRenderer(derived, verbose=False)
                names = ['terminal_foreground', 'terminal_background'] + [
                    f'terminal_{variant}_{color}' for variant in ('normal', 'bright') for color in ANSI_NAMES]
                for mode, roles in derived.items():
                    with self.subTest(spec=spec, style=style, mode=mode):
                        self.assertEqual(roles, derive_terminal_roles(originals[mode], mode))
                        for name in names:
                            self.assertRegex(roles[name], r'^#[0-9a-fA-F]{6}$')
                            rendered = renderer.render('{{colors.' + name + '.' + mode + '.hex}}')
                            self.assertEqual(rendered, roles[name])
                            stripped = renderer.render('{{colors.' + name + '.' + mode + '.hex_stripped}}')
                            self.assertRegex(stripped, r'^[0-9a-fA-F]{6}$')
                            rgb = renderer.render('{{colors.' + name + '.' + mode + '.rgb}}')
                            self.assertRegex(rgb, r'^rgb\(\d+,\s*\d+,\s*\d+\)$')
                        bg = Color.from_hex(roles['terminal_background'])
                        for name in names:
                            if name != 'terminal_background':
                                self.assertGreaterEqual(contrast_ratio(Color.from_hex(roles[name]), bg), 4.5 - 0.01, name)
                self.assertNotEqual(derived['dark']['terminal_background'], derived['light']['terminal_background'])
                self.assertEqual(renderer.render('{{colors.terminal_foreground.default.hex}}'), derived['dark']['terminal_foreground'])

    def test_authored_terminal_values_win_and_layer_is_idempotent(self):
        roles = generate_spec_palette([Color.from_hex('#abc123')], 'dark', 'tonal-spot', '2021')
        roles['terminal_normal_red'] = '#123456'
        roles['terminal_background'] = '#000000'
        result = derive_terminal_roles(roles, 'dark')
        self.assertEqual(result['terminal_normal_red'], '#123456')
        self.assertEqual(result['terminal_background'], '#000000')
        self.assertEqual(result, derive_terminal_roles(result, 'dark'))

    def test_rotate_hue_modulo_preserves_hsl_and_set_hue_stays_absolute(self):
        source = Color.from_hex('#32678f')
        renderer = TemplateRenderer({'dark': {'primary': source.to_hex()}}, verbose=False)
        h, s, l = source.to_hsl()
        outputs = {}
        for angle in (0, 30, -30, 360, 390, -390):
            output = renderer.render('{{colors.primary.default.hex | rotate_hue ' + str(angle) + '}}')
            outputs[angle] = output
            rotated = Color.from_hex(output)
            actual_h, actual_s, actual_l = rotated.to_hsl()
            self.assertLess(abs((actual_h - h - angle + 180) % 360 - 180), 1)
            self.assertAlmostEqual(actual_s, s, delta=0.02)
            self.assertAlmostEqual(actual_l, l, delta=0.01)
        self.assertEqual(outputs[0], outputs[360])
        self.assertEqual(outputs[30], outputs[390])
        self.assertEqual(outputs[-30], outputs[-390])
        absolute = Color.from_hex(renderer.render('{{colors.primary.default.hex | set_hue 30}}'))
        self.assertAlmostEqual(absolute.to_hsl()[0], 30, delta=1)
        for arg in ('invalid', ''):
            with self.subTest(arg=arg), contextlib.redirect_stderr(io.StringIO()):
                renderer.render('{{colors.primary.default.hex | rotate_hue ' + arg + '}}')
                self.assertGreater(renderer._error_count, 0)


class HookTests(unittest.TestCase):
    def test_default_sync_and_opt_in_unchanged_preserve_pre_hook_ordering(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); source = root / 'input'; source.write_text('colors')
            pre = root / 'pre'; post = root / 'post'; config = root / 'config.toml'
            entry = {'input_path': str(source), 'output_path': str(root / 'output'),
                     'pre_hook': f'printf x >> {shlex.quote(str(pre))}',
                     'post_hook': f'printf x >> {shlex.quote(str(post))}'}
            def write_config(always):
                config.write_text('[templates.app]\n' + '\n'.join(k + '=' + json.dumps(v) for k, v in entry.items()) +
                                  ('\nhook_on_unchanged=true\n' if always else '\n'))
            renderer = TemplateRenderer({}, verbose=False)
            write_config(False); renderer.process_config_file(config); renderer.process_config_file(config)
            self.assertEqual(pre.read_text(), 'x'); self.assertEqual(post.read_text(), 'x')
            write_config(True); renderer.process_config_file(config)
            self.assertEqual(pre.read_text(), 'x'); self.assertEqual(post.read_text(), 'xx')

    def test_async_returns_while_hook_waits_on_fifo_without_inherited_pipes(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); fifo = root / 'release'; os.mkfifo(fifo)
            source = root / 'input'; source.write_text('colors')
            marker = root / 'completed'; config = root / 'config.toml'
            completion = root / 'completion'; os.mkfifo(completion)
            completion_fd = os.open(completion, os.O_RDWR | os.O_NONBLOCK)
            hook = (f'read -r release < {shlex.quote(str(fifo))}; '
                    f'printf done > {shlex.quote(str(marker))}; printf ready > {shlex.quote(str(completion))}')
            config.write_text('[templates.app]\ninput_path=' + json.dumps(str(source)) +
                              '\noutput_path=' + json.dumps(str(root / 'out')) +
                              '\nhook_async=true\npost_hook=' + json.dumps(hook) + '\n')
            returned = threading.Event()
            def run():
                TemplateRenderer({}, verbose=False).process_config_file(config)
                returned.set()
            thread = threading.Thread(target=run, daemon=True); thread.start()
            try:
                self.assertTrue(returned.wait(5), 'asynchronous hook blocked renderer')
                self.assertFalse(marker.exists())
            finally:
                with fifo.open('w') as release:
                    release.write('release\n')
                thread.join(5)
            try:
                self.assertTrue(select.select([completion_fd], [], [], 5)[0], 'hook did not finish')
                self.assertEqual(os.read(completion_fd, 64), b'ready')
                self.assertEqual(marker.read_text(), 'done')
            finally:
                os.close(completion_fd)


if __name__ == '__main__':
    unittest.main()
