#!/usr/bin/env python3
"""Draw resources/icon.png (256x219, what the launcher's Apps set shows) from Shadow Warrior's own title screen:

    tools/make_icon.py build_data/sw-shareware-1.2.zip

Nothing of unknown origin: the picture is the one the game opens with, TITLE_PIC (tile 2324, game.c), read out
of the shareware sw.grp the way the Build engine reads it - the GRP's "KenSilverman" directory, the TILESnnn.ART
file holding the tile (column-major 8-bit pixels), PALETTE.DAT's first 768 bytes (6-bit VGA colours).
Needs Pillow.
"""
import io
import os
import struct
import sys
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
W, H = 256, 219
TITLE_PIC = 2324


def grp_files(data):
    assert data[:12] == b"KenSilverman", "not a GRP"
    (count,) = struct.unpack_from("<i", data, 12)
    files, offset = {}, 16 + 16 * count
    for i in range(count):
        name = data[16 + 16 * i:16 + 16 * i + 12].rstrip(b"\0").decode("ascii").upper()
        (size,) = struct.unpack_from("<i", data, 16 + 16 * i + 12)
        files[name] = data[offset:offset + size]
        offset += size
    return files


def tile(files, number):
    for name, art in sorted(files.items()):
        if not (name.startswith("TILES") and name.endswith(".ART")):
            continue
        _, _, first, last = struct.unpack_from("<iiii", art, 0)
        if not first <= number <= last:
            continue
        n = last - first + 1
        widths = struct.unpack_from("<%dh" % n, art, 16)
        heights = struct.unpack_from("<%dh" % n, art, 16 + 2 * n)
        pos = 16 + 8 * n  # after the widths, heights and picanm tables
        for i in range(n):
            if first + i == number:
                return widths[i], heights[i], art[pos:pos + widths[i] * heights[i]]
            pos += widths[i] * heights[i]
    raise SystemExit("tile %d not found" % number)


def main(argv):
    archive = argv[1] if len(argv) > 1 else os.path.join(ROOT, "build_data", "sw-shareware-1.2.zip")
    with zipfile.ZipFile(archive) as z:
        files = grp_files(z.read("sw.grp"))
    raw = files["PALETTE.DAT"][:768]
    palette = [(raw[i] * 255 // 63, raw[i + 1] * 255 // 63, raw[i + 2] * 255 // 63) for i in range(0, 768, 3)]
    width, height, pixels = tile(files, TITLE_PIC)
    image = Image.new("RGB", (width, height))
    # Build stores a tile column by column
    image.putdata([palette[pixels[x * height + y]] for y in range(height) for x in range(width)])
    # a 320x200 picture on a 4:3 screen: stretch to its displayed shape, then fit the icon's width - the words
    # "SHADOW" and "WARRIOR" run to the picture's edges, so it is not cropped; the few lines left over take
    # the picture's own background colour (its top-left pixel)
    image = image.resize((width, height * 6 // 5), Image.LANCZOS)
    image = image.resize((W, round(image.height * W / image.width)), Image.LANCZOS)
    icon = Image.new("RGB", (W, H), image.getpixel((0, 0)))
    icon.paste(image, (0, (H - image.height) // 2))
    icon = icon.convert("RGBA")
    out = os.path.join(ROOT, "resources", "icon.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    icon.save(out)
    print(out, "from a %dx%d title" % (width, height))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
