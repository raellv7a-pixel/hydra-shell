pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root

  required property var telemetry
  property string diskPath: "/"

  readonly property int cpuSamples: telemetry.cpuSamples
  readonly property int temperatureSamples: telemetry.temperatureSamples
  readonly property int memorySamples: telemetry.memorySamples
  readonly property int rxSamples: telemetry.rxSamples
  readonly property int txSamples: telemetry.txSamples
  readonly property bool hasMemory: SystemStatService.memTotalGb > 0
  readonly property bool hasTemperature: SystemStatService.cpuTemp > 0
  readonly property bool hasDisk: SystemStatService.diskSizeGb[diskPath] > 0
  readonly property var processes: {
    const entries = telemetry.data.processes || [];
    return entries.slice().sort((a, b) => b.memoryMiB - a.memoryMiB).slice(0, 4);
  }
  readonly property real largestProcess: processes.length ? Math.max(1, processes[0].memoryMiB) : 1
  readonly property var historyMetrics: [
    {
      label: I18n.tr("system-monitor.dashboard.cpu"),
      values: root.cpuSamples ? SystemStatService.cpuHistory.slice(-root.cpuSamples) : [],
      color: SystemStatService.cpuColor,
      maximum: 100,
      unit: "%",
      interval: SystemStatService.cpuUsageIntervalMs
    },
    {
      label: I18n.tr("common.memory"),
      values: root.hasMemory && root.memorySamples ? SystemStatService.memHistory.slice(-root.memorySamples) : [],
      color: HydraColor.mSecondary,
      maximum: 100,
      unit: "%",
      interval: SystemStatService.memIntervalMs
    },
    {
      label: I18n.tr("system-monitor.dashboard.temperature"),
      values: root.hasTemperature && root.temperatureSamples ? SystemStatService.cpuTempHistory.slice(-root.temperatureSamples).map(value => value > 0 ? value : null) : [],
      color: SystemStatService.tempColor,
      maximum: Math.max(100, SystemStatService.cpuTempHistoryMax + 5),
      unit: "°C",
      interval: SystemStatService.cpuUsageIntervalMs
    }
  ]

  spacing: Style.marginXS

  component DetailTile: NBox {
    id: tile
    required property string label
    required property string valueText
    required property string detail
    required property real ratio
    property color accent: HydraColor.mTertiary

    implicitHeight: tileContent.implicitHeight + Style.margin2M
    color: HydraColor.mSurfaceContainerHigh
    border.width: 0

    ColumnLayout {
      id: tileContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginXXS

      NText {
        Layout.fillWidth: true
        text: tile.label
        pointSize: Style.fontSizeXS
        color: HydraColor.mOnSurfaceVariant
      }
      NText {
        Layout.fillWidth: true
        text: tile.valueText
        family: Settings.data.ui.fontFixed
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightSemiBold
      }
      NLinearGauge {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.marginXXS
        orientation: Qt.Horizontal
        ratio: Math.max(0, tile.ratio)
        color: HydraColor.mSurfaceContainerHighest
        fillColor: tile.accent
        Accessible.ignored: true
      }
      NText {
        Layout.fillWidth: true
        text: tile.detail
        pointSize: Style.fontSizeXS
        color: HydraColor.mOnSurfaceVariant
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginXS

    StatGauge {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.cpu")
      valueText: SystemStatService.nproc > 0 ? Math.round(SystemStatService.cpuUsage) + "%" : "—"
      detail: I18n.tr("system-monitor.dashboard.core-count", {
                        count: SystemStatService.nproc
                      })
      ratio: SystemStatService.nproc > 0 ? SystemStatService.cpuUsage / 100 : -1
      accent: SystemStatService.cpuColor
    }
    StatGauge {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("common.memory")
      valueText: root.hasMemory ? Math.round(SystemStatService.memPercent) + "%" : "—"
      detail: root.hasMemory ? Number(SystemStatService.memGb).toFixed(1) + " GiB" : "—"
      ratio: root.hasMemory ? SystemStatService.memPercent / 100 : -1
      accent: HydraColor.mSecondary
    }
    StatGauge {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.temperature")
      valueText: root.hasTemperature ? Math.round(SystemStatService.cpuTemp) + "°C" : "—"
      detail: I18n.tr("system-monitor.dashboard.cpu")
      ratio: root.hasTemperature ? SystemStatService.cpuTemp / 100 : -1
      accent: SystemStatService.tempColor
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: coresContent.implicitHeight + Style.margin2M
    border.width: 0

    ColumnLayout {
      id: coresContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        NText {
          text: I18n.tr("system-monitor.dashboard.cores")
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightSemiBold
        }
        Item {
          Layout.fillWidth: true
        }
        NText {
          Layout.fillWidth: true
          text: I18n.tr("system-monitor.dashboard.load-average-short")
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
          horizontalAlignment: Text.AlignRight
        }
        NText {
          text: SystemStatService.nproc > 0 ? SystemStatService.loadAvg1.toFixed(2) + " / " + SystemStatService.loadAvg5.toFixed(2) + " / " + SystemStatService.loadAvg15.toFixed(2) : "—"
          family: Settings.data.ui.fontFixed
          pointSize: Style.fontSizeXS
        }
      }

      Item {
        id: coresView
        readonly property int columns: Math.max(1, Math.floor(width / ((SystemStatService.coresUsage.length > 99 ? 28 : 22) * Style.uiScaleRatio)))
        Layout.fillWidth: true
        implicitHeight: coreGrid.implicitHeight

        Grid {
          id: coreGrid
          width: coresView.width
          columns: coresView.columns
          columnSpacing: Style.marginXS
          rowSpacing: Style.marginXS

          Repeater {
            model: SystemStatService.coresUsage
            delegate: Column {
              id: core
              required property int index
              required property real modelData
              width: (coreGrid.width - (coreGrid.columns - 1) * coreGrid.columnSpacing) / coreGrid.columns
              spacing: Style.marginXXS

              NLinearGauge {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(Style.marginM, core.width)
                height: Style.marginXL
                orientation: Qt.Vertical
                ratio: core.modelData / 100
                color: HydraColor.mSurfaceContainerHighest
                fillColor: SystemStatService.getCoreUsageColor(core.modelData)
                Accessible.name: I18n.tr("system-monitor.dashboard.core-usage", {
                                           core: core.index + 1,
                                           usage: Math.round(core.modelData)
                                         })
              }
              NText {
                width: parent.width
                text: core.index + 1
                family: Settings.data.ui.fontFixed
                pointSize: Style.fontSizeXS
                horizontalAlignment: Text.AlignHCenter
                color: HydraColor.mOnSurfaceVariant
              }
            }
          }
        }
      }
      NText {
        visible: SystemStatService.coresUsage.length === 0
        text: "—"
        pointSize: Style.fontSizeXS
        color: HydraColor.mOnSurfaceVariant
      }
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: memoryContent.implicitHeight + Style.margin2M
    border.width: 0

    RowLayout {
      id: memoryContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginL

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Style.marginXXS

        StatMeter {
          Layout.fillWidth: true
          label: I18n.tr("common.memory")
          valueText: root.hasMemory ? Math.round(SystemStatService.memPercent) + "%" : "—"
          ratio: root.hasMemory ? SystemStatService.memPercent / 100 : -1
          accent: HydraColor.mSecondary
        }
        NText {
          Layout.fillWidth: true
          text: root.hasMemory ? I18n.tr("system-monitor.dashboard.memory-used-total", {
                                           used: Number(SystemStatService.memGb).toFixed(1),
                                           total: Number(SystemStatService.memTotalGb).toFixed(1)
                                         }) : "—"
          pointSize: Style.fontSizeXS
          family: Settings.data.ui.fontFixed
        }
        NText {
          Layout.fillWidth: true
          text: root.telemetry.data.memCacheGb !== null && root.telemetry.data.memCacheGb !== undefined ? I18n.tr("system-monitor.dashboard.cache", {
                                                                                                                    value: Number(root.telemetry.data.memCacheGb).toFixed(1)
                                                                                                                  }) : I18n.tr("system-monitor.dashboard.cache", {
                                                                                                                                 value: "—"
                                                                                                                               })
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
        }
        NText {
          Layout.fillWidth: true
          text: root.hasMemory ? I18n.tr("system-monitor.dashboard.available", {
                                           value: Math.max(0, SystemStatService.memTotalGb - SystemStatService.memGb).toFixed(1)
                                         }) : I18n.tr("system-monitor.dashboard.available", {
                                                        value: "—"
                                                      })
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
        }
      }

      ColumnLayout {
        id: processColumn
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Style.marginXXS

        NText {
          Layout.fillWidth: true
          text: I18n.tr("system-monitor.dashboard.top-memory-processes")
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
        }
        Repeater {
          model: root.processes
          delegate: Item {
            id: processRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: processText.implicitHeight + Style.marginXXS

            Rectangle {
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              width: parent.width * Math.min(1, processRow.modelData.memoryMiB / root.largestProcess)
              height: Style.marginXXS
              radius: height / 2
              color: HydraColor.mSecondaryContainer
              Accessible.ignored: true
            }
            RowLayout {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              spacing: Style.marginXS
              NText {
                id: processText
                Layout.fillWidth: true
                text: processRow.modelData.name
                pointSize: Style.fontSizeXS
              }
              NText {
                text: Math.round(processRow.modelData.memoryMiB) + " MiB"
                family: Settings.data.ui.fontFixed
                pointSize: Style.fontSizeXS
                color: HydraColor.mOnSurfaceVariant
              }
            }
          }
        }
        NText {
          Layout.fillWidth: true
          visible: root.processes.length === 0
          text: I18n.tr("system-monitor.dashboard.no-processes")
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginXS

    DetailTile {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.frequency")
      valueText: SystemStatService.cpuFreqRatio > 0 ? SystemStatService.cpuFreq.replace("GHz", " GHz") : "—"
      detail: I18n.tr("system-monitor.dashboard.cpu")
      ratio: SystemStatService.cpuFreqRatio
      accent: SystemStatService.cpuColor
    }
    DetailTile {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.disk-path", {
                       path: root.diskPath
                     })
      valueText: root.hasDisk ? Math.round(SystemStatService.diskPercents[root.diskPath]) + "%" : "—"
      detail: root.hasDisk && SystemStatService.diskAvailableGb[root.diskPath] !== undefined ? I18n.tr("system-monitor.dashboard.disk-free", {
                                                                                                         value: Number(SystemStatService.diskAvailableGb[root.diskPath]).toFixed(1)
                                                                                                       }) : "—"
      ratio: root.hasDisk ? SystemStatService.diskPercents[root.diskPath] / 100 : -1
    }
    DetailTile {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.swap")
      valueText: root.hasMemory ? Math.round(SystemStatService.swapPercent) + "%" : "—"
      detail: root.hasMemory ? I18n.tr("system-monitor.dashboard.swap-used-total", {
                                         used: Number(SystemStatService.swapGb).toFixed(1),
                                         total: Number(SystemStatService.swapTotalGb).toFixed(1)
                                       }) : "—"
      ratio: root.hasMemory ? SystemStatService.swapPercent / 100 : -1
      accent: HydraColor.mSecondary
    }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: networkContent.implicitHeight + Style.margin2M
    border.width: 0

    ColumnLayout {
      id: networkContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: Style.marginXXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        NText {
          text: I18n.tr("common.network")
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightSemiBold
        }
        Item {
          Layout.fillWidth: true
        }
        NText {
          text: I18n.tr("system-monitor.dashboard.rx", {
                          value: SystemStatService.formatSpeed(SystemStatService.rxSpeed) + "/s"
                        })
          pointSize: Style.fontSizeXS
          family: Settings.data.ui.fontFixed
          color: HydraColor.mPrimary
        }
        NText {
          text: I18n.tr("system-monitor.dashboard.tx", {
                          value: SystemStatService.formatSpeed(SystemStatService.txSpeed) + "/s"
                        })
          pointSize: Style.fontSizeXS
          family: Settings.data.ui.fontFixed
          color: HydraColor.mSecondary
        }
      }
      NGraph {
        Layout.fillWidth: true
        Layout.preferredHeight: 28 * Style.uiScaleRatio
        values: root.rxSamples ? SystemStatService.rxSpeedHistory.slice(-root.rxSamples) : []
        values2: root.txSamples ? SystemStatService.txSpeedHistory.slice(-root.txSamples) : []
        maxValue: Math.max(SystemStatService.rxMaxSpeed, SystemStatService.txMaxSpeed)
        maxValue2: maxValue
        color: HydraColor.mPrimary
        color2: HydraColor.mSecondary
        strokeWidth: Math.max(1, Style.uiScaleRatio)
        fill: true
        updateInterval: SystemStatService.networkIntervalMs

        NText {
          anchors.centerIn: parent
          visible: root.rxSamples < 4 && root.txSamples < 4
          text: I18n.tr("system-monitor.dashboard.collecting")
          pointSize: Style.fontSizeXS
          color: HydraColor.mOnSurfaceVariant
        }
      }
    }
  }

  StatHistory {
    Layout.fillWidth: true
    metrics: root.historyMetrics
  }
}
