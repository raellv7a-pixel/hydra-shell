pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  required property var telemetry
  readonly property var gpu: telemetry.data.gpu || ({})
  readonly property real vramRatio: gpu.vramTotalMiB > 0 && gpu.vramUsedMiB !== null ? gpu.vramUsedMiB / gpu.vramTotalMiB : -1
  readonly property var processes: gpu.processes || []
  spacing: Style.marginS

  function metric(value, unit) {
    return value !== null && value !== undefined && Number.isFinite(value) ? Math.round(value) + unit : "—";
  }

  NText {
    Layout.fillWidth: true
    text: root.gpu.name || I18n.tr("system-monitor.dashboard.gpu-unavailable")
    font.weight: Style.fontWeightSemiBold
    pointSize: Style.fontSizeS
    elide: Text.ElideRight
  }
  NText {
    Layout.fillWidth: true
    text: [root.gpu.driver, root.gpu.pcie, root.gpu.state].filter(v => !!v).join(" · ") || I18n.tr("system-monitor.dashboard.gpu-sensor-note")
    color: HydraColor.mOnSurfaceVariant
    pointSize: Style.fontSizeXXS
    wrapMode: Text.Wrap
  }
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    StatGauge {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.gpu-core")
      valueText: root.metric(root.gpu.usage, "%")
      ratio: root.gpu.usage !== null && root.gpu.usage !== undefined ? root.gpu.usage / 100 : -1
      detail: I18n.tr("system-monitor.dashboard.utilization")
      accent: HydraColor.mPrimary
    }
    StatGauge {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.temperature")
      valueText: root.metric(root.gpu.temp, "°")
      ratio: root.gpu.temp !== null && root.gpu.temp !== undefined ? root.gpu.temp / 100 : -1
      detail: I18n.tr("system-monitor.dashboard.gpu-sensor")
      accent: SystemStatService.gpuColor
    }
    StatGauge {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      label: I18n.tr("system-monitor.dashboard.power")
      valueText: root.metric(root.gpu.power, "W")
      ratio: root.gpu.powerLimit > 0 && root.gpu.power !== null ? root.gpu.power / root.gpu.powerLimit : -1
      detail: root.gpu.powerLimit > 0 ? I18n.tr("system-monitor.dashboard.power-budget", {
                                                  value: root.metric(root.gpu.powerLimit, " W")
                                                }) : I18n.tr("system-monitor.dashboard.sensor-unavailable")
      accent: HydraColor.mTertiary
    }
  }
  NBox {
    Layout.fillWidth: true
    implicitHeight: limits.implicitHeight + Style.margin2M
    border.width: 0
    ColumnLayout {
      id: limits
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS
      NText {
        text: I18n.tr("system-monitor.dashboard.limiters")
        pointSize: Style.fontSizeXXS
        color: HydraColor.mOnSurfaceVariant
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        Repeater {
          model: [
            {
              label: I18n.tr("system-monitor.dashboard.power"),
              value: root.gpu.limitPower
            },
            {
              label: I18n.tr("system-monitor.dashboard.thermal"),
              value: root.gpu.limitThermal
            },
            {
              label: I18n.tr("system-monitor.dashboard.hardware"),
              value: root.gpu.limitHardware
            }
          ]
          NText {
            required property var modelData
            Layout.fillWidth: true
            text: (modelData.value === true ? "● " : modelData.value === false ? "○ " : "— ") + modelData.label
            color: modelData.value === true ? HydraColor.mError : HydraColor.mOnSurfaceVariant
            pointSize: Style.fontSizeXXS
            elide: Text.ElideRight
            Accessible.name: modelData.label + ": " + (modelData.value === true ? I18n.tr("system-monitor.dashboard.active") : modelData.value === false ? I18n.tr("system-monitor.dashboard.inactive") : I18n.tr("system-monitor.dashboard.sensor-unavailable"))
          }
        }
      }
    }
  }
  NBox {
    Layout.fillWidth: true
    implicitHeight: memory.implicitHeight + Style.margin2M
    border.width: 0
    ColumnLayout {
      id: memory
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS
      StatMeter {
        Layout.fillWidth: true
        label: "VRAM"
        ratio: root.vramRatio
        valueText: root.vramRatio >= 0 ? (root.gpu.vramUsedMiB / 1024).toFixed(1) + " / " + (root.gpu.vramTotalMiB / 1024).toFixed(1) + " GiB · " + Math.round(root.vramRatio * 100) + "%" : "—"
        accent: HydraColor.mSecondary
      }
      Repeater {
        model: root.processes.slice(0, 4)
        RowLayout {
          id: gpuProcess
          required property var modelData
          Layout.fillWidth: true
          NText {
            Layout.preferredWidth: memory.width * 0.32
            text: gpuProcess.modelData.name
            pointSize: Style.fontSizeXXS
            elide: Text.ElideRight
          }
          NLinearGauge {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.borderM
            orientation: Qt.Horizontal
            ratio: gpuProcess.modelData.memoryMiB / Math.max(1, root.processes[0].memoryMiB)
            fillColor: HydraColor.mSecondary
            color: HydraColor.mSurfaceContainerHighest
          }
          NText {
            Layout.preferredWidth: 65 * Style.uiScaleRatio
            text: root.metric(gpuProcess.modelData.memoryMiB, " MiB")
            pointSize: Style.fontSizeXXS
            horizontalAlignment: Text.AlignRight
            font.family: Settings.data.ui.fontFixed
          }
        }
      }
      NText {
        Layout.fillWidth: true
        visible: root.processes.length === 0
        text: root.gpu.processes === null || root.gpu.processes === undefined ? I18n.tr("system-monitor.dashboard.processes-unavailable") : I18n.tr("system-monitor.dashboard.no-gpu-processes")
        pointSize: Style.fontSizeXXS
        color: HydraColor.mOnSurfaceVariant
        wrapMode: Text.Wrap
      }
    }
  }
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    Repeater {
      model: [
        {
          label: I18n.tr("system-monitor.dashboard.fan"),
          value: root.metric(root.gpu.fan, root.gpu.fanUnit === "RPM" ? " RPM" : "%"),
          ratio: root.gpu.fanUnit === "%" ? (root.gpu.fan || 0) / 100 : 0,
          accent: HydraColor.mTertiary
        },
        {
          label: I18n.tr("system-monitor.dashboard.core-clock"),
          value: root.metric(root.gpu.coreClock, " MHz"),
          ratio: 0,
          accent: HydraColor.mPrimary
        },
        {
          label: I18n.tr("system-monitor.dashboard.memory-clock"),
          value: root.metric(root.gpu.memoryClock, " MHz"),
          ratio: 0,
          accent: HydraColor.mSecondary
        }
      ]
      NBox {
        id: gpuTile
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 64 * Style.uiScaleRatio
        border.width: 0
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS
          NText {
            Layout.fillWidth: true
            text: gpuTile.modelData.label
            pointSize: Style.fontSizeXXS
            color: HydraColor.mOnSurfaceVariant
            elide: Text.ElideRight
          }
          NText {
            Layout.fillWidth: true
            text: gpuTile.modelData.value
            pointSize: Style.fontSizeXS
            font.family: Settings.data.ui.fontFixed
            elide: Text.ElideRight
          }
        }
      }
    }
  }
  StatHistory {
    Layout.fillWidth: true
    metrics: [
      {
        label: I18n.tr("system-monitor.dashboard.usage"),
        values: root.telemetry.gpuUsageHistory,
        color: HydraColor.mPrimary,
        maximum: 100,
        unit: "%",
        interval: root.telemetry.intervalMs
      },
      {
        label: I18n.tr("system-monitor.dashboard.temperature-short"),
        values: root.telemetry.gpuTempHistory,
        color: HydraColor.mTertiary,
        maximum: 100,
        unit: "°C",
        interval: root.telemetry.intervalMs
      },
      {
        label: I18n.tr("system-monitor.dashboard.power"),
        values: root.telemetry.gpuPowerHistory,
        color: HydraColor.mTertiary,
        maximum: Math.max(root.gpu.powerLimit || 0, ...root.telemetry.gpuPowerHistory.filter(v => v !== null), 1),
        unit: "W",
        interval: root.telemetry.intervalMs
      },
      {
        label: "VRAM",
        values: root.telemetry.gpuVramHistory,
        color: HydraColor.mSecondary,
        maximum: 100,
        unit: "%",
        interval: root.telemetry.intervalMs
      }
    ]
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("system-monitor.dashboard.dedicated-gpu")
    description: I18n.tr("system-monitor.dashboard.dedicated-gpu-note")
    checked: Settings.data.systemMonitor.enableDgpuMonitoring
    onToggled: value => Settings.data.systemMonitor.enableDgpuMonitoring = value
  }
}
