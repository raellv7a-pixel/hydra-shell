import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.System
import qs.Services.UI

PanelWindow {
    id: polkitWindow
   
    property AuthFlow flow
    property var pluginApi
    property string resolvedMessage: ""
    property var transientMatch: null

    readonly property string windowPosition: PolkitService.position ?? "center"
    readonly property bool isAttached: windowPosition === "attached"

    Connections {
        target: flow
        function onFailedChanged() {
            if (flow && flow.failed) {
                ToastService.showError(
                    "Autenticação Falhou",
                    "A senha digitada está incorreta. Tente novamente."
                )
            }
        }
    }

    // Resolve transient service names when flow changes
    onFlowChanged: {
        resolveTransientServiceName(flow ? flow.message : "");
    }
    
    // Resolve transient service names (run-PID-random.service) to actual command
    Process {
        id: cmdLineProcess
        command: ["cat", "/proc/0/cmdline"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: function() {
                var args = this.text.split(String.fromCharCode(0)).filter(function(s) { return s.length > 0; });
                Logger.i("polkit-agent: Process output length=" + this.text.length + ", args=" + args.length);
                if (args.length > 0 && polkitWindow.transientMatch) {
                    var resolvedCmd = args.join(' ');
                    var isCommand = args.length > 1 || args[0].includes('/');
                    polkitWindow.resolvedMessage = polkitWindow.resolvedMessage.replace(polkitWindow.transientMatch[0], resolvedCmd);
                    if (isCommand) {
                        polkitWindow.resolvedMessage = polkitWindow.resolvedMessage.replace(/transient unit/i, 'run command');
                    }
                    Logger.i("polkit-agent: Resolved message: " + polkitWindow.resolvedMessage);
                }
            }
        }
    }

    function resolveTransientServiceName(message) {
        if (!message) return;
        var match = message.match(/run-p?(\d+)-[^.]+\.service/);
        if (!match) {
            Logger.i("polkit-agent: No transient service pattern in message: " + message);
            polkitWindow.resolvedMessage = message;
            polkitWindow.transientMatch = null;
            return;
        }
        var pid = match[1];
        Logger.i("polkit-agent: Found transient service pattern, PID=" + pid + ", message=" + message);
        polkitWindow.resolvedMessage = message;
        polkitWindow.transientMatch = match;
        cmdLineProcess.command = ["cat", "/proc/" + pid + "/cmdline"];
        cmdLineProcess.running = true;
    }
    
    // Layer above everything else (critical system prompt)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "polkit-agent"

    anchors.top: true
    anchors.bottom: !isAttached
    anchors.left: !isAttached
    anchors.right: !isAttached

    margins.top: isAttached ? (Style.getBarHeightForScreen(screen?.name) + Style.marginM) : 0

    readonly property real shadowPadding: Style.shadowBlurMax + Style.marginL

    color: "transparent"

    Item {
        id: contentContainer
        anchors.centerIn: isAttached ? undefined : parent
        anchors.top: isAttached ? parent.top : undefined
        anchors.horizontalCenter: isAttached ? parent.horizontalCenter : undefined
        width: Math.max(460 * Style.uiScaleRatio, contentLayout.implicitWidth + (Style.marginL * 4)) + shadowPadding * 2
        height: Math.max(260 * Style.uiScaleRatio, contentLayout.implicitHeight + (Style.marginL * 4)) + shadowPadding * 2
        focus: true

        Keys.onPressed: function(event) {
            if (!flow) return;
            
            if (Keybinds.checkKey(event, "escape", Settings)) {
                flow.cancelAuthenticationRequest();
                event.accepted = true;
            } else if (Keybinds.checkKey(event, "enter", Settings)) {
                if (passwordInput.text !== "") {
                     flow.submit(passwordInput.text);
                     passwordInput.text = "";
                }
                event.accepted = true;
            }
        }

        transform: Translate {
            id: shakeTranslate
            x: 0
        }

        // Error animation
        SequentialAnimation {
            id: errorShake
            running: flow && flow.failed && PolkitService.errorShake
            loops: 1
            
            NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: 0; duration: 50; easing.type: Easing.InOutQuad }
        }

        // Shadow effect
        NDropShadow {
            anchors.fill: customBackground
            source: customBackground
            autoPaddingEnabled: true
            z: -1
        }

        Rectangle {
            id: customBackground
            anchors.fill: parent
            anchors.margins: shadowPadding
            radius: Style.radiusL
            color: Qt.alpha(Color.mSurface, 0.96)
            border.color: (flow && (flow.failed || flow.supplementaryIsError)) ? Color.mError : Color.mOutline
            border.width: Style.borderS
            
            Behavior on border.color {
                ColorAnimation { duration: Style.animationFast }
            }
        }

        ColumnLayout {
            id: contentLayout
            anchors.centerIn: customBackground
            width: customBackground.width - (Style.marginL * 2)
            spacing: Style.marginM

            // Header with Icon
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NImageRounded {
                    Layout.preferredWidth: Style.fontSizeXXL * 2
                    Layout.preferredHeight: Style.fontSizeXXL * 2
                    imagePath: Settings.preprocessPath(Settings.data.general.avatarImage) || ((flow && flow.iconName) ? Quickshell.iconPath(flow.iconName) : "")
                    fallbackIcon: "shield-lock"
                    borderWidth: 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    NText {
                        text: polkitWindow.resolvedMessage || (flow ? flow.message : "Autenticação Administrativa Requerida")
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    NText {
                        text: flow ? flow.actionId : ""
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
                visible: flow && flow.supplementaryMessage !== ""
                text: flow ? flow.supplementaryMessage : ""
                pointSize: Style.fontSizeS
                color: (flow && flow.supplementaryIsError) ? Color.mError : Color.mOnSurfaceVariant
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            // Input Field
            NTextInput {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: "Digite a sua senha de administrador"
                label: "Senha"
                inputItem.echoMode: (flow && !flow.responseVisible) ? TextInput.Password : TextInput.Normal
                visible: flow && flow.isResponseRequired
                
                onAccepted: {
                    if (flow) {
                        flow.submit(passwordInput.text)
                        passwordInput.text = ""
                    }
                }
            }

            // Actions
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
                        if (flow) flow.cancelAuthenticationRequest()
                    }
                }

                NButton {
                    text: "Autenticar"
                    backgroundColor: Color.mPrimary
                    textColor: Color.mOnPrimary
                    enabled: flow && flow.isResponseRequired
                    onClicked: {
                        if (flow) {
                            flow.submit(passwordInput.text)
                            passwordInput.text = ""
                        }
                    }
                }
            }
        }
    }
    
    // Focus handling
    Component.onCompleted: {
        if (PolkitService.autoFocus) {
            passwordInput.inputItem.forceActiveFocus()
        }
    }
}
