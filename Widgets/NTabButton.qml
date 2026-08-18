import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  // Public properties
  property string text: ""
  property string icon: ""
  property var tooltipText
  property bool checked: false
  property int tabIndex: 0
  property real pointSize: Style.fontSizeM
  property bool isFirst: false
  property bool isLast: false

  // Internal state
  property bool isHovered: false
  readonly property bool pressed: tabMouseArea.pressed

  signal clicked

  function activate() {
    root.clicked();
    if (root.parent && root.parent.parent && root.parent.parent.currentIndex !== undefined) {
      root.parent.parent.currentIndex = root.tabIndex;
    }
  }

  // Sizing
  Layout.fillHeight: true
  implicitWidth: contentLayout.implicitWidth + Style.margin2M

  radius: tabMorph.radius
  scale: tabMorph.scale
  activeFocusOnTab: true
  Accessible.role: Accessible.PageTab
  Accessible.name: root.text
  Accessible.selected: root.checked

  color: root.checked ? Color.mSecondaryContainer : "transparent"
  border.color: "transparent"

  Behavior on color {
    enabled: !Color.isTransitioning
    NColorAnimation {
      motionType: NColorAnimation.Standard
    }
  }

  NShapeMorph {
    id: tabMorph

    hovered: root.isHovered
    pressed: root.pressed
    focused: root.activeFocus
    selected: root.checked
    restingRadius: root.height / 2
    hoverRadius: root.height / 2
    pressedRadius: Style.radiusControlPressed
    selectedRadius: root.height / 2
  }

  NStateLayer {
    id: tabStateLayer

    anchors.fill: parent
    radius: root.radius
    hovered: root.isHovered
    pressed: root.pressed
    focused: root.activeFocus
    selected: root.checked
    stateColor: root.checked ? Color.mOnSecondaryContainer : Color.mPrimary
  }

  NFocusRing {
    focusVisible: root.activeFocus
    targetRadius: root.radius
  }

  // Content
  RowLayout {
    id: contentLayout
    anchors.centerIn: parent
    width: Math.min(implicitWidth, parent.width - Style.margin2S)
    spacing: (root.icon !== "" && root.text !== "") ? Style.marginXS : 0

    NIcon {
      visible: root.icon !== ""
      Layout.alignment: Qt.AlignVCenter
      icon: root.icon
      pointSize: root.pointSize * 1.2
      color: root.checked ? Color.mOnSecondaryContainer : Color.mOnSurface

      Behavior on color {
        enabled: !Color.isTransitioning
        NColorAnimation {
          motionType: NColorAnimation.Standard
        }
      }
    }

    NText {
      id: tabText
      visible: root.text !== ""
      Layout.alignment: Qt.AlignVCenter
      text: root.text
      pointSize: root.pointSize
      font.weight: Style.fontWeightSemiBold
      color: root.checked ? Color.mOnSecondaryContainer : Color.mOnSurface
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        enabled: !Color.isTransitioning
        NColorAnimation {
          motionType: NColorAnimation.Standard
        }
      }
    }
  }

  // Tooltip
  Timer {
    id: tooltipTimer
    interval: 500
    onTriggered: {
      if (root.isHovered && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        TooltipService.show(root, root.tooltipText);
      }
    }
  }

  MouseArea {
    id: tabMouseArea

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      root.isHovered = true;
      if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        tooltipTimer.start();
      }
    }
    onExited: {
      root.isHovered = false;
      tooltipTimer.stop();
      if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
        TooltipService.hide();
      }
    }
    onPressed: mouse => {
                 root.forceActiveFocus();
                 tabStateLayer.rippleAt(mouse.x, mouse.y);
               }
    onClicked: root.activate()
  }

  Keys.onReturnPressed: event => {
                          root.activate();
                          event.accepted = true;
                        }
  Keys.onSpacePressed: event => {
                         root.activate();
                         event.accepted = true;
                       }
}
