import QtQuick
import qs.Widgets

NDropShadow {
  property int level: 1

  elevation: Math.max(0, Math.min(5, Math.round(level)))
  active: level > 0
  autoPaddingEnabled: true
}
