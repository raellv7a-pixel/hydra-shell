import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// A settings group in a shared vertical scroll; the owner keeps expansion state.
ColumnLayout {
  id: root
  property string title: ""
  property string description: ""
  property string icon: ""
  property bool expanded: false
  default property alias content: body.children
  signal toggled(bool expanded)

  Layout.fillWidth: true
  spacing: 0

  Rectangle {
    id: surface
    Layout.fillWidth: true
    implicitHeight: heading.implicitHeight + (root.expanded ? body.implicitHeight + Style.marginL : 0) + Style.margin2XL
    radius: Style.radiusL
    color: root.expanded || headingHover.containsMouse ? Color.mSurfaceContainer : Color.mSurfaceContainerLow
    clip: true

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation { duration: headingHover.containsMouse ? Style.hoverEnterDuration : Style.hoverLeaveDuration }
    }
    Behavior on implicitHeight {
      NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginXL
      spacing: Style.marginL

      Item {
        id: heading
        Layout.fillWidth: true
        implicitHeight: Math.max(Style.baseWidgetSize, titleRow.implicitHeight)
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.title
        Accessible.description: root.description + (root.expanded ? "; expandido" : "; recolhido")
        Keys.onReturnPressed: root.toggled(!root.expanded)
        Keys.onSpacePressed: root.toggled(!root.expanded)

        RowLayout {
          id: titleRow
          anchors.fill: parent
          spacing: Style.marginM
          Rectangle {
            Layout.preferredWidth: Style.baseWidgetSize * Style.uiScaleRatio
            Layout.preferredHeight: Layout.preferredWidth
            radius: Style.iRadiusM
            color: Color.mSecondaryContainer
            NIcon {
              anchors.centerIn: parent
              icon: root.icon
              color: Color.mOnSecondaryContainer
              pointSize: Style.fontSizeL
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS
            NText { Layout.fillWidth: true; text: root.title; font.weight: Style.fontWeightSemiBold; pointSize: Style.fontSizeL }
            NText { text: root.description; visible: root.description !== ""; wrapMode: Text.WordWrap; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeM; Layout.fillWidth: true }
          }
          NIcon {
            icon: "chevron-down"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Style.animationFast } }
          }
        }
        MouseArea {
          id: headingHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggled(!root.expanded)
        }
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusM
          color: "transparent"
          border.color: heading.activeFocus ? Color.mPrimary : "transparent"
          border.width: heading.activeFocus ? Style.borderM : 0
        }
      }

      ColumnLayout {
        id: body
        Layout.fillWidth: true
        visible: root.expanded
        spacing: Style.marginM
      }
    }
  }
}
