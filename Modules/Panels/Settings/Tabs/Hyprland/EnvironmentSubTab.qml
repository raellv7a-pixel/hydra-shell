import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Extra env vars, on top of Assets/Hyprland/modules/env.lua's shipped set.
// No live preview: Hyprland only reads `env` once at compositor startup, so
// this only takes effect after Save (+ reload — a full session restart is
// actually required for some vars to reach already-launched apps, same
// caveat as any env var change under any compositor).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  function set(index, field, value) {
    var arr = (HyprlandDraftStore.val("envVars") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    arr[index][field] = value;
    HyprlandDraftStore.edit("envVars", arr);
  }

  function remove(index) {
    var arr = (HyprlandDraftStore.val("envVars") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("envVars", arr);
  }

  function add() {
    var arr = (HyprlandDraftStore.val("envVars") || []).slice();
    arr.push({
               "name": "",
               "value": ""
             });
    HyprlandDraftStore.edit("envVars", arr);
  }

  NLabel {
    label: "Variáveis de ambiente"
    description: "Aplicadas em ordem — uma variável pode referenciar outra definida antes dela"
  }

  Repeater {
    model: HyprlandDraftStore.val("envVars") || []
    delegate: RowLayout {
      id: entryDelegate
      required property int index
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.marginM

      NTextInput {
        Layout.preferredWidth: 220
        text: entryDelegate.modelData.name || ""
        placeholderText: "NOME_DA_VARIAVEL"
        onEditingFinished: root.set(entryDelegate.index, "name", text)
      }
      NTextInput {
        Layout.fillWidth: true
        text: entryDelegate.modelData.value || ""
        placeholderText: "valor"
        onEditingFinished: root.set(entryDelegate.index, "value", text)
      }
      NIconButton {
        icon: "trash"
        tooltipText: "Remover"
        onClicked: root.remove(entryDelegate.index)
      }
    }
  }

  NButton {
    text: "Nova variável"
    icon: "add"
    onClicked: root.add()
  }
}
