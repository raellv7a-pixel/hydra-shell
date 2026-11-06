"""Real material rendering, fallback and persistence in a private compositor."""
import json
import os
import shutil
import signal
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
        for name in ("Commons", "Widgets", "Services", "Modules", "Helpers", "Scripts", "Assets", "Shaders", "Native"):
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
                       WLR_HEADLESS_OUTPUTS="2", WLR_RENDERER_ALLOW_SOFTWARE="1",
                       XDG_CURRENT_DESKTOP="Umbriel", XDG_SESSION_DESKTOP="umbriel", XDG_SESSION_TYPE="wayland")
        for key in ("UMBRIEL_SOCKET", "DISPLAY", "SESSION_MANAGER"):
            cls.env.pop(key, None)
        cls.env["UMBRIEL_SOCKET"] = str(cls.lab / "runtime/umbriel-wayland-0.sock")
        bus = subprocess.check_output(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"], env=cls.env, text=True).splitlines()
        cls.env["DBUS_SESSION_BUS_ADDRESS"] = bus[0]
        cls.addClassCleanup(lambda: subprocess.run(["kill", bus[1]], capture_output=True))
        (cls.lab / "umbriel.toml").write_text('[general]\nxwayland=false\n[output.HEADLESS-1]\nmode="1200x900@60"\n[output.HEADLESS-2]\nmode="1200x900@60"\n[keybinds]\n"Alt+Escape"="session-quit"\n')
        cls.log = (cls.lab / "runtime.log").open("w")
        cls.addClassCleanup(cls.log.close)
        cls.compositor = subprocess.Popen(["umbriel", "-c", str(cls.lab / "umbriel.toml")], env=cls.env, stdout=cls.log, stderr=cls.log, start_new_session=True)
        cls.addClassCleanup(cls.stop, cls.compositor)
        cls.wait(lambda: (cls.lab / "runtime/wayland-0").exists())
        cls.start_shell()
        cls.addClassCleanup(lambda: cls.stop(cls.shell))

    @classmethod
    def start_shell(cls):
        cls.shell = subprocess.Popen(["qs", "-p", str(cls.lab)], env=cls.env, stdout=cls.log, stderr=cls.log, start_new_session=True)
        cls.wait(lambda: cls.call("snapshot")["ready"])

    @staticmethod
    def stop(process):
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        finally:
            # A QML Process may own a compiler subprocess; do not leave it
            # writing into the fixture after its Quickshell parent exits.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
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

    def capture_pixels(self, name):
        # Qt writes P6 directly; keep the renderer regression dependency-free.
        path = self.lab / f"{name}.ppm"
        self.call("capture", str(path))
        self.wait(lambda: path.exists() and path.stat().st_size > 1200 * 900 * 3)
        with path.open("rb") as image:
            self.assertEqual(image.readline().strip(), b"P6")
            width, height = map(int, image.readline().split())
            self.assertEqual(image.readline().strip(), b"255")
            pixels = image.read()
        self.assertEqual(len(pixels), width * height * 3)
        return lambda x, y: tuple(pixels[(y * width + x) * 3:(y * width + x + 1) * 3])

    def test_chassis_opacity_fades_the_composed_material_once(self):
        self.call("select", "aurora", "false")
        self.call("reduced", "false")
        self.call("effects", "false")
        self.call("adjustments", 1, 0)
        self.call("probe", "true", 8)
        self.addCleanup(self.call, "probe", "false", 8)
        self.addCleanup(self.call, "fade", 1)
        full = self.capture_pixels("chassis-opaque")
        self.call("fade", 0)
        clear = self.capture_pixels("chassis-transparent")
        self.call("fade", .5)
        half = self.capture_pixels("chassis-half-opacity")
        for point in ((420, 31), (420, 33)):
            expected = [(a + b) / 2 for a, b in zip(full(*point), clear(*point))]
            self.assertLessEqual(max(abs(a - b) for a, b in zip(half(*point), expected)), 2)

    def test_chassis_light_crosses_the_bar_panel_join_and_switches_off(self):
        self.call("select", "aurora", "false")
        self.call("reduced", "false")
        self.call("effects", "false")
        self.call("probe", "true", 8)
        self.addCleanup(self.call, "probe", "false", 8)
        self.call("adjustments", 0, 0)
        dark = self.capture_pixels("chassis-light-off")
        self.call("adjustments", 1, 0)
        lit = self.capture_pixels("chassis-light-on")
        # One output-space light, no second rectangle beginning at the panel.
        bar, panel = (420, 31), (420, 33)
        self.assertGreater(lit(*bar)[0], dark(*bar)[0] + 10)
        self.assertGreater(lit(*panel)[0], dark(*panel)[0] + 10)
        self.assertLessEqual(max(abs(a - b) for a, b in zip(lit(*bar), lit(*panel))), 4)
        self.assertLessEqual(max(dark(*bar) + dark(*panel)), 2)
        # The original finite ramp must not turn into a uniform full-body veil.
        self.assertLessEqual(max(abs(a - b) for a, b in zip(lit(420, 380), dark(420, 380))), 2)

    def test_frame_bevel_fits_bar_clearance_without_flattening_body_bevel(self):
        self.call("select", "y2k", "false")
        self.call("reduced", "false")
        self.call("effects", "false")
        self.call("adjustments", 1, 0)
        self.call("probe", "true", 8)
        self.addCleanup(self.call, "probe", "false", 8)
        wide = self.capture_pixels("frame-lip-wide")
        self.call("probe", "true", 3)
        narrow = self.capture_pixels("frame-lip-narrow")
        # A tight native bar can reserve room for its capsules without losing
        # the independent body's original rounded, wider metallic finish.
        self.assertGreater(max(abs(a - b) for a, b in zip(wide(100, 28), narrow(100, 28))), 10)
        self.assertLessEqual(max(abs(a - b) for a, b in zip(wide(420, 398), narrow(420, 398))), 2)

    def test_native_frame_reserves_the_capsule_gutter(self):
        self.call("select", "y2k", "false")
        self.call("reduced", "false")
        self.call("effects", "false")
        self.call("adjustments", 1, 0)
        self.call("nativeFrame", "true", "false")
        self.addCleanup(self.call, "nativeFrame", "false", "true")
        wide = self.capture_pixels("native-frame-without-capsules")
        self.call("nativeFrame", "true", "true")
        narrow = self.capture_pixels("native-frame-with-capsules")
        self.assertGreater(max(abs(a - b) for a, b in zip(wide(100, 27), narrow(100, 27))), 10)

    def test_shared_backdrop_releases_and_recreates_after_renderer_teardown(self):
        self.call("select", "liquid-glass", "false")
        self.call("effects", "true")
        self.call("reduced", "false")
        self.wait(lambda: self.call("snapshot")["sources"] == 1)
        self.assertEqual(self.call("snapshot")["sources"], 1)
        self.call("reduced", "true")
        self.wait(lambda: self.call("snapshot")["sources"] == 0)
        self.assertEqual(self.call("snapshot")["fields"], 0)
        self.call("reduced", "false")
        self.wait(lambda: self.call("snapshot")["sources"] == 1)
        self.assertEqual(self.call("snapshot")["sources"], 1)

    def test_unknown_profile_does_not_keep_the_previous_material_palette(self):
        self.call("select", "y2k", "false")
        self.call("select", "unknown-profile", "false")
        self.wait(lambda: (state := self.call("snapshot"))["primary"] == state["sourcePrimary"]
                  and state["surface"] == state["sourceSurface"])
        state = self.call("snapshot")
        self.assertEqual(state["profile"], "material3")
        self.assertEqual(state["primary"], state["sourcePrimary"])
        self.assertEqual(state["surface"], state["sourceSurface"])


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
        self.assertFalse(state["glass"])
        self.assertEqual(state["sources"], 0)
        self.call("effects", "true")


if __name__ == "__main__":
    unittest.main()
