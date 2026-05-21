#!/usr/bin/env python3
"""从 logo.svg 生成所有平台所需的图标 PNG 文件。"""

import subprocess
import os
import sys

SVG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "logo.svg")
OUTPUT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RSVG_CONVERT = "/opt/homebrew/bin/rsvg-convert"


def generate_png(svg_path, output_path, size):
    """使用 rsvg-convert 生成指定尺寸的 PNG。"""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    result = subprocess.run(
        [RSVG_CONVERT, "-w", str(size), "-h", str(size), "-o", output_path, svg_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"  ❌ {output_path} ({size}x{size}): {result.stderr.strip()}")
        return False
    # Verify file size
    file_size = os.path.getsize(output_path)
    print(f"  ✅ {os.path.basename(output_path)} ({size}x{size}, {file_size} bytes)")
    return True


# ===== Android mipmap =====
print("\n📱 Android icons...")
android_sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
all_ok = True
for folder, size in android_sizes.items():
    out = os.path.join(OUTPUT_DIR, "android", "app", "src", "main", "res", folder, "ic_launcher.png")
    if not generate_png(SVG_PATH, out, size):
        all_ok = False

# ===== iOS App Icon =====
print("\n🍎 iOS icons...")
ios_icons = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]
ios_dir = os.path.join(OUTPUT_DIR, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
for filename, size in ios_icons:
    out = os.path.join(ios_dir, filename)
    if not generate_png(SVG_PATH, out, size):
        all_ok = False

# ===== macOS App Icon =====
print("\n🖥️ macOS icons...")
macos_icons = [
    ("app_icon_16.png", 16),
    ("app_icon_32.png", 32),
    ("app_icon_64.png", 64),
    ("app_icon_128.png", 128),
    ("app_icon_256.png", 256),
    ("app_icon_512.png", 512),
    ("app_icon_1024.png", 1024),
]
macos_dir = os.path.join(OUTPUT_DIR, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
for filename, size in macos_icons:
    out = os.path.join(macos_dir, filename)
    if not generate_png(SVG_PATH, out, size):
        all_ok = False

# ===== Web Icons =====
print("\n🌐 Web icons...")
web_icons = [
    ("icons/Icon-192.png", 192),
    ("icons/Icon-512.png", 512),
    ("icons/Icon-maskable-192.png", 192),
    ("icons/Icon-maskable-512.png", 512),
    ("favicon.png", 64),
]
web_dir = os.path.join(OUTPUT_DIR, "web")
for rel_path, size in web_icons:
    out = os.path.join(web_dir, rel_path)
    if not generate_png(SVG_PATH, out, size):
        all_ok = False

if all_ok:
    print("\n🎉 All icons generated successfully!")
else:
    print("\n⚠️ Some icons failed to generate.")
    sys.exit(1)
