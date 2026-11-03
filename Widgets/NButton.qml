import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

FocusScope {
  id: root

  // Public properties
  property string text: ""
  property string icon: ""
  property var tooltipText
  property color backgroundColor: HydraColor.mPrimary
  property color textColor: root.backgroundColor.a === 0 ? HydraColor.mOnSurface : HydraColor.mOnPrimary
  property color hoverColor: root.outlined ? "transparent" : root.backgroundColor
  property color textHoverColor: root.outlined ? root.backgroundColor : root.textColor
  property real fontSize: Style.fontSizeM
  property int fontWeight: Style.fontWeightSemiBold
  property real iconSize: Style.fontSizeL
  property bool outlined: false
  property int horizontalAlignment: Qt.AlignHCenter
  property real buttonRadius: Style.iRadiusS

  // Signals
  signal clicked
  signal rightClicked
  signal middleClicked
  signal entered
  signal exited

  // Internal properties
  property bool hovered: false
  property bool keyboardPressed: false
  readonly property bool pressed: mouseArea.pressed || keyboardPressed
  activeFocusOnTab: false
  Accessible.role: Accessible.Button
  Accessible.name: root.text || root.icon
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
  readonly property color contentColor: {
    if (!root.enabled) {
      return HydraColor.mOnSurfaceVariant;
    }
    if (root.hovered) {
      return root.textHoverColor;
    }
    if (root.outlined) {
      return root.backgroundColor;
    }
    return root.textColor;
  }

  // Dimensions - include margin so border renders cleanly at fractional scales
  implicitWidth: bg.implicitWidth + 2 * Style.borderS
  implicitHeight: bg.implicitHeight + 2 * Style.borderS

  opacity: enabled ? 1.0 : 0.6

  NStateLayer {
    id: bg
    anchors.fill: parent
    anchors.margins: Style.borderS

    implicitWidth: contentRow.implicitWidth + (root.fontSize * 2)
    implicitHeight: contentRow.implicitHeight + (root.fontSize)

    radius: root.buttonRadius
    baseColor: {
      if (!root.enabled)
        return root.outlined ? "transparent" : HydraColor.mSurfaceContainerHighest;
      if (root.hovered)
        return root.hoverColor;
      return root.outlined ? "transparent" : root.backgroundColor;
    }
    stateColor: root.contentColor
    focusColor: root.contentColor
    hovering: root.enabled && root.hovered
    pressed: root.pressed
    focus: true
    focusPolicy: Qt.StrongFocus

    border.width: root.outlined ? Style.borderS : 0
    border.color: {
      if (!root.enabled)
        return HydraColor.mOutline;
      return root.outlined ? root.backgroundColor : "transparent";
    }

    // Content
    RowLayout {
      id: contentRow
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: root.horizontalAlignment === Qt.AlignLeft ? parent.left : undefined
      anchors.horizontalCenter: root.horizontalAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
      anchors.leftMargin: root.horizontalAlignment === Qt.AlignLeft ? Style.marginL : 0
      spacing: Style.marginXS

      // Icon (optional)
      NIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.icon !== ""
        icon: root.icon
        pointSize: root.iconSize
        color: root.contentColor

        Behavior on color {
          enabled: !HydraColor.isTransitioning
          ColorAnimation {
            duration: root.hovered ? Style.hoverEnterDuration : Style.hoverLeaveDuration
            easing.type: Easing.OutCubic
          }
        }
      }

      // Text
      NText {
        Layout.alignment: Qt.AlignVCenter
        visible: root.text !== ""
        text: root.text
        pointSize: root.fontSize
        font.weight: root.fontWeight
        color: root.contentColor

        Behavior on color {
          enabled: !HydraColor.isTransitioning
          ColorAnimation {
            duration: root.hovered ? Style.hoverEnterDuration : Style.hoverLeaveDuration
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    // Mouse interaction
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      enabled: root.enabled
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

      onEntered: {
        root.hovered = root.enabled ? true : false;
        root.entered();
        if (root.hovered && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.show(root, root.tooltipText);
        }
      }
      onExited: {
        root.hovered = false;
        root.exited();
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
      onPressed: mouse => {
        bg.forceActiveFocus(Qt.MouseFocusReason);
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
        if (mouse.button === Qt.LeftButton) {
          root.clicked();
        } else if (mouse.button == Qt.RightButton) {
          root.rightClicked();
        } else if (mouse.button == Qt.MiddleButton) {
          root.middleClicked();
        }
      }

      onCanceled: {
        root.hovered = false;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }
  }
}
