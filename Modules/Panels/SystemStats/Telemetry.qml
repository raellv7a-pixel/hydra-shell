import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System

QtObject {
  id: root

  property bool active: false
  property bool gpuActive: false
  readonly property int intervalMs: 3000
  readonly property int historyDurationMs: 180000
  readonly property var data: root._data
  readonly property var gpuUsageHistory: root._samples.map(sample => sample.usage)
  readonly property var gpuTempHistory: root._samples.map(sample => sample.temp)
  readonly property var gpuPowerHistory: root._samples.map(sample => sample.power)
  readonly property var gpuVramHistory: root._samples.map(sample => sample.vram)
  property int cpuSamples: 0
  property int temperatureSamples: 0
  property int memorySamples: 0
  property int rxSamples: 0
  property int txSamples: 0
  property Connections systemHistory: Connections {
    target: SystemStatService
    function onCpuHistoryChanged() {
      if (root.active)
        root.cpuSamples = Math.min(root.cpuSamples + 1, SystemStatService.cpuHistory.length);
    }
    function onCpuTempHistoryChanged() {
      if (root.active)
        root.temperatureSamples = Math.min(root.temperatureSamples + 1, SystemStatService.cpuTempHistory.length);
    }
    function onMemHistoryChanged() {
      if (root.active)
        root.memorySamples = Math.min(root.memorySamples + 1, SystemStatService.memHistory.length);
    }
    function onRxSpeedHistoryChanged() {
      if (root.active)
        root.rxSamples = Math.min(root.rxSamples + 1, SystemStatService.rxSpeedHistory.length);
    }
    function onTxSpeedHistoryChanged() {
      if (root.active)
        root.txSamples = Math.min(root.txSamples + 1, SystemStatService.txSpeedHistory.length);
    }
  }

  property var _data: ({
                         cpuName: "",
                         uptime: null,
                         memCacheGb: null,
                         processes: [],
                         gpu: null
                       })
  property var _samples: []
  property int _generation: 0
  property int _requestGeneration: -1
  property bool _busy: false
  property bool _ready: false
  property bool _requestGpu: false
  property double _lastSampleTime: 0

  readonly property bool _allowDgpu: Settings.data.systemMonitor.enableDgpuMonitoring
  readonly property string _gpuType: SystemStatService.gpuType
  readonly property string _hwmon: SystemStatService.gpuTempHwmonPath
  readonly property bool _integrated: {
    if (root._gpuType !== "amd")
      return false;
    const sensors = SystemStatService.foundGpuSensors;
    for (let index = 0; index < sensors.length; ++index) {
      const sensor = sensors[index];
      if (sensor.type === "amd" && sensor.hwmonPath === root._hwmon)
        return sensor.hasDedicatedVram === false;
    }
    return false;
  }
  readonly property bool _gpuEnabled: root.active && root.gpuActive && SystemStatService.gpuAvailable && (root._allowDgpu || root._integrated) && (root._gpuType === "nvidia" || ((root._gpuType === "amd" || root._gpuType === "intel") && root._hwmon !== ""))
  readonly property string _collectionKey: !root.active ? "" : root._gpuEnabled ? [root._gpuType, root._hwmon, root._allowDgpu, root._integrated].join("|") : "system"

  function clearGpu() {
    root._data = Object.assign({}, root._data, {
                                 gpu: null
                               });
    root._samples = [];
    root._lastSampleTime = 0;
  }

  function restartCollection() {
    if (!root._ready)
      return;
    ++root._generation;
    root.clearGpu();
    if (root._busy) {
      collector.signal(15);
    } else if (root.active) {
      root.collect();
    }
  }

  function collect() {
    if (!root.active || root._busy)
      return;
    const command = ["python3", Quickshell.shellDir + "/Scripts/python/system_telemetry.py"];
    root._requestGpu = root._gpuEnabled;
    if (root._requestGpu) {
      command.push("--gpu-type", root._gpuType);
      if (root._hwmon !== "")
        command.push("--hwmon", root._hwmon);
      if (root._allowDgpu)
        command.push("--allow-dgpu");
      else if (root._integrated)
        command.push("--integrated");
    }
    root._requestGeneration = root._generation;
    root._busy = true;
    collector.command = command;
    collector.running = true;
  }

  function appendHistory(gpu) {
    const now = Date.now();
    const cutoff = now - root.historyDurationMs;
    let samples = root._samples.filter(sample => sample.time > cutoff);
    if (root._lastSampleTime > 0) {
      // Keep elapsed time honest after a delayed poll; missing intervals are gaps, not zeroes.
      const missing = Math.min(Math.floor(root.historyDurationMs / root.intervalMs) - 1, Math.max(0, Math.floor((now - root._lastSampleTime) / root.intervalMs) - 1));
      for (let index = missing; index > 0; --index)
        samples.push({
                       time: now - index * root.intervalMs,
                       usage: null,
                       temp: null,
                       power: null,
                       vram: null
                     });
    }
    samples.push({
                   time: now,
                   usage: gpu.usage,
                   temp: gpu.temp,
                   power: gpu.power,
                   vram: gpu.vramTotalMiB > 0 && gpu.vramUsedMiB !== null ? gpu.vramUsedMiB / gpu.vramTotalMiB * 100 : null
                 });
    root._samples = samples.slice(-Math.ceil(root.historyDurationMs / root.intervalMs));
    root._lastSampleTime = now;
  }

  function finishCollection(exitCode) {
    root._busy = false;
    if (root._requestGeneration !== root._generation) {
      if (root.active)
        Qt.callLater(root.collect);
      return;
    }
    if (!root.active)
      return;
    if (exitCode !== 0) {
      root.clearGpu();
      return;
    }
    try {
      const result = JSON.parse(collectorOutput.text);
      if (!result || typeof result.cpuName !== "string" || !Array.isArray(result.processes))
        throw new Error("Invalid telemetry response");
      if (!root._requestGpu || !root._gpuEnabled)
        result.gpu = null;
      root._data = result;
      if (result.gpu)
        root.appendHistory(result.gpu);
      else
        root.clearGpu();
    } catch (error) {
      root.clearGpu();
      Logger.w("SystemTelemetry", "Invalid collector output:", error);
    }
  }

  on_CollectionKeyChanged: root.restartCollection()

  Component.onCompleted: {
    root._ready = true;
    root.restartCollection();
  }
  Component.onDestruction: {
    if (root._busy)
      collector.signal(15);
  }

  property Timer pollTimer: Timer {
    interval: root.intervalMs
    repeat: true
    running: root.active
    onTriggered: root.collect()
  }

  property Process collectorProcess: Process {
    id: collector
    running: false
    stdout: StdioCollector {
      id: collectorOutput
    }
    stderr: StdioCollector {}
    onExited: exitCode => root.finishCollection(exitCode)
    onRunningChanged: {
      if (!running && root._busy) {
        const generation = root._requestGeneration;
        Qt.callLater(() => {
          if (root._busy && !collector.running && generation === root._requestGeneration)
            root.finishCollection(-1);
        });
      }
    }
  }
}
