pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons/EdgeShelfIds.js" as EdgeShelfIds
import qs.Commons
import qs.Services.Compositor

Singleton {
  id: root

  // Presentation coordination only: per-screen booleans stay in MainScreen.
  // EdgeVisual/parent will set openScreenName on open and close if another monitor opens.
  property string openScreenName: ""

  // Reactive revision counter incremented on every compositor window subscription update
  property int windowRevision: 0

  // Last error message and busy indicator for serialized operations
  property string error: ""
  property bool busy: false

  // Error signal
  signal errorOccurred(string message)

  // Internal state
  property var _pendingLaunches: ({})
  property var _pendingRemovals: ({})
  property var _deferredRemovals: []
  property var _adopting: ({})
  property var _taskQueue: []
  property var _currentTask: null
  property var _restoreWatchers: []

  // Serialized command execution process
  Process {
    id: cmdProc
    running: false
    stderr: StdioCollector {
      id: cmdErr
    }
    onExited: code => root._onProcessExited(code)
  }

  // Monitor window list updates from CompositorService (event-driven, no continuous polling)
  Connections {
    target: CompositorService
    function onWindowListChanged() {
      root.windowRevision++;
      root._checkPendingLaunches();
      root._checkRestoreWatchers();
      root._checkAdoptions();
    }
  }

  // Single-shot 10s expiry for pending launches (no continuous polling)
  Timer {
    id: pendingExpiryTimer
    interval: 10000
    repeat: false
    onTriggered: root._cleanupExpiredPending()
  }

  Timer {
    id: adoptionTimeoutTimer
    interval: 2000
    repeat: false
    onTriggered: root._checkAdoptions(true)
  }

  // Single-shot restore watcher timeout timer (no continuous polling)
  Timer {
    id: restoreTimeoutTimer
    interval: 2000
    repeat: false
    onTriggered: root._onRestoreTimeout()
  }

  // --------------------------------------------------------------------------
  // Public Interface
  // --------------------------------------------------------------------------

  /**
  * Returns the canonical Umbriel scratchpad name for the given appId.
  */
  function scratchpadFor(appId) {
    return EdgeShelfIds.appIdToScratchpadName(appId);
  }

  /**
  * Returns true if any window currently belongs to the app's named scratchpad.
  */
  function isAssociated(appId) {
    if (!appId)
      return false;
    const spName = scratchpadFor(appId);
    const list = CompositorService.getWindowList();
    for (let i = 0; i < list.length; i++) {
      if (list[i].scratchpad === spName)
        return true;
    }
    return false;
  }

  /**
  * Returns true if any window for this app is running (in scratchpad or normal workspace).
  */
  function isRunning(appId) {
    if (!appId)
      return false;
    if (isAssociated(appId))
      return true;
    const entry = resolveDesktopEntry(appId);
    const list = CompositorService.getWindowList();
    for (let i = 0; i < list.length; i++) {
      const w = list[i];
      if (w.scratchpad && w.scratchpad !== "")
        continue;
      if (windowMatchesApp(w, appId, entry))
        return true;
    }
    return false;
  }

  /**
  * On icon click in Edge Shelf:
  * - if launch is already pending: ignores duplicate click to prevent spawning duplicate instances;
  * - if named scratchpad member exists: uses Umbriel native toggle;
  * - else collects candidate windows (excluding any scratchpad and pre-existing unrelated):
  *   - 0: launches app via DesktopEntry.execute(), snapshots existing window IDs, pending 10s;
  *   - 1: ordered focus, move to scratchpad, then summon;
  *   - >1: returns candidate window list for UI chooser (no picking arbitrarily).
  *
  * @param {string} appId - Application ID / desktop file identifier
  * @param {var} screen - Target ShellScreen
  * @returns {Array} Empty array if handled, or non-empty candidate objects on ambiguity.
  */
  function selectApp(appId, screen) {
    if (!appId)
      return [];

    // Guard: Edge Shelf operates on Umbriel named scratchpads
    if (!CompositorService.isUmbriel) {
      Logger.w("EdgeShelfService", "Edge Shelf is only available under Umbriel compositor");
      return [];
    }
    if (!CompositorService.backend?.windowsReceived) {
      root.error = "Aguardando a lista inicial de janelas do Umbriel";
      root.errorOccurred(root.error);
      return [];
    }

    if (_pendingRemovals[appId] || _deferredRemovals.includes(appId)) {
      root.error = "Aguarde a restauração das janelas de " + appId;
      root.errorOccurred(root.error);
      return [];
    }
    if (!UmbrielKeybindStore.loaded || UmbrielKeybindStore.busy || UmbrielKeybindStore.error) {
      root.error = UmbrielKeybindStore.error || "Configuração do Umbriel em andamento. Aguarde um instante.";
      root.errorOccurred(root.error);
      return [];
    }

    // Guard: rapid repeated clicks while pending should not spawn duplicates
    if (_pendingLaunches[appId] || _adopting[appId]) {
      Logger.d("EdgeShelfService", "Launch already pending for", appId, "- ignoring duplicate click");
      return [];
    }

    const spName = scratchpadFor(appId);
    const allWindows = CompositorService.getWindowList();

    // 1. If named scratchpad member already exists, use Umbriel native toggle
    for (let i = 0; i < allWindows.length; i++) {
      if (allWindows[i].scratchpad === spName) {
        Logger.d("EdgeShelfService", "Toggling existing scratchpad member for", appId, spName);
        _enqueueTask("toggle_" + spName, [["umbriel", "msg", "scratchpad-toggle:" + spName]], null);
        return [];
      }
    }

    // 2. Resolve DesktopEntry; require valid entry for launch
    const entry = resolveDesktopEntry(appId);
    if (!entry) {
      root.error = "DesktopEntry não encontrado para " + appId;
      root.errorOccurred(root.error);
      Logger.w("EdgeShelfService", root.error);
      return [];
    }

    // 3. Collect candidate windows (excluding any scratchpad)
    const candidates = [];
    for (let i = 0; i < allWindows.length; i++) {
      const w = allWindows[i];
      if (w.scratchpad && w.scratchpad !== "")
        continue;
      if (windowMatchesApp(w, appId, entry)) {
        candidates.push(w);
      }
    }

    // 0 candidates: real launch via DesktopEntry.execute(), snapshot IDs, pending 10s
    if (candidates.length === 0) {
      Logger.i("EdgeShelfService", "No running candidate windows for", appId, "- launching new instance via DesktopEntry");
      const snapshotIds = {};
      for (let i = 0; i < allWindows.length; i++)
        snapshotIds[String(allWindows[i].id)] = true;
      _pendingLaunches[appId] = {
        appId: appId,
        spName: spName,
        snapshotIds: snapshotIds,
        screen: screen,
        createdAt: Date.now()
      };
      _schedulePendingExpiry();
      try {
        if (typeof entry.execute === "function")
          entry.execute();
        else if (entry.command && entry.command.length > 0)
          CompositorService.spawn(entry.command);
        else
          throw new Error("DesktopEntry não possui comando executável");
      } catch (err) {
        delete _pendingLaunches[appId];
        root.error = "Falha ao executar " + appId + ": " + err;
        root.errorOccurred(root.error);
        Logger.e("EdgeShelfService", root.error);
      }
      return [];
    }

    // 1 candidate: ordered focus, move to scratchpad, then summon
    if (candidates.length === 1) {
      Logger.i("EdgeShelfService", "Single candidate window found for", appId, candidates[0].id);
      chooseWindow(appId, candidates[0].id, screen);
      return [];
    }

    // Multiple candidates: return candidate list for anchored chooser (no picking arbitrarily)
    Logger.i("EdgeShelfService", "Multiple candidates (" + candidates.length + ") found for", appId);
    return candidates.map(w => ({
                                  id: String(w.id),
                                  title: w.title || ("Janela " + w.id),
                                  appId: w.appId || "",
                                  output: w.output || "",
                                  workspaceId: w.workspaceId,
                                  raw: w
                                }));
  }

  /**
  * Moves a chosen candidate window into the app's named scratchpad and summons it.
  * Re-verifies that the window is still valid, still matches this app, and is outside all scratchpads.
  *
  * @param {string} appId - Application ID
  * @param {string|number} windowId - Chosen window identifier
  * @param {var} screen - Target ShellScreen
  * @returns {boolean} True if accepted and enqueued, false if window invalid.
  */
  function chooseWindow(appId, windowId, screen) {
    if (!appId || windowId === undefined || windowId === null)
      return false;
    if (_pendingRemovals[appId] || _deferredRemovals.includes(appId) || _adopting[appId])
      return false;

    const allWindows = CompositorService.getWindowList();
    let target = null;
    for (let i = 0; i < allWindows.length; i++) {
      if (String(allWindows[i].id) === String(windowId)) {
        target = allWindows[i];
        break;
      }
    }

    if (!target) {
      root.error = "Janela " + windowId + " não encontrada ou não mais disponível";
      root.errorOccurred(root.error);
      return false;
    }

    // Re-verify: candidate must be outside all scratchpads
    if (target.scratchpad && target.scratchpad !== "") {
      root.error = "Janela " + windowId + " já está associada a um scratchpad (" + target.scratchpad + ")";
      root.errorOccurred(root.error);
      Logger.w("EdgeShelfService", root.error);
      return false;
    }

    // Re-verify: candidate must still match this app
    const entry = resolveDesktopEntry(appId);
    if (!windowMatchesApp(target, appId, entry)) {
      root.error = "Janela " + windowId + " não corresponde ao aplicativo " + appId;
      root.errorOccurred(root.error);
      Logger.w("EdgeShelfService", root.error);
      return false;
    }

    const spName = scratchpadFor(appId);
    Logger.i("EdgeShelfService", "Moving window", windowId, "to scratchpad", spName);

    // Serialized order:
    // 1. Focus the window
    // 2. Move window to scratchpad
    // 3. Focus window (summons hidden scratchpad member to screen and active output)
    const commands = [["umbriel", "msg", "window-focus:" + windowId], ["umbriel", "msg", "window-move-to-scratchpad:" + spName], ["umbriel", "msg", "window-focus:" + windowId]];

    _adopting[appId] = String(windowId);
    adoptionTimeoutTimer.restart();
    _enqueueTask("choose_" + windowId, commands, function (success, err) {
      if (!success) {
        delete _adopting[appId];
        root.error = "Falha ao mover janela para scratchpad: " + err;
        root.errorOccurred(root.error);
        root._flushDeferredRemovals();
      } else {
        root._checkAdoptions();
      }
    });

    return true;
  }

  /**
  * Safely removes a pinned app:
  * 1. Coalesces duplicate removals and cancels pending launches.
  * 2. If windows exist in the named scratchpad: restores all member windows to normal workspaces
  *    (requires focus:id first so member is visible, then restore action).
  * 3. Observes subscribed windows until confirmed restored before mutating settings.
  * 4. Failure retains the favorite and configuration without mutating settings.
  *
  * @param {string|number} appId - App ID string or numeric index in pinnedApps
  */
  function removePinnedApp(appId) {
    if (appId === undefined || appId === null)
      return;

    // Resolve index to appId if numeric
    if (typeof appId === "number") {
      if (Settings.data && Settings.data.edgeShelf && Array.isArray(Settings.data.edgeShelf.pinnedApps)) {
        appId = Settings.data.edgeShelf.pinnedApps[appId];
      }
    }
    if (!appId || typeof appId !== "string")
      return;
    if (CompositorService.isUmbriel && !CompositorService.backend?.windowsReceived) {
      root.error = "Aguardando a lista inicial de janelas antes de remover " + appId;
      root.errorOccurred(root.error);
      return;
    }

    // Coalesce duplicate remove operations
    if (_pendingRemovals[appId]) {
      Logger.d("EdgeShelfService", "Removal already in progress for", appId);
      return;
    }
    if (_deferredRemovals.includes(appId))
      return;
    // A queued focus/move may not yet appear in the subscribed window list.
    // Wait for its membership before removing the scratchpad definition.
    if (_currentTask !== null || _taskQueue.length > 0 || _adopting[appId]) {
      _deferredRemovals.push(appId);
      return;
    }
    _pendingRemovals[appId] = true;

    // Cancel pending launches for this app
    if (_pendingLaunches[appId]) {
      delete _pendingLaunches[appId];
      _schedulePendingExpiry();
    }

    const spName = scratchpadFor(appId);
    const allWindows = CompositorService.getWindowList();
    const spWindows = allWindows.filter(w => w.scratchpad === spName);

    // If scratchpad currently has no windows, mutate settings immediately
    if (spWindows.length === 0) {
      _applySettingsRemoval(appId);
      delete _pendingRemovals[appId];
      return;
    }

    Logger.i("EdgeShelfService", "Restoring", spWindows.length, "windows from", spName, "before removal");

    // Build serialized commands: focus:id first (summons/makes visible), then restore
    const commands = [];
    const targetIds = [];
    for (let i = 0; i < spWindows.length; i++) {
      const win = spWindows[i];
      targetIds.push(String(win.id));
      commands.push(["umbriel", "msg", "window-focus:" + win.id]);
      commands.push(["umbriel", "msg", "window-restore-from-scratchpad:" + spName]);
    }

    _enqueueTask("remove_" + appId, commands, function (success, err) {
      if (!success) {
        delete _pendingRemovals[appId];
        root.error = "Falha ao enviar comandos de restauração para " + spName + ": " + err;
        root.errorOccurred(root.error);
        Logger.w("EdgeShelfService", root.error);
        return;
      }

      // Wait to observe confirmation in subscribed window list before mutating settings
      _watchRestoresConfirmed(appId, spName, targetIds);
    });
  }

  // --------------------------------------------------------------------------
  // Internal Helpers & Serialization Engine
  // --------------------------------------------------------------------------

  function _checkAdoptions(expired) {
    const list = CompositorService.getWindowList();
    for (const appId of Object.keys(_adopting)) {
      const id = _adopting[appId];
      const window = list.find(w => String(w.id) === id);
      if (window?.scratchpad === scratchpadFor(appId) || !window || expired) {
        delete _adopting[appId];
        if (expired && window && window.scratchpad !== scratchpadFor(appId)) {
          // IPC succeeded but the subscription never confirmed the move.
          // Never remove the definition based on an unverified snapshot.
          _deferredRemovals = _deferredRemovals.filter(value => value !== appId);
          root.error = "Não foi possível confirmar a associação de " + appId;
          root.errorOccurred(root.error);
        }
      }
    }
    if (Object.keys(_adopting).length === 0)
      adoptionTimeoutTimer.stop();
    root._flushDeferredRemovals();
  }

  function _flushDeferredRemovals() {
    if (_currentTask !== null || _taskQueue.length > 0)
      return;
    const ready = _deferredRemovals.filter(appId => !_adopting[appId]);
    if (!ready.length)
      return;
    _deferredRemovals = _deferredRemovals.filter(appId => _adopting[appId]);
    Qt.callLater(() => {
                   for (const appId of ready)
                   root.removePinnedApp(appId);
                 });
  }

  function _applySettingsRemoval(appId) {
    if (!Settings.data || !Settings.data.edgeShelf)
      return;
    const current = (Settings.data.edgeShelf.pinnedApps || []).slice();
    const idx = current.indexOf(appId);
    if (idx !== -1) {
      current.splice(idx, 1);
      Settings.data.edgeShelf.pinnedApps = current;
      Logger.i("EdgeShelfService", "Successfully removed pinned app:", appId);
    }
  }

  function _watchRestoresConfirmed(appId, spName, targetIds) {
    const list = CompositorService.getWindowList();
    const stillInSp = list.filter(w => w.scratchpad === spName);
    if (stillInSp.length === 0) {
      _applySettingsRemoval(appId);
      delete _pendingRemovals[appId];
      return;
    }

    _restoreWatchers.push({
                            appId: appId,
                            spName: spName,
                            targetIds: targetIds,
                            deadline: Date.now() + 2000
                          });
    restoreTimeoutTimer.restart();
  }

  function _checkRestoreWatchers() {
    if (_restoreWatchers.length === 0)
      return;

    const list = CompositorService.getWindowList();
    const remaining = [];

    for (let i = 0; i < _restoreWatchers.length; i++) {
      const watcher = _restoreWatchers[i];
      const stillInSp = list.filter(w => w.scratchpad === watcher.spName);

      if (stillInSp.length === 0) {
        // Confirmation observed! Safe to mutate settings
        _applySettingsRemoval(watcher.appId);
        delete _pendingRemovals[watcher.appId];
      } else {
        remaining.push(watcher);
      }
    }

    _restoreWatchers = remaining;
    if (_restoreWatchers.length === 0) {
      restoreTimeoutTimer.stop();
    }
  }

  function _onRestoreTimeout() {
    if (_restoreWatchers.length === 0)
      return;

    const list = CompositorService.getWindowList();
    const remaining = [];

    for (let i = 0; i < _restoreWatchers.length; i++) {
      const watcher = _restoreWatchers[i];
      const stillInSp = list.filter(w => w.scratchpad === watcher.spName);

      if (stillInSp.length === 0) {
        _applySettingsRemoval(watcher.appId);
        delete _pendingRemovals[watcher.appId];
      } else {
        // Timed out waiting for restoration confirmation: fail retains favorite and config
        delete _pendingRemovals[watcher.appId];
        root.error = "Tempo limite atingido ao confirmar restauração do scratchpad " + watcher.spName + "; configuração retida";
        root.errorOccurred(root.error);
        Logger.w("EdgeShelfService", root.error);
      }
    }

    _restoreWatchers = remaining;
  }

  function _checkPendingLaunches() {
    const keys = Object.keys(_pendingLaunches);
    if (keys.length === 0)
      return;

    const allWindows = CompositorService.getWindowList();

    for (let k = 0; k < keys.length; k++) {
      const appId = keys[k];
      const pending = _pendingLaunches[appId];
      if (!pending)
        continue;

      const entry = resolveDesktopEntry(appId);
      const newlyAppeared = [];

      for (let i = 0; i < allWindows.length; i++) {
        const w = allWindows[i];
        const winId = String(w.id);

        if (pending.snapshotIds[winId])
          continue;
        if (w.scratchpad && w.scratchpad !== "")
          continue;

        if (windowMatchesApp(w, appId, entry)) {
          newlyAppeared.push(w);
        }
      }

      if (newlyAppeared.length === 1) {
        // Exactly one new matching window: adopt it safely
        const winId = String(newlyAppeared[0].id);
        Logger.i("EdgeShelfService", "Pending launch resolved: single new window", winId, "for", appId);
        delete _pendingLaunches[appId];
        chooseWindow(appId, winId, pending.screen);
      } else if (newlyAppeared.length > 1) {
        // More than one new matching window: never choose arbitrarily! Cancel pending with explicit error
        Logger.w("EdgeShelfService", "Pending launch ambiguity: multiple (" + newlyAppeared.length + ") new windows detected for", appId);
        delete _pendingLaunches[appId];
        root.error = "Múltiplas novas janelas detectadas para " + appId + "; selecione manualmente no chooser";
        root.errorOccurred(root.error);
      }
    }

    if (Object.keys(_pendingLaunches).length === 0) {
      pendingExpiryTimer.stop();
    }
  }

  function _schedulePendingExpiry() {
    const deadlines = Object.values(_pendingLaunches).map(item => item.createdAt + 10000);
    if (!deadlines.length) {
      pendingExpiryTimer.stop();
      return;
    }
    pendingExpiryTimer.interval = Math.max(1, Math.min(...deadlines) - Date.now());
    pendingExpiryTimer.restart();
  }

  function _cleanupExpiredPending() {
    const now = Date.now();
    const keys = Object.keys(_pendingLaunches);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const item = _pendingLaunches[key];
      if (item && (now - item.createdAt >= 10000)) {
        Logger.d("EdgeShelfService", "Pending launch expired after 10s for", key);
        delete _pendingLaunches[key];
      }
    }
    _schedulePendingExpiry();
  }

  function _onProcessExited(code) {
    if (!_currentTask)
      return;

    if (code !== 0) {
      const errText = cmdErr.text.trim() || ("Comando falhou com código " + code);
      Logger.w("EdgeShelfService", "Task " + _currentTask.id + " failed:", _currentTask.commands[_currentTask.cmdIndex], errText);
      root.error = errText;
      root.errorOccurred(errText);
      const cb = _currentTask.onComplete;
      _currentTask = null;
      if (cb)
        cb(false, errText);
      _processNextTask();
      return;
    }

    _currentTask.cmdIndex++;
    _runCurrentTaskCommand();
  }

  function _runCurrentTaskCommand() {
    if (!_currentTask) {
      _processNextTask();
      return;
    }

    if (_currentTask.cmdIndex >= _currentTask.commands.length) {
      const cb = _currentTask.onComplete;
      _currentTask = null;
      if (cb)
        cb(true, "");
      _processNextTask();
      return;
    }

    const cmd = _currentTask.commands[_currentTask.cmdIndex];
    cmdProc.command = cmd;
    cmdProc.running = true;
  }

  function _processNextTask() {
    if (_currentTask !== null)
      return;
    if (_taskQueue.length === 0) {
      root.busy = false;
      root._flushDeferredRemovals();
      return;
    }

    root.busy = true;
    _currentTask = _taskQueue.shift();
    _runCurrentTaskCommand();
  }

  function _enqueueTask(id, commands, onComplete) {
    _taskQueue.push({
                      id: id,
                      commands: commands,
                      cmdIndex: 0,
                      onComplete: onComplete
                    });
    if (_currentTask === null) {
      _processNextTask();
    }
  }

  function resolveDesktopEntry(appId) {
    if (!appId)
      return null;
    try {
      if (typeof DesktopEntries !== "undefined") {
        if (DesktopEntries.byId) {
          let entry = DesktopEntries.byId(appId);
          if (entry)
            return entry;
          const cleanId = appId.endsWith(".desktop") ? appId.slice(0, -8) : appId;
          entry = DesktopEntries.byId(cleanId);
          if (entry)
            return entry;
        }
        if (DesktopEntries.heuristicLookup) {
          const entry = DesktopEntries.heuristicLookup(appId);
          if (entry)
            return entry;
        }
      }
    } catch (e) {}

    try {
      if (typeof ThemeIcons !== "undefined" && ThemeIcons.findAppEntry) {
        const entry = ThemeIcons.findAppEntry(appId);
        if (entry)
          return entry;
      }
    } catch (e2) {}

    return null;
  }

  function windowMatchesApp(w, appId, entry) {
    if (!w || !appId)
      return false;

    const wApp = String(w.appId || "").trim();
    const wAppLower = wApp.toLowerCase();
    if (!wAppLower)
      return false;

    const wId = EdgeShelfIds.normalizeAppId(wApp);
    if (wId === EdgeShelfIds.normalizeAppId(appId))
      return true;

    // Only compare known desktop-entry identities. A fuzzy/leaf match can
    // silently adopt another publisher's window with the same final name.
    if (!entry)
      return false;
    if (entry.id && wId === EdgeShelfIds.normalizeAppId(entry.id))
      return true;
    return !!entry.startupWmClass && wId === EdgeShelfIds.normalizeAppId(entry.startupWmClass);
  }
}
