import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Media
DashboardCard {
  id: playerRow

  property var playerData: null
  property int playerIndex: 0
  readonly property bool selected: playerIndex === MediaService.selectedPlayerIndex

  Layout.preferredHeight: Math.round(52 * panelRoot.panelUnit)
  color: selected ? HydraColor.mPrimaryContainer : HydraColor.mSurfaceContainerHighest
  radius: Style.radiusS
  border.color: selected ? Qt.alpha(HydraColor.mPrimary, 0.38) : "transparent"

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NIcon {
      icon: selected ? "circle-filled" : "music"
      pointSize: Style.fontSizeM
      color: selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurfaceVariant
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      NText {
        Layout.fillWidth: true
        text: panelRoot.playerLabel(playerRow.playerData)
        color: selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurface
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }

      NText {
        Layout.fillWidth: true
        text: (playerRow.playerData?.trackTitle || panelRoot.tr("nothingPlaying"))
        color: selected ? Qt.alpha(HydraColor.mOnPrimaryContainer, 0.78) : HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        elide: Text.ElideRight
      }
    }
  }

  TapHandler {
    onTapped: MediaService.switchToPlayer(playerRow.playerIndex)
  }
}
