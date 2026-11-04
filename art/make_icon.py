# Makes GSLauncher's Finder icon (a window with three app tiles in a row) and
# the generic icon the launcher shows for an app with no Finder icon.
#   python3 art/make_icon.py build/GSL.Icons build/icon-preview.png src/genicon.s
# The icon format and colour pairs are those of GS Commander's art/make_icon.py:
# an icon pixel is two screen pixels of 640 mode, the first from black, red,
# green, white and the second from black, blue, yellow, white.
import struct, sys, zlib

PAIRS = {
    "K": (0, 0), "W": (3, 3),   # black, white
    "N": (0, 1),                # navy (black, blue)
    "B": (3, 1),                # light blue (white, blue)
    "Y": (3, 2),                # gold (white, yellow)
    "R": (1, 0),                # dark red
    "G": (2, 2),                # green (green, yellow)
}
LEFT = [(0, 0, 0), (221, 0, 0), (0, 238, 0), (255, 255, 255)]
RIGHT = [(0, 0, 0), (0, 0, 255), (255, 255, 0), (255, 255, 255)]

# the launcher: a window, its title bar navy, three tiles in a row
LAUNCHER = (
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    "KNNNNNNNNNNNNNNNNNNNNNNNNNNK",
    "KNYYNNNNNNNNNNNNNNNNNNNNNNNK",
    "KNNNNNNNNNNNNNNNNNNNNNNNNNNK",
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWKKKKKKWWKKKKKKWWKKKKKKWWWK",
    "KWKYYYYKWWKBBBBKWWKGGGGKWWWK",
    "KWKYYYYKWWKBBBBKWWKGGGGKWWWK",
    "KWKYYYYKWWKBBBBKWWKGGGGKWWWK",
    "KWKKKKKKWWKKKKKKWWKKKKKKWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWKKKKKKWWKKKKKKWWKKKKKKWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    "............................")
LAUNCHER_SMALL = (
    "KKKKKKKK",
    "KNNNNNNK",
    "KKKKKKKK",
    "KYWBWGWK",
    "KWWWWWWK",
    "KKKKKKKK",
    "........",
    "........")
# any application: a window with a diamond in it
GENERIC = (
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    "KNNNNNNNNNNNNNNNNNNNNNNNNNNK",
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWKKWWWWWWWWWWWWK",
    "KWWWWWWWWWWWKBBKWWWWWWWWWWWK",
    "KWWWWWWWWWWKBBBBKWWWWWWWWWWK",
    "KWWWWWWWWWKBBBBBBKWWWWWWWWWK",
    "KWWWWWWWWWWKBBBBKWWWWWWWWWWK",
    "KWWWWWWWWWWWKBBKWWWWWWWWWWWK",
    "KWWWWWWWWWWWWKKWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    "............................",
    "............................")

def record(grid):
    """A QuickDraw II colour icon: type, size, height, width, image, mask."""
    h, w = len(grid), len(grid[0])
    rb = (w + 1) // 2
    image, mask = bytearray(rb * h), bytearray(rb * h)
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == ".": continue
            l, r = PAIRS[ch]
            sh = 4 if x % 2 == 0 else 0
            image[y * rb + x // 2] |= (l << 2 | r) << sh
            mask[y * rb + x // 2] |= 15 << sh
    return struct.pack("<HHHH", 0x8000, len(image), h, w) + bytes(image) + bytes(mask)

def pascal(text, field):
    b = text.encode("ascii")[:field - 1]
    return bytes([len(b)]) + b + bytes(field - 1 - len(b))

def icon_file(big, little):
    body = pascal("", 64) + pascal("GSLauncher", 16) + struct.pack("<HH", 0xB3, 0) + record(big) + record(little)
    out = bytearray(26); out[4] = 1
    return bytes(out) + struct.pack("<H", len(body) + 2) + body + b"\0\0"

def asm(grid):
    rec = record(grid)
    lines = ["* The icon GSLauncher shows for an app with no Finder icon",
             "* (made by art/make_icon.py: do not edit)", "GenIcon"]
    for i in range(0, len(rec), 16):
        lines.append("            hex   " + rec[i:i + 16].hex().upper())
    return "\n".join(lines) + "\n"

def preview(grids, path, scale=4):
    desk = (102, 119, 255)
    cw, ch = scale, scale * 2
    pad = 6 * scale
    widths = [len(gr[0]) * 2 * cw for gr in grids]
    W = sum(widths) + pad * (len(grids) + 1)
    H = max(len(gr) for gr in grids) * ch + pad * 2
    img = [[desk] * W for _ in range(H)]
    x0 = pad
    for gr, gw in zip(grids, widths):
        y0 = pad + (H - 2 * pad - len(gr) * ch) // 2
        for y, row in enumerate(gr):
            for x, c in enumerate(row):
                if c == ".": continue
                l, r = PAIRS[c]
                for half, col in ((0, LEFT[l]), (1, RIGHT[r])):
                    for yy in range(ch):
                        for xx in range(cw):
                            img[y0 + y * ch + yy][x0 + (x * 2 + half) * cw + xx] = col
        x0 += gw + pad
    raw = b"".join(b"\0" + bytes(v for px in row for v in px) for row in img)
    def chunk(t, b): return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b))
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))

if __name__ == "__main__":
    open(sys.argv[1], "wb").write(icon_file(LAUNCHER, LAUNCHER_SMALL))
    preview([LAUNCHER, LAUNCHER_SMALL, GENERIC], sys.argv[2])
    if len(sys.argv) > 3:
        open(sys.argv[3], "w").write(asm(GENERIC))
