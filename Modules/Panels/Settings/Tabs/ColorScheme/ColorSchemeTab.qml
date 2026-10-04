pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "."
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "colors"

  // Time dropdown options (00:00 .. 23:30)
  ListModel {
    id: timeOptions
  }

  property var screen

  function populateTimeOptions() {
    for (var h = 0; h < 24; h++) {
      for (var m = 0; m < 60; m += 30) {
        var hh = ("0" + h).slice(-2);
        var mm = ("0" + m).slice(-2);
        var key = hh + ":" + mm;
        timeOptions.append({
                             "key": key,
                             "name": key
                           });
      }
    }
  }

  Component.onCompleted: {
    Qt.callLater(populateTimeOptions);
  }

  // Download popup
  Loader {
    id: downloadPopupLoader
    active: false
    sourceComponent: SchemeDownloader {
      parent: Overlay.overlay
    }

    property bool pendingOpen: false

    function open() {
      pendingOpen = true;
      active = true;
      if (item) {
        item.open();
        pendingOpen = false;
      }
    }

    onItemChanged: {
      if (item && pendingOpen) {
        item.open();
        pendingOpen = false;
      }
    }
  }

  groups: [
    { key: "colors", labelKey: "common.colors", icon: "palette", content: colorsContent },
    { key: "templates", labelKey: "common.templates", icon: "file-code", content: templatesContent }
  ]

  Component {
    id: colorsContent
    ColorsSubTab {
      screen: root.screen
      timeOptions: timeOptions
      onOpenDownloadPopup: downloadPopupLoader.open()
    }
  }
  Component { id: templatesContent; TemplatesSubTab {} }
}
