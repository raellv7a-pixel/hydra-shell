-- Default app launch targets, consulted once by modules/binds.lua to build
-- the SUPER+T / SUPER+E dispatchers. Binds capture the resolved command
-- string at registration time, so changing these values later never
-- retroactively updates an already-registered bind — to change what SUPER+T
-- launches, override the *keybind*, not this table: either from the
-- Settings panel's Atalhos sub-tab (Fase 3), which emits
-- `hl.unbind("SUPER,T"); hl.bind("SUPER,T", ...)` into
-- hydra-shell/settings.lua, or by hand in user.lua with the same two calls.
--
-- kitty is the shipped default because it is the one terminal hydra-shell
-- ships first-class templates for (Assets/Templates/kitty.conf,
-- kitty-predefined.conf) — every other choice here is a portable shell
-- fallback chain, not a hardcoded app, so a fresh install never launches
-- nothing just because one specific file manager isn't installed.
return {
  terminal = "kitty",
  file_manager = "sh -c 'xdg-open \"$HOME\" 2>/dev/null || " ..
      "for fm in nautilus dolphin thunar pcmanfm nemo; do " ..
      "command -v \"$fm\" >/dev/null 2>&1 && exec \"$fm\"; done'",
}
