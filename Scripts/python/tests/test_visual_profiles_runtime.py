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
