import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// First-run Hyprland config adoption (PLANO_INTEGRACAO_HYPRMOD.md §4.2).
// hydra-shell ships its own opinionated Hyprland Lua config
// (Assets/Hyprland/) with default binds already wired to every IPC target in
// Services/Control/IPCService.qml. This step installs it — with a backup of
// whatever was there — so the shell is a complete, working desktop out of
// the box instead of leaving the compositor for the user to hand-configure.
ColumnLayout {
  id: root

  spacing: Style.marginM

  readonly property bool isHyprland: CompositorService.isHyprland
  readonly property bool alreadyAdopted: Settings.data.hyprland.ownershipAdopted
  readonly property bool alreadyDeclined: Settings.data.hyprland.ownershipDeclined

  property bool running: false
  property string resultState: "" // "", "success", "error"
  property string resultDetail: ""

  Process {
    id: adoptProcess
    workingDirectory: Quickshell.shellDir
    command: ["bash", Quickshell.shellDir + "/Scripts/bash/hyprland-adopt.sh", Quickshell.shellDir + "/Assets/Hyprland"]
    running: false

    property string collectedOutput: ""
    property string collectedError: ""

    stdout: StdioCollector {
      onStreamFinished: adoptProcess.collectedOutput = this.text
    }
    stderr: StdioCollector {
      onStreamFinished: adoptProcess.collectedError = this.text
    }

    onExited: function (exitCode) {
      root.running = false;
      if (exitCode === 0 && adoptProcess.collectedOutput.includes("RESULT:OK")) {
        Settings.data.hyprland.ownershipAdopted = true;
        Settings.data.hyprland.ownershipDeclined = false;
        root.resultState = "success";
        const backupLine = adoptProcess.collectedOutput.split("\n").find(l => l.startsWith("BACKUP_DIR:"));
        root.resultDetail = backupLine ? backupLine.substring("BACKUP_DIR:".length) : "";
        Logger.i("SetupHyprlandStep", "Adoption succeeded", root.resultDetail ? ("backup: " + root.resultDetail) : "(no backup needed)");
      } else {
        root.resultState = "error";
        root.resultDetail = adoptProcess.collectedError || ("exit code " + exitCode);
        Logger.e("SetupHyprlandStep", "Adoption failed:", root.resultDetail);
        ToastService.showError(I18n.tr("setup.hyprland-adopt-failed-title") || "Falha ao instalar a configuração do Hyprland", root.resultDetail);
      }
    }
  }

  function adopt() {
    if (root.running)
      return;
    root.running = true;
    root.resultState = "";
    adoptProcess.running = true;
  }

  function decline() {
    Settings.data.hyprland.ownershipDeclined = true;
    Settings.data.hyprland.ownershipAdopted = false;
  }

  // Header
  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginL
    spacing: Style.marginM

    Rectangle {
      width: 40
      height: 40
      radius: Style.radiusL
      color: Color.mSurfaceVariant
      opacity: 0.6

      NIcon {
        icon: "settings"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
        anchors.centerIn: parent
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: "Configuração do Hyprland"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mPrimary
      }

      NText {
        text: "Atalhos, animações e regras de janela, prontos para usar"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }
    }
  }

  // Not on Hyprland — nothing to do here.
  ColumnLayout {
    visible: !root.isHyprland
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "Este passo é específico do Hyprland. Como não detectamos o Hyprland como seu compositor atual, não há nada para configurar aqui — continue para a próxima etapa."
      color: Color.mOnSurfaceVariant
    }
  }

  // Already adopted — idempotent re-entry (e.g. wizard re-run from Settings).
  ColumnLayout {
    visible: root.isHyprland && root.alreadyAdopted && root.resultState === ""
    Layout.fillWidth: true
    spacing: Style.marginS

    RowLayout {
      spacing: Style.marginS
      NIcon {
        icon: "check"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }
      NText {
        text: "A hydra-shell já gerencia sua configuração do Hyprland."
        color: Color.mOnSurfaceVariant
      }
    }
  }

  // Choice — fresh adoption not yet decided.
  ColumnLayout {
    visible: root.isHyprland && !root.alreadyAdopted && root.resultState === ""
    Layout.fillWidth: true
    spacing: Style.marginL

    NText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "A hydra-shell pode assumir sua configuração do Hyprland (~/.config/hypr/hyprland.lua): atalhos para o launcher, central de controle, capturas de tela e mais já vêm prontos, ligados diretamente à shell. Sua configuração atual, se houver, é salva com backup antes de qualquer alteração — nada é perdido."
      color: Color.mOnSurfaceVariant
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        Layout.fillWidth: true
        text: root.running ? "Instalando..." : "Deixar a hydra-shell assumir (recomendado)"
        enabled: !root.running
        onClicked: root.adopt()
      }

      NButton {
        Layout.fillWidth: true
        outlined: true
        enabled: !root.running
        text: "Manter minha configuração"
        onClicked: root.decline()
      }
    }

    NText {
      visible: root.alreadyDeclined
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      text: "Você optou por manter sua configuração atual. A aba Hyprland nas Configurações ficará em modo limitado (só adiciona atalhos e regras novas, sem gerenciar o que já existe). Você pode mudar de ideia a qualquer momento pelas Configurações."
    }
  }

  // Result feedback for this session.
  ColumnLayout {
    visible: root.resultState !== ""
    Layout.fillWidth: true
    spacing: Style.marginS

    RowLayout {
      spacing: Style.marginS
      NIcon {
        icon: root.resultState === "success" ? "check" : "alert-triangle"
        pointSize: Style.fontSizeL
        color: root.resultState === "success" ? Color.mPrimary : Color.mError
      }
      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.resultState === "success" ? ("Configuração instalada." + (root.resultDetail ? (" Sua configuração anterior foi salva em " + root.resultDetail) : "")) : ("Não foi possível instalar: " + root.resultDetail)
        color: Color.mOnSurfaceVariant
      }
    }
  }
}
