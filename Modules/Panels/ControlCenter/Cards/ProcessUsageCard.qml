import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Io
import qs.Services.System
DashboardCard {
  id: processUsageCard

  styleKey: "performance"
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS
  readonly property real highestValue: processModel.count > 0 ? Math.max(0.01, Number(processModel.get(0).usage[panelRoot.processUsageMetric] || 0)) : 1

  function refreshModel() {
    const rows = panelRoot.rankedProcessUsageRows();
    for (let targetIndex = 0; targetIndex < rows.length; targetIndex++) {
      let sourceIndex = -1;
      for (let currentIndex = targetIndex; currentIndex < processModel.count; currentIndex++) {
        if (processModel.get(currentIndex).usage.processName === rows[targetIndex].processName) {
          sourceIndex = currentIndex;
          break;
        }
      }

      if (sourceIndex < 0)
        processModel.insert(targetIndex, {
                              "usage": rows[targetIndex]
                            });
      else if (sourceIndex !== targetIndex)
        processModel.move(sourceIndex, targetIndex, 1);

      processModel.setProperty(targetIndex, "usage", rows[targetIndex]);
    }

    while (processModel.count > rows.length)
      processModel.remove(processModel.count - 1);
  }

  Component.onCompleted: refreshModel()

  Connections {
    target: panelRoot
    function onProcessUsageRowsChanged() {
      processUsageCard.refreshModel();
    }
    function onProcessUsageMetricChanged() {
      processUsageCard.refreshModel();
    }
  }

  ListModel {
    id: processModel
    dynamicRoles: true
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          text: panelRoot.tr("applicationUsage")
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
        }

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("applicationUsageSubtitle")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }
      }

      NIcon {
        icon: "activity"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }
    }

    NTabBar {
      id: processMetricTabs
      Layout.fillWidth: true
      tabHeight: Math.round(30 * panelRoot.panelUnit)
      distributeEvenly: true
      currentIndex: panelRoot.processUsageMetric === "ram" ? 1 : (panelRoot.processUsageMetric === "gpu" ? 2 : 0)
      onCurrentIndexChanged: panelRoot.processUsageMetric = currentIndex === 1 ? "ram" : (currentIndex === 2 ? "gpu" : "cpu")

      NTabButton {
        text: panelRoot.tr("cpu")
        icon: "cpu"
        pointSize: Style.fontSizeXS
        tabIndex: 0
        checked: processMetricTabs.currentIndex === 0
      }

      NTabButton {
        text: panelRoot.tr("ram")
        icon: "device-desktop-analytics"
        pointSize: Style.fontSizeXS
        tabIndex: 1
        checked: processMetricTabs.currentIndex === 1
      }

      NTabButton {
        text: panelRoot.tr("gpu")
        icon: "device-desktop"
        pointSize: Style.fontSizeXS
        tabIndex: 2
        checked: processMetricTabs.currentIndex === 2
      }
    }

    ListView {
      id: processList
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: processModel.count > 0
      model: processModel
      spacing: Style.marginXXS
      interactive: contentHeight > height
      clip: true

      delegate: Rectangle {
        id: processRow

        required property var usage
        required property int index

        width: ListView.view.width
        height: Math.max(Math.round(44 * panelRoot.panelUnit), (ListView.view.height - Math.max(0, processModel.count - 1) * processList.spacing) / Math.max(1, processModel.count))
        radius: Style.radiusS
        color: processHover.hovered ? panelRoot.m3PrimaryContainer : panelRoot.m3SurfaceContainerHighest
        scale: processHover.hovered ? 1.008 : 1
        transformOrigin: Item.Center
        readonly property real metricValue: Number(usage[panelRoot.processUsageMetric] || 0)
        readonly property real metricRatio: panelRoot.clamp(metricValue / processUsageCard.highestValue, 0, 1)

        Behavior on color {
          ColorAnimation {
            duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
            easing.type: Easing.OutCubic
          }
        }

        Behavior on scale {
          ScaleAnimator {
            duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
            easing.type: Easing.OutCubic
          }
        }

        HoverHandler {
          id: processHover
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginS

          Rectangle {
            Layout.preferredWidth: Math.round(30 * panelRoot.panelUnit)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Style.radiusS
            color: Qt.alpha(Color.mPrimary, 0.12)

            IconImage {
              anchors.fill: parent
              anchors.margins: Style.marginXS
              source: ThemeIcons.iconFromName(processRow.usage.icon, "application-x-executable")
              asynchronous: true
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NText {
                Layout.fillWidth: true
                text: processRow.usage.displayName
                color: Color.mOnSurface
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightSemiBold
                elide: Text.ElideRight
              }

              NText {
                text: panelRoot.processUsageValue(processRow.usage, panelRoot.processUsageMetric)
                color: Color.mPrimary
                pointSize: Style.fontSizeS
                font.family: Settings.data.ui.fontFixed
                font.weight: Style.fontWeightSemiBold
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.max(4, Math.round(5 * panelRoot.panelUnit))

              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Color.mOutline, 0.16)
              }

              Rectangle {
                width: parent.width * processRow.metricRatio
                height: parent.height
                radius: height / 2
                color: Color.mPrimary

                Behavior on width {
                  NumberAnimation {
                    duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
                    easing.type: Easing.OutCubic
                  }
                }
              }
            }
          }
        }
      }

      displaced: Transition {
        NumberAnimation {
          properties: "y"
          duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
          easing.type: Easing.OutCubic
        }
      }
    }

    RowLayout {
      visible: processModel.count === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginS

      Item {
        Layout.fillWidth: true
      }

      NIcon {
        icon: panelRoot.processUsageMetric === "gpu" ? "device-desktop-off" : "hourglass-empty"
        pointSize: Style.fontSizeL
        color: Color.mOnSurfaceVariant
      }

      NText {
        text: panelRoot.processUsageMetric === "gpu" ? panelRoot.tr("noGpuProcesses") : panelRoot.tr("noActiveProcesses")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      Item {
        Layout.fillWidth: true
      }
    }
  }
}
