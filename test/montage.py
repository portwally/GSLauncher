# Super Hi-Res dumps (.shr) side by side in one PNG, each 320x200 (every
# other pixel of 640-mode lines). Usage: montage.py out.png columns a.shr ...
import sys, struct, zlib
out, cols, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
def rgb(d):
    img = []
    for y in range(200):
        scb = d[0x7D00 + y]
        pal = d[0x7E00 + (scb & 15) * 32:][:32]
        c = [((pal[i*2+1] & 15) * 17, (pal[i*2] >> 4) * 17, (pal[i*2] & 15) * 17) for i in range(16)]
        row = []
        for x in range(160):
            b = d[y * 160 + x]
            if scb & 0x80:
                row += [c[8 + (b >> 6)], c[0 + ((b >> 2) & 3)]]
            else:
                row += [c[b >> 4], c[b & 15]]
        img.append(row)
    return img
tiles = [rgb(open(f, 'rb').read()) for f in files]
rows_n = (len(tiles) + cols - 1) // cols
W, H = cols * 324, rows_n * 204
canvas = [[(40, 40, 40)] * W for _ in range(H)]
for i, t in enumerate(tiles):
    ox, oy = (i % cols) * 324 + 2, (i // cols) * 204 + 2
    for y in range(200):
        canvas[oy + y][ox:ox + 320] = t[y]
raw = b''.join(b'\0' + bytes(v for p in r for v in p) for r in canvas)
def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
open(out, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
    + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
