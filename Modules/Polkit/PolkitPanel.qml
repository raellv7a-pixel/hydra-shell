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
  property var appEntry: null

  readonly property string windowPosition: PolkitService.position ?? "center"
  readonly property bool isAttached: windowPosition === "attached"
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)

  // App identity resolved from the requesting action (icon, common name, description)
  readonly property string appIconPath: {
    if (typeof ThemeIcons === 'undefined' || !root.flow)
      return "";
    const fallback = root.flow.iconName || "shield-lock";
    return root.appEntry ? ThemeIcons.iconFromName(root.appEntry.icon, fallback) : ThemeIcons.iconFromName(fallback, "shield-lock");
  }
  readonly property string appName: root.appEntry ? root.appEntry.name : prettifyActionId(root.flow ? root.flow.actionId : "")
  readonly property string appDescription: root.resolvedMessage || (root.flow ? root.flow.message : "")

  function prettifyActionId(actionId) {
    if (!actionId)
      return "Autenticação Requerida";
    var parts = actionId.split(".");
    var segment = parts.length > 2 ? parts[2] : parts[parts.length - 1];
    segment = segment.replace(/[-_]/g, " ").trim();
    return segment.length > 0 ? segment.charAt(0).toUpperCase() + segment.slice(1) : actionId;
  }

  function refreshAppEntry() {
    if (typeof ThemeIcons === 'undefined' || !root.flow) {
      root.appEntry = null;
      return;
    }
    root.appEntry = ThemeIcons.findAppEntry(root.flow.actionId) || (root.flow.iconName ? ThemeIcons.findAppEntry(root.flow.iconName) : null);
  }

  // Anchoring via native SmartPanel behavior
  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: !isAttached
  panelAnchorTop: isAttached && barPosition !== "bottom"
  panelAnchorBottom: isAttached && barPosition === "bottom"

  preferredWidth: Math.round(460 * Style.uiScaleRatio)
  preferredHeight: Math.round(330 * Style.uiScaleRatio)

  // The prompt is a modal: it layers over the panel that triggered the privileged
  // action (the launcher, for a package update) instead of closing it, and a click
  // on the desktop cannot dismiss it — that used to leave the request stranded
  // with no way left to type the password.
  modalOverlay: true

  // True once the user has either submitted a password or cancelled, so an
  // agent-driven close is not mistaken for an abandoned prompt.
  property bool authResolved: false

  function submitPassword(password) {
    if (!flow || password === "")
      return;
    authResolved = true;
    flow.submit(password);
  }

  function cancelAuth() {
    authResolved = true;
    if (flow)
      flow.cancelAuthenticationRequest();
  }

  // Escape key cancels authentication
  function onEscapePressed() {
    cancelAuth();
    close();
  }

  // Whatever route closed this panel, never leave the caller waiting on a prompt
  // that is no longer on screen.
  onClosed: {
    if (!authResolved && flow && flow.isResponseRequired)
      flow.cancelAuthenticationRequest();
    authResolved = false;
  }

  Connections {
    target: flow
    function onFailedChanged() {
      if (flow && flow.failed) {
        ToastService.showError("Autenticação Falhou", "A senha digitada está incorreta. Tente novamente.");
      }
    }
  }

  onFlowChanged: {
    root.authResolved = false;
    resolveTransientServiceName(flow ? flow.message : "");
    refreshAppEntry();
  }

  Process {
    id: cmdLineProcess
    command: ["cat", "/proc/0/cmdline"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: function () {
        var args = this.text.split(String.fromCharCode(0)).filter(function (s) {
          return s.length > 0;
        });
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
    if (!message)
      return;
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

        NAnim {
          target: shakeTranslate
          property: "x"
          from: 0
          to: -8
          motionType: NAnim.StandardEffects
        }
        NAnim {
          target: shakeTranslate
          property: "x"
          from: -8
          to: 8
          motionType: NAnim.StandardEffects
        }
        NAnim {
          target: shakeTranslate
          property: "x"
          from: 8
          to: 0
          motionType: NAnim.StandardEffects
        }
      }

      ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Style.radiusPanel // must be >= the panel's own blob corner radius (28px), not paddingCard (16px), or content stops short and the wallpaper shows through the rounded-off corner
        spacing: Style.spaceS

        // Header with app icon, common name, description and action-id pill
        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.spaceXXS

          NImageRounded {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Style.fontSizeHeadlineSmall * 2
            Layout.preferredHeight: Style.fontSizeHeadlineSmall * 2
            imagePath: root.appIconPath
            fallbackIcon: "shield-lock"
            borderWidth: 0
          }

          NText {
            Layout.fillWidth: true
            Layout.topMargin: Style.spaceXS
            text: root.appName
            horizontalAlignment: Text.AlignHCenter
            pointSize: Style.fontSizeTitleLarge
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            wrapMode: Text.Wrap
          }

          NText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.appDescription
            horizontalAlignment: Text.AlignHCenter
            pointSize: Style.fontSizeLabelMedium
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
          }

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.spaceXXS
            visible: actionIdLabel.text !== ""
            radius: Style.radiusCapsule
            color: Qt.alpha(Color.mPrimary, 0.16)
            implicitWidth: actionIdLabel.implicitWidth + Style.spaceS * 2
            implicitHeight: actionIdLabel.implicitHeight + Style.spaceXXS * 2

            NText {
              id: actionIdLabel
              anchors.centerIn: parent
              text: root.flow ? root.flow.actionId : ""
              pointSize: Style.fontSizeLabelSmall
              font.weight: Style.fontWeightSemiBold
              color: Color.mPrimary
            }
          }
        }

        // Supplementary Message (Error or prompt)
        NText {
          visible: root.flow && root.flow.supplementaryMessage !== ""
          text: root.flow ? root.flow.supplementaryMessage : ""
          pointSize: Style.fontSizeLabelMedium
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
            root.submitPassword(passwordInput.text);
            passwordInput.text = "";
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
          Layout.topMargin: Style.spaceXS
          spacing: Style.spaceS

          Item {
            Layout.fillWidth: true
          } // Spacer

          NButton {
            text: "Cancelar"
            backgroundColor: Color.mSurfaceVariant
            textColor: Color.mOnSurfaceVariant
            outlined: false
            onClicked: {
              root.cancelAuth();
              root.close();
            }
          }

          NButton {
            text: "Autenticar"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            enabled: root.flow && root.flow.isResponseRequired
            onClicked: {
              root.submitPassword(passwordInput.text);
              passwordInput.text = "";
            }
          }
        }
      }
    }
  }
}
