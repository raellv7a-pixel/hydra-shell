import QtQuick
import qs.Commons

Rectangle {
  id: root

  required property var assignedPanel

  readonly property var panelRegion: assignedPanel?.panelRegion ?? null
  readonly property var panelBg: (panelRegion && panelRegion.visible) ? panelRegion.panelItem : null
  readonly property bool revealHorizontally: assignedPanel?.cachedShouldAnimateWidth ?? false
  readonly property bool revealVertically: assignedPanel?.cachedShouldAnimateHeight ?? false
  readonly property bool fromLeft: revealHorizontally && (assignedPanel?.cachedAnimateFromLeft ?? false)
  readonly property bool fromRight: revealHorizontally && (assignedPanel?.cachedAnimateFromRight ?? false)
  readonly property bool fromTop: revealVertically && (assignedPanel?.cachedAnimateFromTop ?? false)
  readonly property bool fromBottom: revealVertically && (assignedPanel?.cachedAnimateFromBottom ?? false)

  readonly property real panelX: panelBg?.x ?? 0
  readonly property real panelY: panelBg?.y ?? 0
  readonly property real panelWidth: panelBg?.width ?? 0
  readonly property real panelHeight: panelBg?.height ?? 0
  readonly property real revealLength: revealHorizontally ? panelWidth : panelHeight
  readonly property real targetLength: revealHorizontally ? (panelBg?.targetWidth ?? 0) : (panelBg?.targetHeight ?? 0)
  // Follow actual animated geometry in both directions; cached direction flags
  // remain set after opening and are not an animation-lifetime signal.
  readonly property bool revealing: revealLength > 0 && revealLength < targetLength
  readonly property real seamLength: Math.min(24, revealLength)
  readonly property real cornerInset: Math.min(Style.radiusL, (revealHorizontally ? panelHeight : panelWidth) / 2)
  readonly property color seamShadow: Qt.rgba(Color.mShadow.r, Color.mShadow.g, Color.mShadow.b, Color.mShadow.a * 0.34)
  readonly property color seamMidShadow: Qt.rgba(Color.mShadow.r, Color.mShadow.g, Color.mShadow.b, Color.mShadow.a * 0.10)
  readonly property bool shadowAtStart: fromRight || fromBottom

  visible: assignedPanel && panelBg && revealing && seamLength > 0 && (fromLeft || fromRight || fromTop || fromBottom)
  x: panelX + (revealHorizontally ? (fromLeft ? panelWidth - seamLength : 0) : cornerInset)
  y: panelY + (revealVertically ? (fromTop ? panelHeight - seamLength : 0) : cornerInset)
  width: revealHorizontally ? seamLength : Math.max(0, panelWidth - cornerInset * 2)
  height: revealVertically ? seamLength : Math.max(0, panelHeight - cornerInset * 2)
  opacity: Math.min(1, revealLength / 24) * Math.min(1, Math.max(0, targetLength - revealLength) / 24)
  color: "transparent"
  antialiasing: true

  gradient: Gradient {
    orientation: root.revealHorizontally ? Gradient.Horizontal : Gradient.Vertical

    GradientStop {
      position: 0
      color: root.shadowAtStart ? root.seamShadow : "transparent"
    }
    GradientStop {
      position: 0.5
      color: root.seamMidShadow
    }
    GradientStop {
      position: 1
      color: root.shadowAtStart ? "transparent" : root.seamShadow
    }
  }
}
