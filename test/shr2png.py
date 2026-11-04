# Super Hi-Res screen dumps (32K: pixels, SCBs, palettes) to PNG files,
# 640 pixels wide (320-mode lines doubled), each line twice (640x400).
import sys, struct, zlib
def convert(src, dst):
    d = open(src, 'rb').read()
    rows = []
    for y in range(200):
        scb = d[0x7D00 + y]
        pal = d[0x7E00 + (scb & 15) * 32:][:32]
        cols = [((pal[i*2+1] & 15) * 17, (pal[i*2] >> 4) * 17, (pal[i*2] & 15) * 17) for i in range(16)]
        line = bytearray()
        for x in range(160):
            b = d[y * 160 + x]
            if scb & 0x80:
                for k in range(4):
                    v = (b >> (6 - 2 * k)) & 3
                    line += bytes(cols[[8, 12, 0, 4][k] + v])
            else:
                for v in (b >> 4, b & 15):
                    line += bytes(cols[v]) * 2
        rows += [b'\0' + bytes(line)] * 2
    def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 640, 400, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    open(dst, 'wb').write(png)
for f in sys.argv[1:]:
    convert(f, f[:-4] + '.png')
