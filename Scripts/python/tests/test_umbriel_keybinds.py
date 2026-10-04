import json
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import umbriel_keybinds as binds


class UmbrielKeybindsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.config_dir = Path(self.directory.name) / "umbriel"
        self.config_dir.mkdir()
        for name, path in (("CONFIG_DIR", self.config_dir), ("MASTER", self.config_dir / "config.toml"),
                           ("OWNED", self.config_dir / "hydra" / "keybinds.toml"),
                           ("STATE", self.config_dir / "hydra" / "keybinds.json")):
            replacing = patch.object(binds, name, path)
            replacing.start()
            self.addCleanup(replacing.stop)
        real_run = subprocess.run
        def validate_only(command, *args, **kwargs):
            if command[:3] == ["umbriel", "msg", "config-reload"]:
                return subprocess.CompletedProcess(command, 0, "", "")
            return real_run(command, *args, **kwargs)
        reload_patch = patch.object(binds.subprocess, "run", side_effect=validate_only)
        reload_patch.start()
        self.addCleanup(reload_patch.stop)

    def test_switcher_default_defers_to_existing_custom_chord(self):
        state = binds.defaults()
        custom = dict(label='Alternador pessoal', chord='alt+tab', type='command', action='kitty')
        state['custom'].append(custom)
        state['overrides']['shell.launcher'] = {'chord': 'Mod+Y'}
        binds.commit(state)
        rendered = binds.OWNED.read_text()
        self.assertIn('"Alt+Tab" = { action = "spawn:kitty"', rendered)
        self.assertNotIn('ipc call windowSwitcher hold",', rendered)
        self.assertIn('scratchpad-focus-next:hydra-default', rendered)
        self.assertEqual(binds.current_state(), state)
        state['custom'].clear()
        binds.commit(state)
        self.assertIn('"Alt+Tab" = { action = "spawn:qs -c hydra-shell ipc call windowSwitcher hold"', binds.OWNED.read_text())

    def test_switcher_default_preserves_rebound_catalog_action_and_reverse_chord(self):
        state = binds.defaults()
        state['overrides']['app.terminal'] = {'chord': 'Alt+Tab', 'action': 'alacritty'}
        state['custom'].append(dict(label='Anterior pessoal', chord='shift+alt+tab', type='umbriel', action='window-focus-last'))
        binds.commit(state)
        text = binds.OWNED.read_text()
        self.assertIn('"Alt+Tab" = { action = "spawn:alacritty"', text)
        self.assertIn('"Alt+Shift+Tab" = { action = "window-focus-last"', text)
        self.assertNotIn('ipc call windowSwitcher', text)
        self.assertEqual(binds.current_state(), state)

    def test_provision_preserves_user_config_and_rebind_survives_reload(self):
        binds.MASTER.write_text('[general]\nautostart = ["qs -c hydra-shell -d"]\nshow_cheatsheet = false\n')
        binds.commit(binds.defaults())
        before = binds.MASTER.read_text()
        self.assertIn('show_cheatsheet = false', before)
        self.assertEqual(before.count('"hydra/keybinds.toml"'), 1)
        state = binds.current_state()
        state['overrides']['shell.launcher'] = {'chord': 'Mod+Y'}
        state['custom'].append(dict(label='Ação local', chord='Mod+Alt+Y', type='umbriel', action='overview-toggle'))
        binds.commit(state)
        self.assertEqual(binds.MASTER.read_text(), before)
        self.assertEqual(binds.current_state(), state)
        self.assertIn('"Mod+Y" = { action = "spawn:qs -c hydra-shell ipc call launcher toggle"', binds.OWNED.read_text())
        self.assertIn('"Mod+Alt+Y" = { action = "overview-toggle"', binds.OWNED.read_text())

    def test_rejects_conflicts_and_invalid_actions_without_replacing_good_file(self):
        binds.commit(binds.defaults())
        original = binds.OWNED.read_bytes()
        state = binds.defaults()
        state['overrides']['window.close'] = {'chord': 'Super+Space'}
        with self.assertRaisesRegex(ValueError, 'Conflito'):
            binds.commit(state)
        self.assertEqual(binds.OWNED.read_bytes(), original)
        state = binds.defaults()
        state['custom'].append(dict(label='Quebrado', chord='Mod+Y', type='umbriel', action='not-an-action'))
        with self.assertRaisesRegex(ValueError, 'unknown action'):
            binds.commit(state)
        self.assertEqual(binds.OWNED.read_bytes(), original)
        state = binds.defaults()
        state['custom'].append(dict(label='Mídia duplicada', chord='xf86audioplay',
                                    type='hydra', action='media playPause'))
        with self.assertRaisesRegex(ValueError, 'Conflito'):
            binds.commit(state)
        self.assertEqual(binds.OWNED.read_bytes(), original)
        state = binds.defaults()
        state['custom'] = [
            dict(label='Primeira', chord='Shift+Ctrl+F12', type='umbriel', action='overview-toggle'),
            dict(label='Segunda', chord='ctrl+shift+f12', type='command', action='kitty'),
        ]
        with self.assertRaisesRegex(ValueError, 'Primeira / Segunda'):
            binds.commit(state)
        self.assertEqual(binds.OWNED.read_bytes(), original)

    def test_restore_defaults_and_existing_include(self):
        binds.MASTER.write_text('[include]\nfiles = ["another.toml"]\n\n[general]\nshow_cheatsheet = false\n')
        (self.config_dir / 'another.toml').write_text('[appearance.blur]\nradius = 3\n')
        binds.commit(binds.defaults())
        before = binds.MASTER.read_text()
        self.assertIn('"another.toml", "hydra/keybinds.toml"', before)
        state = binds.defaults()
        state['overrides']['window.close'] = {'chord': 'Mod+Y'}
        binds.commit(state)
        binds.commit(binds.defaults())
        self.assertEqual(binds.current_state(), binds.defaults())
        self.assertEqual(binds.MASTER.read_text(), before)
        self.assertIn('"Mod+Q"', binds.OWNED.read_text())

    def test_existing_session_autostart_is_extended_once(self):
        binds.MASTER.write_text('[general]\nautostart = ["notify-send ready"]\n'
                                'show_cheatsheet = false\n')
        binds.commit(binds.defaults())
        binds.commit(binds.defaults())
        master = binds.MASTER.read_text()
        self.assertEqual(master.count("qs -c hydra-shell -d"), 1)
        self.assertIn('"notify-send ready"', master)
        self.assertIn('show_cheatsheet = false', master)

    def test_existing_empty_keybind_table_cannot_override_hydra(self):
        binds.MASTER.write_text('[keybinds]\n')
        with self.assertRaisesRegex(ValueError, "já define"):
            binds.commit(binds.defaults())
        self.assertEqual(binds.MASTER.read_text(), '[keybinds]\n')


    def test_v1_migration_preserves_rebind_and_custom_actions(self):
        old = {'version': 1, 'rebinds': {'app.files': 'Mod+D'},
               'custom': [{'label': 'Visão', 'chord': 'Mod+Alt+Y',
                           'type': 'umbriel', 'action': 'overview-toggle'}]}
        binds.STATE.parent.mkdir(parents=True)
        binds.STATE.write_text(json.dumps(old))
        migrated = binds.current_state()
        self.assertEqual(migrated['overrides']['app.files'], {'chord': 'Mod+D'})
        self.assertEqual(migrated['custom'], old['custom'])
        binds.commit(migrated)
        self.assertEqual(json.loads(binds.STATE.read_text())['version'], 2)
        self.assertIn('\"Mod+D\" = { action = \"spawn:xdg-open ~\"', binds.OWNED.read_text())

    def test_catalog_action_and_options_can_be_overridden_and_restored(self):
        original = binds.generate(binds.defaults())
        state = binds.defaults()
        state['overrides']['app.files'] = {'type': 'command', 'action': 'gtk-launch org.kde.dolphin.desktop',
                                          'repeat': True, 'cooldown_ms': 250}
        binds.commit(state)
        self.assertIn('spawn:gtk-launch org.kde.dolphin.desktop', binds.OWNED.read_text())
        self.assertIn('repeat = true', binds.OWNED.read_text())
        self.assertIn('cooldown_ms = 250', binds.OWNED.read_text())
        state['overrides'].pop('app.files')
        binds.commit(state)
        self.assertEqual(binds.OWNED.read_text(), original)

    def test_official_bind_can_change_type_action_and_permission_flags(self):
        state = binds.defaults()
        state['overrides']['app.files'] = {
            'type': 'umbriel', 'action': 'overview-toggle',
            'allow_when_inhibited': True, 'allow_when_locked': True}
        binds.commit(state)
        rendered = binds.OWNED.read_text()
        self.assertIn('"Mod+E" = { action = "overview-toggle"', rendered)
        self.assertIn('allow_when_locked = true', rendered)
        self.assertIn('allow_when_inhibited = true', rendered)
        self.assertEqual(binds.current_state(), state)

    def test_catalog_override_conflict_and_invalid_action_do_not_modify_files(self):
        binds.commit(binds.defaults())
        original = binds.OWNED.read_bytes()
        for override in ({'chord': 'Mod+Space'}, {'action': ''},
                         {'type': 'umbriel', 'action': 'overview-toggle:'}):
            state = binds.defaults()
            state['overrides']['app.files'] = override
            with self.assertRaises(ValueError):
                binds.commit(state)
            self.assertEqual(binds.OWNED.read_bytes(), original)

    def test_edge_scratchpads_survive_v2_overrides(self):
        state = binds.defaults()
        state['overrides']['app.files'] = {'action': 'gtk-launch org.kde.dolphin.desktop'}
        binds.commit(state, edge_apps=['org.kde.dolphin.desktop', 'org.kde.dolphin.desktop'])
        text = binds.OWNED.read_text()
        self.assertEqual(text.count('name = \"hydra-default\"'), 1)
        self.assertEqual(text.count('name = \"hydra-edge-org-kde-dolphin\"'), 1)
        self.assertIn('spawn:gtk-launch org.kde.dolphin.desktop', text)

    def test_external_keybind_include_blocks_override_without_changes(self):
        personal = self.config_dir / 'personal.toml'
        personal.write_text('[keybinds]\n"Mod+Y" = { action = "overview-toggle" }\n')
        binds.MASTER.write_text('[include]\nfiles = ["personal.toml"]\n')
        original = binds.MASTER.read_bytes()
        with self.assertRaisesRegex(ValueError, 'controlados externamente'):
            binds.commit(binds.defaults())
        self.assertEqual(binds.MASTER.read_bytes(), original)
        self.assertFalse(binds.OWNED.exists())

    def test_external_state_change_between_load_and_save_is_preserved(self):
        initial = binds.defaults()
        binds.commit(initial)
        changed = binds.defaults()
        changed['overrides']['app.files'] = {'chord': 'Mod+D'}
        binds.commit(changed)
        original = binds.STATE.read_bytes()
        new = binds.defaults()
        new['overrides']['app.files'] = {'action': 'gtk-launch org.kde.dolphin.desktop'}
        with self.assertRaisesRegex(ValueError, 'mudaram desde a leitura'):
            binds.commit(new, expected_state=initial)
        self.assertEqual(binds.STATE.read_bytes(), original)
        self.assertEqual(binds.current_state(), changed)

    def test_reload_failure_restores_keybinds_state_and_master(self):
        binds.commit(binds.defaults())
        previous = (binds.MASTER.read_bytes(), binds.OWNED.read_bytes(), binds.STATE.read_bytes())
        change = binds.defaults()
        change['overrides']['app.files'] = {'action': 'gtk-launch org.kde.dolphin'}
        real_run = binds.subprocess.run
        def fail_reload(command, *args, **kwargs):
            if command[:3] == ['umbriel', 'msg', 'config-reload']:
                return subprocess.CompletedProcess(command, 1, '', 'reload refused')
            return real_run(command, *args, **kwargs)
        with patch.object(binds.subprocess, 'run', side_effect=fail_reload):
            with self.assertRaisesRegex(ValueError, 'reload refused'):
                binds.commit(change)
        self.assertEqual((binds.MASTER.read_bytes(), binds.OWNED.read_bytes(), binds.STATE.read_bytes()),
                         previous)

if __name__ == '__main__':
    unittest.main()
