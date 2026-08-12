import QtQuick
import Quickshell.Io
import qs.Services.UI

// Reads the metadata the preview pane shows for a local file: pixel size via
// the shared image probe, byte size and mtime via a single stat call. Results
// are tagged with a generation so answers for a superseded path are dropped.
Item {
  id: root

  property string path: ""

  property int pixelWidth: 0
  property int pixelHeight: 0
  property real fileBytes: 0
  property real modifiedEpoch: 0

  readonly property bool isLocalFile: path !== "" && path.startsWith("/")
  readonly property bool hasResolution: pixelWidth > 0 && pixelHeight > 0
  readonly property string resolutionText: hasResolution ? (pixelWidth + "x" + pixelHeight) : "—"

  property int _generation: 0

  visible: false

  onPathChanged: refresh()
  Component.onCompleted: refresh()

  function refresh() {
    pixelWidth = 0;
    pixelHeight = 0;
    fileBytes = 0;
    modifiedEpoch = 0;

    const generation = ++_generation;
    // Read `path` directly: the isLocalFile binding may not have been
    // re-evaluated yet when this runs from onPathChanged.
    const target = path;
    if (target === "" || !target.startsWith("/")) {
      return;
    }

    statProcess.targetPath = target;
    statProcess.generation = generation;
    // Restart on the next turn so a path change mid-run doesn't drop the
    // relaunch on the floor.
    Qt.callLater(() => {
                   statProcess.running = false;
                   statProcess.running = true;
                 });

    // Videos can't be decoded by the Image probe; their dimensions stay unknown.
    if (_isVideo(target)) {
      return;
    }
    WallpaperUpscaleService.probeImageResolution(target, function (width, height) {
      if (generation !== root._generation) {
        return;
      }
      root.pixelWidth = width;
      root.pixelHeight = height;
    });
  }

  function _isVideo(candidate) {
    const lower = String(candidate).toLowerCase();
    return lower.endsWith(".webm") || lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".mov");
  }

  Process {
    id: statProcess

    property string targetPath: ""
    property int generation: 0

    command: ["stat", "-c", "%s %Y", targetPath]
    stdout: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0 || generation !== root._generation) {
        return;
      }
      const parts = stdout.text.trim().split(/\s+/);
      if (parts.length < 2) {
        return;
      }
      root.fileBytes = parseFloat(parts[0]) || 0;
      root.modifiedEpoch = parseFloat(parts[1]) || 0;
    }
  }
}
