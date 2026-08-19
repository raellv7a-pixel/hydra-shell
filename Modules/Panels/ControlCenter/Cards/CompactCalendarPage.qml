import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
Item {
  id: compactCalendar

  required property var panelRoot

  readonly property var now: Time.now
  property int calendarMonth: now.getMonth()
  property int calendarYear: now.getFullYear()
  readonly property int firstDayOfWeek: Settings.data.location.firstDayOfWeek === -1 ? I18n.locale.firstDayOfWeek : Settings.data.location.firstDayOfWeek

  function navigate(delta) {
    const date = new Date(calendarYear, calendarMonth + delta, 1);
    calendarMonth = date.getMonth();
    calendarYear = date.getFullYear();
  }

  function today() {
    calendarMonth = now.getMonth();
    calendarYear = now.getFullYear();
  }

  function daysModel() {
    const firstOfMonth = new Date(calendarYear, calendarMonth, 1);
    const lastOfMonth = new Date(calendarYear, calendarMonth + 1, 0);
    const daysInMonth = lastOfMonth.getDate();
    const firstOfMonthDayOfWeek = firstOfMonth.getDay();
    const daysBefore = (firstOfMonthDayOfWeek - firstDayOfWeek + 7) % 7;
    const days = [];
    const todayDate = new Date();
    const prevMonth = new Date(calendarYear, calendarMonth, 0);

    for (let i = daysBefore - 1; i >= 0; i--) {
      days.push({
                  "day": prevMonth.getDate() - i,
                  "month": calendarMonth - 1,
                  "year": calendarMonth === 0 ? calendarYear - 1 : calendarYear,
                  "today": false,
                  "currentMonth": false
                });
    }

    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(calendarYear, calendarMonth, day);
      days.push({
                  "day": day,
                  "month": calendarMonth,
                  "year": calendarYear,
                  "today": date.getFullYear() === todayDate.getFullYear() && date.getMonth() === todayDate.getMonth() && date.getDate() === todayDate.getDate(),
                  "currentMonth": true
                });
    }

    for (let day = 1; days.length < 42; day++) {
      days.push({
                  "day": day,
                  "month": calendarMonth + 1,
                  "year": calendarMonth === 11 ? calendarYear + 1 : calendarYear,
                  "today": false,
                  "currentMonth": false
                });
    }

    return days;
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(30 * panelRoot.panelUnit)
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: I18n.locale.monthName(compactCalendar.calendarMonth, Locale.LongFormat).toUpperCase() + " " + compactCalendar.calendarYear
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: panelRoot.componentText("calendar", true)
        elide: Text.ElideRight
      }

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(28 * panelRoot.panelUnit)
        colorBgHover: panelRoot.componentButtonBackground("calendar")
        colorFg: panelRoot.componentText("calendar", true)
        colorFgHover: panelRoot.componentButtonText("calendar")
        colorBorderHover: panelRoot.componentButtonBackground("calendar")
        onClicked: compactCalendar.navigate(-1)
      }

      NIconButton {
        icon: "calendar"
        baseSize: Math.round(28 * panelRoot.panelUnit)
        colorBgHover: panelRoot.componentButtonBackground("calendar")
        colorFg: panelRoot.componentText("calendar", true)
        colorFgHover: panelRoot.componentButtonText("calendar")
        colorBorderHover: panelRoot.componentButtonBackground("calendar")
        onClicked: compactCalendar.today()
      }

      NIconButton {
        icon: "chevron-right"
        baseSize: Math.round(28 * panelRoot.panelUnit)
        colorBgHover: panelRoot.componentButtonBackground("calendar")
        colorFg: panelRoot.componentText("calendar", true)
        colorFgHover: panelRoot.componentButtonText("calendar")
        colorBorderHover: panelRoot.componentButtonBackground("calendar")
        onClicked: compactCalendar.navigate(1)
      }

      SubmoduleButton {
        panelRoot: compactCalendar.panelRoot
        targetView: "calendar"
        tooltipText: panelRoot.tr("details")
      }
    }

    GridLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(20 * panelRoot.panelUnit)
      columns: 7
      columnSpacing: 0
      rowSpacing: 0

      Repeater {
        model: 7

        NText {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: I18n.locale.dayName((compactCalendar.firstDayOfWeek + index) % 7, Locale.ShortFormat).substring(0, 2).toUpperCase()
          color: panelRoot.componentAccent("calendar")
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightBold
        }
      }
    }

    GridLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      columns: 7
      rows: 6
      columnSpacing: Style.marginXXS
      rowSpacing: Style.marginXXS

      Repeater {
        model: compactCalendar.daysModel()

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: 0

          Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, Math.round(28 * panelRoot.panelUnit))
            height: width
            radius: width / 2
            color: modelData.today ? panelRoot.componentButtonBackground("calendar") : "transparent"

            NText {
              anchors.centerIn: parent
              text: modelData.day
              color: modelData.today ? panelRoot.componentButtonText("calendar") : (modelData.currentMonth ? panelRoot.componentText("calendar", true) : panelRoot.componentText("calendar", false))
              opacity: modelData.currentMonth ? 1 : 0.36
              pointSize: Style.fontSizeS
              font.weight: modelData.today ? Style.fontWeightBold : Style.fontWeightMedium
            }
          }
        }
      }
    }
  }
}
