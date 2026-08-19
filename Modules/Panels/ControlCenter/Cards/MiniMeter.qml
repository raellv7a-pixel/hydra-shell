import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: miniMeter

  styleKey: panelRoot.inheritedStyleKey(parent)

  property string labelText: ""
  property string iconName: ""
  property string valueText: ""
  property string detailText: ""
  property real ratio: 0
  property color fillColor: panelRoot.componentAccent(styleKey)
  readonly property real safeRatio: Math.max(0, Math.min(1, ratio))

  Layout.preferredHeight: Math.round(62 * panelRoot.panelUnit)
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: detailText !== "" ? Style.marginXS : Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: iconName
        pointSize: Style.fontSizeM
        color: miniMeter.fillColor
      }

      NText {
        Layout.fillWidth: true
        text: labelText
        color: panelRoot.componentText(miniMeter.styleKey, false)
        pointSize: Style.fontSizeS
      }

      NText {
        text: valueText
        color: panelRoot.componentText(miniMeter.styleKey, true)
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightSemiBold
      }
    }

    NText {
      Layout.fillWidth: true
      visible: detailText !== ""
      text: detailText
      color: Qt.alpha(panelRoot.componentText(miniMeter.styleKey, false), 0.74)
      pointSize: Style.fontSizeXXS
      elide: Text.ElideRight
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(5, Math.round(6 * panelRoot.panelUnit))
      radius: height / 2
      color: Qt.alpha(Color.mOutline, 0.16)
      clip: true

      Rectangle {
        width: parent.width * miniMeter.safeRatio
        height: parent.height
        radius: parent.radius
        color: miniMeter.fillColor

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          opacity: 0.12
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
              position: 0.0
              color: Qt.rgba(1, 1, 1, 0)
            }
            GradientStop {
              position: 0.55
              color: Qt.rgba(1, 1, 1, 0.16)
            }
            GradientStop {
              position: 1.0
              color: Qt.rgba(1, 1, 1, 0)
            }
          }
        }

        Behavior on width {
          NumberAnimation {
            duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
      }

      Rectangle {
        width: Math.max(6, Math.round(7 * panelRoot.panelUnit))
        height: width
        radius: width / 2
        x: Math.max(0, Math.min(parent.width - width, parent.width * miniMeter.safeRatio - width / 2))
        y: (parent.height - height) / 2
        visible: miniMeter.safeRatio > 0.02
        color: miniMeter.fillColor
        opacity: 0.78

        Behavior on x {
          NumberAnimation {
            duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
