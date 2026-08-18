import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Icon-only category tab bar for the launcher, with a single sliding pill
// indicator behind the active tab instead of each tab owning its own
// checked-background. A shared indicator can only ever be in one place at
// once, so it structurally cannot "blink" between two tabs the way
// independent per-button Rectangles can when hover state changes rapidly.
Rectangle {
  id: root
  objectName: "LauncherCategoryTabs"

  property var categories: []
  property int currentIndex: 0
  property var iconFor: null // function(category) -> icon name
  property var nameFor: null // function(category) -> display name
  signal categorySelected(int index)

  readonly property bool animationsEnabled: Style.motionEnabled

  implicitHeight: Style.baseWidgetSize
  color: Color.mSurfaceContainerHigh
  radius: Style.radiusCapsule

  function _updateIndicator() {
    if (root.currentIndex < 0 || root.currentIndex >= repeater.count) {
      indicator.visible = false;
      return;
    }
    const item = repeater.itemAt(root.currentIndex);
    if (!item)
      return;
    indicator.visible = true;
    indicator.indicatorX = item.x;
    indicator.indicatorWidth = item.width;
    indicator.ready = true;
  }

  onCurrentIndexChanged: Qt.callLater(_updateIndicator)
  onWidthChanged: Qt.callLater(_updateIndicator)
  Component.onCompleted: Qt.callLater(_updateIndicator)

  Rectangle {
    id: indicator
    property bool ready: false
    property real indicatorX: 0
    property real indicatorWidth: 0

    visible: false
    y: 0
    height: tabRow.height
    x: indicatorX
    width: indicatorWidth
    radius: Style.radiusCapsule
    color: Color.mSecondaryContainer

    Behavior on x {
      enabled: root.animationsEnabled && indicator.ready
      NAnim {
        motionType: NAnim.ExpressiveFastSpatial
      }
    }
    Behavior on width {
      enabled: root.animationsEnabled && indicator.ready
      NAnim {
        motionType: NAnim.ExpressiveFastSpatial
      }
    }
  }

  RowLayout {
    id: tabRow
    anchors.fill: parent
    spacing: Style.spaceXS

    Repeater {
      id: repeater
      model: root.categories

      delegate: Item {
        id: tabItem
        required property var modelData
        required property int index

        readonly property bool checked: root.currentIndex === index
        readonly property real radius: Style.radiusCapsule
        property bool hovered: false

        Layout.fillWidth: true
        Layout.fillHeight: true
        activeFocusOnTab: true
        Accessible.role: Accessible.PageTab
        Accessible.name: root.nameFor ? root.nameFor(modelData) : String(modelData)
        Accessible.selected: checked

        Keys.onReturnPressed: event => {
                                root.categorySelected(tabItem.index);
                                event.accepted = true;
                              }
        Keys.onSpacePressed: event => {
                               root.categorySelected(tabItem.index);
                               event.accepted = true;
                             }
        Component.onCompleted: Qt.callLater(root._updateIndicator)
        onXChanged: if (checked)
                      Qt.callLater(root._updateIndicator)
        onWidthChanged: if (checked)
                          Qt.callLater(root._updateIndicator)

        HoverHandler {
          id: hoverHandler
          onHoveredChanged: {
            tabItem.hovered = hoverHandler.hovered;
            if (hoverHandler.hovered) {
              if (root.nameFor)
                tooltipTimer.restart();
            } else {
              tooltipTimer.stop();
              TooltipService.hide(tabItem);
            }
          }
        }

        NStateLayer {
          id: tabStateLayer
          anchors.fill: parent
          hovered: tabItem.hovered
          pressed: tabMouseArea.pressed
          focused: tabItem.activeFocus
          radius: tabItem.radius
          stateColor: Color.mOnSurface
        }

        NIcon {
          anchors.centerIn: parent
          icon: root.iconFor ? (root.iconFor(tabItem.modelData) || "star") : "star"
          pointSize: Style.fontSizeBodyLarge
          color: tabItem.checked ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant

          Behavior on color {
            enabled: !Color.isTransitioning
            NColorAnimation {
              motionType: NColorAnimation.Standard
            }
          }
        }

        NFocusRing {
          focusVisible: tabItem.activeFocus
          targetRadius: tabItem.radius
        }

        MouseArea {
          id: tabMouseArea
          anchors.fill: parent
          hoverEnabled: false
          cursorShape: Qt.PointingHandCursor
          onPressed: mouse => tabStateLayer.rippleAt(mouse.x, mouse.y)
          onClicked: root.categorySelected(tabItem.index)
        }

        Timer {
          id: tooltipTimer
          interval: 500
          onTriggered: {
            if (tabItem.hovered && root.nameFor) {
              TooltipService.show(tabItem, root.nameFor(tabItem.modelData));
            }
          }
        }
      }
    }
  }
}
