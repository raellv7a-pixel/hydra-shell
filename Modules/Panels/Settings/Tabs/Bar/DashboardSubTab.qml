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
  implicitHeight: subTabBar.implicitHeight + contentCol.implicitHeight + Style.marginM * 4

  property var cfg: ControlCenterService.settings
  property int subTab: 0

  // Navegação por abas em Português Brasileiro (pt_BR)
  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    currentIndex: root.subTab
    distributeEvenly: true

    NTabButton {
      text: "Janela & Layout"
      tabIndex: 0
      checked: root.subTab === 0
      onClicked: root.subTab = 0
    }
    NTabButton {
      text: "Perfil & Banner"
      tabIndex: 1
      checked: root.subTab === 1
      onClicked: root.subTab = 1
    }
    NTabButton {
      text: "Efeitos & Áudio"
      tabIndex: 2
      checked: root.subTab === 2
      onClicked: root.subTab = 2
    }
    NTabButton {
      text: "Seções da Tela"
      tabIndex: 3
      checked: root.subTab === 3
      onClicked: root.subTab = 3
    }
  }

  ColumnLayout {
    id: contentCol
    Layout.fillWidth: true
    spacing: Style.marginL

    // ==========================================
    // SUBTAB 0: JANELA & LAYOUT
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 0
      spacing: Style.marginM

      NText {
        text: "Comportamento da Janela"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Painel Destacado (Flutuante)"
        description: "Exibe a central flutuante no centro ou posição fixa, desvinculada da barra"
        checked: root.cfg.panelDetached ?? true
        onToggled: checked => {
          root.cfg.panelDetached = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        visible: !root.cfg.panelDetached
        label: "Seguir Posição da Barra"
        description: "Anexa a central na mesma borda da tela onde a barra principal está posicionada"
        checked: root.cfg.followBarEdge ?? true
        onToggled: checked => {
          root.cfg.followBarEdge = checked;
          ControlCenterService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Posição da Janela na Tela"
        description: "Alinhamento padrão da janela da central de controle"
        currentKey: root.cfg.panelPosition ?? "center"
        model: [
          { key: "center", name: "Centralizado" },
          { key: "top_left", name: "Superior Esquerdo" },
          { key: "top_right", name: "Superior Direito" },
          { key: "bottom_left", name: "Inferior Esquerdo" },
          { key: "bottom_right", name: "Inferior Direito" },
          { key: "left", name: "Esquerda" },
          { key: "right", name: "Direita" }
        ]
        onSelected: key => {
          root.cfg.panelPosition = key;
          ControlCenterService.saveSettings();
        }
      }

      Item { Layout.preferredHeight: Style.marginS }

      NText {
        text: "Dimensões e Escala"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NValueSlider {
        Layout.fillWidth: true
        label: "Largura da Central (px)"
        from: 800
        to: 1400
        stepSize: 20
        value: root.cfg.panelWidth ?? 1120
        onMoved: val => {
          root.cfg.panelWidth = Math.round(val);
          ControlCenterService.saveSettings();
        }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: "Altura da Central (px)"
        from: 500
        to: 950
        stepSize: 20
        value: root.cfg.panelHeight ?? 700
        onMoved: val => {
          root.cfg.panelHeight = Math.round(val);
          ControlCenterService.saveSettings();
        }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: "Escala Geral da Interface"
        from: 0.7
        to: 1.3
        stepSize: 0.05
        value: root.cfg.panelScale ?? 1.0
        onMoved: val => {
          root.cfg.panelScale = Math.round(val * 100) / 100;
          ControlCenterService.saveSettings();
        }
      }
    }

    // ==========================================
    // SUBTAB 1: PERFIL & BANNER
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 1
      spacing: Style.marginM

      NText {
        text: "Foto de Perfil & Animação"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Formato da Foto de Perfil"
        currentKey: root.cfg.avatarShape ?? "circle"
        model: [
          { key: "circle", name: "Círculo" },
          { key: "rounded", name: "Canto Arredondado" },
          { key: "square", name: "Quadrado" }
        ]
        onSelected: key => {
          root.cfg.avatarShape = key;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Mascote GIF Animado"
        description: "Mostra um pequeno mascote GIF animado ao lado do cartão de perfil"
        checked: root.cfg.showProfileDanceGif ?? true
        onToggled: checked => {
          root.cfg.showProfileDanceGif = checked;
          ControlCenterService.saveSettings();
        }
      }

      Item { Layout.preferredHeight: Style.marginS }

      NText {
        text: "Capa do Banner de Perfil"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Modo de Imagem do Banner"
        description: "Origem da imagem exibida no topo do cartão de perfil"
        currentKey: root.cfg.profileCoverMode ?? "auto"
        model: [
          { key: "auto", name: "Automático (Usa o Papel de Parede Atual)" },
          { key: "custom", name: "Imagem Personalizada" },
          { key: "random", name: "Aleatório de uma Pasta" },
          { key: "none", name: "Desativado (Cor Sólida)" }
        ]
        onSelected: key => {
          root.cfg.profileCoverMode = key;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Escurecimento Suave (Overlay)"
        description: "Aplica um tom escuro sobre o banner para destacar o texto"
        checked: root.cfg.profileCoverOverlayEnabled ?? true
        onToggled: checked => {
          root.cfg.profileCoverOverlayEnabled = checked;
          ControlCenterService.saveSettings();
        }
      }

      NValueSlider {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverOverlayEnabled ?? true
        label: "Intensidade do Escurecimento"
        from: 0.1
        to: 0.9
        stepSize: 0.05
        value: root.cfg.profileCoverOverlay ?? 0.58
        onMoved: val => {
          root.cfg.profileCoverOverlay = Math.round(val * 100) / 100;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Borda Decorativa no Cartão"
        description: "Aplica uma borda estilizada ao redor do cartão de perfil"
        checked: root.cfg.profileCoverBorder ?? true
        onToggled: checked => {
          root.cfg.profileCoverBorder = checked;
          ControlCenterService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverBorder ?? true
        label: "Efeito de Animação da Borda"
        currentKey: root.cfg.profileCoverBorderAnimation ?? "static"
        model: [
          { key: "static", name: "Estática" },
          { key: "rotate", name: "Rotação de Cores" },
          { key: "pulse", name: "Pulsação Suave" }
        ]
        onSelected: key => {
          root.cfg.profileCoverBorderAnimation = key;
          ControlCenterService.saveSettings();
        }
      }
    }

    // ==========================================
    // SUBTAB 2: EFEITOS & ÁUDIO
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 2
      spacing: Style.marginM

      NText {
        text: "Visualizadores de Áudio"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Espectro de Mídia na Central"
        description: "Estilo visual do espectro ao tocar músicas"
        currentKey: root.cfg.mediaVisualizerEffect ?? "bars"
        model: [
          { key: "bars", name: "Barras Verticais" },
          { key: "wave", name: "Onda Fluida" },
          { key: "dots", name: "Pontos Pulsantes" },
          { key: "none", name: "Desativado" }
        ]
        onSelected: key => {
          root.cfg.mediaVisualizerEffect = key;
          ControlCenterService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Efeito no Controle de Volume"
        description: "Efeito animado sobre a barra de volume principal"
        currentKey: root.cfg.audioSliderEffect ?? "wave"
        model: [
          { key: "wave", name: "Onda Fluida" },
          { key: "pulse", name: "Pulsação de Som" },
          { key: "none", name: "Padrão" }
        ]
        onSelected: key => {
          root.cfg.audioSliderEffect = key;
          ControlCenterService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Efeito no Controle de Microfone"
        description: "Efeito animado para a barra de entrada de áudio"
        currentKey: root.cfg.microphoneSliderEffect ?? "pulse"
        model: [
          { key: "pulse", name: "Pulsação de Voz" },
          { key: "wave", name: "Onda Fluida" },
          { key: "none", name: "Padrão" }
        ]
        onSelected: key => {
          root.cfg.microphoneSliderEffect = key;
          ControlCenterService.saveSettings();
        }
      }

      Item { Layout.preferredHeight: Style.marginS }

      NText {
        text: "Desempenho e Energia"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Respeitar Modo Desempenho da Shell"
        description: "Pausa os efeitos visuais pesados quando o modo Performance estiver ativo"
        checked: root.cfg.followNoctaliaPerformanceMode ?? true
        onToggled: checked => {
          root.cfg.followNoctaliaPerformanceMode = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Economia em Uso de Bateria"
        description: "Reduz o uso de CPU/GPU ao usar a bateria do notebook"
        checked: root.cfg.powerSaverPerformanceMode ?? true
        onToggled: checked => {
          root.cfg.powerSaverPerformanceMode = checked;
          ControlCenterService.saveSettings();
        }
      }
    }

    // ==========================================
    // SUBTAB 3: SEÇÕES DA TELA
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 3
      spacing: Style.marginM

      NText {
        text: "Cards Visíveis na Central de Controle"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Painel de Notificações"
        checked: root.cfg.showNotifications ?? true
        onToggled: checked => {
          root.cfg.showNotifications = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Player de Mídia"
        checked: root.cfg.showMedia ?? true
        onToggled: checked => {
          root.cfg.showMedia = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Calendário e Eventos"
        checked: root.cfg.showCalendar ?? true
        onToggled: checked => {
          root.cfg.showCalendar = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Ferramentas de Captura"
        checked: root.cfg.showRecordingCard ?? true
        onToggled: checked => {
          root.cfg.showRecordingCard = checked;
          ControlCenterService.saveSettings();
        }
      }

      Item { Layout.preferredHeight: Style.marginS }

      NText {
        text: "Mídia na Barra Superior"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Mídia na Barra"
        checked: root.cfg.showBarMediaInfo ?? true
        onToggled: checked => {
          root.cfg.showBarMediaInfo = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.cfg.showBarMediaInfo ?? true
        label: "Exibir Capa do Álbum na Barra"
        checked: root.cfg.barMediaShowAlbumArt ?? true
        onToggled: checked => {
          root.cfg.barMediaShowAlbumArt = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.cfg.showBarMediaInfo ?? true
        label: "Exibir Progresso da Música na Barra"
        checked: root.cfg.barMediaShowProgressRing ?? true
        onToggled: checked => {
          root.cfg.barMediaShowProgressRing = checked;
          ControlCenterService.saveSettings();
        }
      }
    }
  }
}
