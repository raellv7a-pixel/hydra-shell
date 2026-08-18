import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  // Public properties
  property real baseSize: Style.baseWidgetSize
  property bool applyUiScale: true
  property string icon
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool allowClickWhenDisabled: false
  property bool hot: false

  // Internal properties
  property bool hovering: false
  property bool pressed: false

  // Color properties
  property color colorBg: Color.smartAlpha(Color.mSurfaceVariant)
  property color colorFg: Color.mPrimary
  property color colorBgHover: Color.mPrimary
  property color colorFgHover: colorFg
  property color colorBorder: Color.mOutline
  property color colorBorderHover: Color.mOutline

  // Hot state colors
  property color colorBgHot: Color.mPrimary
  property color colorFgHot: Color.mOnPrimary

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
  opacity: enabled ? Style.opacityFull : Style.disabledContentOpacity
  color: hot ? colorBgHot : colorBg
  radius: hotMorph.radius
  scale: hotMorph.scale
  border.color: colorBorder
  border.width: Style.borderS
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: typeof tooltipText === "string" && tooltipText !== "" ? tooltipText : icon
  Accessible.pressed: root.pressed

  Behavior on color {
    enabled: !Color.isTransitioning
    NColorAnimation {
      motionType: NColorAnimation.Standard
    }
  }

  NShapeMorph {
    id: hotMorph

    enabled: root.enabled
    hovered: root.hovering
    pressed: root.pressed
    focused: root.activeFocus
    selected: root.hot
    restingRadius: root.width / 2
    hoverRadius: root.width / 2
    pressedRadius: Style.radiusControlPressed
    selectedRadius: root.width / 2
  }

  NStateLayer {
    id: hotStateLayer

    anchors.fill: parent
    radius: root.radius
    enabled: root.enabled
    hovered: root.hovering
    pressed: root.pressed
    focused: root.activeFocus
    selected: root.hot
    stateColor: root.hot ? root.colorFgHot : root.colorBgHover
  }

  NFocusRing {
    focusVisible: root.activeFocus
    targetRadius: root.radius
  }

  // Icon
  NIcon {
    icon: root.icon
    pointSize: Math.max(1, Math.round(root.width * 0.48))
    applyUiScale: root.applyUiScale
    color: root.hot ? colorFgHot : colorFg
    // Center horizontally
    x: (root.width - width) / 2
    // Center vertically accounting for font metrics
    y: (root.height - height) / 2 + (height - contentHeight) / 2

    Behavior on color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }
  }

  MouseArea {
    id: hotMouseArea

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
      root.forceActiveFocus();
      hotStateLayer.rippleAt(mouse.x, mouse.y);
      if (root.enabled) {
        root.pressed = true;
      }
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide();
      }
    }

    onReleased: function (mouse) {
      root.pressed = false;

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
      root.pressed = false;
      if (tooltipText && (!Array.isArray(tooltipText) || tooltipText.length > 0)) {
        TooltipService.hide();
      }
    }
  }

  Keys.onReturnPressed: event => {
                          if (!root.enabled)
                          return;
                          root.clicked();
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         if (!root.enabled)
                         return;
                         root.clicked();
                         event.accepted = true;
                       }
}
