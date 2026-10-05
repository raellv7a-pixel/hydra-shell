"""Native QML regressions in an isolated headless Umbriel and private XDG/DBus."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
FIXTURE = ROOT / "Scripts/dev/tests/launcher-polish.qml"
REQUIRED = ("umbriel", "qs", "dbus-daemon")


@unittest.skipUnless(all(shutil.which(command) for command in REQUIRED), "Native Umbriel/Quickshell/DBus required")
class LauncherPolishRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="hydra-polish-test-")
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.lab = Path(cls.tmp.name)
        for name in ("config", "cache", "state", "data", "runtime", "bin"):
            (cls.lab / name).mkdir(mode=0o700)
        for name in ("Commons", "Widgets", "Services", "Modules", "Helpers", "Scripts", "Assets", "Shaders"):
            (cls.lab / name).symlink_to(ROOT / name, target_is_directory=True)
        shutil.copyfile(FIXTURE, cls.lab / "shell.qml")
        cls.apps = cls.lab / "data/applications"
        cls.apps.mkdir()
        for i in range(100):
            identity = f"app-{i:03}"
            (cls.apps / f"{identity}.desktop").write_text(f"[Desktop Entry]\nType=Application\nName={identity}\nExec={identity}\nCategories=System;\n")
        (cls.apps / "code.desktop").write_text("[Desktop Entry]\nType=Application\nName=Code\nExec=code\n")
        cls.env = dict(os.environ, XDG_CONFIG_HOME=str(cls.lab / "config"), XDG_CACHE_HOME=str(cls.lab / "cache"),
                       XDG_STATE_HOME=str(cls.lab / "state"), XDG_DATA_HOME=str(cls.lab / "data"),
                       XDG_RUNTIME_DIR=str(cls.lab / "runtime"), WAYLAND_DISPLAY="wayland-0", QT_QPA_PLATFORM="wayland",
                       HYDRA_CONFIG_DIR=str(cls.lab / "config/hydra"), HYDRA_CACHE_DIR=str(cls.lab / "cache/hydra"),
                       HYDRA_SETTINGS_FILE=str(cls.lab / "config/hydra/settings.json"),
                       WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER_ALLOW_SOFTWARE="1",
                       PATH=str(cls.lab / "bin") + os.pathsep + os.environ["PATH"])
        for key in ("UMBRIEL_SOCKET", "DISPLAY", "SESSION_MANAGER"):
            cls.env.pop(key, None)
        bus = subprocess.check_output(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"], env=cls.env, text=True).splitlines()
        cls.env["DBUS_SESSION_BUS_ADDRESS"] = bus[0]
        cls.addClassCleanup(lambda: subprocess.run(["kill", bus[1]], capture_output=True))
        cls.write_binary("pacman", f"""import sys
if '-Qmq' in sys.argv:print('visual-studio-code-bin')
elif '-Ql' in sys.argv:
 for i in range(100):print(f'app-{{i:03}} {cls.apps}/app-{{i:03}}.desktop')
 print('visual-studio-code-bin {cls.apps}/code.desktop')
elif '-Q' in sys.argv:
 for i in range(100):print(f'app-{{i:03}} 1.0')
 print('visual-studio-code-bin 1.2')
else:sys.exit(1)
""")
        cls.write_binary("flatpak", "import sys\nif sys.argv[1]=='list':print('org.mozilla.firefox\\t1.0')\nelse:sys.exit(1)\n")
        cls.write_binary("shelly", f"""import sys,os,json,time,signal,pathlib
root=pathlib.Path({str(cls.lab)!r})
def event(value):
 with (root/'events.jsonl').open('a') as stream:stream.write(json.dumps({{'event':value,'argv':sys.argv[1:]}})+'\\n')
if '--version' in sys.argv:print('3.1.6')
elif sys.argv[1:3]==['list','appimage']:print('[]')
elif 'list-updates' in sys.argv:
 def stopped(*args):event('scan-stopping');time.sleep(.3);event('scan-stopped');sys.exit(143)
 signal.signal(signal.SIGTERM,stopped)
 (root/'scan.pid').write_text(str(os.getpid()));event('scan-start')
 while not (root/'scan-release').exists():time.sleep(.01)
 print(json.dumps({{'Packages':[{{'Name':'app-040','CurrentVersion':'1.0','NewVersion':'2.0'}}]}}));event('scan-finished')
elif sys.argv[1] in ('update','remove','upgrade'):
 pid=int((root/'scan.pid').read_text());state=pathlib.Path(f'/proc/{{pid}}/stat')
 if state.exists() and state.read_text().split()[2]!='Z':event('OVERLAP');sys.exit(44)
 event('mutation-start')
 while not (root/'operation-release').exists():time.sleep(.01)
 event('mutation-finished');print('Fixture completed')
else:sys.exit(1)
""")
        cache = cls.lab / "cache/hydra/shelly-updates.json"
        cache.parent.mkdir()
        cache.write_text(json.dumps({"schema": 1, "timestamp": time.time(), "updates": [{"type": "standard", "name": "app-040", "currentVersion": "1.0", "version": "2.0", "aliases": ["app-040"]}]}))
        (cls.lab / "umbriel.toml").write_text('[general]\nxwayland=false\n[output.HEADLESS-1]\nmode="1000x800@60"\n[keybinds]\n"Alt+Escape"="session-quit"\n')
        cls.log = (cls.lab / "runtime.log").open("w")
        cls.addClassCleanup(cls.log.close)
        subprocess.run(["umbriel", "config", "validate", "-c", str(cls.lab / "umbriel.toml")], env=cls.env, check=True, stdout=cls.log, stderr=cls.log)
        cls.compositor = subprocess.Popen(["umbriel", "-c", str(cls.lab / "umbriel.toml")], env=cls.env, stdout=cls.log, stderr=cls.log)
        cls.addClassCleanup(cls.stop, cls.compositor)
        cls.wait(lambda: (cls.lab / "runtime/wayland-0").exists(), timeout=10)
        cls.shell = subprocess.Popen(["qs", "-p", str(cls.lab / "shell.qml")], env=cls.env, stdout=cls.log, stderr=cls.log)
        cls.addClassCleanup(cls.stop, cls.shell)
        cls.wait(lambda: cls.call("state")["ready"], timeout=10)
        # Umbriel shows its startup keybind overlay even with valid bindings.
        # It otherwise intercepts native pointer events over the test surface.
        subprocess.run(["umbriel", "msg", "cheatsheet-close"], env=cls.env, check=True, stdout=cls.log, stderr=cls.log)

    @classmethod
    def write_binary(cls, name, body):
        path = cls.lab / "bin" / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)

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
    def wait(cls, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (subprocess.SubprocessError, json.JSONDecodeError, KeyError):
                pass
            time.sleep(.02)
        raise AssertionError("Runtime transition timed out:\n" + (cls.lab / "runtime.log").read_text()[-5000:])

    @classmethod
    def call(cls, method, *args):
        output = subprocess.check_output(["qs", "ipc", "-p", str(cls.lab / "shell.qml"), "call", "test", method, *map(str, args)], env=cls.env, text=True, stderr=subprocess.DEVNULL, timeout=3).strip()
        return json.loads(output) if output else None

    def prepare(self):
        self.call("prepare")
        time.sleep(.35)
        self.call("panel", 40)
        time.sleep(.35)
        self.call("position")
        time.sleep(.05)
        self.call("remember")
        before = self.call("snapshot")
        self.assertGreater(before["y"], 500)
        self.assertGreater(before["panelY"], 0)
        self.assertLess(before["panelY"], 700)
        self.assertEqual(before["selected"], "app-040")
        self.assertTrue(before["open"])
        return before

    def events(self):
        path = self.lab / "events.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_seam_only_during_real_reveal_geometry(self):
        for height, visible in [(100, True), (220, False), (190, True), (0, False)]:
            with self.subTest(height=height):
                state = self.call("setGeometry", height)
                self.assertEqual(state["visible"], visible)
                if not visible:
                    self.assertEqual(state["opacity"], 0)

    def test_hover_previous_surface_clears_before_next_finishes_entering(self):
        self.call("hover", 0)
        time.sleep(.15)
        self.assertGreater(self.call("hoverState")["a"], 0)
        for index, previous in [(1, "a"), (2, "b")]:
            self.call("hover", index)
            time.sleep(.075)
            state = self.call("hoverState")
            self.assertLess(state["leave"], state["enter"])
            current = state["b" if index == 1 else "c"]
            self.assertGreater(current, 0)
            # Compare visible state contrast, not exact zero-alpha rounding at
            # a particular animation frame (QColor is quantized).
            self.assertLess(state[previous], current * .1)

    def test_keyboard_navigation_keeps_primary_current_indication(self):
        self.call("prepare")
        time.sleep(.15)
        self.call("keyDown")
        time.sleep(.15)
        state = self.call("snapshot")
        self.assertEqual(state["selected"], "app-001")
        self.assertTrue(state["selectedStyle"])
        self.assertFalse(state["hoveredStyle"])
        self.assertFalse(state["contextTarget"])

    def test_pointer_keyboard_and_context_have_one_primary_target(self):
        self.call("prepare")
        time.sleep(.15)
        self.call("interaction", "keyboard")
        self.wait(lambda: "firstPrimary" in self.call("interaction", "probe")
                  and "secondPrimary" in self.call("interaction", "probe"))
        keyboard = self.call("interaction", "probe")
        self.assertEqual((keyboard["selected"], keyboard["firstPrimary"], keyboard["secondPrimary"]), (0, True, False))
        pointer = self.call("interaction", "pointer")
        self.assertEqual((pointer["selected"], pointer["firstPrimary"], pointer["secondPrimary"]), (0, False, False))
        context = self.call("interaction", "context")
        self.assertEqual((context["selected"], context["firstPrimary"], context["secondPrimary"], context["context"]), (0, False, True, True))
        return_to_keyboard = self.call("interaction", "keyboard")
        self.assertEqual((return_to_keyboard["firstPrimary"], return_to_keyboard["secondPrimary"]), (True, False))

    def test_removal_requires_real_owner_or_installed_flatpak_identity(self):
        code = self.call("mapping", 0)
        self.assertEqual(code["package"]["name"], "visual-studio-code-bin")
        self.assertEqual(code["package"]["type"], "aur")
        self.assertTrue(code["removeEnabled"])
        flatpak = self.call("mapping", 1)
        self.assertEqual(flatpak["package"]["name"], "org.mozilla.firefox")
        self.assertEqual(flatpak["package"]["currentVersion"], "1.0")
        self.assertTrue(flatpak["removeEnabled"])
        for choice in (2, 3):
            unmanaged = self.call("mapping", choice)
            self.assertIsNone(unmanaged["package"])
            self.assertFalse(unmanaged["removeEnabled"])

    def test_manual_subfolders_bound_depth_preserve_missing_apps_and_close_on_deletion(self):
        self.call("prepare")
        parent = self.call("saveFolder", "", "Work", "app-040", "")
        try:
            child = self.call("saveFolder", "", "Suite", "app-041", parent)
            absent = self.call("saveFolder", "", "Absent", "not-installed", parent)
            self.assertEqual(self.call("saveFolder", "", "Too deep", "app-042", child), "")
            self.call("saveFolder", child, "Renamed", "", parent)
            self.call("saveFolder", absent, "Still absent", "", parent)
            self.wait(lambda: len(self.call("folderState", parent)["subfolders"]) == 2)
            state = self.call("folderState", parent)
            self.assertEqual(state["apps"], ["app-040"])
            self.assertEqual(state["subfolders"], [
                {"id": child, "name": "Renamed", "apps": ["app-041"]},
                {"id": absent, "name": "Still absent", "apps": []},
            ])
            self.assertEqual(state["stored"]["children"][1]["apps"], ["not-installed"])
            self.call("expandFolder", parent, child)
            self.wait(lambda: self.call("folderState", parent)["expanded"])
            self.assertEqual(self.call("folderState", parent)["state"], "home")
            self.call("deleteFolder", child, parent)
            self.wait(lambda: self.call("folderState", parent)["child"] == "")
            self.assertTrue(self.call("folderState", parent)["expanded"])
            self.call("deleteFolder", parent, "")
            self.wait(lambda: not self.call("folderState", parent)["expanded"])
        finally:
            self.call("deleteFolder", parent, "")

    def test_metadata_preserves_live_entry_panel_selection_and_viewport(self):
        self.call("clearUpdates")
        self.prepare()
        self.call("showActions")
        self.wait(lambda: (state := self.call("snapshot"))["panelHeight"] == state["panelTargetHeight"])
        self.call("remember")
        before = self.call("snapshot")
        self.assertTrue(before["actionPresent"])
        self.assertEqual(before["badge"], "")
        (self.lab / "scan-release").unlink(missing_ok=True)
        self.call("scan")
        self.wait(lambda: self.call("state")["scan"])
        (self.lab / "scan-release").touch()
        self.wait(lambda: not self.call("state")["scan"])
        after = self.call("snapshot")
        for key in ("y", "selected", "panel", "open", "properties", "panelY", "panelHeight", "count"):
            self.assertEqual(after[key], before[key], key)
        for key in ("resultsStable", "rowStable", "entryStable", "panelStable", "actionStable"):
            self.assertTrue(after[key], key)
        self.assertEqual(after["badge"], "refresh-dot")
        self.assertTrue(next(action for action in after["actions"] if action["id"] == "update")["enabled"])

    def test_scanner_is_reaped_before_mutation_and_busy_has_feedback(self):
        self.prepare()
        self.call("showActions")
        time.sleep(.1)
        (self.lab / "scan-release").unlink(missing_ok=True)
        (self.lab / "operation-release").unlink(missing_ok=True)
        start = len(self.events())
        self.call("scan")
        self.wait(lambda: any(event["event"] == "scan-start" for event in self.events()[start:]))
        self.call("update", 40)
        waiting = self.call("state")
        self.assertEqual(waiting["phase"], "waiting")
        self.assertTrue(waiting["busy"])
        self.assertTrue(next(action for action in self.call("snapshot")["actions"] if action["id"] == "update")["busy"])
        self.wait(lambda: self.call("state")["phase"] == "update")
        self.assertFalse(self.call("state")["scan"])
        self.call("remove", 40)
        self.assertTrue(self.call("state")["error"], "second write was silently ignored")
        (self.lab / "operation-release").touch()
        self.wait(lambda: not self.call("state")["busy"])
        self.wait(lambda: self.call("state")["scan"])
        (self.lab / "scan-release").touch()
        self.wait(lambda: not self.call("state")["scan"])
        events = self.events()[start:]
        self.assertNotIn("OVERLAP", [event["event"] for event in events])
        writes = [event for event in events if event["event"] == "mutation-start"]
        self.assertEqual([event["argv"] for event in writes], [["update", "standard", "app-040", "--no-confirm"]])
        self.assertLess([event["event"] for event in events].index("scan-stopped"), [event["event"] for event in events].index("mutation-start"))
        self.assertTrue(self.call("snapshot")["resultsStable"])

    def test_completed_operation_does_not_reopen_panel_on_later_search(self):
        self.prepare()
        (self.lab / "scan-release").touch()
        self.call("scan")
        self.wait(lambda: (self.lab / "scan.pid").exists() and not self.call("state")["scan"])
        (self.lab / "operation-release").unlink(missing_ok=True)
        self.call("update", 40)
        self.wait(lambda: self.call("state")["busy"])
        (self.lab / "operation-release").touch()
        self.wait(lambda: not self.call("state")["busy"] and not self.call("state")["scan"])
        self.assertEqual(self.call("snapshot")["pendingPanel"], "")
        self.assertTrue(self.call("snapshot")["panelStable"])
        self.call("prepare")
        self.assertFalse(self.call("snapshot")["open"])
        self.call("requestPanel", "removed-application")
        self.assertEqual(self.call("snapshot")["pendingPanel"], "")
        self.call("prepare")
        self.assertFalse(self.call("snapshot")["open"])
        self.call("search", "app-000")
        self.assertFalse(self.call("contains", "app-040"))
        self.call("requestPanel", "app-040")
        self.wait(lambda: self.call("snapshot")["panel"] == "app-040")
        self.assertEqual(self.call("snapshot")["pendingPanel"], "")

    def test_warm_cache_refreshes_at_remaining_lifetime(self):
        self.stop(self.__class__.shell)
        cache = self.lab / "cache/hydra/shelly-updates.json"
        data = json.loads(cache.read_text())
        data["timestamp"] = time.time() - 30 * 60 + 1.5
        cache.write_text(json.dumps(data))
        (self.lab / "scan-release").unlink(missing_ok=True)
        start = len(self.events())
        self.__class__.shell = subprocess.Popen(["qs", "-p", str(self.lab / "shell.qml")], env=self.env,
                                              stdout=self.__class__.log, stderr=self.__class__.log)
        self.addClassCleanup(self.stop, self.__class__.shell)
        try:
            self.wait(lambda: self.call("state")["ready"])
            self.wait(lambda: any(event["event"] == "scan-start" for event in self.events()[start:]), timeout=4)
            self.assertGreater(self.call("state")["records"], 0)
        finally:
            (self.lab / "scan-release").touch()
            self.wait(lambda: not self.call("state")["scan"])

    def test_warm_metadata_survives_launcher_reopening_without_duplicate_scan(self):
        scans = len([event for event in self.events() if event["event"] == "scan-start"])
        self.call("prepare")
        time.sleep(.1)
        self.call("prepare")
        time.sleep(.1)
        self.assertEqual(len([event for event in self.events() if event["event"] == "scan-start"]), scans)
        self.assertFalse(self.call("state")["scan"])
        self.assertEqual(self.call("state")["error"], "")

    def test_xdg_desktop_removal_updates_real_app_composition(self):
        self.call("prepare")
        self.assertTrue(self.call("contains", "app-099"))
        desktop = self.apps / "app-099.desktop"
        original = desktop.read_text()
        try:
            desktop.unlink()
            self.wait(lambda: not self.call("contains", "app-099"))
            self.assertTrue(self.call("contains", "app-040"))
        finally:
            desktop.write_text(original)


if __name__ == "__main__":
    unittest.main()
