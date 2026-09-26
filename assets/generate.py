#!/usr/bin/env python3
"""Regenerate Nexus page images from the source screenshot.

Deterministic rebuild of what was previously done ad-hoc:
  assets/gallery-docking-1920x1080.jpg  (16:9 downscale, gallery slot)
  assets/header-1300x372.jpg            (wide crop + title overlay, banner)

Usage: python3 assets/generate.py   (or: make assets)
Requires: Pillow (pip install Pillow). Typeface is vendored (see FONT).
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src", "docking-procedure.jpg")
GAL = os.path.join(HERE, "gallery-docking-1920x1080.jpg")
HDR = os.path.join(HERE, "header-1300x372.jpg")

# In-game heading typeface, vendored (SIL OFL 1.1):
# https://github.com/NMSCD/No-Mans-Sky-Universal-Font
FONT = os.path.join(HERE, "fonts", "GeosansLight-NMS.ttf")

TITLE = "FASTER SPACESHIP DOCKING ROTATION RELOADED"
SUBTITLE = "INSTANT  \u2022  10x"

# Vertical offset of the header crop band in source pixels
HEADER_BAND_Y = 400


def main():
    img = Image.open(SRC).convert("RGB")
    assert img.size == (2560, 1440), f"unexpected source size {img.size}"

    img.resize((1920, 1080), Image.LANCZOS).save(GAL, quality=92)
    print(f"wrote {GAL}")

    w, h = img.size
    band_h = int(w * 372 / 1300)
    band = img.crop((0, HEADER_BAND_Y, w, HEADER_BAND_Y + band_h))
    band = band.resize((1300, 372), Image.LANCZOS)
    d = ImageDraw.Draw(band, "RGBA")
    # top-weighted gradient: Nexus overlays its own title bottom-left
    for y in range(372):
        a = int(150 * (1 - y / 371) ** 2)
        d.rectangle([0, y, 1300, y + 1], fill=(0, 0, 0, a))
    band = band.convert("RGB")
    d = ImageDraw.Draw(band)
    fb = ImageFont.truetype(FONT, 50)
    fs = ImageFont.truetype(FONT, 30)
    d.text((48, 48), TITLE, font=fb, fill=(255, 255, 255))
    d.text((50, 118), SUBTITLE, font=fs, fill=(255, 200, 120))
    band.save(HDR, quality=92)
    print(f"wrote {HDR}")


if __name__ == "__main__":
    main()
