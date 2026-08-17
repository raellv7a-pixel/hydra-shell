pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons

// Event-driven PipeWire detection plus a slow, time-bounded video4linux probe.
// Camera consumers are not represented consistently in PipeWire, so checking
// open video device descriptors remains necessary.
Singleton {
  id: root

  property var pipewireNodes: []
  property var pipewireLinks: []

  readonly property var microphoneState: computeMicrophoneState(pipewireNodes, pipewireLinks)
  readonly property var cameraPipewireState: computeCameraPipewireState(pipewireNodes, pipewireLinks)
  readonly property var screenShareState: computeScreenShareState(pipewireNodes, pipewireLinks)
  readonly property var trackedPipewireObjects: collectTrackedObjects(pipewireNodes, pipewireLinks)

  property var directCameraApps: []
  property bool cameraBrokerOwnsDevice: false
  property string cameraProbeResult: "pending"

  readonly property bool micActive: microphoneState.active
  readonly property bool camActive: cameraPipewireState.active || directCameraApps.length > 0
  readonly property bool scrActive: screenShareState.active
  readonly property var micApps: microphoneState.apps
  readonly property var camApps: mergeNames(cameraPipewireState.apps, directCameraApps)
  readonly property var scrApps: screenShareState.apps

  // A broker-only V4L2 owner cannot be attributed to an application. Report
  // that limitation without claiming the camera is active.
  readonly property string cameraDetectionState: cameraProbeResult === "ready" && cameraBrokerOwnsDevice && !cameraPipewireState.active && directCameraApps.length === 0 ? "limited" : cameraProbeResult

  Component.onCompleted: refreshPipewireGraph()

  Connections {
    target: Pipewire

    function onReadyChanged() {
      root.refreshPipewireGraph();
    }
  }

  Connections {
    target: Pipewire.nodes

    function onValuesChanged() {
      root.refreshPipewireGraph();
    }
  }

  Connections {
    target: Pipewire.links

    function onValuesChanged() {
      root.refreshPipewireGraph();
    }
  }

  PwObjectTracker {
    objects: root.trackedPipewireObjects
  }

  Process {
    id: cameraDetectionProcess

    running: false
    command: ["timeout", "2s", "sh", "-c",
      "count=0; for sysdev in /sys/class/video4linux/video*; do [ -r \"$sysdev/name\" ] || continue; IFS= read -r name < \"$sysdev/name\" || continue; case \"$name\" in *Metadata*|*metadata*) continue ;; esac; dev=\"/dev/${sysdev##*/}\"; find /proc/[0-9]*/fd -maxdepth 1 -type l -lname \"$dev\" -print 2>/dev/null | while IFS=/ read -r _ proc pid rest; do [ -r \"/proc/$pid/comm\" ] && cat \"/proc/$pid/comm\"; done; count=$((count + 1)); [ \"$count\" -ge 8 ] && break; done; exit 0"]

    stdout: StdioCollector {
      id: cameraOutput
    }

    onExited: exitCode => {
      if (exitCode !== 0) {
        root.directCameraApps = [];
        root.cameraBrokerOwnsDevice = false;
        root.cameraProbeResult = exitCode === 124 ? "timeout" : "unavailable";
        return;
      }

      const names = String(cameraOutput.text || "").split("\n");
      const uniqueNames = [];
      var brokerDetected = false;
      for (var i = 0; i < names.length; i++) {
        const name = names[i].trim();
        if (!name)
          continue;
        if (isCameraBroker(name)) {
          brokerDetected = true;
          continue;
        }
        appendUnique(uniqueNames, name);
      }
      uniqueNames.sort();
      root.directCameraApps = uniqueNames;
      root.cameraBrokerOwnsDevice = brokerDetected;

      root.cameraProbeResult = "ready";
    }
  }

  // PipeWire changes propagate through model/property bindings above. Only the
  // video4linux fallback is polled: slowly while idle and a little faster while
  // an already detected camera consumer needs timely deactivation.
  Timer {
    interval: root.directCameraApps.length > 0 ? 3000 : 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!cameraDetectionProcess.running)
      cameraDetectionProcess.running = true;
    }
  }

  function refreshPipewireGraph() {
    if (!Pipewire.ready) {
      root.pipewireNodes = [];
      root.pipewireLinks = [];
      return;
    }

    root.pipewireNodes = Pipewire.nodes.values || [];
    root.pipewireLinks = Pipewire.links.values || [];
  }

  function collectTrackedObjects(nodes, links) {
    const objects = nodes.slice();
    for (var i = 0; i < links.length; i++) {
      const link = links[i];
      if (!link)
        continue;
      if (link.source && objects.indexOf(link.source) === -1)
        objects.push(link.source);
      if (link.target && objects.indexOf(link.target) === -1)
        objects.push(link.target);
    }
    return objects;
  }

  function linkIsActive(link) {
    return link && link.state === PwLinkState.Active;
  }

  function hasActiveNodeLinks(node, links) {
    for (var i = 0; i < links.length; i++) {
      const link = links[i];
      if (linkIsActive(link) && (link.source === node || link.target === node))
        return true;
    }
    return false;
  }

  function appendUnique(names, name) {
    if (name && names.indexOf(name) === -1)
      names.push(name);
  }

  function mergeNames(first, second) {
    const names = [];
    for (var i = 0; i < first.length; i++)
      appendUnique(names, first[i]);
    for (var j = 0; j < second.length; j++)
      appendUnique(names, second[j]);
    names.sort();
    return names;
  }

  function isCameraBroker(name) {
    const normalized = String(name || "").toLowerCase();
    return normalized === "pipewire" || normalized === "pipewire-pulse" || normalized === "wireplumber";
  }

  function getAppName(node) {
    const properties = node.properties || {};
    return properties["application.name"] || properties["application.process.binary"] || node.nickname || node.description || node.name || "";
  }

  function computeMicrophoneState(nodes, links) {
    const appNames = [];
    var active = false;

    for (var i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      if (!node || !node.isStream || !node.audio || node.isSink || !node.properties)
        continue;

      const mediaClass = String(node.type || node.properties["media.class"] || "");
      if (mediaClass !== "Stream/Input/Audio" || !hasActiveNodeLinks(node, links))
        continue;

      const capturesSink = node.properties["stream.capture.sink"];
      if (capturesSink === true || String(capturesSink || "").toLowerCase() === "true")
        continue;

      active = true;
      appendUnique(appNames, getAppName(node));
    }

    appNames.sort();
    return {
      "active": active,
      "apps": appNames
    };
  }

  function isCameraNode(node) {
    if (!node || !node.properties)
      return false;

    const properties = node.properties;
    const mediaClass = String(node.type || properties["media.class"] || "");
    const deviceApi = String(properties["device.api"] || "").toLowerCase();
    const devicePath = String(properties["api.v4l2.path"] || "");
    return mediaClass.indexOf("Video/Source") !== -1 && (deviceApi === "v4l2" || devicePath.indexOf("/dev/video") === 0);
  }

  function computeCameraPipewireState(nodes, links) {
    const appNames = [];
    var active = false;

    for (var i = 0; i < nodes.length; i++) {
      const cameraNode = nodes[i];
      if (!isCameraNode(cameraNode))
        continue;

      for (var j = 0; j < links.length; j++) {
        const link = links[j];
        if (!linkIsActive(link))
          continue;

        var peer = null;
        if (link.source === cameraNode)
          peer = link.target;
        else if (link.target === cameraNode)
          peer = link.source;
        else
          continue;

        active = true;
        if (peer)
          appendUnique(appNames, getAppName(peer));
      }
    }

    appNames.sort();
    return {
      "active": active,
      "apps": appNames
    };
  }

  function isScreenShareNode(node) {
    if (!node || !node.properties)
      return false;

    const properties = node.properties;
    const mediaClass = String(node.type || properties["media.class"] || "");
    if (mediaClass.indexOf("Video") === -1 || mediaClass.indexOf("Audio") !== -1)
      return false;

    // Physical/virtual V4L2 camera nodes must not light the screen-share icon.
    const deviceApi = String(properties["device.api"] || properties["api.v4l2.path"] || "").toLowerCase();
    if (deviceApi.indexOf("v4l2") !== -1)
      return false;

    const mediaRole = String(properties["media.role"] || "").toLowerCase();
    if (mediaRole === "screen" || mediaRole === "screen-capture" || mediaRole === "screencast")
      return true;

    const identity = [properties["media.name"], properties["node.name"], node.name, node.nickname, node.description].filter(value => value !== undefined && value !== null).join(" ").toLowerCase();

    return /(^|[ ._/-])(xdph-streaming|screencast|screen[- ]?cast|screen[- ]?capture|desktop[- ]?capture|monitor[- ]?capture|window[- ]?capture|game[- ]?capture|wayland[- ]?capture|gsr-default)([ ._/-]|$)/.test(identity);
  }

  function computeScreenShareState(nodes, links) {
    const appNames = [];
    var active = false;

    for (var i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      if (!node || !hasActiveNodeLinks(node, links) || !isScreenShareNode(node))
        continue;

      active = true;
      appendUnique(appNames, getAppName(node));
    }

    appNames.sort();
    return {
      "active": active,
      "apps": appNames
    };
  }
}
