import QtQuick
import qs.Commons

AnchorAnimation {
  enum Type {
    Standard,
    Emphasized,
    ExpressiveFast,
    ExpressiveDefault,
    ExpressiveSlow
  }

  property int motionType: NAnchorAnimation.ExpressiveDefault

  duration: {
    switch (motionType) {
    case NAnchorAnimation.ExpressiveFast:
      return Style.motionDurationFastSpatial;
    case NAnchorAnimation.ExpressiveSlow:
      return Style.motionDurationSlowSpatial;
    default:
      return Style.motionDurationDefaultSpatial;
    }
  }

  easing.type: Easing.BezierSpline
  easing.bezierCurve: {
    switch (motionType) {
    case NAnchorAnimation.Standard:
      return Style.motionCurveStandardSpatial;
    case NAnchorAnimation.Emphasized:
      return Style.motionCurveEmphasizedSpatial;
    case NAnchorAnimation.ExpressiveFast:
      return Style.motionCurveExpressiveFastSpatial;
    case NAnchorAnimation.ExpressiveSlow:
      return Style.motionCurveExpressiveSlowSpatial;
    default:
      return Style.motionCurveExpressiveDefaultSpatial;
    }
  }
}
