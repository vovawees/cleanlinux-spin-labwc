#!/usr/bin/env python3
"""wallpaper.py: the wallpaper of the labwc spin, drawn on the build machine (no image libraries).

    wallpaper.py OUT.png [WIDTH HEIGHT]

A night-blue diagonal gradient with a soft light at the lower right and the CleanLinux mark (the C
with a dot of the start icon) as a faint watermark; an ordered dither keeps the gradient free of bands.
SPDX-License-Identifier: MIT
"""
import math
import struct
import sys
import zlib

TOP = (11, 18, 32)        # the upper left corner
BOTTOM = (30, 58, 138)    # the lower right corner
GLOW = (37, 99, 235)      # the light at the lower right (the blue of the start icon)
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def png(width, height, rows):
    """an RGB PNG: filter type 0 on every row, one zlib stream"""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b"".join(b"\0" + r for r in rows)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def mark_alpha(x, y, cx, cy, r, w):
    """the coverage (0..1) of the C with a dot at (x, y): a ring of radius r and width w open to the
    right (+-40 degrees, round ends) and a dot in the opening, anti-aliased over one pixel"""
    dx, dy = x - cx, y - cy
    d = math.hypot(dx, dy)
    a = 0.0
    ang = math.degrees(math.atan2(dy, dx))
    if abs(ang) >= 40:
        a = w / 2 - abs(d - r) + 0.5
    else:  # the round ends of the ring at +-40 degrees
        for s in (-1, 1):
            ex, ey = cx + r * math.cos(math.radians(40)), cy + s * r * math.sin(math.radians(40))
            a = max(a, w / 2 - math.hypot(x - ex, y - ey) + 0.5)
    dot = 0.264 * r * 1.0  # the dot of the icon: radius 2.9 for a ring of 11
    a = max(a, dot - math.hypot(x - (cx + 0.964 * r), y - cy) + 0.5)
    return min(max(a, 0.0), 1.0)


def main():
    out = sys.argv[1]
    width, height = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1920, 1080)
    diag = width + height
    gx, gy, gr = width * 0.85, height * 1.05, max(width, height) * 0.75
    cx, cy, r = width * 0.5, height * 0.47, height * 0.16
    w = r * 5 / 11  # the stroke of the icon: 5 for a ring of 11
    box = (cx - r - w, cx + 1.3 * r + w, cy - r - w, cy + r + w)
    rows = []
    for y in range(height):
        row = bytearray(width * 3)
        bay = BAYER[y & 3]
        in_y = box[2] <= y <= box[3]
        for x in range(width):
            t = (x + y) / diag
            g = max(0.0, 1.0 - math.hypot(x - gx, y - gy) / gr) ** 2 * 0.55
            m = mark_alpha(x + 0.5, y + 0.5, cx, cy, r, w) * 0.07 if in_y and box[0] <= x <= box[1] else 0.0
            dither = bay[x & 3] / 16.0
            for c in range(3):
                v = TOP[c] + (BOTTOM[c] - TOP[c]) * t
                v += (GLOW[c] - v) * g
                v += (255 - v) * m
                row[x * 3 + c] = min(255, int(v + dither))
        rows.append(bytes(row))
    with open(out, "wb") as f:
        f.write(png(width, height, rows))


if __name__ == "__main__":
    main()
