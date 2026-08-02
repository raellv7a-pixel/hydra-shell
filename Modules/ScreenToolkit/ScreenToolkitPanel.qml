import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets
import qs.Modules.ScreenToolkit as ST

SmartPanel {
  id: root

  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true

  preferredWidth: Math.round(360 * Style.uiScaleRatio)
  preferredHeight: Math.round(540 * Style.uiScaleRatio)

  panelContent: Component {
    Item {
      id: contentContainer
      anchors.fill: parent

      ST.Panel {
        id: screenToolkitContent
        anchors.fill: parent
        pluginApi: ScreenToolkitService.provider
      }
    }
  }
}
