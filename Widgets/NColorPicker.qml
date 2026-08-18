import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property var screen
  property color selectedColor: "black"

  signal colorSelected(color color)

  function openDialog() {
    var dialog = Qt.createComponent("NColorPickerDialog.qml").createObject(root, {
                                                                             "selectedColor": selectedColor,
                                                                             "parent": Overlay.overlay,
                                                                             "screen": root.screen
                                                                           });
    dialog.colorSelected.connect(function (color) {
      root.selectedColor = color;
      root.colorSelected(color);
    });
    dialog.open();
  }

  Layout.margins: Style.borderS
  implicitWidth: 150
  implicitHeight: Math.round(Style.baseWidgetSize * 1.1)

  radius: pickerMorph.radius
  scale: pickerMorph.scale
  color: Color.mSurfaceContainerHigh
  border.color: Color.mOutline
  border.width: Style.borderS
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: I18n.tr("widgets.color-picker.title")

  NShapeMorph {
    id: pickerMorph

    hovered: pickerMouseArea.containsMouse
    pressed: pickerMouseArea.pressed
    focused: root.activeFocus
    restingRadius: Style.radiusControl
    hoverRadius: Style.radiusControlChecked
    pressedRadius: Style.radiusControlPressed
  }

  NStateLayer {
    id: pickerStateLayer

    anchors.fill: parent
    radius: root.radius
    hovered: pickerMouseArea.containsMouse
    pressed: pickerMouseArea.pressed
    focused: root.activeFocus
    stateColor: Color.mPrimary
  }

  NFocusRing {
    focusVisible: root.activeFocus
    targetRadius: root.radius
  }

  // Minimized Look
  MouseArea {
    id: pickerMouseArea

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onPressed: mouse => {
                 root.forceActiveFocus();
                 pickerStateLayer.rippleAt(mouse.x, mouse.y);
               }
    onClicked: root.openDialog()

    RowLayout {
      anchors.fill: parent
      anchors {
        leftMargin: Style.marginL
        rightMargin: Style.marginL
      }
      spacing: Style.marginS

      // Color preview circle
      Rectangle {
        Layout.preferredWidth: root.height * 0.6
        Layout.preferredHeight: root.height * 0.6
        radius: Style.radiusControl
        color: root.selectedColor
        border.color: Color.mOutline
        border.width: Style.borderS
      }

      NText {
        text: root.selectedColor.toString().toUpperCase()
        family: Settings.data.ui.fontFixed
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      NIcon {
        icon: "color-picker"
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  Keys.onReturnPressed: event => {
                          root.openDialog();
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         root.openDialog();
                         event.accepted = true;
                       }
}
