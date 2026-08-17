import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Extra exec-once commands, run inside hl.on("hyprland.start", ...) —
// alongside (not instead of) Assets/Hyprland/modules/autostart.lua's own
// hydra-shell launch hook. No live preview: Hyprland only runs `exec`/
// `exec-once` at startup/reload, so this only takes effect after Save.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  function set(index, field, value) {
    var arr = (HyprlandDraftStore.val("autostart") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    arr[index][field] = value;
    HyprlandDraftStore.edit("autostart", arr);
  }

  function remove(index) {
    var arr = (HyprlandDraftStore.val("autostart") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("autostart", arr);
  }

  function addCommand(command) {
    var arr = (HyprlandDraftStore.val("autostart") || []).slice();
    arr.push({ "command": command || "", "enabled": true });
    HyprlandDraftStore.edit("autostart", arr);
  }

  function runNow(command) {
    if (command && command.length > 0) {
      Quickshell.execDetached(["sh", "-c", command]);
    }
  }

  // -----------------------------------------------------
  // Installed-app picker. Sources from Quickshell's own DesktopEntries
  // service (the same one Modules/Panels/Launcher/Providers/
  // ApplicationsProvider.qml uses) — no separate .desktop-file scanning to
  // maintain. Only apps with a usable `command` array are listed: an app
  // that can only run via app.execute() (quoted/space-containing Exec=)
  // can't be losslessly turned into a portable autostart shell string, so
  // it's excluded rather than added broken.
  ListModel {
    id: installedApps
  }

  function shellQuoteArgs(args) {
    return args.map(function (a) {
      var s = String(a);
      return /^[A-Za-z0-9_./=@%+-]+$/.test(s) ? s : "'" + s.replace(/'/g, "'\\''") + "'";
    }).join(" ");
  }

  function refreshInstalledApps() {
    installedApps.clear();
    if (typeof DesktopEntries === "undefined")
      return;
    var apps = DesktopEntries.applications.values || [];
    var seen = {};
    var rows = [];
    for (var i = 0; i < apps.length; i++) {
      var app = apps[i];
      if (!app || app.noDisplay || app.hidden)
        continue;
      if (!Array.isArray(app.command) || app.command.length === 0)
        continue;
      var key = String(app.id || app.name);
      if (seen[key])
        continue;
      seen[key] = true;
      rows.push({ "key": key, "name": app.name || key, "command": root.shellQuoteArgs(app.command) });
    }
    rows.sort(function (a, b) { return a.name.localeCompare(b.name); });
    for (var j = 0; j < rows.length; j++)
      installedApps.append(rows[j]);
    Logger.i("AutostartSubTab", "TEMP-DEBUG installed apps loaded:", installedApps.count, "first 5:", rows.slice(0, 5).map(function(r) { return r.name + " => " + r.command; }).join(" | "));
  }

  function commandForAppKey(key) {
    for (var i = 0; i < installedApps.count; i++) {
      var row = installedApps.get(i);
      if (row.key === key)
        return row.command;
    }
    return "";
  }

  Component.onCompleted: refreshInstalledApps()

  Connections {
    target: typeof DesktopEntries !== "undefined" ? DesktopEntries.applications : null
    function onValuesChanged() {
      root.refreshInstalledApps();
    }
  }

  NLabel {
    label: "Autostart"
    description: "Comandos extras executados quando o Hyprland inicia"
  }

  NSearchableComboBox {
    Layout.fillWidth: true
    label: "Adicionar aplicativo instalado"
    description: "Escolha um app já instalado — o comando é preenchido automaticamente"
    model: installedApps
    currentKey: ""
    placeholder: "Escolher app..."
    searchPlaceholder: "Buscar aplicativo..."
    onSelected: key => root.addCommand(root.commandForAppKey(key))
  }

  NDivider {
    Layout.fillWidth: true
  }

  Repeater {
    model: HyprlandDraftStore.val("autostart") || []
    delegate: RowLayout {
      id: entryDelegate
      required property int index
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.marginM

      NToggle {
        checked: entryDelegate.modelData.enabled !== false
        onToggled: checked => root.set(entryDelegate.index, "enabled", checked)
      }
      NTextInput {
        Layout.fillWidth: true
        text: entryDelegate.modelData.command || ""
        placeholderText: "comando a executar"
        onEditingFinished: root.set(entryDelegate.index, "command", text)
      }
      NIconButton {
        icon: "player-play"
        tooltipText: "Executar agora"
        onClicked: root.runNow(entryDelegate.modelData.command)
      }
      NIconButton {
        icon: "trash"
        tooltipText: "Remover"
        onClicked: root.remove(entryDelegate.index)
      }
    }
  }

  NButton {
    text: "Novo comando em branco"
    icon: "add"
    outlined: true
    onClicked: root.addCommand("")
  }
}
