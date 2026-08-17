import QtQuick
import QtWebSockets
import "ObsWebSocketHash.js" as Hash

Item {
  id: root

  readonly property int helloOpCode: 0
  readonly property int identifyOpCode: 1
  readonly property int identifiedOpCode: 2
  readonly property int eventOpCode: 5
  readonly property int requestOpCode: 6
  readonly property int responseOpCode: 7
  readonly property int outputsEventSubscription: 64
  readonly property int handshakeTimeoutMs: 3000
  readonly property int requestTimeoutMs: 6000

  property url url: ""
  property string password: ""
  property bool identified: false
  property int nextRequestId: 1
  property var pendingRequests: ({})
  property var queuedRequests: []

  readonly property bool connected: socket.status === WebSocket.Open && identified

  signal authenticated
  signal connectionFailed(string message)
  signal connectionClosed(string message)
  signal eventReceived(string eventType, var eventData)

  function connectToServer() {
    ensureConnected();
  }

  function disconnectFromServer() {
    handshakeTimer.stop();
    identified = false;
    socket.active = false;
  }

  function ensureConnected() {
    if (!url || socket.status === WebSocket.Connecting || socket.status === WebSocket.Open)
      return;
    identified = false;
    socket.url = url;
    socket.active = true;
    handshakeTimer.restart();
  }

  function request(type, requestData, onSuccess, onFailure) {
    const requestId = String(nextRequestId++);
    pendingRequests[requestId] = {
      onSuccess: onSuccess,
      onFailure: onFailure,
      createdAt: Date.now()
    };
    queuedRequests.push({
                          requestType: type,
                          requestId: requestId,
                          requestData: requestData ?? ({})
                        });
    requestTimer.start();
    ensureConnected();
    flushQueuedRequests();
  }

  function flushQueuedRequests() {
    if (!connected)
      return;
    while (queuedRequests.length > 0) {
      const request = queuedRequests.shift();
      socket.sendTextMessage(JSON.stringify({
                                              op: requestOpCode,
                                              d: request
                                            }));
    }
  }

  function resolveRequest(requestId, responseData) {
    const entry = pendingRequests[requestId];
    if (!entry)
      return;
    delete pendingRequests[requestId];
    if (entry.onSuccess)
      entry.onSuccess(responseData ?? ({}));
    updateRequestTimer();
  }

  function rejectRequest(requestId, message) {
    const entry = pendingRequests[requestId];
    if (!entry)
      return;
    delete pendingRequests[requestId];
    if (entry.onFailure)
      entry.onFailure(message);
    updateRequestTimer();
  }

  function rejectAll(message) {
    const pending = pendingRequests;
    pendingRequests = ({});
    queuedRequests = [];
    requestTimer.stop();
    for (const requestId in pending) {
      if (pending[requestId].onFailure)
        pending[requestId].onFailure(message);
    }
  }

  function hasPendingRequests() {
    if (queuedRequests.length > 0)
      return true;
    for (const requestId in pendingRequests)
      return true;
    return false;
  }

  function updateRequestTimer() {
    if (!hasPendingRequests())
      requestTimer.stop();
  }

  function handleHello(payload) {
    const identify = {
      rpcVersion: 1,
      eventSubscriptions: outputsEventSubscription
    };
    const authentication = payload?.authentication;
    if (authentication) {
      const secret = Hash.sha256Base64(`${password}${authentication.salt}`);
      identify.authentication = Hash.sha256Base64(`${secret}${authentication.challenge}`);
    }
    socket.sendTextMessage(JSON.stringify({
                                            op: identifyOpCode,
                                            d: identify
                                          }));
  }

  function handleResponse(payload) {
    const requestId = payload?.requestId;
    if (!requestId)
      return;
    if (payload?.requestStatus?.result) {
      resolveRequest(requestId, payload.responseData);
      return;
    }
    rejectRequest(requestId, payload?.requestStatus?.comment || "OBS request failed.");
  }

  Timer {
    id: handshakeTimer
    interval: root.handshakeTimeoutMs
    repeat: false
    onTriggered: {
      const message = "Timed out while authenticating with OBS WebSocket.";
      root.rejectAll(message);
      root.connectionFailed(message);
      root.disconnectFromServer();
    }
  }

  Timer {
    id: requestTimer
    interval: 1000
    repeat: true
    onTriggered: {
      const now = Date.now();
      const expired = [];
      for (const requestId in root.pendingRequests) {
        if (now - root.pendingRequests[requestId].createdAt >= root.requestTimeoutMs)
          expired.push(requestId);
      }
      for (const requestId of expired)
        root.rejectRequest(requestId, "OBS WebSocket request timed out.");
    }
  }

  WebSocket {
    id: socket
    active: false

    onStatusChanged: {
      if (status !== WebSocket.Closed && status !== WebSocket.Error)
        return;
      const wasIdentified = root.identified;
      const hadPending = root.hasPendingRequests();
      const message = errorString || (status === WebSocket.Error ? "Failed to connect or authenticate with OBS WebSocket." : "OBS WebSocket connection closed.");
      handshakeTimer.stop();
      root.identified = false;
      if (hadPending)
        root.rejectAll(message);
      if (status === WebSocket.Error)
        root.connectionFailed(message);
      else if (wasIdentified)
        root.connectionClosed(message);
    }

    onTextMessageReceived: function (message) {
      let parsed;
      try {
        parsed = JSON.parse(message);
      } catch (error) {
        return;
      }
      if (parsed.op === root.helloOpCode) {
        root.handleHello(parsed.d);
      } else if (parsed.op === root.identifiedOpCode) {
        handshakeTimer.stop();
        root.identified = true;
        root.authenticated();
        root.flushQueuedRequests();
      } else if (parsed.op === root.eventOpCode) {
        root.eventReceived(parsed.d?.eventType ?? "", parsed.d?.eventData ?? ({}));
      } else if (parsed.op === root.responseOpCode) {
        root.handleResponse(parsed.d);
      }
    }
  }
}
