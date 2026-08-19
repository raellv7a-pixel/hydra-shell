import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  required property var windowData
  required property var overview
  property bool livePreviews: true
  property bool active: true
  property bool privacyKnown: false
  property bool privateWindow: true
  property bool dragArmed: false

  readonly property bool isSelected: overview?.selectedWindowAddresses ? overview.selectedWindowAddresses.includes(windowData.addr) : false
  readonly property bool isGrouped: windowData.grouped === true

  radius: Style.radiusControl
  color: isSelected ? Qt.alpha(Color.mPrimary, 0.25) : (privateWindow ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHigh)
  border.width: isSelected || dragArmed ? Style.borderM : Style.borderS
  border.color: isSelected || dragArmed ? Color.mPrimary : (windowArea.containsMouse ? Color.mOutline : Qt.alpha(Color.mOutline, 0.64))
  scale: dragArmed ? 1.035 : 1

  Behavior on scale {
    NAnim {
      motionType: NAnim.ExpressiveFastSpatial
    }
  }

  Process {
    id: privacyProbe
    command: ["hyprctl", "-j", "getprop", "address:" + String(root.windowData.addr), "no_screen_share"]
    running: root.active

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const result = JSON.parse(this.text.trim());
          root.privateWindow = root.overview.isWindowPrivate(root.windowData.addr, result.no_screen_share === true);
        } catch (error) {
          root.privateWindow = true;
        }
        root.privacyKnown = true;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (!root.privacyKnown)
          root.privacyKnown = true;
      }
    }
  }

  Loader {
    anchors.fill: parent
    anchors.margins: Style.borderS
    active: root.active && root.privacyKnown && !root.privateWindow && root.livePreviews
    asynchronous: true
    sourceComponent: Component {
      ScreencopyView {
        captureSource: root.windowData.tl?.wayland || null
        live: root.active
      }
    }
  }

  Row {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: Style.spaceXXS
    spacing: Style.spaceXXS
    z: 5

    Rectangle {
      visible: root.isSelected
      width: 18 * Style.uiScaleRatio
      height: width
      radius: width / 2
      color: Color.mPrimary

      NIcon {
        anchors.centerIn: parent
        icon: "check"
        pointSize: Style.fontSizeLabelSmall
        color: Color.mOnPrimary
      }
    }

    Rectangle {
      visible: root.isGrouped
      width: 18 * Style.uiScaleRatio
      height: width
      radius: width / 2
      color: Qt.alpha(Color.mSecondary, 0.9)

      NIcon {
        anchors.centerIn: parent
        icon: "folders"
        pointSize: Style.fontSizeLabelSmall
        color: Color.mOnSecondary
      }
    }
  }

  Column {
    anchors.centerIn: parent
    width: Math.max(0, parent.width - 2 * Style.spaceS)
    spacing: Style.spaceXXS
    visible: !root.privacyKnown || root.privateWindow || !root.livePreviews

    NIcon {
      anchors.horizontalCenter: parent.horizontalCenter
      icon: root.privateWindow ? "shield-lock" : (!root.privacyKnown ? "hourglass" : "window")
      pointSize: Style.fontSizeHeadlineSmall
      color: root.privateWindow ? Color.mPrimary : Color.mOnSurfaceVariant
    }
    NText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.privateWindow ? qsTr("Private window") : (!root.privacyKnown ? qsTr("Checking privacy…") : root.windowData.title)
      pointSize: Style.fontSizeLabelSmall
      color: Color.mOnSurfaceVariant
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Math.min(parent.height * 0.3, 25 * Style.uiScaleRatio)
    color: Qt.alpha(Color.mSurface, 0.88)
    visible: windowArea.containsMouse && !root.privateWindow

    NText {
      anchors.fill: parent
      anchors.leftMargin: Style.spaceXS
      anchors.rightMargin: Style.spaceXL
      text: root.windowData.title
      pointSize: Style.fontSizeLabelSmall
    }
  }

  Item {
    id: dragItem
    width: 1
    height: 1
    Drag.active: root.dragArmed && windowArea.drag.active
    Drag.hotSpot.x: 0
    Drag.hotSpot.y: 0
  }

  Timer {
    id: holdTimer
    interval: 180
    onTriggered: {
      root.dragArmed = true;
      root.overview.startDrag(root.windowData.tl, root.windowData.addr, root.windowData.workspaceId);
    }
  }

  NStateLayer {
    anchors.fill: parent
    z: 2
    hovered: windowArea.containsMouse
    pressed: windowArea.pressed
    selected: root.isSelected
    dragged: root.dragArmed
    stateColor: Color.mPrimary
    radius: Style.radiusControl
  }
  MouseArea {
    id: windowArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.dragArmed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    drag.target: dragItem
    drag.threshold: 6 * Style.uiScaleRatio

    onPressed: holdTimer.restart()
    onReleased: mouse => {
                  holdTimer.stop();
                  if (root.dragArmed) {
                    dragItem.Drag.drop();
                    Qt.callLater(() => root.overview.endDrag());
                  } else if (mouse.modifiers & Qt.ShiftModifier || mouse.modifiers & Qt.ControlModifier) {
                    root.overview?.toggleWindowSelection(root.windowData.addr);
                  } else {
                    root.overview.switchWorkspace(root.windowData.workspaceId, root.windowData.workspaceName);
                  }
                  root.dragArmed = false;
                }
    onCanceled: {
      holdTimer.stop();
      root.dragArmed = false;
      root.overview.endDrag();
    }
    onWheel: wheel => wheel.accepted = false
  }

  Rectangle {
    z: 6
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.spaceXXS
    width: 22 * Style.uiScaleRatio
    height: width
    radius: Style.radiusCapsule
    color: closeArea.containsMouse ? Color.mError : Qt.alpha(Color.mError, 0.84)
    visible: windowArea.containsMouse || closeArea.containsMouse

    NText {
      anchors.centerIn: parent
      text: "×"
      pointSize: Style.fontSizeLabelMedium
      color: Color.mOnError
    }
    MouseArea {
      id: closeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mouse => {
                   mouse.accepted = true;
                   root.overview.closeWindow(root.windowData.tl, root.windowData.addr);
                 }
    }
  }
}
