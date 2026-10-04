pragma ComponentBehavior: Bound

import QtQuick
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "osd"

  // Helper functions to update arrays immutably
  function addMonitor(list, name) {
    const arr = (list || []).slice();
    if (!arr.includes(name))
      arr.push(name);
    return arr;
  }
  function removeMonitor(list, name) {
    return (list || []).filter(function (n) {
      return n !== name;
    });
  }
  function addType(list, type) {
    const arr = (list || []).slice();
    if (!arr.includes(type))
      arr.push(type);
    return arr;
  }
  function removeType(list, type) {
    return (list || []).filter(function (t) {
      return t !== type;
    });
  }

  groups: [
    { key: "general", labelKey: "common.general", icon: "settings", content: generalContent },
    { key: "events", labelKey: "common.events", icon: "bell", content: eventsContent }
  ]

  Component {
    id: generalContent
    GeneralSubTab {
      addMonitor: root.addMonitor
      removeMonitor: root.removeMonitor
    }
  }
  Component {
    id: eventsContent
    EventsSubTab {
      addType: root.addType
      removeType: root.removeType
    }
  }
}
