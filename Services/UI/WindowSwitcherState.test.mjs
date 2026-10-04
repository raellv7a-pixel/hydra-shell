import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {test} from 'node:test';
const state = vm.createContext({Set, Map});
vm.runInContext(readFileSync(new URL('./WindowSwitcherState.js', import.meta.url), 'utf8').replace(/^\.pragma library\s*/, ''), state);
const plain = value => JSON.parse(JSON.stringify(value));
const windows = [
  {id:'A', output:'DP-1', workspaceId:'one'},
  {id:'B', output:'DP-1', workspaceId:'two'},
  {id:'C', output:'DP-2', workspaceId:'three'},
  {id:'scratch', output:'DP-1', workspaceId:'one', scratchpad:'hydra-edge-app'},
  {id:'tab', output:'DP-1', workspaceId:'one', tabHidden:true},
  {id:'unmapped', output:'DP-1', workspaceId:'one', mapped:false}
];
const options = {showAllOutputs:true, currentWorkspaceOnly:false, mru:true};
test('MRU promotes actual focus, deduplicates and purges closed IDs', () => {
  let ids = [];
  for (const id of ['A','B','C','B']) ids = state.history(ids, windows, id);
  assert.deepEqual(plain(ids), ['B','C','A']);
  assert.deepEqual(plain(state.history([...ids,'A','dead'], windows.filter(w => w.id !== 'C'), '')), ['B','A']);
});
test('membership excludes scratchpads, hidden tabs and unmapped surfaces, not missing app IDs', () => {
  assert.deepEqual(plain(state.candidates(windows, options, 'DP-1', 'one', ['B','A','C'])).map(w=>w.id), ['B','A','C']);
  assert.deepEqual(plain(state.candidates(windows, {...options, showAllOutputs:false}, 'DP-1', 'one', [])).map(w=>w.id), ['A','B']);
  assert.deepEqual(plain(state.candidates(windows, {...options, currentWorkspaceOnly:true}, 'DP-1', 'one', [])).map(w=>w.id), ['A']);
});
test('initial selection advances relative to focused ID in either ordering', () => {
  assert.equal(state.initial(windows.slice(0,3), 'B', 1), 2);
  assert.equal(state.initial(windows.slice(0,3), 'A', -1), 2);
  assert.equal(state.initial([], 'A', 1), -1);
  assert.equal(state.cycle(2,3,1),0);
  assert.equal(state.cycle(0,3,-1),2);
});
test('live refresh preserves selected ID or clamps after its removal', () => {
  assert.equal(state.reconcile([windows[2],windows[0]],'A',1),1);
  assert.equal(state.reconcile([windows[0]],'B',2),0);
  assert.equal(state.reconcile([],'B',2),-1);
});
test('quick tap and release confirm; Shift release does not own hold lifetime', () => {
  assert.equal(state.release(0,0,8),true);
  assert.equal(state.release(8,8,8),false);
  assert.equal(state.release(8,0,8),true);
  assert.equal(state.release(12,8,8),true);
});
