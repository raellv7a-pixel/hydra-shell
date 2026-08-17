import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  required property var overview
  property var workspaces: []
  property string title: ""
  property bool special: false
  property bool livePreviews: true

  readonly property real cardWidth: Math.round(282 * Style.uiScaleRatio)
  readonly property real cardHeight: Math.round(158 * Style.uiScaleRatio)
  readonly property real itemStride: cardWidth + Style.marginM

  readonly property var pinnedSpecials: Array.from(Settings.data.workspaceManager.pinnedSpecials || [])
  readonly property var customOrder: Array.from(Settings.data.workspaceManager.customOrder || [])

  readonly property var carouselModel: {
    if (special && Settings.data.workspaceManager.hideSpecials) {
      return [
            {
              "isAddAction": true,
              "id": 0,
              "name": ""
            }
          ];
    }

    let list = Array.from(workspaces || []);

    if (special) {
      if (Settings.data.workspaceManager.showOnlyActiveSpecial && overview?.screen) {
        list = list.filter(ws => ws.active === true || ws.isActive === true);
      }
      list.sort((a, b) => {
                  const pinA = pinnedSpecials.includes(a.name);
                  const pinB = pinnedSpecials.includes(b.name);
                  if (pinA && !pinB)
                  return -1;
                  if (!pinA && pinB)
                  return 1;
                  return (a.id || 0) - (b.id || 0);
                });
    } else if (customOrder.length > 0) {
      list.sort((a, b) => {
                  const keyA = String(a.id);
                  const keyB = String(b.id);
                  const idxA = customOrder.indexOf(keyA);
                  const idxB = customOrder.indexOf(keyB);
                  if (idxA !== -1 && idxB !== -1)
                  return idxA - idxB;
                  if (idxA !== -1)
                  return -1;
                  if (idxB !== -1)
                  return 1;
                  return (a.id || 0) - (b.id || 0);
                });
    }

    if (special)
      list.push({
                  "isAddAction": true,
                  "id": 0,
                  "name": ""
                });

    return list;
  }
  property real accumulatedWheelDelta: 0

  function moveBy(offset) {
    if (!carouselList.count)
      return;
    let next = carouselList.currentIndex < 0 ? 0 : carouselList.currentIndex + offset;
    if (next < 0)
      next = carouselList.count - 1;
    else if (next >= carouselList.count)
      next = 0;
    carouselList.currentIndex = next;
    const maximum = Math.max(0, carouselList.contentWidth - carouselList.width);
    carouselAnimation.stop();
    carouselAnimation.from = carouselList.contentX;
    carouselAnimation.to = Math.min(maximum, next * root.itemStride);
    carouselAnimation.start();
  }

  function togglePinSpecial(wsName) {
    if (!wsName)
      return;
    const current = Array.from(Settings.data.workspaceManager.pinnedSpecials || []);
    const idx = current.indexOf(wsName);
    if (idx !== -1) {
      current.splice(idx, 1);
    } else {
      current.push(wsName);
    }
    Settings.data.workspaceManager.pinnedSpecials = current;
  }

  spacing: Style.marginS

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      Layout.fillWidth: true
      text: root.title
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
    }

    NIconButton {
      visible: root.special
      icon: Settings.data.workspaceManager.hideSpecials ? "eye-off" : "eye"
      baseSize: Style.baseWidgetSize * 0.72
      tooltipText: Settings.data.workspaceManager.hideSpecials ? qsTr("Show special workspaces") : qsTr("Hide special workspaces")
      onClicked: Settings.data.workspaceManager.hideSpecials = !Settings.data.workspaceManager.hideSpecials
    }

    NText {
      text: carouselList.count ? qsTr("%1 of %2").arg(carouselList.currentIndex + 1).arg(carouselList.count) : ""
      pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
    }
    NIconButton {
      icon: "chevron-left"
      baseSize: Style.baseWidgetSize * 0.72
      enabled: carouselList.count > 1
      tooltipText: qsTr("Previous")
      onClicked: root.moveBy(-1)
    }
    NIconButton {
      icon: "chevron-right"
      baseSize: Style.baseWidgetSize * 0.72
      enabled: carouselList.count > 1
      tooltipText: qsTr("Next")
      onClicked: root.moveBy(1)
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: root.cardHeight

    ListView {
      id: carouselList
      anchors.fill: parent
      orientation: ListView.Horizontal
      model: root.carouselModel
      spacing: Style.marginM
      clip: true
      reuseItems: !root.overview.dragging
      cacheBuffer: root.cardWidth * 2
      boundsBehavior: Flickable.StopAtBounds
      snapMode: ListView.SnapToItem
      interactive: !root.overview.dragging
      currentIndex: count ? 0 : -1

      onMovementEnded: {
        if (count)
          currentIndex = Math.max(0, Math.min(count - 1, Math.round(contentX / root.itemStride)));
      }

      NumberAnimation {
        id: carouselAnimation
        target: carouselList
        property: "contentX"
        duration: Settings.data.general.animationDisabled ? 0 : 280
        easing.type: Easing.OutQuint
      }

      delegate: Item {
        id: delegateRoot
        required property var modelData
        width: root.cardWidth
        height: root.cardHeight

        Loader {
          anchors.fill: parent
          active: !delegateRoot.modelData.isAddAction
          sourceComponent: Component {
            Item {
              anchors.fill: parent

              WorkspaceCell {
                anchors.fill: parent
                wsId: delegateRoot.modelData.id
                wsName: delegateRoot.modelData.name
                overview: root.overview
                isSpecial: root.special
                livePreviews: root.livePreviews
                isPrivate: root.overview.isWorkspacePrivate(delegateRoot.modelData.id, delegateRoot.modelData.name)
                inViewport: delegateRoot.x + delegateRoot.width >= carouselList.contentX - 50 && delegateRoot.x <= carouselList.contentX + carouselList.width + 50 && !root.overview.overviewGrid
              }

              NIconButton {
                z: 8
                visible: root.special
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Style.marginS
                icon: root.pinnedSpecials.includes(delegateRoot.modelData.name) ? "pin-filled" : "pin"
                baseSize: Style.baseWidgetSize * 0.72
                colorFg: root.pinnedSpecials.includes(delegateRoot.modelData.name) ? Color.mPrimary : Color.mOnSurfaceVariant
                tooltipText: root.pinnedSpecials.includes(delegateRoot.modelData.name) ? qsTr("Unpin special workspace") : qsTr("Pin special workspace")
                onClicked: root.togglePinSpecial(delegateRoot.modelData.name)
              }
            }
          }
        }

        Loader {
          anchors.fill: parent
          active: delegateRoot.modelData.isAddAction === true
          sourceComponent: Component {
            Rectangle {
              radius: Style.radiusL
              color: addArea.containsMouse ? Color.mSurfaceContainerHigh : Color.mSurfaceContainer
              border.width: Style.borderS
              border.color: addArea.containsMouse ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.72)

              Row {
                anchors.centerIn: parent
                spacing: Style.marginS
                NIcon {
                  icon: "plus"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
                }
                NText {
                  text: qsTr("New special workspace")
                  color: Color.mOnSurfaceVariant
                }
              }
              MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.overview.openCreateWorkspace()
              }
            }
          }
        }
      }
    }

    WheelHandler {
      target: carouselList
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => {
                 const vertical = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                 const pixel = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.pixelDelta.x;
                 root.accumulatedWheelDelta += pixel !== 0 ? pixel * 2 : vertical;
                 if (Math.abs(root.accumulatedWheelDelta) >= 80) {
                   root.moveBy(root.accumulatedWheelDelta > 0 ? -1 : 1);
                   root.accumulatedWheelDelta = 0;
                 }
                 event.accepted = true;
               }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Style.marginM
      color: Color.mSurface
      opacity: carouselList.contentX > 1 ? 0.72 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.animationFast
        }
      }
    }
    Rectangle {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Style.marginM
      color: Color.mSurface
      opacity: carouselList.contentX < carouselList.contentWidth - carouselList.width - 1 ? 0.72 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.animationFast
        }
      }
    }
  }
}
