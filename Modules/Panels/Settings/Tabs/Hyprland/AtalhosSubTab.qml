import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../../../Helpers/HyprlandBindsParser.js" as HyprlandBindsParser
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Full-parity Atalhos sub-tab (PLANO_INTEGRACAO_HYPRMOD.md §5/§7.4):
// - legend of every *described* shipped bind, read live via `hyprctl binds
//   -j` (Helpers/HyprlandBindsParser.js) — not a text parse of binds.lua.
// - remap any shipped combo without touching modules/binds.lua, via
//   hydra-shell/rebinds.lua's K() lookup table.
// - add fully new combos on top, via hydra-shell/settings.lua.
//
// Text-entry remap, not live key-capture: Commons/Keybinds.qml's
// getKeybindString() has no Super/Meta modifier support and formats combos
// as "Ctrl+A" (shell-nav convention), not Hyprland's own "SUPER + A" —
// reusing it would either silently drop Super chords or require an untested
// new Qt-key→X11-keysym mapping layer. Validated text entry against
// Hyprland's own syntax is the correct-by-construction choice for v1; a
// capture widget mirroring HyprMod's is worthwhile future polish once that
// mapping exists and is tested.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var legend: []
  property bool loading: true

  function refreshLegend() {
    root.loading = true;
    bindsProc.running = true;
  }

  Component.onCompleted: refreshLegend()

  Process {
    id: bindsProc
    command: ["hyprctl", "binds", "-j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.legend = HyprlandBindsParser.parseBindsJson(this.text);
        root.loading = false;
      }
    }
  }

  function rebindsFor(combo) {
    var r = HyprlandDraftStore.val("rebinds") || {};
    return r[combo] || "";
  }

  function setRebind(originalCombo, newCombo) {
    var trimmed = (newCombo || "").trim();
    HyprlandDraftStore.edit("rebinds." + originalCombo, trimmed);
  }

  function clearRebind(originalCombo) {
    root.setRebind(originalCombo, "");
  }

  function setKeybindField(index, field, value) {
    var arr = (HyprlandDraftStore.val("keybinds") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    arr[index][field] = value;
    HyprlandDraftStore.edit("keybinds", arr);
  }

  function removeKeybind(index) {
    var arr = (HyprlandDraftStore.val("keybinds") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("keybinds", arr);
  }

  function addKeybind() {
    var arr = (HyprlandDraftStore.val("keybinds") || []).slice();
    arr.push({
               "combo": "",
               "command": "",
               "description": ""
             });
    HyprlandDraftStore.edit("keybinds", arr);
  }

  NSettingsSection {
    icon: "keyboard"
    title: "Remapear atalhos"
    description: "Toda combinação abaixo já existe — digite uma nova (ex.: \"SUPER + Y\") para remapear. Aplica-se ao salvar."

    RowLayout {
      Layout.fillWidth: true
      NButton {
        text: "Atualizar lista"
        outlined: true
        onClicked: root.refreshLegend()
      }
      NText {
        visible: root.loading
        text: "Carregando..."
        color: Color.mOnSurfaceVariant
      }
    }

    Repeater {
      model: root.legend
      delegate: RowLayout {
        id: legendDelegate
        required property var modelData
        Layout.fillWidth: true
        spacing: Style.marginM

        readonly property string currentRebind: root.rebindsFor(legendDelegate.modelData.combo)

        NLabel {
          Layout.preferredWidth: 260
          label: legendDelegate.modelData.description
          description: legendDelegate.modelData.combo
        }
        NTextInput {
          Layout.fillWidth: true
          placeholderText: "SUPER + Y"
          text: legendDelegate.currentRebind
          onEditingFinished: root.setRebind(legendDelegate.modelData.combo, text)
        }
        NIconButton {
          icon: "x"
          visible: legendDelegate.currentRebind !== ""
          tooltipText: "Restaurar padrão"
          onClicked: root.clearRebind(legendDelegate.modelData.combo)
        }
      }
    }
  }

  NSettingsSection {
    icon: "add"
    title: "Novos atalhos"
    description: "Combinações adicionais que não existem hoje — executam um comando"

    Repeater {
      model: HyprlandDraftStore.val("keybinds") || []
      delegate: RowLayout {
        id: customDelegate
        required property int index
        required property var modelData
        Layout.fillWidth: true
        spacing: Style.marginM

        NTextInput {
          Layout.preferredWidth: 160
          placeholderText: "SUPER + Y"
          text: customDelegate.modelData.combo || ""
          onEditingFinished: root.setKeybindField(customDelegate.index, "combo", text)
        }
        NTextInput {
          Layout.fillWidth: true
          placeholderText: "comando"
          text: customDelegate.modelData.command || ""
          onEditingFinished: root.setKeybindField(customDelegate.index, "command", text)
        }
        NTextInput {
          Layout.preferredWidth: 200
          placeholderText: "descrição (opcional)"
          text: customDelegate.modelData.description || ""
          onEditingFinished: root.setKeybindField(customDelegate.index, "description", text)
        }
        NIconButton {
          icon: "trash"
          tooltipText: "Remover"
          onClicked: root.removeKeybind(customDelegate.index)
        }
      }
    }

    NButton {
      text: "Novo atalho"
      icon: "add"
      onClicked: root.addKeybind()
    }
  }
}
