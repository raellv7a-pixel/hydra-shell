import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../Settings/Tabs/Connections" as WifiPrefs
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(500 * Style.uiScaleRatio)

  // Info panel collapsed by default, view mode persisted in settings
  // Ethernet details UI state (mirrors Wi‑Fi info behavior)
  property bool ethernetInfoExpanded: false
  property bool ethernetDetailsGrid: (Settings.data.network.wifiDetailsViewMode === "grid")
  property int ipVersion: 4

  // Unified panel view mode: "wifi" | "ethernet" (persisted)
  property string panelViewMode: "wifi"
  property bool panelViewPersistEnabled: false

  onPanelViewModeChanged: {
    // Persist last view (only after restored the initial value)
    if (panelViewPersistEnabled) {
      Settings.data.network.networkPanelView = panelViewMode;
    }
    if (panelViewMode === "wifi") {
      ethernetInfoExpanded = false;
      if (NetworkService.wifiEnabled && !NetworkService.scanningActive) {
        NetworkService.scan();
        NetworkService.refreshActiveWifiDetails();
      }
    } else {
      if (NetworkService.ethernetConnected) {
        NetworkService.refreshActiveEthernetDetails();
      }
    }
  }

  // Effectively visible tracking
  readonly property bool effectivelyVisible: root.visible && Window.window && Window.window.visible

  onEffectivelyVisibleChanged: {
    if (effectivelyVisible) {
      SystemStatService.registerComponent("network-panel");
      if (NetworkService.wifiEnabled && !NetworkService.scanningActive) {
        NetworkService.scan();
        NetworkService.refreshActiveWifiDetails();
      }
      if (NetworkService.ethernetConnected) {
        NetworkService.refreshActiveEthernetDetails();
      }
    } else {
      SystemStatService.unregisterComponent("network-panel");
    }
  }

  onOpened: {
    // Restore last view if valid, otherwise choose what's available (prefer Wi‑Fi when both exist)
    if (Settings.data.network.networkPanelView) {
      const last = Settings.data.network.networkPanelView;
      if (last === "ethernet" && NetworkService.ethernetAvailable) {
        panelViewMode = "ethernet";
      } else {
        panelViewMode = "wifi";
      }
    } else {
      if (!NetworkService.wifiEnabled && NetworkService.ethernetAvailable) {
        panelViewMode = "ethernet";
      } else {
        panelViewMode = "wifi";
      }
    }
    panelViewPersistEnabled = true;
  }

  panelContent: Rectangle {
    color: "transparent"

    property real contentPreferredHeight: Math.min(root.preferredHeight, mainColumn.implicitHeight + Style.paddingCard * 2)

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.radiusPanel // must be >= the panel's own blob corner radius (28px), not paddingCard (16px), or content stops short and the wallpaper shows through the rounded-off corner
      spacing: Style.spaceS

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: header.implicitHeight + Style.paddingCard * 2
        radius: Style.radiusCard

        ColumnLayout {
          id: header
          anchors.fill: parent
          anchors.margins: Style.paddingCard
          spacing: Style.spaceS

          RowLayout {
            NIconButton {
              id: modeButton
              icon: panelViewMode === "wifi" ? (NetworkService.wifiEnabled ? "wifi" : "wifi-off") : (NetworkService.ethernetAvailable ? "ethernet" : "ethernet-off")
              tooltipText: panelViewMode === "wifi" ? I18n.tr("common.wifi") : I18n.tr("common.ethernet")
              baseSize: Style.baseWidgetSize * 0.8
              colorBg: "transparent"
              colorBgHover: Color.mSurfaceContainerHigh
              colorFg: {
                if (panelViewMode === "wifi")
                  return NetworkService.wifiEnabled ? Color.mPrimary : Color.mOnSurfaceVariant;
                return NetworkService.ethernetConnected ? Color.mPrimary : Color.mOnSurfaceVariant;
              }
              colorFgHover: colorFg
              onClicked: {
                if (panelViewMode === "wifi") {
                  if (NetworkService.ethernetAvailable)
                    panelViewMode = "ethernet";
                  else
                    TooltipService.show(modeButton, I18n.tr("wifi.panel.no-ethernet-devices"));
                } else {
                  panelViewMode = "wifi";
                }
              }
            }

            NText {
              text: panelViewMode === "wifi" ? I18n.tr("common.wifi") : I18n.tr("common.ethernet")
              Layout.fillWidth: true
              pointSize: Style.fontSizeTitleMedium
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NToggle {
              id: wifiSwitch
              visible: panelViewMode === "wifi"
              checked: NetworkService.wifiEnabled
              enabled: !NetworkService.airplaneModeEnabled && NetworkService.wifiAvailable
              onToggled: checked => NetworkService.setWifiEnabled(checked)
              baseSize: Style.baseWidgetSize * 0.7 // Slightly smaller
            }

            NIconButton {
              icon: "settings"
              tooltipText: I18n.tr("tooltips.open-settings")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 0, screen)
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("common.close")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: root.close()
            }
          }

          // Mode switch (Wi‑Fi / Ethernet)
          NTabBar {
            id: modeTabBar
            visible: NetworkService.ethernetAvailable && NetworkService.wifiAvailable
            margins: Style.spaceS
            Layout.fillWidth: true
            spacing: Style.spaceS
            distributeEvenly: true
            currentIndex: root.panelViewMode === "wifi" ? 0 : 1
            onCurrentIndexChanged: {
              root.panelViewMode = (currentIndex === 0) ? "wifi" : "ethernet";
            }

            NTabButton {
              text: I18n.tr("common.wifi")
              tabIndex: 0
              checked: modeTabBar.currentIndex === 0
            }

            NTabButton {
              text: I18n.tr("common.ethernet")
              tabIndex: 1
              checked: modeTabBar.currentIndex === 1
            }
          }
        }
      }

      // Unified scrollable content (Wi‑Fi or Ethernet view)
      ColumnLayout {
        id: wifiSectionContainer
        visible: true
        Layout.fillWidth: true
        spacing: Style.spaceS

        // Error message
        Rectangle {
          visible: panelViewMode === "wifi" && NetworkService.lastError.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: errorRow.implicitHeight + Style.paddingCard * 2
          color: Qt.alpha(Color.mError, 0.1)
          radius: Style.radiusCard
          border.width: Style.borderS
          border.color: Color.mError

          RowLayout {
            id: errorRow
            anchors.fill: parent
            anchors.margins: Style.paddingCard
            spacing: Style.spaceS

            NIcon {
              icon: "warning"
              pointSize: Style.fontSizeTitleSmall
              color: Color.mError
            }

            NText {
              text: NetworkService.lastError
              color: Color.mError
              pointSize: Style.fontSizeBodySmall
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "close"
              baseSize: Style.baseWidgetSize * 0.6
              onClicked: NetworkService.lastError = ""
            }
          }
        }

        // Unified scrollable content
        NScrollView {
          id: contentScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          reserveScrollbarSpace: false
          gradientColor: Color.mSurface

          ColumnLayout {
            id: contentColumn
            width: contentScroll.availableWidth
            spacing: Style.spaceS

            // Wi‑Fi disabled state
            NBox {
              id: disabledBox
              visible: panelViewMode === "wifi" && !NetworkService.wifiEnabled
              Layout.fillWidth: true
              Layout.preferredHeight: disabledColumn.implicitHeight + Style.paddingCard * 2
              radius: Style.radiusCard

              ColumnLayout {
                id: disabledColumn
                anchors.fill: parent
                anchors.margins: Style.paddingCard
                spacing: Style.spaceM

                Item {
                  Layout.fillHeight: true
                }

                NIcon {
                  icon: "wifi-off"
                  pointSize: 48
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.disabled")
                  pointSize: Style.fontSizeTitleSmall
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.enable-message")
                  pointSize: Style.fontSizeBodySmall
                  color: Color.mOnSurfaceVariant
                  horizontalAlignment: Text.AlignHCenter
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Scanning state (show when no networks and we haven't had any yet)
            NBox {
              id: scanningBox
              visible: panelViewMode === "wifi" && NetworkService.wifiEnabled && Object.keys(NetworkService.networks).length === 0 && NetworkService.scanningActive
              Layout.fillWidth: true
              Layout.preferredHeight: scanningColumn.implicitHeight + Style.paddingCard * 2
              radius: Style.radiusCard

              ColumnLayout {
                id: scanningColumn
                anchors.fill: parent
                anchors.margins: Style.paddingCard
                spacing: Style.spaceM

                Item {
                  Layout.fillHeight: true
                }

                NBusyIndicator {
                  running: visible && root.effectivelyVisible
                  color: Color.mPrimary
                  size: Style.baseWidgetSize
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.searching")
                  pointSize: Style.fontSizeBodyMedium
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Empty state when no networks (only show after we've had networks before, meaning a real empty result)
            NBox {
              id: emptyBox
              visible: panelViewMode === "wifi" && NetworkService.wifiEnabled && Object.keys(NetworkService.networks).length === 0 && !NetworkService.scanningActive
              Layout.fillWidth: true
              Layout.preferredHeight: emptyColumn.implicitHeight + Style.paddingCard * 2
              radius: Style.radiusCard

              ColumnLayout {
                id: emptyColumn
                anchors.fill: parent
                anchors.margins: Style.paddingCard
                spacing: Style.spaceM

                Item {
                  Layout.fillHeight: true
                }

                NIcon {
                  icon: "wifi-question"
                  pointSize: 48
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: I18n.tr("wifi.panel.no-networks")
                  pointSize: Style.fontSizeTitleSmall
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Networks list container (Wi‑Fi)
            ColumnLayout {
              id: networksList
              visible: panelViewMode === "wifi" && NetworkService.wifiEnabled && Object.keys(NetworkService.networks).length > 0
              width: parent.width
              spacing: Style.spaceS

              WifiPrefs.WifiSubTab {
                showOnlyLists: true
              }
            }

            // Ethernet view
            NBox {
              id: ethernetSection
              visible: panelViewMode === "ethernet"
              Layout.fillWidth: true
              Layout.preferredHeight: ethernetColumn.implicitHeight + Style.paddingCard * 2
              radius: Style.radiusCard

              ColumnLayout {
                id: ethernetColumn
                anchors.fill: parent
                anchors.margins: Style.paddingCard
                spacing: Style.spaceS

                // Section label
                NLabel {
                  label: I18n.tr("wifi.panel.available-interfaces")
                  visible: (NetworkService.ethernetInterfaces && NetworkService.ethernetInterfaces.length > 0)
                }

                // Empty state when no Ethernet devices
                ColumnLayout {
                  id: emptyEthColumn

                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                  Layout.preferredHeight: emptyEthColumn.implicitHeight + Style.paddingCard * 2
                  visible: !(NetworkService.ethernetInterfaces && NetworkService.ethernetInterfaces.length > 0)
                  spacing: Style.spaceM

                  Item {
                    Layout.fillHeight: true
                  }

                  NIcon {
                    icon: "ethernet-off"
                    pointSize: 48
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                  }

                  NText {
                    text: I18n.tr("wifi.panel.no-ethernet-devices")
                    pointSize: Style.fontSizeTitleSmall
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                  }

                  Item {
                    Layout.fillHeight: true
                  }
                }

                // Interfaces list
                ColumnLayout {
                  id: ethIfacesList
                  visible: NetworkService.ethernetInterfaces && NetworkService.ethernetInterfaces.length > 0
                  width: parent.width
                  spacing: Style.spaceXS

                  Repeater {
                    model: NetworkService.ethernetInterfaces || []
                    delegate: NBox {
                      id: ethItem

                      function getContentColors(defaultColors = [Color.mSurfaceContainer, Color.mOnSurface]) {
                        if (modelData.connected)
                          return [Color.mSecondaryContainer, Color.mOnSecondaryContainer];
                        return defaultColors;
                      }

                      Layout.fillWidth: true
                      Layout.leftMargin: Style.spaceXS
                      Layout.rightMargin: Style.spaceXS
                      implicitHeight: ethItemColumn.implicitHeight + Style.paddingCard * 2
                      radius: Style.radiusCard
                      forceOpaque: true
                      color: ethItem.getContentColors()[0]
                      activeFocusOnTab: true
                      Accessible.role: Accessible.Button
                      Accessible.name: modelData.connectionName || modelData.ifname
                      Keys.onReturnPressed: event => {
                                              ethItem.toggleDetails();
                                              event.accepted = true;
                                            }
                      Keys.onSpacePressed: event => {
                                             ethItem.toggleDetails();
                                             event.accepted = true;
                                           }

                      function toggleDetails() {
                        if (NetworkService.activeEthernetIf === modelData.ifname && ethernetInfoExpanded) {
                          ethernetInfoExpanded = false;
                          return;
                        }
                        if (NetworkService.activeEthernetIf !== modelData.ifname) {
                          NetworkService.activeEthernetIf = modelData.ifname;
                          NetworkService.activeEthernetDetailsTimestamp = 0;
                        }
                        ethernetInfoExpanded = true;
                        NetworkService.refreshActiveEthernetDetails();
                      }

                      NStateLayer {
                        id: ethStateLayer
                        anchors.fill: parent
                        hovered: ethHover.hovered
                        pressed: ethTap.pressed
                        focused: ethItem.activeFocus
                        radius: Style.radiusCard
                        stateColor: Color.mOnSurface
                      }

                      NFocusRing {
                        focusVisible: ethItem.activeFocus
                        targetRadius: Style.radiusCard
                      }

                      ColumnLayout {
                        id: ethItemColumn
                        width: parent.width - Style.paddingCard * 2
                        x: Style.paddingCard
                        y: Style.paddingCard
                        spacing: Style.spaceS

                        // Main row matching Wi‑Fi card style
                        // Click handling for the whole header row is provided by a sibling MouseArea
                        // anchored to this row (defined right after this RowLayout).
                        RowLayout {
                          id: ethHeaderRow
                          Layout.fillWidth: true
                          spacing: Style.spaceS

                          NIcon {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            icon: NetworkService.getIcon(true)
                            pointSize: Style.fontSizeHeadlineSmall
                            color: ethItem.getContentColors()[1]
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            NText {
                              text: modelData.connectionName || modelData.ifname
                              pointSize: Style.fontSizeBodyMedium
                              font.weight: modelData.connected ? Style.fontWeightBold : Style.fontWeightMedium
                              color: ethItem.getContentColors()[1]
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }

                            RowLayout {
                              spacing: Style.spaceXS

                              NText {
                                text: {
                                  if (modelData.connected) {
                                    switch (NetworkService.networkConnectivity) {
                                    case "full":
                                      return I18n.tr("common.connected");
                                    case "limited":
                                    case "unknown":
                                      return I18n.tr("wifi.panel.internet-limited");
                                    case "portal":
                                      return I18n.tr("wifi.panel.action-required");
                                    default:
                                      return NetworkService.networkConnectivity;
                                    }
                                  }
                                  return I18n.tr("common.disconnected");
                                }
                                pointSize: Style.fontSizeLabelSmall
                                color: Qt.alpha(ethItem.getContentColors()[1], Style.opacityHeavy)
                              }

                              // Network speed indicators (visible when connected and speed > 0)
                              RowLayout {
                                visible: (modelData.connected && NetworkService.networkConnectivity === "full") && (SystemStatService.rxSpeed > 0 || SystemStatService.txSpeed > 0)
                                spacing: 2
                                Layout.leftMargin: Style.spaceXS
                                Layout.fillWidth: false

                                NIcon {
                                  visible: SystemStatService.rxSpeed > 0
                                  icon: "arrow-down"
                                  pointSize: Style.fontSizeLabelSmall
                                  color: Qt.alpha(ethItem.getContentColors()[1], Style.opacityHeavy)
                                }

                                NText {
                                  visible: SystemStatService.rxSpeed > 0
                                  text: SystemStatService.formatSpeed(SystemStatService.rxSpeed)
                                  pointSize: Style.fontSizeLabelSmall
                                  color: Qt.alpha(ethItem.getContentColors()[1], Style.opacityHeavy)
                                  elide: Text.ElideNone
                                }

                                Item {
                                  visible: SystemStatService.rxSpeed > 0 && SystemStatService.txSpeed > 0
                                  width: Style.spaceXS
                                  height: 1
                                }

                                NIcon {
                                  visible: SystemStatService.txSpeed > 0
                                  icon: "arrow-up"
                                  pointSize: Style.fontSizeLabelSmall
                                  color: Qt.alpha(ethItem.getContentColors()[1], Style.opacityHeavy)
                                }

                                NText {
                                  visible: SystemStatService.txSpeed > 0
                                  text: SystemStatService.formatSpeed(SystemStatService.txSpeed)
                                  pointSize: Style.fontSizeLabelSmall
                                  color: Qt.alpha(ethItem.getContentColors()[1], Style.opacityHeavy)
                                  elide: Text.ElideNone
                                }
                              }
                            }
                          }

                          // Info button on the right
                          NIconButton {
                            icon: "info"
                            tooltipText: I18n.tr("common.info")
                            baseSize: Style.baseWidgetSize * 0.75
                            colorBg: Color.mSurfaceVariant
                            colorFg: Color.mOnSurface
                            colorBorder: "transparent"
                            colorBorderHover: "transparent"
                            enabled: true
                            visible: NetworkService.ethernetConnected
                            onClicked: {
                              if (NetworkService.activeEthernetIf === modelData.ifname && ethernetInfoExpanded) {
                                ethernetInfoExpanded = false;
                                return;
                              }
                              if (NetworkService.activeEthernetIf !== modelData.ifname) {
                                NetworkService.activeEthernetIf = modelData.ifname;
                                NetworkService.activeEthernetDetailsTimestamp = 0;
                              }
                              ethernetInfoExpanded = true;
                              NetworkService.refreshActiveEthernetDetails();
                            }
                          }
                        }

                        // Click handling without anchors in a Layout-managed item
                        HoverHandler {
                          id: ethHover
                          target: ethHeaderRow
                        }

                        TapHandler {
                          id: ethTap
                          target: ethHeaderRow
                          onTapped: {
                            ethStateLayer.rippleAt(point.position.x, point.position.y);
                            ethItem.toggleDetails();
                          }
                        }

                        // Inline Ethernet details
                        Rectangle {
                          id: ethInfoInline
                          visible: ethernetInfoExpanded && NetworkService.activeEthernetIf === modelData.ifname
                          Layout.fillWidth: true
                          color: Color.mSurfaceContainerHigh
                          radius: Style.radiusControl
                          border.width: Style.borderS
                          border.color: Color.mOutline
                          implicitHeight: ethInfoGrid.implicitHeight + Style.spaceS * 2
                          clip: true
                          Layout.topMargin: Style.spaceXS

                          // Grid/List toggle
                          NIconButton {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Style.spaceS
                            icon: ethernetDetailsGrid ? "layout-list" : "layout-grid"
                            tooltipText: ethernetDetailsGrid ? I18n.tr("tooltips.list-view") : I18n.tr("tooltips.grid-view")
                            baseSize: Style.baseWidgetSize * 0.65
                            onClicked: {
                              ethernetDetailsGrid = !ethernetDetailsGrid;
                              Settings.data.network.wifiDetailsViewMode = ethernetDetailsGrid ? "grid" : "list";
                            }
                            z: 1
                          }

                          GridLayout {
                            id: ethInfoGrid
                            anchors.fill: parent
                            anchors.margins: Style.spaceS
                            anchors.rightMargin: Style.baseWidgetSize
                            flow: ethernetDetailsGrid ? GridLayout.TopToBottom : GridLayout.LeftToRight
                            rows: ethernetDetailsGrid ? 3 : 6
                            columns: ethernetDetailsGrid ? 2 : 1
                            columnSpacing: Style.spaceS
                            rowSpacing: Style.spaceXS
                            onColumnsChanged: {
                              if (ethInfoGrid.forceLayout) {
                                Qt.callLater(function () {
                                  ethInfoGrid.forceLayout();
                                });
                              }
                            }

                            // --- Item 1: Interface ---
                            RowLayout {
                              Layout.fillWidth: true
                              Layout.preferredWidth: 1
                              spacing: Style.spaceXS
                              NIcon {
                                icon: "ethernet"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onEntered: TooltipService.show(parent, I18n.tr("wifi.panel.interface"))
                                  onExited: TooltipService.hide()
                                }
                              }
                              NText {
                                text: (NetworkService.activeEthernetDetails.ifname && NetworkService.activeEthernetDetails.ifname.length > 0) ? NetworkService.activeEthernetDetails.ifname : (NetworkService.activeEthernetIf || "-")
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                wrapMode: ethernetDetailsGrid ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                elide: ethernetDetailsGrid ? Text.ElideRight : Text.ElideNone
                                maximumLineCount: ethernetDetailsGrid ? 1 : 6
                                clip: true

                                // Click-to-copy Ethernet interface name
                                MouseArea {
                                  anchors.fill: parent
                                  // Guard against undefined by normalizing to empty strings
                                  enabled: ((NetworkService.activeEthernetDetails.ifname || "").length > 0) || ((NetworkService.activeEthernetIf || "").length > 0)
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onEntered: TooltipService.show(parent, I18n.tr("tooltips.copy-address"))
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    const value = (NetworkService.activeEthernetDetails.ifname && NetworkService.activeEthernetDetails.ifname.length > 0) ? NetworkService.activeEthernetDetails.ifname : (NetworkService.activeEthernetIf || "");
                                    if (value.length > 0) {
                                      Quickshell.execDetached(["wl-copy", value]);
                                      ToastService.showNotice(I18n.tr("common.ethernet"), I18n.tr("common.copied-to-clipboard"), "ethernet");
                                    }
                                  }
                                }
                              }
                            }

                            // --- Item 2: Hardware Address ---
                            RowLayout {
                              Layout.fillWidth: true
                              Layout.preferredWidth: 1
                              spacing: Style.spaceXS
                              NIcon {
                                icon: "hash"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onEntered: TooltipService.show(parent, I18n.tr("bluetooth.panel.device-address"))
                                  onExited: TooltipService.hide()
                                }
                              }
                              NText {
                                text: NetworkService.activeEthernetDetails.hwAddr || "-"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                wrapMode: ethernetDetailsGrid ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                elide: ethernetDetailsGrid ? Text.ElideRight : Text.ElideNone
                                maximumLineCount: ethernetDetailsGrid ? 1 : 6
                                clip: true

                                MouseArea {
                                  anchors.fill: parent
                                  enabled: (NetworkService.activeEthernetDetails.hwAddr || "").length > 0
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onEntered: TooltipService.show(parent, I18n.tr("tooltips.copy-address"))
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    const value = NetworkService.activeEthernetDetails.hwAddr || "";
                                    if (value.length > 0) {
                                      Quickshell.execDetached(["wl-copy", value]);
                                      ToastService.showNotice(I18n.tr("common.ethernet"), I18n.tr("common.copied-to-clipboard"), "ethernet");
                                    }
                                  }
                                }
                              }
                            }

                            // --- Item 3: Link speed ---
                            RowLayout {
                              Layout.fillWidth: true
                              Layout.preferredWidth: 1
                              spacing: Style.spaceXS
                              NIcon {
                                icon: "gauge"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onEntered: TooltipService.show(parent, I18n.tr("wifi.panel.link-speed"))
                                  onExited: TooltipService.hide()
                                }
                              }
                              NText {
                                text: (NetworkService.activeEthernetDetails.speed && NetworkService.activeEthernetDetails.speed.length > 0) ? NetworkService.activeEthernetDetails.speed : "-"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                wrapMode: ethernetDetailsGrid ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                elide: ethernetDetailsGrid ? Text.ElideRight : Text.ElideNone
                                maximumLineCount: ethernetDetailsGrid ? 1 : 6
                                clip: true
                              }
                            }

                            // --- Item 4: IPv4 || IPv6 ---
                            RowLayout {
                              Layout.fillWidth: true
                              Layout.preferredWidth: 1
                              spacing: Style.spaceXS
                              NIcon {
                                icon: "network"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onEntered: TooltipService.show(parent, root.ipVersion === 4 ? I18n.tr("wifi.panel.ipv4") : I18n.tr("wifi.panel.ipv6"))
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    root.ipVersion = root.ipVersion === 4 ? 6 : 4;
                                    TooltipService.show(parent, root.ipVersion === 4 ? I18n.tr("wifi.panel.ipv4") : I18n.tr("wifi.panel.ipv6"));
                                  }
                                }
                              }
                              NText {
                                text: root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.ipv4 || "-") : ((NetworkService.activeEthernetDetails.ipv6 || []).join(", ") || "-")
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                wrapMode: ethernetDetailsGrid ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                elide: ethernetDetailsGrid ? Text.ElideRight : Text.ElideNone
                                maximumLineCount: ethernetDetailsGrid ? 1 : 6
                                clip: true

                                // Click-to-copy Ethernet IP address
                                MouseArea {
                                  anchors.fill: parent
                                  enabled: root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.ipv4 || "").length > 0 : (NetworkService.activeEthernetDetails.ipv6 || []).length > 0
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onEntered: TooltipService.show(parent, I18n.tr("tooltips.copy-address"))
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    const value = root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.ipv4 || "") : ((NetworkService.activeEthernetDetails.ipv6 || []).join(", ") || "");
                                    if (value.length > 0) {
                                      Quickshell.execDetached(["wl-copy", value]);
                                      ToastService.showNotice(I18n.tr("common.ethernet"), I18n.tr("common.copied-to-clipboard"), "ethernet");
                                    }
                                  }
                                }
                              }
                            }

                            // --- Item 5: DNS ---
                            RowLayout {
                              Layout.fillWidth: true
                              Layout.preferredWidth: 1
                              spacing: Style.spaceXS
                              NIcon {
                                icon: "world"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onEntered: TooltipService.show(parent, root.ipVersion === 4 ? I18n.tr("wifi.panel.dns") + " (" + I18n.tr("wifi.panel.ipv4") + ")" : I18n.tr("wifi.panel.dns") + " (" + I18n.tr("wifi.panel.ipv6") + ")")
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    root.ipVersion = root.ipVersion === 4 ? 6 : 4;
                                    TooltipService.show(parent, root.ipVersion === 4 ? I18n.tr("wifi.panel.dns") + " (" + I18n.tr("wifi.panel.ipv4") + ")" : I18n.tr("wifi.panel.dns") + " (" + I18n.tr("wifi.panel.ipv6") + ")");
                                  }
                                }
                              }
                              NText {
                                text: root.ipVersion === 4 ? ((NetworkService.activeEthernetDetails.dns4 || []).join(", ") || "-") : ((NetworkService.activeEthernetDetails.dns6 || []).join(", ") || "-")
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                wrapMode: ethernetDetailsGrid ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                elide: ethernetDetailsGrid ? Text.ElideRight : Text.ElideNone
                                maximumLineCount: ethernetDetailsGrid ? 1 : 6
                                clip: true

                                // Click-to-copy Ethernet DNS
                                MouseArea {
                                  anchors.fill: parent
                                  enabled: root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.dns4 || []).length > 0 : (NetworkService.activeEthernetDetails.dns6 || []).length > 0
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onEntered: TooltipService.show(parent, I18n.tr("tooltips.copy-address"))
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    const value = root.ipVersion === 4 ? ((NetworkService.activeEthernetDetails.dns4 || []).join(", ") || "") : ((NetworkService.activeEthernetDetails.dns6 || []).join(", ") || "");
                                    if (value.length > 0) {
                                      Quickshell.execDetached(["wl-copy", value]);
                                      ToastService.showNotice(I18n.tr("common.ethernet"), I18n.tr("common.copied-to-clipboard"), "ethernet");
                                    }
                                  }
                                }
                              }
                            }

                            // --- Item 6: Gateway ---
                            RowLayout {
                              Layout.fillWidth: true
                              Layout.preferredWidth: 1
                              spacing: Style.spaceXS
                              NIcon {
                                icon: "router"
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  onEntered: TooltipService.show(parent, root.ipVersion === 4 ? I18n.tr("common.gateway") + " (" + I18n.tr("wifi.panel.ipv4") + ")" : I18n.tr("common.gateway") + " (" + I18n.tr("wifi.panel.ipv6") + ")")
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    root.ipVersion = root.ipVersion === 4 ? 6 : 4;
                                    TooltipService.show(parent, root.ipVersion === 4 ? I18n.tr("common.gateway") + " (" + I18n.tr("wifi.panel.ipv4") + ")" : I18n.tr("common.gateway") + " (" + I18n.tr("wifi.panel.ipv6") + ")");
                                  }
                                }
                              }
                              NText {
                                text: root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.gateway4 || "-") : ((NetworkService.activeEthernetDetails.gateway6 || []).join(", ") || "-")
                                pointSize: Style.fontSizeLabelLarge
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                wrapMode: ethernetDetailsGrid ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                elide: ethernetDetailsGrid ? Text.ElideRight : Text.ElideNone
                                maximumLineCount: ethernetDetailsGrid ? 1 : 6
                                clip: true

                                // Click-to-copy Ethernet Gateway
                                MouseArea {
                                  anchors.fill: parent
                                  enabled: root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.gateway4 || "").length > 0 : (NetworkService.activeEthernetDetails.gateway6 || []).length > 0
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onEntered: TooltipService.show(parent, I18n.tr("tooltips.copy-address"))
                                  onExited: TooltipService.hide()
                                  onClicked: {
                                    const value = root.ipVersion === 4 ? (NetworkService.activeEthernetDetails.gateway4 || "") : ((NetworkService.activeEthernetDetails.gateway6 || []).join(", ") || "");
                                    if (value.length > 0) {
                                      Quickshell.execDetached(["wl-copy", value]);
                                      ToastService.showNotice(I18n.tr("common.ethernet"), I18n.tr("common.copied-to-clipboard"), "ethernet");
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
