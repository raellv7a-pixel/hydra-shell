import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System

Flickable {
  id: screenUsagePage

  required property var panelRoot

  readonly property var topApps: ScreenTimeService.topAppsToday
  readonly property int maxAppSeconds: ScreenTimeService.maxAppSecondsToday
  contentWidth: width
  contentHeight: summaryColumn.implicitHeight + Style.marginM * 2
  flickableDirection: Flickable.VerticalFlick
  boundsBehavior: Flickable.StopAtBounds
  clip: true

  ColumnLayout {
    id: summaryColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "device-desktop"
        pointSize: Style.fontSizeXL
        color: panelRoot.componentAccent("screenUsage")
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("screenUsage")
          color: panelRoot.componentText("screenUsage", true)
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("trackedToday")
          color: panelRoot.componentText("screenUsage", false)
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }
      }

      NText {
        text: ScreenTimeService.todayFormatted
        color: panelRoot.componentAccent("screenUsage")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        font.family: Settings.data.ui.fontFixed
      }

      NIconButton {
        icon: "chevron-right"
        baseSize: Math.round(28 * screenUsagePage.panelRoot.panelUnit)
        activeFocusOnTab: true
        tooltipText: screenUsagePage.panelRoot.tr("details")
        onClicked: screenUsagePage.panelRoot.activeDetailView = "screenUsage"
      }
    }

    DashboardCard {
      panelRoot: screenUsagePage.panelRoot
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(78 * panelRoot.panelUnit)
      color: Style.materialFill(HydraColor.mSurfaceContainerHighest)
      radius: Style.radiusS

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        Repeater {
          model: ScreenTimeService.weeklyActivity

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginXXS

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              // Background track
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(12, Math.round(16 * panelRoot.panelUnit))
                radius: Style.radiusXS
                color: Style.materialFill(HydraColor.mSurfaceContainerLowest)
              }

              // Active bar
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Math.max(12, Math.round(16 * panelRoot.panelUnit))
                height: Math.max(modelData.totalSeconds > 0 ? Math.round(6 * panelRoot.panelUnit) : 0, parent.height * modelData.ratio)
                radius: Style.radiusXS
                color: modelData.isToday ? panelRoot.componentAccent("screenUsage") : Qt.alpha(panelRoot.componentAccent("screenUsage"), 0.45)

                Behavior on height {
                  enabled: !screenUsagePage.panelRoot.dashboardPerformanceMode && Style.animationNormal > 0
                  NumberAnimation {
                    duration: Style.animationNormal
                    easing.type: Easing.OutCubic
                  }
                }
              }
            }

            NText {
              Layout.fillWidth: true
              text: modelData.dayLabel
              color: modelData.isToday ? panelRoot.componentAccent("screenUsage") : panelRoot.componentText("screenUsage", false)
              pointSize: Style.fontSizeXXS
              font.weight: modelData.isToday ? Style.fontWeightBold : Style.fontWeightRegular
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("topApps")
        color: panelRoot.componentText("screenUsage", true)
        font.weight: Style.fontWeightSemiBold
        pointSize: Style.fontSizeS
        elide: Text.ElideRight
      }

      Repeater {
        model: screenUsagePage.topApps

        ScreenUsageAppRow {
          required property var modelData
          panelRoot: screenUsagePage.panelRoot
          Layout.fillWidth: true
          appData: modelData
          maxSeconds: screenUsagePage.maxAppSeconds
        }
      }

      NText {
        visible: screenUsagePage.topApps.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.round(80 * screenUsagePage.panelRoot.panelUnit)
        text: panelRoot.tr("screenUsageEmpty")
        color: HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
      }
    }
  }
}
