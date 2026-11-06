#!/usr/bin/env python3
# Adapted from iNiR scripts/images/least_busy_region.py (GPL-3.0),
# d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c. Only luma-grid dependency subset.

import os
os.environ["OPENCV_LOG_LEVEL"] = "SILENT"
# Per-widget samples are tiny; library thread pools spinning on every core cost more than the work.
for _var in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_var, "1")
import cv2
import numpy as np
import argparse
import fcntl
import hashlib
import json
import tempfile

cv2.setNumThreads(1)

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "hydra", "iris-region-sampling")
CACHE_KEEP = 8
BACKGROUND = (0, 0, 0)

def center_crop(img, target_w, target_h):
    h, w = img.shape[:2]
    if w == target_w and h == target_h:
        return img
    x1 = max(0, (w - target_w) // 2)
    y1 = max(0, (h - target_h) // 2)
    x2 = x1 + target_w
    y2 = y1 + target_h
    return img[y1:y2, x1:x2]

def center_on_black(img, target_w, target_h):
    """The picture centred on a black screen, cut where it overflows (fit's and center's bars)."""
    img = center_crop(img, target_w, target_h)
    h, w = img.shape[:2]
    out = np.zeros((target_h, target_w) + img.shape[2:], dtype=img.dtype)
    out[:] = BACKGROUND
    x, y = (target_w - w) // 2, (target_h - h) // 2
    out[y:y + h, x:x + w] = img
    return out

def _read_screen_image(image_path, flags, screen_width, screen_height, screen_mode):
    """The wallpaper as the screen shows it in each scaling mode (Wallpapers.fillMode)."""
    img = cv2.imread(image_path, flags)
    if img is None:
        return None
    orig_h, orig_w = img.shape[:2]
    if screen_mode == "stretch":
        return cv2.resize(img, (screen_width, screen_height), interpolation=cv2.INTER_AREA)
    if screen_mode == "center":
        return center_on_black(img, screen_width, screen_height)
    if screen_mode == "tile":
        # Qt tiles from a centred copy (Image.Tile with the default centre alignment).
        reps_y, reps_x = -(-screen_height // orig_h) + 2, -(-screen_width // orig_w) + 2
        tiled = np.tile(img, (reps_y, reps_x) + (1,) * (img.ndim - 2))
        x = (orig_w - ((screen_width - orig_w) // 2) % orig_w) % orig_w
        y = (orig_h - ((screen_height - orig_h) // 2) % orig_h) % orig_h
        return tiled[y:y + screen_height, x:x + screen_width]
    scale_w = screen_width / orig_w
    scale_h = screen_height / orig_h
    scale = min(scale_w, scale_h) if screen_mode == "fit" else max(scale_w, scale_h)
    img = cv2.resize(img, (max(1, int(orig_w * scale)), max(1, int(orig_h * scale))), interpolation=cv2.INTER_LANCZOS4)
    return center_on_black(img, screen_width, screen_height) if screen_mode == "fit" else center_crop(img, screen_width, screen_height)

def load_screen_image(image_path, screen_width=None, screen_height=None, screen_mode="fill", grayscale=False):
    """Wallpaper scaled and cropped to the screen, cached per file revision and screen geometry."""
    flags = cv2.IMREAD_GRAYSCALE if grayscale else cv2.IMREAD_COLOR
    if screen_width is None or screen_height is None:
        return cv2.imread(image_path, flags)
    try:
        st = os.stat(image_path)
        key = hashlib.sha1(f"{os.path.realpath(image_path)}|{st.st_mtime_ns}|{st.st_size}|{screen_width}x{screen_height}|{screen_mode}|{'gray' if grayscale else 'bgr'}|{BACKGROUND}".encode()).hexdigest()
        os.makedirs(CACHE_DIR, exist_ok=True)
        cache_path = os.path.join(CACHE_DIR, key + ".npy")
        lock = open(os.path.join(CACHE_DIR, key + ".lock"), "w")
    except OSError:
        return _read_screen_image(image_path, flags, screen_width, screen_height, screen_mode)
    with lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return np.load(cache_path)
        except (OSError, ValueError):
            pass
        img = _read_screen_image(image_path, flags, screen_width, screen_height, screen_mode)
        if img is None:
            return None
        try:
            with tempfile.NamedTemporaryFile(dir=CACHE_DIR, suffix=".tmp", delete=False) as tmp:
                np.save(tmp, img)
            os.replace(tmp.name, cache_path)
            entries = sorted((e for e in os.scandir(CACHE_DIR) if e.name.endswith(".npy")), key=lambda e: e.stat().st_mtime, reverse=True)
            for stale in entries[CACHE_KEEP:]:
                for suffix in (".npy", ".lock"):
                    try:
                        os.unlink(stale.path[:-4] + suffix)
                    except OSError:
                        pass
        except OSError:
            pass
        return img

def luma_grid(image_path, cell, screen_width, screen_height, screen_mode="fill"):
    """Per-cell mean luma, mean squared luma and mean colour of the wallpaper as the screen shows it.

    One run serves every widget on that screen: a widget sums the cells under its rect, so its
    brightness, spread and mean colour are exact for any position without another process.
    """
    img = load_screen_image(image_path, screen_width, screen_height, screen_mode)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    h, w = img.shape[:2]
    cols = max(1, -(-w // cell))
    rows = max(1, -(-h // cell))
    pad_w = cols * cell - w
    pad_h = rows * cell - h
    if pad_w or pad_h:
        img = cv2.copyMakeBorder(img, 0, pad_h, 0, pad_w, cv2.BORDER_REPLICATE)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    shape = (rows, cell, cols, cell)
    mean = gray.reshape(shape).mean(axis=(1, 3))
    sq = (gray * gray).reshape(shape).mean(axis=(1, 3))
    bgr = img.astype(np.float32).reshape(rows, cell, cols, cell, 3).mean(axis=(1, 3))
    return {
        "cols": int(cols),
        "rows": int(rows),
        "cell": int(cell),
        "width": int(w),
        "height": int(h),
        "mean": [int(round(v)) for v in mean.flatten()],
        "sq": [int(round(v)) for v in sq.flatten()],
        "r": [int(round(v)) for v in bgr[..., 2].flatten()],
        "g": [int(round(v)) for v in bgr[..., 1].flatten()],
        "b": [int(round(v)) for v in bgr[..., 0].flatten()],
    }


def main():
    global BACKGROUND
    parser = argparse.ArgumentParser(description="Original iRiS wallpaper luma grid")
    parser.add_argument("image_path")
    parser.add_argument("--luma-grid", type=int, default=24)
    parser.add_argument("--screen-width", type=int, required=True)
    parser.add_argument("--screen-height", type=int, required=True)
    parser.add_argument("--screen-mode", choices=["fill", "fit", "stretch", "center", "tile"], default="fill")
    parser.add_argument("--fill-color", default="#000000")
    args = parser.parse_args()
    rgb = args.fill_color.lstrip("#")
    BACKGROUND = tuple(int(rgb[i:i + 2], 16) for i in (4, 2, 0))
    print(json.dumps(luma_grid(args.image_path, args.luma_grid, args.screen_width, args.screen_height, args.screen_mode), separators=(",", ":")))


if __name__ == "__main__":
    main()
