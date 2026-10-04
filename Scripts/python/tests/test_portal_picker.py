import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import hydra_share_picker as bridge
import portal_picker_config as config


class PickerContractTests(unittest.TestCase):
    def setUp(self):
        self.request = {'multiple': False, 'types': ['monitor', 'window'],
                        'outputs': [{'name': 'DP-1'}], 'windows': [{'identifier': 'opaque-window-id'}]}

    def test_source_identity_and_single_selection_are_enforced(self):
        monitor = {'kind': 'monitor', 'output': 'DP-1'}
        window = {'kind': 'window', 'identifier': 'opaque-window-id'}
        self.assertEqual(bridge.validate_response(self.request, {'selections': [window]}), {'selections': [window]})
        for rows in ([monitor, window], [{'kind': 'monitor', 'output': 'missing'}], [window, window]):
            with self.assertRaises(ValueError):
                bridge.validate_response(self.request, {'selections': rows})
        self.request['multiple'] = True
        self.assertEqual(bridge.validate_response(self.request, {'selections': [monitor, window]}), {'selections': [monitor, window]})
        with self.assertRaises(ValueError):
            bridge.validate_response(self.request, {'selections': [window, window]})
        self.request['types'] = ['monitor']
        with self.assertRaises(ValueError):
            bridge.validate_response(self.request, {'selections': [window]})


class FallbackCancellationTests(unittest.TestCase):
    def test_cancellation_reaps_owned_picker_without_signalling_other_processes(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            stopped = directory / 'stopped'
            picker = directory / 'picker'
            picker.write_text(
                '#!' + sys.executable + '\n'
                'import signal, sys\n'
                'from pathlib import Path\n'
                'def stop(*args):\n'
                f'    Path({str(stopped)!r}).write_text("terminated")\n'
                '    sys.exit(0)\n'
                'signal.signal(signal.SIGTERM, stop)\n'
                'sys.stdin.buffer.read()\n'
                'print("picker-ready", flush=True)\n'
                'signal.pause()\n')
            picker.chmod(0o700)
            other = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
            helper = subprocess.Popen(
                [sys.executable, '-c',
                 'import signal, sys; import hydra_share_picker as bridge; '
                 'signal.signal(signal.SIGTERM, lambda *_: sys.exit(1)); '
                 f'bridge.official_picker = lambda: {str(picker)!r}; '
                 'bridge.fallback(b"request")'],
                cwd=Path(bridge.__file__).parent,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                with selectors.DefaultSelector() as ready:
                    ready.register(helper.stdout, selectors.EVENT_READ)
                    self.assertTrue(ready.select(timeout=5), 'Picker never became ready')
                self.assertEqual(helper.stdout.readline().strip(), 'picker-ready')
                helper.terminate()
                helper.communicate(timeout=4)
                self.assertEqual(helper.returncode, 1)
                self.assertEqual(stopped.read_text(), 'terminated')
                self.assertIsNone(other.poll())
            finally:
                # These Popen handles are the only signal targets owned by this test.
                for process in (helper, other):
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                helper.stdout.close()
                helper.stderr.close()


class PortalOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.environment = patch.dict(os.environ, {'XDG_CONFIG_HOME': self.temporary.name + '/config',
                                                   'XDG_STATE_HOME': self.temporary.name + '/state'})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.path, self.record = config.paths()
        self.path.parent.mkdir(parents=True)
        self.original = '# Personal portal settings\n[screencast]\nmax_fps = 30 # Keep this\nchooser_cmd = "custom-picker --safe" # My chooser\n[screenshot]\ncmd = "capture"\n'
        self.path.write_text(self.original)
        self.fallback = patch.object(config, 'official_picker', return_value='/official/picker')
        self.fallback.start()
        self.addCleanup(self.fallback.stop)

    def test_enable_disable_preserve_previous_command_and_comments(self):
        enabled = config.set_enabled(True, config.snapshot()[0]['revision'])
        self.assertTrue(enabled['enabled'])
        self.assertIn('max_fps = 30 # Keep this', self.path.read_text())
        self.assertIn('# My chooser', self.path.read_text())
        self.assertIn('cmd = "capture"', self.path.read_text())
        config.set_enabled(False, enabled['revision'])
        self.assertEqual(self.path.read_text(), self.original)
        self.assertFalse(self.record.exists())

    def test_external_change_and_stale_revision_never_overwrite(self):
        enabled = config.set_enabled(True, config.snapshot()[0]['revision'])
        self.path.write_text(self.original.replace('custom-picker --safe', 'external-picker'))
        external = self.path.read_bytes()
        with self.assertRaises(ValueError):
            config.set_enabled(False, enabled['revision'])
        with self.assertRaises(ValueError):
            config.set_enabled(False, config.snapshot()[0]['revision'])
        self.assertEqual(self.path.read_bytes(), external)

    def test_missing_key_is_removed_without_touching_other_fields(self):
        self.path.write_text('[screencast]\nmax_fps = 25\n')
        enabled = config.set_enabled(True, config.snapshot()[0]['revision'])
        config.set_enabled(False, enabled['revision'])
        self.assertEqual(self.path.read_text(), '[screencast]\nmax_fps = 25\n')

    def test_dotted_key_is_reversible(self):
        original = 'screencast.chooser_cmd = "my-picker" # external\n[screenshot]\ncmd = "my-shot"\n'
        self.path.write_text(original)
        enabled = config.set_enabled(True, config.snapshot()[0]['revision'])
        config.set_enabled(False, enabled['revision'])
        self.assertEqual(self.path.read_text(), original)


if __name__ == '__main__':
    unittest.main()
