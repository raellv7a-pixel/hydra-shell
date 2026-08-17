pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  readonly property int class4kWidth: 3840
  readonly property int class4kHeight: 2160
  // How much smaller than the target the candidate must be before we bother
  // the user — avoids nagging over rounding-sized mismatches.
  readonly property real lowResTolerance: 0.95

  // -------------------------------------------------------------------
  // Capability detection (Vulkan runtime, waifu2x binary)
  // -------------------------------------------------------------------
  property bool vulkanChecked: false
  property bool vulkanAvailable: false
  property bool toolChecked: false
  property bool toolAvailable: false

  function probeCapabilities() {
    if (!vulkanChecked) {
      vulkanCheckProcess.running = true;
    }
    if (!toolChecked) {
      toolCheckProcess.running = true;
    }
  }

  Process {
    id: vulkanCheckProcess
    command: ["sh", "-c", "command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo --summary >/dev/null 2>&1"]
    onExited: exitCode => {
      root.vulkanAvailable = (exitCode === 0);
      root.vulkanChecked = true;
    }
  }

  // Callbacks waiting on the install currently in flight. Kept as lists so a
  // second ensureInstalled() while pacman runs joins the same install instead
  // of starting a competing pkexec prompt.
  property var _installReadyCallbacks: []
  property var _installFailedCallbacks: []
  property bool _awaitingInstallRecheck: false
  readonly property bool installing: installProcess.running || _awaitingInstallRecheck

  Process {
    id: toolCheckProcess
    command: ["sh", "-c", "command -v waifu2x-ncnn-vulkan"]
    stdout: StdioCollector {}
    onExited: exitCode => {
      root.toolAvailable = (exitCode === 0);
      root.toolChecked = true;

      if (!root._awaitingInstallRecheck) {
        return;
      }
      root._awaitingInstallRecheck = false;
      if (exitCode === 0) {
        root._resolveInstall(true, "");
      } else {
        root._resolveInstall(false, "waifu2x-ncnn-vulkan ainda não foi encontrado após a instalação.");
      }
    }
  }

  // -------------------------------------------------------------------
  // On-demand install via pacman, same pkexec pattern as
  // LockThemeService.applyTheme() — no custom polkit policy needed, pkexec
  // triggers whichever authentication agent is active (the shell's own
  // themed one, or the system default).
  // -------------------------------------------------------------------
  Process {
    id: installProcess
    command: ["pkexec", "pacman", "-S", "--noconfirm", "waifu2x-ncnn-vulkan"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => root._handleInstallFinished(exitCode, stderr.text)
  }

  function ensureInstalled(onReady, onFailed) {
    if (toolAvailable) {
      if (onReady) {
        onReady();
      }
      return;
    }

    if (onReady) {
      _installReadyCallbacks.push(onReady);
    }
    if (onFailed) {
      _installFailedCallbacks.push(onFailed);
    }

    if (installing) {
      Logger.d("WallpaperUpscale", "Install already in flight, joining it");
      return;
    }

    Logger.i("WallpaperUpscale", "waifu2x-ncnn-vulkan not found, installing via pkexec pacman");
    installProcess.running = true;
  }

  function _resolveInstall(success, error) {
    const ready = _installReadyCallbacks;
    const failed = _installFailedCallbacks;
    _installReadyCallbacks = [];
    _installFailedCallbacks = [];
    const callbacks = success ? ready : failed;
    for (let i = 0; i < callbacks.length; i++) {
      if (success) {
        callbacks[i]();
      } else {
        callbacks[i](error);
      }
    }
  }

  function _handleInstallFinished(exitCode, stderrText) {
    if (exitCode !== 0) {
      Logger.e("WallpaperUpscale", "Install failed:", stderrText);
      _resolveInstall(false, (stderrText || "").trim() || "pacman exited with code " + exitCode);
      return;
    }
    // Re-check so toolAvailable reflects reality before reporting success —
    // toolCheckProcess.onExited above resolves the pending callbacks.
    _awaitingInstallRecheck = true;
    toolCheckProcess.running = true;
  }

  // -------------------------------------------------------------------
  // Resolution helpers (pure, no I/O)
  // -------------------------------------------------------------------
  function targetPixelSize(screen) {
    const dpr = screen?.devicePixelRatio ?? 1.0;
    return {
      "width": Math.round((screen?.width ?? 0) * dpr),
      "height": Math.round((screen?.height ?? 0) * dpr)
    };
  }

  // "Recusa educada": uma imagem já classe 4K nunca aciona o aviso, não
  // importa a tela alvo — não há como ela ficar "borrada" na prática.
  function isLowRes(candidateWidth, candidateHeight, screen) {
    if (candidateWidth <= 0 || candidateHeight <= 0) {
      return false;
    }
    if (candidateWidth >= class4kWidth && candidateHeight >= class4kHeight) {
      return false;
    }
    const target = targetPixelSize(screen);
    if (target.width <= 0 || target.height <= 0) {
      return false;
    }
    return candidateWidth < target.width * lowResTolerance || candidateHeight < target.height * lowResTolerance;
  }

  // Smallest power-of-2 scale (waifu2x-ncnn-vulkan only accepts 1/2/4/8/16/32)
  // that covers the target, capped at 4 — beyond that the quality gain
  // rarely justifies the time.
  function recommendedScale(candidateWidth, candidateHeight, screen) {
    if (candidateWidth <= 0 || candidateHeight <= 0) {
      return 2;
    }
    const target = targetPixelSize(screen);
    const needed = Math.max(target.width / candidateWidth, target.height / candidateHeight, 1);
    var scale = 1;
    while (scale < needed && scale < 4) {
      scale *= 2;
    }
    return scale;
  }

  // Probes a local file's pixel dimensions asynchronously via a throwaway
  // Image — the only way to read image dimensions without shelling out.
  // Wallhaven candidates don't need this: their resolution is already in
  // the search result metadata.
  //
  // The probe is a pre-compiled component instantiated with the path as a
  // property, so nothing about the filename is ever parsed as QML. It always
  // settles exactly once (ready, error or timeout) and destroys itself, so a
  // source that never resolves can't strand the caller or leak the Image.
  Component {
    id: resolutionProbeComponent

    Image {
      id: probe

      property var onResolved: null
      property bool settled: false

      asynchronous: true
      visible: false
      // No sourceSize override: it must report the file's natural dimensions.

      function settle(w, h) {
        if (settled) {
          return;
        }
        settled = true;
        timeoutTimer.stop();
        const callback = onResolved;
        onResolved = null;
        if (callback) {
          callback(w, h);
        }
        Qt.callLater(() => probe.destroy());
      }

      function settleFromStatus() {
        if (status === Image.Ready) {
          settle(sourceSize.width, sourceSize.height);
        } else if (status === Image.Error) {
          Logger.w("WallpaperUpscale", "Resolution probe failed for", source);
          settle(0, 0);
        }
      }

      onStatusChanged: settleFromStatus()
      Component.onCompleted: settleFromStatus()

      Timer {
        id: timeoutTimer
        interval: 8000
        running: true
        repeat: false
        onTriggered: {
          Logger.w("WallpaperUpscale", "Resolution probe timed out for", probe.source);
          probe.settle(0, 0);
        }
      }
    }
  }

  function probeImageResolution(path, callback) {
    if (!path) {
      callback(0, 0);
      return;
    }
    const fileUrl = path.startsWith("/") ? "file://" + path : path;
    const probe = resolutionProbeComponent.createObject(root, {
                                                          "source": fileUrl,
                                                          "onResolved": callback
                                                        });
    if (!probe) {
      Logger.e("WallpaperUpscale", "probeImageResolution failed to create probe for", path);
      callback(0, 0);
    }
  }

  // -------------------------------------------------------------------
  // Upscale pipeline — probe -> prepare -> enhance -> assemble, mirroring
  // WallhavenService's staged-download Process pattern (one Process, one
  // command swap per stage).
  // -------------------------------------------------------------------
  // A single Process drives the pipeline, so only one upscale can run at a
  // time; a second request would silently retarget the running one.
  property bool upscaling: false

  function upscale(sourcePath, scale, onPhase, onDone, onError) {
    if (upscaling) {
      Logger.w("WallpaperUpscale", "Upscale already running, rejecting", sourcePath);
      if (onError) {
        onError("Já existe um upscale em andamento.");
      }
      return;
    }
    upscaling = true;
    upscaleProcess.sourcePath = sourcePath;
    upscaleProcess.scale = scale;
    upscaleProcess.onDoneCb = onDone;
    upscaleProcess.onErrorCb = onError;
    upscaleProcess.onPhaseCb = onPhase;
    upscaleProcess.stage = "probe";
    _runUpscaleStage(upscaleProcess, "probe");
  }

  function _runUpscaleStage(process, stage) {
    process.stage = stage;
    if (process.onPhaseCb) {
      process.onPhaseCb(stage);
    }
    Qt.callLater(() => {
                   if (process) {
                     process.running = true;
                   }
                 });
  }

  function _wallpaperDirectory() {
    var dir = Settings.preprocessPath(Settings.data.wallpaper.directory);
    if (!dir) {
      dir = Settings.defaultWallpapersDirectory;
    }
    while (dir.endsWith("/") && dir.length > 1) {
      dir = dir.slice(0, -1);
    }
    return dir;
  }

  function _outputPathFor(sourcePath, scale) {
    const base = sourcePath.split("/").pop().replace(/\.[^.]+$/, "");
    return _wallpaperDirectory() + "/" + base + "_waifu2x_x" + scale + ".png";
  }

  Process {
    id: upscaleProcess

    property string sourcePath: ""
    property int scale: 2
    property string stage: "probe"
    property string outputPath: ""
    property var onPhaseCb: null
    property var onDoneCb: null
    property var onErrorCb: null

    // argv arrays throughout — no shell-string interpolation of paths, so
    // wallpaper filenames with spaces/quotes/$ can't break or inject commands.
    command: {
      switch (stage) {
        case "probe":
        // Tool availability is already guaranteed by ensureInstalled() before
        // upscale() is ever called — this only needs to confirm the source
        // file is actually there.
        return ["test", "-f", sourcePath];
        case "prepare":
        return ["mkdir", "-p", "--", root._wallpaperDirectory()];
        case "enhance":
        return ["waifu2x-ncnn-vulkan", "-i", sourcePath, "-o", outputPath, "-s", String(scale), "-n", "0"];
        case "assemble":
        return ["test", "-s", outputPath];
        default:
        return [];
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0) {
        const detail = stderr.text ? stderr.text.trim() : ("Falha na fase " + stage);
        Logger.e("WallpaperUpscale", "Stage", stage, "failed:", detail);
        root.upscaling = false;
        if (onErrorCb) {
          onErrorCb(detail);
        }
        return;
      }

      if (stage === "probe") {
        outputPath = root._outputPathFor(sourcePath, scale);
        root._runUpscaleStage(this, "prepare");
      } else if (stage === "prepare") {
        root._runUpscaleStage(this, "enhance");
      } else if (stage === "enhance") {
        root._runUpscaleStage(this, "assemble");
      } else if (stage === "assemble") {
        Logger.i("WallpaperUpscale", "Upscale complete:", outputPath);
        root.upscaling = false;
        if (onDoneCb) {
          onDoneCb(outputPath);
        }
      }
    }
  }
}
