# Credits

Noctalia Shell is made possible by the incredible work of many open-source projects and contributors.

## Design & Branding

- **MrDowntempo** - Creator of the Noctalia Owl and moon logo
- **[SaberJ2X](https://www.reddit.com/user/SaberJ64/)** - Creator of Talia, the Noctalia mascot

## Core Framework

- **[Quickshell](https://github.com/outfoxxed/quickshell)** - The Qt/QML-based Wayland shell framework that powers Noctalia

### Visual engine
- **[Caelestia Shell](https://github.com/caelestia-dots/shell)** (GPLv3) - Source of the Blob SDF rendering and velocity-driven deformation subsystem being adapted for Hydra Shell. The exact source inventory and modifications are tracked in [`LICENSES/Caelestia-Blob-Port.md`](LICENSES/Caelestia-Blob-Port.md).

## Runtime Dependencies

### System Integration
- **[brightnessctl](https://github.com/Hummer12007/brightnessctl)** - Screen brightness control
- **[wlsunset](https://sr.ht/~kennylevinsen/wlsunset/)** - Night light and blue light filter support
- **[wl-clipboard](https://github.com/bugaevc/wl-clipboard)** - Wayland clipboard utilities
- **[ddcutil](https://www.ddcutil.com/)** - External display brightness control
- **[power-profiles-daemon](https://gitlab.freedesktop.org/upower/power-profiles-daemon)** - Power profile management

### Media & Audio
- **[gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/about/)** - Hardware-accelerated screen recording
- **[Cava](https://github.com/karlstav/cava)** - Audio visualizer component

### Utilities
- **[cliphist](https://github.com/sentriz/cliphist)** - Clipboard history support

## Icons
- **[Tabler Icons](https://tabler.io/icons)** - Icon set used throughout the shell
- **[Riyan Resdian on Noun Project](https://thenounproject.com/creator/yaicon/)** - Plug icon

## Cursor Theme
- **[rtgiskard/bibata_cursor](https://github.com/rtgiskard/bibata_cursor)** (GPLv3) - Source of the vendored "Modern" cursor SVGs (`Assets/Cursor/Bibata`), recolored live from the shell's palette by `Scripts/python/src/theming/cursor-generate.py`
- **[Abdulkaiz Khatri (ful1e5)](https://github.com/ful1e5/Bibata_Cursor)** - Original Bibata cursor design
- **[SakibShahariar/material-bibata-cursor](https://github.com/SakibShahariar/material-bibata-cursor)** - Inspiration for recoloring Bibata through Material Design 3's Container/Primary roles

## Audio Assets
- **[Universfield on Pixabay](https://pixabay.com/users/universfield-28281460/)** - Notification sound effect
- **[DrNI on Freesound](https://freesound.org/people/DrNI/sounds/34562/)** - Timer's alarm sound effect
- **[Lucas McCallister on Freesound](http://www.freesound.org/samplesViewSingle.php?id=67091)** - Volume change feedback sound effect

## Bundled Plugin Assets
- **[Noctalia Tamagotchi](https://github.com/noctalia-dev/noctalia-plugins)** (MIT) - Frog sprites and feeding sound vendored in `Assets/Icons/Tamagotchi` and `Assets/Sounds/Tamagotchi`; plugin by Joaquin Righetti and Lucia Bollati, with the Forgy artwork credited to Lucia Bollati.


## Special Thanks
- The **Wayland** community for building the future of Linux desktop graphics
- The **Niri**, **Hyprland**, **Sway**, **Labwc**, and **MangoWC** teams for their excellent Wayland compositors
- All the contributors and users who have helped make Noctalia better

## License
The combined Hydra Shell work is distributed under GPL-3.0-only. See [LICENSE](LICENSE).

Noctalia-origin code retains its original MIT grant in [`LICENSES/Noctalia-MIT.txt`](LICENSES/Noctalia-MIT.txt). The Caelestia Blob port remains GPLv3 and is documented in [`LICENSES/Caelestia-Blob-Port.md`](LICENSES/Caelestia-Blob-Port.md). Each dependency listed above is governed by its respective license.
