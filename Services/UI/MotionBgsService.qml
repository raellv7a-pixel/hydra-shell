pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property bool fetching: false
  property var currentResults: []
  property string lastError: ""
  property string currentQuery: ""
  property int currentPage: 1
  property var activeSearchProcess: null
  property var inFlightDownloads: ({})

  readonly property int pageSize: 24
  readonly property string baseUrl: "https://motionbgs.com"
  readonly property string userAgent: "Mozilla/5.0"

  signal searchCompleted(var results)
  signal searchFailed(string error)
  signal videoDownloaded(string videoId, string localPath)
  signal videoDownloadFailed(string videoId, string error)

  Component {
    id: searchProcessComponent

    Process {
      id: searchProcess

      property string requestQuery: ""
      property int requestPage: 1

      stdout: StdioCollector {}
      stderr: StdioCollector {}

      onExited: exitCode => root._handleSearchExit(searchProcess, exitCode)
    }
  }

  Component {
    id: downloadProcessComponent

    Process {
      id: downloadProcess

      property string videoId: ""
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
          return ["curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2", "--retry-delay", "1", "--connect-timeout", "15", "--max-time", "300", "--user-agent", root.userAgent, "--referer", root.baseUrl + "/", "--output", temporaryPath, url];
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

  function search(query, page) {
    const normalizedQuery = String(query || "").trim();
    const normalizedPage = Math.max(1, Number(page) || 1);

    if (activeSearchProcess) {
      const obsoleteProcess = activeSearchProcess;
      activeSearchProcess = null;
      obsoleteProcess.running = false;
      _destroyProcessLater(obsoleteProcess);
    }

    currentQuery = normalizedQuery;
    currentPage = normalizedPage;
    lastError = "";
    fetching = true;

    const process = searchProcessComponent.createObject(root, {
                                                          requestQuery: normalizedQuery,
                                                          requestPage: normalizedPage,
                                                          command: ["curl", "--fail", "--location", "--silent", "--show-error", "--compressed", "--connect-timeout", "15", "--max-time", "45", "--user-agent", userAgent, "--referer", baseUrl + "/", _searchUrl(normalizedQuery, normalizedPage)]
                                                        });
    if (!process) {
      _publishSearchFailure(I18n.tr("wallpaper.motionbgs.error-process"));
      return;
    }

    activeSearchProcess = process;
    process.running = true;
  }

  function _searchUrl(query, page) {
    let path = "/";
    if (query !== "") {
      const slug = query.toLowerCase().replace(/\s+/g, "-").replace(/^-+|-+$/g, "");
      path = "/tag:" + encodeURIComponent(slug) + "/";
    }
    if (page > 1) {
      path += page;
    }
    return baseUrl + path;
  }

  function _handleSearchExit(process, exitCode) {
    if (!process || process !== activeSearchProcess) {
      if (process) {
        _destroyProcessLater(process);
      }
      return;
    }

    activeSearchProcess = null;
    fetching = false;
    const output = process.stdout.text || "";
    const error = process.stderr.text.trim();
    _destroyProcessLater(process);

    if (exitCode !== 0) {
      if (error !== "") {
        Logger.e("MotionBGS", "Search failed:", error);
      }
      _publishSearchFailure(I18n.tr("wallpaper.motionbgs.error-network"));
      return;
    }

    const results = _parseResults(output);
    currentResults = results;
    lastError = "";
    searchCompleted(results);
  }

  function _parseResults(html) {
    const results = [];
    const seen = {};
    const posterPattern = /\/i\/c\/([0-9]+)x([0-9]+)\/media\/([0-9]+)\/([^"'<> ]+\.jpe?g)/gi;
    let match;

    while ((match = posterPattern.exec(html)) !== null && results.length < pageSize) {
      const width = Number(match[1]) || 0;
      const id = match[3];
      if (width < 300 || seen[id]) {
        continue;
      }
      seen[id] = true;

      const posterPath = match[0];
      const filename = match[4];
      const resolutionMatch = filename.match(/\.([0-9]+x[0-9]+)\.jpe?g$/i);
      let name = filename.replace(/\.jpe?g$/i, "").replace(/\.[0-9]+x[0-9]+$/i, "").replace(/[-_]+/g, " ");
      try {
        name = decodeURIComponent(name);
      } catch (decodeError) {
        Logger.w("MotionBGS", "Could not decode wallpaper name:", decodeError);
      }

      results.push({
                     id: id,
                     name: name,
                     thumb: baseUrl + posterPath,
                     video: baseUrl + "/dl/hd/" + id + "/",
                     dl: baseUrl + "/dl/4k/" + id + "/",
                     resolution: resolutionMatch ? resolutionMatch[1] : ""
                   });
    }

    return results;
  }

  function _publishSearchFailure(error) {
    fetching = false;
    lastError = error;
    currentResults = [];
    searchFailed(error);
  }

  function downloadVideo(item, callback) {
    const id = item && item.id ? String(item.id).replace(/[^0-9]/g, "") : "";
    const url = item && item.dl ? String(item.dl) : "";
    if (id === "" || !url.startsWith(baseUrl + "/")) {
      const error = I18n.tr("wallpaper.motionbgs.error-invalid-download");
      videoDownloadFailed(id, error);
      return;
    }

    const destinationDirectory = Quickshell.env("HOME") + "/Pictures/livewalls";
    const finalPath = destinationDirectory + "/motionbgs-" + id + ".mp4";
    const existing = inFlightDownloads[finalPath];
    if (existing) {
      if (callback) {
        existing.callbacks.push(callback);
      }
      return;
    }

    const process = downloadProcessComponent.createObject(root, {
                                                            videoId: id,
                                                            url: url,
                                                            destinationDirectory: destinationDirectory,
                                                            finalPath: finalPath,
                                                            temporaryPath: finalPath + ".part-" + Date.now(),
                                                            callbacks: callback ? [callback] : []
                                                          });
    if (!process) {
      videoDownloadFailed(id, I18n.tr("wallpaper.motionbgs.error-process"));
      return;
    }

    inFlightDownloads[finalPath] = process;
    process.running = true;
  }

  function _handleDownloadStage(process, exitCode) {
    if (!process) {
      return;
    }
    if (exitCode !== 0) {
      const detail = process.stderr.text.trim();
      if (detail !== "") {
        Logger.e("MotionBGS", "Download failed:", detail);
      }
      _finishDownload(process, false, I18n.tr("wallpaper.motionbgs.download-failed"));
      return;
    }

    if (process.stage === "mkdir") {
      _runDownloadStage(process, "download");
    } else if (process.stage === "download") {
      _runDownloadStage(process, "validate");
    } else if (process.stage === "validate") {
      const mimeType = process.stdout.text.trim();
      if (!mimeType.startsWith("video/")) {
        _finishDownload(process, false, I18n.tr("wallpaper.motionbgs.error-invalid-download"));
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
    const id = process.videoId;
    const finalPath = process.finalPath;
    const temporaryPath = process.temporaryPath;
    process.callbacks = [];
    delete inFlightDownloads[finalPath];

    if (!success) {
      Quickshell.execDetached(["rm", "-f", "--", temporaryPath]);
    }

    // Leave the Process.onExited stack before destroying the dynamic object.
    // Start consumers only on the following event-loop turn, after teardown.
    Qt.callLater(() => {
                   if (process) {
                     process.destroy();
                   }
                   Qt.callLater(() => {
                                  if (success) {
                                    videoDownloaded(id, finalPath);
                                  } else {
                                    videoDownloadFailed(id, error);
                                  }

                                  for (let index = 0; index < callbacks.length; index++) {
                                    try {
                                      callbacks[index](success ? finalPath : "");
                                    } catch (callbackError) {
                                      Logger.e("MotionBGS", "Download callback failed:", callbackError);
                                    }
                                  }
                                });
                 });
  }

  function _destroyProcessLater(process) {
    Qt.callLater(() => {
                   if (process) {
                     process.destroy();
                   }
                 });
  }
}
