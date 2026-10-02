"""Consumer-visible Material models, seed selection and processor recipe contracts."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / "src" / "theming"
sys.path.insert(0, str(ROOT))
from lib.color import Color
from lib.contrast import contrast_ratio
from lib.hct import Hct
from lib.material import SchemeExpressive, SchemeFidelity, SchemeNeutral, SchemeVibrant
from lib.theme import generate_theme, generate_normal_dark
from lib.tinted import mix_hex


class MaterialModels(unittest.TestCase):
    def test_expressive_rotates_primary_and_piecewise_accents(self):
        source = Hct(100, 60, 50)
        scheme = SchemeExpressive(source)
        self.assertEqual(scheme.primary_palette.get_hex(40), Hct(340, 40, 40).to_hex())
        self.assertEqual(scheme.secondary_palette.get_hex(40), Hct(145, 24, 40).to_hex())
        self.assertEqual(scheme.tertiary_palette.get_hex(40), Hct(120, 32, 40).to_hex())

    def test_fidelity_preserves_source_and_complement_identity(self):
        source = Hct.from_rgb(190, 45, 65)
        scheme = SchemeFidelity(source)
        for result in (scheme.get_dark_scheme(), scheme.get_light_scheme()):
            self.assertEqual(result['primary_container'], source.to_hex())
            a = Color.from_hex(result['primary_container'])
            b = Color.from_hex(result['on_primary_container'])
            self.assertGreaterEqual(contrast_ratio(a, b), 4.5)
            self.assertNotEqual(result['tertiary_container'], result['primary_container'])

    def test_neutral_generates_low_chroma_not_rgb_desaturation(self):
        scheme = SchemeNeutral(Hct(100, 60, 50))
        self.assertEqual(scheme.primary_palette.get_hex(40), Hct(100, 12, 40).to_hex())
        self.assertEqual(scheme.neutral_palette.get_hex(20), Hct(100, 2, 20).to_hex())
        self.assertEqual(scheme.tertiary_palette.get_hex(40), Hct(100, 16, 40).to_hex())

    def test_vibrant_material_is_not_legacy_alias(self):
        palette = [Color(80, 100, 210), Color(200, 50, 80), Color(50, 180, 70)]
        self.assertEqual(generate_theme(palette, 'dark', 'vibrant'), generate_normal_dark(palette))
        self.assertNotEqual(generate_theme(palette, 'dark', 'm3-vibrant'), generate_theme(palette, 'dark', 'vibrant'))
        scheme = SchemeVibrant(Hct(100, 60, 50))
        self.assertEqual(scheme.primary_palette.get_hex(40), Hct(100, 200, 40).to_hex())
        self.assertEqual(scheme.secondary_palette.get_hex(40), Hct(110, 24, 40).to_hex())


class RecipeProcessor(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.color = Path(self.tmp.name) / 'color.ppm'
        stripes = [(205, 45, 60), (35, 175, 60), (40, 70, 205), (210, 155, 35)]
        pixels = b''.join(bytes(stripes[x // 32]) for y in range(128) for x in range(128))
        self.color.write_bytes(b'P6\n128 128\n255\n' + pixels)
        self.gray = Path(self.tmp.name) / 'gray.ppm'
        self.gray.write_bytes(b'P6\n128 128\n255\n' + bytes((120, 120, 120)) * 128 * 128)

    def run_recipe(self, model, seed=0, style='classic', image=None):
        result = subprocess.run([sys.executable, str(ROOT / 'template-processor.py'), str(image or self.color), '--scheme-type', model, '--seed-index', str(seed), '--surface-style', style], text=True, capture_output=True, check=True)
        return json.loads(result.stdout)

    def test_smart_uses_effective_model_in_both_styles(self):
        for image, model in ((self.gray, 'monochrome'), (self.color, 'content')):
            smart = self.run_recipe('smart', image=image)
            expected = self.run_recipe(model, image=image)
            self.assertEqual(smart['_effective_scheme_type'], model)
            self.assertEqual(smart['dark'], expected['dark'])
            self.assertEqual(smart['light'], expected['light'])
            tinted = self.run_recipe('smart', style='tinted', image=image)
            self.assertEqual(tinted['dark'], self.run_recipe(model, style='tinted', image=image)['dark'])

    def test_ranked_seeds_change_palette_and_invalid_falls_back(self):
        first = self.run_recipe('tonal-spot')
        second = self.run_recipe('tonal-spot', 1)
        candidates = first['_source_candidates']
        self.assertGreaterEqual(len(candidates), 2)
        self.assertLessEqual(len(candidates), 4)
        self.assertNotEqual(candidates[0]['hex'], candidates[1]['hex'])
        self.assertNotEqual(first['dark']['primary'], second['dark']['primary'])
        for invalid in (-1, 999, 'not-an-index', '1.5'):
            fallback = self.run_recipe('tonal-spot', invalid)
            self.assertEqual(fallback['_seed_index'], 0)
            self.assertEqual(fallback['dark'], first['dark'])
        self.assertNotEqual(first['dark'], self.run_recipe('expressive')['dark'])

    def test_new_tinted_strengths_and_foregrounds(self):
        for model, strength in [('expressive', .105), ('fidelity', .09), ('neutral', .025), ('m3-vibrant', .14)]:
            classic = self.run_recipe(model)
            tinted = self.run_recipe(model, style='tinted')
            for mode in ('dark', 'light'):
                a, b = classic[mode], tinted[mode]
                self.assertEqual(b['surface'], mix_hex(a['surface'], a['primary'], strength * .72))
                self.assertEqual(b['surface_container_highest'], mix_hex(a['surface_container_highest'], a['primary'], strength * 1.16))
                for role in a:
                    if role.startswith('on_') or role in ('outline', 'primary_container'):
                        self.assertEqual(a[role], b[role])


if __name__ == '__main__':
    unittest.main()
