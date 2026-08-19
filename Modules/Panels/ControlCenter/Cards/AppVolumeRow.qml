import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Services.Pipewire
import qs.Services.Media
DashboardCard {
  id: appVolumeRow

  property var streamNode: null
  readonly property bool streamMuted: streamNode?.audio?.muted ?? false
  readonly property real streamVolume: streamNode?.audio?.volume ?? 0

  Layout.preferredHeight: Math.round(72 * panelRoot.panelUnit)
  color: Qt.alpha(Color.mSurface, 0.34)
  radius: Style.radiusS

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: appVolumeRow.streamMuted ? "volume-off" : "volume"
        pointSize: Style.fontSizeM
        color: appVolumeRow.streamMuted ? Color.mError : Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.nodeLabel(appVolumeRow.streamNode)
        color: Color.mOnSurface
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }

      NText {
        text: Math.round(appVolumeRow.streamVolume * 100) + "%"
        color: Color.mOnSurfaceVariant
        font.family: Settings.data.ui.fontFixed
      }

      NIconButton {
        icon: appVolumeRow.streamMuted ? "volume-off" : "volume"
        baseSize: Math.round(26 * panelRoot.panelUnit)
        onClicked: AudioService.setPanelAppStreamMuted(appVolumeRow.streamNode, !appVolumeRow.streamMuted)
      }
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: AudioService.maxVolume
      stepSize: 0.01
      value: appVolumeRow.streamVolume
      enabled: appVolumeRow.streamNode !== null && appVolumeRow.streamNode.audio !== undefined
      onMoved: AudioService.setPanelAppStreamVolume(appVolumeRow.streamNode, value)
    }
  }
}
