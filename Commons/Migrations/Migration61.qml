import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    const legacy = ["hyprland", "niri", "sway", "scroll", "mango", "labwc"];
    const entries = Array.from(adapter.templates.activeTemplates);
    const nativePreference = entries.find(entry => entry.id === "umbriel");
    const old = entries.filter(entry => legacy.includes(entry.id));
    const next = entries.filter(entry => !legacy.includes(entry.id));
    // An explicit Umbriel preference always wins over imported compositor preferences.
    if (!nativePreference)
      next.push({ id: "umbriel", enabled: old.length ? old.some(entry => entry.enabled) : true });
    adapter.templates.activeTemplates = next;
    if (adapter.bar.mouseWheelAction === "content")
      adapter.bar.mouseWheelAction = "workspace";
    logger.i("Settings", "Migrated compositor integration to Umbriel (v61)");
    return true;
  }
}
