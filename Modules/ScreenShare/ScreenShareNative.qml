import QtQuick
import Quickshell
import Quickshell.Io
import "../ScreenToolkit/overlays"
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI

// Ponto de entrada do seletor de compartilhamento de tela.
//
// Scripts/bash/corvus-share-picker.sh (apontado por custom_picker_binary no
// xdph.conf) chama este handler e fica bloqueado lendo o FIFO até respondermos.
Item {
  id: root

  IpcHandler {
    target: "screenshare"

    // O script valida o retorno "ok": qs ipc call sai com 0 mesmo quando o target
    // não existe, então o código de saída sozinho não distingue os casos.
    function open(fifo: string, listFile: string, allowToken: string): string {
      return ScreenShareService.openRequest(fifo, listFile, allowToken) ? "ok" : "busy";
    }

    // Válvula de escape: fecha o seletor de fora, respondendo como cancelamento.
    // Útil se o app solicitante morrer com o painel aberto.
    function cancel(): string {
      if (!ScreenShareService.active)
        return "idle";
      ScreenShareService.cancel();
      return "ok";
    }
  }

  function resolveScreen() {
    const focused = CompositorService.getFocusedScreen();
    if (focused)
      return focused;
    return PanelService.findScreenForPanels();
  }

  function panelFor(screen) {
    return PanelService.getPanel("screenSharePanel", screen);
  }

  Connections {
    target: ScreenShareService

    function onRequestOpened() {
      const screen = root.resolveScreen();
      const panel = root.panelFor(screen);
      if (!panel) {
        Logger.e("ScreenShare", "Panel not found, cancelling request");
        ScreenShareService.cancel();
        return;
      }
      panel.resetSelection();
      panel.open();
    }

    function onRequestClosed() {
      const panel = root.panelFor(root.resolveScreen());
      if (panel)
        panel.close();
    }

    // O seletor de região precisa viver aqui: o conteúdo do painel é descarregado
    // quando ele fecha, e levaria o seletor junto no meio da seleção.
    function onRegionRequested() {
      const screen = root.resolveScreen();
      const panel = root.panelFor(screen);
      if (panel)
        panel.close();
      regionSelector.show(screen);
    }
  }

  RegionSelector {
    id: regionSelector

    // RegionSelector usa `pluginApi?.tr(...)`; um shim mantém os textos traduzidos.
    pluginApi: ({
                  "tr": function (key) {
                    return I18n.tr("screen-share.region-selector." + key.replace("regionSelector.", ""));
                  }
                })

    onRegionSelected: function (x, y, w, h, selectedScreen) {
      // O seletor devolve pixels físicos locais à tela; o xdph espera lógicos locais.
      const scale = selectedScreen?.devicePixelRatio ?? 1.0;
      ScreenShareService.submitRegion(selectedScreen?.name ?? "", x / scale, y / scale, w / scale, h / scale);
    }

    onCancelled: ScreenShareService.cancel()
  }
}
