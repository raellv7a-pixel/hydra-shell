import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
Item {
  id: screenUsagePage

  required property var panelRoot

  readonly property var topApps: panelRoot.screenUsageTopApps(4)
  readonly property int maxAppSeconds: panelRoot.screenUsageMaxAppSeconds(topApps)

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "device-desktop"
        pointSize: Style.fontSizeXL
        color: panelRoot.componentAccent("screenUsage")
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("screenUsage")
          color: panelRoot.componentText("screenUsage", true)
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: panelRoot.tr("trackedToday")
          color: panelRoot.componentText("screenUsage", false)
          pointSize: Style.fontSizeXS
          elide: Text.ElideRight
        }
      }

      NText {
        text: panelRoot.durationText(panelRoot.screenUsageTodayTotal())
        color: panelRoot.componentAccent("screenUsage")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        font.family: Settings.data.ui.fontFixed
      }

      SubmoduleButton {
        panelRoot: screenUsagePage.panelRoot
        labelText: panelRoot.tr("details")
        targetView: "screenUsage"
        tooltipText: panelRoot.tr("details")
      }
    }

    DashboardCard {
      panelRoot: screenUsagePage.panelRoot
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(76 * panelRoot.panelUnit)
      color: Qt.alpha(Color.mSurface, 0.34)
      radius: Style.radiusS

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        Repeater {
          model: panelRoot.screenUsageWeekModel()

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginXXS

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Math.max(14, Math.round(18 * panelRoot.panelUnit))
                height: Math.max(Math.round(8 * panelRoot.panelUnit), parent.height * modelData.ratio)
                radius: Style.radiusXS
                color: index === 6 ? panelRoot.componentAccent("screenUsage") : Qt.alpha(panelRoot.componentText("screenUsage", false), 0.38)
              }
            }

            NText {
              Layout.fillWidth: true
              text: modelData.label
              color: index === 6 ? panelRoot.componentAccent("screenUsage") : panelRoot.componentText("screenUsage", false)
              pointSize: Style.fontSizeXXS
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("topApps")
        color: panelRoot.componentText("screenUsage", true)
        font.weight: Style.fontWeightSemiBold
        pointSize: Style.fontSizeS
        elide: Text.ElideRight
      }

      Repeater {
        model: screenUsagePage.topApps

        ScreenUsageAppRow {
          panelRoot: screenUsagePage.panelRoot
          Layout.fillWidth: true
          appData: modelData
          maxSeconds: screenUsagePage.maxAppSeconds
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: screenUsagePage.topApps.length === 0
        text: panelRoot.tr("screenUsageEmpty")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
      }
    }
  }
}
