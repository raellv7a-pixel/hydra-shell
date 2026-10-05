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
  property string browseState: "home"
  property string activeFolderId: ""
  property string activeSubfolderId: ""
  property var folderAnchor: null
  readonly property var metrics: LauncherDensity {}
  readonly property string effectiveState: searchText !== "" ? "search" : browseState
  readonly property real homePreferredHeight: contentLayout.implicitHeight + metrics.outerPadding * 2
  function scrollHomeVertically(event) { if (home.visible) home.scrollVertically(event); }
  readonly property var browseModel: browse
  readonly property var parentFolder: activeFolderId === "__pinned" ? { id: "__pinned", name: I18n.tr("launcher-home.pinned"), icon: "pin", mode: "pinned", entries: browse.pinned, children: [] } : browse.folders.find(folder => folder.id === activeFolderId) || null
  readonly property var activeFolder: activeSubfolderId ? (parentFolder?.children || []).find(folder => folder.id === activeSubfolderId) || null : parentFolder
  readonly property bool folderExpanded: effectiveState === "home" && activeFolder !== null
  property bool appPanelShowingFolders: false
  property var editingFolder: null
  property string folderEditorAppId: ""
  property string folderEditorParentId: ""
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
  property bool ignoreMouseHover: true // Keyboard owns the primary highlight until genuine pointer motion.

  Connections {
    target: PanelService
    function onPendingLauncherAppPanelIdChanged() {
      if (root.isOpen)
        root.applyPendingAppPanel();
    }
  }
  // Screen coordinates do not move when SmartPanel animates beneath a stationary cursor.
  property real globalLastMouseX: 0
  property real globalLastMouseY: 0
  property bool globalMouseInitialized: false

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
    if (coverMode === "none")
      return "";
    if (coverMode === "custom")
      return Settings.data.appLauncher.coverPath !== "" ? Settings.preprocessPath(Settings.data.appLauncher.coverPath) : "";
    if (coverMode === "random")
      return randomCoverPath !== "" ? Settings.preprocessPath(randomCoverPath) : "";
    // "auto" mode — use the current wallpaper
    var wp = WallpaperService.getWallpaper(screen?.name ?? "");
    if (wp && !WallpaperService.isSolidColorPath(wp))
      return wp;
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

  LauncherBrowseModel {
    id: browse
    provider: appsProvider
    isOpen: root.isOpen
    onFoldersChanged: {
      const parent = browse.folders.find(folder => folder.id === root.activeFolderId);
      if (root.activeFolderId && root.activeFolderId !== "__pinned" && !parent) root.closeExpandedFolder();
      else if (root.activeSubfolderId && !(parent?.children || []).some(child => child.id === root.activeSubfolderId)) root.activeSubfolderId = "";
      Qt.callLater(root.reanchorAppPanel);
    }
  }

  function goHome() {
    closeAppPanel();
    browseState = "home";
    activeFolderId = "";
    activeSubfolderId = "";
    folderAnchor = null;
    appsProvider.selectedCategory = "all";
    updateResults();
    focusSearchInput();
  }

  function openAllApps(category) {
    closeAppPanel();
    browseState = "all_apps";
    activeFolderId = "";
    activeSubfolderId = "";
    folderAnchor = null;
    appsProvider.selectCategory(category || "all");
    focusSearchInput();
  }

  function openFolder(id, anchor) {
    closeAppPanel();
    browseState = "home";
    activeFolderId = id;
    activeSubfolderId = "";
    folderAnchor = anchor || null;
    Qt.callLater(root.focusExpandedFolder);
  }
  function openPinned(anchor) {
    openFolder("__pinned", anchor);
  }

  function focusExpandedFolder() {
    if (collectionFlyout.status === Loader.Ready) collectionFlyout.item.focusFirst();
  }

  function closeExpandedFolder() {
    closeAppPanel();
    activeFolderId = "";
    activeSubfolderId = "";
    folderAnchor = null;
    Qt.callLater(home.focusFirst);
  }

  function openSubfolder(id) {
    if (!(parentFolder?.children || []).some(folder => folder.id === id)) return;
    closeAppPanel();
    activeSubfolderId = id;
    Qt.callLater(root.focusExpandedFolder);
  }

  function backToParentFolder() {
    closeAppPanel();
    activeSubfolderId = "";
    Qt.callLater(root.focusExpandedFolder);
  }

  function showHomeAppActions(item) {
    if (folderExpanded) {
      openAppPanel(item);
      return;
    }
    openAllApps("all");
    const target = results.find(entry => entry.appId === item.appId);
    if (target) {
      selectedIndex = results.indexOf(target);
      openAppPanel(target);
    }
  }

  function editFolder(folder, appId, parentId) {
    editingFolder = folder;
    folderEditorAppId = appId || "";
    folderEditorParentId = parentId || folder?.parentId || "";
    folderEditor.active = true;
  }

  function closeFolderEditor() {
    folderEditor.active = false;
    focusSearchInput();
    if (folderExpanded) Qt.callLater(root.focusExpandedFolder);
  }

  function showFolderActions() {
    appPanelShowingFolders = true;
    appPanelShowingProperties = false;
    appPanelActionIndex = -1;
    refreshAppPanelActions();
  }

  function folderActions() {
    const appId = appPanelItem?.appId || "";
    const actions = [{
      id: "folders-back", icon: "arrow-left", label: I18n.tr("launcher-home.back"),
      keepOpen: true, action: () => { appPanelShowingFolders = false; }
    }];
    for (const folder of Settings.data.appLauncher.userFolders || []) {
      const member = (folder.apps || []).includes(appId);
      actions.push({
        id: "folder-" + folder.id, icon: member ? "check" : (folder.icon || "folder"), label: folder.name,
        description: I18n.tr(member ? "launcher-home.remove-from-folder" : "launcher-home.add-to-folder"),
        keepOpen: true, action: () => browse.toggleMembership(folder.id, appId)
      });
      for (const child of folder.children || []) {
        const childMember = (child.apps || []).includes(appId);
        actions.push({
          id: "folder-" + child.id, icon: childMember ? "check" : (child.icon || "folder"),
          label: I18n.tr("launcher-home.subfolder-path", { parent: folder.name, child: child.name }),
          description: I18n.tr(childMember ? "launcher-home.remove-from-folder" : "launcher-home.add-to-folder"),
          keepOpen: true, action: () => browse.toggleMembership(folder.id, appId, child.id)
        });
      }
    }
    actions.push({ id: "folder-new", icon: "folder-plus", label: I18n.tr("launcher-home.new-folder"),
      keepOpen: true, action: () => editFolder(null, appId) });
    return actions;
  }

  function ensureHomeItemVisible(item) {
    if (home.visible && !folderExpanded) home.ensureVisible(item);
  }

  function focusHomeCategories() {
    if (categoryTabs.visible) categoryTabs.focusFirst();
    else focusSearchInput();
  }

  function handleHomeItemKey(event, item) {
    if (folderEditor.active)
      return;
    if (appPanelOpen && handleAppPanelKeyPress(event)) return;
    if (checkKey(event, "escape")) {
      if (searchText !== "") searchText = "";
      else if (folderExpanded) closeExpandedFolder();
      else if (browseState !== "home") goHome();
      else close();
      event.accepted = true;
    } else if (event.text && event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && event.key !== Qt.Key_Space) {
      searchText += event.text;
      focusSearchInput();
      searchInput.inputItem.cursorPosition = searchText.length;
      event.accepted = true;
    } else if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(event.key)) {
      const forward = event.key === Qt.Key_Down || event.key === Qt.Key_Right;
      let next = item.nextItemInFocusChain(forward);
      for (let i = 0; next && i < 200; i++) {
        if (next.visible && next.enabled && next.activeFocusOnTab) {
          next.forceActiveFocus();
          break;
        }
        next = next.nextItemInFocusChain(forward);
      }
      event.accepted = true;
    }
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
      if (searchText !== "") {
        activeFolderId = "";
        activeSubfolderId = "";
        folderAnchor = null;
      }
      updateResults();
    }
  }

  function onOpened() {
    ignoreMouseHover = true;
    globalMouseInitialized = false;
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
                   appsProvider.selectedCategory = "all";
                   updateResults();
                 });
  }

  function onClosed() {
    searchText = "";
    browseState = "home";
    activeFolderId = "";
    activeSubfolderId = "";
    folderAnchor = null;
    folderEditor.active = false;
    hero.reset();
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

    appPanelItem = item;
    appPanelActions = provider.getContextMenuActions(item);
    appPanelShowingProperties = false;
    appPanelShowingFolders = false;
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
    appPanelShowingFolders = false;
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
    if (appPanelShowingFolders)
      appPanelActions = folderActions();
    else if (provider && provider.getContextMenuActions)
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

    if (currentProvider === defaultProvider) {
      browseState = "all_apps";
      activeFolderId = "";
    }
    currentProvider.selectCategory(categoryList[tabIndex]);
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
    resultsSwapView.swap(direction, () => applyCategorySelection(tabIndex, cats));
  }

  // Public API
  function setSearchText(text) {
    searchText = text;
  }

  function focusSearchInput() {
    if (searchInput && searchInput.inputItem)
      searchInput.inputItem.forceActiveFocus();
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
    let nextResults = [];
    var newActiveProvider = null;

    // Check for command mode
    if (searchText.startsWith(">")) {
      for (let provider of providers) {
        if (provider.handleCommand && provider.handleCommand(searchText)) {
          newActiveProvider = provider;
          nextResults = provider.getResults(searchText);
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
          nextResults = allCommands;
        } else if (searchText.length > 1) {
          const query = searchText.substring(1);
          if (typeof FuzzySort !== 'undefined') {
            const fuzzyResults = FuzzySort.go(query, allCommands, {
                                                "keys": ["name"],
                                                "limit": 50
                                              });
            nextResults = fuzzyResults.map(result => result.obj);
          } else {
            const queryLower = query.toLowerCase();
            nextResults = allCommands.filter(cmd => (cmd.name || "").toLowerCase().includes(queryLower));
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
      nextResults = allResults;
    }

    results = nextResults;
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
    if (!wanted || !isOpen || providers.length === 0 || appsProvider.entries.length === 0)
      return;

    const normalize = id => appsProvider.normalizeAppId ? appsProvider.normalizeAppId(String(id || "")) : String(id || "");
    const target = normalize(wanted);
    let entry = results.find(item => item && item.appId && normalize(item.appId) === target);
    PanelService.pendingLauncherAppPanelId = "";
    if (!entry && appsProvider.entries.some(app => normalize(appsProvider.getAppKey(app)) === target && !appsProvider.isAppHidden(app))) {
      // An operation can finish after closing a filtered launcher. Resolve its
      // still-installed app now, rather than parking a request for later search.
      appsProvider.selectedCategory = "all";
      browseState = "all_apps";
      activeFolderId = "";
      searchText = "";
      updateResults();
      entry = results.find(item => item && item.appId && normalize(item.appId) === target);
    }
    // Completion must not reopen an unchanged panel or leave a request that
    // unexpectedly targets a later, unrelated search.
    if (entry && appPanelItem !== entry) {
      if (effectiveState === "home")
        showHomeAppActions(entry);
      else
        openAppPanel(entry);
    }
  }

  // Results are rebuilt from scratch on every refresh, so an open panel has to
  // be re-bound to the new entry object (or closed if the app is gone).
  function reanchorAppPanel() {
    if (!appPanelItem)
      return;

    const key = appPanelItem.appId || appPanelItem.usageKey;
    const entries = folderExpanded ? activeFolder.entries : results;
    const rebound = key ? entries.find(entry => (entry.appId || entry.usageKey) === key) : null;
    if (!rebound) {
      closeAppPanel();
      return;
    }

    appPanelItem = rebound;
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
    if (results.length > 0 && results[selectedIndex])
      activateEntry(results[selectedIndex]);
  }

  function activateEntry(item) {
    if (item) {
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
      else if (appPanelShowingFolders) {
        appPanelShowingFolders = false;
        refreshAppPanelActions();
      }
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
    // Keyboard intent restores the primary current-item indication. Mouse
    // traversal keeps its own subtle hover state while preserving Enter's target.
    ignoreMouseHover = true;
    globalMouseInitialized = false;
    if (folderEditor.active) {
      if (checkKey(event, "escape")) closeFolderEditor();
      event.accepted = true;
      return;
    }
    // The inline app panel grabs navigation keys while it is open.
    if (appPanelOpen && handleAppPanelKeyPress(event))
      return;

    if (checkKey(event, 'escape')) {
      if (searchText !== "")
        searchText = "";
      else if (folderExpanded)
        closeExpandedFolder();
      else if (browseState !== "home")
        goHome();
      else
        close();
      event.accepted = true;
      return;
    }

    if (effectiveState === "home") {
      if (folderExpanded && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) {
        focusExpandedFolder();
        event.accepted = true;
      } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
        if (categoryTabs.visible) categoryTabs.focusFirst();
        else home.focusFirst();
        event.accepted = true;
      }
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

    // Clipboard pin shortcut. Ctrl avoids stealing plain text input from search.
    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier) && selectedIndex >= 0 && results && results[selectedIndex]) {
      const pinItem = results[selectedIndex];
      const pinProvider = pinItem.provider || currentProvider;
      if (pinProvider && pinProvider.canPinItem && pinProvider.canPinItem(pinItem))
        pinProvider.togglePinItem(pinItem);
      event.accepted = true;
      return;
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
      const position = point.scenePosition;
      if (!root.globalMouseInitialized) {
        root.globalLastMouseX = position.x;
        root.globalLastMouseY = position.y;
        root.globalMouseInitialized = true;
        return;
      }

      const deltaX = Math.abs(position.x - root.globalLastMouseX);
      const deltaY = Math.abs(position.y - root.globalLastMouseY);
      if (deltaX + deltaY >= 5) {
        root.ignoreMouseHover = false;
        root.globalLastMouseX = position.x;
        root.globalLastMouseY = position.y;
      }
    }
  }

  ColumnLayout {
    id: contentLayout
    enabled: !folderEditor.active
    anchors.fill: parent
    anchors.topMargin: root.metrics.outerPadding
    anchors.bottomMargin: root.metrics.outerPadding
    spacing: root.metrics.gapS

    LauncherHero {
      id: hero
      launcher: root
      visible: root.effectiveState === "home" && root.hasCoverBanner
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(root.coverBannerHeight, (root.screen?.height || 1080 * Style.uiScaleRatio) * 0.24)
      Layout.leftMargin: root.metrics.padding
      Layout.rightMargin: root.metrics.padding
      Layout.bottomMargin: root.metrics.gapS
    }


    // One search input in every browsing mode and cover configuration.
    RowLayout {
      visible: true
      Layout.fillWidth: true
      Layout.leftMargin: root.metrics.outerPadding
      Layout.rightMargin: root.metrics.outerPadding
      spacing: root.metrics.gapS

      NTextInput {
        id: searchInput
        Layout.fillWidth: true
        inputHeight: root.metrics.searchHeight
        radius: inputHeight / 2
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
        visible: root.effectiveState !== "home" && root.showLayoutToggle
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
          if (current === "columns")
            Settings.data.appLauncher.viewMode = "grid";
          else if (current === "grid")
            Settings.data.appLauncher.viewMode = "list";
          else
            Settings.data.appLauncher.viewMode = "columns";
        }
      }
    }

    // Unified category tabs (works with any provider that has categories)
    LauncherCategoryPills {
      id: categoryTabs
      launcher: root
      visible: root.showProviderCategories
      Layout.fillWidth: true
      Layout.leftMargin: root.metrics.outerPadding
      Layout.rightMargin: root.metrics.outerPadding
    }

    RowLayout {
      visible: root.effectiveState === "all_apps"
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginM
      Layout.rightMargin: Style.marginM
      LauncherHomeButton {
        launcher: root
        text: I18n.tr("launcher-home.back")
        implicitHeight: Math.round(34 * Style.uiScaleRatio)
        onClicked: root.goHome()
      }
      NIcon { icon: "apps"; color: Color.mPrimary }
      NText {
        Layout.fillWidth: true
        text: I18n.tr("launcher-home.all-apps")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightSemiBold
      }
    }

    LauncherHome {
      id: home
      launcher: root
      visible: root.effectiveState === "home"
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.leftMargin: root.metrics.padding
      Layout.rightMargin: root.metrics.padding
    }

    // Results view
    NSlideSwapView {
      id: resultsSwapView
      visible: root.effectiveState !== "home"
      Layout.fillWidth: true
      Layout.leftMargin: root.metrics.outerPadding
      Layout.rightMargin: root.metrics.outerPadding
      Layout.fillHeight: true
      animationsEnabled: !root.animationsDisabled
      sourceComponent: root.effectiveState === "home" ? null : (root.isSingleView ? singleViewComponent : rowsViewComponent)
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
        spacing: root.isGridView ? 0 : root.metrics.gapXS
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
      visible: root.effectiveState !== "home"
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
  Item {
    id: collectionLayer
    anchors.fill: parent
    anchors.margins: Style.marginXL
    z: 100
    clip: true
    visible: root.folderExpanded
    enabled: !folderEditor.active
    Loader {
      id: collectionFlyout
      active: root.folderExpanded
      width: Math.min(collectionLayer.width, 620 * Style.uiScaleRatio)
      height: Math.min(collectionLayer.height, 360 * Style.uiScaleRatio, item?.implicitHeight || 360 * Style.uiScaleRatio)
      readonly property point anchorPoint: {
        root.width;
        root.height;
        home.contentY;
        return root.folderAnchor ? root.folderAnchor.mapToItem(collectionLayer, 0, 0) : Qt.point(0, 0);
      }
      readonly property real belowAnchor: anchorPoint.y + (root.folderAnchor?.height || 0) + root.metrics.gapM
      readonly property real aboveAnchor: anchorPoint.y - root.metrics.gapM - height
      x: Math.max(0, Math.min(collectionLayer.width - width, anchorPoint.x))
      y: Math.max(0, Math.min(collectionLayer.height - height, belowAnchor + height <= collectionLayer.height ? belowAnchor : aboveAnchor))
      sourceComponent: LauncherCollectionFlyout { launcher: root }
    }
  }

  Loader {
    id: folderEditor
    anchors.fill: parent
    active: false
    z: 200
    sourceComponent: LauncherFolderEditor {
      launcher: root
      folder: root.editingFolder
      appId: root.folderEditorAppId
      parentId: root.folderEditorParentId
    }
  }
}

