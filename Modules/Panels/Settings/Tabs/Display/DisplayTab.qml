pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import qs.Services.Compositor
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "display"

  // Time dropdown options (00:00 .. 23:30)
  ListModel {
    id: timeOptions
  }

  function populateTimeOptions() {
    for (var h = 0; h < 24; h++) {
      for (var m = 0; m < 60; m += 30) {
        var hh = ("0" + h).slice(-2);
        var mm = ("0" + m).slice(-2);
        var key = hh + ":" + mm;
        timeOptions.append({
                             "key": key,
                             "name": key
                           });
      }
    }
  }

  Component.onCompleted: {
    Qt.callLater(populateTimeOptions);
  }

  // Check for wlsunset availability when enabling Night Light
  Process {
    id: wlsunsetCheck
    command: ["sh", "-c", "command -v wlsunset"]
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        Settings.data.nightLight.enabled = true;
        NightLightService.apply();
        ToastService.showNotice(I18n.tr("common.night-light"), I18n.tr("common.enabled"), "nightlight-on");
      } else {
        Settings.data.nightLight.enabled = false;
        ToastService.showWarning(I18n.tr("common.night-light"), I18n.tr("toast.night-light.not-installed"));
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  groups: [
    { key: "brightness", labelKey: "common.brightness", icon: "sun", content: brightnessContent },
    { key: "night-light", labelKey: "common.night-light", icon: "moon-stars", content: nightLightContent },
    { key: "layout", labelKey: "panels.display.monitor-layout-group", icon: "device-desktop", content: monitorLayoutContent, available: CompositorService.isUmbriel }
  ]

  Component { id: brightnessContent; BrightnessSubTab {} }
  Component {
    id: nightLightContent
    NightLightSubTab {
      timeOptions: timeOptions
      onCheckWlsunset: wlsunsetCheck.running = true
    }
  }
  Component { id: monitorLayoutContent; MonitorLayoutSubTab {} }
}
