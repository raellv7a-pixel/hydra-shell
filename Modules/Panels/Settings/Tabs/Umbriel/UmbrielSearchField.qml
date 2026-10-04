import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Local Material search treatment; other Settings text fields keep their style.
ColumnLayout {
  id: root
  property string label: ""
  property string placeholderText: ""
  property alias text: input.text

  Layout.fillWidth: true
  spacing: Style.marginS

  NText {
    id: fieldLabel
    visible: root.label !== ""
    text: root.label
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  Rectangle {
    id: field
    Layout.fillWidth: true
    implicitHeight: Style.baseWidgetSize * 1.2 * Style.uiScaleRatio
    radius: Style.iRadiusL
    color: input.activeFocus || hover.hovered ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHigh
    border.color: input.activeFocus ? Color.mPrimary : "transparent"
    border.width: input.activeFocus ? Style.borderM : 0

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation { duration: hover.hovered ? Style.hoverEnterDuration : Style.hoverLeaveDuration }
    }

    HoverHandler { id: hover }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.marginL
      anchors.rightMargin: Style.marginS
      spacing: Style.marginM

      NIcon { icon: "search"; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeM }
      TextField {
        id: input
        Layout.fillWidth: true
        Layout.fillHeight: true
        background: null
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        verticalAlignment: TextInput.AlignVCenter
        placeholderText: root.placeholderText
        placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.7)
        color: Color.mOnSurface
        font.family: fieldLabel.font.family
        font.pointSize: fieldLabel.font.pointSize
        selectByMouse: true
        Accessible.name: root.label || root.placeholderText
      }
      NIconButton {
        visible: input.text !== ""
        icon: "x"
        baseSize: Style.baseWidgetSize * 0.8
        tooltipText: "Limpar busca"
        onClicked: { input.clear(); input.forceActiveFocus(); }
      }
    }
  }
}
