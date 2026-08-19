import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services.Power
import qs.Widgets

// Unified shadow system
Item {
  id: root

  required property var source

  property bool autoPaddingEnabled: false
  property int elevation: 0
  property bool active: true
  readonly property bool usesElevation: elevation > 0
  property real shadowHorizontalOffset: usesElevation ? 0 : Settings.data.general.shadowOffsetX
  property real shadowVerticalOffset: usesElevation ? Style.elevationVerticalOffset(elevation) : Settings.data.general.shadowOffsetY
  property real shadowOpacity: usesElevation ? Style.elevationOpacity(elevation) : Style.shadowOpacity
  property color shadowColor: Color.mShadow
  property real shadowBlur: usesElevation ? Style.elevationBlur(elevation) : Style.shadowBlur
  property int shadowBlurMax: Style.shadowBlurMax

  Behavior on shadowHorizontalOffset {
    NAnim {
      motionType: NAnim.StandardEffects
    }
  }

  Behavior on shadowVerticalOffset {
    NAnim {
      motionType: NAnim.StandardEffects
    }
  }

  Behavior on shadowOpacity {
    NAnim {
      motionType: NAnim.StandardEffects
    }
  }

  Behavior on shadowBlur {
    NAnim {
      motionType: NAnim.StandardEffects
    }
  }
  layer.enabled: root.active && Settings.data.general.enableShadows && !PowerProfileService.noctaliaPerformanceMode
  layer.effect: MultiEffect {
    source: root.source
    shadowEnabled: true
    blurMax: root.shadowBlurMax
    shadowBlur: root.shadowBlur
    shadowOpacity: root.shadowOpacity
    shadowColor: root.shadowColor
    shadowHorizontalOffset: root.shadowHorizontalOffset
    shadowVerticalOffset: root.shadowVerticalOffset
    autoPaddingEnabled: root.autoPaddingEnabled
  }
}
