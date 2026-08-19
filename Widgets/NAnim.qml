import QtQuick
import qs.Commons

NumberAnimation {
  enum Type {
    StandardSpatial,
    EmphasizedSpatial,
    ExpressiveFastSpatial,
    ExpressiveDefaultSpatial,
    ExpressiveSlowSpatial,
    StandardEffects,
    EmphasizedEffects,
    ExpressiveEffects
  }

  property int motionType: NAnim.ExpressiveDefaultSpatial

  duration: {
    switch (motionType) {
    case NAnim.ExpressiveFastSpatial:
      return Style.motionDurationFastSpatial;
    case NAnim.ExpressiveSlowSpatial:
      return Style.motionDurationSlowSpatial;
    case NAnim.StandardEffects:
    case NAnim.EmphasizedEffects:
    case NAnim.ExpressiveEffects:
      return Style.motionDurationDefaultEffects;
    default:
      return Style.motionDurationDefaultSpatial;
    }
  }

  easing.type: Easing.BezierSpline
  easing.bezierCurve: {
    switch (motionType) {
    case NAnim.StandardSpatial:
      return Style.motionCurveStandardSpatial;
    case NAnim.EmphasizedSpatial:
      return Style.motionCurveEmphasizedSpatial;
    case NAnim.ExpressiveFastSpatial:
      return Style.motionCurveExpressiveFastSpatial;
    case NAnim.ExpressiveSlowSpatial:
      return Style.motionCurveExpressiveSlowSpatial;
    case NAnim.StandardEffects:
      return Style.motionCurveStandardEffects;
    case NAnim.EmphasizedEffects:
      return Style.motionCurveEmphasizedEffects;
    case NAnim.ExpressiveEffects:
      return Style.motionCurveExpressiveEffects;
    default:
      return Style.motionCurveExpressiveDefaultSpatial;
    }
  }
}
