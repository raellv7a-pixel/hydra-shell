import QtQuick
import qs.Commons
import qs.Services.Power

ListView {
  id: root
  required property var launcher
  required property var homeView
  readonly property int visibleCards: Math.max(1, Math.min(count, width >= 820 * Style.uiScaleRatio ? 4 : (width >= 590 * Style.uiScaleRatio ? 3 : 2)))
  readonly property bool overflowing: count > visibleCards
  readonly property real cardWidth: Math.max(1, Math.floor((width - spacing * (visibleCards - 1 + (overflowing ? 1 : 0))) / (visibleCards + (overflowing ? 0.12 : 0))));
  readonly property bool presented: visible && launcher.isOpen && launcher.effectiveState === "home"
  property bool interacted: false
  readonly property bool motionAllowed: !Settings.data.general.animationDisabled && !PowerProfileService.hydraPerformanceMode
  onMotionAllowedChanged: if (!motionAllowed) stopHint()
  orientation: ListView.Horizontal
  model: launcher.browseModel.folders
  spacing: launcher.metrics.gapL
  boundsBehavior: Flickable.StopAtBounds
  snapMode: ListView.SnapToItem
  interactive: overflowing && !Settings.data.appLauncher.ignoreMouseInput
  clip: true
  implicitHeight: currentItem ? currentItem.implicitHeight : 0
  // Initial category population can change ListView.originX before layout settles.
  onModelChanged: if (!interacted) Qt.callLater(root.positionViewAtBeginning)
  onWidthChanged: if (!interacted) Qt.callLater(root.positionViewAtBeginning)
  onDraggingChanged: if (dragging) markInteracted()
  onPresentedChanged: if (!presented) { stopHint(); settle.stop(); snap.stop(); }
  onOverflowingChanged: if (!overflowing) { stopHint(); settle.stop(); snap.stop(); }

  function stopHint() {
    if (!hint.running) return;
    hint.stop();
    if (!interacted) contentX = originX;
  }
  function markInteracted() {
    interacted = true;
    ShellState.launcherFolderHintShown = true;
    hint.stop();
  }

  function focusIndex(index) {
    if (index < 0 || index >= count) return;
    markInteracted();
    currentIndex = index;
    positionViewAtIndex(index, ListView.Contain);
    Qt.callLater(() => { if (root.currentItem) root.currentItem.forceActiveFocus(); });
  }

  function containIndex(index) { markInteracted(); positionViewAtIndex(index, ListView.Contain); }
  function handleWheel(event) {
    if (!interactive || !overflowing) return false;
    const horizontal = Math.abs(event.pixelDelta.x || event.angleDelta.x) > Math.abs(event.pixelDelta.y || event.angleDelta.y);
    const pixels = horizontal ? event.pixelDelta.x : event.pixelDelta.y;
    const angle = horizontal ? event.angleDelta.x : event.angleDelta.y;
    const delta = pixels || angle / 120 * (cardWidth + spacing);
    const next = Math.max(originX, Math.min(originX + Math.max(0, contentWidth - width), contentX - delta));
    if (Math.abs(next - contentX) < 0.5) return false;
    markInteracted();
    snap.stop();
    contentX = next;
    if (horizontal) settle.restart();
    return true;
  }

  delegate: LauncherFolderCard {
    required property var modelData
    required property int index
    launcher: root.launcher
    homeView: root.homeView
    folder: modelData
    folderIndex: index
    width: root.cardWidth
    height: root.height
    onPressedChanged: if (pressed) root.markInteracted()
  }

  Timer {
    interval: 600
    running: root.presented && root.overflowing && root.atXBeginning && !root.moving && !root.interacted && !ShellState.launcherFolderHintShown && root.motionAllowed
    onTriggered: {
      if (!root.atXBeginning || root.moving) return;
      ShellState.launcherFolderHintShown = true;
      hint.restart();
    }
  }
  SequentialAnimation {
    id: hint
    NumberAnimation { target: root; property: "contentX"; to: root.originX + 14 * Style.uiScaleRatio; duration: Style.animationNormal; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "contentX"; to: root.originX; duration: Style.animationSlow; easing.type: Easing.InOutCubic }
  }
  Timer {
    id: settle
    interval: 160
    onTriggered: {
      const stride = root.cardWidth + root.spacing;
      const offset = Math.round((root.contentX - root.originX) / stride) * stride;
      const target = root.originX + Math.max(0, Math.min(root.contentWidth - root.width, offset));
      if (!root.motionAllowed) root.contentX = target;
      else { snap.from = root.contentX; snap.to = target; snap.restart(); }
    }
  }
  NumberAnimation { id: snap; target: root; property: "contentX"; duration: Style.animationFast; easing.type: Easing.OutCubic }
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    enabled: root.interactive
    blocking: false
    onWheel: event => {
      blocking = root.handleWheel(event);
      event.accepted = blocking;
    }
  }
}
