import json
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

    def test_provision_preserves_user_config_and_rebind_survives_reload(self):
        binds.MASTER.write_text('[general]\nautostart = ["qs -c hydra-shell -d"]\nshow_cheatsheet = false\n')
        binds.commit(binds.defaults())
        before = binds.MASTER.read_text()
        self.assertIn('show_cheatsheet = false', before)
        self.assertEqual(before.count('"hydra/keybinds.toml"'), 1)
        state = binds.current_state()
        state['rebinds']['shell.launcher'] = 'Mod+Y'
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
        state['rebinds']['window.close'] = 'Super+Space'
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
        state['rebinds']['window.close'] = 'Mod+Y'
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


if __name__ == '__main__':
    unittest.main()
