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

  property var cfg: PolkitService.settings

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
        checked: root.cfg.enabled ?? true
        onToggled: checked => {
          root.cfg.enabled = checked;
          PolkitService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: root.cfg.enabled ?? true
        label: "Posição da Janela de Autenticação"
        description: "Escolha onde o prompt de senha de administrador será exibido"
        currentKey: root.cfg.position ?? "center"
        model: [
          { key: "center", name: "Centralizado no Centro da Tela" },
          { key: "attached", name: "Acoplado à Barra Superior da Shell" }
        ]
        onSelected: key => {
          root.cfg.position = key;
          PolkitService.saveSettings();
        }
      }

      Item { Layout.preferredHeight: Style.marginS }

      NText {
        text: "Comportamento & Efeitos Visuais"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.cfg.enabled ?? true
        label: "Efeito de Vibração em Caso de Erro"
        description: "Vibra a janela suavemente quando a senha de administrador estiver incorreta"
        checked: root.cfg.errorShake ?? true
        onToggled: checked => {
          root.cfg.errorShake = checked;
          PolkitService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.cfg.enabled ?? true
        label: "Foco Automático na Digitação"
        description: "Direciona o teclado automaticamente para o campo de senha ao abrir a janela"
        checked: root.cfg.autoFocus ?? true
        onToggled: checked => {
          root.cfg.autoFocus = checked;
          PolkitService.saveSettings();
        }
      }
    }
  }
}
