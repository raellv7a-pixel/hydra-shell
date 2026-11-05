"""Real material rendering, fallback and persistence in a private compositor."""
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
PROFILES = ("material3", "tinted-glass", "liquid-glass", "frost", "aurora", "obsidian", "lume", "afterglow", "y2k", "washi")


@unittest.skipUnless(all(shutil.which(binary) for binary in ("umbriel", "qs", "dbus-daemon")), "Native runtime required")
class VisualProfilesRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="hydra-material-test-")
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.lab = Path(cls.tmp.name)
        for name in ("config", "cache", "state", "data", "runtime"):
            (cls.lab / name).mkdir(mode=0o700)
        for name in ("Commons", "Widgets", "Services", "Modules", "Helpers", "Scripts", "Assets", "Shaders"):
            (cls.lab / name).symlink_to(ROOT / name, target_is_directory=True)
        shutil.copyfile(ROOT / "Scripts/dev/tests/visual-profiles.qml", cls.lab / "shell.qml")
        settings = json.loads((ROOT / "Assets/settings-default.json").read_text())
        settings["settingsVersion"] = 61
        settings["templates"]["activeTemplates"] = []
        settings["wallpaper"]["enabled"] = False
        (cls.lab / "config/settings.json").write_text(json.dumps(settings))
        cls.env = dict(os.environ, XDG_CONFIG_HOME=str(cls.lab / "config"), XDG_CACHE_HOME=str(cls.lab / "cache"),
                       XDG_DATA_HOME=str(cls.lab / "data"), XDG_STATE_HOME=str(cls.lab / "state"),
                       XDG_RUNTIME_DIR=str(cls.lab / "runtime"), WAYLAND_DISPLAY="wayland-0", QT_QPA_PLATFORM="wayland",
                       HYDRA_CONFIG_DIR=str(cls.lab / "config"), HYDRA_CACHE_DIR=str(cls.lab / "cache"),
                       HYDRA_SETTINGS_FILE=str(cls.lab / "config/settings.json"), WLR_BACKENDS="headless",
                       WLR_HEADLESS_OUTPUTS="2", WLR_RENDERER_ALLOW_SOFTWARE="1")
        for key in ("UMBRIEL_SOCKET", "DISPLAY", "SESSION_MANAGER"):
            cls.env.pop(key, None)
        bus = subprocess.check_output(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"], env=cls.env, text=True).splitlines()
        cls.env["DBUS_SESSION_BUS_ADDRESS"] = bus[0]
        cls.addClassCleanup(lambda: subprocess.run(["kill", bus[1]], capture_output=True))
        (cls.lab / "umbriel.toml").write_text('[general]\nxwayland=false\n[output.HEADLESS-1]\nmode="1200x900@60"\n[output.HEADLESS-2]\nmode="1200x900@60"\n[keybinds]\n"Alt+Escape"="session-quit"\n')
        cls.log = (cls.lab / "runtime.log").open("w")
        cls.addClassCleanup(cls.log.close)
        cls.compositor = subprocess.Popen(["umbriel", "-c", str(cls.lab / "umbriel.toml")], env=cls.env, stdout=cls.log, stderr=cls.log)
        cls.addClassCleanup(cls.stop, cls.compositor)
        cls.wait(lambda: (cls.lab / "runtime/wayland-0").exists())
        cls.start_shell()
        cls.addClassCleanup(lambda: cls.stop(cls.shell))

    @classmethod
    def start_shell(cls):
        cls.shell = subprocess.Popen(["qs", "-p", str(cls.lab)], env=cls.env, stdout=cls.log, stderr=cls.log)
        cls.wait(lambda: cls.call("snapshot")["ready"])

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

    @classmethod
    def wait(cls, predicate):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (subprocess.SubprocessError, ValueError, KeyError, TypeError):
                pass
            time.sleep(.03)
        raise AssertionError((cls.lab / "runtime.log").read_text()[-5000:])

    @classmethod
    def call(cls, method, *args) -> Any:
        text = subprocess.check_output(["qs", "ipc", "-p", str(cls.lab), "call", "materials", method, *map(str, args)], env=cls.env, text=True, stderr=subprocess.DEVNULL, timeout=3)
        return json.loads(text) if text.strip() else None

    def test_profile_switches_compile_and_reduced_mode_unloads_effects(self):
        self.call("effects", "true")
        self.call("reduced", "false")
        for light in ("false", "true"):
            for profile in PROFILES:
                with self.subTest(profile=profile, light=light):
                    self.call("select", profile, light)
                    self.wait(lambda profile=profile: self.call("snapshot")["profile"] == profile)
                    self.wait(lambda: all(shader.get("status", 0) != 2 for shader in self.call("snapshot")["shaders"]))
                    state = self.call("snapshot")
                    self.assertTrue(all(not shader["log"] for shader in state["shaders"]))
                    # No wallpaper: every material remains a fully readable opaque surface.
                    self.assertEqual(state["alpha"], 1)
                    self.assertEqual(state["sources"], 0)
        self.call("select", "afterglow", "false")
        self.call("reduced", "true")
        self.wait(lambda: not self.call("snapshot")["shaders"])
        state = self.call("snapshot")
        self.assertEqual(state["animation"], 0)
        self.assertFalse(state["effects"])
        self.call("reduced", "false")

    def test_adjustments_and_unknown_profile_fallback(self):
        self.call("select", "washi", "true")
        self.call("adjustments", 0, 0, 0)
        state = self.call("snapshot")
        self.assertEqual(state["texture"], 0)
        self.assertEqual(state["paper"], 0)
        self.assertEqual(state["lighting"], 0)
        self.call("select", "unknown-profile", "false")
        state = self.call("snapshot")
        self.assertEqual(state["profile"], "material3")
        self.assertEqual(state["alpha"], 1)
        self.call("adjustments", 1, 1, 1)

    def test_edge_light_is_independent_and_zero_unloads_finish(self):
        self.call("effects", "true")
        self.call("reduced", "false")
        self.call("select", "tinted-glass", "false")
        self.call("adjustments", 0, 0, 0)
        try:
            self.call("glass", 0, 0, 1)
            self.wait(lambda: any(shader["url"].endswith("material_finish.frag.qsb")
                                  and shader.get("status") == 1
                                  for shader in self.call("snapshot")["shaders"]))
            state = self.call("snapshot")
            self.assertEqual(state["lighting"], 0)
            self.assertTrue(all(shader.get("status", 0) != 2 and not shader["log"]
                                for shader in state["shaders"]))
            self.call("glass", 0, 0, 0)
            self.wait(lambda: not any(shader["url"].endswith("material_finish.frag.qsb")
                                      for shader in self.call("snapshot")["shaders"]))
            state = self.call("snapshot")
            self.assertEqual(state["alpha"], 1)
            self.assertEqual(state["sources"], 0)
        finally:
            self.call("glass", 0.56, 0.85, 0.4)
            self.call("adjustments", 1, 1, 1)

    def test_selected_profile_persists_across_process_restart(self):
        self.call("select", "y2k", "false")
        self.call("save")
        settings_path = self.lab / "config/settings.json"
        self.wait(lambda: json.loads(settings_path.read_text())["ui"]["visualVariant"] == "y2k")
        self.stop(self.shell)
        self.start_shell()
        self.assertEqual(self.call("snapshot")["profile"], "y2k")
        self.call("output", "HEADLESS-2")
        self.call("effects", "false")
        state = self.call("snapshot")
        self.assertFalse(state["effects"])
        self.assertEqual(state["alpha"], 1)
        self.assertEqual(state["sources"], 0)
        self.call("effects", "true")

    @unittest.skipUnless(shutil.which("magick"), "ImageMagick required for raster comparison")
    def test_wallpaper_source_never_paints_outside_surface_masks(self):
        wallpaper = self.lab / "checker.png"
        subprocess.run(["magick", "-size", "256x256", "pattern:checkerboard", str(wallpaper)], check=True)
        self.call("effects", "true")
        self.call("reduced", "false")
        self.call("glass", 0.56, 0.85, 0.4)
        self.call("adjustments", 1, 1, 1)
        self.call("select", "material3", "false")
        self.call("wallpaper", wallpaper)
        try:
            def outside_pixels(name):
                path = self.lab / (name + ".png")
                self.call("capture", path)
                self.wait(lambda: path.exists() and path.read_bytes().endswith(b"\x00\x00\x00\x00IEND\xaeB`\x82"))
                return subprocess.check_output([
                    "magick", str(path), "-gravity", "southeast", "-crop", "32x32+8+8",
                    "+repage", "-depth", "8", "rgba:-",
                ])

            baseline = outside_pixels("opaque-reading-surface")
            self.call("select", "frost", "false")
            self.wait(lambda: self.call("snapshot")["alpha"] < 1)
            self.assertEqual(self.call("snapshot")["sources"], 1)
            self.assertEqual(outside_pixels("frost-reading-surface"), baseline)
        finally:
            self.call("wallpaperEnabled", "false")
            self.wait(lambda: self.call("snapshot")["sources"] == 0)


if __name__ == "__main__":
    unittest.main()
