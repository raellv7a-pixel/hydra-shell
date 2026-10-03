import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Modules.Panels.Settings.Tabs.Connections as Connections
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  required property var panelRoot
  signal back
  property bool ethernetView: !NetworkService.wifiAvailable && NetworkService.ethernetAvailable

  onVisibleChanged: {
    if (visible && NetworkService.wifiEnabled) {
      NetworkService.scan();
      NetworkService.refreshActiveWifiDetails();
    }
    if (visible && NetworkService.ethernetConnected)
      NetworkService.refreshActiveEthernetDetails();
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginS

    // Fixed Header mirroring PerformanceDetailsCard
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        tooltipText: root.panelRoot.tr("back")
        onClicked: root.back()
      }

      NText {
        Layout.fillWidth: true
        text: root.panelRoot.tr("network")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NIconButton {
        icon: "refresh"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        enabled: !root.ethernetView && NetworkService.wifiEnabled && !NetworkService.scanningActive
        tooltipText: I18n.tr("common.scanning")
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurface
        onClicked: NetworkService.scan()
      }

      NIconButton {
        icon: "settings"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        tooltipText: I18n.tr("tooltips.open-settings")
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurface
        onClicked: SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 0, root.panelRoot.activeScreen)
      }

      NToggle {
        visible: !root.ethernetView
        checked: NetworkService.wifiEnabled
        enabled: NetworkService.wifiAvailable && !NetworkService.airplaneModeEnabled
        onToggled: checked => NetworkService.setWifiEnabled(checked)
      }
    }

    // Material Segmented Wi-Fi / Ethernet Selector
    RowLayout {
      id: segmentSelector
      visible: NetworkService.wifiAvailable && NetworkService.ethernetAvailable
      Layout.fillWidth: true
      spacing: Style.marginS

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(32 * root.panelRoot.panelUnit)
        radius: Style.radiusM
        color: !root.ethernetView ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginS

          NIcon {
            icon: "wifi"
            pointSize: Style.fontSizeM
            color: !root.ethernetView ? Color.mOnPrimaryContainer : Color.mOnSurface
          }

          NText {
            text: I18n.tr("common.wifi")
            pointSize: Style.fontSizeS
            font.weight: !root.ethernetView ? Style.fontWeightSemiBold : Style.fontWeightMedium
            color: !root.ethernetView ? Color.mOnPrimaryContainer : Color.mOnSurface
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.ethernetView = false
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(32 * root.panelRoot.panelUnit)
        radius: Style.radiusM
        color: root.ethernetView ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginS

          NIcon {
            icon: "network"
            pointSize: Style.fontSizeM
            color: root.ethernetView ? Color.mOnPrimaryContainer : Color.mOnSurface
          }

          NText {
            text: I18n.tr("common.ethernet")
            pointSize: Style.fontSizeS
            font.weight: root.ethernetView ? Style.fontWeightSemiBold : Style.fontWeightMedium
            color: root.ethernetView ? Color.mOnPrimaryContainer : Color.mOnSurface
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.ethernetView = true;
            NetworkService.refreshActiveEthernetDetails();
          }
        }
      }
    }

    NText {
      visible: NetworkService.lastError !== "" && !root.ethernetView
      text: NetworkService.lastError
      Layout.fillWidth: true
      color: Color.mError
      wrapMode: Text.WordWrap
    }

    // Bounded Scroll
    NScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false

      ColumnLayout {
        width: parent.width
        spacing: Style.marginS

        NText {
          visible: !root.ethernetView && !NetworkService.wifiEnabled
          text: I18n.tr("wifi.panel.enable-message")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          Layout.topMargin: Style.marginL
        }

        NText {
          visible: !root.ethernetView && NetworkService.wifiEnabled && Object.keys(NetworkService.networks).length === 0
          text: NetworkService.scanningActive ? I18n.tr("wifi.panel.searching") : I18n.tr("wifi.panel.no-networks")
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          Layout.topMargin: Style.marginL
        }

        Connections.WifiSubTab {
          id: wifiSubTab
          visible: !root.ethernetView && NetworkService.wifiEnabled
          Layout.fillWidth: true
          showOnlyLists: true
          dashboardMode: true
          panelUnit: root.panelRoot.panelUnit
        }

        Repeater {
          model: root.ethernetView ? NetworkService.ethernetInterfaces : []
          delegate: NBox {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Math.round(32 * root.panelRoot.panelUnit), ethernetText.implicitHeight) + Style.margin2S
            radius: Style.radiusM
            border.width: 0
            color: modelData.connected ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginS

              Rectangle {
                Layout.preferredWidth: Math.round(32 * root.panelRoot.panelUnit)
                Layout.preferredHeight: Layout.preferredWidth
                radius: Style.radiusS
                color: modelData.connected ? Qt.alpha(Color.mPrimary, 0.16) : Color.mSurfaceContainerHighest
                NIcon {
                  anchors.centerIn: parent
                  icon: "network"
                  pointSize: Style.fontSizeM
                  color: modelData.connected ? Color.mPrimary : Color.mOnSurface
                }
              }

              ColumnLayout {
                id: ethernetText
                Layout.fillWidth: true
                spacing: Style.marginXXS
                NText {
                  Layout.fillWidth: true
                  text: modelData.connectionName || modelData.ifname
                  font.weight: modelData.connected ? Style.fontWeightSemiBold : Style.fontWeightMedium
                  color: modelData.connected ? Color.mOnPrimaryContainer : Color.mOnSurface
                  elide: Text.ElideRight
                }
                NText {
                  Layout.fillWidth: true
                  text: modelData.connected ? I18n.tr("common.connected") : I18n.tr("common.disconnected")
                  pointSize: Style.fontSizeXS
                  color: modelData.connected ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
                }
                NText {
                  visible: modelData.connected
                  Layout.fillWidth: true
                  text: [NetworkService.activeEthernetDetails.ipv4, (NetworkService.activeEthernetDetails.dns4 || []).join(", "), NetworkService.activeEthernetDetails.gateway4].filter(Boolean).join(" · ")
                  pointSize: Style.fontSizeXS
                  color: Color.mOnPrimaryContainer
                  wrapMode: Text.WrapAnywhere
                }
              }
            }
          }
        }

        NText {
          visible: root.ethernetView && NetworkService.ethernetInterfaces.length === 0
          text: I18n.tr("wifi.panel.no-ethernet-devices")
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          Layout.topMargin: Style.marginL
        }
      }
    }
  }
}
