import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: performanceDetailsCard

  styleKey: "performance"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"
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

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("performance")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NText {
        text: panelRoot.tr("live")
        pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: Color.mPrimary
      }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: Style.marginM
      rowSpacing: Style.marginM

      DetailMetricTile {
        panelRoot: performanceDetailsCard.panelRoot
        Layout.fillWidth: true
        titleText: panelRoot.tr("cpu")
        valueText: panelRoot.percentText(SystemStatService.cpuUsage)
        detailText: Math.round(SystemStatService.cpuTemp) + "°C · " + SystemStatService.cpuFreq
        iconName: "cpu"
        fillColor: SystemStatService.cpuColor
      }

      DetailMetricTile {
        panelRoot: performanceDetailsCard.panelRoot
        Layout.fillWidth: true
        titleText: panelRoot.tr("ram")
        valueText: panelRoot.percentText(SystemStatService.memPercent)
        detailText: panelRoot.formatGb(SystemStatService.memGb) + " / " + panelRoot.formatGb(SystemStatService.memTotalGb)
        iconName: "device-desktop-analytics"
        fillColor: SystemStatService.memColor
      }

      DetailMetricTile {
        panelRoot: performanceDetailsCard.panelRoot
        Layout.fillWidth: true
        titleText: panelRoot.tr("disk")
        valueText: panelRoot.percentText(panelRoot.primaryDiskPercent())
        detailText: panelRoot.diskLabel(Settings.data.controlCenter.diskPath || "/")
        iconName: "database"
        fillColor: SystemStatService.getDiskColor(Settings.data.controlCenter.diskPath || "/")
      }

      DetailMetricTile {
        panelRoot: performanceDetailsCard.panelRoot
        Layout.fillWidth: true
        titleText: panelRoot.tr("gpu")
        valueText: panelRoot.gpuCompactText()
        valuePointSize: Style.fontSizeL
        detailText: panelRoot.gpuNameText()
        iconName: "device-desktop"
        fillColor: SystemStatService.gpuColor
      }
    }

    ProcessUsageCard {
      panelRoot: performanceDetailsCard.panelRoot
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: Math.round(230 * panelRoot.panelUnit)
    }

    DashboardCard {
      panelRoot: performanceDetailsCard.panelRoot
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(120 * panelRoot.panelUnit)
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          text: panelRoot.tr("resources")
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
        }

        ResourceLine {
          iconName: "cpu"
          labelText: panelRoot.tr("cores")
          valueText: String(SystemStatService.nproc || "--")
        }

        ResourceLine {
          iconName: "activity"
          labelText: panelRoot.tr("loadAverage")
          valueText: SystemStatService.loadAvg1.toFixed(2) + " / " + SystemStatService.loadAvg5.toFixed(2) + " / " + SystemStatService.loadAvg15.toFixed(2)
        }

        ResourceLine {
          iconName: "database"
          labelText: panelRoot.tr("swap")
          valueText: panelRoot.formatGb(SystemStatService.swapGb) + " / " + panelRoot.formatGb(SystemStatService.swapTotalGb)
        }

        ResourceLine {
          iconName: "device-desktop"
          labelText: panelRoot.tr("system")
          valueText: HostService.osPretty || "Linux"
        }
      }
    }
  }
}
