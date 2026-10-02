import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import umbriel_config as config


class UmbrielConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = patch.dict(os.environ, {'HOME':str(self.root), 'XDG_CONFIG_HOME':str(self.root / 'config')})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.directory = config.config_dir()
        self.directory.mkdir(parents=True)
        self.master = self.directory / 'config.toml'

    def test_multiline_required_optional_includes_preserve_user_config_idempotently(self):
        source = '''# user bytes
[general]
gaps = 7
[include] # keep
files = [
  'personal.toml', # preserve its membership
  'hydra/keybinds.toml',
]
[include.optional]
files = ["absent.toml"]
[output."DP-1"]
scale = 1.25
'''
        result = config.with_includes(source, {'hydra/theme.toml':'hydra/theme.toml'})
        data = tomllib.loads(result)
        self.assertEqual(data['include']['files'], ['personal.toml', 'hydra/keybinds.toml'])
        self.assertEqual(data['include']['optional']['files'], ['absent.toml', 'hydra/theme.toml'])
        self.assertIn("files = [\n  'personal.toml', # preserve its membership", result)
        self.assertEqual(data['general'], {'gaps':7})
        self.assertEqual(data['output']['DP-1']['scale'], 1.25)
        self.assertEqual(result, config.with_includes(result, {'hydra/theme.toml':'hydra/theme.toml'}))

    def test_native_validate_and_atomic_install_without_live_reload(self):
        self.master.write_text('[general]\nfocus_on_activate = true\n[include.optional]\nfiles = ["missing-user.toml"]\n')
        config.commit('visual', config.visual_config(True, ['DP-1','DP-2']), reload=False)
        result = subprocess.run(['umbriel', 'config', 'validate', '-c', str(self.master)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        owned = self.directory / 'hydra/visual.toml'
        first = owned.stat().st_ino
        config.commit('visual', config.visual_config(False, ['DP-1','DP-2']), reload=False)
        self.assertNotEqual(first, owned.stat().st_ino)
        self.assertFalse(tomllib.loads(owned.read_text())['layer_rule'][0]['blur'])
        self.assertEqual(tomllib.loads(self.master.read_text())['general']['focus_on_activate'], True)
        self.assertEqual(list(self.directory.rglob('.candidate-*')), [])

    def test_invalid_candidate_retains_valid_file_master_and_never_reloads(self):
        config.commit('theme', '[colors]\nbackground = "#123456ff"\n', reload=False)
        owned = self.directory / 'hydra/theme.toml'
        before = (owned.read_bytes(), self.master.read_bytes())
        for content in ['[invalid', '[output."DP-1"]\nscale = 99\n']:
            with self.subTest(content=content), self.assertRaises(ValueError):
                config.commit('theme', content, reload=False)
            self.assertEqual((owned.read_bytes(), self.master.read_bytes()), before)
        self.assertEqual(list(self.directory.rglob('.candidate-*')), [])

    def test_blur_matches_only_real_surfaces_enabled_and_disabled(self):
        included = ['hydra-background-DP-1','hydra-popupmenu-DP-2','hydra-dock-DP-1','hydra-notifications-DP-1','hydra-osd-DP-2','hydra-show-keys','hydra-toast-DP-1','hydra-launcher-overlay-DP-2']
        excluded = ['hydra-wallpaper-DP-1','hydra-bar-content-DP-1','hydra-bar-exclusion-top-DP-1','hydra-bar-trigger-DP-1','hydra-desktop-widgets-DP-1','hydra-region-selector','hydra-annotate','hydra-record','hydra-measure','hydra-mirror','hydra-pin','hydra-screen-detector','hydra-fade-overlay','hydra-dock-peek-DP-1','hydra-dock-indicator-DP-1']
        for enabled in (True, False):
            data = tomllib.loads(config.visual_config(enabled, ['DP-1','DP-2']))
            patterns = [re.compile(rule['match']['namespace']) for rule in data['layer_rule']]
            self.assertTrue(all(any(p.fullmatch(name) for p in patterns) for name in included))
            self.assertFalse(any(p.fullmatch(name) for p in patterns for name in excluded))
            self.assertTrue(all(rule['blur'] is enabled for rule in data['layer_rule']))
            rule = data['window_rule'][0]
            self.assertTrue(re.fullmatch(rule['match']['app_id'], 'dev.noctalia.noctalia-qs'))
            self.assertFalse(re.fullmatch(rule['match']['title'], 'Hydra Docs - Firefox'))

    def test_output_fractional_scales_and_transform_native_schema(self):
        outputs = [dict(name=f'DP-{i}', width=1920,height=1080,refresh=59.94,x=i*1920,y=0,scale=scale,transform=str(i),active=True) for i,scale in enumerate([1,1.25,1.5,2])]
        content = config.output_config(outputs)
        config.commit('outputs', content, reload=False)
        parsed = tomllib.loads(content)['output']
        self.assertEqual([parsed[f'DP-{i}']['scale'] for i in range(4)], [1,1.25,1.5,2])
        self.assertEqual(parsed['DP-3']['transform'], '270')
        self.assertEqual(parsed['DP-2']['mode'], '1920x1080@59.94')


if __name__ == '__main__':
    unittest.main()
