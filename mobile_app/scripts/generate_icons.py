#!/usr/bin/env python3
"""
Generate app icons from SVG template
Requires: pip install cairosvg pillow

Run this script from the mobile_app directory:
    cd mobile_app
    python generate_icons.py
"""

import os
import sys
from pathlib import Path

# Ensure we're running from the correct directory
script_dir = Path(__file__).parent.absolute()
os.chdir(script_dir)

try:
    import cairosvg
except ImportError:
    print("ERROR: cairosvg not installed.")
    print("Install it with: pip install cairosvg pillow")
    sys.exit(1)

# Path to SVG template
svg_path = Path("assets/images/app_icon_template.svg")

if not svg_path.exists():
    print(f"ERROR: SVG template not found at {svg_path}")
    sys.exit(1)

print("Generating app icons from SVG template...")
print()

# Android icon sizes
android_icons = {
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

# Web icon sizes
web_icons = {
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
    "web/favicon.png": 32,
}

def generate_icon(output_path, size):
    """Generate PNG icon from SVG"""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        cairosvg.svg2png(
            url=str(svg_path),
            write_to=str(output_path),
            output_width=size,
            output_height=size
        )
        print(f"  ✓ Generated: {output_path} ({size}x{size})")
        return True
    except Exception as e:
        print(f"  ✗ Failed: {output_path} - {e}")
        return False

# Generate Android icons
print("Generating Android icons...")
android_success = 0
for icon_path, size in android_icons.items():
    if generate_icon(icon_path, size):
        android_success += 1

print()

# Generate Web icons
print("Generating Web icons...")
web_success = 0
for icon_path, size in web_icons.items():
    if generate_icon(icon_path, size):
        web_success += 1

print()
total_icons = len(android_icons) + len(web_icons)
total_success = android_success + web_success

if total_success == total_icons:
    print(f"✓ All {total_success} icons generated successfully!")
    print()
    print("Next steps:")
    print("  1. Rebuild the app: flutter clean && flutter build apk")
    print("  2. Check that icons appear correctly on the device")
else:
    print(f"⚠ Generated {total_success}/{total_icons} icons")
    print("Some icons failed to generate. Check errors above.")

