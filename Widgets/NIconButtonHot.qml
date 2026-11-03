import QtQuick
import qs.Commons
import qs.Services.UI

NStateLayer {
  id: root

  // Public properties
  property real baseSize: Style.baseWidgetSize
  property bool applyUiScale: true
  property string icon
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool allowClickWhenDisabled: false
  property bool hot: false

  // Color properties
  property color colorBg: HydraColor.smartAlpha(HydraColor.mSurfaceVariant)
  property color colorFg: HydraColor.mPrimary
  property color colorBgHover: root.colorBg
  property color colorFgHover: root.colorFg
  property color colorBorder: "transparent"
  property color colorBorderHover: root.colorBorder

  // Hot state colors
  property color colorBgHot: HydraColor.mPrimary
  property color colorFgHot: HydraColor.mOnPrimary

  // Signals
  signal entered
  signal exited
  signal clicked
  signal rightClicked
  signal middleClicked

  // Dimensions
  implicitWidth: applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)
  implicitHeight: applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)

  // Appearance
  opacity: enabled ? 1.0 : 0.6
  baseColor: root.hot ? root.colorBgHot : root.enabled && root.hovering ? root.colorBgHover : root.colorBg
  stateColor: root.hot ? root.colorFgHot : root.enabled && root.hovering ? root.colorFgHover : root.colorFg
  focusColor: root.stateColor
  focusPolicy: Qt.StrongFocus
  Accessible.role: Accessible.Button
  Accessible.name: typeof root.tooltipText === "string" ? root.tooltipText : root.icon
  Accessible.checkable: true
  Accessible.checked: root.hot
  Accessible.onPressAction: if (root.enabled)
                              root.clicked()
  property bool keyboardPressed: false
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
  pressed: buttonMouse.pressed || root.keyboardPressed
  radius: Math.min(Style.iRadiusL, width / 2)
  border.color: root.enabled && root.hovering ? colorBorderHover : colorBorder
  border.width: Style.borderS

  TextMetrics {
    id: iconMetrics
    font: iconItem.font
    text: iconItem.text
  }

  // Icon
  NIcon {
    id: iconItem
    icon: root.icon
    pointSize: Math.max(1, Math.round(root.width * 0.48))
    applyUiScale: root.applyUiScale
    color: root.stateColor
    // Center horizontally
    x: Math.round((root.width - iconMetrics.tightBoundingRect.width) / 2) - iconMetrics.tightBoundingRect.x
    // Center vertically accounting for font metrics
    y: (root.height - height) / 2 + (height - contentHeight) / 2

    Behavior on color {
      enabled: !HydraColor.isTransitioning
      ColorAnimation {
        duration: root.hovering ? Style.hoverEnterDuration : Style.hoverLeaveDuration
        easing.type: Easing.OutCubic
      }
    }
  }

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
        TooltipService.show(parent, tooltipText, tooltipDirection);
      }
      root.entered();
    }

    onExited: {
      hovering = false;
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide();
      }
      root.exited();
    }

    onPressed: function (mouse) {
      if (root.enabled)
        root.forceActiveFocus(Qt.MouseFocusReason);
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide();
      }
    }

    onReleased: function (mouse) {
      if (!root.enabled && !allowClickWhenDisabled) {
        return;
      }

      // Only trigger actions if released while hovering
      if (root.hovering) {
        if (mouse.button === Qt.LeftButton) {
          root.clicked();
        } else if (mouse.button === Qt.RightButton) {
          root.rightClicked();
        } else if (mouse.button === Qt.MiddleButton) {
          root.middleClicked();
        }
      }
    }

    onCanceled: {
      root.hovering = false;
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide();
      }
    }
  }
}
