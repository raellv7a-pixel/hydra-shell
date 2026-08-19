import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI

Item {
  id: root

  property var launcher: null
  property string name: I18n.tr("launcher.providers.applications")
  property bool handleSearch: true
  property var entries: []
  property string supportedLayouts: "both"
  property bool isDefaultProvider: true // This provider handles empty search
  property bool ignoreDensity: false // Apps should scale with launcher density
  property bool trackUsage: true // Track usage frequency for "most used" sorting
  property int updateRevision: 0
  property bool shellyAvailable: false
  property bool shellyBusy: false
  property string shellyError: ""
  // Normalized package id -> { name, type, version, desktopName }
  property var availableUpdates: ({})
  // `shelly list-updates all --json` answers with one array per backend. Each
  // backend uses its own record shape, so the bucket key is the only reliable
  // source for the package type we later hand back to install/remove.
  readonly property var updateBuckets: ({
                                          "Packages": "standard",
                                          "Aur": "aur",
                                          "AppImage": "appimage",
                                          "Flatpak": "flatpak"
                                        })

  Process {
    id: shellyUpdatesProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
                root.shellyBusy = false;
                if (exitCode !== 0) {
                  root.shellyAvailable = false;
                  root.shellyError = String(stderr.text || "").trim();
                  root.updateRevision++;
                  return;
                }

                try {
                  const parsed = JSON.parse(String(stdout.text || "{}"));
                  const nextUpdates = {};

                  for (const bucket in root.updateBuckets) {
                    const packages = Array.isArray(parsed) ? (bucket === "Packages" ? parsed : []) : (parsed[bucket] || []);
                    if (!Array.isArray(packages))
                    continue;

                    for (const pkg of packages) {
                      const update = root.buildUpdateRecord(pkg, root.updateBuckets[bucket]);
                      if (!update)
                      continue;
                      // Index under every alias the desktop entry could match on.
                      for (const alias of update.aliases)
                      nextUpdates[alias] = update;
                    }
                  }

                  root.availableUpdates = nextUpdates;
                  root.shellyAvailable = true;
                  root.shellyError = "";
                  root.updateRevision++;
                  if (root.launcher && root.launcher.isOpen)
                  root.launcher.updateResults();
                } catch (error) {
                  root.shellyAvailable = false;
                  root.shellyError = String(error);
                  root.updateRevision++;
                }
              }
  }
  // The privileged work runs in PackageManagerService so it survives the
  // launcher panel being unloaded; these mirror its state for the action rows.
  readonly property string operationAppId: PackageManagerService.operationAppId
  readonly property string operationState: PackageManagerService.operationState

  Connections {
    target: PackageManagerService

    function onOperationFinished(appId, operation, success) {
      root.shellyBusy = false;
      root.shellyError = success ? "" : PackageManagerService.lastError;
      if (success && operation === "remove")
        root.loadApplications();
      if (success)
        root.refreshShellyUpdates();
      root.updateRevision++;
      if (root.launcher && root.launcher.isOpen)
        root.launcher.updateResults();
    }
  }

  function buildUpdateRecord(pkg, type) {
    if (!pkg)
      return null;

    // AppImages are keyed by their file name but carry the .desktop name too.
    const name = String(pkg.Name || pkg.ApplicationId || pkg.PackageBase || "").trim();
    if (!name)
      return null;

    const aliases = [];
    const addAlias = value => {
      const normalized = normalizeAppId(String(value || "").replace(/\.desktop$/i, ""));
      if (normalized && !aliases.includes(normalized))
      aliases.push(normalized);
    };

    addAlias(name);
    addAlias(pkg.DesktopName);
    addAlias(pkg.PackageBase);
    addAlias(pkg.ApplicationId);
    addAlias(pkg.AppId);
    if (type === "appimage") {
      // "Ghost-Downloader-v4.2.5-Linux-x86_64" also has to match "ghost-downloader".
      addAlias(name.replace(/[-_]v?\d[\w.\-]*$/i, ""));
      addAlias(String(pkg.DesktopName || "").replace(/\s+/g, "-"));
    }

    return {
      "name": name,
      "type": type,
      // Shelly reports the target version as NewVersion; reading `Version` left
      // this empty, so the action row read "Update to " with nothing after it.
      "version": String(pkg.NewVersion || pkg.Version || "").trim(),
      "currentVersion": String(pkg.CurrentVersion || "").trim(),
      "desktopName": String(pkg.DesktopName || ""),
      "aliases": aliases
    };
  }

  Timer {
    id: shellyUpdatesTimer
    interval: 30 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.refreshShellyUpdates()
  }

  // Category support
  property string selectedCategory: "all"
  property bool showsCategories: true // Default to showing categories
  property var categories: ["all", "Pinned", "Hidden", "AudioVideo", "Chat", "Development", "Education", "Game", "Graphics", "Network", "Office", "System", "Misc", "WebBrowser"]
  property var availableCategories: ["all"] // Reactive property for available categories
  property var categoryIcons: ({
                                 "all": "apps",
                                 "Pinned": "pin",
                                 "Hidden": "eye-off",
                                 "AudioVideo": "music",
                                 "Chat": "message-circle",
                                 "Development": "code",
                                 "Education": "school" // Includes Science
                                              ,
                                 "Game": "device-gamepad",
                                 "Graphics": "brush",
                                 "Network": "wifi",
                                 "Office": "file-text",
                                 "System": "device-desktop" // Includes Settings and Utility
                                           ,
                                 "Misc": "dots",
                                 "WebBrowser": "world"
                               })

  function getCategoryName(category) {
    const names = {
      "all": I18n.tr("launcher.categories.all"),
      "Pinned": I18n.tr("launcher.categories.pinned"),
      "Hidden": I18n.tr("launcher.categories.hidden"),
      "AudioVideo": I18n.tr("launcher.categories.audiovideo"),
      "Chat": I18n.tr("launcher.categories.chat"),
      "Development": I18n.tr("launcher.categories.development"),
      "Education": I18n.tr("launcher.categories.education"),
      "Game": I18n.tr("launcher.categories.game"),
      "Graphics": I18n.tr("launcher.categories.graphics"),
      "Network": I18n.tr("common.network"),
      "Office": I18n.tr("launcher.categories.office"),
      "System": I18n.tr("launcher.categories.system"),
      "Misc": I18n.tr("launcher.categories.misc"),
      "WebBrowser": I18n.tr("launcher.categories.webbrowser")
    };
    return names[category] || category;
  }

  function init() {
    loadApplications();
    migrateLegacyUsageKeys();
    Qt.callLater(() => root.refreshShellyUpdates());
  }

  function onOpened() {
    // Just update available categories in case pinned apps changed
    updateAvailableCategories();
    // Default to Pinned if there are pinned apps, otherwise all
    if (availableCategories.includes("Pinned")) {
      selectedCategory = "Pinned";
    } else {
      selectedCategory = "all";
    }
    // Set category mode initially (will be updated when getResults is called)
    showsCategories = true;
  }

  // Reload applications when desktop entries change on disk
  Connections {
    target: typeof DesktopEntries !== 'undefined' ? DesktopEntries.applications : null
    function onValuesChanged() {
      Logger.d("ApplicationsProvider", "Desktop entries changed, reloading applications");
      loadApplications();
    }
  }

  function selectCategory(category) {
    selectedCategory = category;
    if (launcher) {
      launcher.updateResults();
    }
  }

  function getAppCategories(app) {
    if (!app)
      return [];

    const result = [];

    if (app.categories) {
      if (Array.isArray(app.categories)) {
        for (let cat of app.categories) {
          if (cat && cat.trim && cat.trim() !== '') {
            result.push(cat.trim());
          } else if (cat && typeof cat === 'string' && cat.trim() !== '') {
            result.push(cat.trim());
          }
        }
      } else if (typeof app.categories === 'string') {
        const cats = app.categories.split(';').filter(c => c && c.trim() !== '');
        for (let cat of cats) {
          const trimmed = cat.trim();
          if (trimmed && !result.includes(trimmed)) {
            result.push(trimmed);
          }
        }
      } else if (app.categories.length !== undefined) {
        try {
          for (let i = 0; i < app.categories.length; i++) {
            const cat = app.categories[i];
            if (cat && cat.trim && typeof cat.trim === 'function' && cat.trim() !== '') {
              result.push(cat.trim());
            } else if (cat && typeof cat === 'string' && cat.trim() !== '') {
              result.push(cat.trim());
            }
          }
        } catch (e) {}
      }
    }

    if (app.Categories) {
      const cats = app.Categories.split(';').filter(c => c && c.trim() !== '');
      for (let cat of cats) {
        const trimmed = cat.trim();
        if (trimmed && !result.includes(trimmed)) {
          result.push(trimmed);
        }
      }
    }

    return result;
  }

  function getAppCategory(app) {
    const appCategories = getAppCategories(app);
    if (appCategories.length === 0)
      return null;

    const priorityCategories = ["AudioVideo", "Chat", "WebBrowser", "Game", "Development", "Graphics", "Office", "Education", "System", "Network", "Misc"];

    for (let cat of appCategories) {
      if (cat === "AudioVideo" || cat === "Audio" || cat === "Video") {
        return "AudioVideo";
      }
    }

    if (appCategories.includes("Chat") || appCategories.includes("InstantMessaging")) {
      return "Chat";
    }

    if (appCategories.includes("WebBrowser")) {
      return "WebBrowser";
    }

    // Map Science to Education
    if (appCategories.includes("Science")) {
      return "Education";
    }

    // Map Settings to System
    if (appCategories.includes("Settings")) {
      return "System";
    }

    // Map Utility to System
    if (appCategories.includes("Utility")) {
      return "System";
    }

    for (let priorityCat of priorityCategories) {
      if (appCategories.includes(priorityCat) && root.categories.includes(priorityCat)) {
        return priorityCat;
      }
    }

    return "Misc";
  }

  // Helper function to normalize app IDs for case-insensitive matching
  function normalizeAppId(appId) {
    if (!appId || typeof appId !== 'string')
      return "";
    return appId.toLowerCase().trim();
  }

  // Helper function to check if an app is pinned
  function isAppPinned(app) {
    if (!app)
      return false;
    const pinnedApps = Settings.data.appLauncher.pinnedApps || [];
    const appId = getAppKey(app);
    const normalizedId = normalizeAppId(appId);
    return pinnedApps.some(pinnedId => normalizeAppId(pinnedId) === normalizedId);
  }
  function isAppHidden(app) {
    if (!app)
      return false;
    const hiddenApps = Settings.data.appLauncher.hiddenApps || [];
    const normalizedId = normalizeAppId(getAppKey(app));
    return hiddenApps.some(hiddenId => normalizeAppId(hiddenId) === normalizedId);
  }

  function appMatchesCategory(app, category) {
    if (category === "Hidden")
      return isAppHidden(app);

    if (category !== "Hidden" && isAppHidden(app))
      return false;

    if (category === "all")
      return true;

    if (category === "Pinned")
      return isAppPinned(app);

    // Get the primary category for this app (first matching standard category)
    const primaryCategory = getAppCategory(app);

    // If app has no matching standard category, don't show it in any category (only in "all")
    if (!primaryCategory)
      return false;

    // Map Audio/Video to AudioVideo
    if (category === "AudioVideo") {
      const appCategories = getAppCategories(app);
      // Show if app has AudioVideo, Audio, or Video
      return appCategories.includes("AudioVideo") || appCategories.includes("Audio") || appCategories.includes("Video");
    }

    // Map Science to Education
    if (category === "Education") {
      const appCategories = getAppCategories(app);
      return appCategories.includes("Education") || appCategories.includes("Science");
    }

    // Map Settings and Utility to System
    if (category === "System") {
      const appCategories = getAppCategories(app);
      return appCategories.includes("System") || appCategories.includes("Settings") || appCategories.includes("Utility");
    }

    // Only show app in its primary category to avoid overlap
    // This ensures each app appears in exactly one category tab
    return category === primaryCategory;
  }

  function getAvailableCategories() {
    const categorySet = new Set();
    let hasAudioVideo = false;
    let hasEducation = false;
    let hasSystem = false;
    let hasPinned = false;
    let hasHidden = false;

    // Check if there are any pinned apps
    const pinnedApps = Settings.data.appLauncher.pinnedApps || [];
    if (pinnedApps.length > 0) {
      // Verify that at least one pinned app exists in entries
      for (let app of entries) {
        if (isAppPinned(app)) {
          hasPinned = true;
          break;
        }
      }
    }
    for (let app of entries) {
      if (isAppHidden(app)) {
        hasHidden = true;
        break;
      }
    }

    for (let app of entries) {
      const appCategories = getAppCategories(app);
      const primaryCategory = getAppCategory(app);

      if (appCategories.includes("AudioVideo") || appCategories.includes("Audio") || appCategories.includes("Video")) {
        hasAudioVideo = true;
      } else if (appCategories.includes("Education") || appCategories.includes("Science")) {
        hasEducation = true;
      } else if (appCategories.includes("System") || appCategories.includes("Settings") || appCategories.includes("Utility")) {
        hasSystem = true;
      } else if (primaryCategory && root.categories.includes(primaryCategory)) {
        categorySet.add(primaryCategory);
      }
    }

    const result = [];

    // Add Pinned category first if there are pinned apps
    if (hasPinned) {
      result.push("Pinned");
    }
    if (hasHidden)
      result.push("Hidden");

    result.push("all");

    if (hasAudioVideo) {
      categorySet.add("AudioVideo");
    }
    if (hasEducation) {
      categorySet.add("Education");
    }
    if (hasSystem) {
      categorySet.add("System");
    }

    for (let cat of root.categories) {
      if (cat !== "all" && cat !== "Pinned" && cat !== "Misc" && categorySet.has(cat)) {
        result.push(cat);
      }
    }

    if (categorySet.has("Misc")) {
      result.push("Misc");
    }

    if (result.length === 1) {
      const fallback = root.categories.filter(c => c !== "Misc" && c !== "Hidden");
      fallback.push("Misc");
      return fallback;
    }

    return result;
  }

  function loadApplications() {
    if (typeof DesktopEntries === 'undefined') {
      Logger.w("ApplicationsProvider", "DesktopEntries service not available");
      return;
    }

    const allApps = DesktopEntries.applications.values || [];
    const seen = new Map(); // Map of appId -> exec command

    entries = allApps.filter(app => {
                               if (!app || app.noDisplay || app.hidden)
                               return false;

                               const appId = app.id || app.name;
                               const execCmd = getExecutableName(app);

                               // Check if we've seen this app ID before
                               if (seen.has(appId)) {
                                 const previousExec = seen.get(appId);

                                 // If exec is different, it's a legitimate different entry - keep it
                                 if (previousExec !== execCmd) {
                                   Logger.d("ApplicationsProvider", `Keeping variant of ${appId}: ${execCmd} (differs from ${previousExec})`);
                                   // Add with modified ID to make it unique
                                   app.id = `${appId}_${execCmd}`;
                                   seen.set(app.id, execCmd);
                                   return true;
                                 }

                                 // Same appId AND same exec = true duplicate, skip it
                                 Logger.d("ApplicationsProvider", `Skipping duplicate: ${appId}`);
                                 return false;
                               }

                               seen.set(appId, execCmd);
                               return true;
                             }).map(app => {
                                      app.executableName = getExecutableName(app);
                                      return app;
                                    });

    Logger.d("ApplicationsProvider", `Loaded ${entries.length} applications`);
    updateAvailableCategories();
  }

  function updateAvailableCategories() {
    availableCategories = getAvailableCategories();
  }

  Connections {
    target: Settings.data.appLauncher
    function onPinnedAppsChanged() {
      const wasViewingPinned = selectedCategory === "Pinned";
      updateAvailableCategories();

      // If we were viewing Pinned category and it's no longer available, switch to "all"
      if (wasViewingPinned && !availableCategories.includes("Pinned")) {
        selectedCategory = "all";
      }

      // Update results if we're currently viewing the Pinned category
      if (selectedCategory === "Pinned" && launcher) {
        launcher.updateResults();
      } else if (wasViewingPinned && selectedCategory === "all" && launcher) {
        // Also update results when switching to "all"
        launcher.updateResults();
      }
    }
    function onHiddenAppsChanged() {
      const wasViewingHidden = selectedCategory === "Hidden";
      updateAvailableCategories();
      if (wasViewingHidden && !availableCategories.includes("Hidden"))
        selectedCategory = "all";
      if (launcher)
        launcher.updateResults();
    }
  }

  function getExecutableName(app) {
    if (!app)
      return "";

    // Try to get executable name from command array
    if (app.command && Array.isArray(app.command) && app.command.length > 0) {
      const cmd = app.command[0];
      // Extract just the executable name from the full path
      const parts = cmd.split('/');
      const executable = parts[parts.length - 1];
      // Remove any arguments or parameters
      return executable.split(' ')[0];
    }

    // Try to get from exec property if available
    if (app.exec) {
      const parts = app.exec.split('/');
      const executable = parts[parts.length - 1];
      return executable.split(' ')[0];
    }

    // Fallback to app id (desktop file name without .desktop)
    if (app.id) {
      return app.id.replace('.desktop', '');
    }

    return "";
  }

  function getResults(query) {
    if (!entries || entries.length === 0)
      return [];

    // Set category mode based on whether there's a query
    const isSearching = !!(query && query.trim() !== "");
    showsCategories = !isSearching;

    // Filter by category only when NOT searching
    let filteredEntries = entries.filter(app => selectedCategory === "Hidden" ? isAppHidden(app) : !isAppHidden(app));
    if (!isSearching && selectedCategory && selectedCategory !== "all" && selectedCategory !== "Hidden") {
      filteredEntries = filteredEntries.filter(app => appMatchesCategory(app, selectedCategory));
    }

    if (!query || query.trim() === "") {
      // Return filtered apps, optionally sorted by usage
      let sorted;
      if (Settings.data.appLauncher.sortByMostUsed) {
        sorted = filteredEntries.slice().sort((a, b) => {
                                                // Pinned first
                                                const aPinned = isAppPinned(a);
                                                const bPinned = isAppPinned(b);
                                                if (aPinned !== bPinned)
                                                return aPinned ? -1 : 1;

                                                const ua = getUsageCount(a);
                                                const ub = getUsageCount(b);
                                                if (ub !== ua)
                                                return ub - ua;
                                                return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
                                              });
      } else {
        sorted = filteredEntries.slice().sort((a, b) => {
                                                const aPinned = isAppPinned(a);
                                                const bPinned = isAppPinned(b);
                                                if (aPinned !== bPinned)
                                                return aPinned ? -1 : 1;
                                                return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
                                              });
      }
      return sorted.map(app => createResultEntry(app));
    }

    // Use fuzzy search if available, fallback to simple search
    if (typeof FuzzySort !== 'undefined') {
      const fuzzyResults = FuzzySort.go(query, filteredEntries, {
                                          "keys": ["name", "comment", "genericName", "executableName"],
                                          "limit": 20
                                        });

      // Sort pinned first within fuzzy results while preserving fuzzysort order otherwise
      const pinned = [];
      const nonPinned = [];
      for (const r of fuzzyResults) {
        const app = r.obj;
        if (isAppPinned(app))
          pinned.push(r);
        else
          nonPinned.push(r);
      }
      return pinned.concat(nonPinned).map(result => createResultEntry(result.obj, result.score));
    } else {
      // Fallback to simple search
      const searchTerm = query.toLowerCase();
      return filteredEntries.filter(app => {
                                      const name = (app.name || "").toLowerCase();
                                      const comment = (app.comment || "").toLowerCase();
                                      const generic = (app.genericName || "").toLowerCase();
                                      const executable = getExecutableName(app).toLowerCase();
                                      return name.includes(searchTerm) || comment.includes(searchTerm) || generic.includes(searchTerm) || executable.includes(searchTerm);
                                    }).sort((a, b) => {
                                              // Prioritize name matches, then executable matches
                                              const aName = a.name.toLowerCase();
                                              const bName = b.name.toLowerCase();
                                              const aExecutable = getExecutableName(a).toLowerCase();
                                              const bExecutable = getExecutableName(b).toLowerCase();
                                              const aStarts = aName.startsWith(searchTerm);
                                              const bStarts = bName.startsWith(searchTerm);
                                              const aExecStarts = aExecutable.startsWith(searchTerm);
                                              const bExecStarts = bExecutable.startsWith(searchTerm);

                                              // Prioritize name matches first
                                              if (aStarts && !bStarts)
                                              return -1;
                                              if (!aStarts && bStarts)
                                              return 1;

                                              // Then prioritize executable matches
                                              if (aExecStarts && !bExecStarts)
                                              return -1;
                                              if (!aExecStarts && bExecStarts)
                                              return 1;

                                              return aName.localeCompare(bName);
                                            }).slice(0, 20).map(app => createResultEntry(app));
    }
  }

  function createResultEntry(app, score) {
    const update = getUpdateForApp(app);
    const revision = updateRevision;
    const appKey = getAppKey(app);
    const busy = !!operationState && operationAppId === appKey;
    return {
      "appId": appKey,
      "usageKey": appKey,
      "name": app.name || "Unknown",
      "description": app.genericName || app.comment || "",
      "icon": app.icon || "application-x-executable",
      "isImage": false,
      "hasUpdate": !!update,
      "isBusy": busy,
      "badgeIcon": busy ? "refresh" : (update ? "refresh-dot" : ""),
      "badgeTooltip": busy ? I18n.tr(`launcher.app-actions.busy-${operationState}`) : (update ? I18n.tr("launcher.app-actions.update-to", {
                                                                                                          "value": update.version
                                                                                                        }) : ""),
      "appData": app,
      "_score": (score !== undefined ? score : 0),
      "_updateRevision": revision,
      "provider": root,
      "onActivate": function () {
        // Ensures we are not preventing the future focusing of the app
        launcher.closeImmediately();

        // Defer execution to next event loop iteration to ensure panel is fully closed
        Qt.callLater(() => {
                       Logger.d("ApplicationsProvider", `Launching: ${app.name} (App ID: ${app.id || "unknown"})`);

                       const execString = (app.exec !== undefined && app.exec !== null) ? String(app.exec) : "";
                       const commandArgs = Array.isArray(app.command) ? app.command : (app.command && app.command.length !== undefined) ? Array.from(app.command) : [];
                       let hasQuotedArgs = execString.includes("\"") || execString.includes("'");
                       let hasSpaceArgs = false;
                       if (!hasQuotedArgs) {
                         hasQuotedArgs = commandArgs.some(arg => {
                                                            const text = String(arg);
                                                            return text.includes("\"") || text.includes("'");
                                                          });
                       }
                       if (!hasSpaceArgs) {
                         hasSpaceArgs = commandArgs.some(arg => String(arg).includes(" "));
                       }
                       if (app.execute && (hasQuotedArgs || hasSpaceArgs)) {
                         Logger.d("ApplicationsProvider", `Detected quoted/space arguments in Exec for ${app.name}, using app.execute()`);
                         app.execute();
                         return;
                       }

                       if (Settings.data.appLauncher.customLaunchPrefixEnabled && Settings.data.appLauncher.customLaunchPrefix.trim() !== "") {
                         // Use custom launch prefix
                         const prefix = Settings.data.appLauncher.customLaunchPrefix.trim().split(" ");
                         Logger.d("ApplicationsProvider", `Using custom launch prefix: ${Settings.data.appLauncher.customLaunchPrefix.trim()}`);

                         if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
                           const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
                           const command = prefix.concat(terminal.concat(app.command));
                           Logger.d("ApplicationsProvider", `Executing command (with prefix and terminal): ${command.join(" ")}`);
                           Quickshell.execDetached(command);
                         } else {
                           const command = prefix.concat(app.command);
                           Logger.d("ApplicationsProvider", `Executing command (with prefix): ${command.join(" ")}`);
                           Quickshell.execDetached(command);
                         }
                       } else {
                         if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
                           Logger.d("ApplicationsProvider", "Executing terminal app manually: " + app.name);
                           const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
                           const command = terminal.concat(app.command);
                           Logger.d("ApplicationsProvider", "Executing command (manual terminal): " + command.join(" "));
                           CompositorService.spawn(command);
                         } else if (app.command && app.command.length > 0) {
                           Logger.d("ApplicationsProvider", "Executing command: " + app.command.join(" "));
                           CompositorService.spawn(app.command);
                         } else if (app.execute) {
                           Logger.d("ApplicationsProvider", "Calling app.execute() for: " + app.name);
                           app.execute();
                         } else {
                           Logger.w("ApplicationsProvider", `Could not launch: ${app.name}. No valid launch method.`);
                         }
                       }
                     });
      }
    };
  }

  function appAliases(app) {
    if (!app)
      return [];

    const aliases = [];
    const addAlias = value => {
      const normalized = normalizeAppId(String(value || "").replace(/\.desktop$/i, ""));
      if (normalized && !aliases.includes(normalized))
      aliases.push(normalized);
    };

    addAlias(getAppKey(app));
    addAlias(app.id);
    addAlias(getExecutableName(app));
    addAlias(String(getExecutableName(app)).replace(/\.appimage$/i, ""));
    addAlias(app.name);
    addAlias(String(app.name || "").replace(/\s+/g, "-"));
    return aliases;
  }

  function getUpdateForApp(app) {
    if (!app || !availableUpdates)
      return null;

    for (const alias of appAliases(app)) {
      if (availableUpdates[alias])
        return availableUpdates[alias];
    }
    return null;
  }

  function refreshShellyUpdates() {
    if (shellyUpdatesProcess.running || PackageManagerService.busy)
      return;
    shellyBusy = true;
    shellyUpdatesProcess.exec({
                                command: ["shelly", "list-updates", "all", "--json"]
                              });
  }

  // Resolves the package Shelly should act on. Prefers the record coming from
  // list-updates (authoritative type), otherwise infers the backend from how
  // the desktop entry launches the app.
  function getPackageForApp(app) {
    const update = getUpdateForApp(app);
    if (update)
      return update;

    const command = Array.isArray(app?.command) ? app.command.map(value => String(value)) : [];
    const flatpakIndex = command.indexOf("flatpak");
    if (flatpakIndex >= 0 && command[flatpakIndex + 1] === "run" && command[flatpakIndex + 2]) {
      return {
        "name": command[flatpakIndex + 2],
        "type": "flatpak",
        "version": ""
      };
    }

    const executable = getExecutableName(app) || String(app?.id || "").replace(/\.desktop$/i, "");
    if (executable.toLowerCase().endsWith(".appimage")) {
      return {
        "name": executable.replace(/\.AppImage$/i, ""),
        "type": "appimage",
        "version": ""
      };
    }

    // Repository and AUR packages are both ALPM packages, so `standard` removes
    // either one.
    return executable ? {
                          "name": executable,
                          "type": "standard",
                          "version": ""
                        } : null;
  }

  // Shelly has no per-package "update" verb: repository and AUR packages are
  // upgraded by installing them again, while Flatpak and AppImage only expose a
  // whole-backend upgrade.
  function updateCommandFor(update) {
    switch (update.type) {
    case "aur":
      return ["shelly", "install", "aur", update.name, "--no-confirm"];
    case "flatpak":
      return ["shelly", "upgrade", "flatpak", "--no-confirm"];
    case "appimage":
      return ["shelly", "upgrade", "appimage", "--no-confirm"];
    default:
      return ["shelly", "install", "standard", update.name, "--no-confirm"];
    }
  }

  function removeCommandFor(packageInfo) {
    return ["shelly", "remove", packageInfo.type, packageInfo.name, "--no-confirm"];
  }

  function runShellyOperation(item, operation) {
    if (!item || shellyUpdatesProcess.running || PackageManagerService.busy)
      return;

    const app = item.appData || item;
    const packageInfo = operation === "update" ? getUpdateForApp(app) : getPackageForApp(app);
    if (!packageInfo)
      return;

    const command = operation === "update" ? updateCommandFor(packageInfo) : removeCommandFor(packageInfo);
    const appId = item.appId || getAppKey(app);

    shellyError = "";
    if (!PackageManagerService.run(operation, appId, item.name || app?.name || appId, command))
      return;

    shellyBusy = true;
    updateRevision++;
    if (root.launcher && root.launcher.isOpen)
      root.launcher.updateResults();
  }

  function updateApp(item) {
    runShellyOperation(item, "update");
  }

  function removeApp(item) {
    runShellyOperation(item, "remove");
  }

  // True while this specific app has a Shelly operation in flight.
  function isOperationBusy(item) {
    if (!item || !operationState)
      return false;
    return operationAppId === (item.appId || getAppKey(item.appData || item));
  }

  function toggleHidden(appId) {
    if (!appId)
      return;
    const normalizedId = normalizeAppId(appId);
    let arr = (Settings.data.appLauncher.hiddenApps || []).slice();
    const idx = arr.findIndex(hiddenId => normalizeAppId(hiddenId) === normalizedId);
    if (idx >= 0)
      arr.splice(idx, 1);
    else
      arr.push(appId);
    Settings.data.appLauncher.hiddenApps = arr;
  }

  // Supporting text for the update row: progress while it runs, the target
  // version when Shelly knows it, and a plain "available" when it does not.
  function describeUpdateAction(update, busy) {
    if (busy)
      return I18n.tr("launcher.app-actions.busy-update");
    if (!update)
      return I18n.tr("launcher.app-actions.up-to-date");
    if (!update.version)
      return I18n.tr("launcher.app-actions.update-available");
    return I18n.tr("launcher.app-actions.update-to", {
                     "value": update.version
                   });
  }

  function getContextMenuActions(item) {
    if (!item || !item.appId)
      return [];

    const app = item.appData || item;
    const update = getUpdateForApp(app);
    const packageInfo = getPackageForApp(app);
    const hidden = isAppHidden(app);
    const pinned = isAppPinned(app);
    const busyHere = isOperationBusy(item);
    const canOperate = root.shellyAvailable && !shellyBusy && !operationState;

    return [
          {
            "id": "pin",
            "icon": pinned ? "unpin" : "pin",
            "label": pinned ? I18n.tr("common.unpin") : I18n.tr("common.pin"),
            "action": () => togglePin(item.appId)
          },
          {
            "id": "hide",
            "icon": hidden ? "eye" : "eye-off",
            "label": hidden ? I18n.tr("common.show") : I18n.tr("common.hide"),
            "action": () => toggleHidden(item.appId)
          },
          {
            "id": "update",
            "icon": "download",
            "label": I18n.tr("common.update"),
            "description": describeUpdateAction(update, busyHere && operationState === "update"),
            "enabled": !!update && canOperate,
            "busy": busyHere && operationState === "update",
            "keepOpen": true,
            "action": () => updateApp(item)
          },
          {
            "id": "uninstall",
            "icon": "trash",
            "label": I18n.tr("common.uninstall"),
            "description": (busyHere && operationState === "remove") ? I18n.tr("launcher.app-actions.busy-remove") : (packageInfo ? I18n.tr(`launcher.app-actions.backend-${packageInfo.type}`) : ""),
            "enabled": !!packageInfo && canOperate,
            "busy": busyHere && operationState === "remove",
            "destructive": true,
            "confirm": true,
            "keepOpen": true,
            "action": () => removeApp(item)
          },
          {
            "id": "properties",
            "icon": "info",
            "label": I18n.tr("common.properties"),
            "keepOpen": true,
            "action": () => launcher.showAppProperties(item)
          }
        ];
  }

  function togglePin(appId) {
    if (!appId)
      return;
    const normalizedId = normalizeAppId(appId);
    let arr = (Settings.data.appLauncher.pinnedApps || []).slice();
    const idx = arr.findIndex(pinnedId => normalizeAppId(pinnedId) === normalizedId);
    if (idx >= 0)
      arr.splice(idx, 1);
    else
      arr.push(appId);
    Settings.data.appLauncher.pinnedApps = arr;
  }

  // -------------------------
  // Usage tracking helpers
  function getAppKey(app) {
    if (app && app.id)
      return String(app.id);
    if (app && app.command && app.command.join)
      return app.command.join(" ");
    return String(app && app.name ? app.name : "unknown");
  }

  function getUsageCount(app) {
    return ShellState.getLauncherUsageCount(getAppKey(app));
  }

  // Migrate legacy command-based usage keys to canonical app-id keys at startup
  function migrateLegacyUsageKeys() {
    for (let i = 0; i < entries.length; i++) {
      const app = entries[i];
      if (app && app.id && app.command && app.command.join) {
        const key = getAppKey(app);
        const legacyKey = app.command.join(" ");
        if (legacyKey !== key && ShellState.getLauncherUsageCount(legacyKey) > 0) {
          ShellState.migrateLauncherUsage(legacyKey, key);
          Logger.d("ApplicationsProvider", `Migrated usage: "${legacyKey}" → "${key}"`);
        }
      }
    }
  }
}
