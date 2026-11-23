#!/usr/bin/env python3
"""Gera o wallpaper "Terminal Refinado" (preto + prompt discreto com cursor ambar).
Uso: python3 arch/scripts/gen-brugge-wallpaper.py [saida.png] [LARGURAxALTURA]"""
import subprocess, sys
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1] if len(sys.argv) > 1 else "brugge-terminal.png"
W, H = map(int, (sys.argv[2] if len(sys.argv) > 2 else "2560x1440").split("x"))
font = subprocess.check_output(["fc-match", "-f", "%{file}", "JetBrainsMono Nerd Font:style=Regular"]).decode()
img = Image.new("RGB", (W, H), "#0b0b0c")
d = ImageDraw.Draw(img)
# grade de pontos muito sutil
for y in range(0, H, 48):
    for x in range(0, W, 48):
        d.point((x, y), fill="#16161a")
f = ImageFont.truetype(font, H // 18)
x, y = W // 12, int(H * 0.78)
for txt, col in (("$ ", "#55555a"), ("brugge", "#e7e7e6"), ("OnGrails", "#d6a84a")):
    d.text((x, y), txt, font=f, fill=col)
    x += d.textlength(txt, font=f)
d.rectangle((x + 8, y + H // 90, x + 8 + H // 40, y + H // 18 + H // 90), fill="#d6a84a")  # cursor
img.save(out)
print("ok:", out)
