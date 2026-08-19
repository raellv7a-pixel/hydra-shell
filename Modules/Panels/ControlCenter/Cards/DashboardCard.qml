import QtQuick
import qs.Commons
import qs.Widgets

NBox {
  id: dashboardCard

  // Every dashboard card needs the popup's derived state (per-component
  // style overrides, performance mode, panelUnit scale, music/spectrum
  // state). Passed explicitly from Panel.qml. Named panelRoot (not "root")
  // because a property named the same as the caller's `id: root` would
  // shadow it: `root: root` on this object would try to bind our own
  // "root" to itself instead of reaching the caller's id. The `root` alias
  // below is what the rest of this file (and every DashboardCard-derived
  // card) actually uses, unchanged from the original inline-component code.
  required property var panelRoot
  readonly property var root: panelRoot

  property string styleKey: root.inheritedStyleKey(parent)
  property bool styleRoot: false
  property bool detailTransition: false
  property string detailTransitionDirection: "right"
  property real detailOffset: 0
  readonly property bool borderEffectVisible: root.componentBorderVisible(styleKey, styleRoot)

  color: styleKey !== "" ? root.componentBackground(styleKey) : root.m3SurfaceContainer
  radius: styleRoot ? Style.radiusL : Style.radiusM
  border.color: borderEffectVisible ? Qt.alpha(root.componentAccent(styleKey), 0.42) : (styleRoot ? "transparent" : Qt.alpha(Color.mOutline, 0.10))
  border.width: borderEffectVisible ? Math.max(1, Style.borderS) : Style.borderS

  transform: Translate {
    x: dashboardCard.detailOffset
  }

  onVisibleChanged: {
    if (visible && detailTransition && !root.dashboardPerformanceMode) {
      detailEnterAnimation.restart();
    } else if (visible && detailTransition) {
      opacity = 1;
      scale = 1;
      detailOffset = 0;
    }
  }

  ParallelAnimation {
    id: detailEnterAnimation

    OpacityAnimator {
      target: dashboardCard
      from: 0
      to: 1
      duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }

    ScaleAnimator {
      target: dashboardCard
      from: 0.985
      to: 1
      duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: dashboardCard
      property: "detailOffset"
      from: dashboardCard.detailTransitionDirection === "left" ? -Math.round(22 * root.panelUnit) : Math.round(22 * root.panelUnit)
      to: 0
      duration: root.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  ComponentBorderCanvas {
    panelRoot: dashboardCard.root
    anchors.fill: parent
    styleKey: parent.styleKey
    styleRoot: parent.styleRoot
    z: 20
  }
}
