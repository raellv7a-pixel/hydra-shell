import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
  id: root

  // Public API
  property string label: ""
  property string description: ""
  property bool checked: false
  property bool hovering: false
  readonly property bool pressed: boxMouseArea.pressed
  property color activeColor: Color.mPrimary
  property color activeOnColor: Color.mOnPrimary
  property int baseSize: root.defaultSize
  property real labelSize: Style.fontSizeL

  readonly property int defaultSize: Style.baseWidgetSize * 0.7

  signal toggled(bool checked)
  signal entered
  signal exited

  Layout.fillWidth: true
  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.name: root.label
  Accessible.description: root.description
  Accessible.checked: root.checked

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

  Rectangle {
    id: box

    opacity: root.enabled ? Style.opacityFull : Style.disabledContentOpacity
    Layout.margins: Style.borderS
    implicitWidth: Style.toOdd(root.baseSize)
    implicitHeight: Style.toOdd(root.baseSize)
    radius: boxMorph.radius
    scale: boxMorph.scale
    color: root.checked ? root.activeColor : Color.mSurface
    border.color: Color.mOutline
    border.width: Style.borderS

    Behavior on color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    Behavior on border.color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    NShapeMorph {
      id: boxMorph

      enabled: root.enabled
      hovered: root.hovering
      pressed: root.pressed
      selected: root.checked
      restingRadius: Style.radiusControlChecked * (root.baseSize / root.defaultSize)
      hoverRadius: Style.radiusControlPressed * (root.baseSize / root.defaultSize)
      pressedRadius: Style.radiusControlPressed * (root.baseSize / root.defaultSize)
      selectedRadius: Style.radiusControlPressed * (root.baseSize / root.defaultSize)
    }

    NStateLayer {
      id: boxStateLayer

      anchors.fill: parent
      radius: box.radius
      enabled: root.enabled
      hovered: root.hovering
      pressed: root.pressed
      focused: root.activeFocus
      selected: root.checked
      stateColor: root.checked ? root.activeOnColor : root.activeColor
    }

    NIcon {
      visible: true
      x: Style.pixelAlignCenter(parent.width, width)
      y: Style.pixelAlignCenter(parent.height, height)
      icon: "check"
      color: root.activeOnColor
      pointSize: Style.toOdd(root.baseSize * 0.5)
      opacity: root.checked ? 1 : 0
      scale: root.checked ? 1 : Style.morphPressedScale

      Behavior on opacity {
        NAnim {
          duration: Style.motionDurationFastEffects
          motionType: NAnim.StandardEffects
        }
      }

      Behavior on scale {
        NAnim {
          motionType: NAnim.ExpressiveFastSpatial
        }
      }
    }

    NFocusRing {
      focusVisible: root.activeFocus
      targetRadius: box.radius
    }

    MouseArea {
      id: boxMouseArea

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      enabled: root.enabled
      onEntered: {
        hovering = true;
        root.entered();
      }
      onExited: {
        hovering = false;
        root.exited();
      }
      onPressed: mouse => {
                   root.forceActiveFocus();
                   boxStateLayer.rippleAt(mouse.x, mouse.y);
                 }
      onClicked: root.toggled(!root.checked)
    }
  }

  Keys.onReturnPressed: event => {
                          if (!root.enabled)
                          return;
                          root.toggled(!root.checked);
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         if (!root.enabled)
                         return;
                         root.toggled(!root.checked);
                         event.accepted = true;
                       }
}
