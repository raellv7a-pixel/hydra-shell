import QtQuick
import QtQuick.Controls.Basic
import qs.Commons
import qs.Widgets

Button {
  id: root
  required property var launcher
  property color surface: HydraColor.mSurfaceContainerLow
  property color foreground: HydraColor.mOnSurface
  property real cornerRadius: Style.radiusL
  signal contextRequested
  focusPolicy: Qt.StrongFocus
  hoverEnabled: !Settings.data.appLauncher.ignoreMouseInput
  padding: launcher.metrics.padding
  Accessible.name: text
  background: NStateLayer {
    radius: root.cornerRadius
    baseColor: root.surface
    stateColor: root.foreground
    focusColor: root.foreground
    hovering: root.hovered
    pressed: root.down
    focusVisible: root.visualFocus
  }
  contentItem: NText {
    text: root.text
    color: root.foreground
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  TapHandler {
    acceptedButtons: Qt.RightButton
    enabled: !Settings.data.appLauncher.ignoreMouseInput
    onTapped: root.contextRequested()
  }
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
      root.contextRequested();
      event.accepted = true;
    } else
      root.launcher.handleHomeItemKey(event, root);
  }
  onActiveFocusChanged: if (activeFocus)
                          launcher.ensureHomeItemVisible(root)
}
