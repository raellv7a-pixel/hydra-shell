import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Widgets

// Run through a private checkout facade and private XDG directories, as with
// launcher-polish.qml. Uses real controls and SettingsContent, never host actions.
ShellRoot {
  id: lab
  property bool settingsOnly: false
  property bool lightPalette: false
  property bool paletteReady: false
  property real viewportWidth: 1200
  property real viewportHeight: 700
  property int activations: 0

  function controls(item, propertyName) {
    let result = [];
    if (item[propertyName] !== undefined)
      result.push(item);
    for (const child of item.children || [])
      result = result.concat(controls(child, propertyName));
    return result;
  }

  function applyPalette() {
    if (paletteReady) {
      HydraColor.previewDarkMode = !lightPalette;
      HydraColor.previewPalette(JSON.parse(palette.text())[lightPalette ? "light" : "dark"]);
    }
  }

  function target(name) {
    switch (name) {
    case "action":
      return action;
    case "outlined":
      return outlined;
    case "icon":
      return iconButton;
    case "hot":
      return hot;
    case "cold":
      return cold;
    case "tab":
      return tab;
    case "toggle":
      return controls(toggle, "focusStrokeColor")[0];
    case "checkbox":
      return controls(checkbox, "focusStrokeColor")[0];
    case "combo":
      return controls(combo, "popup")[0];
    case "searchable":
      return controls(searchable, "popup")[0];
    default:
      return settingsPane;
    }
  }

  function describe(item) {
    const paint = controls(item, "focusStrokeColor")[0];
    const center = item.mapToGlobal(item.width / 2, item.height / 2);
    return {
      color: paint ? String(paint.color) : "",
      foreground: paint ? String(paint.stateColor) : "",
      focus: paint ? paint.focusVisible : item.activeFocus,
      focusColor: paint ? String(paint.focusStrokeColor) : "",
      pressed: paint ? paint.pressed : false,
      enabled: item.enabled,
      x: center.x,
      y: center.y,
      width: item.width,
      height: item.height,
      activations: lab.activations
    };
  }

  Window {
    id: window
    width: 1200
    height: 700
    visible: true
    title: "Hydra · Interaction states"
    color: HydraColor.mSurface

    Rectangle {
      id: canvas
      width: Math.min(window.width, lab.viewportWidth)
      height: Math.min(window.height, lab.viewportHeight)
      color: HydraColor.mSurface

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginXL
        spacing: Style.marginL
        RowLayout {
          Layout.fillWidth: true
          NText {
            text: qsTr("Interaction states")
            pointSize: Style.fontSizeXXL
          }
          Item {
            Layout.fillWidth: true
          }
          NButton {
            text: lab.settingsOnly ? qsTr("Controls") : qsTr("Settings")
            onClicked: lab.settingsOnly = !lab.settingsOnly
          }
        }
        RowLayout {
          visible: !lab.settingsOnly
          Layout.preferredHeight: 44 * Style.uiScaleRatio
          Layout.maximumHeight: Layout.preferredHeight
          NButton {
            id: action
            text: qsTr("Primary action")
            onClicked: lab.activations++
          }
          NButton {
            id: outlined
            text: qsTr("Outlined action")
            outlined: true
            onClicked: lab.activations++
          }
          NIconButton {
            id: iconButton
            icon: "settings"
            tooltipText: qsTr("Icon action")
            onClicked: lab.activations++
          }
          NIconButtonHot {
            id: hot
            icon: "sun"
            hot: true
            tooltipText: qsTr("Active action")
            onClicked: lab.activations++
          }
          NIconButtonHot {
            id: cold
            icon: "moon"
            tooltipText: qsTr("Inactive action")
            onClicked: lab.activations++
          }
          NTabButton {
            id: tab
            text: qsTr("Selected tab")
            checked: true
            Layout.preferredHeight: 40 * Style.uiScaleRatio
          }
        }
        RowLayout {
          visible: !lab.settingsOnly
          Layout.fillWidth: true
          NToggle {
            id: toggle
            label: qsTr("Switch")
            checked: true
            onToggled: value => toggle.checked = value
          }
          NCheckbox {
            id: checkbox
            label: qsTr("Checkbox")
            checked: true
            onToggled: value => checkbox.checked = value
          }
          NRadioButton {
            text: qsTr("Radio")
            checked: true
          }
          NSpinBox {
            from: 0
            to: 10
            value: 5
          }
        }
        RowLayout {
          visible: !lab.settingsOnly
          Layout.fillWidth: true
          NComboBox {
            id: combo
            Layout.fillWidth: true
            model: [
              {
                key: "30",
                name: "30 Hz"
              },
              {
                key: "60",
                name: "60 Hz"
              },
              {
                key: "120",
                name: "120 Hz"
              }
            ]
            currentKey: "60"
            onSelected: key => currentKey = key
          }
          NSearchableComboBox {
            id: searchable
            Layout.fillWidth: true
            model: ListModel {
              ListElement {
                key: "a"
                name: "Alpha"
              }
              ListElement {
                key: "b"
                name: "Beta"
              }
              ListElement {
                key: "c"
                name: "Gamma"
              }
            }
            currentKey: "b"
            onSelected: key => currentKey = key
          }
        }
        NSettingsGroupNav {
          visible: !lab.settingsOnly
          groups: [
            {
              key: "a",
              title: "Appearance",
              icon: "palette"
            },
            {
              key: "b",
              title: "Panels",
              icon: "layout"
            }
          ]
          expandedGroups: ({
                             a: true
                           })
          onGroupSelected: key => expandedGroups = ({
                                                      a: key === "a",
                                                      b: key === "b"
                                                    })
        }
        NSettingsGroupCard {
          visible: !lab.settingsOnly
          title: qsTr("Settings group")
          description: qsTr("Hover, press, focus and expansion remain independent.")
          icon: "settings-bar"
          expanded: true
          onToggled: open => expanded = open
          NText {
            text: qsTr("Controls keep their original values and actions.")
          }
        }
        NCollapsible {
          visible: !lab.settingsOnly
          label: qsTr("Expanded group")
          expanded: true
          onToggled: open => expanded = open
          NText {
            text: qsTr("The expanded tone survives hover.")
          }
        }
        SettingsContent {
          id: settingsPane
          visible: lab.settingsOnly
          Layout.fillWidth: true
          Layout.fillHeight: true
          screen: Quickshell.screens[0]
          requestedTab: 2
          Component.onCompleted: initialize()
        }
        Item {
          visible: !lab.settingsOnly
          Layout.fillHeight: true
        }
      }
    }
  }

  FileView {
    id: palette
    path: Quickshell.shellDir + "/Assets/ColorScheme/Hydra-Glacier/Hydra-Glacier.json"
    onLoaded: {
      lab.paletteReady = true;
      lab.applyPalette();
    }
  }

  IpcHandler {
    target: "highlightLab"
    function capture(path: string): void {
      canvas.grabToImage(result => console.log("INTERACTION_CAPTURE", path, result.saveToFile(path)));
    }
    function state(name: string): string {
      return JSON.stringify(lab.describe(lab.target(name)));
    }
    function hover(on: bool): void {
      action.hovered = on;
      hot.hovering = on;
      cold.hovering = on;
      tab.isHovered = on;
    }
    function disabled(on: bool): void {
      hot.enabled = !on;
    }
    function active(on: bool): void {
      hot.hot = on;
    }
    function press(on: bool): void {
      hot.keyboardPressed = on;
    }
    function focus(name: string, keyboard: bool): void {
      lab.target(name).forceActiveFocus(keyboard ? Qt.TabFocusReason : Qt.MouseFocusReason);
    }
    function reduced(on: bool): void {
      Settings.data.general.animationDisabled = on;
    }
    function mode(settingsMode: bool): void {
      lab.settingsOnly = settingsMode;
    }
    function page(id: int): void {
      settingsPane.selectTabById(id);
    }
    function scale(ratio: real): void {
      Settings.data.general.scaleRatio = ratio;
    }
    function size(width: real, height: real): void {
      lab.viewportWidth = width;
      lab.viewportHeight = height;
    }
    function theme(name: string, light: bool): void {
      lab.lightPalette = light;
      palette.path = Quickshell.shellDir + "/Assets/ColorScheme/" + name + "/" + name + ".json";
      lab.applyPalette();
    }
    function sidebar(): string {
      return JSON.stringify(lab.controls(settingsPane, "tabTextColor").map(item => ({
        name: item.Accessible.name,
        selected: item.selected,
        hovered: item.hovering,
        focus: item.visualFocus,
        color: String(item.color),
        x: item.mapToGlobal(item.width / 2, item.height / 2).x,
        y: item.mapToGlobal(item.width / 2, item.height / 2).y,
        width: item.width,
        height: item.height
      })));
    }
      function options(search: bool): string {
      const control = lab.controls(search ? searchable : combo, "popup")[0];
      return JSON.stringify(lab.controls(control.popup.contentItem, "isSelected").map(item => ({
      selected: item.isSelected,
      current: item.isHighlighted === undefined ? item.highlighted : item.isHighlighted,
      color: String(item.color === undefined ? item.background.color : item.color)
    })));
    }
      function quit(): void {
      Qt.quit();
    }
    }
    }
