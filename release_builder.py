#!/usr/bin/env python3
"""
EvilCrow RF V2 — Release Builder with GUI + CLI
=================================================
Creates firmware and/or app release packages with proper naming,
versioning, MD5 hashes, and changelog generation.

Reads current versions from:
  - include/config.h          (firmware version)
  - mobile_app/pubspec.yaml   (app version)

Outputs:
  - releases/firmware/evilcrow-v2-fw-vX.Y.Z.bin + .bin.md5
  - releases/firmware/evilcrow-v2-fw-vX.Y.Z-full.bin (merged OTA-ready)
  - releases/app/EvilCrowRF-vX.Y.Z.apk + .apk.md5
  - releases/changelog.json   (cumulative changelog)

Usage:
  python release_builder.py                  # Launch GUI
  python release_builder.py --cli            # Interactive CLI mode
  python release_builder.py --fw             # Build firmware only (CLI)
  python release_builder.py --apk            # Build APK only (CLI)
  python release_builder.py --fw --apk       # Build both (CLI)
  python release_builder.py --fw --test      # TEST BUILD (adds -TEST suffix, no version bump)
  python release_builder.py --fw --no-bump   # Release without version bump
  python release_builder.py --help           # Show help
"""

import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import threading
from datetime import datetime
from pathlib import Path

# ─── Determine project root (script lives in project root) ───────────
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR  # Script is in the root
CONFIG_H = PROJECT_ROOT / "include" / "config.h"
PUBSPEC_YAML = PROJECT_ROOT / "mobile_app" / "pubspec.yaml"
RELEASES_DIR = PROJECT_ROOT / "releases"
CHANGELOG_FILE = RELEASES_DIR / "changelog.json"
FW_RELEASES_DIR = RELEASES_DIR / "firmware"
APP_RELEASES_DIR = RELEASES_DIR / "app"
PIO_BUILD_DIR = PROJECT_ROOT / ".pio" / "build" / "esp32dev"


# ─── Tool Discovery ─────────────────────────────────────────────────

def get_platformio_core_dir() -> Path:
    """Return PlatformIO core dir if configured, else default to ~/.platformio."""
    env_dir = os.environ.get("PLATFORMIO_CORE_DIR") or os.environ.get("PIO_HOME_DIR")
    if env_dir:
        return Path(env_dir)
    return Path.home() / ".platformio"

def find_platformio_cli() -> str | None:
    """Auto-discover PlatformIO CLI executable.

    Search order:
      1. PATH (pio / platformio)
      2. ~/.platformio/penv/Scripts/pio.exe  (Windows)
      3. ~/.platformio/penv/bin/pio          (Linux/Mac)
      4. Project-local tools/.venv           (build_firmware.bat venv)
    """
    # 1. System PATH
    pio_path = shutil.which("pio") or shutil.which("platformio")
    if pio_path:
        return pio_path

    home = Path.home()
    is_win = platform.system() == "Windows"
    pio_core = get_platformio_core_dir()

    # 2-3. Standard PlatformIO installation
    candidates = []
    if is_win:
        candidates = [
            pio_core / "penv" / "Scripts" / "pio.exe",
            pio_core / "penv" / "Scripts" / "platformio.exe",
            home / ".platformio" / "penv" / "Scripts" / "pio.exe",
            home / ".platformio" / "penv" / "Scripts" / "platformio.exe",
        ]
    else:
        candidates = [
            pio_core / "penv" / "bin" / "pio",
            pio_core / "penv" / "bin" / "platformio",
            home / ".platformio" / "penv" / "bin" / "pio",
            home / ".platformio" / "penv" / "bin" / "platformio",
        ]

    # 4. Project-local venv (created by tools/build_firmware.bat)
    local_venv = PROJECT_ROOT / "tools" / ".venv"
    if is_win:
        candidates.append(local_venv / "Scripts" / "platformio.exe")
    else:
        candidates.append(local_venv / "bin" / "platformio")

    for p in candidates:
        if p.is_file():
            return str(p)

    return None


def find_flutter_cli() -> str | None:
    """Auto-discover Flutter CLI executable."""
    flutter_path = shutil.which("flutter")
    if flutter_path:
        return flutter_path

    env_root = os.environ.get("FLUTTER_HOME") or os.environ.get("FLUTTER_ROOT")
    if env_root:
        env_root_path = Path(env_root)
        if platform.system() == "Windows":
            candidate = env_root_path / "bin" / "flutter.bat"
        else:
            candidate = env_root_path / "bin" / "flutter"
        if candidate.is_file():
            return str(candidate)

    # Common locations
    is_win = platform.system() == "Windows"
    home = Path.home()
    candidates = []
    if is_win:
        candidates = [
            home / "flutter" / "bin" / "flutter.bat",
            Path("C:/flutter/bin/flutter.bat"),
            home / "dev" / "flutter" / "bin" / "flutter.bat",
            home / "AppData" / "Local" / "flutter" / "bin" / "flutter.bat",
        ]
    else:
        candidates = [
            home / "flutter" / "bin" / "flutter",
            Path("/usr/local/flutter/bin/flutter"),
            home / "dev" / "flutter" / "bin" / "flutter",
            home / "snap" / "flutter" / "common" / "flutter" / "bin" / "flutter",
        ]

    for p in candidates:
        if p.is_file():
            return str(p)

    return None


# ─── Version Helpers ─────────────────────────────────────────────────


# ─── Environment Preparation ────────────────────────────────────────

def prepare_environment(log_callback=None) -> bool:
    """Prepare the build environment: install PlatformIO (and optionally Flutter).

    This creates a local Python venv and installs PlatformIO if it is not
    already available.  The function is designed to be fully portable across
    machines – no hardcoded paths.

    Steps:
      1. Check if PlatformIO is already reachable → skip if yes.
      2. Create a Python venv under tools/.venv (like build_firmware.bat).
      3. Install PlatformIO into the venv via pip.
      4. Re-check that ``pio`` is now available.
      5. Report Flutter status (installation left to the user).

    Returns True if PlatformIO is usable after the call.
    """
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    log("=== Prepare Environment ===")
    is_win = platform.system() == "Windows"

    # ── 1. Check existing PlatformIO ──
    pio = find_platformio_cli()
    if pio:
        log(f"PlatformIO already available: {pio}")
    else:
        log("PlatformIO not found — installing into local venv...")

        # Find a Python 3 interpreter
        python_exe = sys.executable  # The Python running this script
        log(f"Using Python: {python_exe}")

        venv_dir = PROJECT_ROOT / "tools" / ".venv"
        pip_exe = (venv_dir / "Scripts" / "pip.exe") if is_win else (venv_dir / "bin" / "pip")
        pio_exe = (venv_dir / "Scripts" / "platformio.exe") if is_win else (venv_dir / "bin" / "platformio")

        # ── 2. Create venv ──
        if not venv_dir.exists():
            log(f"Creating venv: {venv_dir}")
            try:
                result = subprocess.run(
                    [python_exe, "-m", "venv", str(venv_dir)],
                    capture_output=True, text=True, timeout=60,
                )
                if result.returncode != 0:
                    log(f"ERROR: Failed to create venv:\n{result.stderr}")
                    return False
            except Exception as e:
                log(f"ERROR: venv creation failed: {e}")
                return False
        else:
            log(f"Venv exists: {venv_dir}")

        # ── 3. Install PlatformIO ──
        if not pio_exe.exists():
            log("Installing PlatformIO via pip (this may take a few minutes)...")
            try:
                result = subprocess.run(
                    [str(pip_exe), "install", "--upgrade", "platformio"],
                    capture_output=True, text=True, timeout=300,
                )
                if result.returncode != 0:
                    log(f"ERROR: pip install platformio failed:\n{result.stderr}")
                    return False
                log("PlatformIO installed successfully!")
            except subprocess.TimeoutExpired:
                log("ERROR: PlatformIO installation timed out (300s)")
                return False
            except Exception as e:
                log(f"ERROR: PlatformIO installation failed: {e}")
                return False
        else:
            log(f"PlatformIO already in venv: {pio_exe}")

        # ── 4. Verify ──
        pio = find_platformio_cli()
        if pio:
            log(f"PlatformIO ready: {pio}")
        else:
            log("ERROR: PlatformIO still not found after installation.")
            return False

    # ── 5. Flutter status ──
    flutter = find_flutter_cli()
    if flutter:
        log(f"Flutter available: {flutter}")
    else:
        log("Flutter NOT found — APK builds will not work.")
        log("  Install Flutter: https://flutter.dev/docs/get-started/install")
        log("  Then add it to PATH or set FLUTTER_HOME env variable.")

    log("")
    log("Environment ready!")
    log(f"  PlatformIO: {find_platformio_cli()}")
    log(f"  Flutter:    {find_flutter_cli() or 'not installed'}")
    return True


def read_firmware_version() -> str:
    """Read FIRMWARE_VERSION_STRING from include/config.h"""
    if not CONFIG_H.exists():
        return "0.0.0"
    content = CONFIG_H.read_text(encoding="utf-8")
    match = re.search(r'#define\s+FIRMWARE_VERSION_STRING\s+"([^"]+)"', content)
    return match.group(1) if match else "0.0.0"


def read_app_version() -> str:
    """Read version from mobile_app/pubspec.yaml"""
    if not PUBSPEC_YAML.exists():
        return "0.0.0"
    content = PUBSPEC_YAML.read_text(encoding="utf-8")
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)', content, re.MULTILINE)
    return match.group(1) if match else "0.0.0"


def bump_version(version: str, bump_type: str) -> str:
    """Bump a semantic version string.
    bump_type: 'major', 'minor', or 'patch'
    """
    parts = [int(x) for x in version.split(".")]
    while len(parts) < 3:
        parts.append(0)
    if bump_type == "major":
        parts[0] += 1
        parts[1] = 0
        parts[2] = 0
    elif bump_type == "minor":
        parts[1] += 1
        parts[2] = 0
    elif bump_type == "patch":
        parts[2] += 1
    return f"{parts[0]}.{parts[1]}.{parts[2]}"


def write_firmware_version(new_version: str):
    """Update FIRMWARE_VERSION_* defines in config.h"""
    parts = new_version.split(".")
    major, minor, patch = parts[0], parts[1], parts[2]
    content = CONFIG_H.read_text(encoding="utf-8")
    content = re.sub(
        r'#define\s+FIRMWARE_VERSION_MAJOR\s+\d+',
        f'#define FIRMWARE_VERSION_MAJOR {major}', content)
    content = re.sub(
        r'#define\s+FIRMWARE_VERSION_MINOR\s+\d+',
        f'#define FIRMWARE_VERSION_MINOR {minor}', content)
    content = re.sub(
        r'#define\s+FIRMWARE_VERSION_PATCH\s+\d+',
        f'#define FIRMWARE_VERSION_PATCH {patch}', content)
    content = re.sub(
        r'#define\s+FIRMWARE_VERSION_STRING\s+"[^"]+"',
        f'#define FIRMWARE_VERSION_STRING "{new_version}"', content)
    CONFIG_H.write_text(content, encoding="utf-8")


def write_app_version(new_version: str):
    """Update version in pubspec.yaml"""
    content = PUBSPEC_YAML.read_text(encoding="utf-8")
    # Keep or increment the build number
    match = re.search(r'^version:\s*\d+\.\d+\.\d+\+(\d+)', content, re.MULTILINE)
    build_num = int(match.group(1)) + 1 if match else 1
    content = re.sub(
        r'^version:\s*\d+\.\d+\.\d+\+?\d*',
        f'version: {new_version}+{build_num}',
        content, flags=re.MULTILINE)
    PUBSPEC_YAML.write_text(content, encoding="utf-8")


# ─── MD5 ─────────────────────────────────────────────────────────────

def compute_md5(file_path: Path) -> str:
    """Compute MD5 hash of a file."""
    h = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


# ─── Changelog ───────────────────────────────────────────────────────

def load_changelog() -> dict:
    """Load existing changelog.json or create empty structure."""
    if CHANGELOG_FILE.exists():
        with open(CHANGELOG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"firmware": [], "app": []}


def save_changelog(data: dict):
    """Save changelog.json."""
    RELEASES_DIR.mkdir(parents=True, exist_ok=True)
    with open(CHANGELOG_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def add_changelog_entry(
    section: str,  # "firmware" or "app"
    version: str,
    changes_text: str,
):
    """Add an entry to the changelog.json."""
    data = load_changelog()

    changes = []
    for line in changes_text.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        type_match = re.match(r'^\[(\w+)\]\s*(.*)', line)
        if type_match:
            change_type = type_match.group(1).lower()
            text = type_match.group(2)
        else:
            change_type = "improvement"
            text = line
        if change_type not in ("feature", "fix", "improvement", "breaking", "security"):
            change_type = "improvement"
        changes.append({"type": change_type, "text": text})

    entry = {
        "version": version,
        "date": datetime.now().strftime("%Y-%m-%d"),
        "tag": f"{'fw' if section == 'firmware' else 'app'}-v{version}",
        "changes": changes,
    }

    data.setdefault(section, []).insert(0, entry)
    save_changelog(data)


# ─── Build Commands ──────────────────────────────────────────────────

def build_firmware(log_callback=None) -> Path | None:
    """Build firmware with PlatformIO. Returns path to .bin or None."""
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    pio_cli = find_platformio_cli()
    if not pio_cli:
        log("ERROR: PlatformIO CLI not found!")
        log("  Searched: PATH, ~/.platformio/penv/, tools/.venv/")
        log("  Install: pip install platformio  or  https://platformio.org/install")
        return None

    log(f"Using PlatformIO: {pio_cli}")
    log("Building firmware...")

    try:
        result = subprocess.run(
            [pio_cli, "run", "-e", "esp32dev"],
            cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            log(f"ERROR: Build failed!\n{result.stderr}")
            if result.stdout:
                log(result.stdout[-2000:])  # Last 2000 chars of output
            return None

        log("Build successful!")
        bin_path = PIO_BUILD_DIR / "firmware.bin"
        if bin_path.exists():
            size_kb = bin_path.stat().st_size / 1024
            log(f"  firmware.bin: {size_kb:.1f} KB")
            return bin_path
        log("ERROR: firmware.bin not found after build")
        return None
    except FileNotFoundError:
        log(f"ERROR: Could not execute '{pio_cli}'. File not found.")
        return None
    except subprocess.TimeoutExpired:
        log("ERROR: Build timed out (300s)")
        return None


def create_merged_binary(log_callback=None) -> Path | None:
    """Create a merged/full binary ready for complete flash or OTA web tool.

    Merges bootloader.bin + partitions.bin + boot_app0.bin + firmware.bin
    at their correct flash offsets into a single file.

    This binary can be flashed with:
      esptool.py write_flash 0x0 firmware-full.bin
    """
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    # Expected files from PlatformIO build
    bootloader = PIO_BUILD_DIR / "bootloader.bin"
    partitions = PIO_BUILD_DIR / "partitions.bin"
    firmware   = PIO_BUILD_DIR / "firmware.bin"

    # boot_app0.bin is in the framework packages or build dir
    boot_app0 = None
    pio_core = get_platformio_core_dir()
    pkg_base = pio_core / "packages"
    candidates = [
        PIO_BUILD_DIR / "boot_app0.bin",
        pkg_base / "framework-arduinoespressif32" / "tools" / "partitions" / "boot_app0.bin",
        pkg_base / "framework-arduinoespressif32" / "tools" / "boot_app0.bin",
        pkg_base / "tool-esptoolpy" / "boot_app0.bin",
    ]

    for candidate in candidates:
        if candidate.is_file():
            boot_app0 = candidate
            break

    if not boot_app0 and pkg_base.is_dir():
        for candidate in pkg_base.rglob("boot_app0.bin"):
            if "esp32" in str(candidate).lower():
                boot_app0 = candidate
                break

    # Check all required files exist
    missing = []
    if not bootloader.exists():
        missing.append("bootloader.bin")
    if not partitions.exists():
        missing.append("partitions.bin")
    if not firmware.exists():
        missing.append("firmware.bin")

    if missing:
        log(f"ERROR: Missing build artifacts: {', '.join(missing)}")
        log("  Run a full build first (pio run)")
        return None

    # Flash layout for ESP32 (from partitions.csv):
    #   0x1000  bootloader.bin
    #   0x8000  partitions.bin
    #   0xE000  boot_app0.bin (OTA data init)
    #   0x10000 firmware.bin (app0 partition)
    offsets = {
        0x1000:  bootloader,
        0x8000:  partitions,
        0x10000: firmware,
    }

    if boot_app0 and boot_app0.exists():
        offsets[0xE000] = boot_app0
        log(f"  boot_app0.bin: {boot_app0}")
    else:
        log("  WARNING: boot_app0.bin not found — merged binary may not support OTA boot switching")

    # Calculate total size (from start to end of firmware)
    sorted_offsets = sorted(offsets.items())
    last_offset, last_file = sorted_offsets[-1]
    total_size = last_offset + last_file.stat().st_size

    # Create merged binary (fill gaps with 0xFF — flash erased state)
    merged = bytearray(b'\xFF' * total_size)

    for offset, filepath in sorted_offsets:
        data = filepath.read_bytes()
        merged[offset:offset + len(data)] = data
        log(f"  @0x{offset:05X}: {filepath.name} ({len(data)} bytes)")

    # Write merged binary
    merged_path = PIO_BUILD_DIR / "firmware-full.bin"
    merged_path.write_bytes(bytes(merged))

    size_kb = len(merged) / 1024
    log(f"Merged binary: {merged_path.name} ({size_kb:.1f} KB)")
    return merged_path


def build_apk(log_callback=None) -> Path | None:
    """Build APK with Flutter. Returns path to .apk or None."""
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    flutter_cli = find_flutter_cli()
    if not flutter_cli:
        log("ERROR: Flutter CLI not found!")
        log("  Searched: PATH, ~/flutter/bin/")
        log("  Install: https://flutter.dev/docs/get-started/install")
        return None

    log(f"Using Flutter: {flutter_cli}")
    mobile_dir = PROJECT_ROOT / "mobile_app"

    try:
        # Setup Android SDK if setup script exists (auto-enter on prompts)
        setup_script = mobile_dir / "scripts" / "setup_windows_android_toolkit.ps1"
        if platform.system() == "Windows" and setup_script.exists():
            log("Setting up Android SDK (auto)...")
            try:
                subprocess.run(
                    ["powershell", "-ExecutionPolicy", "Bypass",
                     "-NonInteractive", "-File", str(setup_script)],
                    cwd=str(mobile_dir),
                    capture_output=True, text=True, timeout=180,
                    input="",  # Auto-enter for any Read-Host prompts
                )
            except (subprocess.TimeoutExpired, Exception) as e:
                log(f"  Android SDK setup warning: {e}")

        # flutter pub get
        log("Running flutter pub get...")
        result = subprocess.run(
            [flutter_cli, "pub", "get"],
            cwd=str(mobile_dir),
            capture_output=True, text=True, timeout=120,
        )
        if result.returncode != 0:
            log(f"WARNING: flutter pub get failed:\n{result.stderr}")

        # flutter build apk --release
        log("Building APK (release mode)...")
        result = subprocess.run(
            [flutter_cli, "build", "apk", "--release"],
            cwd=str(mobile_dir),
            capture_output=True, text=True, timeout=600,
        )
        if result.returncode != 0:
            log(f"ERROR: APK build failed!\n{result.stderr}")
            if result.stdout:
                log(result.stdout[-2000:])
            return None

        log("APK build successful!")
        apk_path = mobile_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        if apk_path.exists():
            size_mb = apk_path.stat().st_size / (1024 * 1024)
            log(f"  app-release.apk: {size_mb:.1f} MB")
            return apk_path
        log("ERROR: app-release.apk not found after build")
        return None
    except FileNotFoundError:
        log(f"ERROR: Could not execute '{flutter_cli}'. File not found.")
        return None
    except subprocess.TimeoutExpired:
        log("ERROR: APK build timed out (600s)")
        return None


# ─── Package Release ─────────────────────────────────────────────────

def package_firmware_release(version: str, bin_path: Path, log_callback=None,
                             test_build: bool = False) -> bool:
    """Copy firmware .bin to releases/firmware/ with proper naming and MD5."""
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    FW_RELEASES_DIR.mkdir(parents=True, exist_ok=True)
    suffix = "-TEST" if test_build else ""
    dest_name = f"evilcrow-v2-fw-v{version}{suffix}-OTA.bin"
    dest_path = FW_RELEASES_DIR / dest_name
    md5_path = FW_RELEASES_DIR / f"{dest_name}.md5"

    shutil.copy2(bin_path, dest_path)
    md5_hash = compute_md5(dest_path)
    md5_path.write_text(md5_hash, encoding="utf-8")

    size_kb = dest_path.stat().st_size / 1024
    log(f"Firmware: {dest_path.name} ({size_kb:.1f} KB)")
    log(f"MD5:      {md5_hash}")

    # Also create merged/full binary for complete flash
    log("Creating merged OTA-ready binary...")
    merged = create_merged_binary(log_callback=log)
    if merged:
        full_name = f"evilcrow-v2-fw-v{version}{suffix}-full.bin"
        full_dest = FW_RELEASES_DIR / full_name
        full_md5_path = FW_RELEASES_DIR / f"{full_name}.md5"
        shutil.copy2(merged, full_dest)
        full_md5 = compute_md5(full_dest)
        full_md5_path.write_text(full_md5, encoding="utf-8")
        log(f"Full:     {full_dest.name} ({full_dest.stat().st_size / 1024:.1f} KB)")

    return True


def package_app_release(version: str, apk_path: Path, log_callback=None,
                        test_build: bool = False) -> bool:
    """Copy APK to releases/app/ with proper naming and MD5."""
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    APP_RELEASES_DIR.mkdir(parents=True, exist_ok=True)
    suffix = "-TEST" if test_build else ""
    dest_name = f"EvilCrowRF-v{version}{suffix}.apk"
    dest_path = APP_RELEASES_DIR / dest_name
    md5_path = APP_RELEASES_DIR / f"{dest_name}.md5"

    shutil.copy2(apk_path, dest_path)
    md5_hash = compute_md5(dest_path)
    md5_path.write_text(md5_hash, encoding="utf-8")

    size_mb = dest_path.stat().st_size / (1024 * 1024)
    log(f"APK:  {dest_path.name} ({size_mb:.1f} MB)")
    log(f"MD5:  {md5_hash}")
    return True


# =====================================================================
# CLI Mode
# =====================================================================

def cli_release_firmware(bump_type: str = "patch", changelog: str = "",
                         log_callback=None, test_build: bool = False,
                         no_bump: bool = False):
    """Build and release firmware from CLI."""
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    current = read_firmware_version()
    if test_build or no_bump:
        version = current
        label = "TEST BUILD" if test_build else "Release (no version bump)"
        log(f"=== Firmware {label} v{version} ===")
    else:
        version = bump_version(current, bump_type)
        log(f"=== Firmware Release v{version} (was {current}) ===")
        write_firmware_version(version)
        log(f"Updated config.h -> {version}")

    bin_path = build_firmware(log_callback=log)
    if bin_path is None:
        log("ABORTED: Firmware build failed.")
        return False

    package_firmware_release(version, bin_path, log_callback=log,
                             test_build=test_build)

    if changelog.strip():
        add_changelog_entry("firmware", version, changelog)
        log("Changelog updated.")

    log(f"OK: Firmware v{version} ready in releases/firmware/")
    log("")
    log("Which binary to use:")
    log(f"  OTA update (from app/BLE):  evilcrow-v2-fw-v{version}-OTA.bin")
    log(f"  Web flasher / first flash:  evilcrow-v2-fw-v{version}-full.bin")
    log(f"  esptool manual flash:       esptool.py write_flash 0x0 evilcrow-v2-fw-v{version}-full.bin")
    log("")
    log(f"  Git tag: git tag fw-v{version} && git push origin fw-v{version}")
    return True


def cli_release_apk(bump_type: str = "patch", changelog: str = "",
                     log_callback=None, test_build: bool = False,
                     no_bump: bool = False):
    """Build and release APK from CLI."""
    def log(msg):
        if log_callback:
            log_callback(msg)
        else:
            print(msg)

    current = read_app_version()
    if test_build or no_bump:
        version = current
        label = "TEST BUILD" if test_build else "Release (no version bump)"
        log(f"=== App {label} v{version} ===")
    else:
        version = bump_version(current, bump_type)
        log(f"=== App Release v{version} (was {current}) ===")
        write_app_version(version)
        log(f"Updated pubspec.yaml -> {version}")

    apk_path = build_apk(log_callback=log)
    if apk_path is None:
        log("ABORTED: APK build failed.")
        return False

    package_app_release(version, apk_path, log_callback=log,
                        test_build=test_build)

    if changelog.strip():
        add_changelog_entry("app", version, changelog)
        log("Changelog updated.")

    log(f"OK: App v{version} ready in releases/app/")
    log(f"  Git tag: git tag app-v{version} && git push origin app-v{version}")
    return True


def cli_interactive():
    """Interactive CLI mode when --cli is passed."""
    print("=" * 50)
    print("  EvilCrow RF V2 — Release Builder (CLI)")
    print("=" * 50)
    print()
    print(f"  Project root:  {PROJECT_ROOT}")
    print(f"  FW version:    {read_firmware_version()}")
    print(f"  App version:   {read_app_version()}")
    print(f"  PlatformIO:    {find_platformio_cli() or 'NOT FOUND'}")
    print(f"  Flutter:       {find_flutter_cli() or 'NOT FOUND'}")
    print()
    print("  1. Release Firmware")
    print("  2. Release App")
    print("  3. Release Both")
    print("  4. Build firmware only (no release)")
    print("  5. Create merged binary from existing build")
    print("  6. Prepare Environment (install PlatformIO)")
    print("  0. Exit")
    print()
    choice = input("Select [0-6]: ").strip()

    if choice == "0":
        return
    elif choice == "1":
        bump = input("Bump type [major/minor/patch] (default: patch): ").strip() or "patch"
        cl = input("Changelog (one line, or empty): ").strip()
        cli_release_firmware(bump, cl)
    elif choice == "2":
        bump = input("Bump type [major/minor/patch] (default: patch): ").strip() or "patch"
        cl = input("Changelog (one line, or empty): ").strip()
        cli_release_apk(bump, cl)
    elif choice == "3":
        bump = input("Bump type [major/minor/patch] (default: patch): ").strip() or "patch"
        cl = input("Changelog (one line, or empty): ").strip()
        cli_release_firmware(bump, cl)
        cli_release_apk(bump, cl)
    elif choice == "4":
        build_firmware()
    elif choice == "5":
        create_merged_binary()
    elif choice == "6":
        prepare_environment()
    else:
        print("Invalid choice.")


# =====================================================================
# GUI (Tkinter)
# =====================================================================

def launch_gui():
    """Launch the release builder GUI."""
    import tkinter as tk
    from tkinter import scrolledtext, ttk

    root = tk.Tk()
    root.title("EvilCrow RF V2 — Release Builder")
    root.geometry("720x780")
    root.resizable(True, True)
    root.configure(bg="#0a0a0a")

    # Styling
    style = ttk.Style()
    style.theme_use("clam")
    style.configure(".", background="#0a0a0a", foreground="#00e676",
                    fieldbackground="#1a1a1a", font=("Consolas", 10))
    style.configure("TLabel", background="#0a0a0a", foreground="#d4eed4",
                    font=("Consolas", 10))
    style.configure("TLabelframe", background="#0a0a0a", foreground="#00e676",
                    font=("Consolas", 10, "bold"))
    style.configure("TLabelframe.Label", background="#0a0a0a",
                    foreground="#00e676", font=("Consolas", 10, "bold"))
    style.configure("TButton", background="#1a3a1a", foreground="#00e676",
                    font=("Consolas", 10, "bold"), padding=6)
    style.map("TButton",
              background=[("active", "#00e676")],
              foreground=[("active", "#0a0a0a")])
    style.configure("TRadiobutton", background="#0a0a0a", foreground="#d4eed4",
                    font=("Consolas", 10))
    style.configure("TCheckbutton", background="#0a0a0a", foreground="#d4eed4",
                    font=("Consolas", 10))

    # Read current versions
    current_fw = read_firmware_version()
    current_app = read_app_version()

    # ── Title ──
    title_label = tk.Label(root, text="EvilCrow RF V2 — Release Builder",
                           bg="#0a0a0a", fg="#00e676",
                           font=("Consolas", 14, "bold"))
    title_label.pack(pady=(10, 5))

    # ── Main frame ──
    main_frame = ttk.Frame(root)
    main_frame.pack(fill=tk.BOTH, expand=True, padx=15, pady=5)

    # ════════════════════════════════════════════
    # FIRMWARE section
    # ════════════════════════════════════════════
    fw_frame = ttk.LabelFrame(main_frame, text=" Firmware ")
    fw_frame.pack(fill=tk.X, pady=(0, 8))

    fw_row1 = ttk.Frame(fw_frame)
    fw_row1.pack(fill=tk.X, padx=10, pady=4)

    ttk.Label(fw_row1, text=f"Current: {current_fw}").pack(side=tk.LEFT)

    fw_bump_var = tk.StringVar(value="patch")
    ttk.Label(fw_row1, text="  Bump:").pack(side=tk.LEFT, padx=(20, 5))
    for b in ("major", "minor", "patch"):
        ttk.Radiobutton(fw_row1, text=b.capitalize(), value=b,
                        variable=fw_bump_var).pack(side=tk.LEFT, padx=2)

    fw_new_ver = tk.StringVar(value=bump_version(current_fw, "patch"))

    def on_fw_bump_change(*_):
        fw_new_ver.set(bump_version(current_fw, fw_bump_var.get()))
    fw_bump_var.trace_add("write", on_fw_bump_change)

    fw_row2 = ttk.Frame(fw_frame)
    fw_row2.pack(fill=tk.X, padx=10, pady=2)
    ttk.Label(fw_row2, text="New version:").pack(side=tk.LEFT)
    fw_ver_entry = ttk.Entry(fw_row2, textvariable=fw_new_ver, width=12)
    fw_ver_entry.pack(side=tk.LEFT, padx=5)

    fw_build_var = tk.BooleanVar(value=True)
    ttk.Checkbutton(fw_row2, text="Build firmware (pio run)",
                    variable=fw_build_var).pack(side=tk.LEFT, padx=10)

    fw_row3 = ttk.Frame(fw_frame)
    fw_row3.pack(fill=tk.X, padx=10, pady=2)

    fw_test_var = tk.BooleanVar(value=False)
    ttk.Checkbutton(fw_row3, text="TEST BUILD (adds -TEST suffix, no version bump)",
                    variable=fw_test_var).pack(side=tk.LEFT)

    fw_nobump_var = tk.BooleanVar(value=False)
    ttk.Checkbutton(fw_row3, text="Keep current version (no bump)",
                    variable=fw_nobump_var).pack(side=tk.LEFT, padx=(20, 0))

    # Firmware changelog
    ttk.Label(fw_frame, text="Changelog (one per line, optionally [feature]/[fix]/[improvement]):").pack(
        anchor=tk.W, padx=10, pady=(4, 0))
    fw_changelog = scrolledtext.ScrolledText(
        fw_frame, height=4, bg="#1a1a1a", fg="#d4eed4",
        insertbackground="#00e676", font=("Consolas", 10),
        relief=tk.FLAT, wrap=tk.WORD)
    fw_changelog.pack(fill=tk.X, padx=10, pady=(2, 8))

    # ════════════════════════════════════════════
    # APP section
    # ════════════════════════════════════════════
    app_frame = ttk.LabelFrame(main_frame, text=" Mobile App ")
    app_frame.pack(fill=tk.X, pady=(0, 8))

    app_row1 = ttk.Frame(app_frame)
    app_row1.pack(fill=tk.X, padx=10, pady=4)

    ttk.Label(app_row1, text=f"Current: {current_app}").pack(side=tk.LEFT)

    app_bump_var = tk.StringVar(value="patch")
    ttk.Label(app_row1, text="  Bump:").pack(side=tk.LEFT, padx=(20, 5))
    for b in ("major", "minor", "patch"):
        ttk.Radiobutton(app_row1, text=b.capitalize(), value=b,
                        variable=app_bump_var).pack(side=tk.LEFT, padx=2)

    app_new_ver = tk.StringVar(value=bump_version(current_app, "patch"))

    def on_app_bump_change(*_):
        app_new_ver.set(bump_version(current_app, app_bump_var.get()))
    app_bump_var.trace_add("write", on_app_bump_change)

    app_row2 = ttk.Frame(app_frame)
    app_row2.pack(fill=tk.X, padx=10, pady=2)
    ttk.Label(app_row2, text="New version:").pack(side=tk.LEFT)
    app_ver_entry = ttk.Entry(app_row2, textvariable=app_new_ver, width=12)
    app_ver_entry.pack(side=tk.LEFT, padx=5)

    app_build_var = tk.BooleanVar(value=True)
    ttk.Checkbutton(app_row2, text="Build APK (flutter build apk)",
                    variable=app_build_var).pack(side=tk.LEFT, padx=10)

    app_row3 = ttk.Frame(app_frame)
    app_row3.pack(fill=tk.X, padx=10, pady=2)

    app_test_var = tk.BooleanVar(value=False)
    ttk.Checkbutton(app_row3, text="TEST BUILD (adds -TEST suffix, no version bump)",
                    variable=app_test_var).pack(side=tk.LEFT)

    app_nobump_var = tk.BooleanVar(value=False)
    ttk.Checkbutton(app_row3, text="Keep current version (no bump)",
                    variable=app_nobump_var).pack(side=tk.LEFT, padx=(20, 0))

    # App changelog
    ttk.Label(app_frame, text="Changelog (one per line, optionally [feature]/[fix]/[improvement]):").pack(
        anchor=tk.W, padx=10, pady=(4, 0))
    app_changelog = scrolledtext.ScrolledText(
        app_frame, height=4, bg="#1a1a1a", fg="#d4eed4",
        insertbackground="#00e676", font=("Consolas", 10),
        relief=tk.FLAT, wrap=tk.WORD)
    app_changelog.pack(fill=tk.X, padx=10, pady=(2, 8))

    # ════════════════════════════════════════════
    # Action Buttons
    # ════════════════════════════════════════════
    btn_frame = ttk.Frame(main_frame)
    btn_frame.pack(fill=tk.X, pady=4)

    def do_release_fw():
        threading.Thread(target=_release_firmware, daemon=True).start()

    def do_release_app():
        threading.Thread(target=_release_app, daemon=True).start()

    def do_release_both():
        threading.Thread(target=_release_both, daemon=True).start()

    ttk.Button(btn_frame, text="Release Firmware",
               command=do_release_fw).pack(side=tk.LEFT, padx=4)
    ttk.Button(btn_frame, text="Release App",
               command=do_release_app).pack(side=tk.LEFT, padx=4)
    ttk.Button(btn_frame, text="Release Both",
               command=do_release_both).pack(side=tk.LEFT, padx=4)
    ttk.Button(btn_frame, text="Prepare Environment",
               command=lambda: threading.Thread(
                   target=lambda: prepare_environment(log_callback=log),
                   daemon=True).start()).pack(side=tk.LEFT, padx=4)

    # ════════════════════════════════════════════
    # Log output
    # ════════════════════════════════════════════
    log_frame = ttk.LabelFrame(main_frame, text=" Log ")
    log_frame.pack(fill=tk.BOTH, expand=True, pady=(4, 0))

    log_text = scrolledtext.ScrolledText(
        log_frame, height=10, bg="#020a02", fg="#00ff41",
        insertbackground="#00e676", font=("Consolas", 10),
        relief=tk.FLAT, wrap=tk.WORD, state=tk.DISABLED)
    log_text.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)

    def log(msg: str):
        def _append():
            log_text.config(state=tk.NORMAL)
            log_text.insert(tk.END, msg + "\n")
            log_text.see(tk.END)
            log_text.config(state=tk.DISABLED)
        root.after(0, _append)

    # ── Release logic ──

    def _release_firmware():
        is_test = fw_test_var.get()
        is_nobump = fw_nobump_var.get()
        version = fw_new_ver.get().strip()

        if is_test or is_nobump:
            # Use current version, don't bump
            version = current_fw
            label = "TEST BUILD" if is_test else "Release (no version bump)"
            log(f"=== Firmware {label} v{version} ===")
        else:
            if not re.match(r'^\d+\.\d+\.\d+$', version):
                log("ERROR: Invalid firmware version format. Use X.Y.Z")
                return
            log(f"=== Firmware Release v{version} ===")
            # Update config.h
            log(f"Updating config.h -> {version}")
            write_firmware_version(version)

        suffix = "-TEST" if is_test else ""

        if fw_build_var.get():
            bin_path = build_firmware(log_callback=log)
            if bin_path is None:
                log("ABORTED: Firmware build failed.")
                return
        else:
            bin_path = PIO_BUILD_DIR / "firmware.bin"
            if not bin_path.exists():
                log("ERROR: No firmware.bin found. Enable 'Build firmware' or run pio manually.")
                return
            log(f"Using existing firmware.bin ({bin_path.stat().st_size / 1024:.1f} KB)")

        # Package
        package_firmware_release(version, bin_path, log_callback=log,
                                 test_build=is_test)

        # Changelog (skip for TEST builds)
        if not is_test:
            changes = fw_changelog.get("1.0", tk.END).strip()
            if changes:
                add_changelog_entry("firmware", version, changes)
                log("Changelog updated.")

        log(f"OK: Firmware v{version}{suffix} release ready in releases/firmware/")
        log("")
        log("Which binary to use:")
        log(f"  OTA update (from app/BLE):  evilcrow-v2-fw-v{version}{suffix}-OTA.bin")
        log(f"  Web flasher / first flash:  evilcrow-v2-fw-v{version}{suffix}-full.bin")
        log(f"  esptool manual flash:       esptool.py write_flash 0x0 evilcrow-v2-fw-v{version}{suffix}-full.bin")
        if not is_test:
            log("")
            log(f"  Git tag: git tag fw-v{version} && git push origin fw-v{version}")
        log("")

    def _release_app():
        is_test = app_test_var.get()
        is_nobump = app_nobump_var.get()
        version = app_new_ver.get().strip()

        if is_test or is_nobump:
            version = current_app
            label = "TEST BUILD" if is_test else "Release (no version bump)"
            log(f"=== App {label} v{version} ===")
        else:
            if not re.match(r'^\d+\.\d+\.\d+$', version):
                log("ERROR: Invalid app version format. Use X.Y.Z")
                return
            log(f"=== App Release v{version} ===")
            # Update pubspec.yaml
            log(f"Updating pubspec.yaml -> {version}")
            write_app_version(version)

        suffix = "-TEST" if is_test else ""

        if app_build_var.get():
            apk_path = build_apk(log_callback=log)
            if apk_path is None:
                log("ABORTED: APK build failed.")
                return
        else:
            apk_path = PROJECT_ROOT / "mobile_app" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
            if not apk_path.exists():
                log("ERROR: No app-release.apk found. Enable 'Build APK' or run flutter manually.")
                return
            log(f"Using existing APK ({apk_path.stat().st_size / (1024*1024):.1f} MB)")

        # Package
        package_app_release(version, apk_path, log_callback=log,
                            test_build=is_test)

        # Changelog (skip for TEST builds)
        if not is_test:
            changes = app_changelog.get("1.0", tk.END).strip()
            if changes:
                add_changelog_entry("app", version, changes)
                log("Changelog updated.")

        log(f"OK: App v{version}{suffix} release ready in releases/app/")
        if not is_test:
            log(f"  Git tag: git tag app-v{version} && git push origin app-v{version}")
        log("")

    def _release_both():
        _release_firmware()
        _release_app()
        log("=== Both releases complete ===")

    # Show tool discovery status
    pio = find_platformio_cli()
    flutter = find_flutter_cli()
    log(f"Project root: {PROJECT_ROOT}")
    log(f"Firmware version: {current_fw}")
    log(f"App version:      {current_app}")
    log(f"PlatformIO: {pio or 'NOT FOUND - firmware build will fail'}")
    log(f"Flutter:    {flutter or 'NOT FOUND - APK build will fail'}")
    log("Ready. Select bump type, write changelogs, and click Release.")
    log("")

    root.mainloop()


# =====================================================================
# Main entry point
# =====================================================================

def main():
    args = sys.argv[1:]

    if "--help" in args or "-h" in args:
        print(__doc__)
        return

    # CLI flags
    build_fw = "--fw" in args
    build_app = "--apk" in args
    is_cli = "--cli" in args
    is_prepare = "--prepare" in args
    is_test = "--test" in args
    is_nobump = "--no-bump" in args
    bump = "patch"
    for a in args:
        if a.startswith("--bump="):
            bump = a.split("=", 1)[1]

    if is_prepare:
        prepare_environment()
    elif is_cli:
        cli_interactive()
    elif build_fw or build_app:
        # Direct CLI build (non-interactive)
        if build_fw:
            cli_release_firmware(bump, test_build=is_test, no_bump=is_nobump)
        if build_app:
            cli_release_apk(bump, test_build=is_test, no_bump=is_nobump)
    else:
        # Default: launch GUI
        try:
            launch_gui()
        except ImportError:
            print("Tkinter not available. Use --cli or --fw/--apk flags.")
            sys.exit(1)


if __name__ == "__main__":
    main()
