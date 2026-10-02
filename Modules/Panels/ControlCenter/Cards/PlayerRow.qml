import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Media
import qs.Widgets

DashboardCard {
  id: playerRow

  property var playerData: null
  property int playerIndex: 0
  readonly property bool selected: playerIndex === MediaService.selectedPlayerIndex

  Layout.preferredHeight: Math.round(52 * panelRoot.panelUnit)
  color: selected ? Color.mPrimaryContainer : Color.mSurfaceContainerHighest
  radius: Style.radiusS
  border.color: selected ? Qt.alpha(Color.mPrimary, 0.38) : "transparent"

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NIcon {
      icon: selected ? "circle-filled" : "music"
      pointSize: Style.fontSizeM
      color: selected ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      NText {
        Layout.fillWidth: true
        text: panelRoot.playerLabel(playerRow.playerData)
        color: selected ? Color.mOnPrimaryContainer : Color.mOnSurface
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }

      NText {
        Layout.fillWidth: true
        text: (playerRow.playerData?.trackTitle || panelRoot.tr("nothingPlaying"))
        color: selected ? Qt.alpha(Color.mOnPrimaryContainer, 0.78) : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        elide: Text.ElideRight
      }
    }
  }

  TapHandler {
    onTapped: MediaService.switchToPlayer(playerRow.playerIndex)
  }
}
