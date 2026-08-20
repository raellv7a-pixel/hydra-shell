import QtQuick

QtObject {
  id: root

  // Noctalia -> Hydra rebrand: settings keys, widget ids, icon names and
  // predefined color scheme names all lost their old brand prefix.
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v60 (Noctalia → Hydra rebrand)");

    // --- Top level performance-mode block
    const rawPerf = rawJson?.noctaliaPerformance;
    if (rawPerf && adapter.hydraPerformance) {
      if (rawPerf.disableWallpaper !== undefined)
        adapter.hydraPerformance.disableWallpaper = rawPerf.disableWallpaper;
      if (rawPerf.disableDesktopWidgets !== undefined)
        adapter.hydraPerformance.disableDesktopWidgets = rawPerf.disableDesktopWidgets;
      logger.i("Settings", "Migrated noctaliaPerformance → hydraPerformance");
    }

    // --- Control center follow flag
    const rawFollow = rawJson?.controlCenter?.followNoctaliaPerformanceMode;
    if (rawFollow !== undefined && adapter.controlCenter) {
      adapter.controlCenter.followHydraPerformanceMode = rawFollow;
      logger.i("Settings", "Migrated controlCenter.followNoctaliaPerformanceMode → followHydraPerformanceMode");
    }

    // --- Widget / shortcut entries: ids, per-widget keys and icon names
    function migrateEntry(item) {
      if (typeof item === "string")
        return item === "NoctaliaPerformance" ? "HydraPerformance" : null;

      if (typeof item !== "object" || item === null)
        return null;

      var changedEntry = false;
      var newObj = {};
      for (var key in item) {
        var value = item[key];
        var newKey = key === "showNoctaliaPerformance" ? "showHydraPerformance" : key;
        if (newKey !== key)
          changedEntry = true;
        if (typeof value === "string") {
          if ((newKey === "id" || newKey === "widgetId") && value === "NoctaliaPerformance") {
            value = "HydraPerformance";
            changedEntry = true;
          } else if (newKey === "icon" && value === "noctalia") {
            value = "hydra";
            changedEntry = true;
          }
        }
        newObj[newKey] = value;
      }
      return changedEntry ? newObj : null;
    }

    function migrateArray(contextName, rawArr, adapterArr, setItem) {
      if (!adapterArr)
        return;
      for (var i = 0; i < adapterArr.length; i++) {
        const item = rawArr && rawArr[i] !== undefined ? rawArr[i] : adapterArr[i];
        if (item === undefined || item === null)
          continue;
        const migrated = migrateEntry(item);
        if (migrated !== null) {
          setItem(i, migrated);
          logger.i("Settings", `Migrated ${contextName}[${i}] to Hydra naming`);
        }
      }
    }

    const sections = ["left", "center", "right"];
    for (const section of sections) {
      migrateArray(`bar.widgets.${section}`, rawJson?.bar?.widgets?.[section], adapter?.bar?.widgets?.[section], function (i, v) {
        adapter.bar.widgets[section][i] = v;
      });
    }

    migrateArray("controlCenter.shortcuts.left", rawJson?.controlCenter?.shortcuts?.left, adapter?.controlCenter?.shortcuts?.left, function (i, v) {
      adapter.controlCenter.shortcuts.left[i] = v;
    });
    migrateArray("controlCenter.shortcuts.right", rawJson?.controlCenter?.shortcuts?.right, adapter?.controlCenter?.shortcuts?.right, function (i, v) {
      adapter.controlCenter.shortcuts.right[i] = v;
    });

    for (const section of sections) {
      migrateArray(`controlCenter.widgets.${section}`, rawJson?.controlCenter?.widgets?.[section], adapter?.controlCenter?.widgets?.[section], function (i, v) {
        adapter.controlCenter.widgets[section][i] = v;
      });
    }

    // --- Predefined color scheme names
    const scheme = rawJson?.colorSchemes?.predefinedScheme;
    if (typeof scheme === "string" && scheme.indexOf("Noctalia") !== -1) {
      const newScheme = scheme.replace("Noctalia", "Hydra");
      adapter.colorSchemes.predefinedScheme = newScheme;
      logger.i("Settings", "Migrated colorSchemes.predefinedScheme:", scheme, "->", newScheme);
    }

    return true;
  }
}
