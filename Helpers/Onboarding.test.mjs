import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const context = vm.createContext({});
vm.runInContext(readFileSync(new URL("./Onboarding.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, ""), context);
const version = context.versionForSettings;

test("fresh defaults stay pending even after settings exists", () => {
  assert.equal(version(null, true, 1), 0);
  assert.equal(version({ onboardingVersion: 0 }, false, 1), 0);
});
test("valid legacy installation is not forced through onboarding", () => {
  assert.equal(version({ settingsVersion: 61, colorSchemes: { materialSpec: "2021" } }, false, 1), 1);
});
test("completion survives restart and future versions are not downgraded", () => {
  assert.equal(version({ onboardingVersion: 1 }, false, 1), 1);
  assert.equal(version({ onboardingVersion: 3 }, false, 1), 3);
});
test("invalid completion does not silently count as finished", () => {
  for (const value of [-1, "1", null, 1.5])
    assert.equal(version({ onboardingVersion: value }, false, 1), 0);
  assert.equal(version(null, false, 1), 0);
  assert.equal(version([], false, 1), 0);
});
