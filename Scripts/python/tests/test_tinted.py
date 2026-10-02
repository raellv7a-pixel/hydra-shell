"""Behavioral regression tests for surface finishing and the real processor CLI."""

import json
import math
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

THEMING = Path(__file__).parents[1] / "src" / "theming"
ROOT = Path(__file__).parents[3]
sys.path.insert(0, str(THEMING))
from lib.tinted import (
    SURFACE_MULTIPLIERS, apply_surface_tint, grayscale_score,
    mix_hex, surface_tint_strength,
)
from lib.image import read_grayscale_sample
from lib.color import Color
from lib.theme import generate_theme


class TintedTests(unittest.TestCase):
    def test_classic_keeps_every_role_and_unknown_methods_are_conservative(self):
        original = {"primary": "#A0B0C0", "surface": "#102030", "on_surface": "#ffffff"}
        for method, style in [("content", "classic"), ("vibrant", "tinted"),
                              ("faithful", "tinted"), ("dysfunctional", "tinted"),
                              ("muted", "tinted"), ("future-engine", "tinted")]:
            with self.subTest(method=method, style=style):
                roles = dict(original)
                apply_surface_tint(roles, method, style)
                self.assertEqual(roles, original)

    def test_reference_vectors_and_foregrounds_are_unchanged(self):
        # Studio: Content strength .075; surface .72, container .92.
        roles = {"primary": "#A0B0C0", "surface": "#102030",
                 "surface_container": "#102030", "on_surface": "#abcdef",
                 "outline": "#123456", "primary_container": "#789ABC"}
        apply_surface_tint(roles, "content", "tinted")
        self.assertEqual(roles, {"primary": "#A0B0C0", "surface": "#182838",
                                "surface_container": "#1A2A3A", "on_surface": "#abcdef",
                                "outline": "#123456", "primary_container": "#789ABC"})
        self.assertEqual(mix_hex("#000000", "#010101", 0.5), "#010101")
        self.assertEqual(mix_hex("#10203080", "#A0B0C0FF", 0.054), "#182838")

    def test_aliases_use_only_real_material_equivalences(self):
        expected = {"tonal-spot": ("Tonal Spot", .045), "content": ("Content", .075),
                    "fruit-salad": ("Fruit Salad", .12), "rainbow": ("Rainbow", .12),
                    "monochrome": ("Monochrome", 0)}
        for alias, (canonical, strength) in expected.items():
            with self.subTest(alias=alias):
                self.assertEqual(surface_tint_strength(alias), strength)
                self.assertEqual(surface_tint_strength(canonical), strength)
        self.assertEqual(surface_tint_strength("vibrant"), 0)
        self.assertEqual(surface_tint_strength("Vibrant"), .14)

    def test_every_role_multiplier_and_clamp(self):
        for method in ("Tonal Spot", "Content", "Fruit Salad", "Rainbow", "Vibrant"):
            roles = dict.fromkeys(SURFACE_MULTIPLIERS, "#000000")
            roles["primary"] = "#ffffff"
            apply_surface_tint(roles, method, "tinted")
            for role, multiplier in SURFACE_MULTIPLIERS.items():
                amount = min(.18, surface_tint_strength(method) * multiplier)
                channel = math.floor(255 * amount + .5)
                self.assertEqual(roles[role], "#" + f"{channel:02X}" * 3)
                self.assertLessEqual(channel, 46)
        # Exercise the guard itself beyond today's strength table.
        with patch.dict("lib.tinted._STRENGTHS", {"Content": 1.0}):
            roles = {"primary": "#ffffff", "surface": "#000000"}
            apply_surface_tint(roles, "content", "tinted")
            self.assertEqual(roles["surface"], "#2E2E2E")

    def test_monochrome_boundary_and_invisible_pixels(self):
        self.assertEqual(grayscale_score([(128, 128, 128, 255), (255, 0, 0, 0)]), 0)
        self.assertEqual(grayscale_score([(255, 0, 0, 0)]), 0)
        self.assertAlmostEqual(grayscale_score([(128, 128, 128)] * 99 + [(255, 0, 0)]), .01)
        for method, score in [("content", .035), ("content", 0), ("monochrome", 1)]:
            roles = {"primary": "#A0B0C0", "surface": "#102030"}
            apply_surface_tint(roles, method, "tinted", score)
            self.assertEqual(roles["surface"], "#102030")
        roles = {"primary": "#A0B0C0", "surface": "#102030"}
        apply_surface_tint(roles, "content", "tinted", .035001)
        self.assertEqual(roles["surface"], "#182838")


@unittest.skipUnless(shutil.which("magick") or shutil.which("convert"), "ImageMagick required")
class ProcessorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.wallpaper = self.directory / "wallpaper.ppm"
        # Saturated real image; avoid source-score and decoder ambiguity.
        self.wallpaper.write_bytes(b"P6\n128 128\n255\n" + bytes((30, 110, 210)) * 128 * 128)

    def processor(self, *args):
        return subprocess.run([sys.executable, str(THEMING / "template-processor.py"),
                               *map(str, args)], capture_output=True, text=True, check=True)

    def test_dark_light_pipeline_and_external_template_share_final_roles(self):
        classic = json.loads(self.processor(self.wallpaper, "--scheme-type", "content").stdout)
        tinted = json.loads(self.processor(self.wallpaper, "--scheme-type", "content",
                                           "--surface-style", "tinted").stdout)
        source = Color(30, 110, 210)
        external = self.directory / "external.css.in"
        external.write_text("surface={{colors.surface.default.hex}}\nhigh={{colors.surface_container_high.default.hex}}\n")
        for mode in ("dark", "light"):
            with self.subTest(mode=mode):
                self.assertEqual(classic[mode], generate_theme([source], mode, "content"))
                for role in ("primary", "secondary", "tertiary", "on_surface", "outline", "shadow"):
                    self.assertEqual(tinted[mode][role], classic[mode][role])
                self.assertNotEqual(tinted[mode]["surface"], classic[mode]["surface"])
                for role, multiplier in SURFACE_MULTIPLIERS.items():
                    if role in classic[mode]:
                        self.assertEqual(tinted[mode][role], mix_hex(classic[mode][role],
                                         classic[mode]["primary"], .075 * multiplier))
                # These roles form an actual luminance hierarchy, not just present keys.
                keys = ["surface_container_lowest", "surface_container_low", "surface_container",
                        "surface_container_high", "surface_container_highest"]
                tones = [Color.from_hex(tinted[mode][key]).to_hsl()[2] for key in keys]
                self.assertEqual(tones, sorted(tones, reverse=(mode == "light")))
                for style, palette in (("classic", classic), ("tinted", tinted)):
                    config = self.directory / "templates.toml"
                    colors = self.directory / "colors.json"
                    css = self.directory / "external.css"
                    config.write_text(f'[config]\n[templates.hydra]\ninput_path = "{ROOT / "Assets/Templates/hydra.json"}"\noutput_path = "{colors}"\n[templates.external]\ninput_path = "{external}"\noutput_path = "{css}"\n')
                    self.processor(self.wallpaper, "--scheme-type", "content", "--surface-style", style,
                                   "--config", config, "--default-mode", mode)
                    output = json.loads(colors.read_text())
                    self.assertEqual(Color.from_hex(output["mSurface"]), Color.from_hex(palette[mode]["surface"]))
                    self.assertEqual(Color.from_hex(output["mPrimary"]), Color.from_hex(classic[mode]["primary"]))
                    css_values = dict(line.split("=", 1) for line in css.read_text().splitlines())
                    self.assertEqual(Color.from_hex(css_values["surface"]), Color.from_hex(output["mSurface"]))
                    self.assertEqual(Color.from_hex(css_values["high"]), Color.from_hex(palette[mode]["surface_container_high"]))

    def test_real_nearly_gray_image_does_not_tint_saturated_seed(self):
        self.wallpaper.write_bytes(b"P6\n128 128\n255\n" + bytes((130, 130, 130)) * 16320
                                  + bytes((220, 20, 30)) * 64)
        self.assertLessEqual(grayscale_score(read_grayscale_sample(self.wallpaper)), .035)
        classic = self.processor(self.wallpaper, "--scheme-type", "content").stdout
        tinted = self.processor(self.wallpaper, "--scheme-type", "content", "--surface-style", "tinted").stdout
        self.assertEqual(json.loads(tinted), json.loads(classic))

    def test_authored_predefined_scheme_ignores_tinted(self):
        scheme = ROOT / "Assets/ColorScheme/Hydra-default/Hydra-default.json"
        classic = json.loads(self.processor("--scheme", scheme).stdout)
        tinted = json.loads(self.processor("--scheme", scheme, "--surface-style", "tinted").stdout)
        self.assertEqual(tinted, classic)
        original = json.loads(scheme.read_text())
        for mode in ("dark", "light"):
            self.assertEqual(tinted[mode]["surface"], original[mode]["mSurface"])
            output = self.directory / "colors.json"
            self.processor("--scheme", scheme, "--surface-style", "tinted", "--default-mode", mode,
                           "--render", f"{ROOT / 'Assets/Templates/hydra.json'}:{output}")
            rendered = json.loads(output.read_text())
            self.assertEqual(Color.from_hex(rendered["mSurface"]), Color.from_hex(original[mode]["mSurface"]))


if __name__ == "__main__":
    unittest.main()
