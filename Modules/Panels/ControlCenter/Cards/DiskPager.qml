import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: diskPager

  property int currentIndex: 0
  readonly property var paths: panelRoot.diskPaths()
  readonly property int pageCount: paths.length
  readonly property int safeIndex: Math.min(currentIndex, Math.max(0, pageCount - 1))
  readonly property string currentPath: pageCount > 0 ? paths[safeIndex] : "/"
  readonly property real percent: Number(SystemStatService.diskPercents[currentPath] || 0)
  readonly property real usedGb: Number(SystemStatService.diskUsedGb[currentPath] || 0)
  readonly property real sizeGb: Number(SystemStatService.diskSizeGb[currentPath] || 0)

  Layout.preferredHeight: Math.round(76 * panelRoot.panelUnit)
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS

  onPageCountChanged: currentIndex = Math.min(currentIndex, Math.max(0, pageCount - 1))

  function previous() {
    if (pageCount <= 1)
      return;
    currentIndex = (safeIndex + pageCount - 1) % pageCount;
  }

  function next() {
    if (pageCount <= 1)
      return;
    currentIndex = (safeIndex + 1) % pageCount;
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
               if (event.angleDelta.y > 0)
               diskPager.previous();
               else if (event.angleDelta.y < 0)
               diskPager.next();
               event.accepted = diskPager.pageCount > 1;
             }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginXS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "database"
        pointSize: Style.fontSizeM
        color: Color.mPrimary
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: panelRoot.diskLabel(diskPager.currentPath)
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: diskPager.currentPath
          color: Qt.alpha(Color.mOnSurfaceVariant, 0.72)
          pointSize: Style.fontSizeXXS
          elide: Text.ElideMiddle
          visible: diskPager.pageCount > 1
        }
      }

      NText {
        text: Math.round(diskPager.percent) + "%"
        color: Color.mOnSurface
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightSemiBold
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(4, Math.round(5 * panelRoot.panelUnit))
      radius: height / 2
      color: Qt.alpha(Color.mOutline, 0.22)

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, diskPager.percent / 100))
        height: parent.height
        radius: parent.radius
        color: SystemStatService.getDiskColor(diskPager.currentPath)

        Behavior on width {
          NumberAnimation {
            duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      visible: diskPager.pageCount > 1

      NText {
        Layout.fillWidth: true
        text: diskPager.sizeGb > 0 ? (diskPager.usedGb.toFixed(1) + " / " + diskPager.sizeGb.toFixed(1) + " GB") : ""
        color: Qt.alpha(Color.mOnSurfaceVariant, 0.72)
        pointSize: Style.fontSizeXXS
        elide: Text.ElideRight
      }

      PageDots {
        panelRoot: diskPager.panelRoot
        count: diskPager.pageCount
        currentIndex: diskPager.safeIndex
        onSelected: index => diskPager.currentIndex = index
      }
    }

    TapHandler {
      acceptedButtons: Qt.LeftButton
      enabled: diskPager.pageCount > 1
      onTapped: diskPager.next()
    }
  }
}
