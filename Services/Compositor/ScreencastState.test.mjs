import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {test} from 'node:test';
const state = vm.createContext({});
vm.runInContext(readFileSync(new URL('./ScreencastState.js', import.meta.url), 'utf8').replace(/^\.pragma library\s*/, ''), state);
test('commands retain opaque identity but never invent an initial sharing session', () => {
  let current = state.reduce(state.empty(), {serial: 0, kind: 'clear'});
  assert.equal(current.mode, 'unknown');
  current = state.reduce(current, {serial: 1, kind: 'window', identifier: 'opaque'});
  assert.equal(current.targetValue, 'opaque');
  assert.equal(current.mode, 'manual');
  assert.equal(state.reduce(current, {serial: 1, kind: 'clear'}), current);
  assert.equal(state.reduce(current, {serial: 0, kind: 'clear'}), current);
  assert.equal(state.reduce(current, {serial: 2, kind: 'window', identifier: 7}), current);
});
test('follow, stop and clear do not falsely preserve the prior manual target', () => {
  let current = state.reduce(state.empty(), {serial: 1, kind: 'output', output: 'DP-1'});
  current = state.reduce(current, {serial: 2, kind: 'follow_window'});
  assert.equal(current.mode, 'follow-window');
  assert.equal(current.targetValue, '');
  current = state.reduce(current, {serial: 3, kind: 'follow_stop'});
  assert.equal(current.mode, 'manual');
  assert.equal(current.targetKind, 'none');
  current = state.reduce(current, {serial: 4, kind: 'clear'});
  assert.equal(current.mode, 'cleared');
  assert.equal(current.targetValue, '');
});
