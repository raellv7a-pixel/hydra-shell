import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NScrollView {
  id: root
  property bool telemetryOnly: false
  property bool telemetryEnabled: false
  property string monitorSummary: ""
  property string styleSummary: ""
  property string colorsSummary: ""
  property string controlsSummary: ""
  signal telemetrySelected(bool enabled)

  horizontalPolicy: ScrollBar.AlwaysOff
  verticalPolicy: ScrollBar.AlwaysOff

  ColumnLayout {
    width: root.availableWidth
    spacing: Style.marginXL

    NIcon {
      icon: root.telemetryOnly ? "shield-check" : "circle-check"
      pointSize: Style.fontSizeXXXL * 1.5
      color: Color.mPrimary
      Layout.topMargin: Style.marginM
    }
    NText {
      text: I18n.tr(root.telemetryOnly ? "setup.hydra.privacy-title" : "setup.hydra.ready-title")
      pointSize: Style.fontSizeXXXL
      font.weight: Style.fontWeightBold
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }
    NText {
      text: I18n.tr(root.telemetryOnly ? "setup.hydra.privacy-description" : "setup.hydra.ready-description")
      color: Color.mOnSurfaceVariant
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }

    ColumnLayout {
      visible: !root.telemetryOnly
      Layout.fillWidth: true
      spacing: Style.marginXL
      Repeater {
        model: [
          { key: "displays", icon: "device-desktop", value: root.monitorSummary },
          { key: "style", icon: "palette", value: root.styleSummary },
          { key: "colors", icon: "color-picker", value: root.colorsSummary },
          { key: "controls", icon: "keyboard", value: root.controlsSummary }
        ]
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: Style.marginL
          NIcon { icon: modelData.icon; color: Color.mPrimary; pointSize: Style.fontSizeXL }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS
            NText { text: I18n.tr("setup.hydra.summary-" + modelData.key); color: Color.mOnSurfaceVariant }
            NText { text: modelData.value; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.weight: Style.fontWeightMedium }
          }
        }
      }
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("setup.hydra.telemetry-label")
      description: I18n.tr("setup.hydra.telemetry-description")
      checked: root.telemetryEnabled
      onToggled: enabled => root.telemetrySelected(enabled)
    }
    NText {
      text: I18n.tr("setup.hydra.change-later")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }
  }
}
