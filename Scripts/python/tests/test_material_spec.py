"""Real Material spec dispatch, compatibility and processor contract regressions."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'src' / 'theming'
sys.path.insert(0, str(ROOT))
from lib.color import Color
from lib.material_spec import generate_spec_palette, effective_material_spec
from lib.tinted import mix_hex

SUPPORTED = ('tonal-spot', 'm3-vibrant', 'expressive', 'neutral')
REQUIRED = ('primary', 'on_primary', 'secondary', 'on_secondary', 'tertiary',
            'primary_container', 'on_primary_container', 'secondary_container',
            'on_secondary_container', 'tertiary_container', 'on_tertiary_container',
            'surface', 'surface_variant', 'on_surface', 'on_surface_variant',
            'surface_container_lowest', 'surface_container_low', 'surface_container',
            'surface_container_high', 'surface_container_highest', 'outline',
            'outline_variant', 'shadow', 'scrim', 'inverse_on_surface')


class MaterialSpecTests(unittest.TestCase):
    def test_historical_2021_primary_golden_values(self):
        # Captured from the visually validated LOCAL engine before this change.
        expected = {'tonal-spot': ('#ffb4a2', '#9b432d'),
                    'm3-vibrant': ('#ffb4a2', '#b42800'),
                    'expressive': ('#b4c5ff', '#475c99'),
                    'neutral': ('#e0bfb8', '#715953')}
        for model, colors in expected.items():
            for mode, primary in zip(('dark', 'light'), colors):
                with self.subTest(model=model, mode=mode):
                    roles = generate_spec_palette([Color.from_hex('#ff3d00')], mode, model, '2021')
                    self.assertEqual(roles['primary'], primary)

    def test_2025_variants_modes_and_roles(self):
        for seed in ('#ff3d00', '#1e88e5', '#8bc34a'):
            for model in SUPPORTED:
                results = {}
                for mode in ('dark', 'light'):
                    with self.subTest(seed=seed, model=model, mode=mode):
                        result = generate_spec_palette([Color.from_hex(seed)], mode, model, '2025')
                        for key in REQUIRED:
                            self.assertRegex(result[key], r'^#[0-9a-f]{6}$')
                        historical = generate_spec_palette([Color.from_hex(seed)], mode, model, '2021')
                        # Neutral may share an accent with 2021 for a given seed;
                        # its surfaces still use the real 2025 tonal construction.
                        self.assertNotEqual(result['surface_container_high'], historical['surface_container_high'])
                        results[mode] = result
                self.assertNotEqual(results['dark']['surface'], results['light']['surface'])

    def test_dms_vibrant_reference(self):
        for spec, primary in (('2021', '#ffb4a2'), ('2025', '#ff8f73')):
            self.assertEqual(generate_spec_palette([Color(255, 61, 0)], 'dark', 'm3-vibrant', spec)['primary'], primary)

    def test_unsupported_variants_and_legacy_keep_historical_roles(self):
        for model in ('content', 'fidelity', 'fruit-salad', 'rainbow', 'monochrome',
                      'vibrant', 'faithful', 'dysfunctional', 'muted'):
            for mode in ('dark', 'light'):
                palette = [Color(30, 136, 229), Color(205, 50, 70), Color(50, 175, 70)]
                self.assertEqual(generate_spec_palette(palette, mode, model, '2025'),
                                 generate_spec_palette(palette, mode, model, '2021'))
                self.assertEqual(effective_material_spec(model, '2025'), '2021')

    def test_2025_clamps_negative_contrast_and_handles_positive_contrast(self):
        palette = [Color(255, 61, 0)]
        for mode in ('dark', 'light'):
            normal = generate_spec_palette(palette, mode, 'm3-vibrant', '2025', 0)
            self.assertEqual(generate_spec_palette(palette, mode, 'm3-vibrant', '2025', -1), normal)
            high = generate_spec_palette(palette, mode, 'm3-vibrant', '2025', 1)
            self.assertNotEqual(high['primary'], normal['primary'])


class ProcessorSpecTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.image = self.root / 'source.ppm'
        self.image.write_bytes(b'P6\n32 32\n255\n' + bytes((255, 61, 0)) * 32 * 32)
        self.env = os.environ.copy()
        for kind in ('config', 'cache', 'state', 'data'):
            path = self.root / kind
            path.mkdir()
            self.env[f'XDG_{kind.upper()}_HOME'] = str(path)

    def run_recipe(self, spec=None, style='classic', extra=()):
        cmd = [sys.executable, str(ROOT / 'template-processor.py'), str(self.image),
               '--scheme-type', 'm3-vibrant', '--surface-style', style, *extra]
        if spec:
            cmd += ['--material-spec', spec]
        result = subprocess.run(cmd, env=self.env, capture_output=True, text=True, check=True)
        if '--render' in extra:
            return
        return json.loads(result.stdout)

    def test_default_2025_and_explicit_2021(self):
        current = self.run_recipe()
        self.assertEqual(current['_material_spec'], '2025')
        self.assertEqual(current['_effective_material_spec'], '2025')
        self.assertEqual(current['dark']['primary'], '#ff8f73')
        self.assertEqual(self.run_recipe('2021')['dark']['primary'], '#ffb4a2')

    def test_classic_tinted_and_template_share_native_spec_roles(self):
        template = self.root / 'roles.template'
        template.write_text('{{colors.primary.dark.hex}}|{{colors.surface_container_high.light.hex}}')
        for spec in ('2021', '2025'):
            classic = self.run_recipe(spec)
            tinted = self.run_recipe(spec, 'tinted')
            for mode in ('dark', 'light'):
                self.assertEqual(tinted[mode]['surface'], mix_hex(classic[mode]['surface'], classic[mode]['primary'], .14 * .72))
                self.assertEqual(tinted[mode]['on_surface'], classic[mode]['on_surface'])
            output = self.root / f'{spec}.rendered'
            self.run_recipe(spec, 'tinted', ('--render', f'{template}:{output}'))
            self.assertEqual(output.read_text().lower(), (tinted['dark']['primary'] + '|' + tinted['light']['surface_container_high']).lower())

    def test_readonly_calculation_leaves_configuration_unchanged(self):
        for relative in ('hydra/colors.json', 'hydra/settings.json', 'gtk-3.0/gtk.css', 'qt6ct/qt6ct.conf'):
            path = self.root / 'config' / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('existing user config')
        before = {str(p): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.run_recipe('2025')
        after = {str(p): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)

    def test_missing_2025_dependency_never_silently_falls_back(self):
        cmd = [sys.executable, '-S', str(ROOT / 'template-processor.py'), str(self.image), '--scheme-type', 'm3-vibrant']
        isolated_env = dict(self.env)
        isolated_env.pop('PYTHONPATH', None)
        result = subprocess.run(cmd, env=isolated_env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Material 2025 requires materialyoucolor', result.stderr)
        historical = subprocess.run(cmd + ['--material-spec', '2021'], env=isolated_env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(historical.stdout)['dark']['primary'], '#ffb4a2')


if __name__ == '__main__':
    unittest.main()
