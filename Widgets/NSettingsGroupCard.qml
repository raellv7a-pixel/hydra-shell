import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// A settings group in a shared vertical scroll; the owner keeps expansion state.
ColumnLayout {
  id: root
  property string title: ""
  property string description: ""
  property string summary: ""
  property string icon: ""
  property bool expanded: false
  default property alias content: body.children
  signal toggled(bool expanded)

  Layout.fillWidth: true
  spacing: 0

  Rectangle {
    id: surface
    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight
    radius: Style.radiusL
    color: HydraColor.mSurfaceContainerLow

    ColumnLayout {
      id: cardColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: 0

      NStateLayer {
        id: heading
        Layout.fillWidth: true
        implicitHeight: Math.max(Style.baseWidgetSize * Style.uiScaleRatio, titleRow.implicitHeight) + Style.margin2M
        focusPolicy: Qt.StrongFocus
        radius: Style.radiusL
        baseColor: HydraColor.mSurfaceContainerLow
        hovering: headingHover.containsMouse
        pressed: headingHover.pressed
        Accessible.role: Accessible.Button
        Accessible.name: root.title
        Accessible.description: !root.expanded && root.summary !== "" ? root.summary : root.description
        Accessible.checkable: true
        Accessible.checked: root.expanded
        Accessible.onPressAction: root.toggled(!root.expanded)
        Keys.onReturnPressed: root.toggled(!root.expanded)
        Keys.onSpacePressed: root.toggled(!root.expanded)
        Keys.onEnterPressed: root.toggled(!root.expanded)

        RowLayout {
          id: titleRow
          anchors.fill: parent
          anchors.leftMargin: Style.marginL
          anchors.rightMargin: Style.marginL
          anchors.topMargin: Style.marginM
          anchors.bottomMargin: Style.marginM
          spacing: Style.marginM
          NColorIcon {
            icon: root.icon
            size: Math.round(Style.baseWidgetSize * Style.uiScaleRatio * 0.8)
            Accessible.ignored: true
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS
            NText {
              Layout.fillWidth: true
              text: root.title
              font.weight: Style.fontWeightSemiBold
              pointSize: Style.fontSizeXL
              wrapMode: Text.WordWrap
              elide: Text.ElideNone
              Accessible.ignored: true
            }
            NText {
              Layout.fillWidth: true
              text: !root.expanded && root.summary !== "" ? root.summary : root.description
              visible: text !== ""
              wrapMode: Text.WordWrap
              elide: Text.ElideNone
              color: HydraColor.mOnSurfaceVariant
              font.weight: Style.fontWeightRegular
              pointSize: Style.fontSizeS
              Accessible.ignored: true
            }
          }
          NIcon {
            icon: "chevron-right"
            color: HydraColor.mOnSurfaceVariant
            pointSize: Style.fontSizeM
            rotation: root.expanded ? 90 : 0
            Accessible.ignored: true
            Behavior on rotation {
              RotationAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
              }
            }
          }
        }
        MouseArea {
          id: headingHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            heading.forceActiveFocus(Qt.MouseFocusReason);
            root.toggled(!root.expanded);
          }
        }
      }

      ColumnLayout {
        id: body
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginXL
        Layout.rightMargin: Style.marginXL
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginXL
        visible: root.expanded
        spacing: Style.marginM
        opacity: 1
        onVisibleChanged: {
          if (visible)
            appearance.restart();
          else
            appearance.stop();
        }
        NumberAnimation {
          id: appearance
          target: body
          property: "opacity"
          from: 0
          to: 1
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }
  }
}
