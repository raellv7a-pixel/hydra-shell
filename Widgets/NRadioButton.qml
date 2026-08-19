import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Widgets

RadioButton {
  id: root

  property real pointSize: Style.fontSizeBodyMedium

  implicitWidth: outerCircle.implicitWidth + Style.marginS + contentItem.implicitWidth

  onPressedChanged: {
    if (pressed)
      radioStateLayer.rippleAt(radioStateLayer.width / 2, radioStateLayer.height / 2);
  }

  indicator: Rectangle {
    id: outerCircle

    implicitWidth: Style.baseWidgetSize * 0.625 * pointSize / Style.fontSizeM
    implicitHeight: Style.baseWidgetSize * 0.625 * pointSize / Style.fontSizeM
    radius: width / 2
    scale: radioMorph.scale
    color: "transparent"
    border.color: root.checked ? Color.mPrimary : Color.mOnSurface
    border.width: Style.borderM
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      anchors.fill: parent
      anchors.margins: parent.width * 0.3

      radius: width / 2
      color: Qt.alpha(Color.mPrimary, root.checked ? 1 : 0)

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

    Behavior on border.color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    NShapeMorph {
      id: radioMorph

      enabled: root.enabled
      hovered: root.hovered
      pressed: root.pressed
      selected: root.checked
      restingRadius: outerCircle.width / 2
      hoverRadius: outerCircle.width / 2
      pressedRadius: outerCircle.width / 2
      selectedRadius: outerCircle.width / 2
    }

    NStateLayer {
      id: radioStateLayer

      anchors.fill: parent
      anchors.margins: -Style.spaceXXS
      radius: width / 2
      enabled: root.enabled
      hovered: root.hovered
      pressed: root.pressed
      focused: root.activeFocus
      selected: root.checked
      stateColor: Color.mPrimary
    }

    NFocusRing {
      focusVisible: root.activeFocus
      targetRadius: outerCircle.radius
    }
  }

  contentItem: NText {
    text: root.text
    pointSize: root.pointSize
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: outerCircle.right
    anchors.right: parent.right
    anchors.leftMargin: Style.marginS
  }
}
