pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Widgets

NBox {
  id: root
  property var metrics: []
  property int currentIndex: 0
  readonly property var metric: metrics[currentIndex] || ({})
  readonly property var samples: metric.values || []
  readonly property var validSamples: samples.filter(v => v !== null && Number.isFinite(v))
  readonly property real ceiling: Math.max(1, metric.maximum || 100)
  readonly property var segments: {
    let result = [], points = [];
    for (let i = 0; i < samples.length; ++i) {
      const value = samples[i];
      if (value === null || !Number.isFinite(value)) {
        if (points.length > 1)
          result.push(points);
        points = [];
      } else {
        points.push(Qt.point(i * graph.width / Math.max(1, samples.length - 1), graph.height * (1 - Math.max(0, Math.min(1, value / ceiling)))));
      }
    }
    if (points.length > 1)
      result.push(points);
    return result;
  }
  implicitHeight: 126 * Style.uiScaleRatio
  border.width: 0
  color: HydraColor.mSurfaceContainerHigh

  function format(value) {
    return Math.round(value) + (metric.unit || "");
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 25 * Style.uiScaleRatio
      Layout.maximumHeight: Layout.preferredHeight
      Repeater {
        model: root.metrics
        NTabButton {
          required property var modelData
          required property int index
          text: modelData.label
          checked: root.currentIndex === index
          pointSize: Style.fontSizeXXS
          Layout.preferredHeight: 25 * Style.uiScaleRatio
          onClicked: root.currentIndex = index
        }
      }
      Item {
        Layout.fillWidth: true
      }
      NText {
        text: I18n.tr("system-monitor.dashboard.window-seconds", {
                        seconds: Math.round(root.samples.length * (root.metric.interval || 1000) / 1000)
                      })
        pointSize: Style.fontSizeXXS
        color: HydraColor.mOnSurfaceVariant
      }
    }
    Item {
      id: graph
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 50 * Style.uiScaleRatio
      Repeater {
        model: 3
        Rectangle {
          required property int index
          width: graph.width
          height: Style.borderS
          y: index * (graph.height - height) / 2
          color: Qt.alpha(HydraColor.mOnSurface, 0.06)
        }
      }
      Repeater {
        model: root.segments
        Shape {
          id: historySegment
          required property var modelData
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: root.metric.color || HydraColor.mPrimary
            strokeWidth: Style.borderS
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
              path: historySegment.modelData
            }
          }
        }
      }
      NText {
        anchors.centerIn: parent
        visible: root.validSamples.length < 2
        text: I18n.tr("system-monitor.dashboard.collecting")
        color: HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
      }
    }
    NText {
      Layout.fillWidth: true
      text: root.validSamples.length ? I18n.tr("system-monitor.dashboard.history-summary", {
                                                 min: root.format(Math.min(...root.validSamples)),
                                                 average: root.format(root.validSamples.reduce((a, b) => a + b, 0) / root.validSamples.length),
                                                 max: root.format(Math.max(...root.validSamples))
                                               }) : I18n.tr("system-monitor.dashboard.sensor-unavailable")
      pointSize: Style.fontSizeXXS
      font.family: Settings.data.ui.fontFixed
      color: HydraColor.mOnSurfaceVariant
    }
  }
}
