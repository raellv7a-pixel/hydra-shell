"""Consumer-visible cache, identity and scanner cancellation regressions."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "launcher_packages.py"
JS = SCRIPT.parents[2] / "Helpers/LauncherPackage.js"
spec = importlib.util.spec_from_file_location("launcher_packages", SCRIPT)
packages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packages)


class PackageCacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cache = self.root / "xdg/hydra/shelly-updates.json"
        self.records = packages.update_records({"Packages": [{"Name": "firefox", "CurrentVersion": "1", "NewVersion": "2"}]})

    def test_cold_warm_and_expired_preserve_badges(self):
        self.assertEqual(packages.load_cache(self.cache, now=10000), {"timestamp": 0, "updates": [], "fresh": False})
        packages.save_cache(self.cache, self.records, 9000)
        warm = packages.load_cache(self.cache, now=10000)
        self.assertTrue(warm["fresh"])
        self.assertEqual(warm["updates"][0]["name"], "firefox")
        expired = packages.load_cache(self.cache, now=10800)
        self.assertFalse(expired["fresh"])
        self.assertEqual(expired["updates"], warm["updates"])

    def test_malformed_future_and_unsafe_cache_are_ignored(self):
        self.cache.parent.mkdir(parents=True)
        for data in ["not-json", json.dumps({"schema": 2}), json.dumps({"schema": True, "timestamp": 9000, "updates": []}), json.dumps({"schema": 1, "timestamp": 11000, "updates": []}),
                     json.dumps({"schema": 1, "timestamp": 9000, "updates": [{"type": "standard", "name": "--root", "aliases": [], "version": "2", "currentVersion": "1"}]})]:
            with self.subTest(data=data):
                self.cache.write_text(data)
                self.assertFalse(packages.load_cache(self.cache, now=10000)["fresh"])
                self.assertEqual(packages.load_cache(self.cache, now=10000)["updates"], [])

    def test_cache_allowlist_does_not_return_commands(self):
        packages.save_cache(self.cache, self.records, 9000)
        data = json.loads(self.cache.read_text())
        data["updates"][0]["command"] = ["untrusted"]
        self.cache.write_text(json.dumps(data))
        self.assertNotIn("command", packages.load_cache(self.cache, now=10000)["updates"][0])

    def test_backend_identity_and_current_target_versions(self):
        records = packages.update_records({"Packages": [], "Aur": [{"Name": "visual-studio-code-bin", "DesktopName": "code.desktop", "CurrentVersion": "1", "NewVersion": "2"}], "Flatpak": [{"Name": "Mozilla Firefox", "ApplicationId": "org.mozilla.firefox", "CurrentVersion": "3", "LatestVersion": "4"}]})
        self.assertEqual(records[0]["type"], "aur")
        self.assertIn("code", records[0]["aliases"])
        self.assertEqual(records[1]["name"], "org.mozilla.firefox")
        self.assertEqual((records[1]["currentVersion"], records[1]["version"]), ("3", "4"))

    def test_invalid_scan_does_not_replace_good_cache(self):
        packages.save_cache(self.cache, self.records, 9000)
        binary = self.root / "shelly"
        binary.write_text("#!/bin/sh\nprintf '%s' '{bad-json}'\n")
        binary.chmod(0o755)
        result = subprocess.run([sys.executable, str(SCRIPT), "scan", str(self.cache)], env=dict(os.environ, PATH=str(self.root)), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(packages.load_cache(self.cache, now=10000)["updates"], self.records)


class NativeOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.user = self.root / "user/applications"
        self.system = self.root / "system/applications"
        self.user.mkdir(parents=True)
        self.system.mkdir(parents=True)

    def test_binary_mismatch_and_multi_desktop_package_use_owner(self):
        files = []
        for filename, owner in [("code.desktop", "visual-studio-code-bin"), ("writer.desktop", "libreoffice-fresh"), ("calc.desktop", "libreoffice-fresh"), ("nvim.desktop", "neovim")]:
            path = self.system / filename
            path.write_text("[Desktop Entry]\n")
            files.append(f"{owner} {path}")
        mapped = packages.native_packages("\n".join(files), {"visual-studio-code-bin": "1.2"}, {"visual-studio-code-bin"}, [self.user, self.system])
        self.assertEqual(mapped["code"], {"name": "visual-studio-code-bin", "type": "aur", "currentVersion": "1.2"})
        self.assertEqual(mapped["writer"]["name"], "libreoffice-fresh")
        self.assertEqual(mapped["calc"]["name"], "libreoffice-fresh")
        self.assertEqual(mapped["nvim"]["name"], "neovim")

    def test_unmanaged_override_does_not_inherit_native_removal(self):
        system = self.system / "code.desktop"
        system.write_text("[Desktop Entry]\n")
        (self.user / "code.desktop").write_text("[Desktop Entry]\nExec=/opt/manual/code\n")
        mapped = packages.native_packages(f"visual-studio-code-bin {system}", {}, set(), [self.user, self.system])
        self.assertNotIn("code", mapped)
        self.assertNotIn("manual", mapped)

    def test_flatpak_installed_versions_and_invalid_rows(self):
        mapped = packages.flatpak_packages("org.mozilla.firefox\t1.2\nnot-an-id\tbad\norg.gnome.TextEditor\t\n")
        self.assertEqual(mapped["org.mozilla.firefox"], {"name": "org.mozilla.firefox", "type": "flatpak", "currentVersion": "1.2"})
        self.assertNotIn("not-an-id", mapped)
        self.assertEqual(mapped["org.gnome.TextEditor"]["currentVersion"], "")


@unittest.skipUnless(shutil.which("node"), "Node required to execute the QML JavaScript helper")
class PackageCommandTests(unittest.TestCase):
    def js(self, expression):
        runner = "const fs=require('fs'),vm=require('vm');const ctx=vm.createContext({});vm.runInContext(fs.readFileSync(process.argv[1],'utf8').replace(/^\\.pragma library\\s*/,''),ctx);console.log(JSON.stringify(vm.runInContext(process.argv[2],ctx)));"
        return json.loads(subprocess.check_output(["node", "-e", runner, str(JS), expression], text=True))

    def test_flatpak_intermediate_options_and_absolute_binary(self):
        commands = [["flatpak", "run", "org.mozilla.firefox"],
                    ["flatpak", "run", "--branch=stable", "--arch=x86_64", "--command=firefox", "org.mozilla.firefox", "%U"],
                    ["/usr/bin/flatpak", "--user", "run", "--command", "org.not.TheApp", "--branch", "stable", "org.mozilla.firefox"],
                    ["flatpak", "run", "--talk-name", "org.not.TheApp", "--file-forwarding", "org.mozilla.firefox"]]
        for command in commands:
            self.assertEqual(self.js(f"flatpakId({json.dumps(command)})"), "org.mozilla.firefox")

    def test_flatpak_missing_invalid_or_option_only_not_removable(self):
        for command in [[], ["flatpak", "run", "--branch=stable"], ["flatpak", "run", "--command", "org.not.TheApp"], ["flatpak", "run", "not-an-app"], ["custom", "run", "org.mozilla.firefox"]]:
            self.assertEqual(self.js(f"flatpakId({json.dumps(command)})"), "")

    def test_update_is_granular_except_explicit_appimage_backend(self):
        for backend, name in [("standard", "firefox"), ("aur", "visual-studio-code-bin"), ("flatpak", "org.mozilla.firefox")]:
            self.assertEqual(self.js(f"updateCommand({json.dumps({'type': backend, 'name': name})})"), ["shelly", "update", backend, name, "--no-confirm"])
        self.assertEqual(self.js("updateCommand({type:'appimage',name:'reader'})"), ["shelly", "upgrade", "appimage", "--no-confirm"])

    def test_ambiguous_alias_does_not_choose_package_or_backend(self):
        records = [{"name": "app", "type": "standard", "aliases": ["desktop"]}, {"name": "app", "type": "appimage", "aliases": ["desktop"]}]
        indexed = self.js(f"indexRecords({json.dumps(records)})")
        self.assertIsNone(indexed["alias:desktop"])
        self.assertEqual(indexed["package:standard:app"]["type"], "standard")


class ScannerCancellationTests(unittest.TestCase):
    def test_cancel_reaps_shelly_group_without_publishing_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "shelly"
            pidfile = root / "backend.pid"
            binary.write_text(f"#!{sys.executable}\nimport os,time,subprocess,pathlib\np=subprocess.Popen([{sys.executable!r},'-c','import time;time.sleep(60)'])\npathlib.Path({str(pidfile)!r}).write_text(str(p.pid))\ntime.sleep(60)\n")
            binary.chmod(0o755)
            cache = root / "cache.json"
            scanner = subprocess.Popen([sys.executable, str(SCRIPT), "scan", str(cache)], env=dict(os.environ, PATH=str(root)), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 5
                while not pidfile.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(pidfile.exists(), "backend never started")
                scanner.send_signal(signal.SIGTERM)
                scanner.communicate(timeout=5)
                self.assertEqual(scanner.returncode, 130)
                self.assertFalse(cache.exists(), "cancelled scan published partial metadata")
                state = Path(f"/proc/{pidfile.read_text()}/stat")
                if state.exists():
                    self.assertEqual(state.read_text().split()[2], "Z", "scanner backend still running")
            finally:
                if scanner.poll() is None:
                    scanner.kill()
                    scanner.communicate()


if __name__ == "__main__":
    unittest.main()
