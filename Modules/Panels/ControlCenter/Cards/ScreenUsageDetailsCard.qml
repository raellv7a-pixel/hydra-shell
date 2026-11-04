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

  readonly property int activeRangeDays: panelRoot.screenUsageRangeDays || 1
  readonly property var rangeStats: ScreenTimeService.getRangeStats(activeRangeDays)
  readonly property var allApps: rangeStats.topApps || []
  readonly property int maxAppSeconds: ScreenTimeService.getMaxAppSeconds(allApps)

  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // Navigation Header
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        activeFocusOnTab: true
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("screenUsage")
          pointSize: Style.fontSizeXL
          font.weight: Style.fontWeightSemiBold
          color: HydraColor.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr(activeRangeDays === 1 ? "today" : activeRangeDays === 3 ? "threeDays" : activeRangeDays === 7 ? "sevenDays" : "fourteenDays")
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
          elide: Text.ElideRight
        }
      }

      NText {
        text: screenUsageDetails.rangeStats.totalFormatted
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        font.family: Settings.data.ui.fontFixed
        color: HydraColor.mPrimary
      }
    }

    // Keep every period available when translations or UI scaling widen the controls.
    Flow {
      Layout.fillWidth: true
      spacing: Style.marginS

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        labelText: panelRoot.tr("today")
        days: 1
      }

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        labelText: panelRoot.tr("threeDays")
        days: 3
      }

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        labelText: panelRoot.tr("sevenDays")
        days: 7
      }

      ScreenUsageRangeButton {
        panelRoot: screenUsageDetails.panelRoot
        labelText: panelRoot.tr("fourteenDays")
        days: 14
      }
    }

    // Main Scrollable Area for Metrics, Charts and App List
    Flickable {
      id: detailsFlickable
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: detailsContentColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      clip: true

      ColumnLayout {
        id: detailsContentColumn
        width: parent.width
        spacing: Style.marginM

        // Key Metrics Summary Cards
        DashboardCard {
          panelRoot: screenUsageDetails.panelRoot
          Layout.fillWidth: true
          implicitHeight: metricsGrid.implicitHeight + Style.marginM * 2
          color: Style.materialFill(HydraColor.mSurfaceContainerHigh)
          radius: Style.radiusS

          GridLayout {
            id: metricsGrid
            anchors.fill: parent
            anchors.margins: Style.marginM
            columns: width >= Math.round(280 * screenUsageDetails.panelRoot.panelUnit) ? 2 : 1
            rowSpacing: Style.marginM
            columnSpacing: Style.marginM

            // Metric 1: Total for period
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXXS

              NText {
                text: activeRangeDays === 1 ? panelRoot.tr("totalToday") : panelRoot.tr("totalRange")
                color: HydraColor.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
              }

              NText {
                text: screenUsageDetails.rangeStats.totalFormatted
                color: HydraColor.mPrimary
                pointSize: Style.fontSizeXXL
                font.weight: Style.fontWeightBold
                font.family: Settings.data.ui.fontFixed
              }
            }

            // Metric 2: Daily average
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXXS

              NText {
                text: panelRoot.tr("dailyAverage")
                color: HydraColor.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
              }

              NText {
                text: screenUsageDetails.rangeStats.dailyAverageFormatted
                color: HydraColor.mOnSurface
                pointSize: Style.fontSizeXL
                font.weight: Style.fontWeightSemiBold
                font.family: Settings.data.ui.fontFixed
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
              }
            }

            // Metric 3: Apps tracked count
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXXS

              NText {
                text: panelRoot.tr("appsTracked")
                color: HydraColor.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
              }

              NText {
                text: String(screenUsageDetails.rangeStats.appsCount)
                color: HydraColor.mOnSurface
                pointSize: Style.fontSizeXL
                font.weight: Style.fontWeightBold
                font.family: Settings.data.ui.fontFixed
              }
            }

            // Metric 4: Peak usage hours
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXXS

              NText {
                text: panelRoot.tr("peakHours")
                color: HydraColor.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
              }

              NText {
                text: screenUsageDetails.rangeStats.peakHourStr
                color: HydraColor.mOnSurface
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                font.family: Settings.data.ui.fontFixed
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
              }
            }
          }
        }

        // Visual Activity Charts Card (Period Trend + 24h Hourly Distribution)
        DashboardCard {
          panelRoot: screenUsageDetails.panelRoot
          Layout.fillWidth: true
          implicitHeight: chartsColumn.implicitHeight + Style.marginM * 2
          color: Style.materialFill(HydraColor.mSurfaceContainerHigh)
          radius: Style.radiusS

          ColumnLayout {
            id: chartsColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            // Chart A: Daily Activity Trend
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true

                NText {
                  Layout.fillWidth: true
                  text: panelRoot.tr("dailyActivity")
                  color: HydraColor.mOnSurface
                  font.weight: Style.fontWeightSemiBold
                  pointSize: Style.fontSizeS
                }

                NText {
                  text: panelRoot.tr(screenUsageDetails.activeRangeDays === 1 ? "today" : screenUsageDetails.activeRangeDays === 3 ? "threeDays" : screenUsageDetails.activeRangeDays === 7 ? "sevenDays" : "fourteenDays")
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(64 * panelRoot.panelUnit)
                spacing: Style.marginXS

                Repeater {
                  model: screenUsageDetails.rangeStats.dailyTrend || []

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Style.marginXXS

                    Item {
                      Layout.fillWidth: true
                      Layout.fillHeight: true

                      Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(8, Math.min(18, Math.round(parent.width * 0.7)))
                        radius: Style.radiusXS
                        color: Style.materialFill(HydraColor.mSurfaceContainerLowest)
                      }

                      Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Math.max(8, Math.min(18, Math.round(parent.width * 0.7)))
                        height: Math.max(modelData.totalSeconds > 0 ? 5 : 0, parent.height * modelData.ratio)
                        radius: Style.radiusXS
                        color: modelData.isToday ? HydraColor.mPrimary : Qt.alpha(HydraColor.mPrimary, 0.45)

                        Behavior on height {
                          enabled: !screenUsageDetails.panelRoot.dashboardPerformanceMode && Style.animationNormal > 0
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
                      color: modelData.isToday ? HydraColor.mPrimary : HydraColor.mOnSurfaceVariant
                      pointSize: Style.fontSizeXXS
                      font.weight: modelData.isToday ? Style.fontWeightBold : Style.fontWeightRegular
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              color: Qt.alpha(HydraColor.mOutline, 0.12)
            }

            // Chart B: 24h Hourly Activity Distribution
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true

                NText {
                  Layout.fillWidth: true
                  text: panelRoot.tr("hourlyActivity")
                  color: HydraColor.mOnSurface
                  font.weight: Style.fontWeightSemiBold
                  pointSize: Style.fontSizeS
                }

                NText {
                  text: "0h — 23h"
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                  font.family: Settings.data.ui.fontFixed
                }
              }

              // 24 Hour Histogram Bars
              RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(52 * panelRoot.panelUnit)
                spacing: Style.marginXXXS

                Repeater {
                  model: 24

                  Item {
                    id: hourBarItem
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property int hourSecs: (screenUsageDetails.rangeStats.hourlyDistribution && screenUsageDetails.rangeStats.hourlyDistribution[hourBarItem.index]) || 0
                    readonly property real hourRatio: screenUsageDetails.rangeStats.maxHourlySeconds > 0 ? (hourBarItem.hourSecs / screenUsageDetails.rangeStats.maxHourlySeconds) : 0
                    readonly property bool isPeak: hourBarItem.index === screenUsageDetails.rangeStats.peakHour && hourBarItem.hourSecs > 0


                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: Math.max(3, Math.min(10, Math.round(parent.width * 0.75)))
                      radius: 2
                      color: Style.materialFill(HydraColor.mSurfaceContainerLowest)
                    }

                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.bottom: parent.bottom
                      width: Math.max(3, Math.min(10, Math.round(parent.width * 0.75)))
                      height: Math.max(hourSecs > 0 ? 3 : 0, parent.height * hourRatio)
                      radius: 2
                      color: isPeak ? HydraColor.mPrimary : Qt.alpha(HydraColor.mPrimary, 0.45)

                      Behavior on height {
                        enabled: !screenUsageDetails.panelRoot.dashboardPerformanceMode && Style.animationNormal > 0
                        NumberAnimation {
                          duration: Style.animationNormal
                          easing.type: Easing.OutCubic
                        }
                      }
                    }
                  }
                }
              }

              // Hourly Axis Labels (0h, 6h, 12h, 18h, 23h)
              RowLayout {
                Layout.fillWidth: true

                NText {
                  text: "0h"
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                  font.family: Settings.data.ui.fontFixed
                }

                Item { Layout.fillWidth: true }

                NText {
                  text: "6h"
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                  font.family: Settings.data.ui.fontFixed
                }

                Item { Layout.fillWidth: true }

                NText {
                  text: "12h"
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                  font.family: Settings.data.ui.fontFixed
                }

                Item { Layout.fillWidth: true }

                NText {
                  text: "18h"
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                  font.family: Settings.data.ui.fontFixed
                }

                Item { Layout.fillWidth: true }

                NText {
                  text: "23h"
                  color: HydraColor.mOnSurfaceVariant
                  pointSize: Style.fontSizeXXS
                  font.family: Settings.data.ui.fontFixed
                }
              }
            }
          }
        }

        // All Applications Ranking Section
        DashboardCard {
          panelRoot: screenUsageDetails.panelRoot
          Layout.fillWidth: true
          implicitHeight: applicationsColumn.implicitHeight + Style.marginM * 2
          color: Style.materialFill(HydraColor.mSurfaceContainerHigh)
          radius: Style.radiusS

          ColumnLayout {
            id: applicationsColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true

              NText {
                Layout.fillWidth: true
                text: panelRoot.tr("allApps")
                color: HydraColor.mOnSurface
                font.weight: Style.fontWeightSemiBold
                pointSize: Style.fontSizeS
              }

              NText {
                text: screenUsageDetails.allApps.length + " " + panelRoot.tr("appsTracked").toLowerCase()
                color: HydraColor.mOnSurfaceVariant
                pointSize: Style.fontSizeXXS
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              Repeater {
                model: screenUsageDetails.allApps

                ScreenUsageDetailRow {
                  required property var modelData
                  panelRoot: screenUsageDetails.panelRoot
                  Layout.fillWidth: true
                  appData: modelData
                  maxSeconds: screenUsageDetails.maxAppSeconds
                }
              }
            }

            NText {
              Layout.fillWidth: true
              visible: screenUsageDetails.allApps.length === 0
              text: panelRoot.tr("screenUsageEmpty")
              color: HydraColor.mOnSurfaceVariant
              pointSize: Style.fontSizeS
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.preferredHeight: Math.round(80 * panelRoot.panelUnit)
            }
          }
        }
      }
    }
  }
}
