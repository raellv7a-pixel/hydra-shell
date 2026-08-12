-- Generic, app-agnostic window rules only. App-specific rules (pin an IM to a
-- scratchpad workspace, float a specific game launcher) are the Settings
-- panel's Regras de Janela sub-tab's job (Fase 2), not a shipped default —
-- every rule below fixes a real cross-app quirk or wires a required hydra-
-- shell integration point, nothing here is personal taste.
hl.window_rule({
  name = "hydra-shell-suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "hydra-shell-fix-xwayland-drags",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

-- hydra-shell's own Settings window (Modules/Panels/Settings/
-- SettingsPanelWindow.qml sets `title: "Noctalia"` — update this match if
-- that title is ever rebranded) — without this it tiles instead of floating
-- at its own content size.
hl.window_rule({
  name = "hydra-shell-settings-float",
  match = { title = "^(Noctalia)$" },
  float = true,
  center = true,
})

-- Small utility/dialog apps that misbehave tiled across every distro.
hl.window_rule({
  name = "hydra-shell-utility-floating-apps",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|qt6ct|qt5ct|nwg-look|nm-connection-editor|org.gnome.FileRoller)$",
  },
  float = true,
  center = true,
})

-- Picture-in-picture: bottom-right corner, pinned across workspaces, on top.
hl.window_rule({
  name = "hydra-shell-picture-in-picture-float",
  match = { title = "^(Picture-in-Picture)$" },
  float = true,
  pin = true,
  move = "100%-w-20 100%-h-20",
})
