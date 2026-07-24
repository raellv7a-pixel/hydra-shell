# Raell Dashboard

A polished personal dashboard for Noctalia Shell, inspired by Raell's old Caelestia dashboard and rebuilt as a Noctalia plugin.

## Features

- Bar widget with media info, album art, progress ring, and configurable audio visualizer effects.
- Large dashboard panel with profile, quick toggles, performance stats, system sliders, notifications, media controls, weather, and calendar.
- Integrated capture actions: area GIF, area MP4, area screenshot, and screen screenshot.
- Wallpaper selector shortcut using Noctalia's native wallpaper panel.
- Disk pager for multiple mounted disks.
- Weather/calendar pager with mouse wheel support.
- Portuguese and English translations.
- Customizable profile banner with automatic, custom, random-folder, and disabled modes.
- Optional profile banner overlay, blur, animated borders, custom border palettes, and GIF support.
- Per-component visual customization for dashboard cards, buttons, text, accents, and animated borders.
- Adaptive panel scaling for smaller screens and laptops.

## Requirements

Raell Dashboard requires Noctalia Shell `4.4.1` or newer.

The capture buttons use common Wayland tools:

- `grim`
- `slurp`
- `wl-clipboard`
- `wf-recorder`
- `ffmpeg`
- `hyprshot` is optional but recommended on Hyprland for a better screenshot flow.

### Arch / CachyOS

```bash
sudo pacman -S grim slurp wl-clipboard wf-recorder ffmpeg
```

Optional Hyprland screenshot helper:

```bash
paru -S hyprshot
```

or:

```bash
yay -S hyprshot
```

### Fedora

```bash
sudo dnf install grim slurp wl-clipboard wf-recorder ffmpeg
```

If `ffmpeg` is unavailable from the default repositories, enable RPM Fusion first.

### Ubuntu / Debian

```bash
sudo apt install grim slurp wl-clipboard wf-recorder ffmpeg
```

Package names can vary by distro. If your distro does not provide `hyprshot`, screenshots still fall back to `grim`, `slurp`, and `wl-copy`.

## Install From Plugin Sources

Add this repository in Noctalia:

```text
https://github.com/raellx22/raell-noctalia-plugins
```

Then install `Raell Dashboard` from the `Available` tab.

## Notes

- `settings.json` is intentionally not included. Noctalia creates it locally for each user.
- Capture recordings are saved in `~/Videos` as `raell-capture-YYYY-MM-DD_HH-MM-SS.gif` or `.mp4`.
- The plugin does not depend on the separate `screen-toolkit` or `screenshot` plugins.
