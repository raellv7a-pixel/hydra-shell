import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// Bezier curves + per-leaf animation overrides. No shipped default curve or
// leaf appears here — those live in Assets/Hyprland/modules/animations.lua
// and are edited by hand-porting a curve you like into a new named entry
// here, which then wins because hydra-shell/settings.lua loads after the
// shipped modules. A draggable curve canvas (HyprMod's UX, cited in the
// plan) is worthwhile future polish; the numeric fields below are the
// full-precision equivalent in the meantime.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property var leafOptions: ["windows", "windowsIn", "windowsOut", "windowsMove", "fade", "fadeDim", "border", "borderangle", "workspaces", "specialWorkspace", "layers"]

  function curveNames() {
    var names = (HyprlandDraftStore.val("animCurves") || []).map(function (c) {
      return c.name;
    });
    return names.concat(["default", "linear", "easeOutQuint"]);
  }

  function setCurveField(index, field, value) {
    var arr = (HyprlandDraftStore.val("animCurves") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    arr[index][field] = value;
    HyprlandDraftStore.edit("animCurves", arr);
  }

  function removeCurve(index) {
    var arr = (HyprlandDraftStore.val("animCurves") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("animCurves", arr);
  }

  function addCurve() {
    var arr = (HyprlandDraftStore.val("animCurves") || []).slice();
    arr.push({
               "name": "custom" + (arr.length + 1),
               "x0": 0.25,
               "y0": 0.1,
               "x1": 0.25,
               "y1": 1
             });
    HyprlandDraftStore.edit("animCurves", arr);
  }

  function setItemField(index, field, value) {
    var arr = (HyprlandDraftStore.val("animItems") || []).slice();
    arr[index] = Object.assign({}, arr[index]);
    arr[index][field] = value;
    HyprlandDraftStore.edit("animItems", arr);
  }

  function removeItem(index) {
    var arr = (HyprlandDraftStore.val("animItems") || []).slice();
    arr.splice(index, 1);
    HyprlandDraftStore.edit("animItems", arr);
  }

  function addItem() {
    var arr = (HyprlandDraftStore.val("animItems") || []).slice();
    arr.push({
               "leaf": "windows",
               "enabled": true,
               "speed": 4,
               "bezier": "default",
               "style": ""
             });
    HyprlandDraftStore.edit("animItems", arr);
  }

  NSettingsSection {
    icon: "chart-bezier"
    title: "Curvas bezier"
    description: "Pontos de controle P1/P2 — P0 é sempre (0,0) e P3 sempre (1,1)"

    Repeater {
      model: HyprlandDraftStore.val("animCurves") || []
      delegate: ColumnLayout {
        id: curveDelegate
        required property int index
        required property var modelData
        Layout.fillWidth: true
        spacing: Style.marginXS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          NTextInput {
            Layout.fillWidth: true
            label: "Nome"
            text: curveDelegate.modelData.name
            onEditingFinished: root.setCurveField(curveDelegate.index, "name", text)
          }
          NIconButton {
            icon: "trash"
            tooltipText: "Remover"
            onClicked: root.removeCurve(curveDelegate.index)
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          NValueSlider {
            Layout.fillWidth: true
            label: "X1"
            from: 0
            to: 1
            stepSize: 0.01
            value: curveDelegate.modelData.x0
            onMoved: v => root.setCurveField(curveDelegate.index, "x0", v)
            text: Number(curveDelegate.modelData.x0).toFixed(2)
          }
          NValueSlider {
            Layout.fillWidth: true
            label: "Y1"
            from: -1
            to: 2
            stepSize: 0.01
            value: curveDelegate.modelData.y0
            onMoved: v => root.setCurveField(curveDelegate.index, "y0", v)
            text: Number(curveDelegate.modelData.y0).toFixed(2)
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          NValueSlider {
            Layout.fillWidth: true
            label: "X2"
            from: 0
            to: 1
            stepSize: 0.01
            value: curveDelegate.modelData.x1
            onMoved: v => root.setCurveField(curveDelegate.index, "x1", v)
            text: Number(curveDelegate.modelData.x1).toFixed(2)
          }
          NValueSlider {
            Layout.fillWidth: true
            label: "Y2"
            from: -1
            to: 2
            stepSize: 0.01
            value: curveDelegate.modelData.y1
            onMoved: v => root.setCurveField(curveDelegate.index, "y1", v)
            text: Number(curveDelegate.modelData.y1).toFixed(2)
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
      text: "Nova curva"
      icon: "add"
      onClicked: root.addCurve()
    }
  }

  NSettingsSection {
    icon: "sparkles"
    title: "Sobrescrever animações"
    description: "Só entram aqui as animações que você quer diferentes do padrão da hydra-shell"

    Repeater {
      model: HyprlandDraftStore.val("animItems") || []
      delegate: RowLayout {
        id: itemDelegate
        required property int index
        required property var modelData
        Layout.fillWidth: true
        spacing: Style.marginM

        NComboBox {
          Layout.preferredWidth: 160
          label: "Elemento"
          model: root.leafOptions.map(function (l) {
            return {
              "key": l,
              "name": l
            };
          })
          currentKey: itemDelegate.modelData.leaf
          onSelected: key => root.setItemField(itemDelegate.index, "leaf", key)
        }
        NToggle {
          label: "Ativa"
          checked: itemDelegate.modelData.enabled !== false
          onToggled: checked => root.setItemField(itemDelegate.index, "enabled", checked)
        }
        NValueSlider {
          Layout.fillWidth: true
          label: "Velocidade"
          from: 0.5
          to: 30
          stepSize: 0.5
          value: itemDelegate.modelData.speed || 4
          onMoved: v => root.setItemField(itemDelegate.index, "speed", v)
          text: Number(itemDelegate.modelData.speed || 4).toFixed(1)
        }
        NComboBox {
          Layout.preferredWidth: 160
          label: "Curva"
          model: root.curveNames().map(function (c) {
            return {
              "key": c,
              "name": c
            };
          })
          currentKey: itemDelegate.modelData.bezier || "default"
          onSelected: key => root.setItemField(itemDelegate.index, "bezier", key)
        }
        NIconButton {
          icon: "trash"
          tooltipText: "Remover"
          onClicked: root.removeItem(itemDelegate.index)
        }
      }
    }

    NButton {
      text: "Nova sobrescrita"
      icon: "add"
      onClicked: root.addItem()
    }
  }
}
