import QtQuick
import qs.Commons

ColorAnimation {
  enum Type {
    Standard,
    Emphasized,
    Expressive
  }

  property int motionType: NColorAnimation.Standard

  duration: Style.motionDurationDefaultEffects
  easing.type: Easing.BezierSpline
  easing.bezierCurve: {
    switch (motionType) {
    case NColorAnimation.Emphasized:
      return Style.motionCurveEmphasizedEffects;
    case NColorAnimation.Expressive:
      return Style.motionCurveExpressiveEffects;
    default:
      return Style.motionCurveStandardEffects;
    }
  }
}
