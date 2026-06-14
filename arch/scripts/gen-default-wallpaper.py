#!/usr/bin/env python3
"""Gera um wallpaper padrao (gradiente Tokyo Night) sem dependencias externas.

Uso: python3 gen-default-wallpaper.py [saida.png] [largura] [altura]
Padrao: ~/Pictures/Wallpapers/default.png  1920x1080
"""
import os
import sys
import zlib
import struct

# Paleta Tokyo Night: canto superior-esquerdo -> inferior-direito
C0 = (0x16, 0x16, 0x1e)  # base escura
C1 = (0x24, 0x28, 0x3b)  # superficie levemente azulada
ACCENT = (0x7a, 0xa2, 0xf7)  # brilho sutil de destaque


def lerp(a, b, t):
    return int(a + (b - a) * t)


def build_png(width, height):
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filtro 0 (None) por scanline
        for x in range(width):
            t = (x / width + y / height) / 2.0
            r = lerp(C0[0], C1[0], t)
            g = lerp(C0[1], C1[1], t)
            b = lerp(C0[2], C1[2], t)
            # leve halo de destaque no canto superior-esquerdo
            d = ((x / width) ** 2 + (y / height) ** 2) ** 0.5
            halo = max(0.0, 0.12 * (1.0 - d))
            r = min(255, int(r + (ACCENT[0] - r) * halo))
            g = min(255, int(g + (ACCENT[1] - g) * halo))
            b = min(255, int(b + (ACCENT[2] - b) * halo))
            raw += bytes((r, g, b))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    idat = zlib.compress(bytes(raw), 9)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Pictures/Wallpapers/default.png")
    w = int(sys.argv[2]) if len(sys.argv) > 2 else 1920
    h = int(sys.argv[3]) if len(sys.argv) > 3 else 1080
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(build_png(w, h))
    print(f"wallpaper gerado: {out} ({w}x{h})")


if __name__ == "__main__":
    main()
