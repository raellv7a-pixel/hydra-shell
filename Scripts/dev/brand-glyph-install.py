#!/usr/bin/env python3
"""Replace the brand glyph (U+EC33) of the icon font with a traced Hydra mark.

Input: a potrace SVG (single flat path, cubic beziers only).
Output: the TTF, in place, with the glyph redrawn and renamed to "hydra".
"""
import re
import sys

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

SVG, TTF, CODEPOINT, NEW_NAME = sys.argv[1], sys.argv[2], 0xEC33, "hydra"

# --- read potrace output ---------------------------------------------------
svg = open(SVG).read()
tx, ty = (float(v) for v in re.search(
    r'transform="translate\(([-\d.]+),([-\d.]+)\)', svg).groups())
sx, sy = (float(v) for v in re.search(r'scale\(([-\d.]+),([-\d.]+)\)', svg).groups())
d = re.search(r'<path d="([^"]+)"', svg).group(1)

NUM = re.compile(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')


def tokens(data):
    for token in re.findall(r'[MmLlCcZz]|[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', data):
        yield token


def parse(data):
    """potrace emits M/m, l/L, c/C and z only -> list of closed contours."""
    it = list(tokens(data))
    i = 0
    cmd = None
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    contours = []
    contour = []

    def num():
        nonlocal i
        v = float(it[i])
        i += 1
        return v

    while i < len(it):
        if re.match(r'[A-Za-z]', it[i]):
            cmd = it[i]
            i += 1
            if cmd in "Zz":
                if contour:
                    contours.append(contour)
                    contour = []
                cur = start
                continue
        rel = cmd.islower()
        if cmd in "Mm":
            x, y = num(), num()
            if rel:
                x, y = cur[0] + x, cur[1] + y
            if contour:
                contours.append(contour)
            contour = []
            cur = start = (x, y)
            contour.append(("move", (x, y)))
        elif cmd in "Ll":
            x, y = num(), num()
            if rel:
                x, y = cur[0] + x, cur[1] + y
            contour.append(("line", (x, y)))
            cur = (x, y)
        elif cmd in "Cc":
            x1, y1, x2, y2, x, y = (num() for _ in range(6))
            if rel:
                x1, y1 = cur[0] + x1, cur[1] + y1
                x2, y2 = cur[0] + x2, cur[1] + y2
                x, y = cur[0] + x, cur[1] + y
            contour.append(("curve", (x1, y1), (x2, y2), (x, y)))
            cur = (x, y)
        else:
            raise SystemExit(f"unsupported path command {cmd!r}")
    if contour:
        contours.append(contour)
    return contours


contours = parse(d)


def place(p):
    return (p[0] * sx + tx, p[1] * sy + ty)


contours = [[(seg[0], *[place(p) for p in seg[1:]]) for seg in c] for c in contours]

# --- fit into the em square ----------------------------------------------
font = TTFont(TTF)
upem = font["head"].unitsPerEm
old_name = font.getBestCmap()[CODEPOINT]
old_glyph = font["glyf"][old_name]
target_h = old_glyph.yMax - old_glyph.yMin      # match the glyph it replaces
target_y = old_glyph.yMin
side_bearing = old_glyph.xMin
advance_pad = font["hmtx"][old_name][0] - (old_glyph.xMax - old_glyph.xMin)

xs = [p[0] for c in contours for seg in c for p in seg[1:]]
ys = [p[1] for c in contours for seg in c for p in seg[1:]]
scale = target_h / (max(ys) - min(ys))
dx = side_bearing - min(xs) * scale
dy = target_y - min(ys) * scale


def fit(p):
    return (p[0] * scale + dx, p[1] * scale + dy)


# --- draw ----------------------------------------------------------------
rec = RecordingPen()
for c in contours:
    first = True
    for seg in c:
        pts = [fit(p) for p in seg[1:]]
        if seg[0] == "move":
            rec.moveTo(pts[0])
            first = False
        elif seg[0] == "line":
            rec.lineTo(pts[0])
        else:
            rec.curveTo(*pts)
    rec.closePath()

pen = TTGlyphPen(None)
rec.replay(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
glyph = pen.glyph()
glyph.recalcBounds(font["glyf"])
width = glyph.xMax - glyph.xMin

# --- swap in, renaming the old brand glyph if it still carries the old name --
order = font.getGlyphOrder()
font["glyf"].glyphs[old_name] = glyph
font["hmtx"].metrics[old_name] = (int(round(width + advance_pad)), int(round(glyph.xMin)))

if old_name != NEW_NAME:
    assert NEW_NAME not in order, f"{NEW_NAME} already exists as another glyph"
    font["glyf"].glyphs[NEW_NAME] = font["glyf"].glyphs.pop(old_name)
    font["hmtx"].metrics[NEW_NAME] = font["hmtx"].metrics.pop(old_name)
    font.setGlyphOrder([NEW_NAME if n == old_name else n for n in order])
for table in font["cmap"].tables:
    for cp, name in list(table.cmap.items()):
        if name == old_name:
            table.cmap[cp] = NEW_NAME
if "post" in font and getattr(font["post"], "glyphOrder", None):
    font["post"].glyphOrder = [NEW_NAME if n == old_name else n for n in font["post"].glyphOrder]

font.save(TTF)
print(f"replaced {old_name!r} -> {NEW_NAME!r}: {glyph.numberOfContours} contours, "
      f"bbox=({glyph.xMin},{glyph.yMin})-({glyph.xMax},{glyph.yMax}), "
      f"advance={font['hmtx'][NEW_NAME][0]}")
