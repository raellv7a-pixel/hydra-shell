-- Environment variables. Hardware/vendor-agnostic only — nothing here should
-- need per-machine tuning. Cursor theme/size have a dedicated Cursor sub-tab
-- (Fase 3 of PLANO_INTEGRACAO_HYPRMOD.md) that overrides these via
-- hydra-shell/settings.lua; the values below are just a sane cold-boot
-- default so the pointer isn't tiny before that tab is ever touched.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- XDG session identity — every Wayland/XDG-portal consumer expects these.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkit backends: force Wayland-first everywhere so Qt/GTK/SDL apps don't
-- silently fall back to XWayland with worse scaling/latency. qt6ct is the Qt
-- theming backend hydra-shell already ships a template for
-- (Assets/Templates/qtct.conf).
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- Firefox / Chromium-family Wayland + Ozone.
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- NVIDIA-only hints, gated on the driver actually being loaded — setting
-- these unconditionally breaks VA-API video decode and Xwayland GL on
-- Mesa (AMD/Intel), which auto-detects correctly on its own.
do
  local nvidia = io.open("/proc/driver/nvidia/version", "r")
  if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")
  end
end

-- Propagate the vars above into the systemd --user / D-Bus activation
-- environment. Hyprland's own `env` keyword only sets them for itself and
-- for processes *it* execs directly (exec-once, dispatch exec) — it does
-- NOT reach D-Bus-activated systemd --user services. xdg-desktop-portal and
-- its backends (xdg-desktop-portal-hyprland, -gtk, ...) are exactly such
-- services: activated on first request, not spawned by Hyprland, so
-- without this they start with none of the vars above — including
-- QT_QPA_PLATFORM, which Quickshell's own `qs ipc call` needs to find a
-- running shell instance. That's what silently broke the screen-share
-- picker bridge (Scripts/bash/corvus-share-picker.sh calls `qs ipc call`
-- as a child of xdg-desktop-portal-hyprland.service): the call failed with
-- "No running instances", so the script fell back to hyprland-share-picker
-- instead of the shell's own panel. Standard fix per the Hyprland wiki's
-- xdg-desktop-portal setup — must run after the `hl.env` calls above so it
-- reads their already-applied values from Hyprland's own environment.
hl.on("hyprland.start", function()
  hl.exec_cmd(
    "dbus-update-activation-environment --systemd " ..
    "XCURSOR_SIZE HYPRCURSOR_SIZE " ..
    "XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP " ..
    "GDK_BACKEND QT_QPA_PLATFORM QT_WAYLAND_DISABLE_WINDOWDECORATION QT_QPA_PLATFORMTHEME " ..
    "SDL_VIDEODRIVER CLUTTER_BACKEND " ..
    "MOZ_ENABLE_WAYLAND MOZ_DISABLE_RDD_SANDBOX ELECTRON_OZONE_PLATFORM_HINT " ..
    "LIBVA_DRIVER_NAME GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME NVD_BACKEND __GL_SHADER_DISK_CACHE_SKIP_CLEANUP"
  )
end)
