import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  required property var provider
  property bool isOpen: false
  property var documents: []
  readonly property var visibleApps: provider.entries.filter(app => !provider.isAppHidden(app))
  readonly property var pinned: (Settings.data.appLauncher.pinnedApps || []).map(id => visibleApps.find(app => provider.getAppKey(app) === id)).filter(Boolean).map(app => provider.createResultEntry(app))
  readonly property var recentApps: {
    const apps = visibleApps;
    return (ShellState.data.launcherRecentApps || []).map(record => {
      const app = apps.find(value => provider.getAppKey(value) === record.appId);
      return app ? Object.assign(provider.createResultEntry(app), { lastOpenedAt: record.lastOpenedAt }) : null;
    }).filter(Boolean);
  }
  readonly property var recentItems: documents.filter(entry => entry.modifiedAt > ShellState.data.recentDocumentsClearedAt)
  readonly property var smartDefinitions: [
    { id: "tools", icon: "tool", categories: ["System", "Utility", "Settings", "PackageManager"] },
    { id: "productivity", icon: "file-text", categories: ["Office", "TextEditor", "WordProcessor", "Spreadsheet", "Presentation", "ProjectManagement"] },
    { id: "creativity", icon: "palette", categories: ["Graphics", "2DGraphics", "3DGraphics", "Photography", "Publishing"] },
    { id: "social", icon: "users", categories: ["Chat", "InstantMessaging", "Email", "IRCClient", "Telephony", "VideoConference"] },
    { id: "games", icon: "device-gamepad", categories: ["Game", "Emulator", "ActionGame", "AdventureGame", "ArcadeGame", "BoardGame", "BlocksGame", "CardGame", "KidsGame", "LogicGame", "RolePlaying", "Simulation", "SportsGame", "StrategyGame"] },
    { id: "media", icon: "music", categories: ["AudioVideo", "Audio", "Video", "Music", "Player", "Recorder", "AudioVideoEditing"] }
  ]
  readonly property var folders: {
    const apps = visibleApps;
    // Read the usage map here so all folder previews follow changes reactively.
    const usage = ShellState.data.launcherUsage;
    const smart = smartDefinitions.map(definition => {
      const members = apps.filter(app => provider.getAppCategories(app).some(category => definition.categories.includes(category)));
      return { id: definition.id, name: I18n.tr("launcher-home.folders." + definition.id), icon: definition.icon, mode: "smart", entries: orderedEntries(members, true) };
    }).filter(folder => folder.entries.length > 0);
    const manual = (Settings.data.appLauncher.userFolders || []).map(folder => {
      const children = (folder.children || []).map(child => ({
        id: child.id, parentId: folder.id, name: child.name, icon: child.icon || "folder", mode: "manual",
        entries: orderedEntries(apps.filter(app => (child.apps || []).includes(provider.getAppKey(app))), true),
        children: []
      }));
      return {
        id: folder.id, name: folder.name, icon: folder.icon || "folder", mode: "manual", children: children,
        entries: orderedEntries(apps.filter(app => (folder.apps || []).includes(provider.getAppKey(app))), true)
      };
    });
    return smart.concat(manual);
  }

  function orderedEntries(apps, usageOrder) {
    return apps.slice().sort((a, b) => {
      const difference = usageOrder ? provider.getUsageCount(b) - provider.getUsageCount(a) : 0;
      return difference || (a.name || "").localeCompare(b.name || "");
    }).map(app => provider.createResultEntry(app));
  }

  function saveFolder(id, name, icon, appId, parentId) {
    name = name.trim();
    if (!name) return "";
    const folders = (Settings.data.appLauncher.userFolders || []).slice();
    const parentIndex = parentId ? folders.findIndex(folder => folder.id === parentId) : -1;
    if (parentId && parentIndex < 0) return "";
    const target = parentId ? (folders[parentIndex].children || []).slice() : folders;
    const index = target.findIndex(folder => folder.id === id);
    const identity = id || "user-" + Date.now() + "-" + Math.random().toString(36).slice(2, 7);
    const previous = index >= 0 ? target[index] : null;
    const folder = { id: identity, name: name, icon: icon || "folder", apps: previous ? (previous.apps || []).slice() : (appId ? [appId] : []) };
    if (!parentId) folder.children = previous ? (previous.children || []).slice() : [];
    if (index >= 0) target[index] = folder;
    else target.push(folder);
    if (parentId) folders[parentIndex] = Object.assign({}, folders[parentIndex], { children: target });
    Settings.data.appLauncher.userFolders = folders;
    return identity;
  }

  function deleteFolder(id, parentId) {
    Settings.data.appLauncher.userFolders = (Settings.data.appLauncher.userFolders || []).map(folder => {
      if (folder.id !== parentId) return folder;
      return Object.assign({}, folder, { children: (folder.children || []).filter(child => child.id !== id) });
    }).filter(folder => parentId || folder.id !== id);
  }

  function toggleMembership(folderId, appId, childId) {
    function toggle(folder) {
      const apps = (folder.apps || []).slice();
      const index = apps.indexOf(appId);
      if (index >= 0) apps.splice(index, 1);
      else apps.push(appId);
      return Object.assign({}, folder, { apps: apps });
    }
    Settings.data.appLauncher.userFolders = (Settings.data.appLauncher.userFolders || []).map(folder => {
      if (folder.id !== folderId) return folder;
      if (!childId) return toggle(folder);
      return Object.assign({}, folder, { children: (folder.children || []).map(child => child.id === childId ? toggle(child) : child) });
    });
  }

  function clearRecents() {
    ShellState.clearLauncherRecents();
    documents = [];
  }

  onIsOpenChanged: if (isOpen) refreshDocuments()
  function refreshDocuments() {
    if (!reader.running) {
      reader.command = ["python3", Quickshell.shellDir + "/Scripts/python/launcher_recents.py", "--cutoff", String(ShellState.data.recentDocumentsClearedAt)];
      reader.running = true;
    }
  }
  Process {
    id: reader
    stdout: StdioCollector { id: output }
    onExited: code => {
      try { root.documents = code === 0 ? JSON.parse(output.text) : []; }
      catch (error) { root.documents = []; }
    }
  }
  Connections {
    target: ShellState
    function onIsLoadedChanged() { if (root.isOpen) root.refreshDocuments(); }
  }
}
