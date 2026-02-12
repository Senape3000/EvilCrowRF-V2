"""
PlatformIO Pre-Build Script
Excludes HttpsOTAUpdate from the Update library build.

The ESP32 Arduino Update library includes HttpsOTAUpdate.cpp which
requires esp_https_ota.h (available only in ESP-IDF framework, not Arduino).
Since we only use the basic Update class for BLE OTA, we temporarily
disable this file during build by renaming it.
"""

import os
import atexit

Import("env")

framework_dir = env.PioPlatform().get_package_dir(
    "framework-arduinoespressif32"
)
https_ota_src = os.path.join(
    framework_dir, "libraries", "Update", "src", "HttpsOTAUpdate.cpp"
)
https_ota_bak = https_ota_src + ".disabled"

# Handle leftover .disabled file from a previous crashed build (Windows fix)
if os.path.exists(https_ota_bak) and os.path.exists(https_ota_src):
    os.remove(https_ota_bak)
    print("[FILTER] Cleaned up leftover .disabled file from previous build")

# Temporarily disable the problematic file before build
if os.path.exists(https_ota_src):
    os.rename(https_ota_src, https_ota_bak)
    print("[FILTER] Disabled HttpsOTAUpdate.cpp for build")

    # Restore after build finishes (success or failure)
    def restore_https_ota():
        if os.path.exists(https_ota_bak) and not os.path.exists(https_ota_src):
            os.rename(https_ota_bak, https_ota_src)
            print("[FILTER] Restored HttpsOTAUpdate.cpp")

    atexit.register(restore_https_ota)
