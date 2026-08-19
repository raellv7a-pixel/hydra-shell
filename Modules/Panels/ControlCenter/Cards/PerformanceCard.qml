import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: performanceCard

  styleKey: "performance"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "left"
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("performance")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: panelRoot.componentText("performance", true)
        elide: Text.ElideRight
      }

      SubmoduleButton {
        panelRoot: performanceCard.panelRoot
        targetView: "performance"
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      StatTile {
        panelRoot: performanceCard.panelRoot
        Layout.fillWidth: true
        labelText: panelRoot.tr("cpu")
        valueText: Math.round(SystemStatService.cpuUsage) + "%"
        detailText: Math.round(SystemStatService.cpuTemp) + "°C"
        iconName: "cpu"
        ratio: SystemStatService.cpuUsage / 100
        fillColor: SystemStatService.cpuColor
      }

      StatTile {
        panelRoot: performanceCard.panelRoot
        Layout.fillWidth: true
        labelText: panelRoot.tr("ram")
        valueText: Math.round(SystemStatService.memPercent) + "%"
        detailText: SystemStatService.memGb.toFixed(1) + " / " + SystemStatService.memTotalGb.toFixed(1) + " GiB"
        iconName: "device-desktop-analytics"
        ratio: SystemStatService.memPercent / 100
        fillColor: SystemStatService.memColor
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      DiskPager {
        panelRoot: performanceCard.panelRoot
        Layout.fillWidth: true
      }

      MiniMeter {
        panelRoot: performanceCard.panelRoot
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(76 * panelRoot.panelUnit)
        labelText: panelRoot.tr("gpu")
        iconName: "device-desktop"
        valueText: panelRoot.gpuCompactText()
        detailText: panelRoot.gpuNameText()
        ratio: panelRoot.gpuUsageRatio()
        fillColor: SystemStatService.gpuColor
      }
    }

    DashboardCard {
      panelRoot: performanceCard.panelRoot
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NText {
          text: panelRoot.tr("networkTraffic")
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          TrafficTile {
            panelRoot: performanceCard.panelRoot
            Layout.fillWidth: true
            iconName: "download"
            titleText: panelRoot.tr("down")
            valueText: panelRoot.formatBytes(SystemStatService.rxSpeed)
          }

          TrafficTile {
            panelRoot: performanceCard.panelRoot
            Layout.fillWidth: true
            iconName: "upload"
            titleText: panelRoot.tr("up")
            valueText: panelRoot.formatBytes(SystemStatService.txSpeed)
          }
        }
      }
    }
  }
}
