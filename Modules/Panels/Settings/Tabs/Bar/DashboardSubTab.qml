import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Flickable {
  id: root

  contentWidth: width
  contentHeight: contentCol.implicitHeight + Style.marginL * 2
  clip: true

  property var cfg: ControlCenterService.settings
  property int subTab: 0

  ColumnLayout {
    id: contentCol
    width: parent.width - Style.marginL * 2
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.marginL

    // Sub-tab Navigation
    NTabBar {
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
        text: "Seções & Mídia"
        tabIndex: 3
        checked: root.subTab === 3
        onClicked: root.subTab = 3
      }
    }

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
        description: "Exibe a dashboard flutuante no centro ou posição fixa, desvinculada da barra"
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
        description: "Anexa a dashboard na mesma borda da tela onde a barra principal está posicionada"
        checked: root.cfg.followBarEdge ?? true
        onToggled: checked => {
          root.cfg.followBarEdge = checked;
          ControlCenterService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Posição do Painel na Tela"
        description: "Alinhamento padrão da janela da dashboard"
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
        label: "Largura do Painel (px)"
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
        label: "Altura do Painel (px)"
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
        label: "Escala Geral da Dashboard"
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
        text: "Foto de Perfil & GIF"
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
        label: "Exibir GIF Dançante de Acompanhamento"
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
        label: "Modo da Capa de Fundo"
        description: "Origem da imagem exibida no topo do cartão de perfil"
        currentKey: root.cfg.profileCoverMode ?? "auto"
        model: [
          { key: "auto", name: "Automático (Usa o Wallpaper Atual)" },
          { key: "custom", name: "Imagem Personalizada" },
          { key: "random", name: "Aleatório de uma Pasta" },
          { key: "none", name: "Desativado (Apenas Cor Sólida)" }
        ]
        onSelected: key => {
          root.cfg.profileCoverMode = key;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Escurecer Capa (Overlay)"
        description: "Aplica um tom escuro suave sobre o banner para legibilidade dos textos"
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
        label: "Animação da Borda"
        currentKey: root.cfg.profileCoverBorderAnimation ?? "static"
        model: [
          { key: "static", name: "Estática" },
          { key: "rotate", name: "Rotação Gradiente" },
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
        text: "Visualizador de Mídia & Espectro"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Efeito do Visualizador no Painel"
        description: "Estilo do espectro de áudio ao reproduzir músicas"
        currentKey: root.cfg.mediaVisualizerEffect ?? "bars"
        model: [
          { key: "bars", name: "Barras Verticais" },
          { key: "wave", name: "Onda de Áudio" },
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
        label: "Efeito no Slider de Áudio"
        description: "Efeito visual animado sobre o controle de volume"
        currentKey: root.cfg.audioSliderEffect ?? "wave"
        model: [
          { key: "wave", name: "Onda Fluida" },
          { key: "pulse", name: "Pulsação" },
          { key: "none", name: "Padrão" }
        ]
        onSelected: key => {
          root.cfg.audioSliderEffect = key;
          ControlCenterService.saveSettings();
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: "Efeito no Slider de Microfone"
        description: "Efeito visual ao utilizar a entrada de áudio"
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
        text: "Desempenho & Economia de Energia"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Pausar Animações no Modo Performance"
        description: "Desativa espectros e efeitos visuais pesados quando o modo Performance da shell estiver ativo"
        checked: root.cfg.followNoctaliaPerformanceMode ?? true
        onToggled: checked => {
          root.cfg.followNoctaliaPerformanceMode = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Economia no Modo Bateria"
        description: "Reduz o consumo de renderização do visualizador de áudio quando em uso de bateria"
        checked: root.cfg.powerSaverPerformanceMode ?? true
        onToggled: checked => {
          root.cfg.powerSaverPerformanceMode = checked;
          ControlCenterService.saveSettings();
        }
      }
    }

    // ==========================================
    // SUBTAB 3: SEÇÕES & MÍDIA
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 3
      spacing: Style.marginM

      NText {
        text: "Cards Visíveis na Dashboard"
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
        label: "Exibir Controle de Mídia / Player"
        checked: root.cfg.showMedia ?? true
        onToggled: checked => {
          root.cfg.showMedia = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Calendário & Eventos"
        checked: root.cfg.showCalendar ?? true
        onToggled: checked => {
          root.cfg.showCalendar = checked;
          ControlCenterService.saveSettings();
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Card de Ferramentas de Gravação"
        checked: root.cfg.showRecordingCard ?? true
        onToggled: checked => {
          root.cfg.showRecordingCard = checked;
          ControlCenterService.saveSettings();
        }
      }

      Item { Layout.preferredHeight: Style.marginS }

      NText {
        text: "Mídia na Barra de Tarefas"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: "Exibir Informações de Mídia na Barra"
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
        label: "Exibir Anel de Progresso na Barra"
        checked: root.cfg.barMediaShowProgressRing ?? true
        onToggled: checked => {
          root.cfg.barMediaShowProgressRing = checked;
          ControlCenterService.saveSettings();
        }
      }
    }
  }
}
