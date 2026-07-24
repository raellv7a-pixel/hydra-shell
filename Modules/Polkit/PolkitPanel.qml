import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  property AuthFlow flow: null
  property string resolvedMessage: ""
  property var transientMatch: null

  readonly property string windowPosition: PolkitService.position ?? "center"
  readonly property bool isAttached: windowPosition === "attached"
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)

  // Anchoring via native SmartPanel behavior
  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: !isAttached
  panelAnchorTop: isAttached && barPosition !== "bottom"
  panelAnchorBottom: isAttached && barPosition === "bottom"

  preferredWidth: Math.round(460 * Style.uiScaleRatio)
  preferredHeight: Math.round(270 * Style.uiScaleRatio)

  // Escape key cancels authentication
  function onEscapePressed() {
    if (flow) flow.cancelAuthenticationRequest();
    close();
  }

  Connections {
    target: flow
    function onFailedChanged() {
      if (flow && flow.failed) {
        ToastService.showError(
          "Autenticação Falhou",
          "A senha digitada está incorreta. Tente novamente."
        );
      }
    }
  }

  onFlowChanged: {
    resolveTransientServiceName(flow ? flow.message : "");
  }

  Process {
    id: cmdLineProcess
    command: ["cat", "/proc/0/cmdline"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: function() {
        var args = this.text.split(String.fromCharCode(0)).filter(function(s) { return s.length > 0; });
        if (args.length > 0 && root.transientMatch) {
          var resolvedCmd = args.join(' ');
          var isCommand = args.length > 1 || args[0].includes('/');
          root.resolvedMessage = root.resolvedMessage.replace(root.transientMatch[0], resolvedCmd);
          if (isCommand) {
            root.resolvedMessage = root.resolvedMessage.replace(/transient unit/i, 'executar comando');
          }
        }
      }
    }
  }

  function resolveTransientServiceName(message) {
    if (!message) return;
    var match = message.match(/run-p?(\d+)-[^.]+\.service/);
    if (!match) {
      root.resolvedMessage = message;
      root.transientMatch = null;
      return;
    }
    var pid = match[1];
    root.resolvedMessage = message;
    root.transientMatch = match;
    cmdLineProcess.command = ["cat", "/proc/" + pid + "/cmdline"];
    cmdLineProcess.running = true;
  }

  panelContent: Component {
    Item {
      id: panelItem
      anchors.fill: parent
      focus: true

      transform: Translate {
        id: shakeTranslate
        x: 0
      }

      // Error shake animation
      SequentialAnimation {
        id: errorShake
        running: root.flow && root.flow.failed && PolkitService.errorShake
        loops: 1

        NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -10; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: -10; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: 0; duration: 50; easing.type: Easing.InOutQuad }
      }

      ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // Header with Icon
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NImageRounded {
            Layout.preferredWidth: Style.fontSizeXXL * 1.8
            Layout.preferredHeight: Style.fontSizeXXL * 1.8
            imagePath: Settings.preprocessPath(Settings.data.general.avatarImage) || ((root.flow && root.flow.iconName) ? Quickshell.iconPath(root.flow.iconName) : "")
            fallbackIcon: "shield-lock"
            borderWidth: 0
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
              text: root.resolvedMessage || (root.flow ? root.flow.message : "Autenticação Requerida")
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }

            NText {
              text: root.flow ? root.flow.actionId : ""
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              wrapMode: Text.Wrap
              Layout.fillWidth: true
              visible: text !== ""
            }
          }
        }

        // Supplementary Message (Error or prompt)
        NText {
          visible: root.flow && root.flow.supplementaryMessage !== ""
          text: root.flow ? root.flow.supplementaryMessage : ""
          pointSize: Style.fontSizeS
          color: (root.flow && root.flow.supplementaryIsError) ? Color.mError : Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }

        // Password Input Field
        NTextInput {
          id: passwordInput
          Layout.fillWidth: true
          placeholderText: "Digite a sua senha de administrador"
          label: "Senha"
          inputItem.echoMode: (root.flow && !root.flow.responseVisible) ? TextInput.Password : TextInput.Normal
          visible: root.flow && root.flow.isResponseRequired

          onAccepted: {
            if (root.flow && passwordInput.text !== "") {
              root.flow.submit(passwordInput.text);
              passwordInput.text = "";
            }
          }

          Component.onCompleted: {
            if (PolkitService.autoFocus) {
              passwordInput.inputItem.forceActiveFocus();
            }
          }
        }

        // Action Buttons
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.marginS
          spacing: Style.marginM

          Item { Layout.fillWidth: true } // Spacer

          NButton {
            text: "Cancelar"
            backgroundColor: Color.mSurfaceVariant
            textColor: Color.mOnSurfaceVariant
            outlined: false
            onClicked: {
              if (root.flow) root.flow.cancelAuthenticationRequest();
              root.close();
            }
          }

          NButton {
            text: "Autenticar"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            enabled: root.flow && root.flow.isResponseRequired
            onClicked: {
              if (root.flow && passwordInput.text !== "") {
                root.flow.submit(passwordInput.text);
                passwordInput.text = "";
              }
            }
          }
        }
      }
    }
  }
}
