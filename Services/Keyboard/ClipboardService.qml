pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Clipboard history service using cliphist + local content cache
Singleton {
  id: root

  // Public API
  property bool active: Settings.data.appLauncher.enableClipboardHistory && cliphistAvailable
  property bool loading: false
  property var items: [] // [{id, preview, mime, isImage}]

  // Check if cliphist is available on the system
  property bool cliphistAvailable: false
  property bool dependencyChecked: false

  // Optional automatic watchers to feed cliphist DB
  property bool autoWatch: true
  property bool watchersStarted: false

  // Expose decoded thumbnails by id and a revision to notify bindings
  property var imageDataById: ({})
  property var _imageDataInsertOrder: [] // insertion-order IDs for LRU eviction
  readonly property int _imageDataMaxEntries: 20 // max decoded images held in RAM at once
  property int revision: 0

  // Local content cache - stores full text content by ID
  // This avoids relying on cliphist decode which can be unreliable
  property var contentCache: ({})

  // Track the most recent clipboard content for instant access
  property string _latestTextContent: ""
  property string _latestTextId: ""

  // Approximate first-seen timestamps for entries this session (seconds)
  property var firstSeenById: ({})

  // Internal: store callback for decode
  property var _decodeCallback: null
  property int _decodeRequestId: 0

  // Queue for base64 decodes
  property var _b64Queue: []
  property var _b64CurrentCb: null
  property string _b64CurrentMime: ""
  property string _b64CurrentId: ""

  signal listCompleted

  // Check if cliphist is available
  Component.onCompleted: {
    checkCliphistAvailability();
  }

  function isNoteId(id) {
    return String(id || "").startsWith("note-");
  }

  function noteTextById(id) {
    const idStr = String(id || "");
    const notes = Settings.data.appLauncher.clipboardNotes || [];
    for (let i = 0; i < notes.length; ++i) {
      if (String(notes[i].id) === idStr)
        return String(notes[i].text || "");
    }
    return "";
  }

  function isPinned(id) {
    return (Settings.data.appLauncher.pinnedClipboardIds || []).indexOf(String(id)) !== -1;
  }

  function sortItems(entries) {
    return entries.sort((a, b) => {
                          const pinDelta = Number(root.isPinned(b.id)) - Number(root.isPinned(a.id));
                          if (pinDelta !== 0)
                          return pinDelta;
                          if (a.isNote !== b.isNote)
                          return a.isNote ? -1 : 1;
                          return 0;
                        });
  }

  function mergePersistentItems(historyItems) {
    const notes = Settings.data.appLauncher.clipboardNotes || [];
    const noteItems = notes.map(note => {
                                  const id = String(note.id);
                                  const createdAt = Number(note.createdAt || 0);
                                  if (createdAt > 0)
                                  root.firstSeenById[id] = createdAt;
                                  return {
                                    "id": id,
                                    "preview": String(note.text || ""),
                                    "isImage": false,
                                    "isNote": true,
                                    "mime": "text/plain",
                                    "contentType": "note"
                                  };
                                });
    return root.sortItems(noteItems.concat(historyItems));
  }

  function refreshPersistentItems() {
    const historyItems = (root.items || []).filter(item => !item.isNote);
    root.items = root.mergePersistentItems(historyItems);
    root.revision++;
    root.listCompleted();
  }

  function togglePin(id) {
    const idStr = String(id || "");
    if (idStr === "")
      return;
    const pinned = Array.from(Settings.data.appLauncher.pinnedClipboardIds || []);
    const index = pinned.indexOf(idStr);
    if (index === -1)
      pinned.push(idStr);
    else
      pinned.splice(index, 1);
    Settings.data.appLauncher.pinnedClipboardIds = pinned;
    root.refreshPersistentItems();
  }

  function addNote(text) {
    const trimmed = String(text || "").trim();
    if (trimmed === "")
      return "";
    const now = Date.now();
    const id = `note-${now}-${Math.floor(Math.random() * 1000000)}`;
    const notes = Array.from(Settings.data.appLauncher.clipboardNotes || []);
    notes.unshift({
                    "id": id,
                    "text": trimmed,
                    "createdAt": now / 1000
                  });
    Settings.data.appLauncher.clipboardNotes = notes;
    root.refreshPersistentItems();
    return id;
  }

  // Check dependency availability
  function checkCliphistAvailability() {
    if (dependencyChecked)
      return;
    dependencyCheckProcess.command = ["sh", "-c", "command -v cliphist"];
    dependencyCheckProcess.running = true;
  }

  // Process to check if cliphist is available
  Process {
    id: dependencyCheckProcess
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      root.dependencyChecked = true;
      if (exitCode === 0) {
        root.cliphistAvailable = true;
        // Start watchers if feature is enabled
        if (root.active) {
          startWatchers();
        }
      } else {
        root.cliphistAvailable = false;
        // Show toast notification if feature is enabled but cliphist is missing
        if (Settings.data.appLauncher.enableClipboardHistory) {
          ToastService.showWarning(I18n.tr("toast.clipboard.unavailable"), I18n.tr("toast.clipboard.unavailable-desc"), 6000);
        }
      }
    }
  }

  // Start/stop watchers when enabled changes
  onActiveChanged: {
    if (root.active) {
      startWatchers();
    } else {
      stopWatchers();
      loading = false;
      items = [];
    }
  }

  // Fallback: periodically refresh list so UI updates even if not in clip mode
  Timer {
    interval: 5000
    repeat: true
    running: root.active
    onTriggered: list()
  }

  // Internal process objects
  Process {
    id: listProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      const out = String(stdout.text);
      const lines = out.split('\n').filter(l => l.length > 0);
      // cliphist list default format: "<id> <preview>" or "<id>\t<preview>"
      const parsed = lines.map((l, i) => {
                                 let id = "";
                                 let preview = "";
                                 const m = l.match(/^(\d+)\s+(.+)$/);
                                 if (m) {
                                   id = m[1];
                                   preview = m[2];
                                 } else {
                                   const tab = l.indexOf('\t');
                                   id = tab > -1 ? l.slice(0, tab) : l;
                                   preview = tab > -1 ? l.slice(tab + 1) : "";
                                 }
                                 const lower = preview.toLowerCase();
                                 const isImage = lower.startsWith("[image]") || lower.includes(" binary data ");
                                 // Best-effort mime guess from preview
                                 var mime = "text/plain";
                                 if (isImage) {
                                   if (lower.includes(" png"))
                                   mime = "image/png";
                                   else if (lower.includes(" jpg") || lower.includes(" jpeg"))
                                   mime = "image/jpeg";
                                   else if (lower.includes(" webp"))
                                   mime = "image/webp";
                                   else if (lower.includes(" gif"))
                                   mime = "image/gif";
                                   else
                                   mime = "image/*";
                                 }
                                 // Record first seen time for new ids (approximate copy time)
                                 if (!root.firstSeenById[id]) {
                                   const assumedAge = i * 15 * 60;
                                   root.firstSeenById[id] = Time.timestamp - assumedAge;
                                 }
                                 // Smart type detection
                                 var contentType = "text";
                                 if (isImage) {
                                   contentType = "image";
                                 } else {
                                   const t = preview.trim();
                                   const tLower = t.toLowerCase();
                                   if (/^#([a-f0-9]{3}|[a-f0-9]{6}|[a-f0-9]{8})$/.test(tLower)) {
                                     contentType = "color";
                                   } else if (/^https?:\/\//i.test(t)) {
                                     contentType = "link";
                                   } else if (/^(\/|~\/|file:\/\/)/i.test(t) && !t.startsWith('//') && !t.includes('\n')) {
                                     contentType = "file";
                                   } else if ((t.includes('{') && t.includes('}') && (t.includes(';') || t.includes('='))) || t.includes('</') || t.includes('/>') || t.includes('=>') || t.includes('===') || t.includes('!==') || t.includes('::') || t.includes('->') ||
                                              /^(?:const|let|var|function|class|struct|interface|type|enum|import|export|func|fn|pub|def|using|namespace|property|public|private|protected)\b/i.test(t) || /^(?:#include|#define|#\[|@|\/\/|\/\*|<\?|<html|<body|<!DOCTYPE)/i.test(t) || /\b(?:require\(|module\.exports)\b/i.test(t)) {
                                     contentType = "code";
                                   }
                                 }

                                 return {
                                   "id": id,
                                   "preview": preview,
                                   "isImage": isImage,
                                   "mime": mime,
                                   "contentType": contentType
                                 };
                               });

      // Filter out browser junk when copying images
      const filtered = parsed.filter(item => {
                                       if (item.isImage)
                                       return true;
                                       const p = item.preview;
                                       // Skip UTF-16 encoded text (has null bytes between chars), chromium browser artifact
                                       const nullCount = (p.match(/\x00/g) || []).length;
                                       if (nullCount > p.length * 0.2)
                                       return false;
                                       // Skip browser-generated HTML wrapper, firefox
                                       if (p.toLowerCase().startsWith("<meta http-equiv="))
                                       return false;
                                       return true;
                                     });

      items = root.mergePersistentItems(filtered);
      loading = false;

      // Try to capture current clipboard and associate with newest item
      if (filtered.length > 0 && !filtered[0].isImage && !root.contentCache[filtered[0].id]) {
        root.captureCurrentClipboard();
      }

      root.listCompleted();
    }
  }

  Process {
    id: decodeProc
    property int requestId: 0
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (requestId === root._decodeRequestId && root._decodeCallback) {
        const out = String(stdout.text);
        try {
          root._decodeCallback(out);
        } finally {
          root._decodeCallback = null;
        }
      }
    }
  }

  Process {
    id: copyProc
    stdout: StdioCollector {}
  }

  Process {
    id: pasteProc
    stdout: StdioCollector {}
  }

  Process {
    id: deleteProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      revision++;
      Qt.callLater(() => list());
    }
  }

  Process {
    id: wipeProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      root.revision++;
      Qt.callLater(() => root.list());
    }
  }

  // Base64 decode pipeline (queued)
  Process {
    id: decodeB64Proc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      const b64 = String(stdout.text).trim();
      if (root._b64CurrentCb) {
        const url = `data:${root._b64CurrentMime};base64,${b64}`;
        try {
          root._b64CurrentCb(url);
        } catch (e) {}
      }
      if (root._b64CurrentId !== "") {
        const entryId = root._b64CurrentId;
        root.imageDataById[entryId] = `data:${root._b64CurrentMime};base64,${b64}`;
        // Track insertion order and evict oldest entries beyond the cap
        root._imageDataInsertOrder.push(entryId);
        while (root._imageDataInsertOrder.length > root._imageDataMaxEntries) {
          const evicted = root._imageDataInsertOrder.shift();
          delete root.imageDataById[evicted];
        }
        root.revision += 1;
      }
      root._b64CurrentCb = null;
      root._b64CurrentMime = "";
      root._b64CurrentId = "";
      Qt.callLater(root._startNextB64);
    }
  }

  // Text watcher - stores to cliphist and triggers content capture
  Process {
    id: watchText
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (root.autoWatch && root.watchersStarted && Settings.data.appLauncher.clipboardWatchTextCommand.trim() !== "") {
        watchTextRestartTimer.restart();
      }
    }
  }

  Timer {
    id: watchTextRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root.autoWatch && root.watchersStarted)
      watchText.running = true;
    }
  }

  // Image watcher
  Process {
    id: watchImage
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (root.autoWatch && root.watchersStarted && Settings.data.appLauncher.clipboardWatchImageCommand.trim() !== "") {
        watchImageRestartTimer.restart();
      }
    }
  }

  Timer {
    id: watchImageRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root.autoWatch && root.watchersStarted)
      watchImage.running = true;
    }
  }

  // Capture current clipboard text when needed
  Process {
    id: captureTextProc
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        const content = String(stdout.text);
        if (content.length > 0) {
          root._latestTextContent = content;
          // Associate with newest item if we have one
          if (root.items.length > 0 && !root.items[0].isImage) {
            const newestId = root.items[0].id;
            if (!root.contentCache[newestId]) {
              root.contentCache[newestId] = content;
              root.revision++;
            }
          }
        }
      }
    }
  }

  function startWatchers() {
    if (!root.active || !autoWatch || watchersStarted || !root.cliphistAvailable)
      return;
    watchersStarted = true;

    // Text watcher
    watchText.command = ["sh", "-c", Settings.data.appLauncher.clipboardWatchTextCommand];
    watchText.running = true;

    // Image watcher
    watchImage.command = ["sh", "-c", Settings.data.appLauncher.clipboardWatchImageCommand];
    watchImage.running = true;
  }

  function stopWatchers() {
    if (!watchersStarted)
      return;
    watchText.running = false;
    watchImage.running = false;
    watchersStarted = false;
  }

  // Capture current clipboard text and cache it
  function captureCurrentClipboard() {
    if (captureTextProc.running)
      return;
    captureTextProc.command = ["wl-paste", "--no-newline"];
    captureTextProc.running = true;
  }

  function list(maxPreviewWidth) {
    if (!root.active || !root.cliphistAvailable) {
      return;
    }
    if (listProc.running)
      return;
    loading = true;
    const width = maxPreviewWidth || 100;
    listProc.command = ["cliphist", "list", "-preview-width", String(width)];
    listProc.running = true;
  }

  // Get content for an ID - uses cache first, falls back to cliphist decode
  function getContent(id) {
    if (root.contentCache[id]) {
      return root.contentCache[id];
    }
    return null;
  }

  // Async decode - checks cache first, then falls back to cliphist
  function decode(id, cb) {
    if (!root.cliphistAvailable) {
      if (cb)
        cb("");
      return;
    }

    // Check cache first
    const cached = root.contentCache[id];
    if (cached) {
      if (cb)
        cb(cached);
      return;
    }

    // Fall back to cliphist decode
    if (decodeProc.running) {
      decodeProc.running = false;
    }
    root._decodeRequestId++;
    decodeProc.requestId = root._decodeRequestId;
    root._decodeCallback = function (content) {
      // Cache the result if successful
      if (content && content.trim()) {
        root.contentCache[id] = content;
      }
      if (cb)
        cb(content);
    };
    const idStr = String(id);
    decodeProc.command = ["cliphist", "decode", idStr];
    decodeProc.running = true;
  }

  function decodeToDataUrl(id, mime, cb) {
    if (!root.cliphistAvailable) {
      if (cb)
        cb("");
      return;
    }
    // If cached, return immediately
    if (root.imageDataById[id]) {
      if (cb)
        cb(root.imageDataById[id]);
      return;
    }
    // Queue request; ensures single process handles sequentially
    root._b64Queue.push({
                          "id": id,
                          "mime": mime || "image/*",
                          "cb": cb
                        });
    if (!decodeB64Proc.running && root._b64CurrentCb === null) {
      _startNextB64();
    }
  }

  function getImageData(id) {
    if (id === undefined) {
      return null;
    }
    return root.imageDataById[id];
  }

  function _startNextB64() {
    if (root._b64Queue.length === 0 || !root.cliphistAvailable)
      return;
    const job = root._b64Queue.shift();
    root._b64CurrentCb = job.cb;
    root._b64CurrentMime = job.mime;
    root._b64CurrentId = job.id;
    decodeB64Proc.command = ["sh", "-c", `cliphist decode ${job.id} | base64 -w 0`];
    decodeB64Proc.running = true;
  }

  function copyToClipboard(id) {
    if (root.isNoteId(id)) {
      copyProc.command = ["wl-copy", root.noteTextById(id)];
      copyProc.running = true;
      return;
    }
    if (!root.cliphistAvailable)
      return;
    copyProc.command = ["sh", "-c", `cliphist decode ${id} | wl-copy`];
    copyProc.running = true;
  }

  function pasteFromClipboard(id, mime) {
    if (root.isNoteId(id)) {
      root.pasteText(root.noteTextById(id));
      return;
    }
    if (!root.cliphistAvailable)
      return;
    const isImage = mime && mime.startsWith("image/");
    const typeArg = isImage ? ` --type ${mime}` : "";
    const pasteKeys = isImage ? "wtype -M ctrl -k v" : "wtype -M ctrl -M shift v";
    const cmd = `cliphist decode ${id} | wl-copy${typeArg} && ${pasteKeys}`;
    pasteProc.command = ["sh", "-c", cmd];
    pasteProc.running = true;
  }

  function pasteText(text) {
    if (!text)
      return;
    const escaped = text.replace(/'/g, "'\\''");
    const cmd = `printf '%s' '${escaped}' | wl-copy && wtype -M ctrl -M shift v`;
    pasteProc.command = ["sh", "-c", cmd];
    pasteProc.running = true;
  }

  function deleteById(id) {
    const idStr = String(id).trim();
    if (root.isNoteId(idStr)) {
      const notes = Array.from(Settings.data.appLauncher.clipboardNotes || []);
      Settings.data.appLauncher.clipboardNotes = notes.filter(note => String(note.id) !== idStr);
      const pinnedNotes = Array.from(Settings.data.appLauncher.pinnedClipboardIds || []);
      Settings.data.appLauncher.pinnedClipboardIds = pinnedNotes.filter(pinnedId => pinnedId !== idStr);
      delete root.firstSeenById[idStr];
      root.refreshPersistentItems();
      return;
    }
    if (!root.cliphistAvailable || deleteProc.running || !/^\d+$/.test(idStr))
      return;
    const pinned = Array.from(Settings.data.appLauncher.pinnedClipboardIds || []);
    Settings.data.appLauncher.pinnedClipboardIds = pinned.filter(pinnedId => pinnedId !== idStr);
    // Remove from caches
    delete root.contentCache[idStr];
    delete root.imageDataById[idStr];
    const orderIdx = root._imageDataInsertOrder.indexOf(idStr);
    if (orderIdx !== -1)
      root._imageDataInsertOrder.splice(orderIdx, 1);
    deleteProc.command = ["sh", "-c", `echo ${idStr} | cliphist delete`];
    deleteProc.running = true;
  }

  function wipeAll() {
    if (!root.cliphistAvailable || wipeProc.running)
      return;

    const historyItems = (root.items || []).filter(item => !item.isNote);
    const unpinnedIds = historyItems.map(item => String(item.id)).filter(id => /^\d+$/.test(id) && !root.isPinned(id));
    const pinnedIds = Array.from(Settings.data.appLauncher.pinnedClipboardIds || []);

    // Keep pinned cliphist entries and all author-created notes.
    if (pinnedIds.length === 0) {
      wipeProc.command = ["cliphist", "wipe"];
    } else if (unpinnedIds.length === 0) {
      wipeProc.command = ["true"];
    } else {
      const deletes = unpinnedIds.map(id => `printf '%s\\n' ${id} | cliphist delete`).join(" && ");
      wipeProc.command = ["sh", "-c", deletes];
    }

    for (const id of unpinnedIds) {
      delete root.contentCache[id];
      delete root.imageDataById[id];
    }
    root._imageDataInsertOrder = root._imageDataInsertOrder.filter(id => root.isPinned(id));
    root._latestTextContent = "";
    root._latestTextId = "";
    wipeProc.running = true;
  }

  // Parse image metadata from cliphist preview string
  function parseImageMeta(preview) {
    const re = /\[\[\s*binary data\s+([\d\.]+\s*(?:KiB|MiB|GiB|B))\s+(\w+)\s+(\d+)x(\d+)\s*\]\]/i;
    const match = (preview || "").match(re);
    if (!match)
      return null;
    return {
      "size": match[1],
      "fmt": (match[2] || "").toUpperCase(),
      "w": Number(match[3]),
      "h": Number(match[4])
    };
  }
}
