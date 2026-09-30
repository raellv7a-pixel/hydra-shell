import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  function dtr(key) {
    return I18n.tr("panels.dashboard." + key);
  }

  function getCardMeta(cardId) {
    switch (cardId) {
    case "profile":
      return {
        "name": root.dtr("cardProfileName"),
        "description": root.dtr("cardProfileDesc"),
        "icon": "user",
        "locked": true
      };
    case "quick-actions":
      return {
        "name": root.dtr("cardQuickActionsName"),
        "description": root.dtr("cardQuickActionsDesc"),
        "icon": "sparkles",
        "locked": false
      };
    case "recording":
      return {
        "name": root.dtr("cardRecordingName"),
        "description": root.dtr("cardRecordingDesc"),
        "icon": "video",
        "locked": false
      };
    case "shortcuts":
      return {
        "name": root.dtr("cardShortcutsName"),
        "description": root.dtr("cardShortcutsDesc"),
        "icon": "puzzle",
        "locked": false
      };
    case "performance":
      return {
        "name": root.dtr("cardPerformanceName"),
        "description": root.dtr("cardPerformanceDesc"),
        "icon": "cpu",
        "locked": false
      };
    case "system-controls":
      return {
        "name": root.dtr("cardSystemControlsName"),
        "description": root.dtr("cardSystemControlsDesc"),
        "icon": "volume",
        "locked": false
      };
    case "notifications":
      return {
        "name": root.dtr("cardNotificationsName"),
        "description": root.dtr("cardNotificationsDesc"),
        "icon": "bell",
        "locked": false
      };
    case "media":
      return {
        "name": root.dtr("cardMediaName"),
        "description": root.dtr("cardMediaDesc"),
        "icon": "player-play",
        "locked": false
      };
    case "calendar":
      return {
        "name": root.dtr("cardCalendarName"),
        "description": root.dtr("cardCalendarDesc"),
        "icon": "calendar",
        "locked": false
      };
    default:
      return {
        "name": cardId,
        "description": "",
        "icon": "box",
        "locked": false
      };
    }
  }

  NHeader {
    label: root.dtr("settingsCardsTitle")
    description: root.dtr("settingsCardsDesc")
    Layout.fillWidth: true
  }

  Repeater {
    model: [
      {
        "zone": "left",
        "title": root.dtr("zoneLeftColumn")
      },
      {
        "zone": "center",
        "title": root.dtr("zoneCenterColumn")
      },
      {
        "zone": "right",
        "title": root.dtr("zoneRightColumn")
      }
    ]

    delegate: ColumnLayout {
      id: zoneCol
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.marginS

      readonly property string zoneName: modelData.zone
      readonly property var zoneCards: Settings.getControlCenterCardsForZone(zoneName)
      readonly property int enabledCount: {
        var count = 0;
        for (var i = 0; i < zoneCards.length; i++) {
          if (zoneCards[i].enabled)
            count++;
        }
        return count;
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: zoneCol.modelData.title
          pointSize: Style.fontSizeM
          font.bold: true
          color: Color.mPrimary
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: I18n.tr("common.result-count-plural", {
                          "count": zoneCol.zoneCards.length
                        }) || (zoneCol.zoneCards.length + " cards")
          pointSize: Style.fontSizeS
          color: Color.mOutline
        }
      }
      Repeater {
        model: zoneCol.zoneCards

        delegate: NBox {
          id: cardBox
          required property var modelData
          required property int index
          Layout.fillWidth: true
          Layout.preferredHeight: boxColumn.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceContainer
          radius: Style.radiusM
          border.color: cardBox.modelData.enabled ? Qt.alpha(Color.mPrimary, 0.3) : Qt.alpha(Color.mOutline, 0.15)
          border.width: Style.borderS

          readonly property var meta: root.getCardMeta(cardBox.modelData.id)
          readonly property bool isLocked: cardBox.modelData.locked || cardBox.meta.locked
          readonly property int totalInZone: zoneCol.zoneCards.length
          readonly property int enabledCount: zoneCol.enabledCount
          readonly property bool isLastEnabledInZone: cardBox.modelData.enabled && (cardBox.enabledCount <= 1)
          readonly property bool isSystemControls: cardBox.modelData.id === "system-controls"
          readonly property bool hasNoSubcontrolsSelected: cardBox.isSystemControls && !cardBox.modelData.enabled && (Settings.data.controlCenter.audioControlsEnabled === false) && (Settings.data.controlCenter.brightnessControlEnabled === false)
          readonly property bool canToggle: !cardBox.isLocked && !cardBox.isLastEnabledInZone && !cardBox.hasNoSubcontrolsSelected

          readonly property int firstMovableIndex: zoneCol.zoneName === "left" ? 1 : 0

          ColumnLayout {
            id: boxColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
              id: contentRow
              Layout.fillWidth: true
              spacing: Style.marginM
              NIcon {
                icon: cardBox.meta.icon
                pointSize: Style.fontSizeL
                color: cardBox.modelData.enabled ? Color.mPrimary : Color.mOutline
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS

                RowLayout {
                  spacing: Style.marginS

                  NText {
                    text: cardBox.meta.name
                    pointSize: Style.fontSizeM
                    font.bold: true
                    color: cardBox.modelData.enabled ? Color.mOnSurface : Color.mOutline
                  }

                  NBox {
                    visible: cardBox.isLocked
                    Layout.preferredHeight: 18 * Style.uiScaleRatio
                    Layout.preferredWidth: lockedText.implicitWidth + Style.marginS * 2
                    color: Qt.alpha(Color.mPrimary, 0.15)
                    radius: Style.radiusS

                    NText {
                      id: lockedText
                      anchors.centerIn: parent
                      text: root.dtr("cardLocked")
                      pointSize: Style.fontSizeXS
                      font.bold: true
                      color: Color.mPrimary
                    }
                  }
                }

                NText {
                  text: cardBox.meta.description
                  pointSize: Style.fontSizeS
                  color: Color.mOutline
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
              }
            }

            // Move Up
            NIconButton {
              icon: "chevron-up"
              tooltipText: I18n.tr("common.move-up")
              enabled: !cardBox.isLocked && cardBox.index > cardBox.firstMovableIndex
              onClicked: {
                Settings.reorderControlCenterCards(zoneCol.zoneName, cardBox.index, cardBox.index - 1);
              }
            }

            // Move Down
            NIconButton {
              icon: "chevron-down"
              tooltipText: I18n.tr("common.move-down")
              enabled: !cardBox.isLocked && cardBox.index < cardBox.totalInZone - 1
              onClicked: {
                Settings.reorderControlCenterCards(zoneCol.zoneName, cardBox.index, cardBox.index + 1);
              }
            }

            // Toggle switch - disabled when locked or when it is the last enabled card in this zone

            Item {
              Layout.preferredWidth: cardToggle.implicitWidth
              Layout.preferredHeight: cardToggle.implicitHeight

              NToggle {
                id: cardToggle
                anchors.centerIn: parent
                checked: cardBox.isLocked ? true : cardBox.modelData.enabled
                enabled: cardBox.canToggle
                onToggled: {
                  Settings.setControlCenterCardEnabled(cardBox.modelData.id, checked);
                }
              }

              MouseArea {
                anchors.fill: parent
                enabled: !cardBox.canToggle
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                  if (cardBox.isLocked) {
                    TooltipService.show(cardToggle, root.dtr("cardLocked"));
                  } else if (cardBox.isLastEnabledInZone) {
                    TooltipService.show(cardToggle, root.dtr("cardZoneMinimumRequired"));
                  } else if (cardBox.hasNoSubcontrolsSelected) {
                    TooltipService.show(cardToggle, root.dtr("cardEnableSubcontrolFirst"));
                  }
                }
                onExited: {
                  TooltipService.hide();
                }
              }
            }

            // Subordinate switches for system-controls
            ColumnLayout {
              id: controlSettings
              visible: cardBox.isSystemControls
              Layout.fillWidth: true
              Layout.preferredHeight: visible ? implicitHeight : 0
              Layout.leftMargin: Style.marginXL
              Layout.rightMargin: Style.marginS
              Layout.topMargin: Style.marginXXS
              Layout.bottomMargin: Style.marginXXS
              spacing: Style.marginS

              readonly property bool isParentOn: cardBox.modelData.enabled
              readonly property bool audioOn: Settings.data.controlCenter.audioControlsEnabled !== false
              readonly property bool brightnessOn: Settings.data.controlCenter.brightnessControlEnabled !== false

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.borderS
                color: Qt.alpha(Color.mOutline, 0.15)
              }

              // Subordinate 1: Audio Controls
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                  icon: "volume"
                  pointSize: Style.fontSizeM
                  color: controlSettings.audioOn ? Color.mPrimary : Color.mOutline
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: root.dtr("cardAudioControlsLabel")
                    pointSize: Style.fontSizeS
                    font.bold: true
                    color: controlSettings.audioOn ? Color.mOnSurface : Color.mOutline
                  }

                  NText {
                    text: root.dtr("cardAudioControlsDesc")
                    pointSize: Style.fontSizeXS
                    color: Color.mOutline
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                  }
                }

                Item {
                  Layout.preferredWidth: audioToggle.implicitWidth
                  Layout.preferredHeight: audioToggle.implicitHeight

                  readonly property bool canToggleAudio: !controlSettings.isParentOn || controlSettings.brightnessOn

                  NToggle {
                    id: audioToggle
                    anchors.centerIn: parent
                    checked: controlSettings.audioOn
                    enabled: parent.canToggleAudio
                    onToggled: function (val) {
                      Settings.setControlCenterAudioControlsEnabled(val);
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    enabled: !parent.canToggleAudio
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                      TooltipService.show(audioToggle, root.dtr("cardSubcontrolRequired"));
                    }
                    onExited: {
                      TooltipService.hide();
                    }
                  }
                }
              }

              // Subordinate 2: Brightness Control
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                  icon: "brightness-up"
                  pointSize: Style.fontSizeM
                  color: controlSettings.brightnessOn ? Color.mPrimary : Color.mOutline
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: root.dtr("cardBrightnessControlLabel")
                    pointSize: Style.fontSizeS
                    font.bold: true
                    color: controlSettings.brightnessOn ? Color.mOnSurface : Color.mOutline
                  }

                  NText {
                    text: root.dtr("cardBrightnessControlDesc")
                    pointSize: Style.fontSizeXS
                    color: Color.mOutline
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                  }
                }

                Item {
                  Layout.preferredWidth: brightnessToggle.implicitWidth
                  Layout.preferredHeight: brightnessToggle.implicitHeight

                  readonly property bool canToggleBrightness: !controlSettings.isParentOn || controlSettings.audioOn

                  NToggle {
                    id: brightnessToggle
                    anchors.centerIn: parent
                    checked: controlSettings.brightnessOn
                    enabled: parent.canToggleBrightness
                    onToggled: function (val) {
                      Settings.setControlCenterBrightnessControlEnabled(val);
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    enabled: !parent.canToggleBrightness
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                      TooltipService.show(brightnessToggle, root.dtr("cardSubcontrolRequired"));
                    }
                    onExited: {
                      TooltipService.hide();
                    }
                  }
                }
              }
            }
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
        visible: zoneCol.modelData.zone !== "right"
      }
    }
  }

  // Reset to Defaults Button
  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM

    Item {
      Layout.fillWidth: true
    }

    NButton {
      text: I18n.tr("common.reset-to-default")
      icon: "restore"
      onClicked: {
        Settings.resetControlCenterCards();
      }
    }
  }
}
