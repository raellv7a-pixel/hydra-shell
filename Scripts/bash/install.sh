#!/usr/bin/env -S bash
#
# hydra-shell installer — Arch Linux / CachyOS only.
#
# Personal bootstrap script, not a general-purpose public installer: it exists
# so a freshly formatted machine can be brought back to a fully working
# hydra-shell desktop in one command, without re-deriving the dependency list
# by hand every time. Usage (once this file is reachable on GitHub):
#
#   curl -fsSL https://raw.githubusercontent.com/raellv7a-pixel/hydra-shell/legacy-v4/Scripts/bash/install.sh | bash
#
# Or locally: bash Scripts/bash/install.sh
#
# What it does, in order:
#   1. Installs every runtime pacman dependency the shell actually shells out
#      to (audited from Services/, Modules/, Scripts/ — see comments below,
#      this list is NOT the same as the older DEPENDENCIES.md, which was
#      missing about a third of these).
#   2. Installs the build toolchain and compiles noctalia-qs (the Quickshell
#      fork hydra-shell runs on) from source. There is no AUR package for it
#      — AUR only has "noctalia-git", which is the unrelated, incompatible
#      Hydra v5 rewrite. Building from source is the only correct path
#      (this is also what nix/package.nix does under Nix).
#   3. Bootstraps an AUR helper (paru) if needed for the required Material 2025
#      backend, then installs optional polish packages unless --skip-optional.
#   4. Enables the system services the shell talks to over D-Bus
#      (NetworkManager, bluetooth, power-profiles-daemon).
#   5. Clones/updates the hydra-shell repo itself into the path Quickshell's
#      own convention expects (~/.config/quickshell/hydra-shell, used by
#      Umbriel autostart and Hydra keybind actions).
#   6. Provisions Hydra keybinds in Umbriel, preserving personal configuration.
#   7. Prints a doctor-style summary for the native session.
#
# Idempotent: safe to re-run. By default it skips rebuilding the qs engine if
# it's already on PATH (pass --force-engine to rebuild after an upstream
# update) and skips only optional AUR extras with --skip-optional.
set -euo pipefail

# ── flags ─────────────────────────────────────────────────────────────────
FORCE_ENGINE=false
SKIP_OPTIONAL=false
for arg in "$@"; do
  case "$arg" in
    --force-engine) FORCE_ENGINE=true ;;
    --skip-optional) SKIP_OPTIONAL=true ;;
    *) echo "Unknown flag: $arg (known: --force-engine, --skip-optional)" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Do not run as root — the script calls sudo itself where needed."
grep -qiE '^id(_like)?=.*arch' /etc/os-release 2>/dev/null || die "This installer only supports Arch/CachyOS."
command -v sudo >/dev/null 2>&1 || die "sudo is required."

REPO_URL="https://github.com/raellv7a-pixel/hydra-shell.git"
BRANCH="legacy-v4" # the actual active hydra-shell branch; origin/main still tracks upstream noctalia, not this fork's work
INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"
# A local invocation installs its committed checkout, not the remote release.
LOCAL_SOURCE=""
if [[ "${BASH_SOURCE[0]}" == *Scripts/bash/install.sh ]]; then
  source_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
  if [ -d "$source_dir/.git" ]; then
    LOCAL_SOURCE="$source_dir"
    BRANCH="$(git -C "$source_dir" branch --show-current)"
    [ -n "$BRANCH" ] || die "A local install requires a named git branch."
  fi
fi
command -v umbriel >/dev/null 2>&1 || die "Hydra requires an installed Umbriel compositor."
ENGINE_SRC_DIR="$(mktemp -d /tmp/noctalia-qs-build.XXXXXX)"
trap 'rm -rf "$ENGINE_SRC_DIR"' EXIT

# ── 1. runtime dependencies (pacman, official repos) ────────────────────────
# Audited from every Process{command:[...]}, exec_cmd(...) and `command -v`
# check under Services/, Modules/, Scripts/ — not copied from DEPENDENCIES.md,
# which is missing about a third of these (ddcutil, brightnessctl, wlsunset,
# cliphist, wlr-randr, playerctl, bluez, networkmanager, pipewire/wireplumber,
# polkit, power-profiles-daemon, udisks2, qt6ct, xdg-desktop-portal-hyprland/
# -gtk, git, gifski, shelly).
RUNTIME_PACMAN=(
  # Qt/QML runtime the shell itself needs
  qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-multimedia qt6-svg qt6ct
  # Umbriel is provided by the session; don't install another compositor.
  # Screenshot / clipboard / OCR / QR / Screen Toolkit (Modules/ScreenToolkit)
  grim slurp hyprpicker wl-clipboard
  tesseract tesseract-data-eng tesseract-data-por
  imagemagick zbar curl ffmpeg jq gifski
  # File pickers or scripted tooling (python3 for EDS calendar + pick-file.sh)
  python python-gobject
  # Generic portal/file chooser support; screen sharing uses the Umbriel backend.
  xdg-desktop-portal xdg-desktop-portal-gtk
  # Screen recording, OCR translation, GTK3 theming for @define-color overrides
  wf-recorder translate-shell adw-gtk-theme
  # Hardware: laptop/external brightness, night light, clipboard history,
  # monitor layout, media keys (binds.lua's playerctl calls)
  brightnessctl ddcutil wlsunset cliphist wlr-randr wget playerctl
  # Bluetooth / network (BluetoothService.qml, NetworkService.qml, VPNService.qml)
  bluez bluez-utils networkmanager
  # Audio stack (AudioService.qml's wpctl calls need this to exist at all)
  pipewire pipewire-pulse pipewire-alsa wireplumber
  # Polkit agent (Modules/Polkit/PolkitWindow.qml is the UI; the daemon/pkexec
  # still needs to be installed), power profiles, USB drive service, git for
  # the About tab's version check and for cloning this repo itself
  polkit power-profiles-daemon udisks2 git
  # CachyOS's own unified package manager — ApplicationsProvider.qml's
  # update-checking/install/remove flow shells out to it directly
  shelly shelly-flatpak-backend
)

# Cheap official-repo extras that unlock specific opt-in features. Installing
# the binary never turns the feature on by itself (e.g. evtest still needs
# explicit device/group consent in Settings → OSD).
OPTIONAL_PACMAN=(
  fastfetch   # About tab system info
  evtest      # OSD "show pressed keys" (off by default)
  vulkan-tools # WallpaperUpscaleService's vulkaninfo capability check
  waifu2x-ncnn-vulkan # AI wallpaper upscaler (in official repos, not AUR)
  khal        # CLI calendar backend (Services/Location/Calendar/Khal.qml)
  xorg-xcursorgen librsvg # Xcursor fallback for the "Cursor" color model (Settings > Modelos de Cores)
)

# Build toolchain for noctalia-qs (see step 2) — kept installed permanently
# since this is a dev machine that will likely rebuild the engine again after
# upstream updates; prune with `pacman -Rns $(pacman -Qtdq)` if ever unwanted.
ENGINE_BUILD_PACMAN=(
  cmake ninja pkgconf cli11 vulkan-headers spirv-tools
  libdrm cpptrace jemalloc wayland wayland-protocols libxcb glib2 pam base-devel
)


log "Installing runtime dependencies (pacman)"
sudo pacman -S --needed --noconfirm "${RUNTIME_PACMAN[@]}"

if ! $SKIP_OPTIONAL; then
  log "Installing optional extras (pacman)"
  sudo pacman -S --needed --noconfirm "${OPTIONAL_PACMAN[@]}"
fi

# ── 2. build & install the noctalia-qs engine (binary: qs / quickshell) ────
# Cloned from raellv7a-pixel/noctalia-qs (our own fork, byte-identical to
# upstream noctalia-dev/noctalia-qs at the point it was archived on
# 2026-07-12 — Noctalia v5 dropped Quickshell/QML entirely, so upstream has
# no reason to un-archive it). Building from our own copy, not upstream's,
# means this installer keeps working even if the upstream repo is ever
# deleted outright, not just archived.
if command -v qs >/dev/null 2>&1 && ! $FORCE_ENGINE; then
  log "qs already on PATH ($(command -v qs)) — skipping engine build (use --force-engine to rebuild)"
else
  log "Building noctalia-qs engine from source (archived upstream, no AUR package — building from our own mirror)"
  sudo pacman -S --needed --noconfirm "${ENGINE_BUILD_PACMAN[@]}"
  git clone --depth 1 https://github.com/raellv7a-pixel/noctalia-qs.git "$ENGINE_SRC_DIR"
  cmake -S "$ENGINE_SRC_DIR" -B "$ENGINE_SRC_DIR/build" -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DDISTRIBUTOR="hydra-shell install.sh"
  cmake --build "$ENGINE_SRC_DIR/build"
  sudo cmake --install "$ENGINE_SRC_DIR/build"
  # cmake --install already symlinks /usr/local/bin/qs -> quickshell, but
  # some launch contexts (systemd --user, greeters, Hyprland's own exec
  # environment) don't carry /usr/local/bin on PATH — mirror DEPENDENCIES.md's
  # existing workaround into /usr/bin so `command -v qs`/`quickshell` always
  # resolves regardless of caller.
  sudo ln -sf /usr/local/bin/quickshell /usr/bin/quickshell
  sudo ln -sf /usr/local/bin/qs /usr/bin/qs
fi

# ── 3. Required Material 2025 backend and optional AUR extras ──────────────
# materialyoucolor v2 does not implement the 2025 spec. This is required even
# with --skip-optional; install-time downloads only, never during generation.
material_backend_ready() {
  python3 -c 'from importlib.metadata import version; from materialyoucolor.dynamiccolor.dynamic_scheme import DynamicScheme; from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors; v = tuple(map(int, version("materialyoucolor").split(".")[:3])); assert (3, 0, 2) <= v < (4, 0, 0)' 2>/dev/null
}
if ! material_backend_ready || ! $SKIP_OPTIONAL; then
  if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
    log "No AUR helper found — bootstrapping paru"
    sudo pacman -S --needed --noconfirm base-devel git
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
  fi
  AUR_HELPER="$(command -v paru || command -v yay)"
  if ! material_backend_ready; then
    log "Installing required Material 2025 backend"
    "$AUR_HELPER" -S --needed --noconfirm python-materialyoucolor3
    material_backend_ready || die "materialyoucolor >=3.0.2,<4 with Material 2025 support is required."
  fi
  if ! $SKIP_OPTIONAL; then
    AUR_PACKAGES=(wl-screenrec-git papirus-folders) # preferred recorder + optional icon color model
    if lspci 2>/dev/null | grep -qi nvidia; then
      AUR_PACKAGES+=(nvibrant-bin) # NVIDIA digital vibrance control
    fi
    log "Installing AUR extras: ${AUR_PACKAGES[*]}"
    "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}"
  fi
fi

# ── 4. system services the shell talks to over D-Bus ───────────────────────
log "Enabling system services (NetworkManager, bluetooth, power-profiles-daemon)"
sudo systemctl enable --now NetworkManager.service bluetooth.service power-profiles-daemon.service

# ── 5. clone/update the hydra-shell repo ────────────────────────────────────
mkdir -p "$(dirname "$INSTALL_DIR")"
if [ -d "$INSTALL_DIR/.git" ]; then
  if [ "$LOCAL_SOURCE" = "$INSTALL_DIR" ]; then
    log "Using the current checkout at $INSTALL_DIR"
  else
    log "Updating existing checkout at $INSTALL_DIR"
    if [ -n "$(git -C "$INSTALL_DIR" status --porcelain)" ]; then
      die "$INSTALL_DIR has uncommitted changes — resolve/commit them before re-running (this script never discards local work)."
    fi
    git -C "$INSTALL_DIR" fetch "${LOCAL_SOURCE:-origin}" "$BRANCH"
    if [ -n "$LOCAL_SOURCE" ]; then
      git -C "$INSTALL_DIR" checkout "$BRANCH" 2>/dev/null || git -C "$INSTALL_DIR" checkout -b "$BRANCH" FETCH_HEAD
      git -C "$INSTALL_DIR" merge --ff-only FETCH_HEAD
    else
      git -C "$INSTALL_DIR" checkout "$BRANCH"
      git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"
    fi
  fi
else
  log "Cloning hydra-shell into $INSTALL_DIR"
  git clone --branch "$BRANCH" "${LOCAL_SOURCE:-$REPO_URL}" "$INSTALL_DIR"
fi

# ── 5b. migrate pre-rebrand Noctalia state before anything reads it ────────
# Idempotent no-op once the directories/settings keys are already Hydra-named.
log "Migrating pre-rebrand Noctalia config, if any"
bash "$INSTALL_DIR/Scripts/bash/migrate-noctalia-config.sh"

# ── 6. provision native Umbriel configuration ────────────────────────────
  log "Installing Hydra keybinds for Umbriel"
  python3 "$INSTALL_DIR/Scripts/python/umbriel_keybinds.py" provision
  umbriel config validate
  # Umbriel's config.toml already owns autostart. When installing mid-session,
  # that event has passed; a running qs process will not be started twice.
  if [ -n "${UMBRIEL_SOCKET:-}" ] && ! pgrep -f 'qs -c hydra-shell' >/dev/null 2>&1; then
    setsid qs -c hydra-shell -d >/dev/null 2>&1 &
    disown
  fi

# ── 7. doctor summary ────────────────────────────────────────────────────
log "Doctor summary"

umbriel config validate
echo "  Umbriel: config validated"

check() {
  if command -v "$1" >/dev/null 2>&1; then printf '  [ok]   %s\n' "$1"; else printf '  [miss] %s (%s)\n' "$1" "$2"; fi
}
echo "Required:"
compositor_tool=umbriel
for b in qs "$compositor_tool" grim slurp hyprpicker wl-copy tesseract magick zbarimg curl ffmpeg jq \
         brightnessctl ddcutil wlsunset cliphist wlr-randr playerctl bluetoothctl nmcli \
         wpctl pkexec powerprofilesctl udisksctl git shelly wf-recorder trans; do
  check "$b" "runtime dependency"
done
echo "Optional:"
for b in fastfetch evtest vulkaninfo waifu2x-ncnn-vulkan khal wl-screenrec papirus-folders nvibrant; do
  check "$b" "optional feature"
done

if $TARGET_UMBRIEL; then
  log "Done. Hydra keybinds installed; Umbriel autostarts the shell on the next session."
else
  log "Done. Log into Hyprland to start hydra-shell (autostart.lua launches it automatically)."
fi
