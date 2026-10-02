# Credits

Hydra Shell is a fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell)
(MIT, Copyright (c) 2025 noctalia-dev) and is made possible by the incredible work of many
open-source projects and contributors.

## Upstream

- **[noctalia-dev](https://github.com/noctalia-dev)** - Authors of Noctalia Shell, the upstream project this shell is built on

## Design & Branding

- **MrDowntempo** - Creator of the Noctalia Owl and moon logo (upstream branding, no longer shipped)
- **[SaberJ2X](https://www.reddit.com/user/SaberJ64/)** - Creator of Talia, the Noctalia mascot

## Core Framework

- **[Quickshell](https://github.com/outfoxxed/quickshell)** - The Qt/QML-based Wayland shell framework that powers Hydra Shell

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
- **[T-Dynamos/materialyoucolor-python](https://github.com/T-Dynamos/materialyoucolor-python)** (MIT) - Real Material 2025 DynamicScheme and color roles; the historical Hydra 2021 engine and quantizer remain independent.

## Application Themes
- **[refact0r/system24](https://github.com/refact0r/system24)** (MIT, Copyright (c) 2025 refact0r) - Discord System24 layout imported from upstream; `Assets/Templates/discord-system24.css` supplies Hydra palette mappings and retains the full MIT notice. No Noctalia community template or logo is incorporated.
- Prism Launcher, Fastfetch, Claude Code, OpenCode, tmux and Fcitx5 templates are original Hydra mappings of their documented public formats, not copies of unlicensed community templates. Optional reload uses the application's existing `tmux` or `fcitx5-remote` executable.
- Phase 2 uses original Hydra ANSI derivation, Neovim highlights, grouped Zellij KDL, TextMate syntax scopes, Fzf fragments, Obsidian snippets and app-local GTK CSS. No Noctalia community template or external stylesheet/plugin code was copied.
- **[Neovim public API](https://neovim.io/doc/user/api.html)** and **[RRethy/base16-nvim](https://github.com/RRethy/base16-nvim)** (MIT) were inspected as references; the implementation uses native Neovim APIs and requires no Base16 plugin. Reload is an opt-in file watcher, not a process signal.
- **[Zellij themes](https://zellij.dev/documentation/themes.html)**, **[Codex theme loader](https://github.com/openai/codex/blob/main/codex-rs/tui/src/render/highlight.rs)**, **[Bat themes](https://github.com/sharkdp/bat#adding-new-themes)** and **[Fzf options](https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1)** supply public format/path contracts only; Hydra mappings are independently authored.
- **[Antigravity CLI reference](https://antigravity.google/docs/cli/reference)** and **[Gemini migration notes](https://antigravity.google/docs/cli/gcli-migration)** define the current terminal scheme and settings path. Legacy custom seeds were deliberately not reused.
- **[Obsidian CSS snippets](https://help.obsidian.md/snippets)**, **[Inkscape theme loader](https://gitlab.com/inkscape/inkscape/-/blob/INKSCAPE_1_4_2/src/ui/themes.cpp)** and **[GIMP theme loader](https://github.com/GNOME/gimp/blob/master/app/gui/themes.c)** were used to verify discovery/import locations. Existing user snippets/styles/configuration remain user-owned.
- **[MaterialFox](https://github.com/muckSponge/MaterialFox)** was evaluated only; no CSS was incorporated and no optional export was added because its internal Firefox-variable contract is not versioned/stable for this integration.

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
- All the contributors and users who have helped make Noctalia (and therefore Hydra Shell) better

## License
Hydra Shell is licensed under the MIT License, inherited from Noctalia Shell. See [LICENSE](LICENSE) for details.

Each dependency listed above is governed by its own respective license. Please refer to their individual projects for licensing information.
