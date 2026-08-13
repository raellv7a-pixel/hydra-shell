#!/usr/bin/env python3
"""Build the shell's adaptive Bibata-based cursor theme.

Recolors the vendored Bibata "Modern" SVG set (Assets/Cursor/Bibata/svg)
using colors derived live from the shell's generated Material palette, then
builds:

  - A hyprcursor theme (vector, `hyprcursors/*.hlc`) — the primary format on
    Hyprland, resolution-independent, built with the stdlib only (no extra
    system dependency: `.hlc` files are plain zip archives, matching
    rtgiskard/bibata_cursor's own `--hypr` build).
  - An Xcursor fallback (`cursors/` + `index.theme`) for XWayland clients and
    toolkits that don't speak the hyprcursor/wp-cursor-shape protocol — only
    if `rsvg-convert` and `xcursorgen` are both on PATH (optional system
    packages, see DEPENDENCIES.md).

Both are installed under the same theme directory so a single theme name
works everywhere: ~/.local/share/icons/<THEME_NAME>/.

Applies the result live via `hyprctl setcursor` and `gsettings` (both
best-effort, silently skipped when unavailable) — same dual-apply approach
Material Bibata Cursor's own README recommends.

Usage: cursor-generate.py <primary-hex> [size]
Invoked by the "cursor" template's post_hook (Services/Theming/TemplateRegistry.qml),
itself only run by Scripts/python/src/theming/lib/renderer.py when the
rendered primary-color cache file actually changed.
"""

import colorsys
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

THEME_NAME = "Hydra-Adaptive"
THEME_DESCRIPTION = "Bibata cursors, recolored live from Hydra Shell's Material palette"

SCRIPT_DIR = Path(__file__).resolve().parent
SVG_SRC = SCRIPT_DIR.parents[3] / "Assets" / "Cursor" / "Bibata" / "svg"
ICONS_DIR = Path.home() / ".local" / "share" / "icons"
BUILD_DIR = Path.home() / ".cache" / "noctalia" / "cursor-build"

DEFAULT_SIZE = 24

# Recolor placeholders used verbatim by every vendored SVG (see
# Assets/Cursor/Bibata/README.md).
PLACEHOLDER_BODY = "#00FF00"
PLACEHOLDER_OUTLINE = "#0000FF"
PLACEHOLDER_WATCH = "#FF0000"

# Xcursor alias policy: only these human/CSS-friendly names get a physical
# symlink in cursors/ (mirrors rtgiskard/bibata_cursor's own "adwaita"
# default policy) — the long legacy MD5-hash aliases some toolkits look up
# are skipped, they add clutter without practical benefit here.
X11_ALIAS_POLICY = {
    "alias", "all-scroll", "arrow", "bd_double_arrow", "bottom_left_corner",
    "bottom_right_corner", "bottom_side", "cell", "col-resize", "context-menu",
    "copy", "cross", "cross_reverse", "crosshair", "default", "diamond_cross",
    "dnd-move", "e-resize", "ew-resize", "fd_double_arrow", "fleur", "grab",
    "grabbing", "hand1", "hand2", "help", "left_ptr", "left_side", "move",
    "n-resize", "ne-resize", "nesw-resize", "no-drop", "not-allowed",
    "ns-resize", "nw-resize", "nwse-resize", "pointer", "progress",
    "question_arrow", "right_side", "row-resize", "s-resize",
    "sb_h_double_arrow", "sb_v_double_arrow", "se-resize", "sw-resize",
    "tcross", "text", "top_left_arrow", "top_left_corner", "top_right_corner",
    "top_side", "vertical-text", "w-resize", "wait", "watch", "xterm",
    "zoom-in", "zoom-out",
}


def shape(hot=(128, 128), aliases=None, frames=1, delay=0):
    return {"hot": hot, "aliases": aliases or [], "frames": frames, "delay": delay}


# name -> spec, trimmed from rtgiskard/bibata_cursor's config/build.toml to
# exactly the shapes vendored in Assets/Cursor/Bibata/svg (the "Modern",
# left-hand set). hot = (x, y) hotspot in the source SVGs' 256x256 canvas.
SHAPES = {
    "bd_double_arrow": shape(aliases=["c7088f0f3e6c8088236ef8e1e3e70000", "nwse-resize", "size_fdiag"]),
    "bottom_left_corner": shape((26, 232), ["sw-resize"]),
    "bottom_right_corner": shape((229, 232), ["se-resize"]),
    "bottom_side": shape((129, 234), ["s-resize"]),
    "bottom_tee": shape((128, 230)),
    "center_ptr": shape((127, 17)),
    "circle": shape((55, 17), ["forbidden"]),
    "context-menu": shape((57, 17)),
    "copy": shape((55, 17), ["1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872", "b66166c04f8c3109214a4fbd64a50fc8"]),
    "cross": shape(aliases=["cross_reverse", "diamond_cross"]),
    "crossed_circle": shape(aliases=["03b6e0fcb3499374a867c041f52298f0", "not-allowed"]),
    "crosshair": shape(),
    "dnd_no_drop": shape((100, 65), ["no-drop"]),
    "dnd-ask": shape((100, 65)),
    "dnd-copy": shape((100, 65)),
    "dnd-link": shape((100, 65), ["alias"]),
    "dotbox": shape(aliases=["dot_box_mask", "draped_box", "icon", "target"]),
    "fd_double_arrow": shape(aliases=["fcf1c3c7cd4491d801f1e1c78f100000", "nesw-resize", "size_bdiag"]),
    "grabbing": shape((128, 66), ["closedhand", "dnd-move", "dnd-none", "fcf21c00b30f7e3f83fe0dfd12e71cff"]),
    "hand1": shape((144, 79), ["grab", "openhand"]),
    "hand2": shape((114, 18), ["9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106", "pointer", "pointing_hand"]),
    "left_ptr": shape((55, 17), ["arrow", "default", "top_left_arrow"]),
    "left_ptr_watch": shape((55, 17), ["00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599", "progress"], frames=54, delay=40),
    "left_side": shape((21, 128), ["w-resize"]),
    "left_tee": shape((230, 128)),
    "link": shape((55, 17), ["3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f", "a2a266d0498c3104214a47bd64ab0fc8"]),
    "ll_angle": shape((30, 223)),
    "lr_angle": shape((224, 230)),
    "move": shape(aliases=["4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f", "all-scroll", "fleur", "size_all"]),
    "pencil": shape((46, 211), ["draft"]),
    "plus": shape(aliases=["cell"]),
    "pointer-move": shape((55, 17)),
    "question_arrow": shape((42, 86), ["5c6cd98b3f3ebcb1f9c7f1c204630408", "d9ce0ab605698f320427677b458ad60b", "help", "left_ptr_help", "whats_this"]),
    "right_ptr": shape((204, 17), ["draft_large", "draft_small"]),
    "right_side": shape((233, 128), ["e-resize"]),
    "right_tee": shape((29, 128)),
    "sb_down_arrow": shape((128, 222), ["down-arrow"]),
    "sb_h_double_arrow": shape(aliases=["028006030e0e7ebffc7f7070c0600140", "14fef782d02440884392942c1120523", "col-resize", "ew-resize", "h_double_arrow", "size-hor", "size_hor", "split_h"]),
    "sb_left_arrow": shape((33, 128), ["left-arrow"]),
    "sb_right_arrow": shape((223, 128), ["right-arrow"]),
    "sb_up_arrow": shape((128, 33), ["up-arrow"]),
    "sb_v_double_arrow": shape(aliases=["00008160000006810000408080010102", "2870a09082c103050810ffdffffe0204", "double_arrow", "ns-resize", "row-resize", "size-ver", "size_ver", "split_v", "v_double_arrow"]),
    "tcross": shape(aliases=["color-picker"]),
    "top_left_corner": shape((29, 24), ["nw-resize"]),
    "top_right_corner": shape((229, 24), ["ne-resize"]),
    "top_side": shape((128, 23), ["n-resize"]),
    "top_tee": shape((128, 27)),
    "ul_angle": shape((33, 33)),
    "ur_angle": shape((225, 33)),
    "vertical-text": shape(),
    "wait": shape(aliases=["watch"], frames=54, delay=40),
    "wayland-cursor": shape(),
    "X_cursor": shape(aliases=["pirate", "x-cursor"]),
    "xterm": shape(aliases=["ibeam", "text"]),
    "zoom-in": shape((116, 116)),
    "zoom-out": shape((116, 116)),
}


# ----------------------------------------------------------------------------
# Color derivation
# ----------------------------------------------------------------------------
def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    return tuple(int(hex_str[i:i + 2], 16) for i in (0, 2, 4))


def hls_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#{:02X}{:02X}{:02X}".format(round(r * 255), round(g * 255), round(b * 255))


def derive_palette(primary_hex):
    """Derive (body, outline, watch) from the shell's primary accent.

    Follows Material Bibata Cursor's Container/Primary split: the body stays
    dark & desaturated so it reads against any wallpaper, the outline carries
    the actual accent — both pinned to fixed lightness so they don't flip
    with the shell's light/dark mode (M3's own "primary" tone does flip,
    which would make the cursor itself change legibility with the mode).
    """
    r, g, b = hex_to_rgb(primary_hex)
    h, _l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)

    outline = hls_to_hex(h, 0.72, max(s, 0.45))
    body = hls_to_hex(h, 0.17, min(max(s, 0.30), 0.55))
    watch = hls_to_hex(h, 0.08, min(max(s * 0.4, 0.05), 0.25))
    return body, outline, watch


def recolor(svg_text, body, outline, watch):
    return (svg_text
            .replace(PLACEHOLDER_BODY, body)
            .replace(PLACEHOLDER_OUTLINE, outline)
            .replace(PLACEHOLDER_WATCH, watch))


# ----------------------------------------------------------------------------
# Source frame resolution
# ----------------------------------------------------------------------------
def frame_sources(name, spec):
    """Yield vendored SVG source paths for one shape, in frame order."""
    if spec["frames"] <= 1:
        yield SVG_SRC / f"{name}.svg"
    else:
        for i in range(1, spec["frames"] + 1):
            yield SVG_SRC / name / f"{name}-{i:02d}.svg"


# ----------------------------------------------------------------------------
# Hyprcursor build (vector, stdlib-only)
# ----------------------------------------------------------------------------
def build_hyprcursor(out_dir, body, outline, watch):
    hypr_dir = out_dir / "hyprcursors"
    hypr_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "manifest.hl").write_text(
        f"name = {THEME_NAME}\n"
        f"description = {THEME_DESCRIPTION}\n"
        "version = 0.1\n"
        "cursors_directory = hyprcursors\n"
    )

    for name, spec in SHAPES.items():
        raw_dir = hypr_dir / name
        raw_dir.mkdir(parents=True, exist_ok=True)

        hot_x, hot_y = spec["hot"]
        meta_lines = [
            "resize_algorithm = none",
            f"hotspot_x = {hot_x / 256:.4f}",
            f"hotspot_y = {hot_y / 256:.4f}",
        ]
        if spec["aliases"]:
            meta_lines.append("")
            meta_lines.extend(f"define_override = {a}" for a in spec["aliases"])

        meta_lines.append("")
        frames = list(frame_sources(name, spec))
        multi = len(frames) > 1
        for i, src in enumerate(frames):
            dst_name = f"{name}_{i:02d}.svg" if multi else f"{name}.svg"
            (raw_dir / dst_name).write_text(recolor(src.read_text(), body, outline, watch))
            line = f"define_size = 0, {dst_name}"
            if multi and spec["delay"] > 0:
                line += f", {spec['delay']}"
            meta_lines.append(line)

        (raw_dir / "meta.hl").write_text("\n".join(meta_lines) + "\n")

        # hyprcursor shapes are individually zipped (.hlc = a zip archive of
        # meta.hl + its images), matching the on-disk layout hyprcursor
        # itself expects and reading — no external tool needed to produce it.
        hlc_path = hypr_dir / f"{name}.hlc"
        with zipfile.ZipFile(hlc_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for item in raw_dir.iterdir():
                zf.write(item, arcname=item.name)
        shutil.rmtree(raw_dir)


# ----------------------------------------------------------------------------
# Xcursor fallback build (optional: needs rsvg-convert + xcursorgen)
# ----------------------------------------------------------------------------
def have(binary):
    return shutil.which(binary) is not None


def build_xcursor(out_dir, body, outline, watch, size):
    cursors_dir = out_dir / "cursors"
    cursors_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "index.theme").write_text(
        "[Icon Theme]\n"
        f"Name={THEME_NAME}\n"
        f"Comment={THEME_DESCRIPTION}\n"
        "Inherits=hicolor\n"
    )

    raster_root = BUILD_DIR / "x11-raster"
    if raster_root.exists():
        shutil.rmtree(raster_root)
    raster_root.mkdir(parents=True)

    for name, spec in SHAPES.items():
        shape_dir = raster_root / name
        shape_dir.mkdir()

        hot_x, hot_y = spec["hot"]
        px_x = round(size * hot_x / 256)
        px_y = round(size * hot_y / 256)

        frames = list(frame_sources(name, spec))
        multi = len(frames) > 1
        config_lines = []
        for i, src in enumerate(frames):
            svg_tmp = shape_dir / f"{name}_{i:02d}.svg"
            svg_tmp.write_text(recolor(src.read_text(), body, outline, watch))
            png_name = f"{name}_{i:02d}.png"
            subprocess.run(
                ["rsvg-convert", "-a", "-w", str(size), "-h", str(size),
                 "-o", str(shape_dir / png_name), str(svg_tmp)],
                check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            line = f"{size} {px_x} {px_y} {png_name}"
            if multi and spec["delay"] > 0:
                line += f" {spec['delay']}"
            config_lines.append(line)

        config_path = shape_dir / "meta.x11"
        config_path.write_text("\n".join(config_lines) + "\n")

        target = cursors_dir / name
        subprocess.run(
            ["xcursorgen", "-p", str(shape_dir), str(config_path), str(target)],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

        if target.exists():
            for alias in spec["aliases"]:
                if alias in X11_ALIAS_POLICY:
                    link = cursors_dir / alias
                    link.unlink(missing_ok=True)
                    link.symlink_to(name)

    shutil.rmtree(raster_root)


# ----------------------------------------------------------------------------
# Apply (best-effort, silent when the relevant tool/session is absent)
# ----------------------------------------------------------------------------
def apply_theme(size):
    subprocess.run(["hyprctl", "setcursor", THEME_NAME, str(size)],
                    check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", THEME_NAME],
                    check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)],
                    check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if len(sys.argv) < 2:
        print("usage: cursor-generate.py <primary-hex> [size]", file=sys.stderr)
        return 1

    primary_hex = sys.argv[1]
    try:
        size = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_SIZE
    except ValueError:
        size = DEFAULT_SIZE

    if not SVG_SRC.is_dir():
        print(f"error: vendored cursor SVGs not found at {SVG_SRC}", file=sys.stderr)
        return 1

    body, outline, watch = derive_palette(primary_hex)

    build_dir = BUILD_DIR / THEME_NAME
    if build_dir.exists():
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True)

    build_hyprcursor(build_dir, body, outline, watch)

    x11_built = False
    if have("rsvg-convert") and have("xcursorgen"):
        build_xcursor(build_dir, body, outline, watch, size)
        x11_built = True
    else:
        print("cursor-generate: rsvg-convert/xcursorgen not found, skipping Xcursor fallback "
              "(hyprcursor theme still built; XWayland/non-hyprcursor apps won't see it)",
              file=sys.stderr)

    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    install_dir = ICONS_DIR / THEME_NAME
    if install_dir.exists():
        shutil.rmtree(install_dir)
    shutil.move(str(build_dir), str(install_dir))

    apply_theme(size)

    print(f"cursor-generate: installed {THEME_NAME} "
          f"(body={body} outline={outline} watch={watch} size={size} x11={x11_built})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
