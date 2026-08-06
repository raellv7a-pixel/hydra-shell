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

  signal searchCompleted(var results)
  signal searchFailed(string error)
  signal videoDownloaded(string videoId, string localPath)
  signal videoDownloadFailed(string videoId, string error)

  readonly property string searchScript: [
    "bash", "-c",
    "query=\"$1\"; page=\"${2:-1}\"; " +
    "mw=\"https://moewalls.com/wp-json/wp/v2/posts?per_page=24&page=${page}&_embed=1\"; " +
    "if [ -n \"$query\" ]; then mw=\"$mw&search=$(printf '%s' \"$query\" | jq -sRr @uri)\"; fi; " +
    "curl -fsSL -A 'Mozilla/5.0' \"$mw\" 2>/dev/null | jq -c '.[]? | (._embedded[\"wp:featuredmedia\"][0].source_url // \"\") as $thumb | ($thumb | sub(\"/uploads/(?<y>[0-9]{4})/[0-9]{2}/(?<b>[^/]+)-thumb\\\\.(jpe?g|png)\"; \"/uploads/preview/\\(.y)/\\(.b)-preview.webm\")) as $vid | {id: (.id|tostring), thumb: $thumb, video: $vid, dl: $vid, name: (.title.rendered | gsub(\" Live Wallpaper$\"; \"\"))}' 2>/dev/null"
  ].join(" ")

  Process {
    id: searchProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      root.fetching = false;
      var outText = searchProc.stdout.text.trim();
      var errText = searchProc.stderr.text.trim();
      if (exitCode === 0 && outText.length > 0) {
        var lines = outText.split("\n");
        var items = [];
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (line.length > 0) {
            try {
              items.push(JSON.parse(line));
            } catch (e) {}
          }
        }
        root.currentResults = items;
        root.searchCompleted(items);
      } else {
        root.lastError = errText || "Nenhum resultado encontrado";
        root.searchFailed(root.lastError);
      }
    }
  }

  function search(query, page) {
    if (fetching) return;
    fetching = true;
    currentQuery = query || "";
    currentPage = page || 1;
    lastError = "";

    var cmdStr = "query='" + currentQuery.replace(/'/g, "'\\''") + "'; page='" + currentPage + "'; " +
      "mw=\"https://moewalls.com/wp-json/wp/v2/posts?per_page=20&page=${page}&_embed=1\"; " +
      "if [ -n \"$query\" ]; then qenc=$(printf '%s' \"$query\" | jq -sRr @uri); mw=\"https://moewalls.com/wp-json/wp/v2/posts?per_page=20&page=${page}&search=${qenc}&_embed=1\"; fi; " +
      "curl -fsSL -A 'Mozilla/5.0' \"$mw\" 2>/dev/null | jq -c '.[]? | (._embedded[\"wp:featuredmedia\"][0].source_url // \"\") as $thumb | ($thumb | sub(\"/uploads/(?<y>[0-9]{4})/[0-9]{2}/(?<b>[^/]+)-thumb\\\\.(jpe?g|png)\"; \"/uploads/preview/\\(.y)/\\(.b)-preview.webm\")) as $vid | {id: (.id|tostring), thumb: $thumb, video: $vid, dl: $vid, name: (.title.rendered | gsub(\" Live Wallpaper$\"; \"\"))}' 2>/dev/null";

    searchProc.command = ["bash", "-c", cmdStr];
    searchProc.running = true;
  }

  function downloadVideo(item, callback) {
    if (!item || !item.dl) return;
    var destDir = Quickshell.env("HOME") + "/Pictures/livewalls";
    var filename = "moewalls-" + item.id + ".webm";
    var outPath = destDir + "/" + filename;

    var dlProc = Qt.createQmlObject(`
      import Quickshell.Io
      Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `, root, "DownloadProc_" + item.id);

    var dlCmdStr = "mkdir -p '" + destDir + "' && curl -fsSL -A 'Mozilla/5.0' '" + item.dl.replace(/'/g, "'\\''") + "' -o '" + outPath + "' && [ -s '" + outPath + "' ] && echo '" + outPath + "'";
    dlProc.command = ["bash", "-c", dlCmdStr];
    dlProc.exited.connect(function(code) {
      if (code === 0 && dlProc.stdout.text.trim().length > 0) {
        if (callback) callback(outPath);
        root.videoDownloaded(item.id, outPath);
      } else {
        if (callback) callback("");
        root.videoDownloadFailed(item.id, I18n.tr("wallpaper.live-video.download-failed"));
      }
      dlProc.destroy();
    });
    dlProc.running = true;
  }
}
