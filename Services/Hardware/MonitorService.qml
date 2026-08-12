pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import "../../Modules/Panels/Settings/Tabs/Display/MonitorLayout/backends/HyprlandBackend.js" as HyprBackend
import "../../Modules/Panels/Settings/Tabs/Display/MonitorLayout/backends/SwayBackend.js" as SwayBackend

Singleton {
  id: root

  property var originalOutputs: []
  property var draftOutputs: []
  property string selectedOutputId: ""
  property bool isBusy: false

  Component.onCompleted: {
    fetchOutputs();
  }

  function activeBackend() {
    if (CompositorService.isHyprland) return HyprBackend;
    if (CompositorService.isSway) return SwayBackend;
    return HyprBackend;
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {}
    onExited: (code) => {
      root.isBusy = false;
      if (code === 0) {
        var res = root.activeBackend().parseOutputs(fetchProc.stdout.text);
        if (res && res.outputs) {
          root.originalOutputs = JSON.parse(JSON.stringify(res.outputs));
          root.draftOutputs = JSON.parse(JSON.stringify(res.outputs));
          if (root.draftOutputs.length > 0 && root.selectedOutputId === "") {
            root.selectedOutputId = root.draftOutputs[0].outputId;
          }
        }
      }
    }
  }

  Process {
    id: applyProc
    onExited: (code) => {
      root.isBusy = false;
      if (code === 0) {
        ToastService.showNotice("Arranjo de Monitores", "Layout de telas aplicado com sucesso!", "display");
        fetchOutputs();
      } else {
        ToastService.showError("Falha no Layout de Monitores", "Não foi possível aplicar as alterações de tela.");
      }
    }
  }

  function fetchOutputs() {
    root.isBusy = true;
    var cmd = root.activeBackend().buildFetchCommand({}, {});
    fetchProc.exec({ command: cmd });
  }

  function selectOutput(id) {
    root.selectedOutputId = id;
  }

  function getSelectedOutput() {
    for (var i = 0; i < root.draftOutputs.length; i++) {
      if (root.draftOutputs[i].outputId === root.selectedOutputId) {
        return root.draftOutputs[i];
      }
    }
    return root.draftOutputs.length > 0 ? root.draftOutputs[0] : null;
  }

  function updateOutputPosition(outputId, newX, newY) {
    var arr = JSON.parse(JSON.stringify(root.draftOutputs));
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].outputId === outputId) {
        arr[i].x = Math.round(newX);
        arr[i].y = Math.round(newY);
        break;
      }
    }
    root.draftOutputs = arr;
  }

  function updateOutput(outputId, changes) {
    var arr = JSON.parse(JSON.stringify(root.draftOutputs));
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].outputId === outputId) {
        arr[i] = Object.assign({}, arr[i], changes);
        if (changes.scale) {
          arr[i].logicalWidth = Math.max(1, Math.round(arr[i].width / arr[i].scale));
          arr[i].logicalHeight = Math.max(1, Math.round(arr[i].height / arr[i].scale));
        }
        break;
      }
    }
    root.draftOutputs = arr;
  }

  function applyLayout() {
    if (root.draftOutputs.length === 0) return;
    root.isBusy = true;
    var res = root.activeBackend().buildApplyCommand(root.draftOutputs, {}, {});
    if (res && res.script) {
      applyProc.exec({ command: ["bash", "-c", res.script] });
    } else if (res && res.error) {
      root.isBusy = false;
      ToastService.showError("Erro no Layout", res.error);
    }
  }

  function generateConfigSnippet() {
    var res = root.activeBackend().buildConfigFileContent(root.draftOutputs);
    return (res && res.content) ? res.content : "";
  }

  function generateLuaConfigSnippet() {
    var backend = root.activeBackend();
    if (backend && typeof backend.buildLuaConfigFileContent === "function") {
      var res = backend.buildLuaConfigFileContent(root.draftOutputs);
      return (res && res.content) ? res.content : "";
    }
    return generateConfigSnippet();
  }

  // Reload once the write lands (FileView.setText() is async — see
  // HyprlandLuaWriter's saved()/saveFailed() signals).
  Connections {
    target: HyprlandLuaWriter
    function onMonitorsSaved() {
      reloadProc.running = true;
      ToastService.showNotice("Salvo no Hyprland", "Configuração de monitores salva em ~/.config/hypr/hydra-shell/monitors.lua!", "display");
    }
    function onMonitorsSaveFailed(error) {
      ToastService.showError("Erro ao Salvar", "Não foi possível salvar a configuração de telas: " + error);
    }
  }

  Process {
    id: reloadProc
    running: false
    command: ["hyprctl", "reload"]
  }

  function saveToHyprlandConfig() {
    var luaContent = generateLuaConfigSnippet();
    if (luaContent && luaContent.length > 0) {
      HyprlandLuaWriter.writeMonitors(luaContent);
    } else {
      ToastService.showError("Erro ao Salvar", "Não foi possível gerar a configuração de telas.");
    }
  }
}
