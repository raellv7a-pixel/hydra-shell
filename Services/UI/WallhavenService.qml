pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property bool fetching: false
  property var currentResults: []
  property var currentMeta: ({})
  property string lastError: ""
  property string currentQuery: ""
  property int currentPage: 1
  property int lastPage: 1
  property int retrySeconds: 0

  property string categories: "111"
  property string purity: "100"
  property string sorting: "relevance"
  property string order: "desc"
  property string topRange: "1M"
  property string seed: ""
  property string minResolution: ""
  property string resolutions: ""
  property string ratios: ""
  property string colors: ""

  readonly property string envApiKey: Quickshell.env("HYDRA_WALLHAVEN_API_KEY") || ""
  readonly property string apiKey: envApiKey !== "" ? envApiKey : (Settings.data.wallpaper.wallhavenApiKey || "")
  readonly property bool apiKeyManagedByEnv: envApiKey !== ""
  readonly property string apiBaseUrl: "https://wallhaven.cc/api/v1"

  property var pendingSearch: null
  property var retrySearch: null
  property var activeXhr: null
  property int requestGeneration: 0
  property var searchCache: ({})
  property var searchCacheOrder: []
  readonly property int searchCacheTtlMs: 120000
  readonly property int maxSearchCacheEntries: 24

  property var inFlightDownloads: ({})
  property int downloadRevision: 0
  property int activeDownloadCount: 0

  signal searchCompleted(var results, var meta)
  signal searchFailed(string error)
  signal searchRetryScheduled(int seconds)
  signal wallpaperDownloadStarted(string wallpaperId)
  signal wallpaperDownloaded(string wallpaperId, string localPath)
  signal wallpaperDownloadFailed(string wallpaperId, string error)

  onApiKeyChanged: clearSearchCache()

  Timer {
    id: retryTimer
    repeat: false
    onTriggered: {
      root.retrySeconds = 0;
      root.fetching = false;
      if (root.pendingSearch) {
        root.retrySearch = null;
      } else if (root.retrySearch) {
        root.pendingSearch = root.retrySearch;
        root.retrySearch = null;
      }
      root._startNextSearch();
    }
  }

  Timer {
    id: retryCountdownTimer
    interval: 1000
    repeat: true
    running: root.retrySeconds > 0
    onTriggered: root.retrySeconds = Math.max(0, root.retrySeconds - 1)
  }

  Component {
    id: downloadProcessComponent

    Process {
      id: downloadProcess

      property string wallpaperId: ""
      property string url: ""
      property string destinationDirectory: ""
      property string finalPath: ""
      property string temporaryPath: ""
      property string stage: "mkdir"
      property var callbacks: []

      command: {
        switch (stage) {
          case "mkdir":
          return ["mkdir", "-p", "--", destinationDirectory];
          case "download":
          return ["curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2", "--retry-delay", "1", "--connect-timeout", "15", "--max-time", "180", "--output", temporaryPath, url];
          case "validate":
          return ["file", "--brief", "--mime-type", "--", temporaryPath];
          case "commit":
          return ["mv", "--force", "--", temporaryPath, finalPath];
          default:
          return [];
        }
      }

      stdout: StdioCollector {}
      stderr: StdioCollector {}

      onExited: exitCode => root._handleDownloadStage(downloadProcess, exitCode)
    }
  }

  function syncFromSettings() {
    const normalizedCategories = _normalizeBinaryFilter(Settings.data.wallpaper.wallhavenCategories, "111");
    const normalizedPurity = _normalizeBinaryFilter(Settings.data.wallpaper.wallhavenPurity, "100");
    if (Settings.data.wallpaper.wallhavenCategories !== normalizedCategories) {
      Settings.data.wallpaper.wallhavenCategories = normalizedCategories;
    }
    if (Settings.data.wallpaper.wallhavenPurity !== normalizedPurity) {
      Settings.data.wallpaper.wallhavenPurity = normalizedPurity;
    }
    categories = normalizedCategories;
    purity = normalizedPurity;
    sorting = Settings.data.wallpaper.wallhavenSorting || "relevance";
    order = Settings.data.wallpaper.wallhavenOrder || "desc";
    topRange = Settings.data.wallpaper.wallhavenTopRange || "1M";
    ratios = Settings.data.wallpaper.wallhavenRatios || "";
    colors = Settings.data.wallpaper.wallhavenColors || "";

    const width = Settings.data.wallpaper.wallhavenResolutionWidth || "";
    const height = Settings.data.wallpaper.wallhavenResolutionHeight || "";
    const mode = Settings.data.wallpaper.wallhavenResolutionMode || "atleast";
    if (width && height) {
      const resolution = width + "x" + height;
      minResolution = mode === "atleast" ? resolution : "";
      resolutions = mode === "exact" ? resolution : "";
    } else {
      minResolution = "";
      resolutions = "";
    }
  }

  function search(query, page, forceRefresh) {
    const request = _createSearchRequest(query, page, forceRefresh === true);
    pendingSearch = request;
    lastError = "";

    if (retryTimer.running) {
      retryTimer.stop();
      retrySearch = null;
      retrySeconds = 0;
      fetching = false;
    }

    // A newer query supersedes whatever is in flight — drop the socket instead
    // of keeping it open (and parsing its payload) for a discarded result.
    if (fetching) {
      _abortActiveRequest();
    }

    if (!fetching) {
      _startNextSearch();
    }
  }

  // Cancels the in-flight request, if any, and leaves the service idle.
  // Bumping the generation makes any late readyState callback a no-op.
  function _abortActiveRequest() {
    requestGeneration++;
    const xhr = activeXhr;
    activeXhr = null;
    fetching = false;
    if (xhr) {
      xhr.onreadystatechange = function () {};
      xhr.abort();
    }
  }

  function refresh() {
    search(currentQuery, currentPage, true);
  }

  function _createSearchRequest(query, page, forceRefresh) {
    return {
      query: query || "",
      page: Math.max(1, Number(page) || 1),
      categories: _normalizeBinaryFilter(categories, "111"),
      purity: _normalizeBinaryFilter(purity, "100"),
      sorting: sorting || "relevance",
      order: order || "desc",
      topRange: topRange || "1M",
      seed: sorting === "random" && Math.max(1, Number(page) || 1) > 1 ? (seed || "") : "",
      minResolution: minResolution || "",
      resolutions: resolutions || "",
      ratios: ratios || "",
      colors: colors || "",
      authenticated: apiKey !== "",
      forceRefresh: forceRefresh,
      attempt: 0
    };
  }

  function _normalizeBinaryFilter(value, fallback) {
    const normalized = String(value || "");
    return normalized === "000" || normalized.length !== 3 ? fallback : normalized;
  }

  function _startNextSearch() {
    if (fetching || !pendingSearch) {
      return;
    }

    const request = pendingSearch;
    pendingSearch = null;
    const cacheKey = _cacheKey(request);
    const cached = !request.forceRefresh ? _cacheGet(cacheKey) : null;
    if (cached) {
      _publishSearchSuccess(request, cached.results, cached.meta);
      if (pendingSearch) {
        Qt.callLater(root._startNextSearch);
      }
      return;
    }

    fetching = true;
    retrySeconds = 0;
    const generation = ++requestGeneration;
    const url = _buildSearchUrl(request);
    Logger.d("Wallhaven", "Searching page", request.page, "for", request.query || "<latest>");

    const xhr = new XMLHttpRequest();
    activeXhr = xhr;
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE || generation !== root.requestGeneration) {
        return;
      }
      root.activeXhr = null;
      root._handleSearchResponse(request, cacheKey, xhr);
    };
    xhr.open("GET", url);
    if (apiKey !== "") {
      xhr.setRequestHeader("X-API-Key", apiKey);
    }
    xhr.send();
  }

  function _buildSearchUrl(request) {
    const params = [];
    if (request.query) {
      params.push("q=" + encodeURIComponent(request.query));
    }
    params.push("categories=" + request.categories);
    params.push("purity=" + request.purity);
    params.push("sorting=" + request.sorting);
    params.push("order=" + request.order);
    if (request.sorting === "toplist") {
      params.push("topRange=" + request.topRange);
    }
    if (request.sorting === "random" && request.seed && request.page > 1) {
      params.push("seed=" + request.seed);
    }
    if (request.minResolution) {
      params.push("atleast=" + request.minResolution);
    }
    if (request.resolutions) {
      params.push("resolutions=" + request.resolutions);
    }
    if (request.ratios) {
      params.push("ratios=" + request.ratios);
    }
    if (request.colors) {
      params.push("colors=" + request.colors);
    }
    params.push("page=" + request.page);
    return apiBaseUrl + "/search?" + params.join("&");
  }

  function _handleSearchResponse(request, cacheKey, xhr) {
    if (pendingSearch) {
      fetching = false;
      _startNextSearch();
      return;
    }

    if (xhr.status === 200) {
      try {
        const response = JSON.parse(xhr.responseText);
        if (!response.data || !Array.isArray(response.data)) {
          _publishSearchFailure(I18n.tr("wallpaper.wallhaven.error-invalid-response"));
          return;
        }
        const meta = response.meta || {};
        _cachePut(cacheKey, response.data, meta);
        _publishSearchSuccess(request, response.data, meta);
      } catch (error) {
        Logger.e("Wallhaven", "Failed to parse API response:", error);
        _publishSearchFailure(I18n.tr("wallpaper.wallhaven.error-invalid-response"));
      }
      return;
    }

    const retriable = xhr.status === 0 || xhr.status === 429 || xhr.status >= 500;
    if (retriable && request.attempt < 2) {
      request.attempt++;
      retrySearch = request;
      const retryAfterHeader = xhr.getResponseHeader("Retry-After");
      const retryAfter = retryAfterHeader ? Number(retryAfterHeader) : NaN;
      const delayMs = xhr.status === 429 ? Math.max(1000, (isNaN(retryAfter) ? 60 : retryAfter) * 1000) : Math.min(8000, 1000 * Math.pow(2, request.attempt - 1));
      retrySeconds = Math.ceil(delayMs / 1000);
      retryTimer.interval = delayMs;
      retryTimer.restart();
      searchRetryScheduled(retrySeconds);
      return;
    }

    if (xhr.status === 429) {
      _publishSearchFailure(I18n.tr("wallpaper.wallhaven.error-rate-limit"));
    } else if (xhr.status === 401) {
      _publishSearchFailure(I18n.tr("wallpaper.wallhaven.error-api-key"));
    } else if (xhr.status === 0) {
      _publishSearchFailure(I18n.tr("wallpaper.wallhaven.error-network"));
    } else {
      _publishSearchFailure(I18n.tr("wallpaper.wallhaven.error-api", {
                                      status: xhr.status
                                    }));
    }
  }

  function _publishSearchSuccess(request, results, meta) {
    fetching = false;
    lastError = "";
    currentQuery = request.query;
    currentResults = results;
    currentMeta = meta || {};
    currentPage = Number(currentMeta.current_page) || request.page;
    lastPage = Number(currentMeta.last_page) || 1;
    if (currentMeta.seed) {
      seed = currentMeta.seed;
    }
    searchCompleted(currentResults, currentMeta);
  }

  function _publishSearchFailure(error) {
    fetching = false;
    retrySeconds = 0;
    lastError = error;
    Logger.e("Wallhaven", error);
    searchFailed(error);
  }

  function _cacheKey(request) {
    return JSON.stringify([request.query, request.page, request.categories, request.purity, request.sorting, request.order, request.topRange, request.sorting === "random" ? request.seed : "", request.minResolution, request.resolutions, request.ratios, request.colors, request.authenticated]);
  }

  function _cacheGet(key) {
    const entry = searchCache[key];
    if (!entry || Date.now() - entry.timestamp > searchCacheTtlMs) {
      if (entry) {
        _cacheDrop(key);
      }
      return null;
    }
    return entry;
  }

  // Always drop from both the map and the FIFO order — leaving a dangling key
  // in searchCacheOrder makes the eviction shift() free nothing.
  function _cacheDrop(key) {
    delete searchCache[key];
    const index = searchCacheOrder.indexOf(key);
    if (index >= 0) {
      searchCacheOrder.splice(index, 1);
    }
  }

  function _cachePut(key, results, meta) {
    searchCache[key] = {
      timestamp: Date.now(),
      results: results,
      meta: meta
    };
    const existingIndex = searchCacheOrder.indexOf(key);
    if (existingIndex >= 0) {
      searchCacheOrder.splice(existingIndex, 1);
    }
    searchCacheOrder.push(key);
    while (searchCacheOrder.length > maxSearchCacheEntries) {
      const staleKey = searchCacheOrder.shift();
      delete searchCache[staleKey];
    }
  }

  function clearSearchCache() {
    searchCache = {};
    searchCacheOrder = [];
  }

  function getWallpaperUrl(wallpaper) {
    if (wallpaper && wallpaper.path) {
      return wallpaper.path;
    }
    if (wallpaper && wallpaper.id) {
      const idPrefix = wallpaper.id.substring(0, 2);
      const extension = _wallpaperExtension(wallpaper, "");
      return "https://w.wallhaven.cc/full/" + idPrefix + "/wallhaven-" + wallpaper.id + "." + extension;
    }
    return "";
  }

  function getThumbnailUrl(wallpaper, size) {
    if (wallpaper && wallpaper.thumbs && wallpaper.thumbs[size]) {
      return wallpaper.thumbs[size];
    }
    if (wallpaper && wallpaper.id) {
      const idPrefix = wallpaper.id.substring(0, 2);
      const sizeMap = {
        small: "small",
        large: "lg",
        original: "orig"
      };
      return "https://th.wallhaven.cc/" + (sizeMap[size] || "lg") + "/" + idPrefix + "/" + wallpaper.id + ".jpg";
    }
    return "";
  }

  function downloadWallpaper(wallpaper, callback) {
    const url = getWallpaperUrl(wallpaper || {});
    const wallpaperId = wallpaper && wallpaper.id ? String(wallpaper.id).replace(/[^a-zA-Z0-9_-]/g, "") : "";
    if (!url || !wallpaperId) {
      if (callback) {
        callback(false, "");
      }
      return;
    }

    let wallpaperDirectory = Settings.preprocessPath(Settings.data.wallpaper.directory);
    if (!wallpaperDirectory) {
      wallpaperDirectory = Settings.defaultWallpapersDirectory;
    }
    while (wallpaperDirectory.endsWith("/") && wallpaperDirectory.length > 1) {
      wallpaperDirectory = wallpaperDirectory.slice(0, -1);
    }

    const extension = _wallpaperExtension(wallpaper, url);
    const localPath = wallpaperDirectory + "/wallhaven_" + wallpaperId + "." + extension;
    const existing = inFlightDownloads[localPath];
    if (existing) {
      if (callback) {
        existing.callbacks.push(callback);
      }
      return;
    }

    const temporaryPath = localPath + ".part-" + Date.now();
    const process = downloadProcessComponent.createObject(root, {
                                                            wallpaperId: wallpaperId,
                                                            url: url,
                                                            destinationDirectory: wallpaperDirectory,
                                                            finalPath: localPath,
                                                            temporaryPath: temporaryPath,
                                                            callbacks: callback ? [callback] : []
                                                          });
    if (!process) {
      if (callback) {
        callback(false, "");
      }
      wallpaperDownloadFailed(wallpaperId, "Unable to create download process.");
      return;
    }

    inFlightDownloads[localPath] = process;
    activeDownloadCount++;
    downloadRevision++;
    wallpaperDownloadStarted(wallpaperId);
    process.running = true;
  }

  function isDownloading(wallpaperId) {
    const revision = downloadRevision;
    const keys = Object.keys(inFlightDownloads);
    for (let index = 0; index < keys.length; index++) {
      const process = inFlightDownloads[keys[index]];
      if (process && process.wallpaperId === wallpaperId) {
        return true;
      }
    }
    return false;
  }

  function _wallpaperExtension(wallpaper, url) {
    const mime = wallpaper && wallpaper.file_type ? String(wallpaper.file_type).toLowerCase() : "";
    if (mime === "image/png") {
      return "png";
    }
    if (mime === "image/webp") {
      return "webp";
    }
    const match = String(url || "").match(/\.([a-zA-Z0-9]+)(?:\?|$)/);
    if (match && ["jpg", "jpeg", "png", "webp"].includes(match[1].toLowerCase())) {
      return match[1].toLowerCase() === "jpeg" ? "jpg" : match[1].toLowerCase();
    }
    return "jpg";
  }

  function _handleDownloadStage(process, exitCode) {
    if (!process) {
      return;
    }
    if (exitCode !== 0) {
      const detail = process.stderr && process.stderr.text ? process.stderr.text.trim() : "";
      _finishDownload(process, false, detail || "Download failed during " + process.stage + ".");
      return;
    }

    if (process.stage === "mkdir") {
      _runDownloadStage(process, "download");
    } else if (process.stage === "download") {
      _runDownloadStage(process, "validate");
    } else if (process.stage === "validate") {
      const mime = process.stdout && process.stdout.text ? process.stdout.text.trim() : "";
      if (!mime.startsWith("image/")) {
        _finishDownload(process, false, "Downloaded file is not a valid image.");
        return;
      }
      _runDownloadStage(process, "commit");
    } else if (process.stage === "commit") {
      _finishDownload(process, true, "");
    }
  }

  function _runDownloadStage(process, stage) {
    process.stage = stage;
    Qt.callLater(() => {
                   if (process) {
                     process.running = true;
                   }
                 });
  }

  function _finishDownload(process, success, error) {
    const callbacks = process.callbacks ? process.callbacks.slice() : [];
    const wallpaperId = process.wallpaperId;
    const finalPath = process.finalPath;
    const temporaryPath = process.temporaryPath;
    delete inFlightDownloads[finalPath];
    activeDownloadCount = Math.max(0, activeDownloadCount - 1);
    downloadRevision++;

    if (!success) {
      Quickshell.execDetached(["rm", "-f", "--", temporaryPath]);
      Logger.e("Wallhaven", "Wallpaper download failed:", error);
    }

    // Leave the Process.onExited stack before destroying the dynamic object.
    // Start consumers only on the following event-loop turn, after teardown.
    Qt.callLater(() => {
                   if (process) {
                     process.destroy();
                   }
                   Qt.callLater(() => {
                                  if (success) {
                                    wallpaperDownloaded(wallpaperId, finalPath);
                                  } else {
                                    wallpaperDownloadFailed(wallpaperId, error);
                                  }

                                  for (let index = 0; index < callbacks.length; index++) {
                                    try {
                                      callbacks[index](success, success ? finalPath : "");
                                    } catch (callbackError) {
                                      Logger.e("Wallhaven", "Download callback failed:", callbackError);
                                    }
                                  }
                                });
                 });
  }

  function reset() {
    _abortActiveRequest();
    retryTimer.stop();
    pendingSearch = null;
    retrySearch = null;
    fetching = false;
    retrySeconds = 0;
    currentResults = [];
    currentMeta = {};
    currentQuery = "";
    currentPage = 1;
    lastPage = 1;
    seed = "";
    lastError = "";
    clearSearchCache();
  }

  function nextPage() {
    if (currentPage < lastPage) {
      search(currentQuery, currentPage + 1);
    }
  }

  function previousPage() {
    if (currentPage > 1) {
      search(currentQuery, currentPage - 1);
    }
  }
}
