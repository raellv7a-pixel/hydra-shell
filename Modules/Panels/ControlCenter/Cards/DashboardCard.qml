import QtQuick
import qs.Commons
import qs.Widgets

NBox {
  id: dashboardCard

  // Every dashboard card needs the popup's derived state (per-component
  // style overrides, performance mode, panelUnit scale, music/spectrum
  // state). Passed explicitly from Panel.qml. NOT named "root": any
  // DashboardCard-derived type composes this property in too, and a
  // property literally named "root" would shadow the caller's own
  // `id: root` for every card that still lives inline in Panel.qml.
  required property var panelRoot

  property string styleKey: panelRoot.inheritedStyleKey(parent)
  property bool styleRoot: false
  property bool detailTransition: false
  property string detailTransitionDirection: "right"
  property real detailOffset: 0
  readonly property bool borderEffectVisible: panelRoot.componentBorderVisible(styleKey, styleRoot)

  color: styleKey !== "" ? panelRoot.componentBackground(styleKey) : panelRoot.m3SurfaceContainer
  radius: styleRoot ? Style.radiusL : Style.radiusM
  border.color: borderEffectVisible ? Qt.alpha(panelRoot.componentAccent(styleKey), 0.42) : (styleRoot ? "transparent" : Qt.alpha(Color.mOutline, 0.10))
  border.width: borderEffectVisible ? Math.max(1, Style.borderS) : Style.borderS

  transform: Translate {
    x: dashboardCard.detailOffset
  }

  onVisibleChanged: {
    if (visible && detailTransition && !panelRoot.dashboardPerformanceMode) {
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
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }

    ScaleAnimator {
      target: dashboardCard
      from: 0.985
      to: 1
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: dashboardCard
      property: "detailOffset"
      from: dashboardCard.detailTransitionDirection === "left" ? -Math.round(22 * panelRoot.panelUnit) : Math.round(22 * panelRoot.panelUnit)
      to: 0
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  ComponentBorderCanvas {
    panelRoot: dashboardCard.panelRoot
    anchors.fill: parent
    styleKey: parent.styleKey
    styleRoot: parent.styleRoot
    z: 20
  }
}
