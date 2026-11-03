import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.UI

FocusScope {
  id: root

  property real baseSize: Style.baseWidgetSize
  property bool applyUiScale: true

  property string icon
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool allowClickWhenDisabled: false
  property bool handleWheel: false
  property bool hovering: false

  property color colorBg: HydraColor.smartAlpha(HydraColor.mSurfaceContainerHigh)
  property color colorFg: HydraColor.mPrimary
  property color colorBgHover: root.colorBg
  property color colorFgHover: root.colorFg
  property color colorBorder: "transparent"
  property color colorBorderHover: root.colorBorder
  property real customRadius: -1 // -1 means use default (iRadiusL), otherwise use this value
  property bool keyboardPressed: false
  Accessible.role: Accessible.Button
  Accessible.name: typeof root.tooltipText === "string" ? root.tooltipText : root.icon
  Accessible.onPressAction: if (root.enabled)
                              root.clicked()

  function activateFromKeyboard(event) {
    if (!event.isAutoRepeat && root.enabled) {
      root.keyboardPressed = true;
      root.clicked();
    }
  }
  Keys.onReturnPressed: event => root.activateFromKeyboard(event)
  Keys.onEnterPressed: event => root.activateFromKeyboard(event)
  Keys.onSpacePressed: event => root.activateFromKeyboard(event)
  Keys.onReleased: event => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
      root.keyboardPressed = false;
    else
      event.accepted = false;
  }
  onActiveFocusChanged: if (!activeFocus)
                          root.keyboardPressed = false

  // Visual properties stay on the button, independently of its extended hit area.
  property alias border: visualButton.border
  property alias radius: visualButton.radius
  property alias color: visualButton.color

  signal entered
  signal exited
  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheel(int angleDelta)

  // Calculate button size based on settings
  readonly property real buttonSize: applyUiScale ? Style.toOdd(baseSize * Style.uiScaleRatio) : Style.toOdd(baseSize)

  // Size: use implicit width/height which layout can override
  // BarWidgetLoader sets explicit width/height to extend click area
  implicitWidth: buttonSize
  implicitHeight: buttonSize

  opacity: enabled ? 1.0 : 0.6

  // Visual button - stays at buttonSize, centered in parent
  NStateLayer {
    id: visualButton
    width: root.buttonSize
    height: root.buttonSize
    anchors.centerIn: parent

    baseColor: root.enabled && root.hovering ? root.colorBgHover : root.colorBg
    stateColor: root.enabled && root.hovering ? root.colorFgHover : root.colorFg
    focusColor: stateColor
    hovering: root.hovering
    pressed: buttonMouse.pressed || root.keyboardPressed
    focus: true
    focusPolicy: Qt.StrongFocus
    radius: Math.min((customRadius >= 0 ? customRadius : Style.iRadiusL), width / 2)
    border.color: root.enabled && root.hovering ? colorBorderHover : colorBorder
    border.width: Style.borderS

    TextMetrics {
      id: iconMetrics
      font: iconItem.font
      text: iconItem.text
    }

    NIcon {
      id: iconItem
      icon: root.icon
      pointSize: Style.toOdd(visualButton.width * 0.48)
      applyUiScale: root.applyUiScale
      color: root.enabled && root.hovering ? colorFgHover : colorFg
      // Pixel-perfect centering
      x: Math.round((visualButton.width - iconMetrics.tightBoundingRect.width) / 2) - iconMetrics.tightBoundingRect.x
      y: Style.pixelAlignCenter(visualButton.height, contentHeight)

      Behavior on color {
        enabled: !HydraColor.isTransitioning
        ColorAnimation {
          duration: root.hovering ? Style.hoverEnterDuration : Style.hoverLeaveDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  // MouseArea fills root (extends beyond visual button for bar click area)
  MouseArea {
    id: buttonMouse
    // Always enabled to allow hover/tooltip even when the button is disabled
    enabled: true
    anchors.fill: parent
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    onEntered: {
      hovering = root.enabled ? true : false;
      if (hovering && tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.show(root, tooltipText, tooltipDirection);
      }
      root.entered();
    }
    onExited: {
      hovering = false;
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide(root);
      }
      root.exited();
    }
    onClicked: mouse => {
      visualButton.forceActiveFocus(Qt.MouseFocusReason);
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide(root);
      }
      if (!root.enabled && !allowClickWhenDisabled) {
        return;
      }
      if (mouse.button === Qt.LeftButton) {
        root.clicked();
      } else if (mouse.button === Qt.RightButton) {
        root.rightClicked();
      } else if (mouse.button === Qt.MiddleButton) {
        root.middleClicked();
      }
    }
    onWheel: wheel => {
      if (root.handleWheel) {
        root.wheel(wheel.angleDelta.y);
      }
      wheel.accepted = false;
    }
  }
}
