import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.Commons
import qs.Services.System

Item {
    id: root

    PolkitAgent {
        id: agent
    }

    Loader {
        active: agent.isActive && PolkitService.enabled
        sourceComponent: Component {
            PolkitWindow {
                flow: agent.flow
            }
        }
    }
}
