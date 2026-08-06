import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.Commons
import qs.Services.UI

Slider {
  id: root

  readonly property bool sliderActive: activeFocus || pressed
  property color fillColor: Color.mPrimary
  property var cutoutColor: Color.mSurface
  property bool snapAlways: true
  property real heightRatio: 0.7
  property var tooltipText
  property string tooltipDirection: "auto"
  property bool hovering: false

  readonly property color effectiveFillColor: enabled ? fillColor : Color.mOutline

  readonly property real knobDiameter: Math.round((Style.baseWidgetSize * heightRatio * Style.uiScaleRatio) / 2) * 2
  readonly property real handleWidth: Math.max(3, Math.round(4 * Style.uiScaleRatio))
  readonly property real handleTouchWidth: Math.max(knobDiameter, Math.round(28 * Style.uiScaleRatio))
  readonly property real trackHeight: Math.max(6, Math.round(8 * Style.uiScaleRatio))
  readonly property real trackRadius: Math.min(Style.iRadiusL, trackHeight / 2)
  readonly property real cutoutExtra: Math.round((Style.baseWidgetSize * 0.1 * Style.uiScaleRatio) / 2) * 2

  padding: cutoutExtra / 2

  snapMode: snapAlways ? Slider.SnapAlways : Slider.SnapOnRelease
  implicitHeight: Math.max(trackHeight, knobDiameter)

  background: Item {
    id: bgContainer
    x: root.leftPadding
    y: root.topPadding + Style.pixelAlignCenter(root.availableHeight, root.trackHeight)
    implicitWidth: Style.sliderWidth
    implicitHeight: root.trackHeight
    width: root.availableWidth
    height: root.trackHeight

    readonly property real fillWidth: root.visualPosition * width

    // Background track
    Shape {
      anchors.fill: parent
      visible: bgContainer.width > 0 && bgContainer.height > 0
      preferredRendererType: Shape.CurveRenderer
      asynchronous: true

      ShapePath {
        id: bgPath
        strokeColor: "transparent"
        strokeWidth: 0
        fillColor: Color.mSurfaceContainerHighest

        readonly property real w: bgContainer.width
        readonly property real h: bgContainer.height
        readonly property real r: root.trackRadius

        startX: r
        startY: 0

        PathLine {
          x: bgPath.w - bgPath.r
          y: 0
        }
        PathArc {
          x: bgPath.w
          y: bgPath.r
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
        PathLine {
          x: bgPath.w
          y: bgPath.h - bgPath.r
        }
        PathArc {
          x: bgPath.w - bgPath.r
          y: bgPath.h
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
        PathLine {
          x: bgPath.r
          y: bgPath.h
        }
        PathArc {
          x: 0
          y: bgPath.h - bgPath.r
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
        PathLine {
          x: 0
          y: bgPath.r
        }
        PathArc {
          x: bgPath.r
          y: 0
          radiusX: bgPath.r
          radiusY: bgPath.r
        }
      }
    }

    LinearGradient {
      id: fillGradient
      x1: 0
      y1: 0
      x2: root.availableWidth
      y2: 0
      GradientStop {
        position: 0.0
        color: effectiveFillColor
      }
      GradientStop {
        position: 1.0
        color: effectiveFillColor
      }
    }

    // Active/filled track
    Shape {
      width: bgContainer.fillWidth
      height: bgContainer.height
      visible: bgContainer.fillWidth > 0 && bgContainer.height > 0
      preferredRendererType: Shape.CurveRenderer
      asynchronous: true
      clip: true

      ShapePath {
        id: fillPath
        strokeColor: "transparent"
        fillGradient: fillGradient

        readonly property real fullWidth: root.availableWidth
        readonly property real h: root.trackHeight
        readonly property real r: root.trackRadius

        startX: r
        startY: 0

        PathLine {
          x: fillPath.fullWidth - fillPath.r
          y: 0
        }
        PathArc {
          x: fillPath.fullWidth
          y: fillPath.r
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
        PathLine {
          x: fillPath.fullWidth
          y: fillPath.h - fillPath.r
        }
        PathArc {
          x: fillPath.fullWidth - fillPath.r
          y: fillPath.h
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
        PathLine {
          x: fillPath.r
          y: fillPath.h
        }
        PathArc {
          x: 0
          y: fillPath.h - fillPath.r
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
        PathLine {
          x: 0
          y: fillPath.r
        }
        PathArc {
          x: fillPath.r
          y: 0
          radiusX: fillPath.r
          radiusY: fillPath.r
        }
      }
    }

    // Material 3 gap around the handle
    Rectangle {
      id: knobCutout
      implicitWidth: root.handleWidth + root.cutoutExtra
      implicitHeight: root.knobDiameter + root.cutoutExtra
      radius: Math.min(Style.iRadiusL, width / 2)
      color: root.cutoutColor !== undefined ? root.cutoutColor : Color.mSurface
      x: root.visualPosition * (root.availableWidth - root.handleTouchWidth) + (root.handleTouchWidth - width) / 2
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  handle: Item {
    implicitWidth: handleTouchWidth
    implicitHeight: knobDiameter
    x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      id: knob
      implicitWidth: root.pressed ? Math.max(2, root.handleWidth / 2) : root.handleWidth
      implicitHeight: knobDiameter
      radius: width / 2
      color: effectiveFillColor
      border.color: "transparent"
      border.width: 0
      anchors.centerIn: parent

      Behavior on color {
        ColorAnimation {
          duration: Style.animationFast
        }
      }
    }

    MouseArea {
      enabled: true
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      acceptedButtons: Qt.NoButton // Don't accept any mouse buttons - only hover
      propagateComposedEvents: true

      onEntered: {
        root.hovering = true;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.show(knob, root.tooltipText, root.tooltipDirection);
        }
      }

      onExited: {
        root.hovering = false;
        if (root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }

    // Hide tooltip when slider is pressed (anywhere on the slider)
    Connections {
      target: root
      function onPressedChanged() {
        if (root.pressed && root.tooltipText && (!Array.isArray(root.tooltipText) || root.tooltipText.length > 0)) {
          TooltipService.hide();
        }
      }
    }
  }
}
