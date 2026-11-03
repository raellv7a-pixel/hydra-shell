import QtQuick
import QtQuick.Layouts
import qs.Commons

// Open subsections separate related controls without adding another card or
// collapsing form state. The owning group provides the containing surface.
ColumnLayout {
  id: root

  property string icon: ""
  property string title: ""
  property string description: ""

  Layout.fillWidth: true
  Layout.minimumWidth: 0
  Layout.topMargin: Style.marginM
  spacing: Style.marginL
  Accessible.role: Accessible.Grouping
  Accessible.name: title
  Accessible.description: description

  default property alias content: contentColumn.data

  RowLayout {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: Style.marginM
    visible: root.title !== "" || root.icon !== ""

    NColorIcon {
      icon: root.icon
      size: Math.round(22 * Style.uiScaleRatio)
      visible: root.icon !== ""
      Layout.alignment: Qt.AlignTop
      Accessible.ignored: true
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: Style.marginXXS

      NText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.title
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
        color: HydraColor.mPrimary
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        visible: root.title !== ""
        Accessible.ignored: true
      }

      NText {
        text: root.description
        pointSize: Style.fontSizeS
        color: HydraColor.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: root.description !== ""
        elide: Text.ElideNone
        Accessible.ignored: true
      }
    }
  }

  // Controls share one alignment, even on narrow panes; nested indentation
  // would consume the space their descriptions and editors need.
  ColumnLayout {
    id: contentColumn
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: Style.marginM
  }
}
