# Evil Crow RF v2 Mobile Controller

Mobile application to control the Evil Crow RF v2 device via Bluetooth Low Energy (BLE).

## Features

- **Device discovery**: Automatically search for the ESP32 device named "EvilCrow_RF2"
- **BLE connection**: Connect to the device with automatic service discovery
- **Send commands**: Text input and quick buttons for common commands
- **Connection status**: Shows current BLE connection state
- **Cross-platform**: Works on Android and iOS

## Install Flutter

### Windows

1. **Download Flutter SDK**:
   - Visit [flutter.dev](https://flutter.dev/docs/get-started/install/windows)
   - Download the Flutter SDK for Windows
   - Extract to a folder (e.g., `C:\flutter`)

2. **Add Flutter to PATH**:
   - Open Environment Variables in Windows
   - Add `C:\flutter\bin` to the PATH variable

3. **Install Android Studio**:
   - Download [Android Studio](https://developer.android.com/studio)
   - Install Android SDK
   - Configure an emulator or connect a physical device

4. **Verify installation**:
```
flutter doctor
```

## Run the app

1. **Change directory to the app**:
```
cd mobile_app
```

2. **Install dependencies**:
```
flutter pub get
```

3. **Run the app**:
```
flutter run
```

## Usage

### Connect to the device

1. **Enable Bluetooth** on your phone
2. **Tap "Scan for Devices"** to search for devices
3. **Find "EvilCrow_RF2"** in the list
4. **Tap "Connect"** to connect

### Send commands

After connecting you can:

- **Type a command manually** in the input field
- **Use quick buttons**:
  - `SCAN` - Start scanning RF signals
  - `RECORD` - Start recording a signal
  - `PLAY` - Play a recorded signal
  - `STOP` - Stop the current operation

### Connection status

The app shows:
- Current BLE connection status
- Error messages
- Connection indicator (green/red)

## Project structure

```
mobile_app/
├── lib/
│   ├── main.dart              # Main application file
│   ├── screens/
│   │   └── home_screen.dart   # Main screen
│   └── providers/
│       └── ble_provider.dart  # BLE logic
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

## Dependencies

- **flutter_blue_plus**: BLE functionality
- **permission_handler**: Permissions management
- **provider**: State management

## Permissions

The app requests:
- Bluetooth
- Bluetooth Scan
- Bluetooth Connect
- Location (required for BLE on Android)

## Compatibility

- **Android**: 5.0+ (API 21+)
- **iOS**: 12.0+
- **Flutter**: 3.0.0+

## Troubleshooting

### Device not found

1. Make sure the ESP32 is powered on and advertising BLE
2. Check that Bluetooth is enabled on your phone
3. Try restarting the scan

### Connection error

1. Ensure the device is not connected to another app
2. Make sure the ESP32 is not in deep sleep
3. Try restarting the ESP32

### App fails to compile

1. Check Flutter version: `flutter --version`
2. Update dependencies: `flutter pub upgrade`
3. Clear cache: `flutter clean && flutter pub get`

## Development

### Adding new commands

1. Open `lib/screens/home_screen.dart`
2. Add a new button to the "Quick Commands" section
3. Add handling for the command in the ESP32 code

### Changing the UI

1. Open `lib/screens/home_screen.dart`
2. Modify widgets and styles
3. Restart the app

### Debugging BLE

1. Use `print()` in `ble_provider.dart`
2. Check the Flutter console
3. Use nRF Connect to verify the BLE connection

## License

This project is provided "as-is" for educational purposes.

