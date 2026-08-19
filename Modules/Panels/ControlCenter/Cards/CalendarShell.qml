import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets
DashboardCard {
  id: calendarShell
  styleKey: "calendar"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "left"

  clip: true

  SwipeView {
    id: calendarSwipe
    anchors.fill: parent
    anchors.margins: Style.marginS
    anchors.bottomMargin: Math.round(18 * panelRoot.panelUnit)
    currentIndex: 0
    clip: true
    interactive: true

    Item {
      WeatherCard {
        anchors.fill: parent
        forecastDays: 5
        showLocation: false
        radius: Style.radiusS
        color: panelRoot.m3SurfaceContainerHigh
        border.color: "transparent"
      }

      SubmoduleButton {
        panelRoot: calendarShell.panelRoot
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        targetView: "weather"
        tooltipText: panelRoot.tr("details")
      }
    }

    Item {
      CompactCalendarPage {
        panelRoot: calendarShell.panelRoot
        anchors.fill: parent
      }
    }

    Item {
      ScreenUsagePage {
        panelRoot: calendarShell.panelRoot
        anchors.fill: parent
      }
    }

    Item {
      TimerPage {
        panelRoot: calendarShell.panelRoot
        anchors.fill: parent
      }
    }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
               if (event.angleDelta.y > 0)
               calendarSwipe.currentIndex = Math.max(0, calendarSwipe.currentIndex - 1);
               else if (event.angleDelta.y < 0)
               calendarSwipe.currentIndex = Math.min(calendarSwipe.count - 1, calendarSwipe.currentIndex + 1);
               event.accepted = calendarSwipe.count > 1;
             }
  }

  PageDots {
    panelRoot: calendarShell.panelRoot
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.marginS
    count: calendarSwipe.count
    currentIndex: calendarSwipe.currentIndex
    onSelected: index => calendarSwipe.currentIndex = index
  }
}
