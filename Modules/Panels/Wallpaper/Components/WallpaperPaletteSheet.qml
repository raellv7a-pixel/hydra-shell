import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property string wallpaperPath: ""
  property string screenName: ""

  function copyHexToClipboard(hex, label) {
    if (typeof Quickshell !== "undefined" && Quickshell.execDetached) {
      Quickshell.execDetached(["bash", "-c", "printf '%s' '" + hex + "' | wl-copy 2>/dev/null || printf '%s' '" + hex + "' | xclip -selection clipboard 2>/dev/null"]);
    }
    ToastService.showNotice("Paleta de Cores", label + " (" + hex + ") copiado para a área de transferência!", "palette", 2500);
  }

  RowLayout {
    anchors.fill: parent
    spacing: Style.marginL

    // Left Box: Extracted Color Swatches & Cards
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 3
      color: Color.mSurfaceVariant
      radius: Style.radiusM

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          NIcon {
            icon: "color-swatch"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }

          NText {
            text: "Paleta Extraída do Papel de Parede"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NButton {
            text: "Recalcular Cores"
            icon: "refresh"
            fontSize: Style.fontSizeS
            onClicked: AppThemeService.generate()
          }
        }

        NDivider { Layout.fillWidth: true }

        // Core Extracted Colors Grid
        GridLayout {
          Layout.fillWidth: true
          columns: 3
          rowSpacing: Style.marginM
          columnSpacing: Style.marginM

          // Color Card Component
          component ColorCard: Rectangle {
            id: cCard
            property string title: ""
            property color swColor: "#000000"
            property string hexStr: swColor.toString()

            Layout.fillWidth: true
            height: 70
            radius: Style.radiusS
            color: swColor
            border.color: Qt.alpha(Color.mOnSurface, 0.2)
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyHexToClipboard(cCard.hexStr, cCard.title)
            }

            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: 28
              color: Qt.alpha("#000000", 0.65)
              radius: Style.radiusS

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                NText {
                  text: cCard.title
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightBold
                  color: "#ffffff"
                  Layout.fillWidth: true
                }

                NText {
                  text: cCard.hexStr.toUpperCase()
                  pointSize: Style.fontSizeXS
                  color: "#e0e0e0"
                }
              }
            }
          }

          ColorCard { title: "Primária"; swColor: Color.mPrimary }
          ColorCard { title: "Secundária"; swColor: Color.mSecondary }
          ColorCard { title: "Terciária"; swColor: Color.mTertiary }
          ColorCard { title: "Superfície"; swColor: Color.mSurface }
          ColorCard { title: "Variante"; swColor: Color.mSurfaceVariant }
          ColorCard { title: "Fundo"; swColor: Color.mBackground }
        }

        NDivider { Layout.fillWidth: true }

        NText {
          text: "Tonalidades do Tema Material (Pywal)"
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightBold
          color: Color.mOnSurfaceVariant
        }

        // Palette Swatch Bar
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          Repeater {
            model: [
              { name: "P-90", col: Qt.tint(Color.mPrimary, Qt.rgba(1,1,1,0.6)) },
              { name: "P-80", col: Color.mPrimary },
              { name: "P-40", col: Qt.darker(Color.mPrimary, 1.4) },
              { name: "S-80", col: Color.mSecondary },
              { name: "S-40", col: Qt.darker(Color.mSecondary, 1.4) },
              { name: "T-80", col: Color.mTertiary },
              { name: "Surf", col: Color.mSurface },
              { name: "Bg", col: Color.mBackground }
            ]

            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              height: 48
              radius: Style.radiusS
              color: modelData.col
              border.color: Qt.alpha(Color.mOnSurface, 0.2)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyHexToClipboard(modelData.col.toString(), modelData.name)
              }

              NText {
                anchors.centerIn: parent
                text: modelData.name
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightBold
                color: Qt.luminance(modelData.col) > 0.5 ? "#000000" : "#ffffff"
              }
            }
          }
        }
      }
    }

    // Right Box: Palette Settings & Generation Schemes
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 2
      color: Color.mSurfaceVariant
      radius: Style.radiusM

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
          text: "Método de Geração de Cores"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }

        NDivider { Layout.fillWidth: true }

        NComboBox {
          id: schemeMethodCombo
          Layout.fillWidth: true
          model: TemplateProcessor.schemeTypes || []
          currentKey: Settings.data.colorSchemes.generationMethod
          onSelected: key => {
            Settings.data.colorSchemes.generationMethod = key;
            if (Settings.data.colorSchemes.useWallpaperColors) {
              AppThemeService.generate();
            }
          }
        }

        NText {
          text: "Dica: Clique em qualquer cartão ou bloco de cor para copiar o valor Hexadecimal."
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        // Live Mode Switcher
        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: 70
          color: Color.mSurface
          radius: Style.radiusS

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
              text: "Status da Tematização"
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            RowLayout {
              Layout.fillWidth: true

              NText {
                text: Settings.data.colorSchemes.useWallpaperColors ? "Extração Dinâmica Ativa" : "Cores Predefinidas"
                color: Color.mPrimary
                Layout.fillWidth: true
              }

              NIconButton {
                icon: "palette"
                tooltipText: "Alternar entre cores dinâmicas do wallpaper e esquemas manuais"
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: Settings.data.colorSchemes.useWallpaperColors ? Color.mPrimary : Color.mSurfaceVariant
                colorFg: Settings.data.colorSchemes.useWallpaperColors ? Color.mOnPrimary : Color.mPrimary
                onClicked: {
                  Settings.data.colorSchemes.useWallpaperColors = !Settings.data.colorSchemes.useWallpaperColors;
                  if (Settings.data.colorSchemes.useWallpaperColors) {
                    AppThemeService.generate();
                  } else {
                    ColorSchemeService.setPredefinedScheme(Settings.data.colorSchemes.predefinedScheme);
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
