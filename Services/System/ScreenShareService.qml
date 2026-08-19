pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons

// Estado do seletor de compartilhamento de tela.
//
// O xdg-desktop-portal-hyprland executa Scripts/bash/corvus-share-picker.sh, que
// nos aciona via IPC e fica bloqueado lendo um FIFO. Este serviço monta as fontes
// disponíveis, identifica quem pediu a captura e devolve a seleção pelo FIFO no
// formato que o xdph espera.
Singleton {
  id: root

  // --- requisição em andamento ------------------------------------------------

  property bool active: false
  property string fifoPath: ""
  property bool allowToken: false

  // [{ handle, appClass, title, address, toplevel, isPrivate }]
  property var windowSources: []

  // Incrementado quando as miniaturas ficam prontas, para as views reavaliarem o path.
  property int snapshotVersion: 0

  // Compõe o nome dos arquivos de miniatura. Um token novo a cada requisição evita
  // depender de cache-busting por query string, que o Qt não aplica em file://.
  property string snapshotToken: ""

  // App que solicitou a captura (pode ficar vazio — ver _resolveRequestingApp).
  property string requestingAppName: ""
  property string requestingAppIcon: ""

  signal requestOpened
  signal requestClosed

  // O seletor de região vive no módulo nativo, não no painel: o painel é
  // descarregado ao fechar, e levaria o seletor junto.
  signal regionRequested

  function requestRegion() {
    root.regionRequested();
  }

  // --- entrada ----------------------------------------------------------------

  function openRequest(fifo, listFile, allowTokenArg) {
    if (root.active) {
      // Já existe um pedido na tela: recusa o novo para não perder o FIFO antigo.
      Logger.w("ScreenShareService", "Request already active, rejecting new one");
      return false;
    }

    root.fifoPath = String(fifo || "");
    root.allowToken = (String(allowTokenArg) === "1" || String(allowTokenArg) === "true");
    root.windowSources = [];
    root.requestingAppName = "";
    root.requestingAppIcon = "";
    root.snapshotToken = String(Date.now());
    // Zerar aqui é essencial: sem isso, a partir da segunda requisição as views
    // usariam o token novo antes de o grim escrever os arquivos.
    root.snapshotVersion = 0;

    if (root.fifoPath === "") {
      Logger.e("ScreenShareService", "openRequest called without a FIFO path");
      return false;
    }

    listReader.exec({
                      "command": ["cat", String(listFile || "/dev/null")]
                    });

    captureScreens();
    resolveRequestingApp();

    root.active = true;
    root.requestOpened();
    return true;
  }

  // --- saída ------------------------------------------------------------------

  function submitScreen(screenName) {
    respond("screen:" + screenName);
  }

  function submitWindow(handle) {
    respond("window:" + handle);
  }

  // x/y/w/h em pixels lógicos relativos à tela, como o xdph espera.
  function submitRegion(screenName, x, y, w, h) {
    respond("region:" + screenName + "@" + Math.round(x) + "," + Math.round(y) + "," + Math.round(w) + "," + Math.round(h));
  }

  function cancel() {
    // Payload vazio apenas destrava o script; sem "[SELECTION]" o xdph cancela.
    respond("");
  }

  function respond(selection) {
    if (!root.active || root.fifoPath === "") {
      reset();
      return;
    }

    const flags = root.allowToken ? "r" : "";
    const payload = (selection === "") ? "" : ("[SELECTION]" + flags + "/" + selection);

    // execDetached é essencial: escrever num FIFO bloqueia até o leitor aparecer,
    // e não podemos travar o loop de eventos da QML.
    Quickshell.execDetached(["sh", "-c", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(root.fifoPath)]);

    Logger.i("ScreenShareService", "Responded with:", payload === "" ? "<cancel>" : payload);
    reset();
  }

  function reset() {
    root.active = false;
    root.fifoPath = "";
    root.windowSources = [];
    root.requestClosed();
  }

  // --- fontes: janelas --------------------------------------------------------

  Process {
    id: listReader
    stdout: StdioCollector {
      onStreamFinished: root.windowSources = root.parseWindowList(this.text)
    }
  }

  // Formato do xdph: <handleLo>[HC>]<classe>[HT>]<título>[HE>]<endereço>[HA>] repetido.
  function parseWindowList(raw) {
    const result = [];
    let rolling = String(raw || "");

    while (rolling.length > 0) {
      const classSep = rolling.indexOf("[HC>]");
      const titleSep = rolling.indexOf("[HT>]");
      const addrSep = rolling.indexOf("[HE>]");
      const endSep = rolling.indexOf("[HA>]");

      if (classSep < 0 || titleSep < 0 || addrSep < 0 || endSep < 0)
        break;

      const handle = rolling.substring(0, classSep).trim();
      const appClass = rolling.substring(classSep + 5, titleSep);
      const title = rolling.substring(titleSep + 5, addrSep);
      const addrDec = rolling.substring(addrSep + 5, endSep).trim();

      if (handle.length > 0 && /^[0-9]+$/.test(handle)) {
        const address = decimalToAddress(addrDec);
        result.push({
                      "handle": handle,
                      "appClass": appClass,
                      "title": title,
                      "address": address,
                      "toplevel": findToplevel(address, appClass, title)
                    });
      }

      rolling = rolling.substring(endSep + 5);
    }

    Logger.d("ScreenShareService", "Parsed", result.length, "window sources");
    return result;
  }

  // O xdph imprime o endereço da janela em decimal; o Hyprland usa hexadecimal.
  // Ponteiros de heap ficam em ~46 bits, dentro da faixa segura de 53 bits do Number.
  function decimalToAddress(decimal) {
    const n = Number(decimal);
    if (!isFinite(n) || n <= 0)
      return "";
    return "0x" + n.toString(16);
  }

  // O ScreencopyView captura o Toplevel genérico do Wayland, não o objeto do
  // Hyprland — daí o `.wayland` no consumidor.
  function findToplevel(address, appClass, title) {
    const toplevels = (typeof Hyprland !== 'undefined' && Hyprland.toplevels) ? (Hyprland.toplevels.values || []) : [];

    if (address !== "") {
      for (var i = 0; i < toplevels.length; i++) {
        if (String(toplevels[i].address).toLowerCase() === address.toLowerCase())
          return toplevels[i];
      }
    }

    // Fallback: casar por classe + título quando o endereço não bater.
    for (var j = 0; j < toplevels.length; j++) {
      const ipc = toplevels[j].lastIpcObject;
      if (ipc && ipc["class"] === appClass && ipc.title === title)
        return toplevels[j];
    }

    return null;
  }

  // --- fontes: telas ----------------------------------------------------------

  function snapshotPath(screenName) {
    if (root.snapshotToken === "")
      return "";
    return Settings.cacheDir + "screenshare-" + root.snapshotToken + "-" + String(screenName).replace(/[^A-Za-z0-9_-]/g, "_") + ".png";
  }

  // Miniaturas por grim em vez de ScreencopyView ao vivo: o overlay fica sobre uma
  // das telas e um preview ao vivo se capturaria a si mesmo (espelho infinito).
  function captureScreens() {
    const commands = ["rm -f " + shellQuote(Settings.cacheDir) + "screenshare-*.png 2>/dev/null"];

    for (var i = 0; i < Quickshell.screens.length; i++) {
      const name = Quickshell.screens[i].name;
      commands.push("grim -o " + shellQuote(name) + " " + shellQuote(snapshotPath(name)) + " 2>/dev/null");
    }
    if (commands.length <= 1)
      return;

    snapshotProc.exec({
                        "command": ["sh", "-c", commands.join("; ") + "; true"]
                      });
  }

  Process {
    id: snapshotProc
    onExited: root.snapshotVersion++
  }

  // --- quem pediu a captura ---------------------------------------------------

  property string lastSender: ""
  property double lastSenderAt: 0

  // O argumento app_id do portal vem vazio para apps nativos (só é preenchido em
  // Flatpak), então identificamos o solicitante pelo remetente D-Bus -> PID.
  Process {
    id: portalMonitor
    running: true
    command: ["dbus-monitor", "--session", "interface='org.freedesktop.portal.ScreenCast'"]

    stdout: SplitParser {
      onRead: function (line) {
        if (line.indexOf("method call") !== 0)
          return;
        const match = line.match(/sender=(:[0-9.]+)/);
        if (!match)
          return;
        root.lastSender = match[1];
        root.lastSenderAt = Date.now();
      }
    }
  }

  function resolveRequestingApp() {
    if (root.lastSender === "" || (Date.now() - root.lastSenderAt) > 15000)
      return;

    senderResolver.exec({
                          "command": ["sh", "-c", "pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus " + "GetConnectionUnixProcessID s " + shellQuote(root.lastSender) + " 2>/dev/null | awk '{print $2}'); " + "[ -n \"$pid\" ] && cat /proc/$pid/comm 2>/dev/null || true"]
                        });
  }

  Process {
    id: senderResolver
    stdout: StdioCollector {
      onStreamFinished: {
        const comm = String(this.text).trim();
        if (comm === "")
        return;

        const entry = (typeof ThemeIcons !== 'undefined') ? ThemeIcons.findAppEntry(comm) : null;
        root.requestingAppName = entry ? entry.name : comm;
        root.requestingAppIcon = entry ? ThemeIcons.iconFromName(entry.icon, comm) : ThemeIcons.iconFromName(comm, "cast");
      }
    }
  }

  // --- utilitários ------------------------------------------------------------

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
  }
}
