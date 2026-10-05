"""Official authored colors must survive the real predefined/template pipeline."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'Scripts/python/src/theming'))
from lib.color import Color
from lib.contrast import contrast_ratio
from lib.scheme import expand_predefined_scheme

# Human-specified anchors, not regenerated seed output.
ANCHORS = {
    'Glacier': {
        'dark': '0B1115 10181D 172228 1E2C33 7DD3E8 184E5A A9C7D2 8BDDBA E4EDF1',
        'light': 'F6FAFB F9FCFD EDF3F5 E2ECEF 00677A B7EAF4 49646E 006B54 172126',
    },
    'Sage': {
        'dark': '0D1210 121916 19221E 202B26 91D5B2 1D5039 B8CBBF B9C88A E5EEE8',
        'light': 'F7FAF7 FBFDFB EDF2EE E4EBE6 2C6D4F BCECCF 50645A 5E6B2B 19221D',
    },
    'Cobalt': {
        'dark': '0D1118 121720 19202B 222B38 A9C7FF 2B477D BEC7D8 9FD7D0 E6EBF3',
        'light': 'F8FAFD FBFCFF EEF1F6 E5EAF1 345F9B D8E2FF 596371 316A65 1A1E27',
    },
    'Ember': {
        'dark': '14100F 1B1513 241C19 2D231F FFB4A1 7B3020 E7BDB3 D8C68D F3E8E4',
        'light': 'FFF8F6 FFFBFA F7ECE8 EFE2DD 9A452F FFDAD0 765751 6B5E27 261A17',
    },
    'Graphite': {
        'dark': '0B0D0F 111416 181C1F 202529 8FD9D0 164F4A BDC7CA AFC8FF E7ECEE',
        'light': 'FAFBFB FFFFFF F0F3F4 E7EBED 006A64 A8EEE5 536064 47658D 1A1C1D',
    },
}
ROLE_KEYS = ('mSurfaceContainerLowest', 'mSurface', 'mSurfaceContainer',
             'mSurfaceContainerHigh', 'mPrimary', 'mPrimaryContainer',
             'mSecondary', 'mTertiary', 'mOnSurface')
ENGINE_KEYS = ('surface_container_lowest', 'surface', 'surface_container',
               'surface_container_high', 'primary', 'primary_container',
               'secondary', 'tertiary', 'on_surface')


class HydraPaletteTests(unittest.TestCase):
    def variants(self):
        for name, modes in ANCHORS.items():
            path = ROOT / f'Assets/ColorScheme/Hydra-{name}/Hydra-{name}.json'
            scheme = json.loads(path.read_text())
            for mode, anchors in modes.items():
                yield name, mode, scheme[mode], tuple('#' + value for value in anchors.split())

    def test_all_human_anchors_survive_authored_assets_and_expansion(self):
        for name, mode, variant, anchors in self.variants():
            with self.subTest(theme=name, mode=mode):
                self.assertEqual(tuple(variant[key].upper() for key in ROLE_KEYS), anchors)
                before = copy.deepcopy(variant)
                expanded = expand_predefined_scheme(variant, mode)
                self.assertEqual(tuple(expanded[key].upper() for key in ENGINE_KEYS), anchors)
                self.assertEqual(variant, before)

    def test_authored_text_foregrounds_have_readable_contrast(self):
        pairs = [('mPrimary', 'mOnPrimary'), ('mSecondary', 'mOnSecondary'),
                 ('mTertiary', 'mOnTertiary'), ('mError', 'mOnError'),
                 ('mSurface', 'mOnSurface'), ('mSurfaceVariant', 'mOnSurfaceVariant'),
                 ('mPrimaryContainer', 'mOnPrimaryContainer'),
                 ('mSecondaryContainer', 'mOnSecondaryContainer'),
                 ('mTertiaryContainer', 'mOnTertiaryContainer'), ('mHover', 'mOnHover')]
        for name, mode, variant, _ in self.variants():
            for background, foreground in pairs:
                with self.subTest(theme=name, mode=mode, role=foreground):
                    ratio = contrast_ratio(Color.from_hex(variant[background]), Color.from_hex(variant[foreground]))
                    self.assertGreaterEqual(ratio, 4.5)


if __name__ == '__main__':
    unittest.main()
