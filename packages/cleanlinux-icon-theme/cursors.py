#!/usr/bin/env python3
"""cursors.py: the X cursors of Adwaita at fewer sizes, for the CleanLinux icon theme.

    cursors.py ADWAITA_CURSORS OUT_DIR

Adwaita draws every cursor at 24, 30, 36, 48, 72 and 96 px (12 MB; the two animated ones have 60
frames). This keeps 24, 36 and 48 px (the usual size, 1.5x and 2x scaling) and the animated ones at
24 and 48 with every second frame, shown twice as long: ~1.3 MB. The X11 names become symlinks to
the CSS names, as Adwaita's meson.build makes them; the Windows cursors (.cur, .ani) stay out.
"""
import os
import struct
import sys

IMAGE = 0xFFFD0002
KEEP, KEEP_ANIMATED = (24, 36, 48), (24, 48)
SYMLINKS = {  # the CSS name: its X11 names (meson.build of adwaita-icon-theme 51)
    "all-resize": ["fleur"],
    "crosshair": ["cross", "cross_reverse", "diamond_cross", "tcross"],
    "context-menu": ["dnd-ask"],
    "default": ["arrow", "dnd-move", "left_ptr", "top_left_arrow", "move"],
    "e-resize": ["right_side"],
    "ew-resize": ["sb_h_double_arrow"],
    "grab": ["hand1"],
    "help": ["question_arrow"],
    "n-resize": ["top_side"],
    "ne-resize": ["top_right_corner"],
    "nesw-resize": ["fd_double_arrow"],
    "ns-resize": ["sb_v_double_arrow"],
    "nw-resize": ["top_left_corner"],
    "nwse-resize": ["bd_double_arrow"],
    "pointer": ["hand2"],
    "s-resize": ["bottom_side"],
    "se-resize": ["bottom_right_corner"],
    "sw-resize": ["bottom_left_corner"],
    "text": ["xterm"],
    "w-resize": ["left_side"],
    "wait": ["watch"],
}


def trim(data, name):
    """the Xcursor file data with the images of KEEP (KEEP_ANIMATED) only"""
    magic, hsize, version, ntoc = struct.unpack("<4sIII", data[:16])
    if magic != b"Xcur":
        sys.exit(f"cursors.py: {name}: not an X cursor")
    images = {}  # nominal size: [(version, width, height, xhot, yhot, delay, pixels)]
    for i in range(ntoc):
        kind, size, pos = struct.unpack("<III", data[hsize + 12 * i:hsize + 12 * i + 12])
        if kind == IMAGE:
            _, _, _, ver, w, h, xhot, yhot, delay = struct.unpack("<9I", data[pos:pos + 36])
            images.setdefault(size, []).append((ver, w, h, xhot, yhot, delay, data[pos + 36:pos + 36 + w * h * 4]))
    animated = any(len(frames) > 1 for frames in images.values())
    keep = [s for s in (KEEP_ANIMATED if animated else KEEP) if s in images] or sorted(images)
    chunks = []
    for size in keep:
        frames = images[size]
        if animated and len(frames) > 1:
            frames = [f[:5] + (f[5] * 2,) + f[6:] for f in frames[::2]]
        chunks += [(size, f) for f in frames]
    toc, body, start = b"", b"", 16 + 12 * len(chunks)
    for size, (ver, w, h, xhot, yhot, delay, pixels) in chunks:
        toc += struct.pack("<III", IMAGE, size, start + len(body))
        body += struct.pack("<9I", 36, IMAGE, size, ver, w, h, xhot, yhot, delay) + pixels
    return struct.pack("<4sIII", b"Xcur", 16, version, len(chunks)) + toc + body


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: cursors.py ADWAITA_CURSORS OUT_DIR")
    src, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(src)):
        p = os.path.join(src, f)
        if f.endswith((".cur", ".ani")) or os.path.islink(p) or not os.path.isfile(p):
            continue
        with open(p, "rb") as i, open(os.path.join(out, f), "wb") as o:
            o.write(trim(i.read(), f))
        n += 1
    for css, names in sorted(SYMLINKS.items()):
        if not os.path.exists(os.path.join(out, css)):
            sys.exit(f"cursors.py: no cursor {css}")
        for x11 in names:
            if not os.path.lexists(os.path.join(out, x11)):
                os.symlink(css, os.path.join(out, x11))
    print(f"cursors.py: {n} cursors, {sum(len(v) for v in SYMLINKS.values())} X11 names")


if __name__ == "__main__":
    main()
