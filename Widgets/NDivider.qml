import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

Rectangle {
  id: root

  property bool vertical: false
  property real thickness: Style.borderS
  property color dividerColor: Color.mOutline

  width: root.vertical ? root.thickness : parent.width
  height: root.vertical ? parent.height : root.thickness
  gradient: Gradient {
    orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
    GradientStop {
      position: 0.0
      color: "transparent"
    }
    GradientStop {
      position: 0.1
      color: root.dividerColor
    }
    GradientStop {
      position: 0.9
      color: root.dividerColor
    }
    GradientStop {
      position: 1.0
      color: "transparent"
    }
  }
}
