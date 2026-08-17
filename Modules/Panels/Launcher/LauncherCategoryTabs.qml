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

  readonly property bool animationsEnabled: !Settings.data.general.animationDisabled

  implicitHeight: Style.baseWidgetSize
  color: Color.mSurfaceContainerHigh
  radius: Style.iRadiusL

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
  Component.onCompleted: {
    Logger.w("DEBUGCATTABS", "completed w=" + width + " h=" + height + " visible=" + visible + " categories=" + JSON.stringify(categories));
    Qt.callLater(_updateIndicator);
  }
  onVisibleChanged: Logger.w("DEBUGCATTABS", "visible=" + visible + " w=" + width + " h=" + height)
  onHeightChanged: Logger.w("DEBUGCATTABS", "height=" + height)

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
    radius: height / 2
    color: Color.mSecondaryContainer

    Behavior on x {
      enabled: root.animationsEnabled && indicator.ready
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on width {
      enabled: root.animationsEnabled && indicator.ready
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
  }

  RowLayout {
    id: tabRow
    anchors.fill: parent
    spacing: Style.marginXS

    Repeater {
      id: repeater
      model: root.categories

      delegate: Item {
        id: tabItem
        required property var modelData
        required property int index

        readonly property bool checked: root.currentIndex === index
        property bool hovered: false

        Layout.fillWidth: true
        Layout.fillHeight: true

        Component.onCompleted: Qt.callLater(root._updateIndicator)
        onXChanged: if (checked) Qt.callLater(root._updateIndicator)
        onWidthChanged: if (checked) Qt.callLater(root._updateIndicator)

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

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: (!tabItem.checked && tabItem.hovered) ? Color.mSurfaceContainerHighest : "transparent"

          Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }
        }

        NIcon {
          anchors.centerIn: parent
          icon: root.iconFor ? (root.iconFor(tabItem.modelData) || "star") : "star"
          pointSize: Style.fontSizeM * 1.2
          color: tabItem.checked ? Color.mOnSecondaryContainer : Color.mOnSurface

          Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: false
          cursorShape: Qt.PointingHandCursor
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
