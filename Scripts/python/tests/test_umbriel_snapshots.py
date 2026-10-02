import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


class UmbrielSnapshotsTests(unittest.TestCase):
    def js(self, expression):
        script = '''const fs = require('fs'), vm = require('vm');
const api = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8').replace(/^\\.pragma library\\n/, ''), api);
console.log(JSON.stringify(vm.runInContext(process.argv[2], api)));'''
        return json.loads(subprocess.check_output([
            'node', '-e', script, str(ROOT / 'Services/Compositor/UmbrielSnapshots.js'), expression
        ], text=True))

    def test_empty_focused_workspace_wins_over_window_and_snapshots_replace_focus(self):
        result = self.js('''const first = workspaces([
          {id:'DP-1:9', index:1, name:'1', output:'DP-1', focused:false, occupied:true, active:true},
          {id:'DP-2:5', index:1, name:'1', output:'DP-2', focused:true, occupied:false, active:true}]);
          const next = workspaces([{id:'DP-1:9', index:1, output:'DP-1', focused:true}]);
          [first.map(w => w.id), focusedOutput(first), focusedOutput(next), focusedOutput([]),
           workspaceSelector(first[1]), workspaceSelector({named:true,name:'web',output:'DP-2'})]''')
        self.assertEqual(result, [['DP-1:9', 'DP-2:5'], 'DP-2', 'DP-1', '', '1/DP-2', 'web/DP-2'])

    def test_windows_use_opaque_workspace_and_global_active_not_local_focus(self):
        result = self.js('''windows([
          {id:'a',workspace:'DP-1:8',app_id:'kitty',focused:true,active:false},
          {id:'b',workspace:'DP-2:1',app_id:'kitty',focused:true,active:true,x:10,y:20,w:30,h:40},
          {id:'c',workspace:'',scratchpad:'hydra-edge-browser',active:false}
        ], {'DP-1:8':{output:'DP-1'},'DP-2:1':{output:'DP-2'}})''')
        self.assertEqual([w['workspaceId'] for w in result], ['DP-1:8', 'DP-2:1', ''])
        self.assertEqual([w['isFocused'] for w in result], [False, True, False])
        self.assertEqual(result[1]['position'], {'x':10,'y':20})
        self.assertEqual(result[2]['scratchpad'], 'hydra-edge-browser')
        self.assertEqual(result[2]['output'], '')

    def test_keyboard_initial_change_and_absent_layout(self):
        self.assertEqual(self.js("[keyboardLayout({names:['English (US)','Portuguese (Brazil)'],current_index:1}), keyboardLayout({names:['English (US)'],current_index:0}),keyboardLayout({names:[],current_index:0})]"), ['Portuguese (Brazil)', 'English (US)', ''])

    def test_outputs_keep_fractional_scale_modes_and_missing_fields(self):
        result = self.js("outputs([1,1.25,1.5,2].map((scale,i)=>({name:'DP-'+i,scale,enabled:true,position:{x:i*100,y:0},modes:[{current:true,width:1920,height:1080,refresh_mhz:59940}]})).concat([{name:'off',enabled:false}]))")
        self.assertEqual([o['scale'] for o in result[:4]], [1,1.25,1.5,2])
        self.assertEqual(result[2]['refresh'], 59.94)
        self.assertEqual(result[3]['width'], 1920)
        self.assertNotIn('scale', result[4])
        self.assertNotIn('width', result[4])


if __name__ == '__main__':
    unittest.main()
