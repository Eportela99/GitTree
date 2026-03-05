#!/usr/bin/env python3
"""
Process GitTree.png: remove dark outer background, produce transparent PNG icon set.
Requires Pillow: pip3 install Pillow
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    print("Pillow not found. Installing...")
    os.system(f"{sys.executable} -m pip install Pillow --quiet")
    from PIL import Image, ImageDraw, ImageFilter

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
SOURCE_PNG = PROJECT_DIR / "GitTree.png"
APPICONSET = PROJECT_DIR / "GitTree" / "Assets.xcassets" / "AppIcon.appiconset"

ICON_SIZES = [16, 32, 64, 128, 256, 512, 1024]

def remove_outer_background(img: Image.Image) -> Image.Image:
    """
    Remove the dark outer background — sample the corner pixel as the background color,
    then make all similar pixels transparent.
    """
    img = img.convert("RGBA")
    w, h = img.size
    corner_r, corner_g, corner_b, _ = img.getpixel((4, 4))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if abs(r - corner_r) < 30 and abs(g - corner_g) < 30 and abs(b - corner_b) < 30:
                out.putpixel((x, y), (0, 0, 0, 0))
            else:
                out.putpixel((x, y), (r, g, b, 255))
    return out

def crop_to_icon(img: Image.Image) -> Image.Image:
    """
    Find the tightest bounding box of non-transparent content by scanning
    from each edge at the image midpoint (more robust than getbbox for noisy images).
    """
    w, h = img.size
    mid_y = h // 2
    mid_x = w // 2

    # Find left/right edges at mid_y
    left = 0
    for x in range(w):
        if img.getpixel((x, mid_y))[3] > 0:
            left = max(0, x - 5)
            break

    right = w
    for x in range(w - 1, 0, -1):
        if img.getpixel((x, mid_y))[3] > 0:
            right = min(w, x + 5)
            break

    # Find top/bottom edges at mid_x of icon area
    cx = (left + right) // 2
    top = 0
    for y in range(h):
        if img.getpixel((cx, y))[3] > 0:
            top = max(0, y - 5)
            break

    bottom = h
    for y in range(h - 1, 0, -1):
        if img.getpixel((cx, y))[3] > 0:
            bottom = min(h, y + 5)
            break

    cropped = img.crop((left, top, right, bottom))

    # Make square
    cw, ch = cropped.size
    size = max(cw, ch)
    square = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    square.paste(cropped, ((size - cw) // 2, (size - ch) // 2))
    return square

def main():
    if not SOURCE_PNG.exists():
        print(f"ERROR: Source image not found: {SOURCE_PNG}")
        sys.exit(1)

    print(f"Processing: {SOURCE_PNG}")
    img = Image.open(SOURCE_PNG)
    print(f"  Original size: {img.size}, mode: {img.mode}")

    print("  Removing outer background...")
    processed = remove_outer_background(img)

    print("  Cropping to icon content...")
    squared = crop_to_icon(processed)
    print(f"  Final icon size: {squared.size}")

    APPICONSET.mkdir(parents=True, exist_ok=True)

    # Save master
    master_path = APPICONSET / "AppIcon_master.png"
    squared.save(master_path, "PNG")
    print(f"  Saved master: {master_path}")

    # Generate all sizes
    for size in ICON_SIZES:
        resized = squared.resize((size, size), Image.LANCZOS)
        filename = APPICONSET / f"AppIcon_{size}.png"
        resized.save(filename, "PNG")
        print(f"  Generated: AppIcon_{size}.png ({size}x{size})")

    print("\nIcon set generated successfully!")
    print(f"Location: {APPICONSET}")

if __name__ == "__main__":
    main()
