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
