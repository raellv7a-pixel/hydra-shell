pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  readonly property int decayIntervalMs: 30000

  property bool initialized: false
  property real hunger: 100
  property real happiness: 100
  property real cleanliness: 100
  property real energy: 100
  property bool sleeping: false
  property bool eating: false
  property double lastDecayTimestamp: 0
  property string lastInteraction: ""

  readonly property bool isDirty: cleanliness < 20
  readonly property real lowestNeed: Math.min(hunger, happiness, cleanliness, energy)
  readonly property string petState: {
    if (sleeping)
      return "sleeping";
    const sad = happiness < 30;
    const tired = energy < 30;
    const hungry = hunger < 20;
    if (sad && tired && hungry)
      return "angry";
    if (hungry)
      return "hungry";
    if (sad)
      return "sad";
    if (tired)
      return "tired";
    return "idle";
  }

  signal interactionCompleted(string action)

  function clampNeed(value) {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? Math.max(0, Math.min(100, numeric)) : 100;
  }

  function roundedNeed(value) {
    return Math.round(clampNeed(value) * 1000) / 1000;
  }

  function initializeFromSettings() {
    if (!Settings.isLoaded)
      return;

    decayTimer.stop();
    const state = Settings.data.tamagotchi;
    hunger = clampNeed(state.hunger);
    happiness = clampNeed(state.happiness);
    cleanliness = clampNeed(state.cleanliness);
    energy = clampNeed(state.energy);
    sleeping = !!state.sleeping;

    const now = Date.now();
    const storedTimestamp = Number(state.lastDecayTimestamp);
    lastDecayTimestamp = Number.isFinite(storedTimestamp) && storedTimestamp > 0 && storedTimestamp <= now
      ? storedTimestamp
      : now;
    initialized = true;

    const elapsedTicks = Math.floor((now - lastDecayTimestamp) / decayIntervalMs);
    if (elapsedTicks > 0)
      applyDecayTicks(elapsedTicks, now);
    else if (storedTimestamp !== lastDecayTimestamp)
      persist();

    scheduleDecay(now);
  }

  function persist() {
    if (!Settings.isLoaded)
      return;

    const state = Settings.data.tamagotchi;
    state.hunger = roundedNeed(hunger);
    state.happiness = roundedNeed(happiness);
    state.cleanliness = roundedNeed(cleanliness);
    state.energy = roundedNeed(energy);
    state.sleeping = sleeping;
    state.lastDecayTimestamp = lastDecayTimestamp;
    Settings.saveImmediate();
  }

  function applyDecayTicks(ticks, now) {
    const count = Math.max(0, Math.floor(Number(ticks)));
    if (count === 0)
      return false;

    const configuredDifficulty = Number(Settings.data.tamagotchi.difficulty);
    const difficulty = Number.isFinite(configuredDifficulty)
      ? Math.max(0, Math.min(100, configuredDifficulty))
      : 50;
    const factor = 0.3 + difficulty / 100 * 1.7;
    if (sleeping) {
      energy = clampNeed(energy + 3.5 * count);
      hunger = clampNeed(hunger - 0.03 * factor * count);
      happiness = clampNeed(happiness - 0.005 * factor * count);
      cleanliness = clampNeed(cleanliness - 0.02 * factor * count);
    } else {
      energy = clampNeed(energy - 0.03 * factor * count);
      hunger = clampNeed(hunger - 0.05 * factor * count);
      happiness = clampNeed(happiness - 0.005 * factor * count);
      cleanliness = clampNeed(cleanliness - 0.05 * factor * count);
    }

    lastDecayTimestamp += count * decayIntervalMs;
    if (lastDecayTimestamp > now)
      lastDecayTimestamp = now;
    persist();
    return true;
  }

  function applyElapsedDecay(now) {
    if (!initialized)
      return false;
    const elapsedTicks = Math.floor((now - lastDecayTimestamp) / decayIntervalMs);
    return applyDecayTicks(elapsedTicks, now);
  }

  function scheduleDecay(now) {
    if (!initialized)
      return;
    const elapsed = Math.max(0, now - lastDecayTimestamp);
    decayTimer.interval = Math.max(1, decayIntervalMs - elapsed % decayIntervalMs);
    decayTimer.restart();
  }

  function synchronizeBeforeInteraction() {
    const now = Date.now();
    if (applyElapsedDecay(now))
      scheduleDecay(now);
  }

  function interactionAmount(value, fallback) {
    const numeric = Number(value);
    return Number.isFinite(numeric) && numeric >= 0 ? numeric : fallback;
  }

  function recordInteraction(action) {
    lastInteraction = action;
    interactionCompleted(action);
  }

  function feed(amount) {
    if (!initialized)
      return false;
    synchronizeBeforeInteraction();
    if (sleeping || hunger >= 100)
      return false;
    hunger = clampNeed(hunger + interactionAmount(amount, 20));
    eating = true;
    eatingResetTimer.restart();
    recordInteraction("feed");
    persist();
    return true;
  }

  function clean(amount) {
    if (!initialized)
      return false;
    synchronizeBeforeInteraction();
    if (sleeping || cleanliness >= 100)
      return false;
    cleanliness = clampNeed(cleanliness + interactionAmount(amount, 25));
    recordInteraction("clean");
    persist();
    return true;
  }

  function play(happinessAmount, energyCost) {
    if (!initialized)
      return false;
    synchronizeBeforeInteraction();
    const cost = interactionAmount(energyCost, 8);
    if (sleeping || energy < cost || happiness >= 100)
      return false;
    happiness = clampNeed(happiness + interactionAmount(happinessAmount, 20));
    energy = clampNeed(energy - cost);
    recordInteraction("play");
    persist();
    return true;
  }

  function rest() {
    if (!initialized)
      return false;
    synchronizeBeforeInteraction();
    sleeping = !sleeping;
    recordInteraction(sleeping ? "rest" : "wake");
    persist();
    return true;
  }

  function resetNeeds() {
    if (!initialized)
      return false;
    hunger = 100;
    happiness = 100;
    cleanliness = 100;
    energy = 100;
    sleeping = false;
    eating = false;
    lastDecayTimestamp = Date.now();
    recordInteraction("reset");
    persist();
    scheduleDecay(lastDecayTimestamp);
    return true;
  }

  Timer {
    id: decayTimer
    repeat: false
    onTriggered: {
      const now = Date.now();
      root.applyElapsedDecay(now);
      root.scheduleDecay(now);
    }
  }

  Timer {
    id: eatingResetTimer
    interval: 700
    repeat: false
    onTriggered: root.eating = false
  }

  Connections {
    target: Settings

    function onSettingsLoaded() {
      root.initializeFromSettings();
    }

    function onSettingsReloaded() {
      root.initializeFromSettings();
    }
  }

  Component.onCompleted: {
    if (Settings.isLoaded)
      initializeFromSettings();
  }
}
