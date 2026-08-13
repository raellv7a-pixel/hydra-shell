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
#      Noctalia v5 rewrite. Building from source is the only correct path
#      (this is also what nix/package.nix does under Nix).
#   3. Bootstraps an AUR helper (paru) only if genuinely needed, and installs
#      the handful of polish packages that only exist on the AUR.
#   4. Enables the system services the shell talks to over D-Bus
#      (NetworkManager, bluetooth, power-profiles-daemon).
#   5. Clones/updates the hydra-shell repo itself into the path Quickshell's
#      own convention expects (~/.config/quickshell/hydra-shell, matched by
#      `qs -c hydra-shell` in Assets/Hyprland/modules/{autostart,binds}.lua).
#   6. Runs the existing, idempotent Scripts/bash/hyprland-adopt.sh to install
#      the Hyprland Lua config (backs up whatever was there first).
#   7. Prints a doctor-style summary: Hyprland version check, and a pass/fail
#      table of every binary the shell can call, required and optional.
#
# Idempotent: safe to re-run. By default it skips rebuilding the qs engine if
# it's already on PATH (pass --force-engine to rebuild after an upstream
# update) and skips AUR/optional extras with --skip-optional.
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
  hyprland
  # Screenshot / clipboard / OCR / QR / Screen Toolkit (Modules/ScreenToolkit)
  grim slurp hyprpicker wl-clipboard
  tesseract tesseract-data-eng tesseract-data-por
  imagemagick zbar curl ffmpeg jq gifski
  # File pickers or scripted tooling (python3 for EDS calendar + pick-file.sh)
  python python-gobject
  # Portals — xdg-desktop-portal alone is NOT enough on Hyprland: screen
  # share (Scripts/bash/corvus-share-picker.sh, xdph.conf) and the GTK file
  # chooser fallback need the compositor-specific backends explicitly.
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
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

# ── 3. AUR extras (paru bootstrap only if actually needed) ─────────────────
if ! $SKIP_OPTIONAL; then
  if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
    log "No AUR helper found — bootstrapping paru"
    sudo pacman -S --needed --noconfirm base-devel git
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
  fi
  AUR_HELPER="$(command -v paru || command -v yay)"

  AUR_PACKAGES=(wl-screenrec-git papirus-folders) # preferred recorder + optional icon color model
  if lspci 2>/dev/null | grep -qi nvidia; then
    AUR_PACKAGES+=(nvibrant-bin) # NVIDIA digital vibrance control
  fi
  log "Installing AUR extras: ${AUR_PACKAGES[*]}"
  "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}"
fi

# ── 4. system services the shell talks to over D-Bus ───────────────────────
log "Enabling system services (NetworkManager, bluetooth, power-profiles-daemon)"
sudo systemctl enable --now NetworkManager.service bluetooth.service power-profiles-daemon.service

# ── 5. clone/update the hydra-shell repo ────────────────────────────────────
mkdir -p "$(dirname "$INSTALL_DIR")"
if [ -d "$INSTALL_DIR/.git" ]; then
  log "Updating existing checkout at $INSTALL_DIR"
  if [ -n "$(git -C "$INSTALL_DIR" status --porcelain)" ]; then
    die "$INSTALL_DIR has uncommitted changes — resolve/commit them before re-running (this script never discards local work)."
  fi
  git -C "$INSTALL_DIR" fetch origin "$BRANCH"
  git -C "$INSTALL_DIR" checkout "$BRANCH"
  git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"
else
  log "Cloning hydra-shell into $INSTALL_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

# ── 6. adopt the Hyprland config (existing, idempotent, backs up first) ────
log "Installing Hyprland Lua config"
bash "$INSTALL_DIR/Scripts/bash/hyprland-adopt.sh" "$INSTALL_DIR/Assets/Hyprland"

# ── 6b. launch immediately if already inside a running Hyprland session ────
# autostart.lua's exec-once fires on the "hyprland.start" event, which has
# already happened if we're installing mid-session (e.g. right after a fresh
# CachyOS+Hyprland install, logged in, running this script by hand) — a
# `hyprctl reload` does NOT refire it. Without this, the shell would only
# actually appear after the next logout/login, which fails the "instala e já
# está rodando" bar this script is held to.
if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1 && ! pgrep -x quickshell >/dev/null 2>&1; then
  log "Hyprland already running — starting hydra-shell now"
  setsid qs -c hydra-shell -d >/dev/null 2>&1 &
  disown
fi

# ── 7. doctor summary ────────────────────────────────────────────────────
log "Doctor summary"

if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
  hver="$(hyprctl version 2>/dev/null | grep -oP 'Hyprland \K[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
  smaller="$(printf '0.55\n%s\n' "${hver:-0.55}" | sort -V | head -1)"
  if [ -n "$hver" ] && [ "$smaller" != "0.55" ]; then
    warn "Running Hyprland $hver — hydra-shell's config is Lua-native (Hyprland >=0.55 required). Update Hyprland."
  else
    echo "  Hyprland version: ${hver:-unknown} (OK)"
  fi
else
  warn "Hyprland is not currently running — version check skipped, will apply on next login."
fi

check() {
  if command -v "$1" >/dev/null 2>&1; then printf '  [ok]   %s\n' "$1"; else printf '  [miss] %s (%s)\n' "$1" "$2"; fi
}
echo "Required:"
for b in qs hyprctl grim slurp hyprpicker wl-copy tesseract magick zbarimg curl ffmpeg jq \
         brightnessctl ddcutil wlsunset cliphist wlr-randr playerctl bluetoothctl nmcli \
         wpctl pkexec powerprofilesctl udisksctl git shelly wf-recorder trans; do
  check "$b" "runtime dependency"
done
echo "Optional:"
for b in fastfetch evtest vulkaninfo waifu2x-ncnn-vulkan khal wl-screenrec papirus-folders nvibrant; do
  check "$b" "optional feature"
done

log "Done. Log into Hyprland to start hydra-shell (autostart.lua launches it automatically)."
