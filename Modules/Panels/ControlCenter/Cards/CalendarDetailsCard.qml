import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Modules.Cards
DashboardCard {
  id: calendarDetailsCard

  styleKey: "calendar"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"
  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("calendar")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NText {
        text: I18n.locale.toString(Time.now, "ddd, dd")
        pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: Color.mPrimary
      }
    }

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: calendarDetailsColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: calendarDetailsColumn
        width: parent.width
        spacing: Style.marginM

        CalendarHeaderCard {
          Layout.fillWidth: true
        }

        CalendarMonthCard {
          Layout.fillWidth: true
        }
      }
    }
  }
}
