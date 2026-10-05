import QtQuick
import qs.Commons
import qs.Services.Compositor

QtObject {
  id: root

  function formatChord(chord) {
    if (!chord) return "";
    let formatted = chord;
    formatted = formatted.replace(/\bComma\b/g, ",");
    formatted = formatted.replace(/\bPeriod\b/g, ".");
    return formatted;
  }

  function getChord(actionId) {
    if (!UmbrielKeybindStore.loaded || UmbrielKeybindStore.error !== "") {
      return I18n.tr("setup.hydra.controls.unavailable");
    }
    if (UmbrielKeybindStore.externallyOwned)
      return I18n.tr("setup.hydra.controls.external-shortcut");
    const catalog = UmbrielKeybindStore.catalog || [];
    const item = catalog.find(entry => entry.id === actionId);
    if (!item)
      return I18n.tr("setup.hydra.controls.unavailable");
    const state = UmbrielKeybindStore.committed;
    const overrides = state.overrides || {};
    function chordFor(entry, override) {
      const type = override.type ?? entry.type;
      const action = override.action ?? entry.action;
      return type === item.type && JSON.stringify(action) === JSON.stringify(item.action) ? (override.chord ?? entry.chord) : "";
    }
    const originalChord = chordFor(item, overrides[item.id] || {});
    if (originalChord)
      return formatChord(originalChord);
    for (const entry of catalog) {
      const chord = chordFor(entry, overrides[entry.id] || {});
      if (chord)
        return formatChord(chord);
    }
    for (const entry of state.custom || []) {
      const chord = chordFor(entry, {});
      if (chord)
        return formatChord(chord);
    }
    return I18n.tr("setup.hydra.controls.unavailable");
  }

  readonly property string launcherChord: getChord("shell.launcher")
  readonly property string dashboardChord: getChord("shell.control")
  readonly property string overviewChord: getChord("umbriel.overview")
  readonly property string switcherChord: getChord("shell.switcher")
  readonly property string toolkitChord: getChord("tool.region")
  readonly property string settingsChord: getChord("shell.settings")
}
