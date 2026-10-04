import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {test} from 'node:test';
const chords = vm.createContext({});
vm.runInContext(readFileSync(new URL('./Chords.js',import.meta.url),'utf8').replace(/^\.pragma library\s*/,''),chords);
test('existing personal Alt+Tab hides only the unclaimed default, not other choices',()=>{
  const rows=[{id:'shell.switcher',chord:'Alt+Tab'},{id:'shell.switcher.previous',chord:'Alt+Shift+Tab'},{id:'custom.0',chord:'alt+tab'}];
  const adopted=chords.adoptSwitcherDefaults(rows,{});
  assert.deepEqual(Array.from(adopted,row=>row.id),['shell.switcher.previous','custom.0']);
  assert.deepEqual(Object.keys(chords.conflicts(adopted)),[]);
  const explicit=chords.adoptSwitcherDefaults(rows,{'shell.switcher':{action:'windowSwitcher open'}});
  assert.deepEqual(Object.keys(chords.conflicts(explicit)).sort(),['custom.0','shell.switcher']);
});
