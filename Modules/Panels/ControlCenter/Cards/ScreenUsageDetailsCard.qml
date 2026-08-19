import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: screenUsageDetails
  styleKey: "screenUsage"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"

  readonly property var allApps: panelRoot.screenUsageTopApps(-1, panelRoot.screenUsageRangeDays)
  readonly property int maxAppSeconds: panelRoot.screenUsageMaxAppSeconds(allApps)

  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("screenUsage")
          pointSize: Style.fontSizeXL
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("trackedToday")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
        }
      }

      NText {
        text: panelRoot.durationText(panelRoot.screenUsageTotalForRange(panelRoot.screenUsageRangeDays))
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        font.family: Settings.data.ui.fontFixed
        color: Color.mPrimary
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        Layout.fillWidth: true
        labelText: panelRoot.tr("today")
        days: 1
      }

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        Layout.fillWidth: true
        labelText: panelRoot.tr("threeDays")
        days: 3
      }

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        Layout.fillWidth: true
        labelText: panelRoot.tr("fourteenDays")
        days: 14
      }
    }

    DashboardCard {
      panelRoot: screenUsageDetails.panelRoot
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(94 * panelRoot.panelUnit)
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS

          NText {
            text: panelRoot.screenUsageRangeDays === 1 ? panelRoot.tr("totalToday") : panelRoot.tr("totalRange")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
          }

          NText {
            text: panelRoot.durationText(panelRoot.screenUsageTotalForRange(panelRoot.screenUsageRangeDays))
            color: Color.mOnSurface
            pointSize: Style.fontSizeXXL
            font.weight: Style.fontWeightBold
            font.family: Settings.data.ui.fontFixed
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS

          NText {
            text: panelRoot.tr("appsTracked")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignRight
          }

          NText {
            text: String(screenUsageDetails.allApps.length)
            color: Color.mOnSurface
            pointSize: Style.fontSizeXXL
            font.weight: Style.fontWeightBold
            font.family: Settings.data.ui.fontFixed
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignRight
          }
        }
      }
    }

    DashboardCard {
      panelRoot: screenUsageDetails.panelRoot
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("allApps")
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: screenUsageDetailsColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          ColumnLayout {
            id: screenUsageDetailsColumn
            width: parent.width
            spacing: Style.marginS

            Repeater {
              model: screenUsageDetails.allApps

              ScreenUsageDetailRow {
                panelRoot: screenUsageDetails.panelRoot
                Layout.fillWidth: true
                appData: modelData
                maxSeconds: screenUsageDetails.maxAppSeconds
              }
            }
          }
        }

        NText {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: screenUsageDetails.allApps.length === 0
          text: panelRoot.tr("screenUsageEmpty")
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
