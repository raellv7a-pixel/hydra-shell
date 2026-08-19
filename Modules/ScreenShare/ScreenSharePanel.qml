import QtQuick
import QtQuick.Layouts
import Quickshell
import "Components"
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Widgets

// Seletor de compartilhamento de tela.
//
// É um SmartPanel para participar do sistema de fundo compartilhado: o
// AllBackgrounds do MainScreen desenha barra e painel como uma única Shape, o que
// produz a junção côncava com a moldura. Desenhar o próprio fundo deixaria o
// painel "flutuando" em vez de preso à moldura.
SmartPanel {
  id: root

  preferredWidth: Math.round(900 * Style.uiScaleRatio)
  preferredHeight: Math.round(680 * Style.uiScaleRatio)
  preferredWidthRatio: 0
  preferredHeightRatio: 0

  // Emoldurado: acopla à esquerda, centralizado na vertical (o menu de sessão faz
  // o espelho disso, à direita). Demais modos: centro da tela.
  panelAnchorHorizontalCenter: !isFramed
  panelAnchorVerticalCenter: true
  panelAnchorLeft: isFramed

  function onEscapePressed() {
    root.cancelSelection();
  }

  // --- estado da seleção --------------------------------------------------------

  property int activeTab: 0
  property string selectionType: ""
  property string selectedScreenName: ""
  property string selectedWindowHandle: ""

  readonly property bool hasSelection: root.selectionType !== ""

  readonly property var screenSources: {
    // snapshotVersion entra na dependência para reavaliar quando o grim termina.
    const version = ScreenShareService.snapshotVersion;
    const list = [];
    for (var i = 0; i < Quickshell.screens.length; i++) {
      const s = Quickshell.screens[i];
      list.push({
                  "name": s.name,
                  "width": s.width,
                  "height": s.height,
                  "thumbnail": version > 0 ? ScreenShareService.snapshotPath(s.name) : ""
                });
    }
    return list;
  }

  function resetSelection() {
    root.activeTab = 0;
    root.selectionType = "";
    root.selectedScreenName = "";
    root.selectedWindowHandle = "";
  }

  function confirmSelection() {
    if (root.selectionType === "screen" && root.selectedScreenName !== "")
      ScreenShareService.submitScreen(root.selectedScreenName);
    else if (root.selectionType === "window" && root.selectedWindowHandle !== "")
      ScreenShareService.submitWindow(root.selectedWindowHandle);
  }

  function cancelSelection() {
    ScreenShareService.cancel();
  }

  panelContent: Component {
    Item {
      anchors.fill: parent
      focus: true

      Keys.onPressed: function (event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.hasSelection) {
          root.confirmSelection();
          event.accepted = true;
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingCard
        spacing: Style.spaceS

        // --- cabeçalho ----------------------------------------------------------

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spaceS

          NImageRounded {
            Layout.preferredWidth: Style.fontSizeTitleMedium * 2
            Layout.preferredHeight: Style.fontSizeTitleMedium * 2
            visible: ScreenShareService.requestingAppIcon !== ""
            imagePath: ScreenShareService.requestingAppIcon
            fallbackIcon: "cast"
            radius: Style.radiusCard
            borderWidth: 0
          }

          Rectangle {
            Layout.preferredWidth: Style.fontSizeTitleMedium * 2
            Layout.preferredHeight: Style.fontSizeTitleMedium * 2
            visible: ScreenShareService.requestingAppIcon === ""
            radius: Style.radiusCard
            color: Qt.alpha(Color.mPrimary, 0.16)

            NIcon {
              anchors.centerIn: parent
              icon: "screen-share"
              pointSize: Style.fontSizeTitleMedium
              color: Color.mPrimary
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spaceXXS

            NText {
              Layout.fillWidth: true
              text: I18n.tr("screen-share.title")
              pointSize: Style.fontSizeTitleMedium
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              elide: Text.ElideRight
            }

            NText {
              Layout.fillWidth: true
              text: ScreenShareService.requestingAppName !== "" ? I18n.tr("screen-share.subtitle-app", {
                                                                            "app": ScreenShareService.requestingAppName
                                                                          }) : I18n.tr("screen-share.subtitle-generic")
              pointSize: Style.fontSizeLabelMedium
              color: Color.mOnSurfaceVariant
              elide: Text.ElideRight
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("screen-share.cancel")
            onClicked: root.cancelSelection()
          }
        }

        // --- abas ---------------------------------------------------------------

        NTabBar {
          Layout.fillWidth: true
          currentIndex: root.activeTab
          distributeEvenly: true

          NTabButton {
            text: I18n.tr("screen-share.tab-screens")
            icon: "device-desktop"
            tabIndex: 0
            checked: root.activeTab === 0
            onClicked: root.activeTab = 0
          }
          NTabButton {
            text: I18n.tr("screen-share.tab-windows")
            icon: "app-window"
            tabIndex: 1
            checked: root.activeTab === 1
            onClicked: root.activeTab = 1
          }
          NTabButton {
            text: I18n.tr("screen-share.tab-region")
            icon: "crop"
            tabIndex: 2
            checked: root.activeTab === 2
            onClicked: root.activeTab = 2
          }
        }

        // --- conteúdo -----------------------------------------------------------

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          // Telas
          NGridView {
            id: screensGrid
            anchors.fill: parent
            visible: root.activeTab === 0
            model: root.screenSources
            cellWidth: Math.floor(screensGrid.availableWidth / Math.max(1, Math.min(3, root.screenSources.length)))
            cellHeight: Math.round(210 * Style.uiScaleRatio)

            delegate: Item {
              required property var modelData
              width: screensGrid.cellWidth
              height: screensGrid.cellHeight

              ShareSourceCard {
                anchors.fill: parent
                anchors.margins: Style.spaceXXS
                title: parent.modelData.name
                subtitle: parent.modelData.width + " × " + parent.modelData.height
                emptyIcon: "device-desktop"
                thumbnailPath: parent.modelData.thumbnail
                selected: root.selectionType === "screen" && root.selectedScreenName === parent.modelData.name
                onClicked: {
                  root.selectionType = "screen";
                  root.selectedScreenName = parent.modelData.name;
                }
                onActivated: {
                  root.selectionType = "screen";
                  root.selectedScreenName = parent.modelData.name;
                  root.confirmSelection();
                }
              }
            }
          }

          // Janelas
          NGridView {
            id: windowsGrid
            anchors.fill: parent
            visible: root.activeTab === 1
            model: ScreenShareService.windowSources
            cellWidth: Math.floor(windowsGrid.availableWidth / 3)
            cellHeight: Math.round(210 * Style.uiScaleRatio)

            delegate: Item {
              required property var modelData
              width: windowsGrid.cellWidth
              height: windowsGrid.cellHeight

              ShareSourceCard {
                anchors.fill: parent
                anchors.margins: Style.spaceXXS
                title: parent.modelData.title !== "" ? parent.modelData.title : parent.modelData.appClass
                badgeText: parent.modelData.appClass
                emptyIcon: "app-window"
                appIcon: ThemeIcons.iconForAppId(parent.modelData.appClass)
                liveSource: parent.modelData.toplevel ? parent.modelData.toplevel.wayland : null
                selected: root.selectionType === "window" && root.selectedWindowHandle === parent.modelData.handle
                onClicked: {
                  root.selectionType = "window";
                  root.selectedWindowHandle = parent.modelData.handle;
                }
                onActivated: {
                  root.selectionType = "window";
                  root.selectedWindowHandle = parent.modelData.handle;
                  root.confirmSelection();
                }
              }
            }
          }

          // Estado vazio das janelas
          ColumnLayout {
            anchors.centerIn: parent
            visible: root.activeTab === 1 && ScreenShareService.windowSources.length === 0
            spacing: Style.spaceXS

            NIcon {
              Layout.alignment: Qt.AlignHCenter
              icon: "app-window"
              pointSize: Style.fontSizeHeadlineSmall
              color: Qt.alpha(Color.mOnSurfaceVariant, 0.5)
            }
            NText {
              Layout.alignment: Qt.AlignHCenter
              text: I18n.tr("screen-share.no-windows")
              pointSize: Style.fontSizeLabelMedium
              color: Color.mOnSurfaceVariant
            }
          }

          // Região
          ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, Math.round(420 * Style.uiScaleRatio))
            visible: root.activeTab === 2
            spacing: Style.spaceS

            NIcon {
              Layout.alignment: Qt.AlignHCenter
              icon: "crop"
              pointSize: Style.fontSizeHeadlineSmall
              color: Color.mPrimary
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("screen-share.region-hint")
              horizontalAlignment: Text.AlignHCenter
              pointSize: Style.fontSizeLabelMedium
              color: Color.mOnSurfaceVariant
              wrapMode: Text.Wrap
            }

            NButton {
              Layout.alignment: Qt.AlignHCenter
              text: I18n.tr("screen-share.region-select")
              icon: "crop"
              backgroundColor: Color.mPrimary
              textColor: Color.mOnPrimary
              onClicked: ScreenShareService.requestRegion()
            }
          }
        }

        // --- aviso de privacidade -----------------------------------------------

        Rectangle {
          Layout.fillWidth: true
          visible: root.selectionType === "screen"
          radius: Style.radiusCard
          color: Qt.alpha(Color.mError, 0.12)
          implicitHeight: warningRow.implicitHeight + Style.spaceXS * 2

          RowLayout {
            id: warningRow
            anchors.fill: parent
            anchors.margins: Style.spaceXS
            spacing: Style.spaceXS

            NIcon {
              icon: "alert-triangle"
              pointSize: Style.fontSizeBodySmall
              color: Color.mError
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("screen-share.screen-warning", {
                              "screen": root.selectedScreenName
                            })
              pointSize: Style.fontSizeLabelSmall
              color: Color.mOnSurface
              wrapMode: Text.Wrap
            }
          }
        }

        // --- rodapé -------------------------------------------------------------

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spaceS

          NToggle {
            Layout.fillWidth: true
            label: I18n.tr("screen-share.remember")
            description: I18n.tr("screen-share.remember-description")
            checked: ScreenShareService.allowToken
            onToggled: checked => ScreenShareService.allowToken = checked
          }

          NButton {
            text: I18n.tr("screen-share.cancel")
            backgroundColor: Color.mSurfaceVariant
            textColor: Color.mOnSurfaceVariant
            outlined: false
            onClicked: root.cancelSelection()
          }

          NButton {
            text: I18n.tr("screen-share.confirm")
            icon: "screen-share"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            enabled: root.hasSelection
            onClicked: root.confirmSelection()
          }
        }
      }
    }
  }
}
