#!/usr/bin/env python3
"""icons.py: the CleanLinux icon theme from Adwaita, drawn without librsvg.

    icons.py ADWAITA_DIR SVG2RGBA LOGO.svg OUT_DIR [JOBS]

GTK 3 recolours a symbolic SVG icon through librsvg (CSS and XInclude); without librsvg it takes
NAME.symbolic.png: black pixels with the icon's alpha become the text colour of the theme. So every
symbolic icon of Adwaita (but the right-to-left ones and the emotes) becomes such PNGs at the sizes
below, drawn by svg2rgba (NanoSVG); the full-colour PNGs of Adwaita (16x16) and the start icon of
the panel come along. PNGs are written here with zlib: the build machine needs no libpng.
"""
import concurrent.futures
import os
import shutil
import struct
import subprocess
import sys
import zlib

SIZES = (16, 24, 32, 48)
CONTEXTS = {  # Adwaita's directory: the Context of index.theme
    "actions": "Actions",
    "apps": "Applications",
    "categories": "Categories",
    "devices": "Devices",
    "emblems": "Emblems",
    "legacy": "Legacy",
    "mimetypes": "MimeTypes",
    "places": "Places",
    "status": "Status",
    "ui": "UI",
}
LOGO = "cleanlinux-start"


def png(size, rgba):
    """an RGBA PNG of size x size pixels: one zlib stream, no filters, no metadata"""
    stride = size * 4
    raw = b"".join(b"\0" + rgba[y * stride:(y + 1) * stride] for y in range(size))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def draw(svg2rgba, svg, color):
    """the RGBA pixels of svg at every size of SIZES"""
    out = subprocess.run([svg2rgba, svg, color] + [str(s) for s in SIZES], check=True, stdout=subprocess.PIPE).stdout
    images, at = [], 0
    for s in SIZES:
        images.append(out[at:at + s * s * 4])
        at += s * s * 4
    if at != len(out):
        sys.exit(f"icons.py: {svg}: svg2rgba wrote {len(out)} bytes, not {at}")
    return images


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def main():
    if len(sys.argv) not in (5, 6):
        sys.exit("usage: icons.py ADWAITA_DIR SVG2RGBA LOGO.svg OUT_DIR [JOBS]")
    adwaita, svg2rgba, logo, out = sys.argv[1:5]
    jobs = int(sys.argv[5]) if len(sys.argv) == 6 else os.cpu_count() or 1
    work = []  # (svg, colour, name, context)
    for ctx in sorted(CONTEXTS):
        d = os.path.join(adwaita, "symbolic", ctx)
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if f.endswith("-symbolic.svg") and "-rtl" not in f:
                work.append((os.path.join(d, f), "000000", f[:-4] + ".symbolic", ctx))
    work.append((logo, "-", LOGO, "apps"))
    dirs = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        for (svg, color, name, ctx), images in zip(work, pool.map(lambda w: draw(svg2rgba, w[0], w[1]), work)):
            for s, rgba in zip(SIZES, images):
                write(os.path.join(out, f"{s}x{s}", ctx, name + ".png"), png(s, rgba))
                dirs.add((s, ctx))
    # the full-colour icons of Adwaita that are PNGs already (folders, file types, disks)
    full = os.path.join(adwaita, "16x16")
    for ctx in sorted(os.listdir(full)) if os.path.isdir(full) else []:
        if ctx in CONTEXTS:
            for f in sorted(os.listdir(os.path.join(full, ctx))):
                if f.endswith(".png"):
                    os.makedirs(os.path.join(out, "16x16", ctx), exist_ok=True)
                    shutil.copyfile(os.path.join(full, ctx, f), os.path.join(out, "16x16", ctx, f))
                    dirs.add((16, ctx))
    write(os.path.join(out, "scalable", "apps", LOGO + ".svg"), open(logo, "rb").read())
    names = [f"{s}x{s}/{c}" for s, c in sorted(dirs)] + ["scalable/apps"]
    theme = ["[Icon Theme]", "Name=CleanLinux",
             "Comment=The symbolic icons of Adwaita for GTK without librsvg, the start icon of CleanLinux",
             "Inherits=hicolor", "Example=folder", "Directories=" + ",".join(names), ""]
    for s, c in sorted(dirs):
        theme += [f"[{s}x{s}/{c}]", f"Size={s}", f"Context={CONTEXTS[c]}", "Type=Fixed", ""]
    theme += ["[scalable/apps]", "Size=48", "MinSize=8", "MaxSize=512", "Context=Applications", "Type=Scalable", ""]
    write(os.path.join(out, "index.theme"), "\n".join(theme).encode())
    print(f"icons.py: {len(work)} icons at {len(SIZES)} sizes, {len(names)} directories")


if __name__ == "__main__":
    main()
