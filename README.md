# EvilCrow RF V2

  

![Banner](docs/media/img/Banner_V2.png)

EvilCrow RF V2 is an open-source project providing firmware, tools and a mobile app for sub-GHz radio research, testing and experimentation. The project centers on an ESP32-based controller using CC1101 transceivers and a companion Flutter mobile app for BLE control, plus Python SDR tools and a web-based firmware flasher.

  

## Quick Links


- [⚡WEB FIRMWARE FLASHER](https://senape3000.github.io/EvilCrowRF-V2/web-flasher/)

- [🖥️APP & FW Release](https://github.com/Senape3000/EvilCrowRF-V2/releases) 

- [❤️DONATE](https://ko-fi.com/senape3000)

  

## Supported Hardware

  

- EvilCrowRF-V2 [[link]](https://it.aliexpress.com/item/1005007868951389.html?gatewayAdapt=glo2ita4itemAdapt)- [[link]](https://labs.ksec.co.uk/product/evil-crow-rf-v2/)
- Storage: LittleFS (internal) and SD card support (max 32GB) (FAT32 FS)

  

## Key Features

  

- CC1101 driver and dual-module support for sub-GHz operations

- 33+ protocol brute-force engine and De Bruijn attack modes

- Universal Sweep mode (automated multi-frequency scanning)

- Pause / Resume bruter state persisted via LittleFS

- BLE-based binary protocol with chunked transfers and notifications

- OTA over BLE with MD5 verification (app ↔ device workflow)

- Web flasher UI (ESP Web Tools manifest + GitHub releases integration)

- Flutter mobile app: BLE controller, quick actions, OTA checks

- [SDR-like tools and Python utilities (spectrum scan, raw RX, URH bridge)](https://github.com/Senape3000/EvilCrowRF-V2/tree/main/SDR)

- Battery monitoring and status notifications via BLE

  

See `docs/` for detailed guides, attack-method documentation, and developer notes.

  

## Quick Start

  

Requirements: PlatformIO (for firmware), Flutter (for mobile app), Python 3.8+ (for SDR tools).

  

Build firmware (PlatformIO):

  

```bash

todo

```

  

Build mobile app (Android):

  

```bash

todo

```

  

Run SDR tools (example):

  

```bash

todo

```

  

***Web flasher***: open the hosted flasher URL above. The web flasher fetches releases and drives ESP Web Tools for in-browser flashing.

  

## OTA & Releases

  

- Releases follow semantic versioning. Firmware and app releases are published to GitHub releases and referenced by the web flasher.

- Typical assets: `evilcrow-v2-fw-vX.Y.Z.bin`, `evilcrow-v2-fw-vX.Y.Z.bin.md5`, `EvilCrowRF-vX.Y.Z.apk`.

- OTA high-level protocol: device commands include OTA begin, chunked data transfer, end and reboot. The app verifies MD5 before the transfer.

 

## Project Structure

  

-  `src/` — firmware C/C++ sources

-  `include/` — shared headers and message definitions

-  `lib/` — external libraries and drivers (e.g., CC1101 driver)

-  `mobile_app/` — Flutter mobile controller (UI + BLE code)

-  `web-flasher/` — static web flasher site (index.html, app.js)

-  `SDR/` — Python SDR utilities

-  `docs/` — documentation, guides, schematics and plans

  

## Development & Contributing

  

- Follow existing coding style and keep changes focused.

- Use PlatformIO for building and flashing firmware; Windows helper scripts are provided (`build_firmware.bat`, `flash_firmware.bat`).

- Mobile contributions: work inside `mobile_app/` (Flutter); see `mobile_app/README.md` for setup.

- Tests & tools: there are Python helpers and test harnesses for the bruter module under `tools/` and `SDR/`.
  

## Future Work

- Add dictionary attack mode (wordlist-based brute-force)

- Explore rolling-code analysis tooling

- Add multi-frequency protocol variants (Chamberlain/Liftmaster/etc.)

- Enhance DuckyScript parser (REPEAT, DELAY, multi-key combos)

- Complete app localization

- Add De Bruijn support for larger n (14/16) after verifying heap budget

  

## Security & Legal Notice

  

This project is intended for research and authorized testing only. Do not use these tools on systems for which you do not have explicit permission. The maintainers disclaim liability for misuse.
**By using or downloading this code, you agree to these terms and acknowledge that the authors will not be held liable for any misuse.**


  

## Acknowledgements & Contributors

  

Thanks to the many contributors and collaborators — notable maintainers and authors:

- tutejshy-bit — https://github.com/tutejshy-bit

- realdaveblanch — https://github.com/realdaveblanch

- joelsernamoreno — https://github.com/joelsernamoreno/EvilCrowRF-V2




## Contact & Issues

Open an issue on GitHub for bugs, feature requests or support.

  

![Logo](docs/media/img/Senape3000_LOGO.png)
