import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Compositor

NScrollView {
  id: root

  property bool useRecommended: true
  signal recommendedSelected(bool enabled)
  signal committed
  signal failed(string message)

  readonly property bool externallyOwned: UmbrielKeybindStore.externallyOwned
  readonly property bool busy: UmbrielKeybindStore.busy
  readonly property bool blocked: !UmbrielKeybindStore.loaded || busy || UmbrielKeybindStore.error !== ""
  readonly property string summary: useRecommended
    ? (externallyOwned
        ? I18n.tr("setup.hydra.controls.summary-external")
        : I18n.tr("setup.hydra.controls.summary-recommended"))
    : I18n.tr("setup.hydra.controls.summary-keep")

  SetupShortcuts {
    id: shortcuts
  }

  readonly property var catalogEssentials: [
    {
      id: "shell.launcher",
      titleKey: "setup.hydra.controls.essential-launcher-title",
      descKey: "setup.hydra.controls.essential-launcher-desc",
      chord: shortcuts.launcherChord,
      icon: "rocket"
    },
    {
      id: "shell.control",
      titleKey: "setup.hydra.controls.essential-dashboard-title",
      descKey: "setup.hydra.controls.essential-dashboard-desc",
      chord: shortcuts.dashboardChord,
      icon: "layout-dashboard"
    },
    {
      id: "umbriel.overview",
      titleKey: "setup.hydra.controls.essential-overview-title",
      descKey: "setup.hydra.controls.essential-overview-desc",
      chord: shortcuts.overviewChord,
      icon: "layout-grid"
    },
    {
      id: "shell.switcher",
      titleKey: "setup.hydra.controls.essential-switcher-title",
      descKey: "setup.hydra.controls.essential-switcher-desc",
      chord: shortcuts.switcherChord,
      icon: "layers"
    },
    {
      id: "tool.region",
      titleKey: "setup.hydra.controls.essential-toolkit-title",
      descKey: "setup.hydra.controls.essential-toolkit-desc",
      chord: shortcuts.toolkitChord,
      icon: "camera"
    },
    {
      id: "shell.settings",
      titleKey: "setup.hydra.controls.essential-settings-title",
      descKey: "setup.hydra.controls.essential-settings-desc",
      chord: shortcuts.settingsChord,
      icon: "settings"
    }
  ]

  horizontalPolicy: ScrollBar.AlwaysOff
  verticalPolicy: ScrollBar.AlwaysOff

  Component.onCompleted: UmbrielKeybindStore.refreshForOnboarding()

  Connections {
    target: UmbrielKeybindStore
    function onCommittedState() {
      root.committed();
    }
    function onSaveFailed(message) {
      root.failed(message);
    }
  }

  function commit() {
    if (!useRecommended || externallyOwned) {
      root.committed();
      return;
    }

    UmbrielKeybindStore.commitRecommended();
  }

  ColumnLayout {
    width: root.availableWidth
    spacing: Style.marginXL

    NText {
      text: I18n.tr("setup.hydra.controls.header")
      pointSize: Style.fontSizeXXXL
      font.weight: Style.fontWeightBold
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }

    NText {
      text: I18n.tr("setup.hydra.controls.subheader")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeM
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }

    NBox {
      Layout.fillWidth: true
      visible: root.externallyOwned
      color: Color.mSurfaceContainerHigh
      implicitHeight: externalRow.implicitHeight + Style.marginL * 2

      RowLayout {
        id: externalRow
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NIcon {
          icon: "info-circle"
          pointSize: Style.fontSizeXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: I18n.tr("setup.hydra.controls.external-title")
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }

          NText {
            text: I18n.tr("setup.hydra.controls.external-description")
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            pointSize: Style.fontSizeS
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Rectangle {
          id: radioRec
          width: 22
          height: 22
          radius: 11
          color: "transparent"
          border.color: radioRec.activeFocus || root.useRecommended ? Color.mPrimary : Color.mOutline
          border.width: radioRec.activeFocus ? Style.borderL : Style.borderS
          activeFocusOnTab: true
          Accessible.role: Accessible.RadioButton
          Accessible.name: I18n.tr("setup.hydra.controls.recommended-title")
          Accessible.checked: root.useRecommended

          Keys.onSpacePressed: event => { root.recommendedSelected(true); event.accepted = true; }
          Keys.onReturnPressed: event => { root.recommendedSelected(true); event.accepted = true; }

          Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: Color.mPrimary
            visible: root.useRecommended
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              radioRec.forceActiveFocus();
              root.recommendedSelected(true);
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: I18n.tr("setup.hydra.controls.recommended-title")
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }
          NText {
            text: I18n.tr("setup.hydra.controls.recommended-description")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Rectangle {
          id: radioKeep
          width: 22
          height: 22
          radius: 11
          color: "transparent"
          border.color: radioKeep.activeFocus || !root.useRecommended ? Color.mPrimary : Color.mOutline
          border.width: radioKeep.activeFocus ? Style.borderL : Style.borderS
          activeFocusOnTab: true
          Accessible.role: Accessible.RadioButton
          Accessible.name: I18n.tr("setup.hydra.controls.keep-title")
          Accessible.checked: !root.useRecommended

          Keys.onSpacePressed: event => { root.recommendedSelected(false); event.accepted = true; }
          Keys.onReturnPressed: event => { root.recommendedSelected(false); event.accepted = true; }

          Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: Color.mPrimary
            visible: !root.useRecommended
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              radioKeep.forceActiveFocus();
              root.recommendedSelected(false);
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: I18n.tr("setup.hydra.controls.keep-title")
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }
          NText {
            text: I18n.tr("setup.hydra.controls.keep-description")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
          }
        }
      }
    }

    NText {
      text: I18n.tr("setup.hydra.controls.essentials-header")
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeL
      Layout.topMargin: Style.marginM
    }

    GridLayout {
      Layout.fillWidth: true
      columns: 2
      rowSpacing: Style.marginM
      columnSpacing: Style.marginM

      Repeater {
        model: root.catalogEssentials
        delegate: NBox {
          Layout.fillWidth: true
          implicitHeight: cardContent.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceContainer

          RowLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: modelData.icon
              pointSize: Style.fontSizeXL
              color: Color.mPrimary
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              NText {
                text: I18n.tr(modelData.titleKey)
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
              }

              NText {
                text: I18n.tr(modelData.descKey)
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }
            }

            Rectangle {
              height: 28
              radius: Style.radiusS
              color: Color.mSurfaceContainerHighest
              border.color: Color.mOutline
              border.width: Style.borderS
              implicitWidth: chordText.implicitWidth + Style.marginM * 2

              NText {
                id: chordText
                anchors.centerIn: parent
                text: modelData.chord
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeS
                color: Color.mPrimary
              }
            }
          }
        }
      }
    }

    NText {
      text: I18n.tr("setup.hydra.controls.change-later")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      Layout.topMargin: Style.marginS
    }
  }
}
