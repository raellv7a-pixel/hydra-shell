import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "Helpers/LauncherNavigation.js" as LauncherNav

import "Providers"
import qs.Commons
import qs.Services.Keyboard
import qs.Services.UI
import qs.Widgets

// Core launcher logic and UI - shared between SmartPanel (Launcher.qml) and overlay (LauncherOverlayWindow.qml)
Rectangle {
  id: root
  color: "transparent"

  // External interface - set by parent
  property var screen: null
  property bool isOpen: false
  signal requestClose
  signal requestCloseImmediately

  function closeImmediately() {
    requestCloseImmediately();
  }

  // Expose for preview panel positioning
  readonly property var resultsView: resultsSwapView.item

  // State
  property string searchText: ""
  property int selectedIndex: 0
  property var results: []
  property var providers: []
  property var activeProvider: null
  property bool resultsReady: false
  property var pluginProviderInstances: ({})
  property var propertiesApp: null
  // Inline app actions panel (right-click / Menu key on a result)
  property var appPanelItem: null
  property var appPanelActions: []
  property bool appPanelShowingProperties: false
  property int appPanelActionIndex: -1
  property int appPanelConfirmIndex: -1
  readonly property bool appPanelOpen: appPanelItem !== null
  // Resolved once here instead of once per row delegate: every row needs to know
  // whether the open panel belongs to it, and results can hold hundreds of items.
  readonly property int appPanelIndex: appPanelItem ? results.indexOf(appPanelItem) : -1
  property bool ignoreMouseHover: true // Transient flag, should always be true on init

  // Global mouse tracking for movement detection across delegates
  property real globalLastMouseX: 0
  property real globalLastMouseY: 0
  property bool globalMouseInitialized: false
  property bool mouseTrackingReady: false // Delay tracking until panel is settled

  readonly property bool animationsDisabled: Settings.data.general.animationDisabled

  Timer {
    id: mouseTrackingDelayTimer
    interval: root.animationsDisabled ? 0 : (Style.animationNormal + 50) // Wait for panel animation to complete + safety margin
    repeat: false
    onTriggered: {
      root.mouseTrackingReady = true;
      root.globalMouseInitialized = false; // Reset so we get fresh initial position
    }
  }

  readonly property var defaultProvider: appsProvider
  readonly property var currentProvider: activeProvider || defaultProvider

  readonly property string launcherDensity: (currentProvider && currentProvider.ignoreDensity === false) ? (Settings.data.appLauncher.density || "default") : "comfortable"
  readonly property int effectiveIconSize: launcherDensity === "comfortable" ? 48 : (launcherDensity === "default" ? 36 : 24)
  readonly property int badgeSize: Math.round(effectiveIconSize * Style.uiScaleRatio)
  readonly property int entryHeight: Math.round(badgeSize + (launcherDensity === "compact" ? Style.margin2XS : Style.margin2M))

  readonly property bool providerShowsCategories: (currentProvider.showsCategories !== undefined ? currentProvider.showsCategories : true) && providerCategories.length > 0

  readonly property var providerCategories: {
    if (currentProvider.availableCategories && currentProvider.availableCategories.length > 0) {
      return currentProvider.availableCategories;
    }
    return currentProvider.categories || [];
  }

  readonly property bool showProviderCategories: {
    if (!providerShowsCategories || providerCategories.length === 0)
      return false;
    if (currentProvider === defaultProvider)
      return Settings.data.appLauncher.showCategories;
    return true;
  }

  readonly property bool providerHasDisplayString: results.length > 0 && !!results[0].displayString

  readonly property string providerSupportedLayouts: {
    if (activeProvider && activeProvider.supportedLayouts)
      return activeProvider.supportedLayouts;
    if (results.length > 0 && results[0].provider && results[0].provider.supportedLayouts)
      return results[0].provider.supportedLayouts;
    if (defaultProvider && defaultProvider.supportedLayouts)
      return defaultProvider.supportedLayouts;
    return "both";
  }

  readonly property bool showLayoutToggle: !providerHasDisplayString && providerSupportedLayouts === "both"

  readonly property string layoutMode: {
    if (searchText === ">")
      return "list";
    if (providerSupportedLayouts === "grid")
      return "grid";
    if (providerSupportedLayouts === "list")
      return "list";
    if (providerSupportedLayouts === "single")
      return "single";
    if (providerHasDisplayString)
      return "grid";
    return Settings.data.appLauncher.viewMode;
  }

  readonly property bool isGridView: layoutMode === "grid"
  readonly property bool isColumnsView: layoutMode === "columns"
  readonly property bool isSingleView: layoutMode === "single"
  readonly property bool isCompactDensity: launcherDensity === "compact"

  property string randomCoverPath: ""
  readonly property string coverMode: Settings.data.appLauncher.coverMode || "auto"
  readonly property bool hasCoverBanner: coverMode !== "none"
  readonly property int coverBannerHeight: hasCoverBanner ? Math.round((Settings.data.appLauncher.coverHeight || 160) * Style.uiScaleRatio) : 0

  readonly property string profileWallpaperPath: {
    if (coverMode === "none") return "";
    if (coverMode === "custom") return Settings.data.appLauncher.coverPath !== "" ? Settings.preprocessPath(Settings.data.appLauncher.coverPath) : "";
    if (coverMode === "random") return randomCoverPath !== "" ? Settings.preprocessPath(randomCoverPath) : "";
    // "auto" mode — use the current wallpaper
    var wp = WallpaperService.getWallpaper(screen?.name ?? "");
    if (wp && !WallpaperService.isSolidColorPath(wp)) return wp;
    return WallpaperService.defaultWallpaper || "";
  }

  Process {
    id: randomCoverProcess
    stdout: StdioCollector {}
    onExited: code => {
      if (code === 0) {
        root.randomCoverPath = String(stdout.text || "").trim();
      } else {
        root.randomCoverPath = "";
      }
    }
  }

  function pickRandomCover() {
    if (coverMode !== "random" || !Settings.data.appLauncher.coverFolder) {
      root.randomCoverPath = "";
      return;
    }
    randomCoverProcess.exec({
      command: ["bash", "-c", "dir=$1; find \"$dir\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | shuf -n 1", "raell-launcher", Settings.preprocessPath(Settings.data.appLauncher.coverFolder)]
    });
  }

  readonly property int targetGridColumns: {
    if (isColumnsView)
      return 2;
    let base = 5;
    if (launcherDensity === "comfortable")
      base = 4;
    else if (launcherDensity === "compact")
      base = 6;

    if (!activeProvider || activeProvider === defaultProvider)
      return base;

    if (activeProvider.preferredGridColumns) {
      let multiplier = base / 5.0;
      return Math.max(1, Math.round(activeProvider.preferredGridColumns * multiplier));
    }

    return base;
  }
  readonly property int listPanelWidth: Math.round(500 * Style.uiScaleRatio)
  readonly property int gridContentWidth: listPanelWidth - Style.margin2XS
  readonly property int gridCellSize: Math.floor((gridContentWidth - ((targetGridColumns - 1) * Style.marginS)) / targetGridColumns)

  readonly property int gridColumns: targetGridColumns

  // Columns per row in the unified rows view, per layout mode.
  readonly property int rowColumns: isGridView ? Math.max(1, gridColumns) : (isColumnsView ? 2 : 1)

  // Check if current provider allows wrap navigation (default true)
  readonly property bool allowWrapNavigation: {
    var provider = activeProvider || currentProvider;
    return provider && provider.wrapNavigation !== undefined ? provider.wrapNavigation : true;
  }

  // Listen for plugin provider registry changes
  Connections {
    target: LauncherProviderRegistry
    function onPluginProviderRegistryUpdated() {
      root.syncPluginProviders();
    }
  }

  // Lifecycle
  onIsOpenChanged: {
    if (isOpen) {
      onOpened();
    } else {
      onClosed();
    }
  }

  onSearchTextChanged: {
    if (isOpen) {
      // Typing is a new intent: drop the panel instead of dragging it along.
      closeAppPanel();
      updateResults();
    }
  }

  function onOpened() {
    ignoreMouseHover = true;
    globalMouseInitialized = false;
    mouseTrackingReady = false;
    mouseTrackingDelayTimer.restart();
    pickRandomCover();
    // Show launcher immediately, results will populate asynchronously
    resultsReady = true;
    focusSearchInput();

    Qt.callLater(() => {
                   syncPluginProviders();
                   for (let provider of providers) {
                     if (provider.onOpened)
                     provider.onOpened();
                   }
                   updateResults();
                 });
  }

  function onClosed() {
    searchText = "";
    closeAppPanel();
    ignoreMouseHover = true;
    if (resultsSwapView)
      resultsSwapView.resetVisuals();
    for (let provider of providers) {
      if (provider.onClosed)
        provider.onClosed();
    }
  }

  function close() {
    requestClose();
  }

  function openAppPanel(item) {
    if (!item)
      return;

    const provider = item.provider || currentProvider;
    if (!provider || !provider.getContextMenuActions)
      return;

    const index = results.indexOf(item);
    selectedIndex = index >= 0 ? index : 0;
    appPanelItem = item;
    appPanelActions = provider.getContextMenuActions(item);
    appPanelShowingProperties = false;
    appPanelActionIndex = -1;
    appPanelConfirmIndex = -1;
    propertiesApp = null;
    Logger.d("Launcher", `App panel: ${item.name || "unknown"} (${appPanelActions.length} actions)`);
    ignoreMouseHover = true;
  }

  function toggleAppPanel(item) {
    if (appPanelItem === item)
      closeAppPanel();
    else
      openAppPanel(item);
  }

  // Opens the panel for whatever result is currently selected (keyboard path).
  function openAppPanelForSelection() {
    if (selectedIndex >= 0 && results && results[selectedIndex])
      openAppPanel(results[selectedIndex]);
  }

  function closeAppPanel() {
    appPanelItem = null;
    appPanelActions = [];
    appPanelShowingProperties = false;
    appPanelActionIndex = -1;
    appPanelConfirmIndex = -1;
    propertiesApp = null;
    ignoreMouseHover = false;
    globalMouseInitialized = false;
  }

  // Rebuilds the action list in place so labels and busy/enabled states follow
  // the provider without collapsing the panel.
  function refreshAppPanelActions() {
    if (!appPanelItem)
      return;
    const provider = appPanelItem.provider || currentProvider;
    if (provider && provider.getContextMenuActions)
      appPanelActions = provider.getContextMenuActions(appPanelItem);
  }

  function setAppPanelActionIndex(index) {
    // Moving the cursor away disarms a pending confirmation, exactly like the
    // keyboard path does — otherwise a destructive action could stay armed while
    // the pointer wanders and fire on the very next click.
    if (index !== appPanelConfirmIndex)
      appPanelConfirmIndex = -1;
    appPanelActionIndex = index;
  }

  function cancelAppPanelConfirm() {
    appPanelConfirmIndex = -1;
  }

  function activateAppPanelAction(index) {
    const action = appPanelActions[index];
    if (!action || action.enabled === false || action.busy)
      return;

    // Destructive actions arm first, then run on a second activation.
    if (action.confirm && appPanelConfirmIndex !== index) {
      appPanelConfirmIndex = index;
      appPanelActionIndex = index;
      return;
    }

    appPanelConfirmIndex = -1;
    if (action.action)
      action.action();

    if (action.keepOpen) {
      Qt.callLater(() => root.refreshAppPanelActions());
    } else {
      closeAppPanel();
    }
  }

  function selectNextAppPanelAction(step) {
    const count = appPanelActions.length;
    if (count === 0)
      return;
    appPanelConfirmIndex = -1;
    let index = appPanelActionIndex;
    // Skip over disabled entries so the cursor never parks on a dead row.
    for (let i = 0; i < count; i++) {
      index = (index + step + count) % count;
      const action = appPanelActions[index];
      if (action && action.enabled !== false && !action.busy) {
        appPanelActionIndex = index;
        return;
      }
    }
  }

  function showAppProperties(item) {
    propertiesApp = item?.appData || item;
    appPanelShowingProperties = true;
    appPanelActionIndex = -1;
    appPanelConfirmIndex = -1;
  }

  function hideAppProperties() {
    appPanelShowingProperties = false;
    propertiesApp = null;
  }

  // Keep the panel in sync with package-manager progress.
  Connections {
    target: appsProvider
    function onUpdateRevisionChanged() {
      root.refreshAppPanelActions();
    }
  }


  function applyCategorySelection(tabIndex, categories) {
    const categoryList = categories || providerCategories;
    if (!categoryList || tabIndex < 0 || tabIndex >= categoryList.length)
      return false;

    currentProvider.selectCategory(categoryList[tabIndex]);
    // Don't assign categoryTabs.currentIndex imperatively here: it has a
    // live binding to computedCurrentIndex (which tracks selectedCategory).
    // Overwriting it breaks that binding permanently, so any future
    // selectedCategory change from elsewhere (e.g. a provider resetting it)
    // would stop being reflected in the tab highlight.
    return true;
  }

  function selectCategoryWithSlide(tabIndex) {
    if (!showProviderCategories || !currentProvider || !currentProvider.selectCategory)
      return;

    const cats = providerCategories;
    if (!cats || tabIndex < 0 || tabIndex >= cats.length)
      return;

    const currentIdx = cats.indexOf(currentProvider.selectedCategory);
    if (tabIndex === currentIdx)
      return;

    const canAnimate = !animationsDisabled && resultsSwapView.width > 0 && resultsSwapView.height > 0;
    if (!canAnimate) {
      applyCategorySelection(tabIndex, cats);
      return;
    }

    const direction = tabIndex > currentIdx ? 1 : -1;
    resultsSwapView.swap(direction, () => applyCategorySelection(tabIndex, providerCategories));
  }

  // Public API
  function setSearchText(text) {
    searchText = text;
  }

  function focusSearchInput() {
    var item = (hasCoverBanner && bannerSearchInput) ? bannerSearchInput : searchInput;
    if (item && item.inputItem) {
      item.inputItem.forceActiveFocus();
    }
  }

  // Provider registration
  function registerProvider(provider) {
    providers.push(provider);
    provider.launcher = root;
    if (provider.init)
      provider.init();
  }

  function syncPluginProviders() {
    var registeredIds = LauncherProviderRegistry.getPluginProviders();
    var changed = false;

    // Remove providers that are no longer registered
    for (var existingId in pluginProviderInstances) {
      if (registeredIds.indexOf(existingId) === -1) {
        var idx = providers.indexOf(pluginProviderInstances[existingId]);
        if (idx >= 0)
          providers.splice(idx, 1);
        delete pluginProviderInstances[existingId];
        Logger.d("Launcher", "Removed plugin provider:", existingId);
        changed = true;
      }
    }

    // Adopt persistent instances from the registry
    for (var i = 0; i < registeredIds.length; i++) {
      var providerId = registeredIds[i];
      if (!pluginProviderInstances[providerId]) {
        var instance = LauncherProviderRegistry.getProviderInstance(providerId);
        if (instance) {
          pluginProviderInstances[providerId] = instance;
          providers.push(instance);
          instance.launcher = root;
          Logger.d("Launcher", "Adopted plugin provider:", providerId);
          changed = true;
        }
      }
    }

    // Update results only if providers changed
    if (changed && root.isOpen) {
      updateResults();
    }
  }

  // Search handling
  function updateResults() {
    results = [];
    var newActiveProvider = null;

    // Check for command mode
    if (searchText.startsWith(">")) {
      for (let provider of providers) {
        if (provider.handleCommand && provider.handleCommand(searchText)) {
          newActiveProvider = provider;
          results = provider.getResults(searchText);
          break;
        }
      }

      // Show available commands if just ">" or filter commands if partial match
      if (!newActiveProvider) {
        let allCommands = [];
        for (let provider of providers) {
          if (provider.commands)
            allCommands = allCommands.concat(provider.commands());
        }
        if (searchText === ">") {
          results = allCommands;
        } else if (searchText.length > 1) {
          const query = searchText.substring(1);
          if (typeof FuzzySort !== 'undefined') {
            const fuzzyResults = FuzzySort.go(query, allCommands, {
                                                "keys": ["name"],
                                                "limit": 50
                                              });
            results = fuzzyResults.map(result => result.obj);
          } else {
            const queryLower = query.toLowerCase();
            results = allCommands.filter(cmd => (cmd.name || "").toLowerCase().includes(queryLower));
          }
        }
      }
    } else {
      // Regular search - let providers contribute results
      let allResults = [];
      for (let provider of providers) {
        if (provider.handleSearch) {
          const providerResults = provider.getResults(searchText);
          allResults = allResults.concat(providerResults);
        }
      }

      // Sort by _score (higher = better match), items without _score go first
      if (searchText.trim() !== "") {
        const boostByUsage = Settings.data.appLauncher.sortByMostUsed;

        allResults.sort((a, b) => {
                          let sa = a._score !== undefined ? a._score : 0;
                          let sb = b._score !== undefined ? b._score : 0;

                          // Boost scores for frequently used items from tracked providers
                          // _score is normalized 0–1, so boost is scaled to nudge, not overwhelm
                          if (boostByUsage) {
                            if (a.provider && a.provider.trackUsage && a.usageKey) {
                              sa += 0.1 * Math.log2(1 + ShellState.getLauncherUsageCount(a.usageKey));
                            }
                            if (b.provider && b.provider.trackUsage && b.usageKey) {
                              sb += 0.1 * Math.log2(1 + ShellState.getLauncherUsageCount(b.usageKey));
                            }
                          }

                          return sb - sa;
                        });
      }
      results = allResults;
    }

    // Update activeProvider only after computing new state to avoid UI flicker
    activeProvider = newActiveProvider;
    selectedIndex = 0;
    reanchorAppPanel();
    applyPendingAppPanel();
  }

  // A finished package operation asks (via PanelService) for the panel to come
  // back on the app it touched. Results arrive asynchronously, so the request is
  // parked until there is something to anchor to.
  function applyPendingAppPanel() {
    const wanted = PanelService.pendingLauncherAppPanelId;
    if (!wanted || results.length === 0)
      return;

    const normalize = id => appsProvider.normalizeAppId ? appsProvider.normalizeAppId(String(id || "")) : String(id || "");
    const target = normalize(wanted);
    const entry = results.find(item => item && item.appId && normalize(item.appId) === target);
    if (!entry)
      return;

    PanelService.pendingLauncherAppPanelId = "";
    openAppPanel(entry);
  }

  // Results are rebuilt from scratch on every refresh, so an open panel has to
  // be re-bound to the new entry object (or closed if the app is gone).
  function reanchorAppPanel() {
    if (!appPanelItem)
      return;

    const key = appPanelItem.appId || appPanelItem.usageKey;
    const rebound = key ? results.find(entry => (entry.appId || entry.usageKey) === key) : null;
    if (!rebound) {
      closeAppPanel();
      return;
    }

    appPanelItem = rebound;
    selectedIndex = results.indexOf(rebound);
    refreshAppPanelActions();
  }

  // Navigation functions (delegated to LauncherNavigation.js)
  function selectNext() {
    selectedIndex = LauncherNav.selectNext(selectedIndex, results.length);
  }
  function selectPrevious() {
    selectedIndex = LauncherNav.selectPrevious(selectedIndex, results.length);
  }
  function selectNextWrapped() {
    selectedIndex = LauncherNav.selectNextWrapped(selectedIndex, results.length, allowWrapNavigation);
  }
  function selectPreviousWrapped() {
    selectedIndex = LauncherNav.selectPreviousWrapped(selectedIndex, results.length, allowWrapNavigation);
  }
  function selectFirst() {
    selectedIndex = LauncherNav.selectFirst();
  }
  function selectLast() {
    selectedIndex = LauncherNav.selectLast(results.length);
  }
  function selectNextPage() {
    selectedIndex = LauncherNav.selectNextPage(selectedIndex, results.length, entryHeight);
  }
  function selectPreviousPage() {
    selectedIndex = LauncherNav.selectPreviousPage(selectedIndex, results.length, entryHeight);
  }
  function selectPreviousRow() {
    selectedIndex = LauncherNav.selectPreviousRow(selectedIndex, results.length, gridColumns);
  }
  function selectNextRow() {
    selectedIndex = LauncherNav.selectNextRow(selectedIndex, results.length, gridColumns);
  }
  function selectPreviousColumn() {
    selectedIndex = LauncherNav.selectPreviousColumn(selectedIndex, results.length, gridColumns);
  }
  function selectNextColumn() {
    selectedIndex = LauncherNav.selectNextColumn(selectedIndex, results.length, gridColumns);
  }

  function activate() {
    if (results.length > 0 && results[selectedIndex]) {
      const item = results[selectedIndex];
      const provider = item.provider || currentProvider;

      // Track usage for providers that opt in (cross-provider "most used" tracking)
      if (Settings.data.appLauncher.sortByMostUsed && provider && provider.trackUsage && item.usageKey) {
        ShellState.recordLauncherUsage(item.usageKey);
      }

      // Check if auto-paste is enabled and provider/item supports it
      if (Settings.data.appLauncher.autoPasteClipboard && provider && provider.supportsAutoPaste && item.autoPasteText) {
        if (item.onAutoPaste)
          item.onAutoPaste();
        closeImmediately();
        Qt.callLater(() => {
                       ClipboardService.pasteText(item.autoPasteText);
                     });
        return;
      }

      if (item.onActivate)
        item.onActivate();
    }
  }

  function checkKey(event, settingName) {
    return Keybinds.checkKey(event, settingName, Settings);
  }

  // Returns true when the event was consumed by the inline app panel.
  function handleAppPanelKeyPress(event) {
    if (checkKey(event, 'escape')) {
      // Unwind one layer at a time: confirmation, then properties, then panel.
      if (appPanelConfirmIndex >= 0)
        appPanelConfirmIndex = -1;
      else if (appPanelShowingProperties)
        hideAppProperties();
      else
        closeAppPanel();
      event.accepted = true;
      return true;
    }

    if (appPanelShowingProperties) {
      // Properties has no list to walk; only Enter/Backspace step back.
      if (checkKey(event, 'enter') || event.key === Qt.Key_Backspace) {
        hideAppProperties();
        event.accepted = true;
        return true;
      }
      // Swallow navigation too: letting it through would move the selection out
      // from under the panel while it keeps showing the previous app.
      if (checkKey(event, 'up') || checkKey(event, 'down') || checkKey(event, 'left') || checkKey(event, 'right')) {
        event.accepted = true;
        return true;
      }
      return false;
    }

    if (checkKey(event, 'up')) {
      selectNextAppPanelAction(-1);
      event.accepted = true;
      return true;
    }

    if (checkKey(event, 'down')) {
      selectNextAppPanelAction(1);
      event.accepted = true;
      return true;
    }

    // Grid and columns layouts map left/right to the results grid; while the
    // panel owns the focus they must not move the selection out from under it.
    if (checkKey(event, 'left') || checkKey(event, 'right')) {
      event.accepted = true;
      return true;
    }

    if (checkKey(event, 'enter')) {
      if (appPanelActionIndex < 0)
        selectNextAppPanelAction(1);
      else
        activateAppPanelAction(appPanelActionIndex);
      event.accepted = true;
      return true;
    }

    if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
      closeAppPanel();
      event.accepted = true;
      return true;
    }

    return false;
  }

  // Keyboard handler
  function handleKeyPress(event) {
    // The inline app panel grabs navigation keys while it is open.
    if (appPanelOpen && handleAppPanelKeyPress(event))
      return;

    if (checkKey(event, 'escape')) {
      close();
      event.accepted = true;
      return;
    }

    if (checkKey(event, 'enter')) {
      activate();
      event.accepted = true;
      return;
    }

    // Context-menu key opens the panel on the current selection
    if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
      openAppPanelForSelection();
      event.accepted = true;
      return;
    }

    if (checkKey(event, 'up')) {
      if (!isSingleView) {
        isGridView ? selectPreviousRow() : selectPreviousWrapped();
      }
      event.accepted = true;
      return;
    }

    if (checkKey(event, 'down')) {
      if (!isSingleView) {
        isGridView ? selectNextRow() : selectNextWrapped();
      }
      event.accepted = true;
      return;
    }

    if (checkKey(event, 'left')) {
      if (isGridView) {
        selectPreviousColumn();
        event.accepted = true;
        return;
      }
    }

    if (checkKey(event, 'right')) {
      if (isGridView) {
        selectNextColumn();
        event.accepted = true;
        return;
      }
    }

    // Static bindings
    switch (event.key) {
    case Qt.Key_Tab:
      if (showProviderCategories) {
        var cats = providerCategories;
        var idx = cats.indexOf(currentProvider.selectedCategory);
        var nextIdx = (idx + 1) % cats.length;
        selectCategoryWithSlide(nextIdx);
      } else {
        selectNextWrapped();
      }
      event.accepted = true;
      break;
    case Qt.Key_Backtab:
      if (showProviderCategories) {
        var cats2 = providerCategories;
        var idx2 = cats2.indexOf(currentProvider.selectedCategory);
        var prevIdx = ((idx2 - 1) % cats2.length + cats2.length) % cats2.length;
        selectCategoryWithSlide(prevIdx);
      } else {
        selectPreviousWrapped();
      }
      event.accepted = true;
      break;
    case Qt.Key_Home:
      selectFirst();
      event.accepted = true;
      break;
    case Qt.Key_End:
      selectLast();
      event.accepted = true;
      break;
    case Qt.Key_PageUp:
      selectPreviousPage();
      event.accepted = true;
      break;
    case Qt.Key_PageDown:
      selectNextPage();
      event.accepted = true;
      break;
    case Qt.Key_Delete:
      if (selectedIndex >= 0 && results && results[selectedIndex]) {
        var item = results[selectedIndex];
        var provider = item.provider || currentProvider;
        if (provider && provider.canDeleteItem && provider.canDeleteItem(item))
          provider.deleteItem(item);
      }
      event.accepted = true;
      break;
    }
  }

  // -----------------------
  // Provider components
  // -----------------------
  ApplicationsProvider {
    id: appsProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: ApplicationsProvider");
    }
  }

  ClipboardProvider {
    id: clipProvider
    Component.onCompleted: {
      if (Settings.data.appLauncher.enableClipboardHistory) {
        registerProvider(this);
        Logger.d("Launcher", "Registered: ClipboardProvider");
      }
    }
  }

  CommandProvider {
    id: cmdProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: CommandProvider");
    }
  }

  EmojiProvider {
    id: emojiProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: EmojiProvider");
    }
  }

  CalculatorProvider {
    id: calcProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: CalculatorProvider");
    }
  }

  SettingsProvider {
    id: settingsProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: SettingsProvider");
    }
  }

  SessionProvider {
    id: sessionProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: SessionProvider");
    }
  }

  WindowsProvider {
    id: windowsProvider
    Component.onCompleted: {
      registerProvider(this);
      Logger.d("Launcher", "Registered: WindowsProvider");
    }
  }

  // ==================== UI Content ====================

  opacity: resultsReady ? 1.0 : 0.0

  Behavior on opacity {
    OpacityAnimator {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  HoverHandler {
    id: globalHoverHandler
    enabled: !Settings.data.appLauncher.ignoreMouseInput

    onPointChanged: {
      if (!root.mouseTrackingReady) {
        return;
      }

      if (!root.globalMouseInitialized) {
        root.globalLastMouseX = point.position.x;
        root.globalLastMouseY = point.position.y;
        root.globalMouseInitialized = true;
        return;
      }

      const deltaX = Math.abs(point.position.x - root.globalLastMouseX);
      const deltaY = Math.abs(point.position.y - root.globalLastMouseY);
      if (deltaX + deltaY >= 5) {
        root.ignoreMouseHover = false;
        root.globalLastMouseX = point.position.x;
        root.globalLastMouseY = point.position.y;
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.topMargin: Style.marginM
    anchors.bottomMargin: Style.marginM
    spacing: Style.marginS

    // Header Cover Banner (when coverMode !== "none")
    Item {
      id: coverBannerHeader
      visible: root.hasCoverBanner
      Layout.fillWidth: true
      Layout.preferredHeight: root.coverBannerHeight
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.topMargin: 0
      clip: false

      // Two-layer elevation: a wide ambient halo plus a tight contact shadow.
      // Both stay well inside the panel's side margins so they never bleed past
      // the launcher edges (Style.marginM on each side, blurMax is 22px).
      NDropShadow {
        anchors.fill: bannerContainer
        source: bannerContainer
        autoPaddingEnabled: true
        shadowBlur: 0.30
        shadowOpacity: 0.22
        shadowHorizontalOffset: 0
        shadowVerticalOffset: Math.round(2 * Style.uiScaleRatio)
        z: -2
      }

      NDropShadow {
        anchors.fill: bannerContainer
        source: bannerContainer
        autoPaddingEnabled: true
        shadowBlur: 0.13
        shadowOpacity: 0.26
        shadowHorizontalOffset: 0
        shadowVerticalOffset: Math.round(5 * Style.uiScaleRatio)
        z: -1
      }

      Rectangle {
        id: bannerContainer
        anchors.fill: parent
        radius: Style.radiusL
        color: Color.mSurfaceContainerLow
        border.color: "transparent"
        border.width: 0

        NImageRounded {
          id: coverImage
          anchors.fill: parent
          imagePath: root.profileWallpaperPath
          imageFillMode: Image.PreserveAspectCrop
          radius: Style.radiusL
        }

        Rectangle {
          anchors.fill: parent
          // Gradient-style overlay: stronger at bottom for text legibility
          gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, (Settings.data.appLauncher.coverOverlay ?? 0.40) * 0.4) }
            GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, (Settings.data.appLauncher.coverOverlay ?? 0.40) * 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, Settings.data.appLauncher.coverOverlay ?? 0.40) }
          }
          radius: Style.radiusL
        }

        // Rim light: reads as a lit top edge, which is what actually sells the
        // floating look now that the shadow no longer carries it alone.
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusL
          gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
          }
        }

        // Hairline outline so the banner keeps a crisp edge against the panel
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusL
          color: "transparent"
          border.width: Style.borderS
          border.color: Qt.rgba(1, 1, 1, 0.14)
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginS

        Item { Layout.fillHeight: true }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NTextInput {
            id: bannerSearchInput
            Layout.fillWidth: true
            radius: Style.iRadiusL
            inputIconName: "search"
            text: root.searchText
            placeholderText: I18n.tr("placeholders.search-launcher")
            fontSize: Style.fontSizeM
            onTextChanged: root.searchText = text

            Component.onCompleted: {
              if (bannerSearchInput.inputItem) {
                bannerSearchInput.inputItem.forceActiveFocus();
                bannerSearchInput.inputItem.Keys.onPressed.connect(function (event) {
                  root.handleKeyPress(event);
                });
              }
            }
          }

          NIconButton {
            visible: root.showLayoutToggle
            icon: Settings.data.appLauncher.viewMode === "columns" ? "layout-columns" : (Settings.data.appLauncher.viewMode === "grid" ? "layout-grid" : "layout-list")
            tooltipText: Settings.data.appLauncher.viewMode === "columns" ? I18n.tr("options.launcher-view-mode.columns") : (Settings.data.appLauncher.viewMode === "grid" ? I18n.tr("options.launcher-view-mode.grid") : I18n.tr("options.launcher-view-mode.list"))
            customRadius: Style.iRadiusL
            colorBg: Color.mSurfaceContainerHigh
            colorBgHover: Color.mPrimaryContainer
            colorFg: Color.mOnSurfaceVariant
            colorFgHover: Color.mOnPrimaryContainer
            colorBorder: "transparent"
            colorBorderHover: "transparent"
            Layout.preferredWidth: bannerSearchInput.implicitHeight > 0 ? bannerSearchInput.implicitHeight : Math.round(36 * Style.uiScaleRatio)
            Layout.preferredHeight: bannerSearchInput.implicitHeight > 0 ? bannerSearchInput.implicitHeight : Math.round(36 * Style.uiScaleRatio)
            onClicked: {
              const current = Settings.data.appLauncher.viewMode;
              if (current === "columns") Settings.data.appLauncher.viewMode = "grid";
              else if (current === "grid") Settings.data.appLauncher.viewMode = "list";
              else Settings.data.appLauncher.viewMode = "columns";
            }
          }
        }
      }
      } // ends bannerContainer
    } // ends coverBannerHeader

    // Standard Search Bar when coverMode === "none"
    RowLayout {
      visible: !root.hasCoverBanner
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      spacing: Style.marginS

      NTextInput {
        id: searchInput
        Layout.fillWidth: true
        radius: Style.iRadiusL
        inputIconName: "search"
        text: root.searchText
        placeholderText: I18n.tr("placeholders.search-launcher")
        fontSize: Style.fontSizeM
        onTextChanged: root.searchText = text

        Component.onCompleted: {
          if (searchInput.inputItem) {
            searchInput.inputItem.forceActiveFocus();
            searchInput.inputItem.Keys.onPressed.connect(function (event) {
              root.handleKeyPress(event);
            });
          }
        }
      }

      NIconButton {
        visible: root.showLayoutToggle
        icon: Settings.data.appLauncher.viewMode === "columns" ? "layout-columns" : (Settings.data.appLauncher.viewMode === "grid" ? "layout-grid" : "layout-list")
        tooltipText: Settings.data.appLauncher.viewMode === "columns" ? I18n.tr("options.launcher-view-mode.columns") : (Settings.data.appLauncher.viewMode === "grid" ? I18n.tr("options.launcher-view-mode.grid") : I18n.tr("options.launcher-view-mode.list"))
        customRadius: Style.iRadiusL
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mPrimaryContainer
        colorFg: Color.mOnSurfaceVariant
        colorFgHover: Color.mOnPrimaryContainer
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        Layout.preferredWidth: searchInput.height
        Layout.preferredHeight: searchInput.height
        onClicked: {
          const current = Settings.data.appLauncher.viewMode;
          if (current === "columns") Settings.data.appLauncher.viewMode = "grid";
          else if (current === "grid") Settings.data.appLauncher.viewMode = "list";
          else Settings.data.appLauncher.viewMode = "columns";
        }
      }
    }

    // Unified category tabs (works with any provider that has categories)
    LauncherCategoryTabs {
      id: categoryTabs
      visible: root.showProviderCategories
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM

      categories: root.providerCategories
      currentIndex: visible && root.providerCategories.length > 0 ? root.providerCategories.indexOf(root.currentProvider.selectedCategory) : 0
      iconFor: category => root.currentProvider.categoryIcons ? root.currentProvider.categoryIcons[category] : undefined
      nameFor: category => root.currentProvider.getCategoryName ? root.currentProvider.getCategoryName(category) : category
      onCategorySelected: index => root.selectCategoryWithSlide(index)
    }

    // Results view
    NSlideSwapView {
      id: resultsSwapView
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      Layout.fillHeight: true
      animationsEnabled: !root.animationsDisabled
      sourceComponent: root.isSingleView ? singleViewComponent : rowsViewComponent
    }

    // --------------------------
    // LIST / 2-COLUMNS / GRID VIEW
    // All three are rows of N cells; only the column count, the row height and
    // the cell style differ. Rows (instead of a GridView) are what let the
    // inline app panel expand full-width and push the rows below it down.
    Component {
      id: rowsViewComponent
      NListView {
        id: resultsRows

        readonly property int columns: root.rowColumns
        readonly property int rowCount: Math.ceil(root.results.length / columns)
        readonly property int selectedRow: root.selectedIndex >= 0 ? Math.floor(root.selectedIndex / columns) : 0
        readonly property real cellWidth: width / Math.max(1, columns)
        readonly property real rowHeight: {
          if (!root.isGridView)
            return root.entryHeight;
          const ratio = root.currentProvider && root.currentProvider.preferredGridCellRatio ? root.currentProvider.preferredGridCellRatio : 1;
          return cellWidth * ratio;
        }

        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AlwaysOff
        reserveScrollbarSpace: false
        gradientColor: Settings.data.ui.panelBackgroundOpacity < 1 ? "transparent" : Color.mSurfaceContainer
        wheelScrollMultiplier: 2.25
        smoothWheelAnimationDuration: Style.animationFast

        width: parent.width
        height: parent.height
        spacing: root.isGridView ? 0 : Style.marginXS
        model: rowCount
        currentIndex: selectedRow
        cacheBuffer: resultsRows.height * 2
        interactive: !Settings.data.appLauncher.ignoreMouseInput

        onCurrentIndexChanged: {
          cancelFlick();
          if (currentIndex >= 0)
            positionViewAtIndex(currentIndex, ListView.Contain);
        }

        // Keep an expanding panel inside the viewport.
        Connections {
          target: root
          function onAppPanelItemChanged() {
            if (!root.appPanelItem)
              return;
            Qt.callLater(() => {
                           if (resultsRows)
                             resultsRows.positionViewAtIndex(resultsRows.selectedRow, ListView.Contain);
                         });
          }
        }

        delegate: LauncherRowDelegate {
          launcher: root
          columns: resultsRows.columns
          rowHeight: resultsRows.rowHeight
          useCards: root.isGridView
        }
      }
    }

    // --------------------------
    // SINGLE ITEM VIEW
    Component {
      id: singleViewComponent

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NBox {
          anchors.fill: parent
          color: Color.mSurfaceContainerLow
          forceOpaque: true
          Layout.fillWidth: true
          Layout.fillHeight: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
              Layout.alignment: Qt.AlignTop | Qt.AlignLeft
              NText {
                text: root.results.length > 0 ? root.results[0].name : ""
                pointSize: Style.fontSizeL
                font.weight: Font.Bold
                color: Color.mOnSurface
              }
            }

            NScrollView {
              id: descriptionScrollView
              Layout.alignment: Qt.AlignTop | Qt.AlignLeft
              Layout.topMargin: Style.fontSizeL + Style.marginXL
              Layout.fillWidth: true
              Layout.fillHeight: true
              horizontalPolicy: ScrollBar.AlwaysOff
              reserveScrollbarSpace: false

              NText {
                width: descriptionScrollView.availableWidth
                text: root.results.length > 0 ? root.results[0].description : ""
                pointSize: Style.fontSizeM
                font.weight: Font.Bold
                color: Color.mOnSurface
                horizontalAlignment: Text.AlignHLeft
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                markdownTextEnabled: true
              }
            }
          }
        }
      }
    }

    ColumnLayout {
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      spacing: 0

      NDivider {
        Layout.fillWidth: true
        Layout.bottomMargin: Style.marginXS
        opacity: 0.35
      }

      NText {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginXXS
        Layout.bottomMargin: Style.marginM
        text: {
          if (root.results.length === 0) {
            if (root.searchText) {
              return I18n.tr("common.no-results");
            }
            // Use provider's empty browsing message if available
            var provider = root.currentProvider;
            if (provider && provider.emptyBrowsingMessage) {
              return provider.emptyBrowsingMessage;
            }
            return "";
          }
          var prefix = root.activeProvider && root.activeProvider.name ? root.activeProvider.name + ": " : "";
          return prefix + I18n.trp("common.result-count", root.results.length);
        }
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignLeft
        opacity: 1.0
      }
    }
  }

}
