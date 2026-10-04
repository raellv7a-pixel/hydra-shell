import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "region"
  groups: [
    { key: "location", labelKey: "common.location", icon: "map-pin", content: locationContent },
    { key: "date", labelKey: "common.date", icon: "calendar", content: dateContent },
    { key: "calendar", labelKey: "common.calendar-panel", icon: "clock", content: calendarContent }
  ]

  Component { id: locationContent; LocationSubTab {} }
  Component { id: dateContent; DateSubTab {} }
  Component { id: calendarContent; ClockPanelSubTab {} }
}
