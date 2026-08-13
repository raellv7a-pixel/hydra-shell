pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  readonly property int defaultPort: 4455
  readonly property int minimumPollInterval: 750
  readonly property string homeDir: Quickshell.env("HOME") ?? ""
  readonly property string configPath: `${Quickshell.env("XDG_CONFIG_HOME") ?? `${homeDir}/.config`}/obs-studio/plugin_config/obs-websocket/config.json`
  readonly property var config: Settings.data.obsControl ?? ({})
  readonly property bool manualConfiguration: config.manualConfiguration ?? false
  readonly property string manualHost: String(config.host ?? "127.0.0.1").trim()
  readonly property int manualPort: Number(config.port ?? defaultPort)
  readonly property string manualPassword: String(config.password ?? "")
  readonly property int pollInterval: Math.max(minimumPollInterval, Number(config.pollInterval ?? 1500))

  property bool fileConfigAvailable: false
  property int filePort: defaultPort
  property string filePassword: ""
  property bool actionBusy: false
  property bool pollBusy: false
  property bool authenticated: false
  property string connectionState: "disconnected"
  property string lastError: ""
  property bool recording: false
  property bool streaming: false
  property bool replayBuffer: false
  property int recordDurationMs: 0
  property int streamDurationMs: 0
  property int displayRecordDurationMs: 0
  property int displayStreamDurationMs: 0

  readonly property bool manualConfigValid: manualHost !== "" && manualPort > 0 && manualPort <= 65535 && Math.floor(manualPort) === manualPort
  readonly property bool configurationAvailable: manualConfiguration ? manualConfigValid : fileConfigAvailable
  readonly property bool configurationMissing: !configurationAvailable
  readonly property bool dependencyMissing: transportLoader.status === Loader.Error
  readonly property bool transportReady: transportLoader.status === Loader.Ready
  readonly property string host: manualConfiguration ? manualHost : "127.0.0.1"
  readonly property int port: manualConfiguration ? manualPort : filePort
  readonly property string password: manualConfiguration ? manualPassword : filePassword
  readonly property string websocketUrl: configurationAvailable ? `ws://${host}:${port}` : ""
  readonly property bool connected: transportReady && authenticated
  readonly property bool anyOutputActive: recording || streaming || replayBuffer
  readonly property string effectiveState: dependencyMissing ? "dependency-missing"
                                                    : configurationMissing ? "configuration-missing"
                                                    : connectionState

  function resetOutputs() {
    recording = false
    streaming = false
    replayBuffer = false
    recordDurationMs = 0
    streamDurationMs = 0
    displayRecordDurationMs = 0
    displayStreamDurationMs = 0
  }

  function updateTransportCredentials() {
    if (!transportLoader.item)
      return
    const changed = String(transportLoader.item.url) !== websocketUrl || transportLoader.item.password !== password
    if (changed)
      transportLoader.item.disconnectFromServer()
    transportLoader.item.url = websocketUrl
    transportLoader.item.password = password
  }

  function reloadConfiguration() {
    if (!manualConfiguration)
      websocketConfigFile.reload()
    updateTransportCredentials()
    authenticated = false
    pollBusy = false
    resetOutputs()
    if (!configurationAvailable) {
      connectionState = "configuration-missing"
      return
    }
    connectionState = "disconnected"
    Qt.callLater(refresh)
  }

  function loadAutomaticConfiguration() {
    try {
      const parsed = JSON.parse(websocketConfigFile.text())
      const configuredPort = Number(parsed?.server_port ?? defaultPort)
      const validPort = configuredPort > 0 && configuredPort <= 65535 && Math.floor(configuredPort) === configuredPort
      filePort = validPort ? configuredPort : defaultPort
      filePassword = String(parsed?.server_password ?? "")
      fileConfigAvailable = parsed?.server_enabled === true && validPort
      if (!fileConfigAvailable)
        lastError = "OBS WebSocket is disabled or its port is invalid."
      else
        lastError = ""
    } catch (error) {
      fileConfigAvailable = false
      filePort = defaultPort
      filePassword = ""
      lastError = "OBS WebSocket configuration could not be read."
    }
    updateTransportCredentials()
    if (!manualConfiguration)
      Qt.callLater(refresh)
  }

  function failConnection(message) {
    pollBusy = false
    authenticated = false
    connectionState = "connection-error"
    lastError = String(message || "Failed to connect or authenticate with OBS WebSocket.")
    resetOutputs()
  }

  function request(type, data, onSuccess, onFailure) {
    if (!transportReady || !configurationAvailable || !transportLoader.item) {
      if (onFailure)
        onFailure(dependencyMissing ? "Qt WebSockets support is not installed." : "OBS WebSocket configuration is missing.")
      return
    }
    updateTransportCredentials()
    transportLoader.item.request(type, data ?? ({}), onSuccess, onFailure)
  }

  function refresh() {
    if (dependencyMissing) {
      connectionState = "dependency-missing"
      lastError = "Qt WebSockets support is not installed."
      return
    }
    if (!configurationAvailable) {
      connectionState = "configuration-missing"
      if (!manualConfiguration)
        websocketConfigFile.reload()
      return
    }
    if (!transportReady || pollBusy)
      return

    pollBusy = true
    if (!authenticated)
      connectionState = "connecting"

    const status = {
      recording: false,
      streaming: false,
      replayBuffer: false,
      recordDurationMs: 0,
      streamDurationMs: 0
    }
    let remaining = 3
    let failed = false

    function complete() {
      --remaining
      if (remaining !== 0 || failed)
        return
      root.pollBusy = false
      root.authenticated = true
      root.connectionState = "authenticated"
      root.lastError = ""
      root.recording = status.recording
      root.streaming = status.streaming
      root.replayBuffer = status.replayBuffer
      root.recordDurationMs = status.recordDurationMs
      root.streamDurationMs = status.streamDurationMs
      root.displayRecordDurationMs = status.recording ? status.recordDurationMs : 0
      root.displayStreamDurationMs = status.streaming ? status.streamDurationMs : 0
    }

    function fail(message) {
      if (failed)
        return
      failed = true
      root.failConnection(message)
    }

    request("GetRecordStatus", {}, response => {
      status.recording = response?.outputActive ?? false
      status.recordDurationMs = Math.max(0, Number(response?.outputDuration ?? 0))
      complete()
    }, fail)
    request("GetStreamStatus", {}, response => {
      status.streaming = response?.outputActive ?? false
      status.streamDurationMs = Math.max(0, Number(response?.outputDuration ?? 0))
      complete()
    }, fail)
    request("GetReplayBufferStatus", {}, response => {
      status.replayBuffer = response?.outputActive ?? false
      complete()
    }, message => {
      if (String(message).toLowerCase().includes("replay buffer is not available")) {
        status.replayBuffer = false
        complete()
      } else {
        fail(message)
      }
    })
  }

  function performOutputAction(requestType, successCallback) {
    if (actionBusy)
      return
    if (!connected) {
      ToastService.showError(I18n.tr("bar.obs-control.error-title"), I18n.tr(`bar.obs-control.state-${effectiveState}`))
      refresh()
      return
    }
    actionBusy = true
    request(requestType, {}, () => {
      if (successCallback)
        successCallback()
      actionBusy = false
      actionRefreshTimer.restart()
    }, message => {
      actionBusy = false
      lastError = String(message)
      ToastService.showError(I18n.tr("bar.obs-control.error-title"), lastError)
    })
  }

  function toggleRecord() {
    performOutputAction(recording ? "StopRecord" : "StartRecord", () => recording = !recording)
  }

  function toggleStream() {
    performOutputAction(streaming ? "StopStream" : "StartStream", () => streaming = !streaming)
  }

  function toggleReplay() {
    performOutputAction(replayBuffer ? "StopReplayBuffer" : "StartReplayBuffer", () => replayBuffer = !replayBuffer)
  }

  function saveReplay() {
    performOutputAction("SaveReplayBuffer", () => ToastService.showNotice(I18n.tr("bar.obs-control.replay-saved"), "", "", 2500))
  }

  function applyOutputEvent(eventType, eventData) {
    if (eventType === "RecordStateChanged") {
      recording = eventData?.outputActive ?? false
      if (!recording) {
        recordDurationMs = 0
        displayRecordDurationMs = 0
      }
    } else if (eventType === "StreamStateChanged") {
      streaming = eventData?.outputActive ?? false
      if (!streaming) {
        streamDurationMs = 0
        displayStreamDurationMs = 0
      }
    } else if (eventType === "ReplayBufferStateChanged") {
      replayBuffer = eventData?.outputActive ?? false
    }
    actionRefreshTimer.restart()
  }

  onManualConfigurationChanged: reloadConfiguration()
  onManualHostChanged: if (manualConfiguration) reloadConfiguration()
  onManualPortChanged: if (manualConfiguration) reloadConfiguration()
  onManualPasswordChanged: if (manualConfiguration) reloadConfiguration()

  Component.onCompleted: {
    websocketConfigFile.reload()
    Qt.callLater(refresh)
  }

  Loader {
    id: transportLoader
    active: true
    source: Qt.resolvedUrl("ObsWebSocketTransport.qml")
    onStatusChanged: {
      root.updateTransportCredentials()
      if (status === Loader.Error) {
        root.connectionState = "dependency-missing"
        root.lastError = "Qt WebSockets support is not installed."
        root.resetOutputs()
      } else if (status === Loader.Ready) {
        Qt.callLater(root.refresh)
      }
    }
  }

  Connections {
    target: transportLoader.item
    ignoreUnknownSignals: true

    function onAuthenticated() {
      root.authenticated = true
      root.connectionState = "authenticated"
      root.lastError = ""
    }
    function onConnectionFailed(message) {
      root.failConnection(message)
    }
    function onConnectionClosed(message) {
      root.failConnection(message)
    }
    function onEventReceived(eventType, eventData) {
      root.applyOutputEvent(eventType, eventData)
    }
  }

  FileView {
    id: websocketConfigFile
    path: root.configPath
    watchChanges: true
    onLoaded: root.loadAutomaticConfiguration()
    onLoadFailed: function() {
      root.fileConfigAvailable = false
      root.filePort = root.defaultPort
      root.filePassword = ""
      if (!root.manualConfiguration) {
        root.connectionState = "configuration-missing"
        root.lastError = "OBS WebSocket configuration file was not found."
        root.resetOutputs()
      }
    }
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    running: root.transportReady && root.configurationAvailable
    repeat: true
    onTriggered: if (!root.actionBusy) root.refresh()
  }

  Timer {
    id: actionRefreshTimer
    interval: 500
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 1000
    running: root.recording || root.streaming
    repeat: true
    onTriggered: {
      if (root.recording)
        root.displayRecordDurationMs += 1000
      if (root.streaming)
        root.displayStreamDurationMs += 1000
    }
  }

  IpcHandler {
    target: "obsControl"
    function refresh() { root.refresh() }
    function toggleRecord() { root.toggleRecord() }
    function toggleStream() { root.toggleStream() }
    function toggleReplay() { root.toggleReplay() }
    function saveReplay() { root.saveReplay() }
  }
}
