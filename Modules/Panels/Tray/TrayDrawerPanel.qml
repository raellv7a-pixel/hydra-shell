import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI
import qs.Widgets

// A compact grid panel listing all tray items, opened from the Tray widget
SmartPanel {
  id: root

  // Keep pointer interaction inside this SmartPanel surface for grid and menus.
  exclusiveKeyboard: false

  // Widget info for menu functionality (set by Tray widget when opening)
  property string widgetSection: ""
  property int widgetIndex: -1
  property var selectedTrayItem: null
  property var menuPath: []
  readonly property bool menuOpen: selectedTrayItem !== null

  function showGrid() {
    selectedTrayItem = null;
    menuPath = [];
  }

  function showItemMenu(item, section, index, anchor) {
    if (!item?.hasMenu || !item.menu)
      return;
    widgetSection = section;
    widgetIndex = index;
    selectedTrayItem = item;
    menuPath = [];
    if (!isPanelOpen)
      open(anchor);
  }

  function menuBack() {
    if (menuPath.length)
      menuPath = menuPath.slice(0, -1);
    else
      showGrid();
  }

  function togglePinned() {
    if (!selectedTrayItem || !widgetSection || widgetIndex < 0)
      return;
    const name = selectedTrayItem.tooltipTitle || selectedTrayItem.name || selectedTrayItem.id || "";
    if (!name)
      return;
    const screenName = screen?.name || "";
    const widgets = Settings.getBarWidgetsForScreen(screenName)[widgetSection];
    const current = widgets?.[widgetIndex];
    if (!current || current.id !== "Tray")
      return;
    const pinned = (current.pinned || []).slice();
    const match = pinned.indexOf(name);
    if (match >= 0)
      pinned.splice(match, 1);
    else
      pinned.push(name);
    widgets[widgetIndex] = Object.assign({}, current, { pinned: pinned });
    if (Settings.hasScreenOverride(screenName, "widgets")) {
      const perScreen = Settings.getBarWidgetsForScreen(screenName);
      perScreen[widgetSection] = widgets;
      Settings.setScreenOverride(screenName, "widgets", perScreen);
    } else {
      Settings.data.bar.widgets[widgetSection] = widgets;
    }
    Settings.saveImmediate();
    showGrid();
    if (trayValues.length === 0)
      close();
  }

  // Sizing properties must stay at root for preferredWidth/Height
  readonly property int maxColumns: 8
  readonly property real cellSize: Math.round(Style.capsuleHeight * 0.65)
  readonly property real outerPadding: Style.marginM
  readonly property real innerSpacing: Style.marginM

  // All tray items from SystemTray
  readonly property var trayValuesAll: (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : []

  // Filtered items - computed in panelContent where isPinned is available
  property var trayValues: []

  readonly property int itemCount: trayValues.length
  readonly property int columns: Math.max(1, Math.min(maxColumns, itemCount))
  readonly property int rows: Math.max(1, Math.ceil(itemCount / Math.max(1, columns)))

  readonly property real gridPreferredWidth: (columns * cellSize) + ((columns - 1) * innerSpacing) + (2 * outerPadding)
  readonly property real gridPreferredHeight: (rows * cellSize) + ((rows - 1) * innerSpacing) + (2 * outerPadding)

  preferredWidth: (menuOpen && contentItem?.menuPreferredWidth) ? contentItem.menuPreferredWidth : gridPreferredWidth
  preferredHeight: (menuOpen && contentItem?.menuPreferredHeight) ? contentItem.menuPreferredHeight : gridPreferredHeight

  // Auto-close drawer when all items are pinned (drawer becomes empty)
  onTrayValuesChanged: {
    if (visible && trayValues.length === 0 && !menuOpen)
      close();
  }

  onOpened: {
    if (contentItem)
      contentItem.settingsVersion++;
  }
  onClosed: showGrid()

  panelContent: Item {
    id: panelContent

    // Settings state (lazy-loaded with panelContent)
    property int settingsVersion: 0

    readonly property var widgetSettings: {
      // Reference settingsVersion to force recalculation when it changes
      void (settingsVersion);
      if (root.widgetSection === "" || root.widgetIndex < 0)
        return {};
      var widgets = Settings.getBarWidgetsForScreen(root.screen?.name)[root.widgetSection];
      if (!widgets || root.widgetIndex >= widgets.length)
        return {};
      var settings = widgets[root.widgetIndex];
      if (!settings || settings.id !== "Tray")
        return {};
      return settings;
    }

    readonly property var pinnedList: widgetSettings.pinned || []
    readonly property bool hidePassive: widgetSettings.hidePassive !== undefined ? widgetSettings.hidePassive : true

    // Filter tray items - this runs in panelContent context where isPinned is available
    function updateFilteredItems() {
      var filtered = [];
      for (var i = 0; i < root.trayValuesAll.length; i++) {
        var item = root.trayValuesAll[i];
        if (!item)
          continue;

        // Filter out passive items if hidePassive is enabled
        if (hidePassive && item.status !== undefined && (item.status === SystemTray.Passive || item.status === 0)) {
          continue;
        }

        // Filter out pinned items
        if (isPinned(item)) {
          continue;
        }

        filtered.push(item);
      }
      root.trayValues = filtered;
    }

    // Update filtered items when dependencies change
    Component.onCompleted: updateFilteredItems()
    onPinnedListChanged: updateFilteredItems()
    onHidePassiveChanged: updateFilteredItems()

    Connections {
      target: root
      function onTrayValuesAllChanged() {
        panelContent.updateFilteredItems();
      }
    }

    // Helper functions (lazy-loaded with panelContent)
    function wildCardMatch(str, rule) {
      if (!str || !rule)
        return false;
      const placeholder = '\uE000';
      let processedRule = rule.replace(/\*/g, placeholder);
      let escaped = processedRule.replace(/[.+?^${}()|[\]\\]/g, '\\$&');
      let pattern = '^' + escaped.replace(new RegExp(placeholder, 'g'), '.*') + '$';
      try {
        return new RegExp(pattern, 'i').test(str);
      } catch (e) {
        return false;
      }
    }

    function isPinned(item) {
      if (!pinnedList || pinnedList.length === 0)
        return false;
      const title = item?.tooltipTitle || item?.name || item?.id || "";
      for (var i = 0; i < pinnedList.length; i++) {
        if (wildCardMatch(title, pinnedList[i]))
          return true;
      }
      return false;
    }

    // SmartPanel reads these from its loaded content as well as from the root.
    readonly property real menuPreferredWidth: menuPage.implicitWidth
    readonly property real menuPreferredHeight: menuPage.implicitHeight
    property real contentPreferredWidth: root.menuOpen ? menuPreferredWidth : root.gridPreferredWidth
    property real contentPreferredHeight: root.menuOpen ? menuPreferredHeight : root.gridPreferredHeight

    // Connections (lazy-loaded with panelContent)
    Connections {
      target: Settings
      function onSettingsSaved() {
        panelContent.settingsVersion++;
      }
    }


    Grid {
      id: grid
      visible: !root.menuOpen
      anchors.fill: parent
      anchors.margins: root.outerPadding
      spacing: root.innerSpacing
      columns: root.columns
      rowSpacing: root.innerSpacing
      columnSpacing: root.innerSpacing

      Repeater {
        id: repeater
        model: root.trayValues

        delegate: Item {
          width: root.cellSize
          height: root.cellSize

          IconImage {
            id: trayIcon
            anchors.fill: parent
            asynchronous: true
            backer.fillMode: Image.PreserveAspectFit
            source: {
              let icon = modelData?.icon || "";
              if (!icon)
                return "";
              if (icon.includes("?path=")) {
                const chunks = icon.split("?path=");
                const name = chunks[0];
                const path = chunks[1];
                const fileName = name.substring(name.lastIndexOf("/") + 1);
                return `file://${path}/${fileName}`;
              }
              return icon;
            }

            layer.enabled: panelContent.widgetSettings.colorizeIcons !== false
            layer.effect: ShaderEffect {
              property color targetColor: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mSurfaceVariant
              property real colorizeMode: 1.0
              fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

              onClicked: mouse => {
                           if (!modelData)
                           return;
                           if (mouse.button === Qt.LeftButton) {
                             if (!modelData.onlyMenu) {
                               modelData.activate();
                             }
                             if ((PanelService.openedPanel !== null) && !PanelService.openedPanel.isClosing) {
                               PanelService.openedPanel.close();
                             }
                           } else if (mouse.button === Qt.MiddleButton) {
                             modelData.secondaryActivate && modelData.secondaryActivate();
                             if ((PanelService.openedPanel !== null) && !PanelService.openedPanel.isClosing) {
                               PanelService.openedPanel.close();
                             }
                           } else if (mouse.button === Qt.RightButton) {
                             TooltipService.hideImmediately();
                             root.showItemMenu(modelData, root.widgetSection, root.widgetIndex, trayIcon);
                           }
                         }

              onWheel: wheel => {
                         if (wheel.angleDelta.y > 0)
                         modelData?.scrollUp();
                         else if (wheel.angleDelta.y < 0)
                         modelData?.scrollDown();
                       }

              onEntered: TooltipService.show(trayIcon, modelData.tooltipTitle || modelData.name || modelData.id || "Tray Item", BarService.getTooltipDirection(root.screen?.name))
              onExited: TooltipService.hide()
            }
          }
        }
      }
    }
    TrayMenuPage {
      id: menuPage
      anchors.fill: parent
      visible: root.menuOpen
      trayItem: root.selectedTrayItem
      menuPath: root.menuPath
      pinned: panelContent.isPinned(root.selectedTrayItem)
      canPin: root.widgetSection !== "" && root.widgetIndex >= 0
      onBack: root.menuBack()
      onSubmenu: entry => root.menuPath = root.menuPath.concat([entry])
      onActivated: root.close()
      onPinToggled: root.togglePinned()
    }
  }
}
