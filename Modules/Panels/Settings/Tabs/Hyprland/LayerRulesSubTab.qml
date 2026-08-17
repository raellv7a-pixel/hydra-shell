import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Additive-only layer rules — target layer-shell surfaces (bars, launchers,
// notification popups) by namespace. Same additive-only model as Window
// Rules: see that file's header comment.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property var valueActions: ["ignore_alpha", "order", "above_lock", "animation"]
  readonly property var actionOptions: [
    {
      "key": "blur",
      "name": "Desfoque"
    },
    {
      "key": "no_anim",
      "name": "Sem animação"
    },
    {
      "key": "dim_around",
      "name": "Escurecer o restante da tela"
    },
    {
      "key": "xray",
      "name": "X-ray (desfoca só o wallpaper)"
    },
    {
      "key": "no_screen_share",
      "name": "Ocultar de compartilhamento de tela"
    },
    {
      "key": "ignore_alpha",
      "name": "Ignorar transparência abaixo de (valor: 0.0–1.0)"
    },
    {
      "key": "order",
      "name": "Ordem de renderização (valor: número)"
    },
    {
      "key": "above_lock",
      "name": "Acima da tela de bloqueio (valor: 0, 1 ou 2)"
    },
    {
      "key": "animation",
      "name": "Estilo de animação (valor: slide/popin/fade/none)"
    }
  ]

  function set(index, field, value) {
    var arr = (HyprlandDraftStore.val("layerRules") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    arr[index][field] = value;
    HyprlandDraftStore.edit("layerRules", arr);
  }

  function remove(index) {
    var arr = (HyprlandDraftStore.val("layerRules") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("layerRules", arr);
  }

  function add() {
    var arr = (HyprlandDraftStore.val("layerRules") || []).slice();
    arr.push({
               "name": "layer-" + (arr.length + 1),
               "namespace": "",
               "action": "blur",
               "value": ""
             });
    HyprlandDraftStore.edit("layerRules", arr);
  }

  NLabel {
    label: "Regras de camada"
    description: "Correspondência por namespace do layer-shell (regex Hyprland)"
  }

  Repeater {
    model: HyprlandDraftStore.val("layerRules") || []
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
          label: "Namespace (regex)"
          text: ruleDelegate.modelData.namespace || ""
          placeholderText: "^(waybar|rofi)$"
          onEditingFinished: root.set(ruleDelegate.index, "namespace", text)
        }
        NComboBox {
          Layout.fillWidth: true
          label: "Efeito"
          model: root.actionOptions
          currentKey: ruleDelegate.modelData.action
          onSelected: key => root.set(ruleDelegate.index, "action", key)
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
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
