import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings.Tabs
import qs.Modules.Panels.Settings.Tabs.About
import qs.Modules.Panels.Settings.Tabs.Audio
import qs.Modules.Panels.Settings.Tabs.Bar
import qs.Modules.Panels.Settings.Tabs.ColorScheme
import qs.Modules.Panels.Settings.Tabs.Connections
import qs.Modules.Panels.Settings.Tabs.ControlCenter
import qs.Modules.Panels.Settings.Tabs.Display
import qs.Modules.Panels.Settings.Tabs.Dock
import qs.Modules.Panels.Settings.Tabs.Hooks
import qs.Modules.Panels.Settings.Tabs.Hyprland
import qs.Modules.Panels.Settings.Tabs.Idle
import qs.Modules.Panels.Settings.Tabs.Launcher
import qs.Modules.Panels.Settings.Tabs.LockScreen
import qs.Modules.Panels.Settings.Tabs.Notifications
import qs.Modules.Panels.Settings.Tabs.Osd
import qs.Modules.Panels.Settings.Tabs.Plugins
import qs.Modules.Panels.Settings.Tabs.Region
import qs.Modules.Panels.Settings.Tabs.Security
import qs.Modules.Panels.Settings.Tabs.SessionMenu
import qs.Modules.Panels.Settings.Tabs.SystemMonitor
import qs.Modules.Panels.Settings.Tabs.UserInterface
import qs.Modules.Panels.Settings.Tabs.Wallpaper
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  Component.onDestruction: SystemStatService.unregisterComponent("settings")

  // Screen reference for child components
  property var screen

  // Input: which tab to show initially
  property int requestedTab: 0

  // Exposed state for parent to access
  property int currentTabIndex: 0
  property var tabsModel: []
  property var activeScrollView: null
  property var activeTabContent: null
  property bool sidebarExpanded: true
  // Track if sidebar was collapsed before searching started
  property bool wasCollapsedBeforeSearch: false

  // Search state
  property string searchText: ""
  property var searchResults: []
  property int searchSelectedIndex: 0
  property string highlightLabelKey: ""
  property bool navigatingFromSearch: false

  // Mouse hover suppression during keyboard navigation
  property bool ignoreMouseHover: false
  property real _lastMouseX: 0
  property real _lastMouseY: 0
  property bool _mouseInitialized: false

  readonly property bool sidebarCardStyle: Settings.data.ui.settingsPanelSideBarCardStyle

  onSearchResultsChanged: {
    searchSelectedIndex = 0;
    ignoreMouseHover = true;
    _mouseInitialized = false;
  }

  // Signal when close button is clicked
  signal closeRequested

  // Search function
  onSearchTextChanged: {
    if (searchText.trim() === "") {
      searchResults = [];
      if (wasCollapsedBeforeSearch) {
        root.sidebarExpanded = false;
        wasCollapsedBeforeSearch = false;
      }
      return;
    }

    // Auto-expand sidebar when searching
    if (!root.sidebarExpanded) {
      if (root.activeFocus) {
        // If we are typing and the sidebar is collapsed and focused, we assume the user is typing to search
        wasCollapsedBeforeSearch = true;
      }
      root.sidebarExpanded = true;
    }

    if (SettingsSearchService.searchIndex.length === 0)
      return;

    // Build searchable items with resolved translations, filtering out invisible entries
    let items = [];
    for (let j = 0; j < SettingsSearchService.searchIndex.length; j++) {
      const entry = SettingsSearchService.searchIndex[j];
      if (!SettingsSearchService.isEntryVisible(entry))
        continue;
      items.push({
                   "labelKey": entry.labelKey,
                   "descriptionKey": entry.descriptionKey,
                   "widget": entry.widget,
                   "tab": entry.tab,
                   "tabLabel": entry.tabLabel,
                   "subTab": entry.subTab,
                   "subTabLabel": entry.subTabLabel || null,
                   "label": I18n.tr(entry.labelKey),
                   "description": entry.descriptionKey ? I18n.tr(entry.descriptionKey) : "",
                   "subTabName": entry.subTabLabel ? I18n.tr(entry.subTabLabel) : ""
                 });
    }

    const results = FuzzySort.go(searchText.trim(), items, {
                                   "keys": ["label", "subTabName", "description"],
                                   "limit": 20,
                                   "scoreFn": function (r) {
                                     // r[0]=label, r[1]=subTabName, r[2]=description
                                     // Boost subTabName matches by 1.5x
                                     const labelScore = r[0].score;
                                     const subTabScore = r[1].score * 1.5;
                                     const descScore = r[2].score;
                                     return Math.max(labelScore, subTabScore, descScore);
                                   }
                                 });

    let extracted = [];
    for (let i = 0; i < results.length; i++) {
      extracted.push(results[i].obj);
    }
    searchResults = extracted;
  }

  // Navigate to a search result
  property int _pendingSubTab: -1

  function navigateToResult(entry) {
    if (entry.tab < 0 || entry.tab >= tabsModel.length)
      return;

    highlightLabelKey = entry.labelKey;
    _pendingSubTab = (entry.subTab !== null && entry.subTab !== undefined) ? entry.subTab : -1;

    const alreadyOnTab = (currentTabIndex === entry.tab);
    navigatingFromSearch = true;
    currentTabIndex = entry.tab;
    navigatingFromSearch = false;

    if (alreadyOnTab && activeTabContent) {
      if (_pendingSubTab >= 0) {
        navigatingFromSearch = true;
        setSubTabIndex(_pendingSubTab);
        navigatingFromSearch = false;
        _pendingSubTab = -1;
      }
      highlightScrollTimer.targetKey = highlightLabelKey;
      highlightScrollTimer.restart();
    }

    // Clear highlight after a delay
    highlightClearTimer.restart();
  }

  // Navigate to a tab and optionally a subtab (simpler than navigateToResult, no highlighting)
  function navigateToTab(tabId, subTabIndex) {
    // Find the tab index by tab ID
    let tabIndex = -1;
    for (let i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].id === tabId) {
        tabIndex = i;
        break;
      }
    }

    if (tabIndex < 0)
      return;

    const hasSubTab = subTabIndex !== null && subTabIndex !== undefined && subTabIndex >= 0;
    _pendingSubTab = hasSubTab ? subTabIndex : -1;

    // Check if we're already on this tab
    const alreadyOnTab = (currentTabIndex === tabIndex);

    currentTabIndex = tabIndex;

    if (alreadyOnTab && activeTabContent && hasSubTab) {
      // Tab is already loaded, apply subtab directly
      setSubTabIndex(subTabIndex);
      _pendingSubTab = -1;
    }
  }

  function searchSelectNext() {
    if (searchResults.length === 0)
      return;
    ignoreMouseHover = true;
    _mouseInitialized = false;
    searchSelectedIndex = Math.min(searchSelectedIndex + 1, searchResults.length - 1);
    searchResultsList.positionViewAtIndex(searchSelectedIndex, ListView.Contain);
  }

  function searchSelectPrevious() {
    if (searchResults.length === 0)
      return;
    ignoreMouseHover = true;
    _mouseInitialized = false;
    searchSelectedIndex = Math.max(searchSelectedIndex - 1, 0);
    searchResultsList.positionViewAtIndex(searchSelectedIndex, ListView.Contain);
  }

  function searchActivate() {
    if (searchSelectedIndex >= 0 && searchSelectedIndex < searchResults.length) {
      navigateToResult(searchResults[searchSelectedIndex]);
      searchInput.text = "";
    }
  }

  // Set sub-tab on the currently loaded tab content. Returns true if an NTabBar was found.
  function setSubTabIndex(subTabIndex) {
    if (activeTabContent) {
      return setSubTabRecursive(activeTabContent, subTabIndex);
    }
    return false;
  }

  function setSubTabRecursive(item, subTabIndex) {
    if (!item)
      return false;

    if (item.objectName === "NTabBar") {
      // Prepare the sibling NTabView so the index change doesn't animate
      if (item.parent) {
        for (let j = 0; j < item.parent.children.length; j++) {
          const sibling = item.parent.children[j];
          if (sibling.objectName === "NTabView" && sibling.setIndexWithoutAnimation) {
            sibling.setIndexWithoutAnimation(subTabIndex);
            break;
          }
        }
      }
      item.currentIndex = subTabIndex;
      return true;
    }

    const childCount = item.children ? item.children.length : 0;
    for (let i = 0; i < childCount; i++) {
      if (setSubTabRecursive(item.children[i], subTabIndex))
        return true;
    }
    return false;
  }

  onCurrentTabIndexChanged: {
    if (!navigatingFromSearch) {
      clearHighlightImmediately();
    }
  }

  property var currentSubTabBar: null

  onActiveTabContentChanged: {
    if (currentSubTabBar) {
      try {
        currentSubTabBar.currentIndexChanged.disconnect(onSubTabChanged);
      } catch (e) {}
      currentSubTabBar = null;
    }

    if (activeTabContent) {
      const tabBar = findNTabBar(activeTabContent);
      if (tabBar) {
        currentSubTabBar = tabBar;
        currentSubTabBar.currentIndexChanged.connect(onSubTabChanged);
      }
    }
  }

  function onSubTabChanged() {
    if (!navigatingFromSearch) {
      clearHighlightImmediately();
    }
  }

  function findNTabBar(item) {
    if (!item)
      return null;

    if (item.objectName === "NTabBar") {
      return item;
    }

    const childCount = item.children ? item.children.length : 0;
    for (let i = 0; i < childCount; i++) {
      const found = findNTabBar(item.children[i]);
      if (found)
        return found;
    }
    return null;
  }

  function clearHighlightImmediately() {
    highlightClearTimer.stop();
    highlightScrollTimer.stop();
    highlightAnimation.stop();
    highlightLabelKey = "";
    highlightOverlay.opacity = 0;
  }

  function isEffectivelyVisible(item) {
    var current = item;
    while (current) {
      if (current.visible === false)
        return false;
      if (current.opacity !== undefined && current.opacity <= 0)
        return false;
      current = current.parent;
    }
    return true;
  }

  // Find and highlight a widget by its label key.
  function findAndHighlightWidget(item, labelKey) {
    if (!item)
      return null;

    // Skip hidden branches to avoid highlighting controls that are not on screen.
    if (!isEffectivelyVisible(item))
      return null;

    // Check if this item has a matching label.
    if (item.hasOwnProperty("label") && item.label === I18n.tr(labelKey) && item.width > 0 && item.height > 0) {
      return item;
    }

    // Recursively search children
    if (item.children) {
      for (let i = 0; i < item.children.length; i++) {
        const found = findAndHighlightWidget(item.children[i], labelKey);
        if (found)
          return found;
      }
    }
    return null;
  }

  Timer {
    id: highlightClearTimer
    interval: 3000
    onTriggered: root.highlightLabelKey = ""
  }

  Timer {
    id: highlightScrollTimer
    interval: 333
    property string targetKey: ""
    onTriggered: {
      if (root.activeTabContent && targetKey) {
        const widget = root.findAndHighlightWidget(root.activeTabContent, targetKey);
        if (widget && root.activeScrollView) {
          // Scroll widget into view using the Flickable directly
          const flickable = root.activeScrollView.contentItem;
          const mapped = widget.mapToItem(flickable.contentItem, 0, 0);
          const targetY = mapped.y - flickable.height / 3;
          flickable.contentY = Math.max(0, Math.min(targetY, flickable.contentHeight - flickable.height));

          // Position highlight overlay after scroll layout has settled
          Qt.callLater(function () {
            const overlayPos = widget.mapToItem(tabContentArea, 0, 0);
            highlightOverlay.x = overlayPos.x - Style.marginM;
            highlightOverlay.y = overlayPos.y - Style.marginM;
            highlightOverlay.width = widget.width + Style.margin2M;
            highlightOverlay.height = widget.height + Style.margin2M;
            highlightAnimation.restart();
          });
        }
      }
      targetKey = "";
    }
  }

  // Clear highlight when the user scrolls so the outline doesn't stay in place
  Connections {
    target: root.activeScrollView ? root.activeScrollView.contentItem : null
    enabled: root.highlightLabelKey !== "" && !highlightScrollTimer.running
    function onContentYChanged() {
      root.clearHighlightImmediately();
    }
  }

  // Save sidebar state when it changes
  onSidebarExpandedChanged: {
    ShellState.setSettingsSidebarExpanded(sidebarExpanded);
    if (!sidebarExpanded) {
      root.searchText = "";
      searchInput.text = "";
      root.forceActiveFocus();
    }
  }

  Component.onCompleted: {
    SystemStatService.registerComponent("settings");
    // Restore sidebar state
    sidebarExpanded = ShellState.getSettingsSidebarExpanded();
  }

  // Tab components
  Component {
    id: generalTab
    GeneralTab {}
  }
  Component {
    id: launcherTab
    LauncherTab {}
  }
  Component {
    id: barTab
    BarTab {}
  }
  Component {
    id: audioTab
    AudioTab {}
  }
  Component {
    id: displayTab
    DisplayTab {}
  }
  Component {
    id: osdTab
    OsdTab {}
  }
  Component {
    id: connectionsTab
    ConnectionsTab {}
  }
  Component {
    id: regionTab
    RegionTab {}
  }
  Component {
    id: colorSchemeTab
    ColorSchemeTab {}
  }
  Component {
    id: wallpaperTab
    WallpaperTab {}
  }
  Component {
    id: aboutTab
    AboutTab {}
  }
  Component {
    id: hooksTab
    HooksTab {}
  }
  Component {
    id: idleTab
    IdleTab {}
  }
  Component {
    id: dockTab
    DockTab {}
  }
  Component {
    id: notificationsTab
    NotificationsTab {}
  }
  Component {
    id: controlCenterTab
    ControlCenterTab {}
  }
  Component {
    id: userInterfaceTab
    UserInterfaceTab {}
  }
  Component {
    id: lockScreenTab
    LockScreenTab {}
  }
  Component {
    id: sessionMenuTab
    SessionMenuTab {}
  }
  Component {
    id: systemMonitorTab
    SystemMonitorTab {}
  }
  Component {
    id: pluginsTab
    PluginsTab {}
  }
  Component {
    id: desktopWidgetsTab
    DesktopWidgetsTab {}
  }
  Component {
    id: securityTab
    SecurityTab {}
  }
  Component {
    id: hyprlandTab
    HyprlandTab {}
  }

  function updateTabsModel() {
    let newTabs = [
          {
            "id": SettingsPanel.Tab.General,
            "label": "common.general",
            "icon": "settings-general",
            "source": generalTab
          },
          {
            "id": SettingsPanel.Tab.UserInterface,
            "label": "panels.user-interface.title",
            "icon": "settings-user-interface",
            "source": userInterfaceTab
          },
          {
            "id": SettingsPanel.Tab.ColorScheme,
            "label": "panels.color-scheme.title",
            "icon": "settings-color-scheme",
            "source": colorSchemeTab
          },
          {
            "id": SettingsPanel.Tab.Wallpaper,
            "label": "common.wallpaper",
            "icon": "settings-wallpaper",
            "source": wallpaperTab
          },
          {
            "id": SettingsPanel.Tab.Bar,
            "label": "panels.bar.title",
            "icon": "settings-bar",
            "source": barTab
          },
          {
            "id": SettingsPanel.Tab.Dock,
            "label": "panels.dock.title",
            "icon": "settings-dock",
            "source": dockTab
          },
          {
            "id": SettingsPanel.Tab.DesktopWidgets,
            "label": "panels.desktop-widgets.title",
            "icon": "clock",
            "source": desktopWidgetsTab
          },
          {
            "id": SettingsPanel.Tab.ControlCenter,
            "label": "panels.control-center.title",
            "icon": "settings-control-center",
            "source": controlCenterTab
          },
          {
            "id": SettingsPanel.Tab.Security,
            "label": "panels.security.title",
            "icon": "shield-lock",
            "source": securityTab
          },
          {
            "id": SettingsPanel.Tab.Launcher,
            "label": "panels.launcher.title",
            "icon": "settings-launcher",
            "source": launcherTab
          },
          {
            "id": SettingsPanel.Tab.Notifications,
            "label": "common.notifications",
            "icon": "settings-notifications",
            "source": notificationsTab
          },
          {
            "id": SettingsPanel.Tab.OSD,
            "label": "panels.osd.title",
            "icon": "settings-osd",
            "source": osdTab
          },
          {
            "id": SettingsPanel.Tab.LockScreen,
            "label": "panels.lock-screen.title",
            "icon": "settings-lock-screen",
            "source": lockScreenTab
          },
          {
            "id": SettingsPanel.Tab.SessionMenu,
            "label": "session-menu.title",
            "icon": "settings-session-menu",
            "source": sessionMenuTab
          },
          {
            "id": SettingsPanel.Tab.Idle,
            "label": "panels.idle.title",
            "icon": "settings-idle",
            "source": idleTab
          },
          {
            "id": SettingsPanel.Tab.Audio,
            "label": "panels.audio.title",
            "icon": "settings-audio",
            "source": audioTab
          },
          {
            "id": SettingsPanel.Tab.Display,
            "label": "panels.display.title",
            "icon": "settings-display",
            "source": displayTab
          },
          {
            "id": SettingsPanel.Tab.Connections,
            "label": "panels.connections.title",
            "icon": "settings-network",
            "source": connectionsTab
          },
          {
            "id": SettingsPanel.Tab.Location,
            "label": "panels.region.title",
            "icon": "settings-location",
            "source": regionTab
          },
          {
            "id": SettingsPanel.Tab.System,
            "label": "panels.system.title",
            "icon": "settings-system-monitor",
            "source": systemMonitorTab
          },
          {
            "id": SettingsPanel.Tab.Plugins,
            "label": "panels.plugins.title",
            "icon": "plugin",
            "source": pluginsTab
          },
          {
            "id": SettingsPanel.Tab.Hooks,
            "label": "panels.hooks.title",
            "icon": "settings-hooks",
            "source": hooksTab
          },
          {
            "id": SettingsPanel.Tab.Hyprland,
            "label": "panels.hyprland.title",
            "icon": "keyboard",
            "source": hyprlandTab
          },
          {
            "id": SettingsPanel.Tab.About,
            "label": "panels.about.title",
            "icon": "settings-about",
            "source": aboutTab
          }
        ];

    // Hyprland tab only makes sense with Hyprland as the active compositor
    // (PLANO_INTEGRACAO_HYPRMOD.md §5) — every other tab is compositor-
    // agnostic and always shown.
    newTabs = newTabs.filter(t => t.id !== SettingsPanel.Tab.Hyprland || CompositorService.isHyprland);

    root.tabsModel = newTabs;
  }

  function selectTabById(tabId) {
    for (var i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].id === tabId) {
        currentTabIndex = i;
        return;
      }
    }
    currentTabIndex = 0;
  }

  function initialize() {
    ProgramCheckerService.checkAllPrograms();
    // Guard _pendingSubTab during model rebuild: updateTabsModel() triggers
    // a ListView model reset which can set currentTabIndex=0 via the sidebar
    // sync handler, causing the wrong tab to load and consume _pendingSubTab.
    const savedPendingSubTab = _pendingSubTab;
    _pendingSubTab = -1;
    updateTabsModel();
    _pendingSubTab = savedPendingSubTab;
    selectTabById(requestedTab);
    // Skip auto-focus on Nvidia GPUs - cursor blink causes UI choppiness
    const isNvidia = SystemStatService.gpuType === "nvidia";
    if (sidebarExpanded && !isNvidia) {
      Qt.callLater(() => {
                     if (searchInput.inputItem)
                     searchInput.inputItem.forceActiveFocus();
                   });
    } else {
      // Ensure root has focus so it can catch typing
      Qt.callLater(() => root.forceActiveFocus());
    }
  }

  // Handle typing when sidebar is collapsed
  focus: true
  Keys.onPressed: event => {
                    if (!sidebarExpanded && event.text.length > 0 && event.text.trim() !== "") {
                      // Only capture if it looks like visible text
                      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                      return;

                      // Explicitly ignore backspace and similar keys that might have text but shouldn't trigger search
                      if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete || event.key === Qt.Key_Escape)
                      return;

                      wasCollapsedBeforeSearch = true;
                      sidebarExpanded = true;
                      searchInput.text = event.text;
                      Qt.callLater(() => {
                                     if (searchInput.inputItem) {
                                       searchInput.inputItem.forceActiveFocus();
                                       // Cursor moves to end automatically usually, but let's be safe
                                       searchInput.inputItem.cursorPosition = 1;
                                     }
                                   });
                      event.accepted = true;
                    }
                  }

  // Scroll functions
  function scrollDown() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const stepSize = activeScrollView.height * 0.1;
      scrollBar.position = Math.min(scrollBar.position + stepSize / activeScrollView.contentHeight, 1.0 - scrollBar.size);
    }
  }

  function scrollUp() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const stepSize = activeScrollView.height * 0.1;
      scrollBar.position = Math.max(scrollBar.position - stepSize / activeScrollView.contentHeight, 0);
    }
  }

  function scrollPageDown() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const pageSize = activeScrollView.height * 0.9;
      scrollBar.position = Math.min(scrollBar.position + pageSize / activeScrollView.contentHeight, 1.0 - scrollBar.size);
    }
  }

  function scrollPageUp() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const pageSize = activeScrollView.height * 0.9;
      scrollBar.position = Math.max(scrollBar.position - pageSize / activeScrollView.contentHeight, 0);
    }
  }

  // Tab navigation functions
  function selectNextTab() {
    if (tabsModel.length > 0) {
      currentTabIndex = (currentTabIndex + 1) % tabsModel.length;
    }
  }

  function selectPreviousTab() {
    if (tabsModel.length > 0) {
      currentTabIndex = (currentTabIndex - 1 + tabsModel.length) % tabsModel.length;
    }
  }

  // Main UI
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.paddingCard
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.spaceS

      // Sidebar
      NBox {
        id: sidebar

        clip: true
        Layout.preferredWidth: Math.round(root.sidebarExpanded ? 212 * Style.uiScaleRatio : sidebarToggle.width + (root.sidebarCardStyle ? Style.margin2M : 0) + (sidebarList.verticalScrollBarActive ? Style.marginM : 0))
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop

        radius: root.sidebarCardStyle ? Style.radiusCard : 0
        color: root.sidebarCardStyle ? Color.mSurfaceContainerLow : "transparent"
        border.color: "transparent"

        Behavior on Layout.preferredWidth {
          NAnim {
            motionType: NAnim.ExpressiveDefaultSpatial
          }
        }

        // Sidebar content
        ColumnLayout {
          anchors.fill: parent
          spacing: Style.spaceS
          anchors.margins: root.sidebarCardStyle ? Style.paddingCard : 0

          // Sidebar toggle button
          NIconButton {
            id: sidebarToggle
            icon: root.sidebarExpanded ? "layout-sidebar-right-expand" : "layout-sidebar-left-expand"
            tooltipText: root.sidebarExpanded ? I18n.tr("tooltips.collapse") : I18n.tr("tooltips.expand")
            colorBg: "transparent"
            colorBgHover: Color.mSecondaryContainer
            colorFg: Color.mOnSurfaceVariant
            colorFgHover: Color.mOnSecondaryContainer
            colorBorder: "transparent"
            colorBorderHover: "transparent"
            customRadius: Style.radiusControl
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignLeft
            onClicked: root.sidebarExpanded = !root.sidebarExpanded
          }

          // Search container wrapper to prevent layout jumps
          Item {
            id: searchContainerWrapper
            Layout.fillWidth: true
            Layout.preferredHeight: searchInput.implicitHeight > 0 ? searchInput.implicitHeight : (Style.fontSizeXL + Style.margin2M)

            // Search input
            NTextInput {
              id: searchInput
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: I18n.tr("common.search")
              inputIconName: "search"
              radius: Style.radiusCapsule
              visible: opacity > 0
              opacity: root.sidebarExpanded ? 1.0 : 0.0

              Behavior on opacity {
                NAnim {
                  motionType: NAnim.StandardEffects
                }
              }

              onTextChanged: root.searchText = text
              onEditingFinished: {
                if (root.searchText.trim() !== "")
                  root.searchActivate();
              }
            }

            // Search button for collapsed sidebar
            NIconButton {
              id: searchCollapsedButton
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              visible: opacity > 0
              opacity: root.sidebarExpanded ? 0.0 : 1.0
              icon: "search"
              tooltipText: I18n.tr("common.search")
              colorBg: "transparent"
              colorBgHover: Color.mSecondaryContainer
              colorFg: Color.mOnSurfaceVariant
              colorFgHover: Color.mOnSecondaryContainer
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              customRadius: Style.radiusControl
              width: 36
              height: 36

              Behavior on opacity {
                NAnim {
                  motionType: NAnim.StandardEffects
                }
              }

              onClicked: {
                root.sidebarExpanded = true;
                root.wasCollapsedBeforeSearch = false;
                Qt.callLater(() => searchInput.inputItem.forceActiveFocus());
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: Style.marginXL

            // Search results list
            NListView {
              id: searchResultsList
              anchors.fill: parent
              model: root.searchResults
              spacing: Style.spaceXS
              visible: root.searchText.trim() !== ""
              verticalPolicy: ScrollBar.AsNeeded
              gradientColor: "transparent"
              reserveScrollbarSpace: false

              HoverHandler {
                onPointChanged: {
                  if (!root._mouseInitialized) {
                    root._lastMouseX = point.position.x;
                    root._lastMouseY = point.position.y;
                    root._mouseInitialized = true;
                    return;
                  }

                  const deltaX = Math.abs(point.position.x - root._lastMouseX);
                  const deltaY = Math.abs(point.position.y - root._lastMouseY);
                  if (deltaX + deltaY >= 5) {
                    root.ignoreMouseHover = false;
                    root._lastMouseX = point.position.x;
                    root._lastMouseY = point.position.y;
                  }
                }
              }

              delegate: Rectangle {
                id: resultItem
                width: searchResultsList.width - (searchResultsList.verticalScrollBarActive ? Style.marginM : 0)
                height: resultColumn.implicitHeight + Style.margin2M
                radius: Style.radiusControl
                readonly property bool selected: index === root.searchSelectedIndex
                readonly property bool effectiveHover: !root.ignoreMouseHover && resultMouseArea.containsMouse
                color: selected ? Color.mSecondaryContainer : "transparent"

                NStateLayer {
                  id: resultStateLayer
                  anchors.fill: parent
                  hovered: resultItem.effectiveHover
                  pressed: resultMouseArea.pressed
                  radius: resultItem.radius
                  stateColor: resultItem.selected ? Color.mOnSecondaryContainer : Color.mOnSurface
                }

                ColumnLayout {
                  id: resultColumn
                  anchors.fill: parent
                  anchors.leftMargin: Style.paddingControl
                  anchors.rightMargin: Style.paddingControl
                  anchors.topMargin: Style.spaceS
                  anchors.bottomMargin: Style.spaceS
                  spacing: Style.spaceXS

                  NText {
                    text: I18n.tr(modelData.labelKey)
                    pointSize: Style.fontSizeBodySmall
                    font.weight: Style.fontWeightSemiBold
                    color: resultItem.selected ? Color.mOnSecondaryContainer : Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }

                  NText {
                    text: {
                      let t = I18n.tr(modelData.tabLabel);
                      if (modelData.subTabLabel)
                        t += " › " + I18n.tr(modelData.subTabLabel);
                      return t;
                    }
                    pointSize: Style.fontSizeLabelSmall
                    color: resultItem.selected ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }
                }

                MouseArea {
                  id: resultMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: mouse => resultStateLayer.rippleAt(mouse.x, mouse.y)
                  onEntered: {
                    if (!root.ignoreMouseHover)
                      root.searchSelectedIndex = index;
                  }
                  onClicked: {
                    root.searchSelectedIndex = index;
                    root.navigateToResult(modelData);
                    searchInput.text = "";
                  }
                }
              }
            }

            // Tab list
            NListView {
              id: sidebarList
              visible: root.searchText.trim() === ""
              anchors.fill: parent
              model: root.tabsModel
              spacing: Style.spaceXS
              currentIndex: root.currentTabIndex
              horizontalPolicy: ScrollBar.AlwaysOff
              verticalPolicy: ScrollBar.AlwaysOff
              gradientColor: "transparent"
              reserveScrollbarSpace: false

              delegate: Rectangle {
                id: tabItem
                width: sidebarList.width
                height: Math.max(Style.baseWidgetSize, tabEntryRow.implicitHeight + Style.spaceS)
                radius: Style.radiusControl
                color: selected ? Color.mSecondaryContainer : "transparent"
                border.color: "transparent"
                border.width: 0
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: I18n.tr(modelData.label)
                Accessible.selected: selected
                readonly property bool selected: index === root.currentTabIndex
                property bool hovering: false
                property color tabTextColor: selected ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant

                Behavior on tabTextColor {
                  enabled: !Color.isTransitioning
                  NColorAnimation {
                    motionType: NColorAnimation.Standard
                  }
                }

                NStateLayer {
                  id: tabStateLayer
                  anchors.fill: parent
                  hovered: tabItem.hovering
                  pressed: tabMouseArea.pressed
                  focused: tabItem.activeFocus
                  radius: tabItem.radius
                  stateColor: tabItem.selected ? Color.mOnSecondaryContainer : Color.mOnSurface
                }

                RowLayout {
                  id: tabEntryRow
                  anchors.fill: parent
                  anchors.leftMargin: Style.paddingControl
                  anchors.rightMargin: Style.paddingControl
                  spacing: Style.spaceS

                  NIcon {
                    icon: modelData.icon
                    color: tabTextColor
                    pointSize: Style.fontSizeBodyLarge
                    Layout.alignment: Qt.AlignVCenter
                  }

                  NText {
                    text: I18n.tr(modelData.label)
                    color: tabTextColor
                    pointSize: Style.fontSizeBodySmall
                    font.weight: Style.fontWeightSemiBold
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.sidebarExpanded
                    opacity: root.sidebarExpanded ? 1.0 : 0.0

                    Behavior on opacity {
                      NAnim {
                        motionType: NAnim.StandardEffects
                      }
                    }
                  }
                }

                NFocusRing {
                  focusVisible: tabItem.activeFocus
                  targetRadius: tabItem.radius
                }

                MouseArea {
                  id: tabMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton
                  cursorShape: Qt.PointingHandCursor
                  onPressed: mouse => tabStateLayer.rippleAt(mouse.x, mouse.y)
                  onEntered: {
                    tabItem.hovering = true;
                    // Show tooltip when sidebar is collapsed
                    if (!root.sidebarExpanded) {
                      TooltipService.show(tabItem, I18n.tr(modelData.label));
                    }
                  }
                  onExited: {
                    tabItem.hovering = false;
                    // Hide tooltip when sidebar is collapsed
                    if (!root.sidebarExpanded) {
                      TooltipService.hide();
                    }
                  }
                  onCanceled: {
                    tabItem.hovering = false;
                    if (!root.sidebarExpanded) {
                      TooltipService.hide();
                    }
                  }
                  onClicked: {
                    tabItem.forceActiveFocus();
                    root.currentTabIndex = index;
                    // Hide tooltip on click
                    if (!root.sidebarExpanded) {
                      TooltipService.hide();
                    }
                  }
                }

                Keys.onReturnPressed: event => {
                                        root.currentTabIndex = index;
                                        event.accepted = true;
                                      }
                Keys.onSpacePressed: event => {
                                       root.currentTabIndex = index;
                                       event.accepted = true;
                                     }
              }

              onCurrentIndexChanged: {
                if (currentIndex !== root.currentTabIndex) {
                  root.currentTabIndex = currentIndex;
                }
              }

              Connections {
                target: root
                function onCurrentTabIndexChanged() {
                  if (sidebarList.currentIndex !== root.currentTabIndex) {
                    sidebarList.currentIndex = root.currentTabIndex;
                    sidebarList.positionViewAtIndex(root.currentTabIndex, ListView.Contain);
                  }
                }
              }
            }
          }
        }
      }

      // Content pane
      NBox {
        id: contentPane
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        radius: Style.radiusCard
        color: Color.mSurfaceContainerLow
        border.color: "transparent"

        ColumnLayout {
          id: contentLayout
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.margins: Style.paddingCard
          // Keep long settings copy readable in spacious window mode.
          width: Math.min(parent.width - Style.paddingCard * 2, 1040 * Style.uiScaleRatio)
          spacing: Style.spaceS

          // Header row
          RowLayout {
            id: headerRow
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(48 * Style.uiScaleRatio)
            spacing: Style.spaceS

            NIcon {
              icon: root.tabsModel[currentTabIndex]?.icon ?? ""
              color: Color.mPrimary
              pointSize: Style.fontSizeHeadlineSmall
            }

            NText {
              text: root.tabsModel[root.currentTabIndex]?.label ? I18n.tr(root.tabsModel[root.currentTabIndex].label) : ""
              pointSize: Style.fontSizeTitleLarge
              font.weight: Style.fontWeightSemiBold
              color: Color.mOnSurface
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("common.close")
              Layout.alignment: Qt.AlignVCenter
              colorBg: Color.mSurfaceContainerHigh
              colorBgHover: Color.mSecondaryContainer
              colorFg: Color.mOnSurfaceVariant
              colorFgHover: Color.mOnSecondaryContainer
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: root.closeRequested()
            }
          }

          // Tab content area
          Rectangle {
            id: tabContentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: -Style.spaceS
            Layout.rightMargin: -Style.paddingCard
            color: "transparent"

            Repeater {
              id: contentRepeater
              model: root.tabsModel
              delegate: Loader {
                anchors.fill: parent
                active: index === root.currentTabIndex
                opacity: 0

                NAnim on opacity {
                  id: fadeInAnim
                  from: 0
                  to: 1
                  motionType: NAnim.StandardEffects
                  running: false
                }

                onStatusChanged: {
                  if (status === Loader.Ready && item) {
                    fadeInAnim.start();
                    const scrollView = item.children[0];
                    if (scrollView && scrollView.toString().includes("ScrollView")) {
                      root.activeScrollView = scrollView;
                    }
                  }
                }

                sourceComponent: NScrollView {
                  id: scrollView
                  anchors.fill: parent
                  horizontalPolicy: ScrollBar.AlwaysOff
                  verticalPolicy: ScrollBar.AsNeeded
                  leftPadding: Style.paddingCard
                  topPadding: Style.paddingCard
                  bottomPadding: Style.paddingCard
                  userRightPadding: Style.paddingCard
                  reserveScrollbarSpace: false

                  Component.onCompleted: {
                    root.activeScrollView = scrollView;
                  }

                  Loader {
                    active: true
                    sourceComponent: root.tabsModel[index]?.source
                    width: scrollView.availableWidth
                    onLoaded: {
                      if (item && item.hasOwnProperty("screen")) {
                        item.screen = root.screen;
                      }
                      root.activeTabContent = item;
                      if (root._pendingSubTab >= 0) {
                        root.navigatingFromSearch = true;
                        if (root.setSubTabIndex(root._pendingSubTab))
                          root._pendingSubTab = -1;
                        root.navigatingFromSearch = false;
                      }
                      if (root.highlightLabelKey) {
                        highlightScrollTimer.targetKey = root.highlightLabelKey;
                        highlightScrollTimer.restart();
                      }
                    }
                  }
                }
              }
            }

            // Highlight overlay for search results
            Rectangle {
              id: highlightOverlay
              visible: opacity > 0
              opacity: 0
              color: Qt.alpha(Color.mSecondaryContainer, 0.72)
              border.color: Color.mSecondary
              border.width: Style.borderM
              radius: Style.radiusControl
              z: 100

              SequentialAnimation {
                id: highlightAnimation

                NAnim {
                  target: highlightOverlay
                  property: "opacity"
                  to: 1.0
                  motionType: NAnim.StandardEffects
                }

                PauseAnimation {
                  duration: 2000
                }

                NAnim {
                  target: highlightOverlay
                  property: "opacity"
                  to: 0
                  motionType: NAnim.StandardEffects
                }
              }
            }
          }
        }
      }
    }
  }
}
