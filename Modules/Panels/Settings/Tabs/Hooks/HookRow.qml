import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
  id: root

  property string label: ""
  property string description: ""
  property string value: ""

  signal editClicked

  spacing: Style.marginM
  Layout.fillWidth: true

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXS
    NLabel {
      label: root.label
      description: root.description
      labelColor: root.value ? HydraColor.mPrimary : HydraColor.mOnSurface
    }
    NText {
      Layout.fillWidth: true
      text: root.value ? I18n.tr("settings.content.configured") : I18n.tr("settings.content.not-configured")
      pointSize: Style.fontSizeXS
      color: HydraColor.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }
  }

  NIconButton {
    icon: "settings"
    onClicked: root.editClicked()
    tooltipText: I18n.tr("common.edit")
  }
}
