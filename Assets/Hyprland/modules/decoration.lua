-- Appearance defaults: general/decoration/dwindle/master/misc. Deliberately
-- conservative — opaque windows, modest blur/shadow/rounding — so a fresh
-- install looks clean without imposing a strong personal aesthetic; the
-- Settings panel's Hyprland → Geral sub-tab (Fase 2) is where a user turns
-- these up.
--
-- Border colors (general.col.active_border / inactive_border,
-- group.col.*, group.groupbar.col.*) are deliberately NOT set here: they
-- come from the existing color-template pipeline
-- (Assets/Templates/hyprland.lua, Services/Theming/TemplateRegistry.qml)
-- which is `dofile()`'d in after every module in hyprland.lua. Setting them
-- here would just get overwritten the moment a color scheme is applied, and
-- would show stale colors on every reload until then.
hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    layout = "dwindle",
    resize_on_border = true,
    allow_tearing = false,
  },

  decoration = {
    rounding = 10,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
    },
    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  misc = {
    -- hydra-shell renders its own wallpaper (Modules/Background,
    -- Services/UI/WallpaperService) — Hyprland's built-in wallpaper renderer
    -- must stay off or the two fight over the same monitors.
    force_default_wallpaper = -1,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})
