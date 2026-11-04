pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  property bool active: true
  property string componentId: "panel-systemstats"
  property string diskPath: "/"
  property alias currentPage: tabs.currentIndex
  readonly property alias telemetry: telemetry
  signal closeRequested
  spacing: Style.marginM

  property bool registered: false
  property bool initialized: false
  function syncRegistration() {
    if (!initialized || active === registered)
      return;
    if (active)
      SystemStatService.registerComponent(componentId);
    else
      SystemStatService.unregisterComponent(componentId);
    registered = active;
  }
  onActiveChanged: syncRegistration()
  Component.onCompleted: {
    initialized = true;
    syncRegistration();
  }
  Component.onDestruction: {
    if (registered)
      SystemStatService.unregisterComponent(componentId);
  }

  Telemetry {
    id: telemetry
    active: root.active && !SystemStatService._lockScreenActive
    gpuActive: root.currentPage === 1
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM
    NIcon {
      icon: "device-analytics"
      color: HydraColor.mPrimary
      pointSize: Style.fontSizeXL
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS
      NText {
        Layout.fillWidth: true
        text: I18n.tr("system-monitor.title")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
      }
      NText {
        Layout.fillWidth: true
        text: I18n.tr("system-monitor.dashboard.uptime", {
                        hours: Math.floor((telemetry.data.uptime || 0) / 3600),
                        minutes: Math.floor((telemetry.data.uptime || 0) / 60) % 60,
                        threads: SystemStatService.nproc
                      })
        color: HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeXXS
        elide: Text.ElideRight
      }
    }
    NIconButton {
      icon: "close"
      tooltipText: I18n.tr("common.close")
      baseSize: Style.baseWidgetSize * 0.8
      onClicked: root.closeRequested()
    }
  }
  NTabBar {
    id: tabs
    Layout.fillWidth: true
    tabHeight: Style.baseWidgetSize
    NTabButton {
      id: systemTab
      text: I18n.tr("system-monitor.dashboard.system")
      icon: "cpu"
      checked: root.currentPage === 0
      tabIndex: 0
      Keys.onRightPressed: {
        root.currentPage = 1;
        gpuTab.forceActiveFocus(Qt.TabFocusReason);
      }
    }
    NTabButton {
      id: gpuTab
      text: "GPU"
      icon: "device-desktop-analytics"
      checked: root.currentPage === 1
      tabIndex: 1
      Keys.onLeftPressed: {
        root.currentPage = 0;
        systemTab.forceActiveFocus(Qt.TabFocusReason);
      }
    }
  }
  NScrollView {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    horizontalPolicy: ScrollBar.AlwaysOff
    showGradientMasks: false
    contentWidth: availableWidth
    contentHeight: pageLoader.status === Loader.Ready ? (pageLoader.item as Item).implicitHeight : 0
    clip: true
    Loader {
      id: pageLoader
      width: scroll.availableWidth
      active: root.active
      sourceComponent: root.currentPage === 0 ? systemPage : gpuPage
      onSourceComponentChanged: {
        if (scroll._internalFlickable)
          scroll._internalFlickable.contentY = 0;
      }
    }
  }
  RowLayout {
    Layout.fillWidth: true
    NText {
      Layout.fillWidth: true
      text: telemetry.data.cpuName || I18n.tr("system-monitor.dashboard.collecting")
      pointSize: Style.fontSizeXXS
      color: HydraColor.mOnSurfaceVariant
      elide: Text.ElideRight
    }
    NButton {
      text: I18n.tr("system-monitor.dashboard.copy-summary")
      icon: "copy"
      fontSize: Style.fontSizeXS
      backgroundColor: HydraColor.mSecondaryContainer
      textColor: HydraColor.mOnSecondaryContainer
      hoverColor: backgroundColor
      onClicked: {
        const summary = {
          cpu: {
            name: telemetry.data.cpuName,
            usage: SystemStatService.cpuUsage,
            temperature: SystemStatService.cpuTemp,
            frequency: SystemStatService.cpuFreq,
            load: [SystemStatService.loadAvg1, SystemStatService.loadAvg5, SystemStatService.loadAvg15]
          },
          memory: {
            usedGiB: SystemStatService.memGb,
            totalGiB: SystemStatService.memTotalGb,
            swapGiB: SystemStatService.swapGb
          },
          network: {
            rxBytesPerSecond: SystemStatService.rxSpeed,
            txBytesPerSecond: SystemStatService.txSpeed
          },
          disk: {
            path: root.diskPath,
            usedGB: SystemStatService.diskUsedGb[root.diskPath],
            totalGB: SystemStatService.diskSizeGb[root.diskPath]
          },
          gpu: telemetry.data.gpu
        };
        Quickshell.execDetached(["wl-copy", JSON.stringify(summary, null, 2)]);
        ToastService.showNotice(I18n.tr("system-monitor.title"), I18n.tr("common.copied-to-clipboard"));
      }
    }
  }
  Component {
    id: systemPage
    SystemOverview {
      telemetry: root.telemetry
      diskPath: root.diskPath
    }
  }
  Component {
    id: gpuPage
    GpuOverview {
      telemetry: root.telemetry
    }
  }
}
