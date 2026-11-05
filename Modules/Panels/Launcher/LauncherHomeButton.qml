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
  property bool pressFeedback: false
  property bool raisedSurface: false
  scale: pressFeedback && down && Style.animationFast > 0 ? 0.98 : 1
  Behavior on scale {
    enabled: root.pressFeedback && Style.animationFast > 0
    ScaleAnimator { duration: Style.animationFaster; easing.type: Easing.OutCubic }
  }
  signal contextRequested
  focusPolicy: Qt.StrongFocus
  hoverEnabled: !Settings.data.appLauncher.ignoreMouseInput
  padding: launcher.metrics.padding
  topPadding: launcher.metrics.gapS
  bottomPadding: launcher.metrics.gapS
  Accessible.name: text
  NDropShadow {
    z: -2
    anchors.fill: root.background
    source: root.background
    visible: root.raisedSurface && root.visible
    autoPaddingEnabled: true
    shadowColor: HydraColor.mShadow
    shadowOpacity: Style.shadowOpacity * Style.opacityLight
    shadowHorizontalOffset: 0
    shadowVerticalOffset: Style.marginXXS
  }
  background: NStateLayer {
    radius: root.cornerRadius
    baseColor: Style.materialFill(root.surface)
    stateColor: root.foreground
    focusColor: root.foreground
    hovering: root.hovered
    pressed: root.down
    focusVisible: root.visualFocus
  }
  contentItem: NText {
    text: root.text
    color: root.foreground
    font.weight: Style.fontWeightSemiBold
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
