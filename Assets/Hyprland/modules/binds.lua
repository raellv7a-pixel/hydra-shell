-- Default keybinds. Every shell-facing action here goes through
-- `qs -c hydra-shell ipc call <target> <function>`, calling one of the
-- IpcHandler targets already implemented in Services/Control/IPCService.qml
-- — nothing below invents new shell behavior, it only wires keys to IPC
-- surface that already exists but ships with zero default binds today.
--
-- Only IPC targets a user would want *instant, muscle-memory* keyboard
-- access to are bound here (shell surfaces, screenshot tools, media/volume/
-- brightness, window management). Secondary toggles (Wi-Fi, Bluetooth,
-- airplane mode, dock, night light, dark mode, power profile, desktop
-- widgets...) stay reachable through the Central de Controle / Settings UI
-- and are NOT force-bound to a key by default — add a bind for any of them
-- from the Settings panel's Atalhos sub-tab (Fase 3) if you want one; that
-- sub-tab lists every function under every IPC target below as a candidate.
--
-- Category comments (`-- Category`) are a parser contract: Fase 3's
-- HyprlandBindsParser.js groups the Settings panel's Atalhos legend by the
-- nearest preceding `-- Category` comment, mirroring keybinds.go's
-- parseBinds() in ryoku-arch. Keep every new bind under a category comment.
--
-- K(): rebind indirection, safe because this file — unlike an arbitrary
-- user's binds.lua — is versioned by hydra-shell itself. K(k) returns the
-- user's chosen combo for a shipped chord `k`, or `k` unchanged if it was
-- never remapped. The Settings panel writes remaps to
-- hydra-shell/rebinds.lua (Fase 3); absent or malformed, K() is the
-- identity and every default below keeps working.
local ok, rebinds = pcall(require, "hydra-shell.rebinds")
if not ok or type(rebinds) ~= "table" then rebinds = {} end
local function K(k) return rebinds[k] or k end

local programs = require("modules.programs")

local function ipc(target, fn)
  return hl.dsp.exec_cmd("qs -c hydra-shell ipc call " .. target .. " " .. fn)
end

-- Shell surfaces
hl.bind(K("SUPER + SPACE"), ipc("launcher", "toggle"), { description = "Abrir launcher" })
hl.bind(K("SUPER + SUPER_L"), ipc("launcher", "toggle"), { release = true, description = "Abrir launcher (toque no Super)" })
hl.bind(K("SUPER + V"), ipc("launcher", "clipboard"), { description = "Histórico de área de transferência" })
hl.bind(K("SUPER + COMMA"), ipc("settings", "toggle"), { description = "Configurações" })
hl.bind(K("SUPER + L"), ipc("lockScreen", "lock"), { description = "Bloquear tela" })
hl.bind(K("SUPER + S"), ipc("controlCenter", "toggle"), { description = "Central de controle" })
hl.bind(K("SUPER + N"), ipc("notifications", "toggleHistory"), { description = "Histórico de notificações" })
hl.bind(K("SUPER + C"), ipc("calendar", "toggle"), { description = "Calendário" })
hl.bind(K("SUPER + B"), ipc("bar", "toggle"), { description = "Mostrar/ocultar a barra" })
hl.bind(K("SUPER + ESCAPE"), ipc("sessionMenu", "toggle"), { description = "Menu de sessão" })
hl.bind(K("ALT + TAB"), ipc("workspaces", "toggle"), { description = "Gerenciador de workspaces" })

-- Screenshot / ScreenToolkit
hl.bind(K("Print"), ipc("screenToolkit", "annotate"), { locked = true, description = "Anotar / capturar região" })
hl.bind(K("SHIFT + Print"), ipc("screenToolkit", "annotateWindow"), { locked = true, description = "Anotar janela ativa" })
hl.bind(K("CTRL + Print"), ipc("screenToolkit", "annotateFullscreen"), { locked = true, description = "Anotar tela cheia" })
hl.bind(K("SUPER + Print"), ipc("screenToolkit", "colorPicker"), { locked = true, description = "Seletor de cores" })
hl.bind(K("SUPER + SHIFT + Print"), ipc("screenToolkit", "record"), { locked = true, description = "Gravador de tela" })
hl.bind(K("SUPER + ALT + Print"), ipc("screenToolkit", "ocr"), { locked = true, description = "Extrair texto (OCR)" })

-- Apps
hl.bind(K("SUPER + T"), hl.dsp.exec_cmd(programs.terminal), { description = "Terminal" })
hl.bind(K("SUPER + E"), hl.dsp.exec_cmd(programs.file_manager), { description = "Gerenciador de arquivos" })

-- Window management (native dispatchers, no IPC round-trip)
hl.bind(K("SUPER + Q"), hl.dsp.window.close(), { description = "Fechar janela" })
hl.bind(K("SUPER + F"), hl.dsp.window.float({ action = "toggle" }), { description = "Alternar flutuante" })
hl.bind(K("SUPER + SHIFT + F"), hl.dsp.window.fullscreen(), { description = "Alternar tela cheia" })
hl.bind(K("SUPER + P"), hl.dsp.window.pseudo(), { description = "Modo pseudo" })
hl.bind(K("SUPER + SHIFT + P"), hl.dsp.window.pin({ action = "toggle" }), { description = "Fixar janela flutuante" })
hl.bind(K("SUPER + J"), hl.dsp.layout("togglesplit"), { description = "Alternar divisão do layout" })

hl.bind(K("SUPER + left"), hl.dsp.focus({ direction = "left" }), { description = "Foco à esquerda" })
hl.bind(K("SUPER + right"), hl.dsp.focus({ direction = "right" }), { description = "Foco à direita" })
hl.bind(K("SUPER + up"), hl.dsp.focus({ direction = "up" }), { description = "Foco acima" })
hl.bind(K("SUPER + down"), hl.dsp.focus({ direction = "down" }), { description = "Foco abaixo" })

hl.bind(K("SUPER + SHIFT + left"), hl.dsp.window.move({ direction = "l" }), { description = "Mover janela à esquerda" })
hl.bind(K("SUPER + SHIFT + right"), hl.dsp.window.move({ direction = "r" }), { description = "Mover janela à direita" })
hl.bind(K("SUPER + SHIFT + up"), hl.dsp.window.move({ direction = "u" }), { description = "Mover janela acima" })
hl.bind(K("SUPER + SHIFT + down"), hl.dsp.window.move({ direction = "d" }), { description = "Mover janela abaixo" })

hl.bind(K("SUPER + ALT + left"), hl.dsp.window.swap({ direction = "l" }), { description = "Trocar com a janela à esquerda" })
hl.bind(K("SUPER + ALT + right"), hl.dsp.window.swap({ direction = "r" }), { description = "Trocar com a janela à direita" })
hl.bind(K("SUPER + ALT + up"), hl.dsp.window.swap({ direction = "u" }), { description = "Trocar com a janela acima" })
hl.bind(K("SUPER + ALT + down"), hl.dsp.window.swap({ direction = "d" }), { description = "Trocar com a janela abaixo" })

hl.bind(K("SUPER + SHIFT + G"), hl.dsp.group.toggle(), { description = "Alternar grupo (abas)" })
hl.bind(K("SUPER + TAB"), hl.dsp.group.next(), { description = "Próxima aba no grupo" })
hl.bind(K("SUPER + SHIFT + TAB"), hl.dsp.group.prev(), { description = "Aba anterior no grupo" })

hl.bind(K("SUPER + mouse:272"), hl.dsp.window.drag(), { mouse = true, description = "Mover janela com o mouse" })
hl.bind(K("SUPER + mouse:273"), hl.dsp.window.resize(), { mouse = true, description = "Redimensionar janela com o mouse" })

-- Resize submap: SUPER+R enters, arrows resize, Escape/Enter exits.
hl.bind(K("SUPER + R"), hl.dsp.submap("resize"), { description = "Modo redimensionar" })
hl.define_submap("resize", function()
  hl.bind("left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
  hl.bind("right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
  hl.bind("up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
  hl.bind("down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("Return", hl.dsp.submap("reset"))
end)

-- Workspaces
for i = 1, 10 do
  local key = i % 10 -- SUPER+0 targets workspace 10
  hl.bind(K("SUPER + " .. key), hl.dsp.focus({ workspace = i }), { description = "Ir para a área de trabalho " .. i })
  hl.bind(K("SUPER + SHIFT + " .. key), hl.dsp.window.move({ workspace = i }), { description = "Mover janela para a área de trabalho " .. i })
end
hl.bind(K("SUPER + mouse_up"), hl.dsp.focus({ workspace = "+1" }), { description = "Próxima área de trabalho" })
hl.bind(K("SUPER + mouse_down"), hl.dsp.focus({ workspace = "-1" }), { description = "Área de trabalho anterior" })

-- Media, volume, brightness — always locked (work over the lock screen) and
-- repeating where holding the key should ramp the value.
hl.bind(K("XF86AudioNext"), hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Próxima faixa" })
hl.bind(K("XF86AudioPrev"), hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Faixa anterior" })
hl.bind(K("XF86AudioPlay"), hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Tocar/pausar" })
hl.bind(K("XF86AudioPause"), hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Tocar/pausar" })

hl.bind(K("XF86AudioRaiseVolume"), ipc("volume", "increase"), { locked = true, repeating = true, description = "Aumentar volume" })
hl.bind(K("XF86AudioLowerVolume"), ipc("volume", "decrease"), { locked = true, repeating = true, description = "Diminuir volume" })
hl.bind(K("XF86AudioMute"), ipc("volume", "muteOutput"), { locked = true, description = "Mudo" })

hl.bind(K("XF86MonBrightnessUp"), ipc("brightness", "increase"), { locked = true, repeating = true, description = "Aumentar brilho" })
hl.bind(K("XF86MonBrightnessDown"), ipc("brightness", "decrease"), { locked = true, repeating = true, description = "Diminuir brilho" })
