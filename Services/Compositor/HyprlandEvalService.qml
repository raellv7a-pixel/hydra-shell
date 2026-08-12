pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Serialized `hyprctl eval` writer — the ONLY live-apply path for Hyprland
// running its Lua config (PLANO_INTEGRACAO_HYPRMOD.md §2.5/§3.4):
// `hyprctl keyword` is rejected outright by the Lua config manager. Never
// call `hyprctl keyword` for anything under the Hyprland Settings tab or
// MonitorService — always route through evalLua() here.
//
// One Process at a time, newest request wins: a queued call replaces any
// call still waiting behind the current one (never behind more than one),
// mirroring ryoku-arch's ryolayer writer — a fast slider drag must apply the
// latest value, not replay every intermediate one.
Singleton {
  id: root

  property string pending: ""
  property bool hasPending: false

  Process {
    id: evalProcess
    running: false
    // Leading space defends against hyprctl's own arg parser treating a
    // snippet that happens to start with "--" (a Lua comment) as a flag
    // instead of the eval code — reproduced live against Hyprland 0.56.2
    // during development; see PLANO_INTEGRACAO_HYPRMOD.md.
    command: ["hyprctl", "eval", " " + root.pending]

    stderr: StdioCollector {
      onStreamFinished: {
        var text = this.text.trim();
        if (text.length > 0) {
          Logger.w("HyprlandEvalService", "eval stderr:", text);
        }
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0) {
        Logger.e("HyprlandEvalService", "eval failed, exit code", exitCode, "for:", root.pending);
      }
      if (root.hasPending) {
        root.hasPending = false;
        evalProcess.running = true; // re-run with the (now-updated) root.pending
      }
    }
  }

  // Fire-and-forget live preview. Safe to call rapidly (e.g. from an
  // NValueSlider's onMoved) — intermediate values are coalesced, only the
  // latest is guaranteed to reach the compositor.
  function evalLua(luaSnippet) {
    if (!luaSnippet || luaSnippet.length === 0)
      return;
    root.pending = luaSnippet;
    if (evalProcess.running) {
      root.hasPending = true;
    } else {
      evalProcess.running = true;
    }
  }
}
