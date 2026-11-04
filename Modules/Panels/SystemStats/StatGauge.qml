import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Widgets

NBox {
  id: root
  property string label: ""
  property string valueText: ""
  property string detail: ""
  property real ratio: -1
  property color accent: HydraColor.mPrimary
  implicitHeight: 116 * Style.uiScaleRatio
  border.width: 0
  color: HydraColor.mSurfaceContainerHigh
  Accessible.role: Accessible.StaticText
  Accessible.name: label + ": " + valueText + ". " + detail

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginXS
    Item {
      id: ring
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: 60 * Style.uiScaleRatio
      Layout.preferredHeight: Layout.preferredWidth
      readonly property real inset: Style.borderL
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: "transparent"
          strokeColor: HydraColor.mSurfaceContainerHighest
          strokeWidth: Style.borderL
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.width / 2 - ring.inset
            radiusY: radiusX
            startAngle: -90
            sweepAngle: 360
          }
        }
        ShapePath {
          fillColor: "transparent"
          strokeColor: root.ratio >= 0 ? root.accent : "transparent"
          strokeWidth: Style.borderL
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.width / 2 - ring.inset
            radiusY: radiusX
            startAngle: -90
            sweepAngle: 360 * Math.max(0, Math.min(1, root.ratio))
          }
        }
      }
      NText {
        anchors.centerIn: parent
        text: root.valueText
        pointSize: Style.fontSizeL
        font.family: Settings.data.ui.fontFixed
        font.weight: Style.fontWeightSemiBold
      }
    }
    NText {
      Layout.fillWidth: true
      text: root.label
      pointSize: Style.fontSizeS
      horizontalAlignment: Text.AlignHCenter
    }
    NText {
      Layout.fillWidth: true
      text: root.detail
      pointSize: Style.fontSizeXXS
      color: HydraColor.mOnSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }
}
