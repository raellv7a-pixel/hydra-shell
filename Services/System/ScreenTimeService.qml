pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.UI

// Session-wide focus accounting; durations retain millisecond precision in seconds.
Singleton {
  id: root

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/hydra"
  readonly property string stateFilePath: stateDir + "/screen-usage.json"
  readonly property string legacyCacheFilePath: Settings.cacheDir ? (Settings.cacheDir.endsWith("/") ? Settings.cacheDir.slice(0, -1) : Settings.cacheDir) + "/screen-usage.json" : ((Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hydra/screen-usage.json")
  readonly property string legacyRaellFilePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/raell-dashboard/screen-usage.json"

  // Public tracking and query state.
  property var days: ({})
  property string todayKey: _dateKey(new Date())
  property string currentAppId: ""
  property string currentAppName: ""
  property string currentAppIcon: ""
  property string currentAppTitle: ""
  property double lastTickMs: 0
  property double currentSessionSeconds: 0
  property bool isLoaded: false
  property bool dirty: false
  property int idleThresholdSeconds: 120
  property bool wasIdle: false
  property bool _intervalTrackable: false
  property var _recentIntervals: []
  property bool _directoryReady: false
  property bool _saveInProgress: false
  property double _revision: 0
  property double _savingRevision: -1
  property string _persistedText: ""
  property string _savingText: ""
  property bool _lastSaveFailed: false
  readonly property int _maxTickGapMs: 5000

  // Reactive properties for consumers
  readonly property bool isUserIdle: {
    if (PanelService.lockScreen?.active ?? false)
      return true;
    if (CompositorService.overviewActive)
      return true;
    if (IdleService.nativeIdleMonitorAvailable && IdleService.idleSeconds >= idleThresholdSeconds)
      return true;
    return false;
  }

  readonly property bool isTracking: isLoaded && !isUserIdle && currentAppId !== ""
  readonly property double todayTotalSeconds: (days[todayKey]?.total) || 0
  readonly property string todayFormatted: formatDuration(todayTotalSeconds)
  readonly property var topAppsToday: getTopApps(1, 4)
  readonly property var weeklyActivity: getWeeklyActivity()
  readonly property double maxAppSecondsToday: {
    const top = topAppsToday;
    return (top && top.length > 0) ? top[0].seconds : 1;
  }

  signal dataUpdated

  Component.onCompleted: ensureDirProcess.running = true

  Component.onDestruction: {
    _tick();
    if (dirty)
      _persist();
  }

  function init() {
    if (root.isLoaded && root.lastTickMs <= 0)
      root._resetTracking();
  }

  function _resetTracking() {
    root.lastTickMs = Date.now();
    root._updateCurrentAppProps(root._resolveCurrentApp());
    root.wasIdle = root._nativeIdle();
    root._intervalTrackable = !root.isUserIdle && root.currentAppId !== "";
    root._recentIntervals = [];
    root.currentSessionSeconds = 0;
  }

  function _nativeIdle() {
    return IdleService.nativeIdleMonitorAvailable && IdleService.idleSeconds >= root.idleThresholdSeconds;
  }


  Connections {
    target: CompositorService

    function onActiveWindowChanged() {
      root._onFocusChanged();
    }

    function onOverviewActiveChanged() {
      root._tick();
    }
  }

  Connections {
    target: IdleService

    function onIdleSecondsChanged() {
      root._checkIdleTransition();
    }
  }

  Connections {
    target: PanelService.lockScreen ? PanelService.lockScreen : null

    function onActiveChanged() {
      root._tick();
    }
  }

  Timer {
    id: heartbeatTimer
    interval: 2000
    repeat: true
    running: root.isLoaded
    onTriggered: root._tick()
  }

  Timer {
    id: dayRolloverTimer
    interval: 30000
    repeat: true
    running: root.isLoaded
    onTriggered: root._checkDayRollover()
  }

  // Start once on the first mutation: continuous activity must not postpone saving.
  Timer {
    id: persistDebounceTimer
    interval: 20000
    repeat: false
    onTriggered: root._persist()
  }

  function _onFocusChanged() {
    _tick();
  }

  function _checkIdleTransition() {
    root._tick();
  }

  function _checkDayRollover() {
    if (root.isLoaded)
      root._tick();
  }

  function _tick(nowMs) {
    if (!root.isLoaded)
      return;

    const now = nowMs === undefined ? Date.now() : nowMs;
    const app = root._resolveCurrentApp();
    const idle = root._nativeIdle();
    const elapsedMs = now - root.lastTickMs;

    // Use eligibility captured at the beginning of the interval. The signal may
    // already expose the new lock/overview/focus state when this callback runs.
    if (root.lastTickMs > 0 && elapsedMs > 0 && elapsedMs <= root._maxTickGapMs && root._intervalTrackable) {
      root._accrueTime(root.currentAppId, root.currentAppName, root.currentAppIcon, root.currentAppTitle, root.lastTickMs, now);
      root.currentSessionSeconds += elapsedMs / 1000;
    } else if (elapsedMs < 0) {
      root._recentIntervals = [];
    }

    if (idle && !root.wasIdle)
      root._rollbackIdleSeconds(root.idleThresholdSeconds, now);
    root.wasIdle = idle;
    root._trimRecentIntervals(now);

    const changedApp = (app ? app.id : "") !== root.currentAppId;
    root._updateCurrentAppProps(app);
    if (changedApp || root.isUserIdle)
      root.currentSessionSeconds = 0;
    root.lastTickMs = now;
    root._intervalTrackable = !root.isUserIdle && root.currentAppId !== "";

    const key = root._dateKey(new Date(now));
    if (key !== root.todayKey) {
      root.todayKey = key;
      root.days = root._pruneHistory(root.days);
      root._ensureTodayEntry();
      root._markDirty();
      root.dataUpdated();
      root._persist();
    }
  }

  function _updateCurrentAppProps(app) {
    if (app) {
      root.currentAppId = app.id;
      root.currentAppName = app.name;
      root.currentAppIcon = app.icon;
      root.currentAppTitle = app.title;
    } else {
      root.currentAppId = "";
      root.currentAppName = "";
      root.currentAppIcon = "";
      root.currentAppTitle = "";
    }
  }

  function _resolveCurrentApp() {
    const win = CompositorService.getFocusedWindow();
    if (!win)
      return null;

    const rawId = String(win.appId || "").trim();
    const title = String(win.title || "").replace(/(\r\n|\n|\r)/g, "").trim();
    if (rawId === "" && title === "")
      return null;

    const appId = rawId !== "" ? rawId : title;
    if (_isExcludedApp(appId))
      return null;

    let appName = "";
    let appIcon = "";

    try {
      if (typeof ThemeIcons !== "undefined" && ThemeIcons.findAppEntry) {
        const entry = ThemeIcons.findAppEntry(appId);
        if (entry && entry.name) {
          appName = entry.name;
        }
      }
    } catch (e) {}

    if (!appName) {
      appName = CompositorService.getCleanAppName(rawId, title);
    }

    try {
      if (typeof ThemeIcons !== "undefined" && ThemeIcons.iconForAppId) {
        appIcon = ThemeIcons.iconForAppId(rawId || appId);
      }
    } catch (e) {}

    return {
      "id": appId.toLowerCase(),
      "rawId": rawId,
      "name": appName,
      "icon": appIcon || "",
      "title": title
    };
  }

  function _isExcludedApp(appId) {
    const id = String(appId || "").toLowerCase();
    if (id === "" || id === "unknown")
      return true;

    // Quickshell and Hydra internal windows
    if (id.indexOf("dev.noctalia.") === 0 || id.indexOf("dev.hydra.") === 0 || id === "hydra" || id.indexOf("quickshell") >= 0)
      return true;

    const compact = id.replace(/[._\-\s]/g, "");
    const patterns = [
      "xdg-desktop-portal", "xdgdesktopportal", "org.freedesktop.portal",
      "org.freedesktop.policykit", "polkit", "gcr-prompter", "kwallet",
      "zenity", "hyprlock", "swaylock", "gtklock"
    ];

    for (let i = 0; i < patterns.length; i++) {
      const pattern = patterns[i];
      if (id.indexOf(pattern) >= 0 || compact.indexOf(pattern.replace(/[._\-\s]/g, "")) >= 0)
        return true;
    }
    return false;
  }

  // Accrues elapsed time split across exact hour/day boundaries
  function _accrueTime(appId, appName, appIcon, appTitle, startMs, endMs) {
    if (!appId || startMs >= endMs)
      return;

    const segments = distributeElapsed(startMs, endMs);
    if (segments.length === 0)
      return;

    const currentDays = Object.assign({}, root.days);
    let modified = false;

    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i];
      const dateK = seg.dateKey;
      const hour = seg.hour;
      const sec = seg.seconds;
      if (sec <= 0)
        continue;

      const day = Object.assign({
        "total": 0,
        "apps": {},
        "hourly": new Array(24).fill(0),
        "appHourly": {}
      }, currentDays[dateK] || {});

      const dayApps = Object.assign({}, day.apps || {});
      const hourly = (day.hourly && day.hourly.length === 24) ? day.hourly.slice() : new Array(24).fill(0);
      const appHourly = Object.assign({}, day.appHourly || {});
      const appBuckets = (appHourly[appId] && appHourly[appId].length === 24) ? appHourly[appId].slice() : new Array(24).fill(0);

      const appEntry = Object.assign({
        "id": appId,
        "name": appName || appId,
        "icon": appIcon || "",
        "seconds": 0
      }, dayApps[appId] || {});
      appEntry.title = appTitle || appEntry.title || "";

      if (appName && (!appEntry.name || appEntry.name === appId))
        appEntry.name = appName;
      if (appIcon && !appEntry.icon)
        appEntry.icon = appIcon;

      appEntry.seconds = Math.max(0, Number(appEntry.seconds || 0) + sec);
      dayApps[appId] = appEntry;

      hourly[hour] = Math.max(0, Number(hourly[hour] || 0) + sec);
      appBuckets[hour] = Math.max(0, Number(appBuckets[hour] || 0) + sec);
      appHourly[appId] = appBuckets;

      day.apps = dayApps;
      day.hourly = hourly;
      day.appHourly = appHourly;
      day.total = Math.max(0, Number(day.total || 0) + sec);

      currentDays[dateK] = day;
      root._recentIntervals.push({
        "appId": appId,
        "dateKey": dateK,
        "hour": hour,
        "startMs": seg.startMs,
        "endMs": seg.endMs
      });
      modified = true;
    }

    if (modified) {
      root.days = currentDays;
      root._markDirty();
      root.dataUpdated();
    }
  }

  function _trimRecentIntervals(now) {
    const cutoff = now - Math.max(0, root.idleThresholdSeconds) * 1000;
    root._recentIntervals = root._recentIntervals.filter(interval => interval.endMs > cutoff);
  }

  function _rollbackIdleSeconds(secondsToRollback, nowMs) {
    const now = nowMs === undefined ? Date.now() : nowMs;
    const cutoff = now - Math.max(0, secondsToRollback) * 1000;
    const currentDays = Object.assign({}, root.days);
    let modified = false;

    // Only this process's recent accrual is reversible, never loaded history.
    for (const interval of root._recentIntervals) {
      const seconds = (Math.min(now, interval.endMs) - Math.max(cutoff, interval.startMs)) / 1000;
      const source = currentDays[interval.dateKey];
      if (seconds <= 0 || !source || !source.apps[interval.appId])
        continue;

      const day = Object.assign({}, source);
      const apps = Object.assign({}, day.apps);
      const app = Object.assign({}, apps[interval.appId]);
      const hourly = day.hourly.slice();
      const appHourly = Object.assign({}, day.appHourly);
      const buckets = appHourly[interval.appId].slice();
      const amount = Math.min(seconds, app.seconds, day.total, hourly[interval.hour], buckets[interval.hour]);
      if (amount <= 0)
        continue;

      app.seconds = Math.max(0, app.seconds - amount);
      day.total = Math.max(0, day.total - amount);
      hourly[interval.hour] = Math.max(0, hourly[interval.hour] - amount);
      buckets[interval.hour] = Math.max(0, buckets[interval.hour] - amount);
      apps[interval.appId] = app;
      appHourly[interval.appId] = buckets;
      day.apps = apps;
      day.hourly = hourly;
      day.appHourly = appHourly;
      currentDays[interval.dateKey] = day;
      modified = true;
    }
    root._recentIntervals = [];
    if (modified) {
      root.days = currentDays;
      root._markDirty();
      root.dataUpdated();
    }
  }

  // Splits [startMs, endMs] across hour and midnight boundaries
  function distributeElapsed(startMs, endMs) {
    const segments = [];
    if (!Number.isFinite(startMs) || !Number.isFinite(endMs) || startMs < 0 || endMs <= startMs || isNaN(new Date(endMs).getTime()))
      return segments;

    let cursor = startMs;
    while (cursor < endMs) {
      const at = new Date(cursor);
      const nextHour = new Date(at.getFullYear(), at.getMonth(), at.getDate(), at.getHours() + 1, 0, 0, 0);
      const boundary = Math.min(nextHour.getTime(), endMs);
      if (!(boundary > cursor))
        break;
      const secs = (boundary - cursor) / 1000;

      if (secs > 0) {
        segments.push({
          "dateKey": _dateKey(at),
          "hour": at.getHours(),
          "seconds": secs,
          "startMs": cursor,
          "endMs": boundary
        });
      }
      cursor = boundary;
    }
    return segments;
  }

  function _ensureTodayEntry() {
    const key = root.todayKey;
    if (!root.days[key]) {
      const d = Object.assign({}, root.days);
      d[key] = {
        "total": 0,
        "apps": {},
        "hourly": new Array(24).fill(0),
        "appHourly": {}
      };
      root.days = d;
    }
  }

  function _dateKey(d) {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  Process {
    id: ensureDirProcess
    command: ["mkdir", "-p", "--", root.stateDir]
    onExited: exitCode => {
      root._directoryReady = exitCode === 0;
      if (!root._directoryReady)
        Logger.e("ScreenTimeService", "Cannot create state directory:", root.stateDir);
      root._loadStorage();
    }
  }


  FileView {
    id: storageFileView
    path: root.stateFilePath
    preload: false
    blockLoading: true
    blockAllReads: true
    blockWrites: true
    atomicWrites: true
    printErrors: false
    onSaved: {
      root._saveInProgress = false;
      root._persistedText = root._savingText;
      root._lastSaveFailed = false;
      root.dirty = root._revision !== root._savingRevision;
      if (root.dirty && !persistDebounceTimer.running)
        persistDebounceTimer.start();
    }
    onSaveFailed: error => {
      root._saveInProgress = false;
      root._lastSaveFailed = true;
      root.dirty = true;
      if (!persistDebounceTimer.running)
        persistDebounceTimer.start();
      Logger.e("ScreenTimeService", "Failed to save screen usage:", error);
    }
  }

  FileView {
    id: legacyFileView
    preload: false
    blockLoading: true
    blockAllReads: true
    printErrors: false
  }

  function _loadStorage() {
    if (root.isLoaded)
      return;
    const state = storageFileView.text();
    if (state.trim() && root._loadData(state)) {
      root._persistedText = state;
      root._markDirty();
      root._persist();
      return;
    }
    const sources = [root.legacyCacheFilePath, root.legacyRaellFilePath];
    for (const path of sources) {
      legacyFileView.path = path;
      const legacy = legacyFileView.text();
      if (legacy.trim() && root._loadData(legacy)) {
        root._markDirty();
        root._persist();
        return;
      }
    }
    root._loadData("{}");
    root._markDirty();
    root._persist();
  }

  function _loadData(text) {
    try {
      const parsed = JSON.parse(text || "{}");
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
        return false;
      const source = parsed.days === undefined ? parsed : parsed.days;
      if (!source || typeof source !== "object" || Array.isArray(source))
        return false;
      const retained = root._pruneHistory(source);
      const normalized = {};
      for (const key of Object.keys(retained))
        normalized[key] = root._normalizeDay(retained[key]);
      root.days = normalized;
    } catch (e) {
      Logger.w("ScreenTimeService", "Cannot parse screen usage:", e);
      return false;
    }

    root.todayKey = root._dateKey(new Date());
    root._ensureTodayEntry();
    root._resetTracking();
    root.isLoaded = true;
    root.dataUpdated();
    return true;
  }

  function _seconds(value) {
    const number = Number(value);
    return Number.isFinite(number) && number > 0 ? number : 0;
  }

  function _hourBuckets(value) {
    const buckets = new Array(24).fill(0);
    if (value && typeof value === "object") {
      for (let hour = 0; hour < 24; hour++)
        buckets[hour] = root._seconds(value[hour]);
    }
    return buckets;
  }

  function _normalizeDay(source) {
    const apps = {};
    const appHourly = {};
    const hourly = root._hourBuckets(source.hourly);
    const sourceApps = source.apps && typeof source.apps === "object" ? source.apps : {};
    const sourceBuckets = source.appHourly && typeof source.appHourly === "object" ? source.appHourly : {};

    for (const rawId of Object.keys(sourceApps)) {
      const id = rawId.trim().toLowerCase();
      if (!id)
        continue;
      const value = sourceApps[rawId];
      const record = value && typeof value === "object" ? value : {};
      const seconds = root._seconds(typeof value === "number" ? value : record.seconds);
      const previous = apps[id];
      const entry = ThemeIcons.findAppEntry(id);
      apps[id] = {
        "id": id,
        "name": record.name || (previous && previous.name) || (entry && entry.name) || CompositorService.getCleanAppName(id, ""),
        "icon": record.icon || (previous && previous.icon) || ThemeIcons.iconForAppId(id),
        "title": record.title || (previous && previous.title) || "",
        "seconds": (previous ? previous.seconds : 0) + seconds
      };
    }
    for (const rawId of Object.keys(sourceBuckets)) {
      const id = rawId.trim().toLowerCase();
      if (!id)
        continue;
      const buckets = root._hourBuckets(sourceBuckets[rawId]);
      if (!appHourly[id])
        appHourly[id] = new Array(24).fill(0);
      for (let hour = 0; hour < 24; hour++)
        appHourly[id][hour] += buckets[hour];
      if (!apps[id]) {
        const entry = ThemeIcons.findAppEntry(id);
        apps[id] = {
          "id": id,
          "name": (entry && entry.name) || CompositorService.getCleanAppName(id, ""),
          "icon": ThemeIcons.iconForAppId(id),
          "title": "",
          "seconds": 0
        };
      }
    }

    let appTotal = 0;
    const attributedHourly = new Array(24).fill(0);
    for (const id of Object.keys(apps)) {
      const buckets = appHourly[id] || new Array(24).fill(0);
      appHourly[id] = buckets;
      let bucketTotal = 0;
      for (let hour = 0; hour < 24; hour++) {
        attributedHourly[hour] += buckets[hour];
        bucketTotal += buckets[hour];
      }
      apps[id].seconds = Math.max(apps[id].seconds, bucketTotal);
      appTotal += apps[id].seconds;
    }
    let hourlyTotal = 0;
    for (let hour = 0; hour < 24; hour++) {
      hourly[hour] = Math.max(hourly[hour], attributedHourly[hour]);
      hourlyTotal += hourly[hour];
    }
    // Missing legacy attribution cannot be reconstructed. Keep known totals and
    // known hour buckets rather than assigning old usage to an invented app/hour.
    return {
      "total": Math.max(root._seconds(source.total), appTotal, hourlyTotal),
      "apps": apps,
      "hourly": hourly,
      "appHourly": appHourly
    };
  }

  function _pruneHistory(daysObj) {
    const today = new Date();
    const oldest = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 29, 12);
    const oldestKey = root._dateKey(oldest);
    const newestKey = root._dateKey(today);
    const retained = {};
    for (const key of Object.keys(daysObj || {})) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(key) || key < oldestKey || key > newestKey)
        continue;
      const parts = key.split("-").map(Number);
      const date = new Date(parts[0], parts[1] - 1, parts[2], 12);
      const day = daysObj[key];
      if (root._dateKey(date) === key && day && typeof day === "object" && !Array.isArray(day))
        retained[key] = day;
    }
    return retained;
  }

  function _markDirty() {
    root._revision++;
    root.dirty = true;
    if (!persistDebounceTimer.running)
      persistDebounceTimer.start();
  }

  function _persist() {
    if (!root.isLoaded || !root.dirty || !root._directoryReady || root._saveInProgress)
      return;

    const dataStr = JSON.stringify({
      "version": 2,
      "days": root._pruneHistory(root.days)
    });
    // FileView.setText() does not emit saved when its text is unchanged.
    if (dataStr === root._persistedText) {
      root.dirty = false;
      return;
    }
    root._saveInProgress = true;
    root._savingRevision = root._revision;
    root._savingText = dataStr;
    try {
      // A failed FileView write still updates its cached text. Reload before a
      // retry so setText cannot mistake the failed payload for a completed save.
      if (root._lastSaveFailed) {
        storageFileView.reload();
        storageFileView.text();
        root._lastSaveFailed = false;
      }
      storageFileView.setText(dataStr);
    } catch (e) {
      root._saveInProgress = false;
      root._lastSaveFailed = true;
      root.dirty = true;
      if (!persistDebounceTimer.running)
        persistDebounceTimer.start();
      Logger.e("ScreenTimeService", "Failed to save screen usage:", e);
    }
  }

  function forceSave() {
    _tick();
    _persist();
  }


  function getTopApps(rangeDays, limit) {
    const range = Math.max(1, Math.min(30, Math.floor(Number(rangeDays) || 1)));
    const targetDate = new Date();
    const appMap = {};
    let totalSecs = 0;

    for (let i = 0; i < range; i++) {
      const d = new Date(targetDate);
      d.setDate(d.getDate() - i);
      const k = _dateKey(d);
      const day = root.days[k];
      if (!day)
        continue;

      totalSecs += Number(day.total || 0);
      const dayApps = day.apps || {};
      for (const id in dayApps) {
        const entry = dayApps[id];
        const sec = typeof entry === "number" ? entry : Number(entry.seconds || 0);
        if (sec <= 0 || _isExcludedApp(id))
          continue;

        if (!appMap[id]) {
          const appName = (typeof entry === "object" && entry.name) ? entry.name : CompositorService.getCleanAppName(id, "");
          const appIcon = (typeof entry === "object" && entry.icon) ? entry.icon : (ThemeIcons.iconForAppId ? ThemeIcons.iconForAppId(id) : "");
          const appTitle = (typeof entry === "object" && entry.title) ? entry.title : "";
          appMap[id] = {
            "id": id,
            "name": appName,
            "title": appTitle,
            "icon": appIcon,
            "seconds": 0
          };
        }
        appMap[id].seconds += sec;
      }
    }

    const appList = Object.values(appMap).sort((a, b) => b.seconds - a.seconds);
    for (let i = 0; i < appList.length; i++) {
      const item = appList[i];
      item.formatted = formatDuration(item.seconds);
      item.percent = totalSecs > 0 ? Math.round((item.seconds / totalSecs) * 100) : 0;
    }

    return (limit && limit > 0) ? appList.slice(0, limit) : appList;
  }

  function getWeeklyActivity() {
    const out = [];
    const now = new Date();
    let max = 1;

    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
      const k = _dateKey(d);
      const day = root.days[k];
      const tot = day ? Number(day.total || 0) : 0;
      max = Math.max(max, tot);

      let dayName = "";
      try {
        dayName = I18n.locale.dayName(d.getDay() || 7, Locale.ShortFormat).substring(0, 3);
      } catch (e) {
        dayName = Qt.locale().dayName(d.getDay() || 7, Locale.ShortFormat).substring(0, 3);
      }

      out.push({
        "dateKey": k,
        "dayLabel": dayName,
        "dayNumber": String(d.getDate()),
        "totalSeconds": tot,
        "formatted": formatDurationShort(tot),
        "isToday": i === 0,
        "total": tot
      });
    }

    for (let i = 0; i < out.length; i++) {
      out[i].ratio = Math.max(0, Math.min(1, out[i].totalSeconds / max));
    }
    return out;
  }

  function getRangeStats(rangeDays) {
    const range = Math.max(1, Math.min(30, Math.floor(Number(rangeDays) || 1)));
    const targetDate = new Date();
    const appMap = {};
    const hourly = new Array(24).fill(0);
    const dailyTrend = [];
    let totalSecs = 0;
    let activeDays = 0;

    for (let i = range - 1; i >= 0; i--) {
      const d = new Date(targetDate);
      d.setDate(d.getDate() - i);
      const k = _dateKey(d);
      const day = root.days[k] || {
        "total": 0,
        "apps": {},
        "hourly": new Array(24).fill(0)
      };
      const dayTotal = Number(day.total || 0);

      if (dayTotal > 0) {
        activeDays++;
        totalSecs += dayTotal;
      }

      const dayHourly = (day.hourly && day.hourly.length === 24) ? day.hourly : new Array(24).fill(0);
      for (let h = 0; h < 24; h++) {
        hourly[h] += Number(dayHourly[h] || 0);
      }

      const dayApps = day.apps || {};
      for (const id in dayApps) {
        const entry = dayApps[id];
        const sec = typeof entry === "number" ? entry : Number(entry.seconds || 0);
        if (sec <= 0 || _isExcludedApp(id))
          continue;

        if (!appMap[id]) {
          const appName = (typeof entry === "object" && entry.name) ? entry.name : CompositorService.getCleanAppName(id, "");
          const appIcon = (typeof entry === "object" && entry.icon) ? entry.icon : (ThemeIcons.iconForAppId ? ThemeIcons.iconForAppId(id) : "");
          const appTitle = (typeof entry === "object" && entry.title) ? entry.title : "";
          appMap[id] = {
            "id": id,
            "name": appName,
            "title": appTitle,
            "icon": appIcon,
            "seconds": 0
          };
        }
        appMap[id].seconds += sec;
      }

      let dayName = "";
      try {
        dayName = I18n.locale.dayName(d.getDay() || 7, Locale.ShortFormat).substring(0, 3);
      } catch (e) {
        dayName = Qt.locale().dayName(d.getDay() || 7, Locale.ShortFormat).substring(0, 3);
      }

      dailyTrend.push({
        "dateKey": k,
        "dayLabel": dayName,
        "dayNumber": String(d.getDate()),
        "totalSeconds": dayTotal,
        "formatted": formatDurationShort(dayTotal),
        "isToday": i === 0,
        "ratio": 0
      });
    }

    let maxDaily = 1;
    for (let i = 0; i < dailyTrend.length; i++) {
      maxDaily = Math.max(maxDaily, dailyTrend[i].totalSeconds);
    }
    for (let i = 0; i < dailyTrend.length; i++) {
      dailyTrend[i].ratio = Math.max(0, Math.min(1, dailyTrend[i].totalSeconds / maxDaily));
    }

    let maxHourly = 1;
    let peakH = 0;
    for (let h = 0; h < 24; h++) {
      if (hourly[h] > maxHourly) {
        maxHourly = hourly[h];
        peakH = h;
      }
    }
    const peakHourStr = maxHourly > 1 ? `${peakH}h - ${(peakH + 1) % 24}h` : "—";

    const appList = Object.values(appMap).sort((a, b) => b.seconds - a.seconds);
    for (let i = 0; i < appList.length; i++) {
      const item = appList[i];
      item.formatted = formatDuration(item.seconds);
      item.percent = totalSecs > 0 ? Math.round((item.seconds / totalSecs) * 100) : 0;
    }

    const avgSecs = totalSecs / range;

    return {
      "rangeDays": range,
      "totalSeconds": totalSecs,
      "totalFormatted": formatDuration(totalSecs),
      "appsCount": appList.length,
      "activeDaysCount": activeDays,
      "dailyAverageSeconds": avgSecs,
      "dailyAverageFormatted": formatDuration(avgSecs),
      "peakHour": peakH,
      "peakHourStr": peakHourStr,
      "hourlyDistribution": hourly,
      "maxHourlySeconds": maxHourly,
      "dailyTrend": dailyTrend,
      "topApps": appList
    };
  }

  function getMaxAppSeconds(apps) {
    let max = 1;
    if (apps && Array.isArray(apps)) {
      for (let i = 0; i < apps.length; i++)
        max = Math.max(max, Number(apps[i].seconds || 0));
    }
    return max;
  }


  function formatDuration(seconds, compact) {
    const total = Math.max(0, Math.round(Number(seconds || 0)));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;

    if (hours > 0) {
      return hours + "h " + String(minutes).padStart(2, "0") + "m";
    }
    if (minutes > 0) {
      return minutes + "m" + (compact ? "" : " " + String(secs).padStart(2, "0") + "s");
    }
    return total + "s";
  }

  function formatDurationShort(seconds) {
    const total = Math.max(0, Math.round(Number(seconds || 0)));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);

    if (hours > 0) {
      return hours + "h" + (minutes > 0 ? " " + minutes + "m" : "");
    }
    if (minutes > 0) {
      return minutes + "m";
    }
    return total + "s";
  }
}
