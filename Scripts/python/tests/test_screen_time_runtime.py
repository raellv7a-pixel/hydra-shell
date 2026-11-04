"""Screen-time accounting and persistence in native Quickshell/Umbriel."""
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
REQUIRED = ("umbriel", "qs", "dbus-daemon", "kitty")


@unittest.skipUnless(all(shutil.which(command) for command in REQUIRED), "Native Umbriel/Quickshell/DBus/kitty required")
class ScreenTimeRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="hydra-screen-time-")
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.lab = Path(cls.tmp.name)
        for name in ("config", "cache", "state", "data", "runtime"):
            (cls.lab / name).mkdir(mode=0o700)
        for name in ("Commons", "Widgets", "Services", "Modules", "Helpers", "Scripts", "Assets", "Shaders"):
            (cls.lab / name).symlink_to(ROOT / name, target_is_directory=True)
        shutil.copyfile(ROOT / "Scripts/dev/tests/screen-time.qml", cls.lab / "shell.qml")
        cls.env = dict(os.environ, XDG_CONFIG_HOME=str(cls.lab / "config"), XDG_CACHE_HOME=str(cls.lab / "cache"),
                       XDG_STATE_HOME=str(cls.lab / "state"), XDG_DATA_HOME=str(cls.lab / "data"),
                       XDG_RUNTIME_DIR=str(cls.lab / "runtime"), WAYLAND_DISPLAY="wayland-0", QT_QPA_PLATFORM="wayland",
                       XDG_CURRENT_DESKTOP="umbriel", XDG_SESSION_DESKTOP="umbriel",
                       HYDRA_CONFIG_DIR=str(cls.lab / "config/hydra"), HYDRA_CACHE_DIR=str(cls.lab / "cache/hydra"),
                       HYDRA_SETTINGS_FILE=str(cls.lab / "config/hydra/settings.json"),
                       WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER_ALLOW_SOFTWARE="1")
        for key in ("UMBRIEL_SOCKET", "DISPLAY", "SESSION_MANAGER"):
            cls.env.pop(key, None)
        bus = subprocess.check_output(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"], env=cls.env, text=True).splitlines()
        cls.env["DBUS_SESSION_BUS_ADDRESS"] = bus[0]
        cls.addClassCleanup(lambda: subprocess.run(["kill", bus[1]], capture_output=True))
        cls.log = (cls.lab / "runtime.log").open("w")
        cls.addClassCleanup(cls.log.close)
        (cls.lab / "umbriel.toml").write_text('[general]\nxwayland=false\n[output.HEADLESS-1]\nmode="1000x800@60"\n[keybinds]\n"Super+Escape"="session-quit"\n')
        cls.compositor = subprocess.Popen(["umbriel", "-c", str(cls.lab / "umbriel.toml")], env=cls.env, stdout=cls.log, stderr=cls.log)
        cls.addClassCleanup(cls.stop, cls.compositor)
        cls.wait(lambda: (cls.lab / "runtime/wayland-0").exists(), timeout=10)
        cls.start_shell()
        cls.addClassCleanup(lambda: cls.stop(cls.shell))
        subprocess.run(["umbriel", "msg", "cheatsheet-close"], env=cls.env, check=True, stdout=cls.log, stderr=cls.log)

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
    def start_shell(cls):
        cls.shell = subprocess.Popen(["qs", "-p", str(cls.lab / "shell.qml")], env=cls.env, stdout=cls.log, stderr=cls.log)
        cls.wait(lambda: cls.call("state")["loaded"], timeout=10)

    @classmethod
    def wait(cls, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (subprocess.SubprocessError, json.JSONDecodeError, KeyError):
                pass
            time.sleep(.05)
        raise AssertionError("Runtime transition timed out:\n" + (cls.lab / "runtime.log").read_text()[-5000:])

    @classmethod
    def call(cls, method, *args):
        value = subprocess.check_output(["qs", "ipc", "-p", str(cls.lab / "shell.qml"), "call", "screenTimeTest", method, *map(str, args)], env=cls.env, text=True, stderr=subprocess.DEVNULL, timeout=3).strip()
        return json.loads(value) if value else None

    def setUp(self):
        self.call("load", '{"days":{}}')

    def app(self, identity):
        process = subprocess.Popen(["kitty", "--class", identity, "--title", identity, "sh", "-c", "sleep 120"], env=self.env, stdout=self.log, stderr=self.log)
        self.addCleanup(self.stop, process)
        self.wait(lambda: self.call("state")["app"] == identity)
        return process

    def test_fractional_midnight_conserves_daily_hourly_and_app_totals(self):
        today = dt.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        start = (today - dt.timedelta(milliseconds=600)).timestamp() * 1000
        end = (today + dt.timedelta(milliseconds=600)).timestamp() * 1000
        self.call("accrue", "fractional-app", start, end)
        days = self.call("state")["days"]
        for date, hour in ((today - dt.timedelta(days=1), 23), (today, 0)):
            day = days[date.strftime("%Y-%m-%d")]
            self.assertAlmostEqual(day["total"], .6, places=5)
            self.assertAlmostEqual(day["apps"]["fractional-app"]["seconds"], .6, places=5)
            self.assertAlmostEqual(day["hourly"][hour], .6, places=5)
            self.assertAlmostEqual(day["appHourly"]["fractional-app"][hour], .6, places=5)

    def test_numeric_legacy_apps_remain_queryable_and_accrue(self):
        now = dt.datetime.now()
        key = now.strftime("%Y-%m-%d")
        self.call("load", json.dumps({"days": {key: {"total": 90, "apps": {"legacy-app": 90}}}}))
        end = now.timestamp() * 1000
        self.call("accrue", "legacy-app", end - 1000, end)
        stats = self.call("stats", 3)
        self.assertEqual(stats["totalSeconds"], 91)
        self.assertEqual(stats["topApps"][0]["seconds"], 91)
        self.assertAlmostEqual(stats["dailyAverageSeconds"], 91 / 3, delta=1)

    def test_real_focus_switch_and_automatic_save_survive_restart(self):
        first = self.app("screen-time-first")
        initial = self.call("state")["total"]
        self.wait(lambda: self.call("state")["total"] >= initial + 2, timeout=6)
        second = self.app("screen-time-second")
        self.wait(lambda: self.call("state")["total"] >= initial + 4, timeout=6)
        state_path = Path(self.call("state")["path"])
        # No forceSave: continuous heartbeat must not postpone persistence forever.
        self.wait(lambda: state_path.exists() and any("screen-time-second" in day.get("apps", {}) for day in json.loads(state_path.read_text())["days"].values()), timeout=30)
        self.stop(second)
        self.stop(first)
        self.wait(lambda: self.call("state")["app"] == "")
        self.call("save")
        before = self.call("state")["total"]
        self.stop(self.shell)
        type(self).start_shell()
        after = self.call("state")
        self.assertAlmostEqual(after["total"], before, delta=.1)
        self.assertFalse(after["tracking"])
        apps = self.call("stats", 1)["topApps"]
        self.assertEqual({app["id"] for app in apps}, {"screen-time-first", "screen-time-second"})
        self.assertTrue(all(app["seconds"] >= 1 for app in apps))

    def test_idle_tail_removes_only_recent_accrual_across_apps_and_midnight(self):
        midnight = dt.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        stamp = lambda seconds: (midnight + dt.timedelta(seconds=seconds)).timestamp() * 1000
        self.call("accrue", "historical", stamp(-7200), stamp(-7140))
        self.call("accrue", "first", stamp(-60), stamp(-15))
        self.call("accrue", "second", stamp(-15), stamp(30))
        self.call("rollback", 120, stamp(30))
        days = self.call("state")["days"]
        self.assertAlmostEqual(sum(day["total"] for day in days.values()), 60)
        for day in days.values():
            self.assertAlmostEqual(day["total"], sum(app["seconds"] for app in day["apps"].values()))
            self.assertAlmostEqual(day["total"], sum(day["hourly"]))
            self.assertAlmostEqual(day["total"], sum(sum(hours) for hours in day["appHourly"].values()))
            self.assertTrue(all(app["seconds"] == 0 for app_id, app in day["apps"].items() if app_id != "historical"))

    def test_startup_migrates_legacy_cache_to_state(self):
        self.stop(self.shell)
        state_path = self.lab / "state/hydra/screen-usage.json"
        state_path.unlink(missing_ok=True)
        legacy = self.lab / "cache/hydra/screen-usage.json"
        legacy.parent.mkdir(exist_ok=True)
        key = dt.date.today().isoformat()
        legacy.write_text(json.dumps({"days": {key: {"total": 75, "apps": {"legacy-app": {"name": "Legacy", "seconds": 75}}}}}))
        type(self).start_shell()
        self.wait(lambda: state_path.exists())
        self.assertEqual(self.call("stats", 1)["topApps"][0]["seconds"], 75)
        self.assertEqual(json.loads(state_path.read_text())["days"][key]["total"], 75)

    def test_retention_uses_calendar_age_even_with_sparse_history(self):
        today = dt.date.today()
        kept = (today - dt.timedelta(days=29)).isoformat()
        expired = (today - dt.timedelta(days=30)).isoformat()
        self.call("load", json.dumps({"days": {
            kept: {"total": 10, "apps": {"retained": 10}},
            expired: {"total": 20, "apps": {"expired": 20}}
        }}))
        days = self.call("state")["days"]
        self.assertIn(kept, days)
        self.assertNotIn(expired, days)
        self.assertEqual(self.call("stats", 30)["totalSeconds"], 10)


if __name__ == "__main__":
    unittest.main()
