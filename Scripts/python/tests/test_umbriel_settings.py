import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import umbriel_config
import umbriel_settings


class UmbrielSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / 'umbriel'
        self.directory.mkdir()
        patched = patch.object(umbriel_config, 'config_dir', return_value=self.directory)
        patched.start()
        self.addCleanup(patched.stop)
        real_run = subprocess.run
        def validate_only(command, *args, **kwargs):
            if command[:3] == ['umbriel', 'msg', 'config-reload']:
                return subprocess.CompletedProcess(command, 0, '', '')
            return real_run(command, *args, **kwargs)
        reload_patch = patch.object(umbriel_config.subprocess, 'run', side_effect=validate_only)
        reload_patch.start()
        self.addCleanup(reload_patch.stop)

    def test_overview_and_corners_save_reload_with_user_master_intact(self):
        master = self.directory / 'config.toml'
        master.write_text('[general]\nshow_cheatsheet = false\n')
        state = umbriel_settings.defaults()
        state['overview']['zoom'] = 0.65
        state['hot_corners']['top_left'] = {'enabled': True, 'delay_ms': 250,
                                              'action': 'overview-toggle'}
        umbriel_config.commit('settings', umbriel_settings.generate(state))
        self.assertEqual(umbriel_settings.current()['state'], state)
        self.assertEqual(umbriel_settings.current()['owners'], [])
        self.assertIn('show_cheatsheet = false', master.read_text())
        self.assertIn('hydra/settings.toml', master.read_text())
        stored = tomllib.loads((self.directory / 'hydra' / 'settings.toml').read_text())
        self.assertEqual(stored['hot_corners']['top_left']['action'], 'overview-toggle')

    def test_parameterized_action_uses_installed_umbriel_parser(self):
        state = umbriel_settings.defaults()
        state['hot_corners']['bottom_right'] = {
            'enabled': True, 'delay_ms': 0, 'action': 'spawn:kitty -e htop'}
        umbriel_config.commit('settings', umbriel_settings.generate(state))
        self.assertEqual(umbriel_settings.current()['state']['hot_corners']['bottom_right']['action'],
                         'spawn:kitty -e htop')

    def test_external_ownership_blocks_save_without_modifying_user_config(self):
        master = self.directory / 'config.toml'
        personal = self.directory / 'personal.toml'
        personal.write_text('[hot_corners.top_right]\nenabled = true\naction = "overview-toggle"\n')
        master.write_text('[include]\nfiles = ["personal.toml"]\n\n[general]\nshow_cheatsheet = false\n')
        original = master.read_bytes()
        self.assertIn('personal.toml', str(umbriel_settings.current()['owners']))
        with self.assertRaisesRegex(ValueError, 'controlada externamente'):
            umbriel_config.commit('settings', umbriel_settings.generate(umbriel_settings.defaults()))
        self.assertEqual(master.read_bytes(), original)
        self.assertFalse((self.directory / 'hydra' / 'settings.toml').exists())

    def test_screencast_external_ownership_preserves_native_confirmation(self):
        master = self.directory / 'config.toml'
        original = '[screencast]\ndisable_dynamic_confirmation = false # native protection\n'
        master.write_text(original)
        update = umbriel_settings.defaults()
        update['screencast']['disable_dynamic_confirmation'] = True
        with self.assertRaisesRegex(ValueError, 'controlada externamente'):
            umbriel_config.commit('settings', umbriel_settings.generate(update))
        self.assertEqual(master.read_text(), original)
        self.assertFalse((self.directory / 'hydra' / 'settings.toml').exists())

    def test_invalid_values_and_incomplete_actions_are_rejected(self):
        for section, key, value in [('overview', 'zoom', 0.01),
                                    ('overview', 'shortcut_keys', 'Aa'),
                                    ('hot_corners.top_left', 'delay_ms', 10001),
                                    ('hot_corners.top_left', 'action', 'workspace-switch:')]:
            state = copy.deepcopy(umbriel_settings.defaults())
            if section.startswith('hot_corners.'):
                state['hot_corners'][section.split('.')[1]][key] = value
            else:
                state[section][key] = value
            with self.assertRaises(ValueError):
                umbriel_settings.generate(state)
        state = umbriel_settings.defaults()
        state['hot_corners']['top_left']['enabled'] = True
        with self.assertRaisesRegex(ValueError, 'Ação inválida'):
            umbriel_settings.generate(state)

    def test_reload_failure_restores_owned_settings_and_master(self):
        original = umbriel_settings.defaults()
        umbriel_config.commit('settings', umbriel_settings.generate(original))
        master = self.directory / 'config.toml'
        owned = self.directory / 'hydra' / 'settings.toml'
        before = (master.read_bytes(), owned.read_bytes())
        update = copy.deepcopy(original)
        update['overview']['zoom'] = 0.7
        real_run = umbriel_config.subprocess.run
        def fail_reload(command, *args, **kwargs):
            if command[:3] == ['umbriel', 'msg', 'config-reload']:
                return subprocess.CompletedProcess(command, 1, '', 'reload refused')
            return real_run(command, *args, **kwargs)
        with patch.object(umbriel_config.subprocess, 'run', side_effect=fail_reload):
            with self.assertRaisesRegex(ValueError, 'reload refused'):
                umbriel_config.commit('settings', umbriel_settings.generate(update))
        self.assertEqual((master.read_bytes(), owned.read_bytes()), before)
        self.assertEqual(umbriel_settings.current()['state'], original)

    def test_external_include_change_during_validation_aborts_without_install(self):
        master = self.directory / 'config.toml'
        master.write_text('[include]\nfiles = ["personal.toml"]\n')
        personal = self.directory / 'personal.toml'
        personal.write_text('[general]\nshow_cheatsheet = false\n')
        original = master.read_bytes()
        run = umbriel_config.subprocess.run
        def change_during_validate(command, *args, **kwargs):
            result = run(command, *args, **kwargs)
            if command[:3] == ['umbriel', 'config', 'validate']:
                personal.write_text('[general]\nshow_cheatsheet = true\n')
            return result
        with patch.object(umbriel_config.subprocess, 'run', side_effect=change_during_validate):
            with self.assertRaisesRegex(ValueError, 'alterado durante'):
                umbriel_config.commit('settings', umbriel_settings.generate(umbriel_settings.defaults()))
        self.assertEqual(master.read_bytes(), original)
        self.assertFalse((self.directory / 'hydra' / 'settings.toml').exists())

    def test_stale_snapshot_cannot_overwrite_externally_changed_owned_file(self):
        initial = umbriel_settings.defaults()
        umbriel_config.commit('settings', umbriel_settings.generate(initial))
        stale_revision = umbriel_settings.current()['revision']
        changed = copy.deepcopy(initial)
        changed['overview']['zoom'] = 0.6
        umbriel_config.commit('settings', umbriel_settings.generate(changed))
        owned = self.directory / 'hydra' / 'settings.toml'
        original = owned.read_bytes()
        stale_edit = copy.deepcopy(initial)
        stale_edit['overview']['zoom'] = 0.7
        with self.assertRaisesRegex(ValueError, 'mudou desde a leitura'):
            umbriel_config.commit('settings', umbriel_settings.generate(stale_edit),
                                  expected_revision=stale_revision)
        self.assertEqual(owned.read_bytes(), original)
        self.assertEqual(umbriel_settings.current()['state'], changed)


if __name__ == '__main__':
    unittest.main()
