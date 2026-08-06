import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  Component.onCompleted: SystemStatService.registerComponent("panel-systemstats")
  Component.onDestruction: SystemStatService.unregisterComponent("panel-systemstats")

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.28)

  panelContent: Item {
    id: panelContent
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L
    readonly property real cardHeight: 96 * Style.uiScaleRatio

    // Get diskPath from bar's SystemMonitor widget if available, otherwise use "/"
    readonly property string diskPath: {
      const sysMonWidget = BarService.lookupWidget("SystemMonitor");
      if (sysMonWidget && sysMonWidget.diskPath) {
        return sysMonWidget.diskPath;
      }
      return "/";
    }

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // HEADER
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusL

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          Rectangle {
            Layout.preferredWidth: Style.baseWidgetSize * 0.8
            Layout.preferredHeight: Style.baseWidgetSize * 0.8
            radius: height / 2
            color: Color.mPrimaryContainer

            NIcon {
              anchors.centerIn: parent
              icon: "device-analytics"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }
          }

          NText {
            text: I18n.tr("system-monitor.title")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              root.close();
            }
          }
        }
      }

      // CPU Card (dual-line: usage % + temperature °C)
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: panelContent.cardHeight
        color: Color.mSurfaceContainer
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NIcon {
              icon: "cpu-usage"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("system-monitor.cpu-usage")
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              font.weight: Style.fontWeightMedium
            }

            Item {
              Layout.fillWidth: true
            }

            NIcon {
              icon: "cpu-temperature"
              pointSize: Style.fontSizeXS
              color: Color.mSecondary
            }

            NText {
              text: `${Math.round(SystemStatService.cpuTemp)}°C`
              pointSize: Style.fontSizeXS
              color: Color.mSecondary
              font.family: Settings.data.ui.fontFixed
            }

            NText {
              text: `${Math.round(SystemStatService.cpuUsage)}% · ${SystemStatService.cpuFreq.replace(/[^0-9.]/g, "")} GHz`
              pointSize: Style.fontSizeXS
              color: Color.mPrimary
              font.family: Settings.data.ui.fontFixed
              font.weight: Style.fontWeightBold
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Color.mSurfaceContainerLow
            radius: Style.iRadiusM

            NGraph {
              anchors.fill: parent
              anchors.margins: Style.marginXS
              values: SystemStatService.cpuHistory
              values2: SystemStatService.cpuTempHistory
              minValue: 0
              maxValue: 100
              minValue2: Math.max(SystemStatService.cpuTempHistoryMin - 5, 0)
              maxValue2: Math.max(SystemStatService.cpuTempHistoryMax + 5, 1)
              color: Color.mPrimary
              color2: Color.mSecondary
              strokeWidth: Math.max(1, Style.uiScaleRatio)
              fill: true
              fillOpacity: 0.18
              updateInterval: SystemStatService.cpuUsageIntervalMs
            }
          }
        }
      }

      // Memory Card (single-line + optional swap indicator)
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: panelContent.cardHeight
        color: Color.mSurfaceContainer
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NIcon {
              icon: "memory"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("common.memory")
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              font.weight: Style.fontWeightMedium
            }

            Item {
              Layout.fillWidth: true
            }

            NText {
              text: `${Math.round(SystemStatService.memPercent)}% · ${(SystemStatService.memGb).toFixed(1)} GiB`
              pointSize: Style.fontSizeXS
              color: Color.mPrimary
              font.family: Settings.data.ui.fontFixed
              font.weight: Style.fontWeightBold
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Color.mSurfaceContainerLow
            radius: Style.iRadiusM

            NGraph {
              anchors.fill: parent
              anchors.margins: Style.marginXS
              values: SystemStatService.memHistory
              minValue: 0
              maxValue: 100
              color: Color.mPrimary
              strokeWidth: Math.max(1, Style.uiScaleRatio)
              fill: true
              fillOpacity: 0.18
              updateInterval: SystemStatService.memIntervalMs
            }
          }
        }
      }

      // Network Card (dual-line: RX + TX speeds)
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: panelContent.cardHeight
        color: Color.mSurfaceContainer
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NIcon {
              icon: "network"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("common.network")
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              font.weight: Style.fontWeightMedium
            }

            Item {
              Layout.fillWidth: true
            }

            NIcon {
              icon: "download-speed"
              pointSize: Style.fontSizeXS
              color: Color.mPrimary
            }

            NText {
              text: SystemStatService.formatSpeed(SystemStatService.rxSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
              pointSize: Style.fontSizeXS
              color: Color.mPrimary
              font.family: Settings.data.ui.fontFixed
            }

            NIcon {
              icon: "upload-speed"
              pointSize: Style.fontSizeXS
              color: Color.mSecondary
            }

            NText {
              text: SystemStatService.formatSpeed(SystemStatService.txSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s"
              pointSize: Style.fontSizeXS
              color: Color.mSecondary
              font.family: Settings.data.ui.fontFixed
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Color.mSurfaceContainerLow
            radius: Style.iRadiusM

            NGraph {
              anchors.fill: parent
              anchors.margins: Style.marginXS
              values: SystemStatService.rxSpeedHistory
              values2: SystemStatService.txSpeedHistory
              minValue: 0
              maxValue: SystemStatService.rxMaxSpeed
              minValue2: 0
              maxValue2: SystemStatService.txMaxSpeed
              color: Color.mPrimary
              color2: Color.mSecondary
              strokeWidth: Math.max(1, Style.uiScaleRatio)
              fill: true
              fillOpacity: 0.18
              updateInterval: SystemStatService.networkIntervalMs
              animateScale: true
            }
          }
        }
      }

      // Detailed Stats section
      NBox {
        Layout.fillWidth: true
        implicitHeight: detailsColumn.implicitHeight + Style.margin2M
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusL

        ColumnLayout {
          id: detailsColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          // Load Average
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: SystemStatService.nproc > 0

            NIcon {
              icon: "cpu-usage"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("system-monitor.load-average") + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            NText {
              text: `${SystemStatService.loadAvg1.toFixed(2)} • ${SystemStatService.loadAvg5.toFixed(2)} • ${SystemStatService.loadAvg15.toFixed(2)}`
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
            }
          }

          // GPU Temperature (only if available)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: SystemStatService.gpuAvailable

            NIcon {
              icon: "gpu-temperature"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("system-monitor.gpu-temp") + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            NText {
              text: `${Math.round(SystemStatService.gpuTemp)}°C`
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
            }
          }

          // Disk usage
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "storage"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("system-monitor.disk") + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            NText {
              text: {
                const usedGb = SystemStatService.diskUsedGb[panelContent.diskPath] || 0;
                const sizeGb = SystemStatService.diskSizeGb[panelContent.diskPath] || 0;
                const percent = SystemStatService.diskPercents[panelContent.diskPath] || 0;
                return `${percent}% (${usedGb.toFixed(1)} / ${sizeGb.toFixed(1)} GB)`;
              }
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideMiddle
            }
          }

          // Swap details (only visible if swap is enabled)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: SystemStatService.swapTotalGb > 0

            NIcon {
              icon: "exchange"
              pointSize: Style.fontSizeM
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("bar.system-monitor.swap-usage-label") + ":"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            NText {
              text: `${(SystemStatService.swapGb).toFixed(1)} / ${(SystemStatService.swapTotalGb).toFixed(1)} GiB`
              pointSize: Style.fontSizeXS
              color: Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }
    }
  }
}
