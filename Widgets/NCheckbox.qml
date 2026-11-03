import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

RowLayout {
  id: root

  // Public API
  property string label: ""
  property string description: ""
  property bool checked: false
  property bool hovering: false
  property color activeColor: HydraColor.mPrimary
  property color activeOnColor: HydraColor.mOnPrimary
  property int baseSize: root.defaultSize
  property real labelSize: Style.fontSizeL

  readonly property int defaultSize: Style.baseWidgetSize * 0.7

  signal toggled(bool checked)
  signal entered
  signal exited

  Layout.fillWidth: true

  NLabel {
    label: root.label
    labelSize: root.labelSize
    description: root.description
    visible: root.label !== "" || root.description !== ""
  }

  // Spacer to push the checkbox to the far right
  Item {
    Layout.fillWidth: true
  }

  NStateLayer {
    id: box

    opacity: enabled ? 1.0 : 0.6
    Layout.margins: Style.borderS
    implicitWidth: Style.toOdd(root.baseSize)
    implicitHeight: Style.toOdd(root.baseSize)
    radius: Style.iRadiusXS * (root.baseSize / root.defaultSize)
    baseColor: root.checked ? root.activeColor : HydraColor.mSurface
    stateColor: root.checked ? root.activeOnColor : HydraColor.mOnSurface
    focusColor: root.checked ? root.activeOnColor : HydraColor.mPrimary
    hovering: root.hovering
    pressed: checkboxMouse.pressed
    focusPolicy: Qt.StrongFocus
    border.color: HydraColor.mOutline
    border.width: Style.borderS
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.label
    Accessible.description: root.description
    Accessible.checked: root.checked
    Accessible.onPressAction: root.toggled(!root.checked)
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onEnterPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)

    NIcon {
      visible: root.checked
      x: Style.pixelAlignCenter(parent.width, width)
      y: Style.pixelAlignCenter(parent.height, height)
      icon: "check"
      color: root.activeOnColor
      pointSize: Style.toOdd(root.baseSize * 0.5)
    }

    MouseArea {
      id: checkboxMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: {
        root.hovering = true;
        root.entered();
      }
      onExited: {
        root.hovering = false;
        root.exited();
      }
      onClicked: {
        box.forceActiveFocus(Qt.MouseFocusReason);
        root.toggled(!root.checked);
      }
    }
  }
}
