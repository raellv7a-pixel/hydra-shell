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

  spacing: Style.marginM
  Layout.fillWidth: true
  Layout.fillHeight: true

  ScrollView {
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
      id: contentCol
      width: root.width - Style.marginL * 2
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.marginL

      NText {
        text: "Agente de Autenticação Polkit"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Agente Polkit Nativo da Shell"
        description: "Habilita a caixa de diálogo nativa da Hydra Shell para elevação de privilégios administrativos (sudo / pkexec)"
        checked: PolkitService.enabled
        onToggled: checked => {
          PolkitService.enabled = checked;
        }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: PolkitService.enabled
        label: "Posição da Janela de Autenticação"
        description: "Escolha onde o prompt de senha de administrador será exibido"
        currentKey: PolkitService.position
        model: [
          {
            key: "center",
            name: "Centralizado no Centro da Tela"
          },
          {
            key: "attached",
            name: "Acoplado à Barra Superior da Shell"
          }
        ]
        onSelected: key => {
          PolkitService.position = key;
        }
      }

      Item {
        Layout.preferredHeight: Style.marginS
      }

      NText {
        text: "Comportamento & Efeitos Visuais"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        visible: PolkitService.enabled
        label: "Efeito de Vibração em Caso de Erro"
        description: "Vibra a janela suavemente quando a senha de administrador estiver incorreta"
        checked: PolkitService.errorShake
        onToggled: checked => {
          PolkitService.errorShake = checked;
        }
      }

      NToggle {
        Layout.fillWidth: true
        visible: PolkitService.enabled
        label: "Foco Automático na Digitação"
        description: "Direciona o teclado automaticamente para o campo de senha ao abrir a janela"
        checked: PolkitService.autoFocus
        onToggled: checked => {
          PolkitService.autoFocus = checked;
        }
      }
    }
  }
}
