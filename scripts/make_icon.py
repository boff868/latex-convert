#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 App 图标：1024x1024 源图 + 全尺寸 .icns

依赖: pip install pillow

用法:
    python3 scripts/make_icon.py            # 输出到 <repo>/icon/
    python3 scripts/make_icon.py 输出目录
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "icon")
os.makedirs(OUT, exist_ok=True)

S = 1024
CONTENT = int(S * 0.82)          # 圆角方块内容区
PAD = (S - CONTENT) // 2
R = int(CONTENT * 0.225)         # 圆角半径

# ---------------- 竖向渐变底 ----------------
top = (124, 77, 255)    # #7C4DFF
bot = (41, 98, 255)     # #2962FF
grad = Image.new("RGB", (1, CONTENT))
for y in range(CONTENT):
    t = y / (CONTENT - 1)
    grad.putpixel((0, y), (
        int(top[0] + (bot[0] - top[0]) * t),
        int(top[1] + (bot[1] - top[1]) * t),
        int(top[2] + (bot[2] - top[2]) * t),
    ))
grad = grad.resize((CONTENT, CONTENT))

# ---------------- 圆角遮罩 ----------------
mask = Image.new("L", (CONTENT, CONTENT), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, CONTENT, CONTENT], radius=R, fill=255)

block = Image.new("RGBA", (CONTENT, CONTENT), (0, 0, 0, 0))
block.paste(grad, (0, 0), mask)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
img.paste(block, (PAD, PAD), block)

# ---------------- 文字 "TeX" ----------------
font = None
for p in ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
          "/System/Library/Fonts/Supplemental/Arial.ttf",
          "/System/Library/Fonts/Helvetica.ttc"]:
    if os.path.exists(p):
        try:
            font = ImageFont.truetype(p, int(CONTENT * 0.40))
            break
        except Exception:
            pass

d = ImageDraw.Draw(img)
if font is not None:
    bb = d.textbbox((0, 0), "TeX", font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text((S / 2 - tw / 2 - bb[0],
            S / 2 - th / 2 - bb[1] + int(CONTENT * 0.02)),
           "TeX", font=font, fill=(255, 255, 255, 255))

    # 底部小字 "→ PDF / Word"
    try:
        f2 = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                                int(CONTENT * 0.13))
    except Exception:
        f2 = font
    a = "→ PDF / Word"
    bb = d.textbbox((0, 0), a, font=f2)
    d.text((S / 2 - (bb[2] - bb[0]) / 2 - bb[0], PAD + CONTENT * 0.72),
           a, font=f2, fill=(255, 255, 255, 235))

img.save(os.path.join(OUT, "icon_512x512@2x.png"))

# ---------------- 生成 iconset 并打包 icns ----------------
specs = [(16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
         (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
         (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
         (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
         (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")]
iset = os.path.join(OUT, "AppIcon.iconset")
os.makedirs(iset, exist_ok=True)
for px, name in specs:
    img.resize((px, px), Image.LANCZOS).save(os.path.join(iset, name))

icns = os.path.join(OUT, "AppIcon.icns")
if sys.platform == "darwin":
    subprocess.run(["iconutil", "-c", "icns", iset, "-o", icns], check=True)
    print("iconset ready:", iset)
    print("icns ready:   ", icns)
else:
    print("iconset ready:", iset)
    print("（非 macOS，已跳过 iconutil 打包 .icns）")
