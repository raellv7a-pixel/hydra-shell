import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from umbriel_actions import catalog


class UmbrielActionsTests(unittest.TestCase):
    def test_official_help_keeps_space_separated_signatures_and_arguments(self):
        help_text = '''Usage: umbriel msg <action> [args...]

Available actions, grouped as the cheatsheet groups them:

Apps
  spawn <cmd...>  Run a command with a launch activation token

Scratchpad
  scratchpad-toggle [<scratchpad>]  Show or hide the selected scratchpad windows

Workspaces
  workspace-switch <workspace> [--output <output>]  Switch to the selected workspace
  workspace-set-layout <scrolling|dwindle|master|stacking|toggle [mode1 mode2 ...]>  Set the active workspace's layout mode

System
  config-reload  Reload the configuration file
'''
        entries = {row['key']: row for row in catalog(help_text)}
        self.assertEqual(set(entries), {'spawn', 'scratchpad-toggle', 'workspace-switch',
                                        'workspace-set-layout', 'config-reload'})
        self.assertEqual(entries['spawn'], {
            'key': 'spawn', 'name': 'Run a command with a launch activation token',
            'category': 'Aplicativos', 'argument': '<cmd...>', 'required': True,
            'signature': 'spawn <cmd...>'})
        self.assertEqual(entries['scratchpad-toggle']['argument'], '[<scratchpad>]')
        self.assertFalse(entries['scratchpad-toggle']['required'])
        self.assertEqual(entries['workspace-switch']['argument'], '<workspace> [--output <output>]')
        self.assertTrue(entries['workspace-switch']['required'])
        self.assertEqual(entries['workspace-set-layout']['signature'],
                         'workspace-set-layout <scrolling|dwindle|master|stacking|toggle [mode1 mode2 ...]>')
        self.assertEqual(entries['config-reload']['argument'], '')
        self.assertFalse(entries['config-reload']['required'])
        self.assertEqual(entries['config-reload']['category'], 'Sistema')

    def test_help_preamble_and_non_action_rows_are_not_catalog_entries(self):
        self.assertEqual(catalog('  spawn <cmd...>  Run a command\n'), [])
        help_text = '''Available actions:
Future group
  window-close  Close a window
  workspace-switch:1  Legacy syntax is not an action name
  --help  Not an action
'''
        self.assertEqual(catalog(help_text), [{
            'key': 'window-close', 'name': 'Close a window', 'category': 'Future group',
            'argument': '', 'required': False, 'signature': 'window-close'}])


if __name__ == '__main__':
    unittest.main()
