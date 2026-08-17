import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets
import "."

// Hyprland tab (PLANO_INTEGRACAO_HYPRMOD.md §5) — gated to Hyprland via
// CompositorService.isHyprland, same pattern used ~15x elsewhere in the
// codebase. Every SubTab below reads/writes only through HyprlandDraftStore;
// this file owns the one thing that must be shared across all of them: the
// Save/Revert bar and the dirty indicator (ryoku-arch's "hub" chrome, see
// plan §3.5) — no SubTab has its own Save button.
ColumnLayout {
  id: root
  spacing: 0

  readonly property bool isHyprland: CompositorService.isHyprland
  readonly property bool ownershipLimited: Settings.data.hyprland.ownershipDeclined && !Settings.data.hyprland.ownershipAdopted

  Component.onCompleted: HyprlandDraftStore.load()

  // Not on Hyprland at all — nothing in this tab applies.
  ColumnLayout {
    visible: !root.isHyprland
    Layout.fillWidth: true
    Layout.topMargin: Style.marginXL
    spacing: Style.marginM

    NIcon {
      Layout.alignment: Qt.AlignHCenter
      icon: "alert-triangle"
      pointSize: Style.fontSizeXXL
      color: Color.mOnSurfaceVariant
    }
    NText {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      text: "Esta aba é específica do Hyprland com config Lua (0.55+). Não detectamos o Hyprland como compositor atual."
      color: Color.mOnSurfaceVariant
    }
  }

  ColumnLayout {
    visible: root.isHyprland
    Layout.fillWidth: true
    spacing: 0

    // "Modo limitado" banner — user declined adoption in the Setup Wizard.
    Rectangle {
      visible: root.ownershipLimited
      Layout.fillWidth: true
      Layout.bottomMargin: Style.marginM
      radius: Style.radiusM
      color: Color.mSurfaceVariant
      implicitHeight: limitedRow.implicitHeight + Style.marginM * 2

      RowLayout {
        id: limitedRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "info-circle"
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeL
        }
        NText {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          color: Color.mOnSurfaceVariant
          text: "Modo limitado: você optou por manter sua configuração atual do Hyprland. Esta aba só adiciona atalhos, regras e variáveis novas — não gerencia o que já existe. Adote a configuração da hydra-shell para liberar o restante."
        }
        NButton {
          text: "Adotar agora"
          outlined: true
          onClicked: {
            Settings.data.hyprland.ownershipDeclined = false;
            // The actual install still needs Scripts/bash/hyprland-adopt.sh —
            // reopen the wizard step's flow via Settings General tab's setup
            // wizard launcher (SetupHyprlandStep is idempotent and safe to
            // re-run from there).
          }
        }
      }
    }

    NTabBar {
      id: subTabBar
      Layout.fillWidth: true
      Layout.bottomMargin: Style.marginM
      distributeEvenly: false
      currentIndex: tabView.currentIndex

      NTabButton {
        text: "Geral"
        tabIndex: 0
        checked: subTabBar.currentIndex === 0
      }
      NTabButton {
        text: "Animações"
        tabIndex: 1
        checked: subTabBar.currentIndex === 1
      }
      NTabButton {
        text: "Regras de Janela"
        tabIndex: 2
        checked: subTabBar.currentIndex === 2
      }
      NTabButton {
        text: "Regras de Camada"
        tabIndex: 3
        checked: subTabBar.currentIndex === 3
      }
      NTabButton {
        text: "Autostart"
        tabIndex: 4
        checked: subTabBar.currentIndex === 4
      }
      NTabButton {
        text: "Variáveis de Ambiente"
        tabIndex: 5
        checked: subTabBar.currentIndex === 5
      }
      NTabButton {
        text: "Atalhos"
        tabIndex: 6
        checked: subTabBar.currentIndex === 6
      }
    }

    NTabView {
      id: tabView
      currentIndex: subTabBar.currentIndex

      GeneralSubTab {}
      AnimationsSubTab {}
      WindowRulesSubTab {}
      LayerRulesSubTab {}
      AutostartSubTab {}
      EnvironmentSubTab {}
      AtalhosSubTab {}
    }

    // Persistent Save/Revert bar — visible whenever the draft diverges from
    // the committed state, regardless of which sub-tab is active.
    RowLayout {
      visible: HyprlandDraftStore.isDirty
      Layout.fillWidth: true
      Layout.topMargin: Style.marginL
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: "Alterações não salvas"
        color: Color.mOnSurfaceVariant
      }
      NButton {
        text: "Reverter"
        outlined: true
        onClicked: HyprlandDraftStore.revert()
      }
      NButton {
        text: "Salvar"
        onClicked: {
          HyprlandDraftStore.save();
          ToastService.showNotice("Hyprland", "Configuração salva e recarregada.", "settings");
        }
      }
    }
  }
}
