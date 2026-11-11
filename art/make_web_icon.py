# Makes the 256 x 256 icon for the web page: a monitor with GSLauncher's window on it.
#   python3 art/make_web_icon.py out.png
import struct, sys, zlib
S = 64                                   # drawn on 64 x 64, shown 4 times as big
BG, CASE, EDGE, BEZEL = (40, 40, 140), (216, 207, 189), (176, 166, 148), (28, 26, 24)
DESK, WHITE, NAVY, BLACK = (153, 170, 255), (255, 255, 255), (16, 24, 110), (0, 0, 0)
GOLD, BLUE, GREEN, LED = (238, 196, 60), (60, 120, 230), (94, 189, 62), (94, 189, 62)
g = [[BG] * S for _ in range(S)]
def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c
rect(6, 6, 57, 48, CASE)                 # the monitor
rect(6, 46, 57, 48, EDGE)
rect(9, 9, 54, 42, BEZEL)
rect(11, 11, 52, 40, DESK)               # the desktop
rect(14, 14, 49, 37, BLACK)              # the launcher window
rect(15, 15, 48, 36, WHITE)
rect(15, 15, 48, 18, NAVY)               # its title bar
rect(20, 16, 27, 17, GOLD)
for x0, c in ((18, GOLD), (29, BLUE), (40, GREEN)):   # three slots
    rect(x0, 22, x0 + 7, 29, BLACK)
    rect(x0 + 1, 23, x0 + 6, 28, c)
    rect(x0, 32, x0 + 7, 32, BLACK)      # (a name under each)
rect(26, 49, 37, 52, EDGE)               # stand and base
rect(18, 53, 45, 55, EDGE)
rect(50, 44, 52, 45, LED)
rows = []
for y in range(S):
    line = b''.join(bytes(c) * 4 for c in g[y])
    rows += [b'\0' + line] * 4
def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', S * 4, S * 4, 8, 2, 0, 0, 0))
    + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b''))
