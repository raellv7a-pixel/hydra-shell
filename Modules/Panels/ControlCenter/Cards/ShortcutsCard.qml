import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import qs.Commons
import qs.Widgets

DashboardCard {
  id: shortcutsCard

  styleKey: "shortcuts"
  styleRoot: true
  clip: true

  readonly property var leftShortcuts: Settings.data.controlCenter.shortcuts?.left || []
  readonly property var rightShortcuts: Settings.data.controlCenter.shortcuts?.right || []
  readonly property int totalShortcuts: leftShortcuts.length + rightShortcuts.length

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "puzzle"
        pointSize: Style.fontSizeXL
        color: panelRoot.componentAccent("shortcuts")
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: I18n.tr("common.shortcuts")
          font.weight: Style.fontWeightSemiBold
          color: panelRoot.componentText("shortcuts", true)
        }

        NText {
          text: shortcutsCard.totalShortcuts > 0 ? (shortcutsCard.totalShortcuts + " " + I18n.tr("common.active").toLowerCase()) : I18n.tr("panels.dashboard.settings")
          pointSize: Style.fontSizeS
          color: panelRoot.componentText("shortcuts", false)
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.marginS
        visible: shortcutsCard.totalShortcuts > 0

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          visible: shortcutsCard.leftShortcuts.length > 0

          Repeater {
            model: shortcutsCard.leftShortcuts
            delegate: ControlCenterWidgetLoader {
              required property var modelData
              required property int index

              Layout.fillWidth: false
              widgetId: (modelData.id !== undefined ? modelData.id : "")
              widgetScreen: panelRoot.activeScreen
              widgetProps: {
                "widgetId": modelData.id,
                "section": "quickSettings",
                "sectionWidgetIndex": index,
                "sectionWidgetsCount": shortcutsCard.leftShortcuts.length,
                "widgetSettings": modelData
              }
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          visible: shortcutsCard.rightShortcuts.length > 0

          Repeater {
            model: shortcutsCard.rightShortcuts
            delegate: ControlCenterWidgetLoader {
              required property var modelData
              required property int index

              Layout.fillWidth: false
              widgetId: (modelData.id !== undefined ? modelData.id : "")
              widgetScreen: panelRoot.activeScreen
              widgetProps: {
                "widgetId": modelData.id,
                "section": "quickSettings",
                "sectionWidgetIndex": index,
                "sectionWidgetsCount": shortcutsCard.rightShortcuts.length,
                "widgetSettings": modelData
              }
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }
      }

      NText {
        anchors.centerIn: parent
        visible: shortcutsCard.totalShortcuts === 0
        text: I18n.tr("panels.dashboard.noExtensionWidgets")
        pointSize: Style.fontSizeS
        color: panelRoot.componentText("shortcuts", false)
      }
    }
  }
}
