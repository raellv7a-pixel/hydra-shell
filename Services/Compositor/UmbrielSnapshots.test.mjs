import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {test} from 'node:test';
const snapshots = vm.createContext({});
vm.runInContext(readFileSync(new URL('./UmbrielSnapshots.js', import.meta.url),'utf8').replace(/^\.pragma library\s*/,''), snapshots);
test('submap snapshots replace active name, including reset to normal context', () => {
  assert.equal(snapshots.submap('resize'),'resize');
  assert.equal(snapshots.submap(null),'');
  assert.equal(snapshots.submap(''),'');
});
test('window snapshots preserve opaque IDs and hidden tab membership', () => {
  const id = 'd933353cc56fc85346b75aea6cd70859';
  const [window] = snapshots.windows([{id, workspace:'opaque', active:true, focused:false, tab_hidden:true, tab_index:2, tabbed:true}], {opaque:{output:'DP-2'}});
  assert.equal(window.id,id);
  assert.equal(window.output,'DP-2');
  assert.equal(window.isActive,true);
  assert.equal(window.tabHidden,true);
  assert.equal(window.tabIndex,2);
});
