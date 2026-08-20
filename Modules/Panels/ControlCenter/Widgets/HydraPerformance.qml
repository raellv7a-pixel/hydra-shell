import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.hydraPerformanceMode ? "rocket" : "rocket-off"
  tooltipText: I18n.tr("tooltips.hydra-performance-enabled")
  hot: PowerProfileService.hydraPerformanceMode
  onClicked: PowerProfileService.toggleHydraPerformance()
}
