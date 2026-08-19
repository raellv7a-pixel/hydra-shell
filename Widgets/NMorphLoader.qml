import M3Shapes
import QtQuick
import qs.Commons

// Material 3 Expressive loading indicator: cycles through a shape sequence
// with continuous morph animation, replacing the plain rotating-arc spinner
// (NBusyIndicator) where a more expressive, branded loading moment is
// appropriate. Falls back to a single static shape when motion is disabled
// or performance mode is active, matching NBusyIndicator's own gating.
Item {
  id: root

  property bool running: true
  property color color: Color.mPrimary
  property int size: Style.baseWidgetSize

  // Shape sequence the indicator cycles through while running. Kept short
  // and legible at small sizes; callers may override for a different mood.
  property var shapeSequence: [MaterialShape.Circle, MaterialShape.Cookie9Sided, MaterialShape.Sunny, MaterialShape.Circle]
  property int holdDuration: Style.motionDurationSlowSpatial
  property int morphDuration: Style.motionDurationDefaultSpatial

  implicitWidth: size
  implicitHeight: size

  readonly property bool morphActive: root.running && Style.motionEnabled

  MaterialShape {
    id: shape

    anchors.fill: parent
    shape: root.shapeSequence[0]
    color: root.color
    animationDuration: root.morphDuration
    animationEasing.type: Easing.BezierSpline
    animationEasing.bezierCurve: Style.motionCurveExpressiveDefaultSpatial

    RotationAnimation on rotation {
      running: root.morphActive
      from: 0
      to: 360
      duration: root.morphDuration * root.shapeSequence.length + root.holdDuration * root.shapeSequence.length
      loops: Animation.Infinite
    }
  }

  // Cycles `shape.shape` through the sequence; each change auto-triggers
  // MaterialShape's built-in morph tween (see M3Shapes README).
  property int _sequenceIndex: 0

  Timer {
    id: cycleTimer
    interval: root.holdDuration + root.morphDuration
    running: root.morphActive
    repeat: true
    onTriggered: {
      root._sequenceIndex = (root._sequenceIndex + 1) % root.shapeSequence.length;
      shape.shape = root.shapeSequence[root._sequenceIndex];
    }
  }

  onMorphActiveChanged: {
    if (!morphActive) {
      // Freeze on a legible resting shape instead of stopping mid-morph.
      root._sequenceIndex = 0;
      shape.shape = root.shapeSequence[0];
    }
  }
}
