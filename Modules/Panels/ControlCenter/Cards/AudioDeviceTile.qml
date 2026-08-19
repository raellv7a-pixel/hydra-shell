import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: audioDeviceTile

  property string titleText: ""
  property string valueText: ""
  property string iconName: ""
  property bool muted: false
  property var devices: []
  property string currentDeviceKey: ""
  signal toggleMuted
  signal deviceSelected(string key)

  Layout.preferredHeight: Math.round(102 * panelRoot.panelUnit)
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS
  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: audioDeviceTile.iconName
        pointSize: Style.fontSizeL
        color: audioDeviceTile.muted ? Color.mError : Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        text: audioDeviceTile.titleText
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        elide: Text.ElideRight
      }

      NIconButton {
        icon: audioDeviceTile.muted ? "volume-off" : "volume"
        baseSize: Math.round(26 * panelRoot.panelUnit)
        tooltipText: audioDeviceTile.muted ? I18n.tr("tooltips.unmute") : I18n.tr("tooltips.mute")
        onClicked: audioDeviceTile.toggleMuted()
      }
    }

    NComboBox {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(34 * panelRoot.panelUnit)
      model: audioDeviceTile.devices
      currentKey: audioDeviceTile.currentDeviceKey
      placeholder: audioDeviceTile.valueText
      minimumWidth: Math.max(88, audioDeviceTile.width - Style.marginM * 2)
      popupHeight: 240
      enabled: audioDeviceTile.devices.length > 0
      onSelected: key => audioDeviceTile.deviceSelected(key)
    }
  }
}
