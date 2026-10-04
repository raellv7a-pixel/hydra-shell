pragma ComponentBehavior: Bound

import QtQuick
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "system"
  property var screen
  groups: [
    { key: "general", labelKey: "system-monitor.title", icon: "activity", content: generalContent },
    { key: "thresholds", labelKey: "common.thresholds", icon: "alarm", content: thresholdsContent },
    { key: "performance", labelKey: "common.performance", icon: "chart-bar", content: performanceContent }
  ]

  Component { id: generalContent; GeneralSubTab { screen: root.screen } }
  Component { id: thresholdsContent; ThresholdsSubTab {} }
  Component { id: performanceContent; PerformanceSubTab {} }
}
