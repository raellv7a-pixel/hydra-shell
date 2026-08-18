import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property real baseSize: Style.baseWidgetSize
  property bool applyUiScale: true

  property string icon
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool allowClickWhenDisabled: false
  property bool handleWheel: false
  property bool hovering: false
  readonly property bool pressed: mouseArea.pressed

  property color colorBg: Color.smartAlpha(Color.mSurfaceVariant)
  property color colorFg: Color.mPrimary
  property color colorBgHover: colorFg
  property color colorFgHover: colorFg
  property color colorBorder: Color.mOutline
  property color colorBorderHover: Color.mOutline
  property real customRadius: -1 // -1 uses the semantic control radius

  // Expose border properties for backwards compatibility (aliases to visualButton)
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

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: typeof tooltipText === "string" && tooltipText !== "" ? tooltipText : icon

  // Size: use implicit width/height which layout can override
  // BarWidgetLoader sets explicit width/height to extend click area
  implicitWidth: buttonSize
  implicitHeight: buttonSize

  opacity: Style.opacityFull

  // Visual button - stays at buttonSize, centered in parent
  Rectangle {
    id: visualButton
    width: root.buttonSize
    height: root.buttonSize
    anchors.centerIn: parent

    color: root.enabled ? colorBg : Qt.alpha(colorBg, Style.disabledContainerOpacity)
    radius: morph.radius
    scale: morph.scale
    border.color: colorBorder
    border.width: Style.borderS

    Behavior on color {
      enabled: !Color.isTransitioning
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }

    NShapeMorph {
      id: morph

      enabled: root.enabled
      hovered: root.hovering
      pressed: root.pressed
      restingRadius: Math.min((root.customRadius >= 0 ? root.customRadius : Style.radiusControl), visualButton.width / 2)
      hoverRadius: Math.min((root.customRadius >= 0 ? root.customRadius : Style.radiusControlChecked), visualButton.width / 2)
      pressedRadius: Math.min((root.customRadius >= 0 ? root.customRadius : Style.radiusControlPressed), visualButton.width / 2)
    }

    NStateLayer {
      id: stateLayer

      anchors.fill: parent
      radius: visualButton.radius
      enabled: root.enabled
      hovered: root.hovering
      pressed: root.pressed
      focused: root.activeFocus
      stateColor: root.colorBgHover
    }

    NIcon {
      icon: root.icon
      pointSize: Style.toOdd(visualButton.width * 0.48)
      applyUiScale: root.applyUiScale
      color: root.enabled && root.hovering ? colorFgHover : colorFg
      // Pixel-perfect centering
      x: Style.pixelAlignCenter(visualButton.width, width)
      y: Style.pixelAlignCenter(visualButton.height, contentHeight)

      Behavior on color {
        enabled: !Color.isTransitioning
        NColorAnimation {
          motionType: NColorAnimation.Standard
        }
      }
    }

    NFocusRing {
      focusVisible: root.activeFocus
      targetRadius: visualButton.radius
    }
  }

  // MouseArea fills root (extends beyond visual button for bar click area)
  MouseArea {
    id: mouseArea

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
    onPressed: mouse => {
                 if (!root.enabled)
                 return;
                 root.forceActiveFocus();
                 const position = mouseArea.mapToItem(visualButton, mouse.x, mouse.y);
                 stateLayer.rippleAt(position.x, position.y);
               }
    onClicked: mouse => {
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
