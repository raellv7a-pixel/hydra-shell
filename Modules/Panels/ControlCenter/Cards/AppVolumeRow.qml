import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../../../../Helpers/AudioStreamMetadata.js" as StreamMetadata
import qs.Services.Media
DashboardCard {
  id: appVolumeRow

  property var streamNode: null
  readonly property PwNodeAudio nodeAudio: streamNode?.audio ?? null
  readonly property bool streamMuted: nodeAudio?.muted ?? false
  readonly property real streamVolume: nodeAudio?.volume ?? 0
  readonly property string appName: StreamMetadata.name(streamNode, ThemeIcons)
  readonly property string streamTitle: StreamMetadata.title(streamNode, appName)

  PwObjectTracker {
    objects: appVolumeRow.streamNode ? [appVolumeRow.streamNode] : []
  }

  Layout.preferredHeight: Math.round((streamTitle ? 94 : 76) * panelRoot.panelUnit)
  color: Color.mSurfaceContainerHighest
  radius: Style.radiusS

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      IconImage {
        id: appIcon
        Layout.preferredWidth: Math.round(24 * panelRoot.panelUnit)
        Layout.preferredHeight: Layout.preferredWidth
        source: StreamMetadata.icon(appVolumeRow.streamNode, ThemeIcons)
        asynchronous: true
        NIcon {
          anchors.fill: parent
          icon: "apps"
          visible: appIcon.status === Image.Error || appIcon.status === Image.Null
          color: Color.mPrimary
        }
      }

      NText {
        Layout.fillWidth: true
        text: appVolumeRow.appName
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
    NText {
      visible: appVolumeRow.streamTitle !== ""
      Layout.fillWidth: true
      text: appVolumeRow.streamTitle
      color: Color.mOnSurfaceVariant
      elide: Text.ElideRight
      pointSize: Style.fontSizeXS
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: AudioService.maxVolume
      stepSize: 0.01
      value: appVolumeRow.streamVolume
      enabled: appVolumeRow.streamNode?.ready === true && appVolumeRow.nodeAudio !== null
      onMoved: AudioService.setPanelAppStreamVolume(appVolumeRow.streamNode, value)
    }
  }
}
