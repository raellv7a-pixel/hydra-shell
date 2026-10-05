pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Modules/Panels/Settings/Tabs/Display/MonitorLayout/MonitorGeometry.js" as MonitorGeometry
import "../../Modules/Panels/Settings/Tabs/Display/MonitorLayout/backends/UmbrielBackend.js" as UmbrielBackend
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Singleton {
  id: root

  property var originalOutputs: []
  property var draftOutputs: []
  property string selectedOutputId: ""
  property string primaryOutputId: ""

  // Transaction state machine:
  // "idle" | "preparing" | "applying" | "verifying" | "confirming" |
  // "reverting" | "rollback_verifying" | "rollback_failed"
  property string transactionState: "idle"
  property int transactionId: 0
  property var rollbackSnapshot: null
  property bool verifyingRollback: false
  property int confirmationRemainingSeconds: 15

  readonly property bool isBusy: transactionState !== "idle" || fetchProc.running || snapshotProc.running || applyProc.running || rollbackProc.running || verifyProc.running || saveProc.running
  readonly property bool isSettling: transactionState === "preparing" || transactionState === "applying" || transactionState === "verifying" || transactionState === "reverting" || transactionState === "rollback_verifying" || saveProc.running
  readonly property bool isPersisting: saveProc.running
  readonly property string persistenceError: lastPersistenceError
  property string lastPersistenceError: ""

  signal configSaved(bool success, string error)
  signal layoutConfirmed
  readonly property var backendConfig: ({ script: Quickshell.shellDir + "/Scripts/python/umbriel_config.py" })
  Component.onCompleted: {
    if (CompositorService.isUmbriel)
      Qt.callLater(fetchOutputs);
  }
  function activeBackend() { return UmbrielBackend; }
  function replaceOutputs(outputs) {
    root.originalOutputs = JSON.parse(JSON.stringify(outputs));
    root.draftOutputs = JSON.parse(JSON.stringify(outputs));
    var primary = MonitorGeometry.derivePrimary(root.draftOutputs);
    root.primaryOutputId = primary ? (primary.outputId || primary.name) : "";
    var selectedExists = false;
    for (var i = 0; i < root.draftOutputs.length; i++) {
      if (root.draftOutputs[i].outputId === root.selectedOutputId) {
        selectedExists = true;
        break;
      }
    }
    if (!selectedExists) {
      root.selectedOutputId = root.draftOutputs.length > 0 ? root.draftOutputs[0].outputId : "";
    }
  }

  function outputsMatch(expected, actual) {
    // Verify full geometry, scales and modes before asking the user to keep the layout.
    return MonitorGeometry.layoutsMatch(expected, actual);
  }
  function startApply(outputs, tx) {
    var activeCount = outputs.filter(function (output) {
      return output && output.active !== false && !output.disabled;
    }).length;
    if (activeCount === 0) {
      root.transactionState = "idle";
      root.rollbackSnapshot = null;
      ToastService.showError("Erro no Layout", "Mantenha pelo menos uma tela ativa.");
      return;
    }
    var res = root.activeBackend().buildApplyCommand(outputs, root.backendConfig);
    if (res && res.script) {
      root.transactionState = "applying";
      applyProc.activeTx = tx;
      applyProc.exec({
                       command: ["bash", "-c", res.script]
                     });
    } else {
      root.transactionState = "idle";
      root.rollbackSnapshot = null;
      ToastService.showError("Erro no Layout", res ? res.error : "Comando de aplicação indisponível.");
    }
  }

  Timer {
    id: confirmationTimer
    interval: 1000
    repeat: true
    running: root.transactionState === "confirming"
    onTriggered: {
      if (root.confirmationRemainingSeconds > 1) {
        root.confirmationRemainingSeconds -= 1;
      } else {
        root.confirmationRemainingSeconds = 0;
        stop();
        Logger.w("MonitorService", "Layout confirmation timed out after 15s. Reverting automatically.");
        root.rollback();
      }
    }
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {}
    onExited: code => {
      if (code === 0) {
        var res = root.activeBackend().parseOutputs(fetchProc.stdout.text);
        if (res && res.outputs) {
          root.replaceOutputs(res.outputs);
        } else {
          Logger.e("MonitorService", "Failed to parse monitor state: " + (res ? res.error : "empty response"));
        }
      } else {
        Logger.e("MonitorService", "Failed to fetch monitor state with exit code " + code + ".");
      }
    }
  }
  Process {
    id: snapshotProc
    property int activeTx: 0
    stdout: StdioCollector {}
    onExited: code => {
      if (activeTx !== root.transactionId || root.transactionState !== "preparing") {
        Logger.w("MonitorService", "Ignoring stale pre-apply snapshot callback for tx " + activeTx);
        return;
      }
      if (code !== 0) {
        root.transactionState = "idle";
        ToastService.showError("Erro no Layout", "Não foi possível capturar o estado atual das telas.");
        return;
      }

      var res = root.activeBackend().parseOutputs(snapshotProc.stdout.text);
      if (!res || !res.outputs) {
        root.transactionState = "idle";
        ToastService.showError("Erro no Layout", "Não foi possível interpretar o estado atual das telas.");
        return;
      }
      if (!root.outputsMatch(root.originalOutputs, res.outputs)) {
        root.replaceOutputs(res.outputs);
        root.transactionState = "idle";
        ToastService.showError("Layout alterado", "As telas mudaram fora deste painel. Revise o layout atualizado antes de aplicar.");
        return;
      }

      root.rollbackSnapshot = JSON.parse(JSON.stringify(res.outputs));
      root.startApply(root.draftOutputs, activeTx);
    }
  }

  Process {
    id: applyProc
    property int activeTx: 0
    onExited: code => {
      if (activeTx !== root.transactionId) {
        Logger.w("MonitorService", "Ignoring stale apply callback for tx " + activeTx);
        return;
      }

      if (code === 0) {
        CompositorService.updateDisplayScales();
        // Step 2: Fetch and verify actual outputs after apply
        root.transactionState = "verifying";
        verifyProc.activeTx = activeTx;
        var cmd = root.activeBackend().buildFetchCommand();
        verifyProc.exec({
                          command: cmd
                        });
      } else {
        Logger.e("MonitorService", "Apply process failed with exit code " + code + ". Rolling back.");
        ToastService.showError("Falha no Layout de Monitores", "Não foi possível aplicar as alterações de tela. Restaurando...");
        root.rollback();
      }
    }
  }

  Process {
    id: verifyProc
    property int activeTx: 0
    stdout: StdioCollector {}
    onExited: code => {
      if (activeTx !== root.transactionId) {
        Logger.w("MonitorService", "Ignoring stale verify callback for tx " + activeTx);
        return;
      }

      var isRollbackCheck = root.verifyingRollback;
      var res = code === 0 ? root.activeBackend().parseOutputs(verifyProc.stdout.text) : null;
      var expected = isRollbackCheck ? root.rollbackSnapshot : root.draftOutputs;
      if (res && res.outputs && root.outputsMatch(expected, res.outputs)) {
        if (isRollbackCheck) {
          root.replaceOutputs(res.outputs);
          root.rollbackSnapshot = null;
          root.verifyingRollback = false;
          root.transactionState = "idle";
          ToastService.showNotice("Layout Restaurado", "Configuração anterior de monitores verificada e restaurada.", "display");
        } else {
          root.transactionState = "confirming";
          root.confirmationRemainingSeconds = 15;
          ToastService.showNotice("Layout Aplicado", "Deseja manter as novas configurações de tela?", "display");
        }
        return;
      }

      if (isRollbackCheck) {
        root.verifyingRollback = false;
        root.transactionState = "rollback_failed";
        Logger.e("MonitorService", "Rollback verification failed. Snapshot retained.");
        ToastService.showError("Falha na Reversão", "A configuração anterior não foi confirmada pelo compositor. O snapshot foi preservado.");
        return;
      }

      Logger.e("MonitorService", "Output verification failed. Triggering rollback.");
      ToastService.showError("Aplicação Incompleta", "A configuração solicitada não foi confirmada integralmente. Revertendo...");
      root.rollback();
    }
  }

  Process {
    id: rollbackProc
    property int activeTx: 0
    onExited: code => {
      if (activeTx !== root.transactionId) {
        Logger.w("MonitorService", "Ignoring stale rollback callback for tx " + activeTx);
        return;
      }

      if (code === 0) {
        CompositorService.updateDisplayScales();
        root.transactionState = "rollback_verifying";
        root.verifyingRollback = true;
        verifyProc.activeTx = activeTx;
        var cmd = root.activeBackend().buildFetchCommand();
        verifyProc.exec({
                          command: cmd
                        });
      } else {
        root.verifyingRollback = false;
        root.transactionState = "rollback_failed";
        Logger.e("MonitorService", "Rollback execution failed with exit code " + code + ". Snapshot retained.");
        ToastService.showError("Falha na Reversão", "Não foi possível restaurar a configuração anterior automaticamente.");
      }
    }
  }

  function fetchOutputs() {
    if (root.isBusy) {
      Logger.w("MonitorService", "fetchOutputs blocked while monitor state is busy");
      return;
    }
    var cmd = root.activeBackend().buildFetchCommand();
    fetchProc.exec({
                     command: cmd
                   });
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
    if (root.isBusy)
      return;
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
    if (root.isBusy)
      return;
    var arr = JSON.parse(JSON.stringify(root.draftOutputs));
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].outputId === outputId) {
        arr[i] = Object.assign({}, arr[i], changes);

        // Umbriel accepts fractional scale directly; do not coerce to a Hyprland ladder.

        var size = MonitorGeometry.computeLogicalSize(arr[i].width, arr[i].height, arr[i].scale, arr[i].transform);
        arr[i].logicalWidth = size.width;
        arr[i].logicalHeight = size.height;

        if ((changes.active === false || changes.disabled === true) && outputId === root.primaryOutputId) {
          var active = arr.filter(function (output) {
            return output.active !== false && !output.disabled;
          });
          var primary = MonitorGeometry.derivePrimary(active);
          root.primaryOutputId = primary ? (primary.outputId || primary.name) : "";
          if (primary) {
            arr = MonitorGeometry.rebaseToPrimary(arr, root.primaryOutputId);
          }
        }
        break;
      }
    }
    if (!root.primaryOutputId) {
      var activeOutputs = arr.filter(function (output) {
        return output.active !== false && !output.disabled;
      });
      var currentPrimary = MonitorGeometry.derivePrimary(activeOutputs);
      root.primaryOutputId = currentPrimary ? (currentPrimary.outputId || currentPrimary.name) : "";
      if (currentPrimary) {
        arr = MonitorGeometry.rebaseToPrimary(arr, root.primaryOutputId);
      }
    }
    root.draftOutputs = arr;
  }

  function setPrimaryOutput(outputId) {
    if (root.isBusy)
      return;
    var output = null;
    for (var i = 0; i < root.draftOutputs.length; i++) {
      var candidate = root.draftOutputs[i];
      if (candidate.outputId === outputId && candidate.active !== false && !candidate.disabled) {
        output = candidate;
        break;
      }
    }
    if (!output)
      return;
    root.primaryOutputId = outputId;
    root.draftOutputs = MonitorGeometry.rebaseToPrimary(root.draftOutputs, outputId);
  }

  function commitLayout(updatedOutputs, primaryId) {
    if (root.isBusy)
      return;
    var active = updatedOutputs.filter(function (output) {
      return output && output.active !== false && !output.disabled;
    });
    if (active.length === 0)
      return;
    var targetPrimary = primaryId || root.primaryOutputId;
    var hasActivePrimary = active.some(function (output) {
      return output.outputId === targetPrimary || output.name === targetPrimary;
    });
    if (!hasActivePrimary) {
      var primary = MonitorGeometry.derivePrimary(active);
      targetPrimary = primary ? (primary.outputId || primary.name) : "";
    }
    root.primaryOutputId = targetPrimary;
    root.draftOutputs = MonitorGeometry.rebaseToPrimary(updatedOutputs, targetPrimary);
  }

  function resetDraftOutputs() {
    if (root.isBusy)
      return;
    root.draftOutputs = JSON.parse(JSON.stringify(root.originalOutputs));
  }

  function applyLayout() {
    if (root.isBusy)
      return;
    if (root.draftOutputs.length === 0)
      return;
    var activeCount = root.draftOutputs.filter(function (output) {
      return output && output.active !== false && !output.disabled;
    }).length;
    if (activeCount === 0) {
      ToastService.showError("Erro no Layout", "Mantenha pelo menos uma tela ativa.");
      return;
    }

    var tx = ++root.transactionId;
    root.rollbackSnapshot = null;
    root.verifyingRollback = false;
    root.transactionState = "preparing";
    snapshotProc.activeTx = tx;
    snapshotProc.exec({
                        command: root.activeBackend().buildFetchCommand()
                      });
  }

  function keepLayout() {
    if (root.transactionState !== "confirming")
      return;
    confirmationTimer.stop();
    root.originalOutputs = JSON.parse(JSON.stringify(root.draftOutputs));
    root.rollbackSnapshot = null;
    root.transactionState = "idle";
    root.lastPersistenceError = "";
    root.layoutConfirmed();
    ToastService.showNotice("Layout Confirmado", "Configuração de monitores salva com sucesso para esta sessão!", "display");
  }
  function rollback() {
    confirmationTimer.stop();
    root.verifyingRollback = false;
    if (!root.rollbackSnapshot || root.rollbackSnapshot.length === 0) {
      root.transactionState = "idle";
      return;
    }

    var tx = root.transactionId;
    root.transactionState = "reverting";

    var res = root.activeBackend().buildApplyCommand(root.rollbackSnapshot, root.backendConfig);
    if (res && res.script) {
      rollbackProc.activeTx = tx;
      rollbackProc.exec({
                          command: ["bash", "-c", res.script]
                        });
    } else {
      root.transactionState = "rollback_failed";
      ToastService.showError("Erro na Reversão", "Não foi possível gerar script de reversão.");
    }
  }

  function retryRollback() {
    if (root.transactionState === "rollback_failed" && root.rollbackSnapshot) {
      rollback();
    }
  }

  function generateConfigSnippet(outputsList) {
    var target = outputsList || root.originalOutputs;
    var res = root.activeBackend().buildConfigFileContent(target);
    return (res && res.content) ? res.content : "";
  }

  function saveToUmbrielConfig() {
    if (root.isBusy)
      return false;
    root.lastPersistenceError = "";
    const result = root.activeBackend().buildApplyCommand(root.originalOutputs, root.backendConfig);
    if (result && result.script) {
      saveProc.exec({ command: ["bash", "-c", result.script] });
      return true;
    }
    root.lastPersistenceError = result ? (result.error || "No apply command") : "Failed to generate config command";
    root.configSaved(false, root.lastPersistenceError);
    return false;
  }

  Process {
    id: saveProc
    stderr: StdioCollector {}
    onExited: code => {
      if (code === 0) {
        root.lastPersistenceError = "";
        CompositorService.updateDisplayScales();
        ToastService.showNotice("Salvo na Umbriel", "Configuração validada em hydra/outputs.toml.", "display");
        root.configSaved(true, "");
      } else {
        root.lastPersistenceError = saveProc.stderr.text || ("Process exited with code " + code);
        ToastService.showError("Erro ao Salvar", root.lastPersistenceError);
        root.configSaved(false, root.lastPersistenceError);
      }
    }
  }
}
