import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.Commons
import qs.Services.System

Item {
    id: root

    PolkitAgent {
        id: agent
        
        onIsActiveChanged: {
            if (isActive && (PolkitService.settings.enabled ?? true)) {
                openWindow()
            } else {
                closeWindow()
            }
        }
    }

    property var window: null

    function openWindow() {
        if (agent.flow === null) {
            Logger.w("PolkitNative: Cannot open window, agent.flow is null");
            return;
        }
        if (window === null) {
            var component = Qt.createComponent("PolkitWindow.qml");
            if (component.status === Component.Ready) {
                window = component.createObject(root, {
                    flow: agent.flow
                });
                if (window !== null) {
                    window.visible = true;
                }
            }
            component.destroy();
        } else {
            window.flow = agent.flow;
            window.visible = true;
        }
    }

    function closeWindow() {
        if (window !== null) {
            window.destroy();
            window = null;
        }
    }
}
