import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Additive-only window rules (PLANO_INTEGRACAO_HYPRMOD.md §5) — this list
// never inventories what already exists in the shipped
// modules/window_rules.lua or in a hand-written user.lua; it only adds new
// hl.window_rule({...}) calls on top, via hydra-shell/settings.lua.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property var valueActions: ["move", "workspace", "opacity", "rounding", "size", "monitor", "tag"]
  readonly property var actionOptions: [
    { "key": "float", "name": "Flutuar" },
    { "key": "tile", "name": "Encaixar (tile)" },
    { "key": "pin", "name": "Fixar sobre outras janelas" },
    { "key": "center", "name": "Centralizar" },
    { "key": "fullscreen", "name": "Tela cheia" },
    { "key": "maximize", "name": "Maximizar" },
    { "key": "no_focus", "name": "Nunca focar" },
    { "key": "no_screen_share", "name": "Ocultar de compartilhamento de tela" },
    { "key": "opaque", "name": "Forçar opaca" },
    { "key": "no_blur", "name": "Sem desfoque" },
    { "key": "no_shadow", "name": "Sem sombra" },
    { "key": "no_anim", "name": "Sem animação" },
    { "key": "idle_inhibit", "name": "Impedir suspensão enquanto aberta" },
    { "key": "move", "name": "Mover para posição (valor: \"X Y\")" },
    { "key": "size", "name": "Redimensionar (valor: \"L A\")" },
    { "key": "workspace", "name": "Enviar para workspace (valor: nome/número)" },
    { "key": "opacity", "name": "Opacidade fixa (valor: 0.0–1.0)" },
    { "key": "rounding", "name": "Raio de canto (valor: px)" },
    { "key": "monitor", "name": "Monitor fixo (valor: nome)" }
  ]

  function set(index, field, value) {
    var arr = (HyprlandDraftStore.val("windowRules") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    if (field === "matchClass" || field === "matchTitle") {
      arr[index].match = Object.assign({}, arr[index].match);
      arr[index].match[field === "matchClass" ? "class" : "title"] = value;
    } else {
      arr[index][field] = value;
    }
    HyprlandDraftStore.edit("windowRules", arr);
  }

  function remove(index) {
    var arr = (HyprlandDraftStore.val("windowRules") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("windowRules", arr);
  }

  function add() {
    var arr = (HyprlandDraftStore.val("windowRules") || []).slice();
    arr.push({ "name": "regra-" + (arr.length + 1), "match": { "class": "" }, "action": "float", "value": "" });
    HyprlandDraftStore.edit("windowRules", arr);
  }

  NLabel {
    label: "Regras de janela"
    description: "Correspondência por classe/título (regex Hyprland) + uma ação"
  }

  Repeater {
    model: HyprlandDraftStore.val("windowRules") || []
    delegate: ColumnLayout {
      id: ruleDelegate
      required property int index
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        NTextInput {
          Layout.fillWidth: true
          label: "Classe (regex)"
          text: (ruleDelegate.modelData.match && ruleDelegate.modelData.match.class) || ""
          placeholderText: "^(mpv)$"
          onEditingFinished: root.set(ruleDelegate.index, "matchClass", text)
        }
        NTextInput {
          Layout.fillWidth: true
          label: "Título (regex, opcional)"
          text: (ruleDelegate.modelData.match && ruleDelegate.modelData.match.title) || ""
          onEditingFinished: root.set(ruleDelegate.index, "matchTitle", text)
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        NComboBox {
          Layout.fillWidth: true
          label: "Ação"
          model: root.actionOptions
          currentKey: ruleDelegate.modelData.action
          onSelected: key => root.set(ruleDelegate.index, "action", key)
        }
        NTextInput {
          Layout.fillWidth: true
          visible: root.valueActions.indexOf(ruleDelegate.modelData.action) !== -1
          label: "Valor"
          text: ruleDelegate.modelData.value || ""
          onEditingFinished: root.set(ruleDelegate.index, "value", text)
        }
        NIconButton {
          icon: "trash"
          tooltipText: "Remover"
          onClicked: root.remove(ruleDelegate.index)
        }
      }
      NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
      }
    }
  }

  NButton {
    text: "Nova regra"
    icon: "add"
    onClicked: root.add()
  }
}
