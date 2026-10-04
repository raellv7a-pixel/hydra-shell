pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Native.Input as Input
import qs.Services.UI
import qs.Widgets

Loader {
  id: root
  active: WindowSwitcherService.active
  Component.onCompleted: WindowSwitcherService.initialize()
  sourceComponent: PanelWindow {
    id: overlay
    screen: WindowSwitcherService.screen
    color: "transparent"
    implicitWidth: Math.min((screen?.width || 640) - Style.margin2XL, (carousel ? 880 : 480) * Style.uiScaleRatio)
    implicitHeight: Math.min((screen?.height || 480) - Style.margin2XL, content.implicitHeight + Style.margin2XL)
    readonly property bool carousel: Settings.data.umbriel.windowSwitcher.style === "carousel"
    WlrLayershell.namespace: "hydra-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Input.KeyboardState {
      id: modifiers
      onChecked: (mask, token) => WindowSwitcherService.modifiersChecked(mask, token)
    }
    Connections {
      target: keyboard.Window.window
      function onActiveChanged() {
        if (keyboard.Window.window.active && WindowSwitcherService.holding)
          modifiers.check(WindowSwitcherService.generation);
      }
    }
    Rectangle {
      anchors.fill: parent
      radius: Style.radiusL
      color: Color.mSurfaceContainerHigh
      Item {
        id: keyboard
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
                          if (event.key === Qt.Key_Escape)
                          WindowSwitcherService.close();
                          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                          WindowSwitcherService.confirm();
                          else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                          WindowSwitcherService.cycle((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                          else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                          WindowSwitcherService.cycle(-1);
                          else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                          WindowSwitcherService.cycle(1);
                          event.accepted = true;
                        }
        Keys.onReleased: event => {
                           if (WindowSwitcherService.holding && !event.isAutoRepeat && (event.key === Qt.Key_Alt || event.key === Qt.Key_Control || event.key === Qt.Key_Meta))
                           modifiers.check(WindowSwitcherService.generation);
                           event.accepted = true;
                         }
        ColumnLayout {
          id: content
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Style.marginXL
          }
          spacing: Style.marginL
          RowLayout {
            Layout.fillWidth: true
            NText {
              text: "Alternador de janelas"
              font.weight: Style.fontWeightSemiBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }
            NText {
              visible: Settings.data.umbriel.windowSwitcher.showCount
              text: (WindowSwitcherService.selectedIndex + 1) + " / " + WindowSwitcherService.entries.length
              color: Color.mOnSurfaceVariant
            }
          }
          Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min((item as Item)?.implicitHeight || 0, (overlay.screen?.height || 480) - 150 * Style.uiScaleRatio)
            sourceComponent: overlay.carousel ? carouselView : compactView
          }
          NText {
            text: WindowSwitcherService.holding ? "Solte o modificador para alternar · Esc cancela" : "Enter alterna · Esc cancela"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
          }
        }
      }
    }
    Component {
      id: compactView
      ListView {
        id: list
        implicitHeight: Math.min(count, 7) * (60 * Style.uiScaleRatio + Style.marginXS)
        model: WindowSwitcherService.entries
        currentIndex: WindowSwitcherService.selectedIndex
        spacing: Style.marginXS
        clip: true
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: SwitcherEntry {
          required property var modelData
          required property int index
          width: list.width
          height: 60 * Style.uiScaleRatio
          windowData: modelData
          selected: index === WindowSwitcherService.selectedIndex
          onChosen: {
            WindowSwitcherService.select(index);
            WindowSwitcherService.confirm();
          }
        }
      }
    }
    Component {
      id: carouselView
      Row {
        id: row
        spacing: Style.marginS
        height: 180 * Style.uiScaleRatio
        readonly property int slots: Math.min(5, WindowSwitcherService.entries.length)
        Repeater {
          model: row.slots
          delegate: SwitcherEntry {
            required property int index
            readonly property int windowIndex: (WindowSwitcherService.selectedIndex + WindowSwitcherService.entries.length + index - Math.floor(row.slots / 2)) % WindowSwitcherService.entries.length
            windowData: WindowSwitcherService.entries[windowIndex] || ({})
            width: (row.width - row.spacing * (row.slots - 1)) / Math.max(1, row.slots)
            height: row.height
            vertical: true
            selected: windowIndex === WindowSwitcherService.selectedIndex
            scale: selected ? 1 : 0.9
            Behavior on scale {
              NumberAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
              }
            }
            onChosen: {
              WindowSwitcherService.select(windowIndex);
              WindowSwitcherService.confirm();
            }
          }
        }
      }
    }
  }
}
