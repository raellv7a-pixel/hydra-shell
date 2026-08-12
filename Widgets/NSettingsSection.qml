import QtQuick
import QtQuick.Layouts
import qs.Commons

// A titled group of settings controls, inspired by End4's ContentSection:
// an icon + bold title header followed by a column of controls, with no
// border or background of its own — grouping comes from typography and
// spacing alone, not a card container.
//
// Meant for tabs to adopt incrementally; existing Settings tabs keep using
// NDivider between groups until migrated to this one at a time.
//
// Usage:
//   NSettingsSection {
//     icon: "sync-alt"
//     title: I18n.tr("panels.background.parallax-title")
//     NToggle { ... }
//     NComboBox { ... }
//   }
ColumnLayout {
  id: root

  property string icon: ""
  property string title: ""
  property string description: ""

  Layout.fillWidth: true
  spacing: Style.marginS

  default property alias content: contentColumn.children

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    visible: root.title !== "" || root.icon !== ""

    NIcon {
      icon: root.icon
      pointSize: Style.fontSizeL
      color: Color.mPrimary
      visible: root.icon !== ""
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS

      NText {
        text: root.title
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        visible: root.title !== ""
      }

      NText {
        text: root.description
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        visible: root.description !== ""
      }
    }
  }

  // Indented under the title (past the icon column) so content visually
  // belongs to this section's header, End4-style.
  ColumnLayout {
    id: contentColumn
    Layout.fillWidth: true
    Layout.leftMargin: root.icon !== "" ? (Style.fontSizeL + Style.marginS) : 0
    spacing: Style.marginM
  }
}
