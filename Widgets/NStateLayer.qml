import QtQuick
import QtQuick.Controls.Basic
import qs.Commons

// Paint only: the owning control supplies input, focus and persistent state.
Control {
  id: root

  property color baseColor: "transparent"
  property color stateColor: HydraColor.mOnSurface
  property color focusColor: HydraColor.mPrimary
  property bool hovering: false
  property bool pressed: false
  property bool focusVisible: visualFocus
  readonly property color focusStrokeColor: root.enabled && root.focusVisible ? Style.focusOutlineColor(root.baseColor, root.stateColor, root.focusColor) : root.focusColor
  property alias radius: surface.radius
  property alias color: surface.color
  property alias border: surface.border

  focusPolicy: Qt.NoFocus
  background: Rectangle {
    id: surface
    border.width: 0
    border.color: "transparent"
    radius: Math.min(Style.iRadiusS, width / 2, height / 2)
    color: Style.interactionColor(root.baseColor, root.stateColor, root.enabled && root.hovering, root.enabled && root.pressed)

    Behavior on color {
      enabled: root.visible && !HydraColor.isTransitioning
      ColorAnimation {
        duration: root.pressed ? Style.hoverLeaveDuration : root.hovering ? Style.hoverEnterDuration : Style.hoverLeaveDuration
        easing.type: Easing.OutCubic
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.borderS
      radius: Math.max(0, surface.radius - Style.borderS)
      color: "transparent"
      border.color: root.focusStrokeColor
      border.width: Style.borderM
      visible: root.enabled && root.focusVisible
      Accessible.ignored: true
    }
  }
}
