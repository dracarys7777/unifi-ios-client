"""Create a deterministic opaque app icon using only the Python standard library."""
import json
import struct
import zlib
from pathlib import Path

size = 1024
pixels = bytearray()
for y in range(size):
    pixels.append(0)
    for x in range(size):
        # White U on indigo, with generous safe area.
        side = (270 <= x <= 370 or 654 <= x <= 754) and 260 <= y <= 580
        ring = y >= 580 and 142**2 <= (x-512)**2 + (y-580)**2 <= 242**2
        pixels.extend((248, 249, 255) if side or ring else (64, 55, 180))
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data) & 0xffffffff)
image = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')
root = Path('App/Assets.xcassets')
folder = root/'AppIcon.appiconset'
folder.mkdir(parents=True, exist_ok=True)
(root/'Contents.json').write_text(json.dumps({'info':{'author':'unifi','version':1}}))
(folder/'AppIcon.png').write_bytes(image)
(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}], 'info':{'author':'unifi','version':1}}))
