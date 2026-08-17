import QtQuick
import qs.Commons
import qs.Widgets

Item {
  id: root

  property Component sourceComponent
  property int duration: Style.motionDurationDefaultEffects
  property int motionType: NAnim.ExpressiveEffects
  readonly property var item: _frontIsB ? loaderB.item : loaderA.item
  readonly property bool running: unloadTimer.running

  property bool _initialized: false
  property bool _frontIsB: false

  clip: true

  function applySource(component) {
    if (!_initialized) {
      loaderA.sourceComponent = component;
      _initialized = true;
      return;
    }

    if (!component) {
      loaderA.sourceComponent = null;
      loaderB.sourceComponent = null;
      _frontIsB = false;
      unloadTimer.stop();
      return;
    }

    const incoming = _frontIsB ? loaderA : loaderB;
    incoming.sourceComponent = component;
    _frontIsB = !_frontIsB;

    if (duration === 0) {
      const outgoing = _frontIsB ? loaderA : loaderB;
      outgoing.sourceComponent = null;
    } else {
      unloadTimer.restart();
    }
  }

  onSourceComponentChanged: applySource(sourceComponent)
  Component.onCompleted: {
    if (!_initialized)
      applySource(sourceComponent);
  }

  Loader {
    id: loaderA

    anchors.fill: parent
    opacity: root._frontIsB ? 0 : 1

    Behavior on opacity {
      NAnim {
        motionType: root.motionType
        duration: root.duration
      }
    }
  }

  Loader {
    id: loaderB

    anchors.fill: parent
    opacity: root._frontIsB ? 1 : 0

    Behavior on opacity {
      NAnim {
        motionType: root.motionType
        duration: root.duration
      }
    }
  }

  Timer {
    id: unloadTimer

    interval: Math.max(1, root.duration)
    onTriggered: {
      const outgoing = root._frontIsB ? loaderA : loaderB;
      outgoing.sourceComponent = null;
    }
  }
}
