import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../models/detected_signal.dart';
import '../models/directory_tree_node.dart';
import 'firmware_protocol.dart';
import '../services/signal_processing/signal_data.dart';
import '../services/signal_generators/signal_generator_factory.dart';
import '../services/signal_generators/base_signal_generator.dart';
import '../services/file_parsers/file_parser_factory.dart';
import '../services/cc1101/cc1101_calculator.dart';
import '../services/cc1101/cc1101_values.dart';
import '../services/binary_message_parser.dart';
// import 'log_provider.dart'; // Unused import removed

class BleProvider extends ChangeNotifier {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? txCharacteristic;
  BluetoothCharacteristic? rxCharacteristic;
  
  // BLE stream subscriptions (stored for cleanup on reconnect/dispose)
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<List<int>>? _rxValueSubscription;
  
  // OTA auto-reconnect state
  bool _otaRebootPending = false;
  String? _otaPreRebootVersion;
  Timer? _otaReconnectTimer;

  // Callback for logging
  Function(String level, String message, {String? details})? _logCallback;

  // Callback for user-facing notifications (forwarded to NotificationProvider)
  Function(String level, String message)? _notificationCallback;
  
  // File reading state
  String? _currentFileContent;
  Completer<String>? _pendingFileReadCompleter;
  bool isLoadingFileContent = false;
  double fileContentProgress = 0.0;
  
  // File system operations completers
  Completer<Map<String, dynamic>>? _pendingRenameCompleter;
  Completer<Map<String, dynamic>>? _pendingDeleteCompleter;
  Completer<Map<String, dynamic>>? _pendingMkdirCompleter;
  Completer<Map<String, dynamic>>? _pendingDirectoryTreeCompleter;
  
  // Method for setting logging callback
  void setLogCallback(Function(String level, String message, {String? details}) callback) {
    _logCallback = callback;
  }

  // Method for setting notification callback (for user-facing notifications)
  void setNotificationCallback(Function(String level, String message) callback) {
    _notificationCallback = callback;
  }

  // Helper to fire a user-facing notification
  void _notify(String level, String message) {
    _notificationCallback?.call(level, message);
  }
  
  // Helper method for logging
  void _log(String level, String message, {String? details}) {
    _logCallback?.call(level, message, details: details);
  }
  
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> scanResults = [];
  String statusMessage = ''; // Will be set with localized strings
  String lastCommandMessage = ''; // Separate field for command messages
  
  // List of supported device names (fallback)
  static const List<String> supportedDeviceNames = [
    'ESP32_CC1101',
    'EvilCrow_RF2',
    'ESP32_Binary',
    'ESP32',
  ];
  
  // Our custom Service UUID for device identification
  static const String evilCrowServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  
  // Nordic UART Service (NUS) UUIDs
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String txUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // Write characteristic
  static const String rxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // Notify characteristic
  
  // EvilCrow Manufacturer ID and Device ID
  static const int evilCrowManufacturerId = 0x1234;
  static const List<int> evilCrowDeviceId = [0x01, 0x02, 0x03, 0x04];
  List<FileItem> fileList = [];
  String currentPath = '/';
  int currentPathType = 5; // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, 2=/DATA/PRESETS, 3=/DATA/TEMP, 4=INTERNAL (LittleFS), 5=SD Root
  bool isLoadingFiles = false;
  double fileListProgress = 0.0; // Progress for file list loading (0.0 to 1.0)
  
  // Scanner state
  List<DetectedSignal> detectedSignals = [];
  Map<String, double> frequencySpectrum = {};
  int selectedModule = 0;
  int rssiThreshold = -100;
  
  // Device status
  Map<String, dynamic>? deviceStatus;
  int? freeHeap;
  double? cpuTempC;
  int? core0Mhz;
  int? core1Mhz;
  List<Map<String, dynamic>>? cc1101Modules;
  
  // Recorded files
  List<Map<String, dynamic>> recordedRuntimeFiles = [];
  
  // Recording state for each module
  Map<int, bool> isRecording = {0: false, 1: false}; // Module -> is recording
  Map<int, bool> isFrequencySearching = {0: false, 1: false}; // Module -> is frequency searching
  Map<int, bool> isJamming = {0: false, 1: false}; // Module -> is jamming

  // ── NRF24 state (reactive, used by NrfScreen via Consumer) ──
  bool nrfInitialized = false;
  bool nrfScanning = false;
  bool nrfAttacking = false;
  bool nrfSpectrumRunning = false;
  bool nrfJammerRunning = false;
  int nrfJamMode = 0;
  int nrfJamChannel = 0;
  int nrfJamDwellTimeMs = 0;
  List<Map<String, dynamic>> nrfTargets = [];
  List<int> nrfSpectrumLevels = List.filled(126, 0);

  // Per-mode jammer config cache (populated by 0xD6 responses)
  Map<int, Map<String, dynamic>> nrfJamModeConfigs = {};
  // Per-mode jammer info cache (populated by 0xD7 responses)
  Map<int, Map<String, dynamic>> nrfJamModeInfos = {};

  /// Trigger UI rebuild after NRF state fields are modified externally.
  ///
  /// NRF screen manages provider state fields directly for simplicity;
  /// use this instead of calling notifyListeners() from outside the class.
  void nrfNotify() => notifyListeners();

  // ── SDR state (reactive, used by SettingsScreen via Consumer) ──
  bool sdrModeActive = false;
  int sdrSubMode = 0;
  double sdrFrequencyMHz = 433.92;
  int sdrModulation = 2; // ASK/OOK default

  // ── SD card storage info (populated by 0xC9 on GetState) ──
  bool sdMounted = false;
  int sdTotalMB = 0;
  int sdFreeMB = 0;

  // ── nRF24 hardware status (populated by 0xCA on GetState) ──
  bool nrfPresent = false;

  // ── HW button config from device (populated by 0xC8 on GetState) ──
  // -1 = not yet received from device
  int deviceBtn1Action = -1;
  int deviceBtn2Action = -1;
  int deviceBtn1PathType = -1;
  int deviceBtn2PathType = -1;

  // ── OTA state (reactive, used by OtaScreen via Consumer) ──
  int otaProgress = 0;
  int otaBytesWritten = 0;
  bool otaComplete = false;
  String? otaErrorMessage;
  
  // Cache for file lists by paths
  final Map<String, List<FileItem>> _fileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {}; // Time of last update for each path
  
  // Streaming file list buffer (for accumulating files from multiple messages)
  final List<FileItem> _streamingFileBuffer = [];
  bool _isStreamingFileList = false;
  int _streamingTotalFiles = 0;  // Total files expected (for progress)
  
  // Directory tree streaming state
  final List<String> _streamingDirectoryTreeBuffer = [];
  bool _isStreamingDirectoryTree = false;
  int _streamingTotalDirs = 0;  // Total directories expected (for progress)
  
  // Protection against multiple commands
  bool _isCommandInProgress = false;
  bool _isWriting = false; // Flag to prevent concurrent BLE writes
  DateTime? _lastCommandTime;
  static const Duration _commandCooldown = Duration(milliseconds: 200);
  
  // Timeouts for commands
  Timer? _commandTimeout;
  static const Duration _commandTimeoutDuration = Duration(seconds: 15);
  
  // Timeout for file list loading
  Timer? _fileListTimeout;
  static const Duration _fileListTimeoutDuration = Duration(seconds: 15);
  
  // Buffers for chunks
  // Old chunk buffers removed - using firmware protocol now
  
  // Current chunk state
  // Old chunk state variables removed - using firmware protocol now
  
  // Old chunk processing variables removed - using firmware protocol now
  
  
  // Target device name - updated to match firmware
  static const String targetDeviceName = 'ESP32_CC1101';
  
  // Known device storage
  String? _knownDeviceId;
  static const String _deviceIdKey = 'known_device_id';
  
  // Quick connect to known device
  Future<void> quickConnect() async {
    if (isConnected || isScanning) return;
    
    try {
      // First try: Connect to known device if we have one
      if (_knownDeviceId != null) {
        print('Attempting direct connection to known device: $_knownDeviceId');
        statusMessage = 'connectingToKnownDevice'; // Key for localization
        notifyListeners();
        
        try {
          BluetoothDevice knownDevice = BluetoothDevice.fromId(_knownDeviceId!);
          print('Created device object for known device: ${knownDevice.name} (${knownDevice.id})');
          await connectToDevice(knownDevice);
          return; // Success, exit early
        } catch (e) {
          print('Direct connection failed: $e');
          // Clear the known device if it's no longer available
          await _clearKnownDevice();
        }
      }
      
      // Second try: Scan for target device
      print('Scanning for target device: $targetDeviceName');
      statusMessage = 'Scanning for device...';
      notifyListeners();
      
      await startScan();
      
      // Wait for scan results (reduced timeout)
      await Future.delayed(const Duration(seconds: 2));
      
      // Look for target device in supported scan results
      List<ScanResult> supportedDevices = supportedScanResults;
      for (var result in supportedDevices) {
        if (result.device.name == targetDeviceName) {
          print('Found target device: ${result.device.id}');
          await connectToDevice(result.device);
          // Save this device for future quick connections
          await saveKnownDevice(result.device.id.toString());
          break;
        }
      }
      
      // If no device found, show error
      if (!isConnected) {
        statusMessage = 'Device not found. Make sure it\'s powered on and nearby.';
        notifyListeners();
      }
      
    } catch (e) {
      statusMessage = 'Connection error: $e';
      notifyListeners();
    }
  }

  BleProvider() {
    _initializeBle();
    _loadKnownDevice();
    _loadTempOffsetPref();
  }

  Future<void> _initializeBle() async {
    // Request permissions
    await requestPermissions();
    
    // Listen to Bluetooth state changes
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        // Don't show "Bluetooth enabled" message
        statusMessage = '';
      } else {
        statusMessage = 'Bluetooth disabled';
        isConnected = false;
        connectedDevice = null;
      }
      notifyListeners();
    });
  }
  
  Future<void> _loadKnownDevice() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _knownDeviceId = prefs.getString(_deviceIdKey);
      if (_knownDeviceId != null) {
        print('Loaded known device ID: $_knownDeviceId');
      }
    } catch (e) {
      print('Error loading known device: $e');
    }
  }

  Future<void> _loadTempOffsetPref() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _cpuTempOffsetDeciC = (prefs.getInt('cpuTempOffsetDeciC') ?? -200).clamp(-500, 500);
    } catch (e) {
      print('Error loading cpu temp offset: $e');
    }
  }
  
  Future<void> saveKnownDevice(String deviceId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, deviceId);
      _knownDeviceId = deviceId;
      print('Saved known device ID: $deviceId');
    } catch (e) {
      print('Error saving known device: $e');
    }
  }
  
  Future<void> _clearKnownDevice() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      _knownDeviceId = null;
      print('Cleared known device ID');
    } catch (e) {
      print('Error clearing known device: $e');
    }
  }
  
  /// Clear saved device cache
  Future<void> clearDeviceCache() async {
    await _clearKnownDevice();
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    // Basic Bluetooth permissions
    if (await Permission.bluetooth.isDenied) {
      await Permission.bluetooth.request();
    }
    
    // Android 12+ specific permissions
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    
    if (await Permission.bluetoothAdvertise.isDenied) {
      await Permission.bluetoothAdvertise.request();
    }
    
    // Location permission (required for scanning)
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    
    // Check if all permissions are granted
    bool allGranted = await Permission.bluetooth.isGranted &&
                      await Permission.bluetoothScan.isGranted &&
                      await Permission.bluetoothConnect.isGranted &&
                      await Permission.location.isGranted;
    
    if (!allGranted) {
      statusMessage = 'Some permissions denied. Bluetooth may not work properly.';
      notifyListeners();
    } else {
      statusMessage = 'All permissions granted. Bluetooth ready.';
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    if (isScanning) return;
    
    // Check permissions before scanning
    if (!await _checkScanPermissions()) {
      statusMessage = 'Bluetooth scan permissions not granted';
      notifyListeners();
      return;
    }
    
    try {
      isScanning = true;
      scanResults.clear();
      statusMessage = 'scanningForDevices'; // Key for localization
      notifyListeners();
      
      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      // Listen to scan results
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        scanResults = results;
        print('Scan results updated: ${results.length} devices found');
        
        // Log all devices
        for (var result in results) {
          print('Found device: ${result.device.name} (${result.device.id})');
        }
        
        // Log supported devices count only
        List<ScanResult> supportedDevices = supportedScanResults;
        if (supportedDevices.isNotEmpty) {
          print('Found ${supportedDevices.length} supported device(s)');
        }
        
        notifyListeners();
      });
      
      await Future.delayed(const Duration(seconds: 10));
      await stopScan();
      
      // Show scan results
      List<ScanResult> supportedDevices = supportedScanResults;
      if (supportedDevices.isNotEmpty) {
        statusMessage = 'foundSupportedDevices:${supportedDevices.length}'; // Key with count for localization
      } else {
        statusMessage = 'No supported devices found. Make sure ESP32 is powered on and nearby.';
      }
      notifyListeners();
    } catch (e) {
      statusMessage = 'Scan error: $e';
      notifyListeners();
    }
  }

  Future<bool> _checkScanPermissions() async {
    return await Permission.bluetooth.isGranted &&
           await Permission.bluetoothScan.isGranted &&
           await Permission.location.isGranted;
  }
  
  // Filter scan results to show only supported devices
  List<ScanResult> get supportedScanResults {
    return scanResults.where((result) {
      // Primary method: Check for our Service UUID
      if (result.advertisementData.serviceUuids.contains(evilCrowServiceUuid)) {
        return true;
      }
      
      // Secondary method: Check Manufacturer Data
      var manufacturerData = result.advertisementData.manufacturerData;
      if (manufacturerData.containsKey(evilCrowManufacturerId)) {
        var data = manufacturerData[evilCrowManufacturerId];
        if (data != null && data.length >= evilCrowDeviceId.length) {
          bool deviceIdMatch = true;
          for (int i = 0; i < evilCrowDeviceId.length; i++) {
            if (data[i] != evilCrowDeviceId[i]) {
              deviceIdMatch = false;
              break;
            }
          }
          if (deviceIdMatch) {
            return true;
          }
        }
      }
      
      // Fallback method: Check device name
      String deviceName = result.device.name;
      bool nameMatch = supportedDeviceNames.any((supportedName) => 
        deviceName.toLowerCase().contains(supportedName.toLowerCase()));
      
      return nameMatch;
    }).toList();
  }

  Future<void> stopScan() async {
    if (!isScanning) return;
    
    try {
      await FlutterBluePlus.stopScan();
      isScanning = false;
      statusMessage = 'Scan stopped';
      notifyListeners();
    } catch (e) {
      statusMessage = 'Stop scan error: $e';
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      statusMessage = 'connecting'; // Key for localization
      _log('info', 'Attempting to connect to device', details: 'Device: ${device.name} (${device.id})');
      print('Connecting to device: ${device.name} (${device.id})');
      notifyListeners();
      
      await device.connect(timeout: const Duration(seconds: 10));
      connectedDevice = device;
      
      // Set up connection state monitoring (cancel previous subscription on reconnect)
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        bool isConnected = state == BluetoothConnectionState.connected;
        print('Connection state changed: $isConnected');
        if (!isConnected) {
          print('Device disconnected, resetting state');
          _resetConnectionState();
        }
      });
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our service
      BluetoothService? targetService;
      print('Discovered services:');
      for (BluetoothService service in services) {
        print('  Service UUID: ${service.uuid.toString()}');
        if (service.uuid.toString().toUpperCase() == serviceUuid.toUpperCase()) {
          targetService = service;
          print('  Found target service!');
          break;
        }
      }
      
      if (targetService != null) {
        // Find characteristics
        print('Target service characteristics:');
        for (BluetoothCharacteristic characteristic in targetService.characteristics) {
          print('  Characteristic UUID: ${characteristic.uuid.toString()}');
          if (characteristic.uuid.toString().toUpperCase() == txUuid.toUpperCase()) {
            txCharacteristic = characteristic;
            print('  Found TX characteristic!');
          } else if (characteristic.uuid.toString().toUpperCase() == rxUuid.toUpperCase()) {
            rxCharacteristic = characteristic;
            print('  Found RX characteristic!');
          }
        }
        
        if (txCharacteristic != null && rxCharacteristic != null) {
          isConnected = true;
          statusMessage = 'Connected to ${device.name}';
          _log('info', 'Successfully connected to device', details: 'Device: ${device.name} (${device.id})');
          
          // Save this device for future quick connections
          await saveKnownDevice(device.id.toString());
          
         // Listen to notifications on RX characteristic (cancel previous on reconnect)
         await rxCharacteristic!.setNotifyValue(true);
         
         // Request MTU increase for better performance
         try {
           int mtu = await device.requestMtu(512);
           print('MTU negotiated: $mtu');
           _log('info', 'MTU negotiated', details: 'MTU: $mtu');
         } catch (e) {
           print('MTU negotiation failed: $e');
           _log('warning', 'MTU negotiation failed', details: 'Error: $e');
         }
         
         _rxValueSubscription?.cancel();
         _rxValueSubscription = rxCharacteristic!.onValueReceived.listen((value) {
            _log('debug', 'Received data', details: 'Length: ${value.length} bytes');
            
            // Check if we're hitting MTU limits
            if (value.length >= 20) { // Close to typical BLE MTU
              // Large packet received - this is normal for chunked responses
            }
            
            try {
              // Try to parse as firmware protocol response
              Map<String, dynamic> response = FirmwareBinaryProtocol.parseResponse(Uint8List.fromList(value));
              _log('debug', 'Parsed response', details: response.toString());
              
              // Handle the parsed response
              _handleFirmwareResponse(response);
            } catch (e) {
              // Fallback: log parse error (legacy chunk path removed)
              if (value.isNotEmpty && value[0] == 0xAA) {
                print('BLE protocol parse error for 0xAA packet (${value.length} bytes): $e');
              } else {
                // Fallback to text processing
                String message = String.fromCharCodes(value);
                print('Received text: $message');
                _log('debug', 'Received text', details: message);
                // Old message handling removed - using firmware protocol now
              }
            }
          });
          
          // Send initialization command to get device state
          await Future.delayed(const Duration(milliseconds: 500));
          await sendGetStateCommand();
          
          // Send current time to ESP32 for synchronization
          await Future.delayed(const Duration(milliseconds: 200));
          await sendSetTimeCommand();
          
        } else {
          statusMessage = 'Required characteristics not found';
          await disconnect();
        }
      } else {
        statusMessage = 'Required service not found';
        print('ERROR: Our custom service not found!');
        print('Expected service: $serviceUuid');
        print('Available services:');
        for (BluetoothService service in services) {
          print('  - ${service.uuid.toString()}');
        }
        await disconnect();
      }
      
      notifyListeners();
    } catch (e) {
      statusMessage = 'Connection error: $e';
      notifyListeners();
    }
  }

  void _resetConnectionState() {
    // Cancel BLE stream subscriptions to prevent leaks on reconnect
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _rxValueSubscription?.cancel();
    _rxValueSubscription = null;
    
    // Check if we should auto-reconnect after OTA reboot
    final shouldAutoReconnect = _otaRebootPending;
    
    connectedDevice = null;
    txCharacteristic = null;
    rxCharacteristic = null;
    isConnected = false;
    statusMessage = 'disconnected'; // Key for localization
    lastCommandMessage = '';
    fileList.clear();
    currentPath = '/';
    _isWriting = false;
    _isCommandInProgress = false;
    _commandTimeout?.cancel();
    _commandTimeout = null;
    recordedRuntimeFiles.clear();
    detectedSignals.clear();
    
    // Reset recording and frequency searching state for all modules
    isRecording.clear();
    isRecording[0] = false;
    isRecording[1] = false;
    
    isFrequencySearching.clear();
    isFrequencySearching[0] = false;
    isFrequencySearching[1] = false;

    // Reset bruter state
    _resetBruterState();
    
    notifyListeners();
    
    // Schedule auto-reconnect after OTA reboot (device needs time to boot)
    if (shouldAutoReconnect) {
      _otaRebootPending = false;
      _scheduleOtaReconnect();
    }
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      try {
        _log('info', 'Disconnecting from device', details: 'Device: ${connectedDevice!.name}');
        await connectedDevice!.disconnect();
      } catch (e) {
        print('Disconnect error: $e');
        _log('error', 'Error during disconnect', details: 'Error: $e');
      }
    }
    
    // Reset all connection state
    _resetConnectionState();
    _log('info', 'Disconnected from device');
    isLoadingFiles = false;
    
    // Clear cache on disconnect
    _fileCache.clear();
    _cacheTimestamps.clear();
    
    // Old chunk buffer clearing removed - using firmware protocol now
    
    // Reset command state
    _isCommandInProgress = false;
    _lastCommandTime = null;
    
    // Cancel command timeout
    _cancelCommandTimeout();
    
    // Clear chunk buffers
    _clearChunkBuffers();
    
    notifyListeners();
  }
  
  /// Call BEFORE sending OTA_REBOOT command.
  /// Saves current version and sets flag for auto-reconnect after reboot.
  void notifyOtaReboot() {
    _otaPreRebootVersion = _firmwareVersion;
    _otaRebootPending = true;
    _log('info', 'OTA reboot pending — will auto-reconnect after disconnect');
  }
  
  /// Auto-reconnect after OTA reboot.
  /// Waits 5 seconds (device boot time), then attempts quickConnect.
  /// On success, verifies the firmware version changed.
  void _scheduleOtaReconnect() {
    _otaReconnectTimer?.cancel();
    statusMessage = 'otaRebooting'; // Device is rebooting
    notifyListeners();
    
    _log('info', 'Waiting 5 seconds for device to reboot...');
    
    _otaReconnectTimer = Timer(const Duration(seconds: 5), () async {
      _log('info', 'Attempting auto-reconnect after OTA reboot...');
      statusMessage = 'reconnecting';
      notifyListeners();
      
      try {
        await quickConnect();
        
        // After reconnect, check if firmware version changed
        if (isConnected && _otaPreRebootVersion != null) {
          // Wait a moment for getState response with version info
          await Future.delayed(const Duration(seconds: 2));
          
          if (_firmwareVersion.isNotEmpty && _firmwareVersion != _otaPreRebootVersion) {
            _log('info', 'OTA verification: firmware updated from $_otaPreRebootVersion to $_firmwareVersion');
            _notify('success', 'Firmware updated to v$_firmwareVersion');
          } else if (_firmwareVersion == _otaPreRebootVersion) {
            _log('warning', 'OTA verification: firmware version unchanged ($_firmwareVersion)');
            _notify('warning', 'Firmware version unchanged after OTA');
          }
        }
      } catch (e) {
        _log('error', 'Auto-reconnect failed: $e');
        statusMessage = 'reconnectFailed';
        notifyListeners();
      }
      
      _otaPreRebootVersion = null;
    });
  }
  
  // Clear known device (useful for troubleshooting)
  Future<void> clearKnownDevice() async {
    await _clearKnownDevice();
    statusMessage = 'Known device cleared. Next connection will scan for devices.';
    notifyListeners();
  }
  
  /// Send reboot command to device
  /// Device will disconnect and reboot. Auto-reconnect will be attempted if OTA was pending.
  Future<void> rebootDevice() async {
    if (!isConnected) {
      _notify('error', 'Device not connected');
      return;
    }
    
    try {
      _log('info', 'Sending reboot command to device');
      _notify('info', 'Rebooting device...');
      
      // Notify about pending OTA reboot if applicable
      notifyOtaReboot();
      
      // Send reboot command
      await sendCommand('REBOOT');
      
      // Wait a moment for disconnect to happen
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      _log('error', 'Failed to send reboot command: $e');
      _notify('error', 'Failed to reboot device');
    }
  }

  Future<void> sendCommand(String command) async {
    if (!isConnected || txCharacteristic == null) {
      statusMessage = 'Not connected';
      _log('error', 'Failed to send command: Not connected', details: 'Command: $command');
      notifyListeners();
      return;
    }
    
    // Send command directly (legacy text queue removed)
    await _sendCommandDirect(command);
  }
  
  Future<void> _sendCommandDirect(String command) async {
    // Wait for any ongoing write operation to complete
    while (_isWriting) {
      print('Waiting for previous BLE write to complete...');
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Check timeout between commands
    if (_lastCommandTime != null) {
      final timeSinceLastCommand = DateTime.now().difference(_lastCommandTime!);
      if (timeSinceLastCommand < _commandCooldown) {
        final remainingTime = _commandCooldown - timeSinceLastCommand;
        print('Command cooldown active, waiting: $command (${remainingTime.inMilliseconds}ms remaining)');
        await Future.delayed(remainingTime);
      }
    }
    
    _lastCommandTime = DateTime.now();
    
    print('Sending command: "$command" (length: ${command.length})');
    _log('command', 'Sent command: $command');
    
    try {
      _isWriting = true; // Set write flag
      
      // Convert command to firmware protocol
      Uint8List commandBytes = _convertCommandToFirmwareProtocol(command);
      print('Command bytes length: ${commandBytes.length}');
      print('Command bytes: ${commandBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Add timeout to BLE write
      await txCharacteristic!.write(commandBytes).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('BLE write timeout after 10 seconds');
        },
      );
      print('BLE write completed successfully');
      
      lastCommandMessage = 'Command sent: $command';
      // Don't update statusMessage for commands to avoid interfering with connection messages
      notifyListeners();
      
      // Start timeout for commands that expect a response
      if (_shouldWaitForResponse(command)) {
        _startCommandTimeout(command);
      }
    } catch (e) {
      print('BLE write failed: $e');
      statusMessage = 'Send error: $e';
      _log('error', 'Failed to send command', details: 'Command: $command, Error: $e');
      notifyListeners();
      rethrow; // Re-throw to be caught by queue processor
    } finally {
      _isWriting = false; // Always reset write flag
    }
  }

  // Checks whether a command should wait for a response
  bool _shouldWaitForResponse(String command) {
    // Commands that expect a response
    return command.startsWith('sd.list') || 
           command.startsWith('sd.info') ||
           command.startsWith('sd.read');
  }

  // Starts timeout for a command
  void _startCommandTimeout(String command) {
    _commandTimeout?.cancel();
    
    // Increase timeout for file list commands
    final timeoutDuration = command.startsWith('sd.list') 
        ? const Duration(seconds: 20) 
        : _commandTimeoutDuration;
    
    _commandTimeout = Timer(timeoutDuration, () {
      print('Command timeout: $command');
      _log('warning', 'Command timeout - no response received', details: 'Command: $command');
      
      // Reset file loading state
      if (isLoadingFiles) {
        isLoadingFiles = false;
        statusMessage = 'Command timeout - please try again';
        notifyListeners();
      }
    });
  }

  // Cancels command timeout (called when response is received)
  void _cancelCommandTimeout() {
    _commandTimeout?.cancel();
    _commandTimeout = null;
  }

  // Old binary packet processing removed - using firmware protocol now
  
  
  // Old binary data processing removed - using firmware protocol now
  
  // Old binary packet handling methods removed - using firmware protocol now
  // Old binary packet handling methods removed - using firmware protocol now
  
  
  




  // Old chunk data handling removed - using firmware protocol now
  
  // Old chunk timeout and assembly methods removed - using firmware protocol now

  // Old chunk end handling removed - using firmware protocol now
  
  // Old raw chunk data handling removed - using firmware protocol now

  // Old complete chunked data processing removed - using firmware protocol now

  // Old chunk cleanup removed - using firmware protocol now

  Future<void> refreshFileList({bool forceRefresh = false, int? pathType}) async {
    if (!isConnected) return;
    
    // Immediately block repeated presses
    if (isLoadingFiles) return;
    
    // Use currentPathType if pathType not specified
    int effectivePathType = pathType ?? currentPathType;
    
    // Check cache if not forced refresh
    if (!forceRefresh && _fileCache.containsKey(currentPath)) {
      fileList = List.from(_fileCache[currentPath]!);
      notifyListeners();
      return;
    }
    
    isLoadingFiles = true;
    notifyListeners();
    
    // Clear chunk buffers before new request
    _clearChunkBuffers();
    
    // Cancel previous timeout if exists
    _fileListTimeout?.cancel();
    
    // Set timeout for file list loading
    _fileListTimeout = Timer(_fileListTimeoutDuration, () {
      if (isLoadingFiles) {
        print('File list loading timeout');
        _log('warning', 'File list loading timeout', details: 'Path: $currentPath, PathType: $effectivePathType');
        isLoadingFiles = false;
        fileListProgress = 0.0;
        statusMessage = 'File list loading timeout - please try again';
        notifyListeners();
      }
    });
    
    // Use binary command with pathType (no need to escape quotes for binary protocol)
    print('refreshFileList: currentPath="$currentPath", pathType=$effectivePathType');
    final command = FirmwareBinaryProtocol.createGetFilesListCommand(currentPath, pathType: effectivePathType);
    await sendBinaryCommand(command);
  }

  Future<void> navigateToDirectory(String directoryName) async {
    if (!isConnected) return;
    
    // Immediately block repeated presses
    if (isLoadingFiles) return;
    
    print('Navigating to directory: "$directoryName"');
    print('Current path before navigation: "$currentPath"');
    
    // Update current path
    if (currentPath.endsWith('/')) {
      currentPath += directoryName;
    } else {
      currentPath += '/$directoryName';
    }
    
    // Ensure the path starts with /
    if (!currentPath.startsWith('/')) {
      currentPath = '/$currentPath';
    }
    
    print('New current path: "$currentPath"');
    
    // Check cache before loading
    if (_fileCache.containsKey(currentPath)) {
      fileList = List.from(_fileCache[currentPath]!);
      notifyListeners();
      return;
    }
    
    isLoadingFiles = true;
    notifyListeners();
    
    // Clear chunk buffers before new request
    _clearChunkBuffers();
    
    // Cancel previous timeout if exists
    _fileListTimeout?.cancel();
    
    // Set timeout for file list loading
    _fileListTimeout = Timer(_fileListTimeoutDuration, () {
      if (isLoadingFiles) {
        print('File list loading timeout in navigateToDirectory');
        _log('warning', 'File list loading timeout', details: 'Path: $currentPath');
        isLoadingFiles = false;
        fileListProgress = 0.0;
        statusMessage = 'File list loading timeout - please try again';
        notifyListeners();
      }
    });
    
    // Use binary command with pathType (no need to escape quotes for binary protocol)
    final command = FirmwareBinaryProtocol.createGetFilesListCommand(currentPath, pathType: currentPathType);
    await sendBinaryCommand(command);
  }

  Future<void> navigateUp() async {
    if (!isConnected) return;
    
    // Immediately block repeated presses
    if (isLoadingFiles) return;
    
    if (currentPath == '/' || currentPath.isEmpty) {
      return; // Already at root
    }
    
    // Remove the last path segment
    int lastSlash = currentPath.lastIndexOf('/');
    if (lastSlash > 0) {
      currentPath = currentPath.substring(0, lastSlash);
    } else {
      currentPath = '/';
    }
    
    // Check cache before loading
    if (_fileCache.containsKey(currentPath)) {
      fileList = List.from(_fileCache[currentPath]!);
      notifyListeners();
      return;
    }
    
    isLoadingFiles = true;
    notifyListeners();
    
    // Clear chunk buffers before new request
    _clearChunkBuffers();
    
    // Cancel previous timeout if exists
    _fileListTimeout?.cancel();
    
    // Set timeout for file list loading
    _fileListTimeout = Timer(_fileListTimeoutDuration, () {
      if (isLoadingFiles) {
        print('File list loading timeout in navigateUp');
        _log('warning', 'File list loading timeout', details: 'Path: $currentPath');
        isLoadingFiles = false;
        fileListProgress = 0.0;
        statusMessage = 'File list loading timeout - please try again';
        notifyListeners();
      }
    });
    
    // Use binary command with pathType (no need to escape quotes for binary protocol)
    final command = FirmwareBinaryProtocol.createGetFilesListCommand(currentPath, pathType: currentPathType);
    await sendBinaryCommand(command);
  }

  /// Switch to a different path type (directory)
  Future<void> switchPathType(int pathType) async {
    if (pathType < 0 || pathType > 5) {
      _log('error', 'Invalid pathType', details: 'pathType must be 0-5, got $pathType');
      return;
    }
    
    currentPathType = pathType;
    currentPath = '/'; // Reset to root of the selected directory
    
    // Clear cache for old path
    _fileCache.clear();
    _cacheTimestamps.clear();
    
    // Refresh file list for new path type
    await refreshFileList(forceRefresh: true);
  }

  /// Clear file cache
  void clearFileCache() {
    _fileCache.clear();
    _cacheTimestamps.clear();
    _log('info', 'File cache cleared');
    notifyListeners();
  }

  /// Invalidate cache for a specific path
  void invalidateCacheForPath(String path) {
    if (_fileCache.containsKey(path)) {
      _fileCache.remove(path);
      _cacheTimestamps.remove(path);
      _log('info', 'Cache invalidated for path: $path');
    }
  }

  /// Get directory path from full file path
  String _getDirectoryPath(String filePath) {
    if (filePath.isEmpty || filePath == '/') {
      return '/';
    }
    // Remove leading slash if present
    String normalizedPath = filePath.startsWith('/') ? filePath.substring(1) : filePath;
    // Find last slash
    int lastSlashIndex = normalizedPath.lastIndexOf('/');
    if (lastSlashIndex == -1) {
      return '/';
    }
    // Return directory path with leading slash
    return '/${normalizedPath.substring(0, lastSlashIndex)}';
  }

  /// Extract relative path from full path (removes base directory like /DATA/RECORDS)
  String _extractRelativePath(String fullPath, int pathType) {
    if (fullPath.isEmpty) return '/';
    
    // Base paths for each pathType
    const basePaths = [
      '/DATA/RECORDS',  // 0
      '/DATA/SIGNALS',  // 1
      '/DATA/PRESETS',  // 2
      '/DATA/TEMP',     // 3
      '/',              // 4
      '/',              // 5
    ];
    
    if (pathType < 0 || pathType >= basePaths.length) {
      return '/';
    }
    
    String basePath = basePaths[pathType];
    
    // Remove base path prefix
    if (fullPath.startsWith(basePath)) {
      String relative = fullPath.substring(basePath.length);
      // If relative is empty or just a slash, it's root
      if (relative.isEmpty || relative == '/') {
        return '/';
      }
      // Ensure it starts with /
      if (!relative.startsWith('/')) {
        relative = '/$relative';
      }
      // Get directory path (remove filename)
      return _getDirectoryPath(relative);
    }
    
    // If base path not found, try to extract relative path anyway
    return _getDirectoryPath(fullPath);
  }

  /// Reset file loading state (useful for recovery from hang)
  void resetFileLoadingState() {
    _fileListTimeout?.cancel();
    _fileListTimeout = null;
    isLoadingFiles = false;
    fileListProgress = 0.0;
    _clearChunkBuffers();
    _log('info', 'File loading state reset');
    notifyListeners();
  }

  // Getter for chunk loading progress (old variables removed)
  double get chunkProgress {
    return 0.0; // Old chunk progress removed
  }
  
  // Check if chunks are being loaded (old variables removed)
  bool get isChunking {
    return false; // Old chunking removed
  }
  
  // Getter for total file count in directory
  int get totalFilesInDirectory => _streamingTotalFiles;
  
  // Getter for saved device
  String? get savedDeviceId => _knownDeviceId;
  String get savedDeviceName => _knownDeviceId != null ? 'EvilCrow_RF2' : '';

  // Methods for working with files
  
  /// Reads file content from ESP
  Future<String> readFileContent(String filePath, {String? basePath}) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }
    
    // Determine pathType based on basePath
    int pathType = 0;  // Default to /DATA/RECORDS
    String relativePath = filePath;
    
    if (basePath == '/DATA/SIGNALS') {
      pathType = 1;
    } else if (basePath == '/DATA/PRESETS') {
      pathType = 2;
    } else if (basePath == '/DATA/TEMP') {
      pathType = 3;
    } else if (basePath == '/SDROOT') {
      pathType = 5;
    } else if (basePath == '/') {
      pathType = 4; // LittleFS internal storage
    }
    
    // Remove /DATA/ prefix if present (shouldn't be, but handle it)
    if (relativePath.startsWith('/DATA/')) {
      relativePath = relativePath.substring(6); // Remove '/DATA/'
    }
    
    // Remove leading slash if present
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.substring(1);
    }
    
    _log('INFO', 'Reading file content: $relativePath (pathType: $pathType, basePath: $basePath)');
    
    // Set loading flag
    isLoadingFileContent = true;
    fileContentProgress = 0.0;
    notifyListeners();
    
    // Clear previous state
    _currentFileContent = null;
    _pendingFileReadCompleter?.completeError('New file read started');
    final completer = Completer<String>();
    _pendingFileReadCompleter = completer;
    
    // Use binary command with path type - pass full relative path including subdirectory
    final command = FirmwareBinaryProtocol.createLoadFileDataCommand(relativePath, pathType: pathType);
    _log('INFO', 'Sending binary command for file: $relativePath (pathType: $pathType, command length: ${command.length})');
    
    // Send binary file read command
    await sendBinaryCommand(command);
    
    // Set timeout
    Timer timeout = Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        _log('ERROR', 'Timeout reading file: $filePath');
        completer.completeError('Timeout reading file');
        _pendingFileReadCompleter = null;
        isLoadingFileContent = false;
        fileContentProgress = 0.0;
        notifyListeners();
      }
    });
    
    try {
      final result = await completer.future;
      return result;
    } finally {
      timeout.cancel();
      _pendingFileReadCompleter = null;
      _currentFileContent = null;
      isLoadingFileContent = false;
      fileContentProgress = 0.0;
      notifyListeners();
    }
  }
  
  /// Downloads file from ESP with progress (uses binary protocol)
  Future<String?> downloadFile(
    String filePath, {
    Function(double progress)? onProgress,
  }) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }
    
    _log('INFO', 'Downloading file: $filePath');
    
    // Using readFileContent, which already uses binary protocol
    // Determine pathType based on current path
    try {
      final basePath = _getBasePathForPathType(currentPathType);
      final content = await readFileContent(filePath, basePath: basePath);
      
      // Call progress callback if available
      onProgress?.call(1.0);
      
      return content;
    } catch (e) {
      _log('ERROR', 'Error downloading file: $e');
      rethrow;
    }
  }
  
  /// Gets base path for pathType
  String? _getBasePathForPathType(int pathType) {
    switch (pathType) {
      case 0:
        return '/DATA/RECORDS';
      case 1:
        return '/DATA/SIGNALS';
      case 2:
        return '/DATA/PRESETS';
      case 3:
        return '/DATA/TEMP';
      case 4:
        return '/';
      case 5:
        return '/SDROOT';
      default:
        return '/';
    }
  }
  
  /// Clears chunk buffers
  /// [clearStreamingBuffer] - if true, also clears streaming buffers (default true)
  void _clearChunkBuffers({bool clearStreamingBuffer = true}) {
    _chunkData.clear();
    _expectedChunks.clear();
    _receivedChunks.clear();
    _chunkStartTimes.clear();
    _chunkLastReceived.clear();
    // Clear streaming file list buffer only if explicitly requested
    // Don't clear during active streaming to prevent data loss
    if (clearStreamingBuffer) {
      _streamingFileBuffer.clear();
      _isStreamingFileList = false;
      _streamingTotalFiles = 0;
    }
  }
  
  /// Clears stale chunk buffers (older than _chunkTimeout or if chunks stop arriving)
  /// Does NOT clear streaming buffers - they are managed separately
  void _cleanupStaleChunkBuffers() {
    final now = DateTime.now();
    final staleChunkIds = <int>[];
    
    for (var chunkId in _chunkStartTimes.keys) {
      final startTime = _chunkStartTimes[chunkId]!;
      final age = now.difference(startTime);
      
      // Check if buffer is too old (overall timeout)
      if (age > _chunkTimeout) {
        staleChunkIds.add(chunkId);
        continue;
      }
      
      // Check if chunks haven't been received recently (stale after initial creation)
      if (_chunkLastReceived.containsKey(chunkId)) {
        final lastReceived = _chunkLastReceived[chunkId]!;
        final timeSinceLastChunk = now.difference(lastReceived);
        
        // If no chunks received for a while, consider stale
        if (timeSinceLastChunk > _chunkStaleTimeout) {
          final received = _receivedChunks[chunkId] ?? <int>{};
          final expected = _expectedChunks[chunkId] ?? 0;
          
          // Only mark as stale if we're missing chunks (not just waiting)
          if (received.length < expected) {
            staleChunkIds.add(chunkId);
          }
        }
      }
    }
    
    if (staleChunkIds.isNotEmpty) {
      print('Cleaning up ${staleChunkIds.length} stale chunk buffers: $staleChunkIds');
      for (var chunkId in staleChunkIds) {
        _chunkData.remove(chunkId);
        _expectedChunks.remove(chunkId);
        _receivedChunks.remove(chunkId);
        _chunkStartTimes.remove(chunkId);
        _chunkLastReceived.remove(chunkId);
      }
    }
  }
  
  // Callback functions for chunks (will be set temporarily)
  Function(int sessionId, String data)? _onChunkComplete;
  Function(int sessionId, double progress)? _onChunkProgress;
  
  // Chunked response handling for firmware protocol
  final Map<int, Map<int, Uint8List>> _chunkData = {}; // chunkId -> chunkNumber -> data (allows overwriting duplicates)
  final Map<int, int> _expectedChunks = {}; // chunkId -> total chunks expected
  final Map<int, Set<int>> _receivedChunks = {}; // chunkId -> set of received chunk numbers
  final Map<int, DateTime> _chunkStartTimes = {}; // chunkId -> timestamp when chunk buffer was created
  final Map<int, DateTime> _chunkLastReceived = {}; // chunkId -> timestamp when last chunk was received
  static const Duration _chunkTimeout = Duration(seconds: 3); // Timeout for stale chunk buffers
  static const Duration _chunkStaleTimeout = Duration(milliseconds: 500); // Timeout if chunks arrive out of order
  
  // Callback for JSON responses
  Function(dynamic jsonData)? _onJsonReceived;

  /// Convert text command to firmware binary protocol
  Uint8List _convertCommandToFirmwareProtocol(String command) {
    print('Converting command to enhanced protocol: "$command"');
    
    // Parse command and convert to appropriate firmware protocol
    if (command == 'getState') {
      return FirmwareBinaryProtocol.createGetStateCommand();
    } else if (command.startsWith('scan')) {
      // Parse scan command: "scan <minRssi> <module>"
      List<String> parts = command.split(' ');
      if (parts.length >= 3) {
        int minRssi = int.tryParse(parts[1]) ?? -100;
        int module = int.tryParse(parts[2]) ?? 0;
        return FirmwareBinaryProtocol.createRequestScanCommand(minRssi, module);
      }
      return FirmwareBinaryProtocol.createRequestScanCommand(-100, 0);
    } else if (command.startsWith('idle')) {
      // Parse idle command: "idle <module>"
      List<String> parts = command.split(' ');
      if (parts.length >= 2) {
        int module = int.tryParse(parts[1]) ?? 0;
        return FirmwareBinaryProtocol.createRequestIdleCommand(module);
      }
      return FirmwareBinaryProtocol.createRequestIdleCommand(0);
    } else if (command.startsWith('sd.list')) {
      // Parse list command: "sd.list <path>" or "sd.list "<path>""
      String path = command.substring(7).trim();
      
      // Remove quotes if present
      if (path.startsWith('"') && path.endsWith('"')) {
        path = path.substring(1, path.length - 1);
      }
      
      if (path.isEmpty || path == '/') path = ''; // Don't send '/' prefix
      print('Creating getFilesList command for path: "$path" with pathType: $currentPathType');
      // Use currentPathType instead of hardcoded 0 - ensures all storage types work correctly
      return FirmwareBinaryProtocol.createGetFilesListCommand(path, pathType: currentPathType);
    } else if (command.startsWith('sd.read')) {
      // Parse read command: "sd.read <path>"
      String path = command.substring(7).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createLoadFileDataCommand(path);
    } else if (command.startsWith('sd.mkdir')) {
      // Parse mkdir command: "sd.mkdir <path>"
      String path = command.substring(8).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createCreateDirectoryCommand(path);
    } else if (command.startsWith('sd.rm')) {
      // Parse remove command: "sd.rm <path>"
      String path = command.substring(6).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createRemoveFileCommand(path);
    } else if (command.startsWith('sd.mv')) {
      // Parse move command: "sd.mv <from> <to>"
      List<String> parts = command.split(' ');
      if (parts.length >= 3) {
        String fromPath = parts[1];
        String toPath = parts[2];
        if (fromPath.startsWith('/')) fromPath = fromPath.substring(1); // Remove leading '/'
        if (toPath.startsWith('/')) toPath = toPath.substring(1); // Remove leading '/'
        return FirmwareBinaryProtocol.createRenameFileCommand(fromPath, toPath);
      }
    } else if (command.startsWith('tx.file')) {
      // Parse transmit from file command: "tx.file <path>"
      String path = command.substring(7).trim();
      if (path.startsWith('/')) path = path.substring(1); // Remove leading '/'
      return FirmwareBinaryProtocol.createTransmitFromFileCommand(path);
    } else if (command.startsWith('tx.bin')) {
      // Parse transmit binary command: "tx.bin <frequency> <pulseDuration> <data>"
      List<String> parts = command.split(' ');
      if (parts.length >= 4) {
        double frequency = double.tryParse(parts[1]) ?? 433.92;
        int pulseDuration = int.tryParse(parts[2]) ?? 100;
        String data = parts.sublist(3).join(' ');
        return FirmwareBinaryProtocol.createTransmitBinaryCommand(frequency, pulseDuration, data);
      }
    } else if (command == 'REBOOT') {
      return FirmwareBinaryProtocol.createRebootCommand();
    }
    
    // Default: send as getState command
    print('Unknown command, defaulting to getState');
    return FirmwareBinaryProtocol.createGetStateCommand();
  }

  /// Handle firmware protocol responses
  void _handleFirmwareResponse(Map<String, dynamic> response) {
    int packetType = response['packetType'] ?? 0;
    int chunkId = response['chunkId'] ?? 0;
    int chunkNumber = response['chunkNumber'] ?? 0;
    int totalChunks = response['totalChunks'] ?? 1;
    bool isChunked = response['isChunked'] ?? false;
    bool isLastChunk = response['isLastChunk'] ?? false;
    bool isBinary = response['isBinary'] ?? false;
    Uint8List? payloadBytes = response['payloadBytes'];
    String payloadString = response['payload'] ?? '';
    
    _log('debug', 'Handling firmware response', details: 'PacketType: $packetType, Chunked: $isChunked, totalChunks: $totalChunks, Binary: $isBinary');
    
    // CRITICAL: Always check totalChunks > 1, not just isChunked flag
    // This ensures chunked messages are never processed as single messages
    if (totalChunks > 1) {
      print('Processing as chunked: chunkId=$chunkId, chunkNumber=$chunkNumber, totalChunks=$totalChunks, isLastChunk=$isLastChunk');
      _handleChunkedResponse(chunkId, chunkNumber, totalChunks, isLastChunk, isBinary, payloadBytes, payloadString);
    } else {
      // Single packet - handle directly
      // Check if this is a system message that should be processed even with active chunk buffers
      bool isSystemMessage = false;
      bool isFileListMessage = false;
      
      if (isBinary && payloadBytes != null && payloadBytes.isNotEmpty) {
        // Binary system messages: Heartbeat is 0x82, Status is 0x81, FileList is 0xA1
        int messageType = payloadBytes[0];
        isSystemMessage = (messageType == 0x82 || messageType == 0x81);
        isFileListMessage = (messageType == 0xA1);
      } else if (!isBinary && payloadString.isNotEmpty) {
        // JSON system messages: Check if it's a system notification (SignalRecorded, SignalDetected, etc.)
        // These should be processed even with active chunk buffers
        try {
          // Quick check without full parsing to avoid overhead
          if (payloadString.contains('"type":"SignalRecorded"') ||
              payloadString.contains('"type":"SignalDetected"') ||
              payloadString.contains('"type":"SignalRecordError"') ||
              payloadString.contains('"type":"SignalSent"') ||
              payloadString.contains('"type":"SignalSendingError"') ||
              payloadString.contains('"type":"ModeSwitch"') ||
              payloadString.contains('"type":"State"') ||
              payloadString.contains('"action":"list"')) {
            isSystemMessage = true;
            if (payloadString.contains('"action":"list"')) {
              isFileListMessage = true;
            }
          }
        } catch (e) {
          // If check fails, continue with normal processing
        }
      }
      
      // Additional safety: check if we have active chunk buffers (shouldn't happen for single packet)
      // Exception: system messages and file list messages should be processed even with active chunk buffers
      // File list messages can arrive as separate single packets during streaming
      if (_chunkData.isNotEmpty && !isSystemMessage && !isFileListMessage) {
        // Clean up stale chunk buffers first - they might be blocking new messages
        _cleanupStaleChunkBuffers();
        
        // Double-check: if buffers exist but are very old (>300ms), they're probably stuck
        // Also clean ALL buffers missing chunk 1 (chunk 1 is required for completion)
        final now = DateTime.now();
        final stuckBuffers = <int>[];
        for (var chunkId in _chunkData.keys) {
          bool shouldClean = false;
          
          if (_chunkStartTimes.containsKey(chunkId)) {
            final age = now.difference(_chunkStartTimes[chunkId]!);
            // Clean if buffer is old
            if (age > const Duration(milliseconds: 300)) {
              shouldClean = true;
            }
          }
          
          // CRITICAL: Always clean buffers missing chunk 1 (required for multi-chunk messages)
          // If chunk 1 is missing, the message can never be completed
          if (!shouldClean && _receivedChunks.containsKey(chunkId)) {
            if (!_receivedChunks[chunkId]!.contains(1)) {
              final expected = _expectedChunks[chunkId] ?? 0;
              if (expected > 1) { // Only for multi-chunk messages
                // Clean immediately - chunk 1 is required and if it hasn't arrived yet,
                // it's likely lost (especially if we're receiving other messages)
                shouldClean = true;
              }
            }
          }
          
          if (shouldClean) {
            stuckBuffers.add(chunkId);
          }
        }
        
        if (stuckBuffers.isNotEmpty) {
          print('Cleaning up ${stuckBuffers.length} stuck chunk buffers (old or missing chunk 1): $stuckBuffers');
          for (var chunkId in stuckBuffers) {
            _chunkData.remove(chunkId);
            _expectedChunks.remove(chunkId);
            _receivedChunks.remove(chunkId);
            _chunkStartTimes.remove(chunkId);
            _chunkLastReceived.remove(chunkId);
          }
        }
        
        // If buffers are still active after aggressive cleanup, ignore this single packet
        // Exception: file list messages should be processed even with active chunk buffers
        // because they arrive as separate single packets during streaming
        if (_chunkData.isNotEmpty && !isFileListMessage) {
          print('WARNING: Received single packet (totalChunks=1) but chunk buffers are active (${_chunkData.keys.toList()}), ignoring to avoid processing incomplete data');
          return;
        }
      }
      
      if (isBinary && payloadBytes != null) {
        _handleBinaryMessage(payloadBytes);
      } else {
        _handleSingleResponse(payloadString);
      }
    }
  }
  
  /// Handle chunked responses from firmware protocol
  void _handleChunkedResponse(int chunkId, int chunkNumber, int totalChunks, bool isLastChunk, bool isBinary, Uint8List? payloadBytes, String payloadString) {
    int payloadLength = isBinary ? (payloadBytes?.length ?? 0) : payloadString.length;
    
    // Clean up stale chunk buffers periodically
    _cleanupStaleChunkBuffers();
    
    // Initialize chunk storage if needed
    final now = DateTime.now();
    if (!_chunkData.containsKey(chunkId)) {
      _chunkData[chunkId] = <int, Uint8List>{};
      _expectedChunks[chunkId] = totalChunks;
      _receivedChunks[chunkId] = <int>{};
      _chunkStartTimes[chunkId] = now;
      _chunkLastReceived[chunkId] = now;
      print('Initialized chunk buffer for chunkId $chunkId, expecting $totalChunks chunks');
    } else {
      // Update last received time
      _chunkLastReceived[chunkId] = now;
    }
    
    // Check if chunk arrives out of order (e.g., chunk 2/2 before chunk 1/2)
    // If we're missing chunk 1 and this is chunk 2+, check if we should wait or cleanup
    if (chunkNumber > 1 && !_receivedChunks[chunkId]!.contains(1)) {
      final bufferAge = now.difference(_chunkStartTimes[chunkId]!);
      // If buffer is older than 100ms and we're missing chunk 1, it's likely lost
      // Reduced from 200ms to be more aggressive - BLE chunks should arrive within 100ms
      if (bufferAge > const Duration(milliseconds: 100)) {
        print('WARNING: Chunk $chunkNumber/$totalChunks arrived for chunkId $chunkId but chunk 1 is missing (buffer age: ${bufferAge.inMilliseconds}ms), cleaning up stale buffer');
        _chunkData.remove(chunkId);
        _expectedChunks.remove(chunkId);
        _receivedChunks.remove(chunkId);
        _chunkStartTimes.remove(chunkId);
        _chunkLastReceived.remove(chunkId);
        // Don't process this chunk - it's incomplete without chunk 1
        return;
      } else {
        print('INFO: Chunk $chunkNumber/$totalChunks arrived for chunkId $chunkId but chunk 1 is not yet received (may arrive out of order, age: ${bufferAge.inMilliseconds}ms)');
      }
    }
    
    // Handle duplicate chunks: overwrite data (safe since data is identical)
    // This handles BLE stack retransmissions gracefully
    bool isDuplicate = _receivedChunks[chunkId]!.contains(chunkNumber);
    
    if (isDuplicate) {
      print('INFO: Duplicate chunk $chunkNumber/$totalChunks for chunkId $chunkId, overwriting (BLE retransmission)');
    } else {
      // Mark chunk as received only if it's new
      _receivedChunks[chunkId]!.add(chunkNumber);
    }
    
    // Store chunk data by chunk number (allows overwriting duplicates)
    Uint8List chunkBytes;
    if (isBinary && payloadBytes != null) {
      chunkBytes = payloadBytes;
    } else {
      chunkBytes = Uint8List.fromList(utf8.encode(payloadString));
    }
    
    // Overwrite if duplicate (safe - data is identical)
    _chunkData[chunkId]![chunkNumber] = chunkBytes;
    
    // Update progress for file list or file content loading
    if (totalChunks > 1) {
      double progress = _receivedChunks[chunkId]!.length / totalChunks;
      if (isLoadingFiles) {
        fileListProgress = progress;
        notifyListeners();
      } else if (isLoadingFileContent) {
        fileContentProgress = progress;
        notifyListeners();
      }
    }
    
    
    // Check if we have all chunks
    if (_receivedChunks[chunkId]!.length == totalChunks) {
      // Rebuild complete message from chunks in order
      BytesBuilder completeBuilder = BytesBuilder();
      for (int i = 1; i <= totalChunks; i++) {
        if (_chunkData[chunkId]!.containsKey(i)) {
          completeBuilder.add(_chunkData[chunkId]![i]!);
        } else {
          print('ERROR: Missing chunk $i/$totalChunks for chunkId $chunkId');
          return; // Don't process incomplete data
        }
      }
      
      // CRITICAL: Clean up chunk storage BEFORE processing to avoid false positives in _handleBinaryMessage
      // Save data and remove from active buffers first
      Uint8List completeBytes = completeBuilder.toBytes();
      _chunkData.remove(chunkId);
      _expectedChunks.remove(chunkId);
      _receivedChunks.remove(chunkId);
      _chunkStartTimes.remove(chunkId);
      _chunkLastReceived.remove(chunkId);
      
      // Process complete chunked response
      // Check if binary message (first byte >= 0x80)
      if (completeBytes.isNotEmpty && completeBytes[0] >= 0x80) {
        _handleBinaryMessage(completeBytes);
      } else {
        // Text message - decode as UTF-8 and parse as JSON
        try {
          String completeData = utf8.decode(completeBytes);
          dynamic jsonData = jsonDecode(completeData);
          _handleCompleteResponse(jsonData);
        } catch (e) {
          String completeData = utf8.decode(completeBytes, allowMalformed: true);
          _handleCompleteResponse(completeData);
        }
      }
    }
  }
  
  /// Handle single (non-chunked) responses
  void _handleSingleResponse(String payload) {
    print('Handling single response: ${payload.substring(0, payload.length > 100 ? 100 : payload.length)}${payload.length > 100 ? '...' : ''}');
    
    // CRITICAL: Check if this might be part of a chunked message first
    // If we have active chunk buffers, check if this is a system message
    if (_chunkData.isNotEmpty) {
      // Check if this is a system notification that should be processed
      bool isSystemNotification = false;
      try {
        if (payload.contains('"type":"SignalRecorded"') ||
            payload.contains('"type":"SignalDetected"') ||
            payload.contains('"type":"SignalRecordError"') ||
            payload.contains('"type":"SignalSent"') ||
            payload.contains('"type":"SignalSendingError"') ||
            payload.contains('"type":"ModeSwitch"') ||
            payload.contains('"type":"State"')) {
          isSystemNotification = true;
        }
      } catch (e) {
        // If check fails, treat as non-system
      }
      
      if (!isSystemNotification) {
        print('WARNING: Received single response while chunk buffers are active, ignoring to avoid processing incomplete data');
        return;
      } else {
        print('INFO: Processing system notification even with active chunk buffers');
      }
    }
    
    // BINARY MESSAGE CHECK: Check if this is a binary message (0x80-0xFF)
    if (payload.isNotEmpty) {
      final firstByte = payload.codeUnitAt(0);
      if (firstByte >= 0x80) {
        print('Detected binary message: 0x${firstByte.toRadixString(16)}');
        _handleBinaryMessage(Uint8List.fromList(payload.codeUnits));
        return;
      }
    }
    
    try {
      // Try to parse as JSON
      dynamic jsonData = jsonDecode(payload);
      _handleCompleteResponse(jsonData);
    } catch (e) {
      // Handle as plain text - check if it looks like JSON
      if (payload.trim().startsWith('{') && payload.trim().endsWith('}')) {
        // Try to extract type manually from plain text
        if (payload.contains('"type":"ModeSwitch"')) {
          try {
            // Try to extract just the data part
            int dataStart = payload.indexOf('"data":');
            if (dataStart != -1) {
              String dataPart = payload.substring(dataStart + 7); // Skip '"data":'
              if (dataPart.startsWith('{')) {
                // Find matching closing brace
                int braceCount = 0;
                int endIndex = -1;
                for (int i = 0; i < dataPart.length; i++) {
                  if (dataPart[i] == '{') braceCount++;
                  if (dataPart[i] == '}') {
                    braceCount--;
                    if (braceCount == 0) {
                      endIndex = i;
                      break;
                    }
                  }
                }
                if (endIndex != -1) {
                  String dataJson = dataPart.substring(0, endIndex + 1);
                  Map<String, dynamic> modeData = jsonDecode(dataJson);
                  _handleModeSwitch(modeData);
                  return;
                }
              }
            }
          } catch (e2) {
            print('Manual parsing failed: $e2');
          }
        }
      }
      // Fallback to plain text handling
      print('Plain text response: $payload');
      _log('info', 'Plain text response received', details: payload);
    }
  }
  
  /// Handle complete responses (both chunked and single)
  void _handleCompleteResponse(dynamic data) {
    print('_handleCompleteResponse called with data type: ${data.runtimeType}');
    if (data is Map) {
      String type = data['type'] ?? 'unknown';
      print('Processing response type: $type');
      
      switch (type) {
        case 'state':
        case 'State':
          _handleStateResponse(data.cast<String, dynamic>());
          break;
        case 'SignalDetected':
          _handleSignalDetectedResponse(data);
          break;
        case 'SignalRecorded':
          _handleSignalRecordedResponse(data);
          break;
        case 'SignalRecordError':
          _handleSignalRecordErrorResponse(data);
          break;
        case 'SignalSent':
          _handleSignalSentResponse(data);
          break;
        case 'SignalSendingError':
          _handleSignalSendingErrorResponse(data);
          break;
        case 'ModeSwitch':
          _handleModeSwitch(data['data']);
          break;
        case 'FileSystem':
          _handleFileSystemResponse(data);
          break;
        case 'DirectoryTree':
          _handleFileSystemResponse(data); // DirectoryTree also goes through FileSystem handler
          break;
        case 'file_data':
          _handleFileDataResponse(data);
          break;
        case 'FileUpload':
          _handleFileUploadResponse(data);
          break;
        case 'scan_result':
          _handleScanResult(data);
          break;
        case 'files_list':
          _handleFilesListResponse(data);
          break;
        case 'error':
        case 'Error':
          _handleErrorResponse(data);
          break;
        case 'notification':
          _handleNotification(data);
          break;
        case 'BruterProgress':
          _handleBruterProgress(data['data']);
          break;
        case 'BruterComplete':
          _handleBruterComplete(data['data']);
          break;
        case 'BruterPaused':
          _handleBruterPaused(data['data']);
          break;
        case 'BruterResumed':
          _handleBruterResumed(data['data']);
          break;
        case 'BruterStateAvail':
          _handleBruterStateAvail(data['data']);
          break;
        case 'SettingsSync':
          _handleSettingsSync(data['data']);
          break;
        case 'VersionInfo':
          _handleVersionInfo(data['data']);
          break;
        case 'DeviceName':
          _handleDeviceName(data['data']);
          break;
        case 'BatteryStatus':
          _handleBatteryStatus(data['data']);
          break;
        case 'HwButtonStatus':
          _handleHwButtonStatus(data['data']);
          break;
        case 'SdStatus':
          _handleSdStatus(data['data']);
          break;
        case 'NrfModuleStatus':
          _handleNrfModuleStatus(data['data']);
          break;
        // ── NRF24 notifications ──
        case 'NrfDeviceFound':
          final d = data['data'] as Map?;
          if (d != null) {
            nrfTargets.add({
              'deviceType': d['deviceType'] ?? 0,
              'channel': d['channel'] ?? 0,
              'address': d['address'] ?? [],
            });
          }
          _log('info', 'NRF device found', details: d.toString());
          notifyListeners();
          break;
        case 'NrfAttackComplete':
          nrfAttacking = false;
          _log('info', 'NRF attack complete', details: data['data'].toString());
          _notify('info', 'NRF attack finished');
          notifyListeners();
          break;
        case 'NrfScanComplete':
          nrfScanning = false;
          _log('info', 'NRF scan complete', details: data['data'].toString());
          _notify('info', 'MouseJack scan finished');
          notifyListeners();
          break;
        case 'NrfScanStatus':
          final d = data['data'] as Map?;
          if (d != null && d['targets'] is List) {
            nrfTargets = List<Map<String, dynamic>>.from(d['targets']);
          }
          _log('debug', 'NRF scan status', details: d.toString());
          notifyListeners();
          break;
        case 'NrfSpectrumData':
          final d = data['data'] as Map?;
          if (d != null && d['levels'] is List) {
            nrfSpectrumLevels = List<int>.from(d['levels']);
          }
          // High-frequency update — no log, just notify UI
          notifyListeners();
          break;
        case 'NrfJamStatus':
          final d = data['data'] as Map?;
          if (d != null) {
            nrfJammerRunning = d['running'] == true;
            nrfJamMode = d['mode'] ?? 0;
            nrfJamDwellTimeMs = d['dwellTimeMs'] ?? 0;
            nrfJamChannel = d['channel'] ?? 0;
          }
          _log('debug', 'NRF jam status', details: d.toString());
          notifyListeners();
          break;
        case 'NrfJamModeConfig':
          final d = data['data'] as Map<String, dynamic>?;
          if (d != null) {
            int cfgMode = d['mode'] ?? 0;
            nrfJamModeConfigs[cfgMode] = d;
          }
          _log('debug', 'NRF jam mode config', details: d.toString());
          notifyListeners();
          break;
        case 'NrfJamModeInfo':
          final d = data['data'] as Map<String, dynamic>?;
          if (d != null) {
            int infoMode = d['mode'] ?? 0;
            nrfJamModeInfos[infoMode] = d;
          }
          _log('debug', 'NRF jam mode info', details: d.toString());
          notifyListeners();
          break;
        case 'SdrStatus':
          final d = data['data'] as Map?;
          if (d != null) {
            sdrModeActive = d['active'] == true;
            sdrFrequencyMHz = (d['freqKhz'] ?? 433920) / 1000.0;
            sdrModulation = d['modulation'] ?? 2;
          }
          _log('info', 'SDR mode ${sdrModeActive ? "ON" : "OFF"}',
               details: d.toString());
          notifyListeners();
          break;
        // ── OTA notifications ──
        case 'OtaProgress':
          final d = data['data'] as Map?;
          otaProgress = d?['percentage'] ?? 0;
          otaBytesWritten = d?['bytesWritten'] ?? 0;
          _log('debug', 'OTA progress', details: '$otaProgress%');
          notifyListeners();
          break;
        case 'OtaComplete':
          otaComplete = true;
          _log('info', 'OTA complete');
          _notify('success', 'Firmware update complete!');
          notifyListeners();
          break;
        case 'OtaError':
          otaErrorMessage = data['data']?['message'] ?? 'Unknown error';
          _log('error', 'OTA error', details: otaErrorMessage ?? '');
          _notify('error', 'OTA error: $otaErrorMessage');
          notifyListeners();
          break;
        case 'CommandResult':
          // Generic command result - no special handling needed
          break;
        default:
          print('Unknown response type: $type');
          _log('warning', 'Unknown response type', details: 'Type: $type, Data: $data');
      }
    } else {
      // Handle plain text responses
      print('Plain text response: $data');
      _log('info', 'Plain text response received', details: data.toString());
    }
  }


  /// Handle scan result
  void _handleScanResult(dynamic data) {
    print('Scan result: $data');
    _log('info', 'Scan result received', details: data.toString());
    // Update scan results in UI
    notifyListeners();
  }

  /// Handle files list response
  void _handleFilesListResponse(dynamic data) {
    print('Files list response: $data');
    _log('info', 'Files list received', details: data.toString());
    
    if (data is List) {
      fileList.clear();
      for (var item in data) {
        if (item is Map) {
          fileList.add(FileItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      notifyListeners();
    }
  }

  /// Handle file data response
  void _handleFileDataResponse(dynamic data) {
    print('File data response: $data');
    _log('info', 'File data received', details: data.toString());
    
    // Handle file content response
    if (data is Map<String, dynamic>) {
      if (data.containsKey('content')) {
        String fileContent = data['content'];
        print('File content received via file_data, length: ${fileContent.length}');
        
        // Store the file content for the current file reading operation
        _currentFileContent = fileContent;
        
        // If we have a pending file reading operation, complete it
        if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
          _pendingFileReadCompleter!.complete(fileContent);
          _pendingFileReadCompleter = null;
        }
      }
    }
    
    notifyListeners();
  }

  /// Handle error response
  void _handleErrorResponse(dynamic data) {
    print('Error response: $data');
    _log('error', 'Error response received', details: data.toString());
    
    // Extract error message
    String errorMessage = 'Unknown error';
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) {
        errorMessage = data['data'].toString();
      } else if (data.containsKey('message')) {
        errorMessage = data['message'].toString();
      }
    } else if (data is String) {
      errorMessage = data;
    }
    
    statusMessage = 'Error: $errorMessage';
    notifyListeners();
  }

  /// Handle notification response
  void _handleNotification(dynamic data) {
    print('Notification response: $data');
    _log('info', 'Notification received', details: data.toString());
    // Update UI or state on the basis of notification
    notifyListeners();
  }

  /// Handle signal detected response
  void _handleSignalDetectedResponse(dynamic data) {
    print('Signal detected: $data');
    _log('info', 'Signal detected', details: data.toString());
    
    // Parse the signal data and add to detected signals list
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      Map<String, dynamic> signalData = data['data'];
      print('SignalDetected: Parsing signal data: $signalData');
      
      // Get module number
      int module = int.tryParse(signalData['module']?.toString() ?? '0') ?? 0;
      
      // In binary protocol, isBackgroundScanner is always false (sent as string 'false')
      // Parse it safely - can be bool or String
      bool isBackgroundScanner = false;
      if (signalData['isBackgroundScanner'] != null) {
        final value = signalData['isBackgroundScanner'];
        if (value is bool) {
          isBackgroundScanner = value;
        } else if (value is String) {
          isBackgroundScanner = value.toLowerCase() == 'true';
        }
      }
      
      // Create DetectedSignal from the data first
      DetectedSignal signal = DetectedSignal(
        frequency: signalData['frequency']?.toString() ?? '0',
        modulation: 'Unknown', // SignalDetected doesn't include modulation
        rssi: int.tryParse(signalData['rssi']?.toString() ?? '0') ?? 0,
        data: '', // SignalDetected doesn't include data
        timestamp: DateTime.now(),
        module: module,
        isBackgroundScanner: isBackgroundScanner,
      );
      
      // Note: Frequency search state will be updated by ModeSwitch message
      // when the module transitions back to Idle after detecting signal
      // But add a fallback in case ModeSwitch doesn't arrive
      print('Signal detected for module $module - waiting for ModeSwitch to update state');
      
      // Fallback: if ModeSwitch doesn't arrive within 2 seconds, stop search manually
      if (!signal.isBackgroundScanner && isFrequencySearching[module] == true) {
        Future.delayed(const Duration(seconds: 2), () {
          // Only stop if ModeSwitch hasn't already stopped the search
          if (isFrequencySearching[module] == true) {
            isFrequencySearching[module] = false;
            print('Module $module frequency search stopped (fallback after signal detection)');
            _log('info', 'Frequency search stopped (fallback)', details: 'Module: $module');
            
            // Also update module state in cc1101Modules if it exists
            if (cc1101Modules != null && module < cc1101Modules!.length) {
              cc1101Modules![module]['mode'] = 'Idle';
              print('Updated module $module mode in cc1101Modules to Idle (fallback)');
            } else if (cc1101Modules == null) {
              // Initialize if needed
              cc1101Modules = [];
              while (cc1101Modules!.length <= module) {
                cc1101Modules!.add({
                  'id': cc1101Modules!.length,
                  'mode': 'Unknown',
                });
              }
              cc1101Modules![module]['mode'] = 'Idle';
              cc1101Modules![module]['id'] = module;
              print('Created module $module in cc1101Modules with mode Idle (fallback)');
            }
            
            notifyListeners();
          }
        });
      }
      
      print('SignalDetected: Created signal: $signal');
      
      // Only add to detected signals list if it's NOT a background scanner
      // Background scanner signals should only appear on scanner screen
      if (!signal.isBackgroundScanner) {
      detectedSignals.insert(0, signal);
      
      // Limit list size (max 100 signals)
      if (detectedSignals.length > 100) {
        detectedSignals = detectedSignals.take(100).toList();
      }
      
      // Sort by timestamp (newest first)
      detectedSignals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('Added signal to list. Total signals: ${detectedSignals.length}');
      } else {
        print('Background scanner signal - not adding to main list');
      }
    }
    
    notifyListeners();
  }

  /// Handle signal recorded response
  void _handleSignalRecordedResponse(dynamic data) {
    print('Signal recorded: $data');
    _log('info', 'Signal recorded', details: data.toString());
    
    // Add the new file to recorded files list
    String? filename;
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        // Format: {type: SignalRecorded, data: {filename: ...}}
        filename = data['data']['filename'];
      } else if (data['filename'] != null) {
        // Format: {filename: ...}
        filename = data['filename'];
      }
    }
    
    if (filename != null) {
      final newFile = {
        'filename': filename,
        'date': DateTime.now().toIso8601String(),
        'type': 'recorded'
      };
      
      // Add to the beginning of the list
      recordedRuntimeFiles.insert(0, newFile);
      
      // Limit list size to prevent memory issues
      if (recordedRuntimeFiles.length > 50) {
        recordedRuntimeFiles = recordedRuntimeFiles.take(50).toList();
      }
      
      _notify('success', 'Signal recorded: $filename');
      print('Added new recorded file: $filename');
    } else {
      print('Could not extract filename from SignalRecorded data: $data');
    }
    
    notifyListeners();
  }

  /// Removes file from local recorded files list
  void removeRecordedFile(String filename) {
    recordedRuntimeFiles.removeWhere((file) => file['filename'] == filename);
    notifyListeners();
  }

  /// Handle signal record error response
  void _handleSignalRecordErrorResponse(dynamic data) {
    print('Signal record error: $data');
    _log('error', 'Signal record error', details: data.toString());
    _notify('error', 'Record error');
    notifyListeners();
  }

  /// Handle signal sent response
  void _handleSignalSentResponse(dynamic data) {
    print('Signal sent: $data');
    _log('info', 'Signal sent', details: data.toString());
    _notify('success', 'Signal transmitted');
    notifyListeners();
  }

  /// Handle signal sending error response
  void _handleSignalSendingErrorResponse(dynamic data) {
    print('Signal sending error: $data');
    String errorMessage = 'Transmission failed';
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final errorData = data['data'];
      if (errorData is Map<String, dynamic>) {
        errorMessage = errorData['error']?.toString() ?? 'Transmission failed';
        if (errorData.containsKey('filename')) {
          errorMessage += ': ${errorData['filename']}';
        }
      }
    }
    statusMessage = errorMessage;
    _log('error', 'Signal sending error', details: errorMessage);
    _notify('error', errorMessage);
    notifyListeners();
  }

  /// Handle mode switch response
  void _handleModeSwitchResponse(dynamic data) {
    print('Mode switch: $data');
    _log('info', 'Mode switch', details: data.toString());
    notifyListeners();
  }

  /// Handle file system response
  void _handleFileSystemResponse(dynamic data) {
    print('File system response: $data');
    _log('info', 'File system response', details: data.toString());
    
    // Handle file system operations
    if (data is Map<String, dynamic>) {
      // Handle DirectoryTree response FIRST (top-level type check)
      // Structure from BinaryMessageParser: {type: 'DirectoryTree', data: {pathType: 0, paths: [...], streaming: bool, totalDirs: int}}
      if (data.containsKey('type') && data['type'] == 'DirectoryTree') {
        print('DirectoryTree response detected (top-level): $data');
        
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          Map<String, dynamic> directoryTreeData = data['data'];
          
          // Check for errors first
          if (directoryTreeData.containsKey('error')) {
            print('Directory tree error: ${directoryTreeData['error']}');
            _isStreamingDirectoryTree = false;
            _streamingDirectoryTreeBuffer.clear();
            _streamingTotalDirs = 0;
            
            if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
              _pendingDirectoryTreeCompleter!.completeError('Error getting directory tree: ${directoryTreeData['error']}');
              _pendingDirectoryTreeCompleter = null;
            }
            return;
          }
          
          bool isStreaming = directoryTreeData['streaming'] == true;
          int totalDirs = directoryTreeData['totalDirs'] ?? 0;
          List<dynamic> paths = directoryTreeData['paths'] ?? [];
          
          if (isStreaming) {
            // Streaming mode: accumulate paths in buffer
            if (!_isStreamingDirectoryTree) {
              // First message of stream - clear buffer
              _streamingDirectoryTreeBuffer.clear();
              // 0xFFFF (65535) means total is unknown
              _streamingTotalDirs = (totalDirs == 65535) ? 0 : totalDirs;
              _isStreamingDirectoryTree = true;
              print('Directory tree streaming started, totalDirs: $_streamingTotalDirs');
            }
            
            // Add paths from this message
            for (var path in paths) {
              if (path is String) {
                _streamingDirectoryTreeBuffer.add(path);
              }
            }
            
            print('Directory tree streaming: ${_streamingDirectoryTreeBuffer.length} paths received${_streamingTotalDirs > 0 ? ' / $_streamingTotalDirs' : ''}');
          } else {
            // Final or single message
            if (_isStreamingDirectoryTree) {
              // End of stream - combine buffer with this message
              for (var path in paths) {
                if (path is String) {
                  _streamingDirectoryTreeBuffer.add(path);
                }
              }
              
              // Create response with all accumulated paths
              Map<String, dynamic> directoryTreeResponse = {
                'type': 'DirectoryTree',
                'data': {
                  'pathType': directoryTreeData['pathType'] ?? 0,
                  'paths': List<String>.from(_streamingDirectoryTreeBuffer),
                },
              };
              
              _streamingDirectoryTreeBuffer.clear();
              _streamingTotalDirs = 0;
              _isStreamingDirectoryTree = false;
              
              print('Directory tree stream complete: ${directoryTreeResponse['data']['paths'].length} paths total');
              
              if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
                _pendingDirectoryTreeCompleter!.complete(directoryTreeResponse);
                print('Directory tree completer completed successfully (streaming)');
              }
            } else {
              // Single message (non-streaming)
              print('Directory tree single message: ${paths.length} paths');
              
              if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
                _pendingDirectoryTreeCompleter!.complete(data);
                print('Directory tree completer completed successfully (single message)');
              } else {
                print('Warning: Directory tree completer is null or already completed');
              }
            }
          }
        } else {
          print('Warning: DirectoryTree response missing data field: $data');
        }
        return; // Don't process further
      }
      
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        Map<String, dynamic> responseData = data['data'];
        
        // Handle file list response (supports streaming protocol)
        if (responseData.containsKey('action') && responseData['action'] == 'list') {
          // Check for errors first
          if (responseData.containsKey('error')) {
            print('File list error: ${responseData['error']}');
            _log('error', 'File list error', details: responseData['error'].toString());
            isLoadingFiles = false;
            fileListProgress = 0.0;
            _isStreamingFileList = false;
            _streamingFileBuffer.clear();
            _streamingTotalFiles = 0;
            _fileListTimeout?.cancel();
            _fileListTimeout = null;
            statusMessage = 'Error loading file list: ${responseData['error']}';
            notifyListeners();
            return;
          }
          
          if (responseData.containsKey('files') && responseData['files'] is List) {
            List<dynamic> files = responseData['files'];
            bool isStreaming = responseData['streaming'] == true;
            int totalFiles = responseData['totalFiles'] ?? 0;
            
            // Parse files from this message
            List<FileItem> parsedFiles = [];
            for (var file in files) {
              if (file is Map<String, dynamic>) {
                try {
                  parsedFiles.add(FileItem.fromJson(file));
                } catch (e) {
                  print('Error parsing file item: $e');
                }
              }
            }
            
            // CRITICAL: Check streaming flag FIRST before checking _isStreamingFileList
            // This ensures we properly handle the first streaming message
            if (isStreaming) {
              // Streaming mode: accumulate files in buffer
              if (!_isStreamingFileList) {
                // First message of stream - clear buffer and initialize
                // This should only happen once at the start of a new file list request
                _streamingFileBuffer.clear();
                // 0xFFFF (65535) means total is unknown
                _streamingTotalFiles = (totalFiles == 65535) ? 0 : totalFiles;
                _isStreamingFileList = true;
                _log('info', 'File list streaming started', 
                     details: 'Total files: ${_streamingTotalFiles > 0 ? _streamingTotalFiles : "unknown"}');
              }
              
              // Add files to buffer (accumulate across all streaming messages)
              final filesBefore = _streamingFileBuffer.length;
              _streamingFileBuffer.addAll(parsedFiles);
              final filesAfter = _streamingFileBuffer.length;
              
              // Update progress based on received/total files
              // If total is unknown (0 or was 65535), use indeterminate progress
              if (_streamingTotalFiles > 0) {
                fileListProgress = _streamingFileBuffer.length / _streamingTotalFiles;
              } else {
                // Indeterminate progress
                fileListProgress = 0.5;
              }
              
              _log('debug', 'File list streaming', 
                   details: 'Added ${filesAfter - filesBefore} files, total in buffer: ${_streamingFileBuffer.length}${_streamingTotalFiles > 0 ? '/$_streamingTotalFiles' : ''}');
              
              // CRITICAL: Update fileList during streaming so UI shows accumulated files
              // This ensures all files are visible, not just the last packet
              fileList = List.from(_streamingFileBuffer);
              notifyListeners();
            } else {
              // Final or single message (isStreaming == false)
              if (_isStreamingFileList) {
                // End of stream - combine buffer with this final message
                _streamingFileBuffer.addAll(parsedFiles);
                fileList = List.from(_streamingFileBuffer);
                _log('info', 'File list streaming complete', 
                     details: 'Total files: ${fileList.length} (buffer had ${_streamingFileBuffer.length - parsedFiles.length}, final message added ${parsedFiles.length})');
                _streamingFileBuffer.clear();
                _streamingTotalFiles = 0;
                _isStreamingFileList = false;
              } else {
                // Single message (non-streaming) - no previous streaming
                fileList = parsedFiles;
              }
              
              _log('info', 'File list complete', details: 'Path: $currentPath, Files: ${fileList.length}');
              
              // Save to cache
              if (fileList.isNotEmpty || files.isEmpty) {
                _fileCache[currentPath] = List.from(fileList);
                _cacheTimestamps[currentPath] = DateTime.now();
              }
              
              isLoadingFiles = false;
              fileListProgress = 0.0;
              _fileListTimeout?.cancel();
              _fileListTimeout = null;
              notifyListeners();
            }
          } else {
            // Invalid response format
            print('Invalid file list response format');
            _log('warning', 'Invalid file list response', details: 'Missing or invalid files array');
            isLoadingFiles = false;
            fileListProgress = 0.0;
            _isStreamingFileList = false;
            _streamingFileBuffer.clear();
            _streamingTotalFiles = 0;
            _fileListTimeout?.cancel();
            _fileListTimeout = null;
            notifyListeners();
          }
        }
      }
      
      // Handle file load response (direct response, not nested in 'data')
      if (data.containsKey('action') && data['action'] == 'load') {
        print('File load response received (direct)');
        _handleFileLoadResponse(data);
      }
      
      // Handle file load response (nested in 'data' field)
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        Map<String, dynamic> responseData = data['data'];
        if (responseData.containsKey('action') && responseData['action'] == 'load') {
          print('File load response received (nested in data)');
          _handleFileLoadResponse(responseData);
        }
        
        // Handle rename response
        if (responseData.containsKey('action') && responseData['action'] == 'rename') {
          print('Rename response received: $responseData');
          if (_pendingRenameCompleter != null && !_pendingRenameCompleter!.isCompleted) {
            _pendingRenameCompleter!.complete(responseData);
          }
        }
        
        // Handle delete response
        if (responseData.containsKey('action') && responseData['action'] == 'delete') {
          print('Delete response received: $responseData');
          if (_pendingDeleteCompleter != null && !_pendingDeleteCompleter!.isCompleted) {
            _pendingDeleteCompleter!.complete(responseData);
          }
        }
        
        // Handle create-directory response
        if (responseData.containsKey('action') && responseData['action'] == 'create-directory') {
          print('Create directory response received: $responseData');
          if (_pendingMkdirCompleter != null && !_pendingMkdirCompleter!.isCompleted) {
            _pendingMkdirCompleter!.complete(responseData);
          }
        }
        
        // Handle upload response
        if (responseData.containsKey('action') && responseData['action'] == 'upload') {
          print('Upload response received: $responseData');
          _handleFileUploadResponse(responseData);
        }
        
        // Handle copy response
        if (responseData.containsKey('action') && responseData['action'] == 'copy') {
          print('Copy response received: $responseData');
          if (_pendingCopyCompleter != null && !_pendingCopyCompleter!.isCompleted) {
            _pendingCopyCompleter!.complete(responseData);
          }
        }
        
        // Handle move response
        if (responseData.containsKey('action') && responseData['action'] == 'move') {
          print('Move response received: $responseData');
          if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
            _pendingMoveCompleter!.complete(responseData);
          }
        }
      }
      
      // Handle copy response (direct, not nested)
      if (data.containsKey('action') && data['action'] == 'copy') {
        print('Copy response received (direct): $data');
        if (_pendingCopyCompleter != null && !_pendingCopyCompleter!.isCompleted) {
          _pendingCopyCompleter!.complete(data);
        }
      }
      
      // Handle move response (direct, not nested)
      if (data.containsKey('action') && data['action'] == 'move') {
        print('Move response received (direct): $data');
        if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
          _pendingMoveCompleter!.complete(data);
        }
      }
      
      // Handle upload response (direct, not nested)
      if (data.containsKey('action') && data['action'] == 'upload') {
        print('Upload response received (direct): $data');
        _handleFileUploadResponse(data);
      }
    }
    
    notifyListeners();
  }

  /// Handle file load response
  void _handleFileLoadResponse(Map<String, dynamic> data) {
    print('Handling file load response: $data');
    
    if (data.containsKey('success') && data['success'] == true) {
      if (data.containsKey('content')) {
        String fileContent = data['content'];
        print('File content received, length: ${fileContent.length}');
        print('File content preview: ${fileContent.substring(0, fileContent.length > 100 ? 100 : fileContent.length)}...');
        
        // Store the file content for the current file reading operation
        _currentFileContent = fileContent;
        
        // If we have a pending file reading operation, complete it
        if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
          print('Completing pending file read completer with content length: ${fileContent.length}');
          _pendingFileReadCompleter!.complete(fileContent);
          _pendingFileReadCompleter = null;
        } else {
          print('No pending file read completer found');
        }
      } else {
        print('File load response missing content field');
        if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
          _pendingFileReadCompleter!.completeError('File content missing from response');
          _pendingFileReadCompleter = null;
        }
      }
    } else {
      String error = data['error'] ?? 'Unknown error loading file';
      print('File load failed: $error');
      if (_pendingFileReadCompleter != null && !_pendingFileReadCompleter!.isCompleted) {
        _pendingFileReadCompleter!.completeError(error);
        _pendingFileReadCompleter = null;
      }
    }
  }

  /// Handle file upload response
  void _handleFileUploadResponse(dynamic data) {
    print('File upload response: $data');
    _log('info', 'File upload response', details: data.toString());
    
    // Check if we have a pending upload completer
    if (_pendingUploadCompleter != null && !_pendingUploadCompleter!.isCompleted) {
      if (data is Map<String, dynamic>) {
        if (data['success'] == true) {
          _pendingUploadCompleter!.complete(data);
        } else {
          String error = data['error'] ?? 'Upload failed';
          _pendingUploadCompleter!.completeError(error);
        }
      } else {
        _pendingUploadCompleter!.completeError('Invalid upload response');
      }
      _pendingUploadCompleter = null;
    }
    
    notifyListeners();
  }

  Completer<Map<String, dynamic>>? _pendingUploadCompleter;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  /// Upload file to ESP32 with chunking
  /// Reads file from device storage and uploads it in chunks
  Future<Map<String, dynamic>> uploadFile(
    File file,
    String targetPath, {
    int pathType = 0,
    Function(double progress)? onProgress,
  }) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    _log('INFO', 'Uploading file: ${file.path} to $targetPath');
    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      // Read file size
      final fileSize = await file.length();
      _log('INFO', 'File size: $fileSize bytes');

      // Calculate number of chunks
      // First chunk contains: [0x0D][pathLength:1][pathType:1][path:variable] in payload
      // Subsequent chunks contain only file data
      // Payload size = MAX_CHUNK_SIZE - PACKET_HEADER_SIZE - checksum(1)
      const int maxChunkDataSize = FirmwareBinaryProtocol.MAX_CHUNK_SIZE - FirmwareBinaryProtocol.PACKET_HEADER_SIZE - 1;
      final int totalChunks = 1 + ((fileSize + maxChunkDataSize - 1) ~/ maxChunkDataSize);
      
      _log('INFO', 'Total chunks: $totalChunks');

      // Generate chunk ID
      final int chunkId = DateTime.now().millisecondsSinceEpoch & 0xFF;

      // Create completer for upload response
      _pendingUploadCompleter?.completeError('New upload started');
      _pendingUploadCompleter = Completer<Map<String, dynamic>>();

      // Send first chunk with path
      final firstChunk = FirmwareBinaryProtocol.createUploadFileStartCommand(
        targetPath,
        pathType: pathType,
        chunkId: chunkId,
        totalChunks: totalChunks,
      );
      await sendBinaryCommand(firstChunk);
      _uploadProgress = 1.0 / totalChunks;
      onProgress?.call(_uploadProgress);
      notifyListeners();

      // Read and send file data in chunks
      final fileStream = file.openRead();
      int chunkNum = 2; // Start from chunk 2 (chunk 1 is the path)
      int totalSent = 0;

      await for (final chunk in fileStream) {
        // Split chunk if it's too large
        int offset = 0;
        while (offset < chunk.length) {
          final int remaining = chunk.length - offset;
          final int chunkSize = remaining > maxChunkDataSize ? maxChunkDataSize : remaining;
          
          final Uint8List chunkData = Uint8List.fromList(chunk.sublist(offset, offset + chunkSize));
          
          // Create and send chunk
          final chunkCommand = FirmwareBinaryProtocol.createUploadFileChunkCommand(
            chunkData,
            chunkId,
            chunkNum,
            totalChunks,
          );
          
          await sendBinaryCommand(chunkCommand);
          
          totalSent += chunkSize;
          offset += chunkSize;
          chunkNum++;
          
          // Update progress
          _uploadProgress = totalSent / fileSize;
          onProgress?.call(_uploadProgress);
          notifyListeners();
          
          // Small delay to avoid overwhelming BLE stack
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      _log('INFO', 'File upload completed: $totalSent bytes sent in ${chunkNum - 1} chunks');

      // Wait for upload response with timeout
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingUploadCompleter != null && !_pendingUploadCompleter!.isCompleted) {
          _pendingUploadCompleter!.completeError('Upload timeout');
          _pendingUploadCompleter = null;
        }
      });

      try {
        final response = await _pendingUploadCompleter!.future;
        timeout.cancel();
        _uploadProgress = 1.0;
        onProgress?.call(1.0);
        _isUploading = false;
        notifyListeners();
        return response;
      } catch (e) {
        timeout.cancel();
        _isUploading = false;
        _uploadProgress = 0.0;
        notifyListeners();
        rethrow;
      } finally {
        _pendingUploadCompleter = null;
      }
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      _log('ERROR', 'File upload failed: $e');
      rethrow;
    }
  }

  // Scanner state management methods
  void updateDetectedSignals(List<DetectedSignal> newSignals) {
    detectedSignals.clear();
    detectedSignals.addAll(newSignals);
    notifyListeners();
  }

  void updateFrequencySpectrum(Map<String, double> newSpectrum) {
    frequencySpectrum = newSpectrum;
    notifyListeners();
  }

  void setScanning(bool scanning) {
    isScanning = scanning;
    notifyListeners();
  }

  void setSelectedModule(int module) {
    selectedModule = module;
    notifyListeners();
  }

  void setRssiThreshold(int threshold) {
    rssiThreshold = threshold;
    notifyListeners();
  }

  // === Methods for working with signals ===
  
  /// Signal file parsing
  /// [fileContent] - file content
  /// [filename] - file name (optional)
  /// Returns SignalData or null if parsing failed
  SignalData? parseSignalFile(String fileContent, {String? filename}) {
    try {
      final result = FileParserFactory.parseFile(fileContent, filename: filename);
      if (result.success) {
        _log('info', 'Successfully parsed signal file', details: filename);
        return result.signalData;
      } else {
        _log('error', 'Failed to parse signal file', details: result.errors.join(', '));
        return null;
      }
    } catch (e) {
      _log('error', 'Error parsing signal file', details: e.toString());
      return null;
    }
  }
  
  /// Signal file generation
  /// [signalData] - signal data
  /// [format] - file format
  /// Returns file content or null if generation failed
  String? generateSignalFile(SignalData signalData, SignalFormat format) {
    try {
      final result = SignalGeneratorFactory.generateFromSignalData(signalData, format);
      if (result.success) {
        _log('info', 'Successfully generated signal file', details: format.description);
        return result.content;
      } else {
        _log('error', 'Failed to generate signal file', details: result.errors.join(', '));
        return null;
      }
    } catch (e) {
      _log('error', 'Error generating signal file', details: e.toString());
      return null;
    }
  }
  
  /// Recording parameters validation
  /// [config] - recording configuration
  /// Returns list of errors (empty if all valid)
  List<String> validateRecordConfig(RecordConfig config) {
    final errors = <String>[];
    
    // Frequency validation
    if (!CC1101Values.isValidFrequency(config.frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(config.frequency);
      if (closest != null) {
        errors.add('Invalid frequency ${config.frequency.toStringAsFixed(2)} MHz. Closest valid: ${closest.toStringAsFixed(2)} MHz');
      } else {
        errors.add('Invalid frequency ${config.frequency.toStringAsFixed(2)} MHz');
      }
    }
    
    // Module validation
    if (config.module < 0) {
      errors.add('Invalid module number: ${config.module}');
    }
    
    // Advanced mode parameters validation
    if (config.advancedMode) {
      if (config.dataRate != null && !CC1101Values.isValidDataRate(config.dataRate!)) {
        errors.add('Invalid data rate ${config.dataRate!.toStringAsFixed(2)} kBaud');
      }
      
      if (config.deviation != null && !CC1101Values.isValidDeviation(config.deviation!)) {
        errors.add('Invalid deviation ${config.deviation!.toStringAsFixed(2)} kHz');
      }
    }
    
    return errors;
  }
  
  /// Get signal file information
  /// [fileContent] - file content
  /// [filename] - file name (optional)
  /// Returns file information
  Map<String, dynamic>? getSignalFileInfo(String fileContent, {String? filename}) {
    try {
      return FileParserFactory.getFileInfo(fileContent, filename: filename);
    } catch (e) {
      _log('error', 'Error getting file info', details: e.toString());
      return null;
    }
  }
  
  /// Get list of supported file formats
  /// Returns list of file extensions
  List<String> getSupportedFileExtensions() {
    return FileParserFactory.getSupportedExtensions();
  }
  
  /// Get list of supported generation formats
  /// Returns list of formats
  List<SignalFormat> getSupportedGenerationFormats() {
    return SignalGeneratorFactory.getSupportedFormats();
  }
  
  /// Create recording configuration from SignalData
  /// [signalData] - signal data
  /// [module] - module number
  /// Returns recording configuration
  RecordConfig createRecordConfigFromSignal(SignalData signalData, int module) {
    return RecordConfig.fromSignalData(signalData, module);
  }
  
  /// Get CC1101 calculator
  /// Returns calculator instance
  CC1101Calculator getCC1101Calculator() {
    return CC1101Calculator();
  }
  
  /// Get CC1101 values
  /// Returns class with predefined values
  CC1101Values getCC1101Values() {
    return CC1101Values();
  }
  
  /// Send binary command via Enhanced Protocol
  /// [command] - binary command to send
  // Transmit signal from file
  Future<void> transmitFromFile(String filePath, {int? module, int repeat = 1, int? pathType}) async {
    if (!isConnected || txCharacteristic == null) {
      statusMessage = 'Not connected';
      _log('error', 'Failed to transmit: Not connected', details: 'File: $filePath');
      notifyListeners();
      throw Exception('Not connected to device');
    }

    try {
      // Find idle module if not specified
      int? selectedModule = module;
      if (selectedModule == null) {
        // Find first idle module
        if (cc1101Modules != null) {
          for (int i = 0; i < cc1101Modules!.length; i++) {
            final moduleMode = cc1101Modules![i]['mode']?.toString().toLowerCase();
            if (moduleMode == 'idle') {
              selectedModule = i;
              break;
            }
          }
        }
        
        // If no idle module found, throw error
        if (selectedModule == null) {
          statusMessage = 'No idle module available';
          _log('error', 'Failed to transmit: No idle module', details: 'File: $filePath');
          notifyListeners();
          throw Exception('No idle module available for transmission');
        }
      } else {
        // Check if specified module is idle
        if (cc1101Modules != null && selectedModule < cc1101Modules!.length) {
          final moduleMode = cc1101Modules![selectedModule]['mode']?.toString().toLowerCase();
          if (moduleMode != 'idle') {
            statusMessage = 'Module $selectedModule is not idle';
            _log('error', 'Failed to transmit: Module not idle', details: 'File: $filePath, Module: $selectedModule, Mode: $moduleMode');
            notifyListeners();
            throw Exception('Module $selectedModule is not idle (current mode: $moduleMode)');
          }
        }
      }
      
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      
      // Use the filePath as-is (it should be a relative path like "folder/file.sub" or just "file.sub")
      // Only extract filename if it's an absolute path starting with /DATA/
      String pathToUse = filePath;
      if (filePath.startsWith('/DATA/')) {
        // Extract relative path from /DATA/RECORDS/... or /DATA/SIGNALS/...
        final parts = filePath.split('/');
        if (parts.length > 3) {
          pathToUse = parts.sublist(3).join('/');
        } else {
          pathToUse = parts.last;
        }
      }
      
      _log('info', 'Transmitting signal from file', details: 'File: $pathToUse, pathType: $effectivePathType, Module: $selectedModule, Repeat: $repeat');
      
      // Use FirmwareBinaryProtocol to create properly formatted command with pathType and module
      final command = FirmwareBinaryProtocol.createTransmitFromFileCommand(pathToUse, pathType: effectivePathType, module: selectedModule);
      
      _log('debug', 'Sending transmitFromFile command', 
           details: 'File: $pathToUse, pathType: $effectivePathType, Module: $selectedModule, Command length: ${command.length} bytes');
      
      await sendBinaryCommand(command);
      
      statusMessage = 'transmittingSignal';
      lastCommandMessage = 'Transmitting from $filePath';
      notifyListeners();
    } catch (e) {
      _log('error', 'Failed to transmit signal', details: e.toString());
      statusMessage = 'Transmission failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendBinaryCommand(Uint8List command, {bool withoutResponse = false}) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    try {
      // Only use writeWithoutResponse if the characteristic actually supports it
      final useNoResp = withoutResponse &&
          txCharacteristic!.properties.writeWithoutResponse;
      await txCharacteristic!.write(command, withoutResponse: useNoResp);
    } catch (e) {
      print('Error sending binary command: $e');
      throw Exception('Failed to send command: $e');
    }
  }

  /// Send signal recording command
  /// Start jamming on specified module
  Future<void> sendStartJamCommand({
    required int module,
    required double frequency,
    int power = 7, // 0-7
    int patternType = 0, // 0=Random, 1=Alternating, 2=Continuous, 3=Custom
    int maxDurationMs = 60000, // 60 seconds default
    int cooldownMs = 5000, // 5 seconds default
    List<int>? customPattern, // Optional custom pattern bytes
  }) async {
    if (!isConnected || txCharacteristic == null) {
      _log('error', 'Cannot start jam: not connected');
      throw Exception('Not connected');
    }
    
    _log('command', 'Starting jam on module $module: freq=$frequency, power=$power, pattern=$patternType');
    
    final command = FirmwareBinaryProtocol.createStartJamCommand(
      module: module,
      frequency: frequency,
      power: power,
      patternType: patternType,
      maxDurationMs: maxDurationMs,
      cooldownMs: cooldownMs,
      customPattern: customPattern,
    );
    
    await sendBinaryCommand(command);
  }

  Future<void> sendRecordCommand({
    required double frequency,
    required int module,
    String? preset,
    int? modulation,
    double? deviation,
    double? rxBandwidth,
    double? dataRate,
  }) async {
    final command = FirmwareBinaryProtocol.createRequestRecordCommand(
      frequency: frequency,
      module: module,
      preset: preset,
      modulation: modulation,
      deviation: deviation,
      rxBandwidth: rxBandwidth,
      dataRate: dataRate,
    );
    
    await sendBinaryCommand(command);
  }

  /// Send idle command (stop operations)
  Future<void> sendIdleCommand(int module) async {
    final command = FirmwareBinaryProtocol.createRequestIdleCommand(module);
    await sendBinaryCommand(command);
  }

  /// Send signal transmission command
  Future<void> sendTransmitCommand({
    required double frequency,
    required String data,
    int pulseDuration = 100,
  }) async {
    final command = FirmwareBinaryProtocol.createTransmitBinaryCommand(
      frequency,
      pulseDuration,
      data,
    );
    
    await sendBinaryCommand(command);
  }

  /// Send device state request command
  /// Send current time to ESP32 for synchronization
  Future<void> sendSetTimeCommand() async {
    if (!isConnected) {
      return;
    }

    try {
      final command = FirmwareBinaryProtocol.createSetTimeCommand(DateTime.now());
      await sendBinaryCommand(command);
      _log('info', 'Time synchronization command sent', details: 'Time: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      _log('error', 'Failed to send time synchronization command', details: e.toString());
      // Don't throw - time sync is not critical
    }
  }

  // --- Bruter commands ---

  /// Whether a bruter attack is currently running
  bool _isBruterRunning = false;
  bool get isBruterRunning => _isBruterRunning;

  /// Currently selected bruter protocol menu index (1-33), 0 = none
  int _bruterActiveProtocol = 0;
  int get bruterActiveProtocol => _bruterActiveProtocol;

  /// Bruter progress tracking (updated via BLE notifications)
  int _bruterCurrentCode = 0;
  int get bruterCurrentCode => _bruterCurrentCode;
  int _bruterTotalCodes = 0;
  int get bruterTotalCodes => _bruterTotalCodes;
  int _bruterPercentage = 0;
  int get bruterPercentage => _bruterPercentage;
  int _bruterCodesPerSec = 0;
  int get bruterCodesPerSec => _bruterCodesPerSec;

  /// Inter-frame delay in ms (configurable, synced with firmware)
  int _bruterDelayMs = 10; // Default matches BRUTER_INTER_FRAME_GAP_MS
  int get bruterDelayMs => _bruterDelayMs;

  // --- Persistent device settings (synced via 0xC0 / 0xC1) ---
  int _scannerRssi = -80;
  int get scannerRssi => _scannerRssi;
  int _bruterPower = 7;
  int get bruterPower => _bruterPower;
  int _bruterRepeats = 4;
  int get bruterRepeats => _bruterRepeats;
  int _radioPowerMod1 = 10;
  int get radioPowerMod1 => _radioPowerMod1;
  int _radioPowerMod2 = 10;
  int get radioPowerMod2 => _radioPowerMod2;
  int _cpuTempOffsetDeciC = -200;
  int get cpuTempOffsetDeciC => _cpuTempOffsetDeciC;
  bool _settingsSynced = false;
  bool get settingsSynced => _settingsSynced;

  // --- Firmware version (received via 0xC2 on connect) ---
  String _firmwareVersion = '';
  String get firmwareVersion => _firmwareVersion;
  int _fwMajor = 0;
  int get fwMajor => _fwMajor;
  int _fwMinor = 0;
  int get fwMinor => _fwMinor;
  int _fwPatch = 0;
  int get fwPatch => _fwPatch;

  // --- Battery status (received via 0xC3 periodically + on connect) ---
  int _batteryVoltage = 0;       // millivolts
  int get batteryVoltage => _batteryVoltage;
  int _batteryPercent = -1;      // -1 = unknown, 0-100
  int get batteryPercent => _batteryPercent;
  bool _batteryCharging = false;
  bool get batteryCharging => _batteryCharging;
  bool get hasBatteryInfo => _batteryPercent >= 0;

  // --- Device name (received via 0xC7 on connect) ---
  String _deviceName = 'EvilCrow_RF2';
  String get deviceName => _deviceName;

  /// Set BLE device name on the device. Takes effect after reboot.
  Future<bool> setDeviceName(String name) async {
    if (name.isEmpty || name.length > 20) return false;
    if (!isConnected || txCharacteristic == null) return false;
    try {
      final cmd = FirmwareBinaryProtocol.createSetDeviceNameCommand(name);
      await sendBinaryCommand(cmd);
      _deviceName = name; // optimistic update
      notifyListeners();
      _log('info', 'Set device name to: $name (reboot required)');
      return true;
    } catch (e) {
      _log('error', 'Failed to set device name: $e');
      return false;
    }
  }

  /// Send factory reset command. Device will erase all settings and reboot.
  Future<bool> factoryReset() async {
    if (!isConnected || txCharacteristic == null) return false;
    try {
      final cmd = FirmwareBinaryProtocol.createFactoryResetCommand();
      await sendBinaryCommand(cmd);
      _log('warning', 'Factory reset command sent — device will reboot');
      return true;
    } catch (e) {
      _log('error', 'Failed to send factory reset: $e');
      return false;
    }
  }

  /// Start a bruter attack with the given menu choice (1-33)
  Future<void> sendBruterCommand(int menuChoice) async {
    if (!isConnected || txCharacteristic == null) {
      _log('error', 'Cannot start bruter: not connected');
      throw Exception('Not connected');
    }

    if (menuChoice < 1 || menuChoice > 40) {
      _log('error', 'Invalid bruter menu choice: $menuChoice');
      throw Exception('Invalid menu choice: $menuChoice (must be 1-40)');
    }

    _log('command', 'Starting bruter attack: protocol $menuChoice');

    final command = FirmwareBinaryProtocol.createBruterCommand(menuChoice);
    await sendBinaryCommand(command);

    _isBruterRunning = true;
    _bruterActiveProtocol = menuChoice;
    notifyListeners();
  }

  /// Cancel a running bruter attack (STOP — clears saved state)
  Future<void> sendBruterCancelCommand() async {
    if (!isConnected || txCharacteristic == null) {
      _log('error', 'Cannot cancel bruter: not connected');
      throw Exception('Not connected');
    }

    _log('command', 'Cancelling bruter attack');

    final command = FirmwareBinaryProtocol.createBruterCancelCommand();
    await sendBinaryCommand(command);

    _isBruterRunning = false;
    _bruterActiveProtocol = 0;
    _bruterSavedStateAvailable = false; // Stop clears saved state on device
    notifyListeners();
  }

  /// Pause a running bruter attack (saves state to LittleFS for resume)
  Future<void> sendBruterPauseCommand() async {
    if (!isConnected || txCharacteristic == null) {
      _log('error', 'Cannot pause bruter: not connected');
      throw Exception('Not connected');
    }

    _log('command', 'Pausing bruter attack');

    final command = FirmwareBinaryProtocol.createBruterPauseCommand();
    await sendBinaryCommand(command);
    // State will be updated when we receive the 0xB2 paused notification
  }

  /// Resume a previously paused bruter attack
  Future<void> sendBruterResumeCommand() async {
    if (!isConnected || txCharacteristic == null) {
      _log('error', 'Cannot resume bruter: not connected');
      throw Exception('Not connected');
    }

    _log('command', 'Resuming bruter attack');

    final command = FirmwareBinaryProtocol.createBruterResumeCommand();
    await sendBinaryCommand(command);

    _isBruterRunning = true;
    _bruterActiveProtocol = _bruterSavedMenuId;
    _bruterSavedStateAvailable = false;
    notifyListeners();
  }

  /// Query the device for any saved bruter state
  Future<void> queryBruterSavedState() async {
    if (!isConnected || txCharacteristic == null) return;
    final command = FirmwareBinaryProtocol.createBruterQueryStateCommand();
    await sendBinaryCommand(command);
  }

  /// Whether a saved/paused bruter state is available for resume
  bool _bruterSavedStateAvailable = false;
  bool get bruterSavedStateAvailable => _bruterSavedStateAvailable;
  int _bruterSavedMenuId = 0;
  int get bruterSavedMenuId => _bruterSavedMenuId;
  int _bruterSavedCurrentCode = 0;
  int get bruterSavedCurrentCode => _bruterSavedCurrentCode;
  int _bruterSavedTotalCodes = 0;
  int get bruterSavedTotalCodes => _bruterSavedTotalCodes;
  int _bruterSavedPercentage = 0;
  int get bruterSavedPercentage => _bruterSavedPercentage;

  /// Reset bruter state (called on disconnect or error)
  void _resetBruterState() {
    _isBruterRunning = false;
    _bruterActiveProtocol = 0;
    _bruterCurrentCode = 0;
    _bruterTotalCodes = 0;
    _bruterPercentage = 0;
    _bruterCodesPerSec = 0;
    _bruterSavedStateAvailable = false;
    _bruterSavedMenuId = 0;
    _bruterSavedCurrentCode = 0;
    _bruterSavedTotalCodes = 0;
    _bruterSavedPercentage = 0;
  }

  /// Set bruter inter-frame delay (sent to firmware)
  Future<void> setBruterDelay(int delayMs) async {
    _bruterDelayMs = delayMs.clamp(1, 1000);
    
    if (!isConnected || txCharacteristic == null) {
      _log('info', 'Bruter delay set locally to $_bruterDelayMs ms (will sync on connect)');
      notifyListeners();
      return;
    }

    _log('command', 'Setting bruter delay to $_bruterDelayMs ms');
    final command = FirmwareBinaryProtocol.createBruterSetDelayCommand(_bruterDelayMs);
    await sendBinaryCommand(command);
    notifyListeners();
  }

  /// Handle bruter progress update from firmware
  void _handleBruterProgress(Map<String, dynamic> data) {
    _bruterCurrentCode = data['currentCode'] ?? 0;
    _bruterTotalCodes = data['totalCodes'] ?? 0;
    _bruterPercentage = data['percentage'] ?? 0;
    _bruterCodesPerSec = data['codesPerSec'] ?? 0;
    int menuId = data['menuId'] ?? 0;
    
    // Ensure running state is correct, but do not override a paused state.
    // Late progress messages (queued before pause took effect) must not
    // re-set _isBruterRunning after the pause handler cleared it.
    if (menuId > 0 && !_isBruterRunning && !_bruterSavedStateAvailable) {
      _isBruterRunning = true;
      _bruterActiveProtocol = menuId;
    }
    
    notifyListeners();
  }

  /// Handle bruter attack completion from firmware
  void _handleBruterComplete(Map<String, dynamic> data) {
    int menuId = data['menuId'] ?? 0;
    int status = data['status'] ?? 0; // 0=completed, 1=cancelled, 2=error
    int totalSent = data['totalSent'] ?? 0;
    
    String statusStr = status == 0 ? 'completed' : (status == 1 ? 'cancelled' : 'error');
    _log('info', 'Brute force $statusStr: protocol $menuId, $totalSent codes sent');
    
    _isBruterRunning = false;
    _bruterActiveProtocol = 0;
    _bruterPercentage = status == 0 ? 100 : _bruterPercentage;
    _bruterCodesPerSec = 0;
    
    // Store completion info for UI notification
    _lastBruterCompletionStatus = status;
    _lastBruterCompletionMenuId = menuId;

    _notify(status == 0 ? 'success' : 'warning', 'Bruter $statusStr ($totalSent codes)');
    notifyListeners();
  }

  /// Handle bruter paused notification (attack saved to LittleFS)
  void _handleBruterPaused(Map<String, dynamic> data) {
    int menuId = data['menuId'] ?? 0;
    int currentCode = data['currentCode'] ?? 0;
    int totalCodes = data['totalCodes'] ?? 0;
    int percentage = data['percentage'] ?? 0;

    _log('info', 'Brute force paused: protocol $menuId at $currentCode/$totalCodes ($percentage%)');

    _isBruterRunning = false;
    _bruterActiveProtocol = 0;
    _bruterCodesPerSec = 0;

    // Mark saved state as available for resume
    _bruterSavedStateAvailable = true;
    _bruterSavedMenuId = menuId;
    _bruterSavedCurrentCode = currentCode;
    _bruterSavedTotalCodes = totalCodes;
    _bruterSavedPercentage = percentage;

    notifyListeners();
  }

  /// Handle bruter resumed notification (attack continuing from saved point)
  void _handleBruterResumed(Map<String, dynamic> data) {
    int menuId = data['menuId'] ?? 0;
    int resumeCode = data['resumeCode'] ?? 0;
    int totalCodes = data['totalCodes'] ?? 0;

    _log('info', 'Brute force resumed: protocol $menuId from code $resumeCode/$totalCodes');

    _isBruterRunning = true;
    _bruterActiveProtocol = menuId;
    _bruterSavedStateAvailable = false;

    notifyListeners();
  }

  /// Handle saved bruter state available notification (sent on BLE connect)
  void _handleBruterStateAvail(Map<String, dynamic> data) {
    int menuId = data['menuId'] ?? 0;
    int currentCode = data['currentCode'] ?? 0;
    int totalCodes = data['totalCodes'] ?? 0;
    int percentage = data['percentage'] ?? 0;

    _log('info', 'Saved bruter state available: protocol $menuId at $percentage%');

    _bruterSavedStateAvailable = true;
    _bruterSavedMenuId = menuId;
    _bruterSavedCurrentCode = currentCode;
    _bruterSavedTotalCodes = totalCodes;
    _bruterSavedPercentage = percentage;

    notifyListeners();
  }

  /// Handle settings sync from firmware (0xC0).
  /// Updates local settings to match the device state.
  void _handleSettingsSync(Map<String, dynamic> data) {
    _scannerRssi   = data['scannerRssi'] ?? -80;
    _bruterPower   = data['bruterPower'] ?? 7;
    _bruterDelayMs = data['bruterDelay'] ?? 10;
    _bruterRepeats = data['bruterRepeats'] ?? 4;
    _radioPowerMod1 = data['radioPowerMod1'] ?? 10;
    _radioPowerMod2 = data['radioPowerMod2'] ?? 10;
    final tempOffset = data['cpuTempOffsetDeciC'];
    if (tempOffset is num) {
      _cpuTempOffsetDeciC = tempOffset.toInt().clamp(-500, 500);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('cpuTempOffsetDeciC', _cpuTempOffsetDeciC);
      });
    }
    _settingsSynced = true;

    _log('info', 'Settings synced from device: rssi=$_scannerRssi power=$_bruterPower delay=$_bruterDelayMs reps=$_bruterRepeats mod1=$_radioPowerMod1 mod2=$_radioPowerMod2 tempOff=$_cpuTempOffsetDeciC');
    notifyListeners();
  }

  /// Handle firmware version info (0xC2) — received on every getState.
  void _handleVersionInfo(Map<String, dynamic> data) {
    _fwMajor = data['major'] ?? 0;
    _fwMinor = data['minor'] ?? 0;
    _fwPatch = data['patch'] ?? 0;
    _firmwareVersion = data['version'] ?? '$_fwMajor.$_fwMinor.$_fwPatch';

    _log('info', 'Firmware version: $_firmwareVersion');
    notifyListeners();
  }

  /// Handle device name notification (0xC7) — received on every getState.
  void _handleDeviceName(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    if (name.isNotEmpty) {
      _deviceName = name;
      _log('info', 'Device name: $_deviceName');
      notifyListeners();
    }
  }

  /// Handle battery status (0xC3) — received periodically and on connect.
  void _handleBatteryStatus(Map<String, dynamic> data) {
    _batteryVoltage = data['voltage_mv'] ?? 0;
    _batteryPercent = data['percentage'] ?? 0;
    _batteryCharging = data['charging'] ?? false;
    _log('info', 'Battery: ${_batteryVoltage}mV ${_batteryPercent}% charging=$_batteryCharging');
    notifyListeners();
  }

  /// Handle HW button config (0xC8) — received on GetState.
  /// Updates local state so the Settings screen can show current button config.
  void _handleHwButtonStatus(Map<String, dynamic> data) {
    deviceBtn1Action = data['btn1Action'] ?? 0;
    deviceBtn2Action = data['btn2Action'] ?? 0;
    deviceBtn1PathType = data['btn1PathType'] ?? 0;
    deviceBtn2PathType = data['btn2PathType'] ?? 0;
    _log('info', 'HwButtonStatus: btn1=$deviceBtn1Action btn2=$deviceBtn2Action');
    notifyListeners();
  }

  /// Handle SD card status (0xC9) — received on GetState.
  void _handleSdStatus(Map<String, dynamic> data) {
    sdMounted = data['mounted'] ?? false;
    sdTotalMB = data['totalMB'] ?? 0;
    sdFreeMB = data['freeMB'] ?? 0;
    _log('info', 'SdStatus: mounted=$sdMounted total=${sdTotalMB}MB free=${sdFreeMB}MB');
    notifyListeners();
  }

  /// Handle nRF24 module status (0xCA) — received on GetState.
  void _handleNrfModuleStatus(Map<String, dynamic> data) {
    nrfPresent = data['present'] ?? false;
    nrfInitialized = data['initialized'] ?? false;
    // activeState: 0=idle, 1=jamming, 2=scanning, 3=attacking, 4=spectrum
    int state = data['activeState'] ?? 0;
    nrfJammerRunning = (state == 1);
    nrfScanning = (state == 2);
    nrfAttacking = (state == 3);
    nrfSpectrumRunning = (state == 4);
    _log('info', 'NrfModuleStatus: present=$nrfPresent init=$nrfInitialized state=$state');
    notifyListeners();
  }

  /// Send updated settings to the device (0xC1).
  /// Payload: [0xAA][cmd=0xC1][5 bytes settings data][checksum]
  Future<void> sendSettingsToDevice({
    int? scannerRssi,
    int? bruterPower,
    int? bruterDelay,
    int? bruterRepeats,
    int? radioPowerMod1,
    int? radioPowerMod2,
    int? cpuTempOffsetDeciC,
  }) async {
    // Update local state first
    if (scannerRssi != null) _scannerRssi = scannerRssi;
    if (bruterPower != null) _bruterPower = bruterPower.clamp(0, 7);
    if (bruterDelay != null) _bruterDelayMs = bruterDelay.clamp(1, 1000);
    if (bruterRepeats != null) _bruterRepeats = bruterRepeats.clamp(1, 10);
    if (radioPowerMod1 != null) _radioPowerMod1 = radioPowerMod1.clamp(-30, 10);
    if (radioPowerMod2 != null) _radioPowerMod2 = radioPowerMod2.clamp(-30, 10);
    if (cpuTempOffsetDeciC != null) {
      _cpuTempOffsetDeciC = cpuTempOffsetDeciC.clamp(-500, 500);
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('cpuTempOffsetDeciC', _cpuTempOffsetDeciC);
      } catch (e) {
        _log('warning', 'Failed to store cpu temp offset: $e');
      }
    }

    if (!isConnected || txCharacteristic == null) {
      _log('warning', 'Settings saved locally only (not connected)');
      notifyListeners();
      return;
    }

    // Build binary command: 9-byte payload
    final payload = Uint8List(9);
    payload[0] = _scannerRssi < 0 ? (_scannerRssi + 256) & 0xFF : _scannerRssi; // int8_t
    payload[1] = _bruterPower;
    payload[2] = _bruterDelayMs & 0xFF;
    payload[3] = (_bruterDelayMs >> 8) & 0xFF;
    payload[4] = _bruterRepeats;
    payload[5] = _radioPowerMod1 < 0 ? (_radioPowerMod1 + 256) & 0xFF : _radioPowerMod1;
    payload[6] = _radioPowerMod2 < 0 ? (_radioPowerMod2 + 256) & 0xFF : _radioPowerMod2;
    payload[7] = _cpuTempOffsetDeciC & 0xFF;
    payload[8] = (_cpuTempOffsetDeciC >> 8) & 0xFF;

    final command = FirmwareBinaryProtocol.createSettingsUpdateCommand(payload);
    await sendBinaryCommand(command);
    _log('command', 'Settings sent to device: rssi=$_scannerRssi power=$_bruterPower delay=$_bruterDelayMs reps=$_bruterRepeats mod1=$_radioPowerMod1 mod2=$_radioPowerMod2 tempOff=$_cpuTempOffsetDeciC');
    notifyListeners();
  }

  /// Last bruter completion status (for UI notification)
  int _lastBruterCompletionStatus = -1;
  int get lastBruterCompletionStatus => _lastBruterCompletionStatus;
  int _lastBruterCompletionMenuId = 0;
  int get lastBruterCompletionMenuId => _lastBruterCompletionMenuId;
  
  /// Clear completion notification (called by UI after displaying)
  void clearBruterCompletion() {
    _lastBruterCompletionStatus = -1;
    _lastBruterCompletionMenuId = 0;
  }

  Future<void> sendGetStateCommand() async {
    final command = FirmwareBinaryProtocol.createGetStateCommand();
    await sendBinaryCommand(command);
  }



  /// Handle module mode switch
  /// Handle binary message (0x80-0xFF)
  void _handleBinaryMessage(Uint8List data) {
    // NOTE: Chunk buffers are now cleaned up BEFORE calling _handleBinaryMessage
    // So this check should rarely trigger, but we keep it as a safety measure
    // Only warn if buffers are active for a long time (might indicate stuck state)
    if (_chunkData.isNotEmpty) {
      // Don't return - allow processing since buffers should be cleaned up before this call
    }
    
    try {
      // Parse binary message and convert to JSON-compatible format
      final jsonData = BinaryMessageParser.parseBinaryMessage(data);
      
      if (jsonData != null) {
        _log('debug', 'Binary message received', details: '${jsonData['type']}: ${data.length} bytes');
        
        // Handle as if it was JSON (maintains compatibility with existing code)
        _handleCompleteResponse(jsonData);
      } else {
        _log('warning', 'Unknown binary message type', details: '0x${data[0].toRadixString(16)}');
      }
    } catch (e, stackTrace) {
      _log('error', 'Binary message parse error', details: '$e\n$stackTrace');
    }
  }

  void _handleModeSwitch(Map<String, dynamic> modeData) {
    print('_handleModeSwitch called with data: $modeData');
    int module = int.tryParse(modeData['module']?.toString() ?? '0') ?? 0;
    String mode = modeData['mode'] ?? 'Unknown';
    String previousMode = modeData['previousMode'] ?? 'Unknown';
    
    print('Mode switch: module=$module, mode=$mode, previous=$previousMode');
    print('Current cc1101Modules state before update: ${cc1101Modules?.map((m) => 'Module ${m['id']}: ${m['mode']}').join(', ')}');
    
    // Update recording state
    if (mode == 'RecordSignal') {
      isRecording[module] = true;
      print('Module $module started recording');
    } else if (mode == 'Idle') {
      isRecording[module] = false;
      print('Module $module stopped recording');
    }
    
    // Update jamming state
    if (mode == 'Jamming') {
      isJamming[module] = true;
      print('Module $module started jamming');
    } else if (mode == 'Idle') {
      isJamming[module] = false;
      if (previousMode == 'Jamming') {
        print('Module $module stopped jamming');
      }
    }
    
    // Update frequency search state
    if (mode == 'DetectSignal') {
      // Always set frequency search flag on transition to DetectSignal
      isFrequencySearching[module] = true;
      print('Module $module frequency search started (ModeSwitch to DetectSignal)');
      _log('info', 'Frequency search started', details: 'Module: $module');
    } else if (mode == 'Idle' && previousMode == 'DetectSignal') {
      // Simplified logic: on transition from DetectSignal to Idle, reset flag immediately
      // Controller automatically transitions to Idle after signal detection
      if (isFrequencySearching[module] == true) {
        isFrequencySearching[module] = false;
        print('Module $module frequency search stopped (ModeSwitch from DetectSignal to Idle)');
        _log('info', 'Frequency search stopped', details: 'Module: $module');
      }
    } else if (mode == 'Idle') {
      // On transition to Idle from another mode, also reset if flag was set
      if (isFrequencySearching[module] == true) {
        isFrequencySearching[module] = false;
        print('Module $module frequency search stopped (ModeSwitch to Idle)');
      }
    }
    
    // Update module state in cc1101Modules for UI display
    if (cc1101Modules != null && module < cc1101Modules!.length) {
      cc1101Modules![module]['mode'] = mode;
      print('Updated module $module mode in cc1101Modules to: $mode');
    } else {
      // If cc1101Modules is not initialized, create basic structure
      cc1101Modules ??= [];
      // Ensure there are enough elements
      while (cc1101Modules!.length <= module) {
        cc1101Modules!.add({
          'id': cc1101Modules!.length,
          'mode': 'Unknown',
        });
      }
      cc1101Modules![module]['mode'] = mode;
      cc1101Modules![module]['id'] = module;
      print('Created/updated module $module in cc1101Modules with mode: $mode');
    }
    
    // Notify UI of changes
    notifyListeners();
  }

  /// Handle device state response
  void _handleStateResponse(Map<String, dynamic> stateData) {
    // Check if data is nested under 'data' key
    Map<String, dynamic> actualData = stateData;
    if (stateData.containsKey('data') && stateData['data'] is Map<String, dynamic>) {
      actualData = Map<String, dynamic>.from(stateData['data']);
    }
    
    // Update device state
    if (actualData['device'] != null) {
      deviceStatus = actualData['device'];
      freeHeap = actualData['device']['freeHeap'];
      final dynamic t = actualData['device']['cpuTempC'];
      cpuTempC = t is num ? t.toDouble() : null;
      final dynamic c0 = actualData['device']['core0Mhz'];
      final dynamic c1 = actualData['device']['core1Mhz'];
      core0Mhz = c0 is num ? c0.toInt() : null;
      core1Mhz = c1 is num ? c1.toInt() : null;
    }
    
    if (actualData['cc1101'] != null) {
      cc1101Modules = List<Map<String, dynamic>>.from(actualData['cc1101']);
      
      // Update recording state based on current module modes
      for (var module in cc1101Modules!) {
        int moduleId = module['id'] ?? 0;
        String mode = module['mode'] ?? 'Unknown';
        
        print('Module $moduleId: mode=$mode');
        
        // Update recording state
        if (mode == 'RecordSignal') {
          isRecording[moduleId] = true;
          print('Module $moduleId is recording');
        } else {
          isRecording[moduleId] = false;
          print('Module $moduleId is not recording');
        }
        
        // Update jamming state
        if (mode == 'Jamming') {
          isJamming[moduleId] = true;
          print('Module $moduleId is jamming');
        } else {
          isJamming[moduleId] = false;
          print('Module $moduleId is not jamming');
        }
      }
      
      print('Final recording state: $isRecording');
    }
    
    print('Calling notifyListeners()');
    notifyListeners();
  }

  /// Check recording state for module
  bool isModuleRecording(int module) {
    return isRecording[module] ?? false;
  }

  /// Check frequency search state for module
  bool isModuleFrequencySearching(int module) {
    return isFrequencySearching[module] ?? false;
  }

  /// Check jamming state for module
  bool isModuleJamming(int module) {
    return isJamming[module] ?? false;
  }

  /// Rename file
  Future<bool> renameFile(String oldPath, String newName, {int? pathType}) async {
    if (!isConnected || txCharacteristic == null) return false;
    
    try {
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      String relativePath = oldPath;
      
      // Extract relative path (remove /DATA/xxx prefix if present)
      if (relativePath.startsWith('/DATA/')) {
        // Find the base path and extract the rest
        final parts = relativePath.split('/');
        // /DATA/RECORDS/subdir/file.txt -> subdir/file.txt
        if (parts.length > 3) {
          relativePath = parts.sublist(3).join('/');
        } else {
          relativePath = parts.last;
        }
      }
      
      // Build new path by preserving directory structure
      // e.g., "subdir/file.txt" -> "subdir/newname.txt"
      String newPath;
      final lastSlash = relativePath.lastIndexOf('/');
      if (lastSlash >= 0) {
        // File is in a subdirectory - preserve the path
        final directory = relativePath.substring(0, lastSlash);
        newPath = '$directory/$newName';
      } else {
        // File is in root
        newPath = newName;
      }
      
      _log('command', 'Renaming file: $relativePath -> $newPath (pathType: $effectivePathType)');
      
      // Use binary command with pathType
      final command = FirmwareBinaryProtocol.createRenameFileCommand(relativePath, newPath, pathType: effectivePathType);
      
      // Create completer to wait for response
      _pendingRenameCompleter?.completeError('New rename operation started');
      _pendingRenameCompleter = Completer<Map<String, dynamic>>();
      
      await sendBinaryCommand(command);
      
      // Set timeout
      Timer timeout = Timer(const Duration(seconds: 10), () {
        if (_pendingRenameCompleter != null && !_pendingRenameCompleter!.isCompleted) {
          _pendingRenameCompleter!.completeError('Timeout waiting for rename response');
          _pendingRenameCompleter = null;
        }
      });
      
      try {
        // Wait for response
        final response = await _pendingRenameCompleter!.future;
        timeout.cancel();
        
        final success = response['success'] ?? false;
        if (success) {
          _log('info', 'File renamed successfully');
          await refreshFileList(); // Refresh file list
          return true;
        } else {
          _log('error', 'Failed to rename file: ${response['error']}');
          return false;
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error waiting for rename response: $e');
        return false;
      } finally {
        _pendingRenameCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error renaming file: $e');
      return false;
    }
  }

  /// Delete file
  Future<bool> deleteFile(String filePath, {int? pathType}) async {
    if (!isConnected || txCharacteristic == null) return false;
    
    try {
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      String fileName = filePath;
      
      // Extract filename if full path provided
      if (filePath.startsWith('/DATA/')) {
        fileName = filePath.split('/').last;
      }
      
      _log('command', 'Deleting file: $fileName (pathType: $effectivePathType)');
      
      // Use FirmwareBinaryProtocol to create properly formatted command
      final command = FirmwareBinaryProtocol.createRemoveFileCommand(fileName, pathType: effectivePathType);
      
      // Create completer to wait for firmware response
      _pendingDeleteCompleter?.completeError('New delete operation started');
      _pendingDeleteCompleter = Completer<Map<String, dynamic>>();
      
      await sendBinaryCommand(command);
      
      // Set timeout
      Timer timeout = Timer(const Duration(seconds: 10), () {
        if (_pendingDeleteCompleter != null && !_pendingDeleteCompleter!.isCompleted) {
          _pendingDeleteCompleter!.completeError('Timeout waiting for delete response');
          _pendingDeleteCompleter = null;
        }
      });
      
      try {
        final response = await _pendingDeleteCompleter!.future;
        timeout.cancel();
        
        final success = response['success'] ?? false;
        if (success) {
          _log('info', 'File deleted successfully');
          await refreshFileList();
          return true;
        } else {
          _log('error', 'Failed to delete file: ${response['error']}');
          return false;
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error waiting for delete response: $e');
        return false;
      } finally {
        _pendingDeleteCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error deleting file: $e');
      return false;
    }
  }

  /// Move file
  Future<bool> moveFile(String sourcePath, String destinationPath, {int? sourcePathType, int? destPathType}) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    try {
      // Use provided pathTypes or current (for backward compatibility)
      int effectiveSourcePathType = sourcePathType ?? currentPathType;
      int effectiveDestPathType = destPathType ?? currentPathType;
      
      _log('command', 'Moving file: $sourcePath -> $destinationPath (sourcePathType: $effectiveSourcePathType, destPathType: $effectiveDestPathType)');
      
      // Create completer for move response
      _pendingMoveCompleter?.completeError('New move request started');
      _pendingMoveCompleter = Completer<Map<String, dynamic>>();
      
      // Create binary command with separate pathTypes
      final command = FirmwareBinaryProtocol.createMoveFileCommand(
        sourcePath,
        destinationPath,
        sourcePathType: effectiveSourcePathType,
        destPathType: effectiveDestPathType,
      );
      
      // Send command
      await sendBinaryCommand(command);
      
      // Wait for response with timeout
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingMoveCompleter != null && !_pendingMoveCompleter!.isCompleted) {
          _pendingMoveCompleter!.completeError('Move timeout');
          _pendingMoveCompleter = null;
        }
      });
      
      try {
        final response = await _pendingMoveCompleter!.future;
        timeout.cancel();
        
        if (response['success'] == true) {
          _log('info', 'File moved successfully');
          
          // Extract destination path from response
          String? destPath = response['path'] as String?;
          if (destPath != null) {
            // Extract relative directory path from full path (removes /DATA/RECORDS etc.)
            // Use effectiveDestPathType (destination storage) for path extraction
            String destDirectory = _extractRelativePath(destPath, effectiveDestPathType);
            
            // Check if we're currently viewing the destination directory
            if (destDirectory == currentPath) {
              // Same directory - refresh the list
              await refreshFileList(forceRefresh: true);
            } else {
              // Different directory - invalidate cache for destination
              invalidateCacheForPath(destDirectory);
            }
          } else {
            // If dest path not in response, just refresh current directory
            await refreshFileList(forceRefresh: true);
          }
          
          return true;
        } else {
          String error = response['error'] ?? 'Unknown error';
          _log('error', 'Failed to move file: $error');
          throw Exception(error);
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error moving file: $e');
        rethrow;
      } finally {
        _pendingMoveCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error moving file: $e');
      rethrow;
    }
  }

  /// Copy file
  Completer<Map<String, dynamic>>? _pendingCopyCompleter;
  
  /// Move file
  Completer<Map<String, dynamic>>? _pendingMoveCompleter;

  Future<bool> copyFile(String sourcePath, String destinationPath) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    try {
      _log('command', 'Copying file: $sourcePath -> $destinationPath');
      
      // Create completer for copy response
      _pendingCopyCompleter?.completeError('New copy request started');
      _pendingCopyCompleter = Completer<Map<String, dynamic>>();
      
      // Create binary command
      final command = FirmwareBinaryProtocol.createCopyFileCommand(
        sourcePath,
        destinationPath,
        pathType: currentPathType,
      );
      
      // Send command
      await sendBinaryCommand(command);
      
      // Wait for response with timeout
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingCopyCompleter != null && !_pendingCopyCompleter!.isCompleted) {
          _pendingCopyCompleter!.completeError('Copy timeout');
          _pendingCopyCompleter = null;
        }
      });
      
      try {
        final response = await _pendingCopyCompleter!.future;
        timeout.cancel();
        
        if (response['success'] == true) {
          _log('info', 'File copied successfully');
          
          // Extract destination path from response
          String? destPath = response['dest'] as String?;
          if (destPath != null) {
            // Extract relative directory path from full path (removes /DATA/RECORDS etc.)
            String destDirectory = _extractRelativePath(destPath, currentPathType);
            
            // Check if we're currently viewing the destination directory
            if (destDirectory == currentPath) {
              // Same directory - refresh the list
              await refreshFileList(forceRefresh: true);
            } else {
              // Different directory - invalidate cache for destination
              invalidateCacheForPath(destDirectory);
            }
          } else {
            // If dest path not in response, just refresh current directory
            await refreshFileList(forceRefresh: true);
          }
          
          return true;
        } else {
          final error = response['error'] ?? 'Copy failed';
          _log('error', 'Failed to copy file: $error');
          throw Exception(error);
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error copying file: $e');
        rethrow;
      } finally {
        _pendingCopyCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error copying file: $e');
      rethrow;
    }
  }

  /// Create directory
  Future<bool> createDirectory(String path, {int? pathType}) async {
    if (!isConnected || txCharacteristic == null) return false;
    
    try {
      // Use provided pathType or current
      int effectivePathType = pathType ?? currentPathType;
      String dirName = path;
      
      // Extract directory name if full path provided
      if (path.startsWith('/DATA/')) {
        dirName = path.split('/').last;
      }
      
      _log('command', 'Creating directory: $dirName (pathType: $effectivePathType)');
      
      // Use binary command with pathType
      final command = FirmwareBinaryProtocol.createCreateDirectoryCommand(dirName, pathType: effectivePathType);
      
      // Create completer to wait for firmware response
      _pendingMkdirCompleter?.completeError('New mkdir operation started');
      _pendingMkdirCompleter = Completer<Map<String, dynamic>>();
      
      await sendBinaryCommand(command);
      
      // Set timeout
      Timer timeout = Timer(const Duration(seconds: 10), () {
        if (_pendingMkdirCompleter != null && !_pendingMkdirCompleter!.isCompleted) {
          _pendingMkdirCompleter!.completeError('Timeout waiting for mkdir response');
          _pendingMkdirCompleter = null;
        }
      });
      
      try {
        final response = await _pendingMkdirCompleter!.future;
        timeout.cancel();
        
        final success = response['success'] ?? false;
        if (success) {
          _log('info', 'Directory created successfully');
          await refreshFileList();
          return true;
        } else {
          _log('error', 'Failed to create directory: ${response['error']}');
          return false;
        }
      } catch (e) {
        timeout.cancel();
        _log('error', 'Error waiting for mkdir response: $e');
        return false;
      } finally {
        _pendingMkdirCompleter = null;
      }
    } catch (e) {
      _log('error', 'Error creating directory: $e');
      return false;
    }
  }

  /// Get directory tree for selected storage
  Future<List<DirectoryTreeNode>> getDirectoryTree({int pathType = 0}) async {
    if (!isConnected || txCharacteristic == null) {
      throw Exception('Device not connected');
    }
    
    _log('info', 'Getting directory tree', details: 'pathType: $pathType');
    
    // Cancel previous request if exists
    if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
      _pendingDirectoryTreeCompleter!.completeError('New directory tree request started');
    }
    
    // Reset streaming state
    _isStreamingDirectoryTree = false;
    _streamingDirectoryTreeBuffer.clear();
    _streamingTotalDirs = 0;
    
    _pendingDirectoryTreeCompleter = Completer<Map<String, dynamic>>();
    print('Created directory tree completer for pathType: $pathType');
    
    // Send directory tree request command
    final command = FirmwareBinaryProtocol.createGetDirectoryTreeCommand(pathType: pathType);
    print('Sending getDirectoryTree command (pathType: $pathType, command length: ${command.length})');
    await sendBinaryCommand(command);
    print('Command sent, waiting for response...');
    
    // Set timeout
    Timer timeout = Timer(const Duration(seconds: 30), () {
      if (_pendingDirectoryTreeCompleter != null && !_pendingDirectoryTreeCompleter!.isCompleted) {
        _pendingDirectoryTreeCompleter!.completeError('Timeout waiting for directory tree');
        _pendingDirectoryTreeCompleter = null;
      }
    });
    
    try {
      final response = await _pendingDirectoryTreeCompleter!.future;
      timeout.cancel();
      
      print('Received directory tree response: $response');
      
      // Parse response
      if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
        Map<String, dynamic> data = response['data'];
        
        if (data.containsKey('error')) {
          throw Exception('Error getting directory tree: ${data['error']}');
        }
        
        if (data.containsKey('paths') && data['paths'] is List) {
          List<dynamic> paths = data['paths'];
          print('Building tree from ${paths.length} paths');
          
          // Rebuild tree from flat paths
          List<DirectoryTreeNode> tree = _rebuildDirectoryTree(paths.cast<String>(), pathType);
          
          _log('info', 'Directory tree received', details: '${paths.length} directories');
          return tree;
        } else {
          print('Response data missing paths field. Keys: ${data.keys.toList()}');
        }
      } else {
        print('Response missing data field or data is not Map. Response keys: ${response.keys.toList()}');
      }
      
      throw Exception('Invalid directory tree response format: $response');
    } catch (e) {
      timeout.cancel();
      _log('error', 'Error getting directory tree: $e');
      rethrow;
    } finally {
      _pendingDirectoryTreeCompleter = null;
    }
  }

  /// Rebuild directory tree from flat list of absolute paths
  List<DirectoryTreeNode> _rebuildDirectoryTree(List<String> paths, int pathType) {
    Map<String, DirectoryTreeNode> nodeMap = {};
    List<DirectoryTreeNode> roots = [];
    
    // Sort paths by length to process parents before children
    paths.sort((a, b) => a.length.compareTo(b.length));
    
    for (String fullPath in paths) {
      // Get base path based on pathType
      String basePath = _getBasePathForPathType(pathType) ?? '';
      
      // Extract relative path from absolute path
      String relativePath = fullPath;
      if (fullPath.startsWith(basePath)) {
        relativePath = fullPath.substring(basePath.length);
      }
      if (!relativePath.startsWith('/')) relativePath = '/$relativePath';
      
      String name = relativePath.split('/').last;
      if (name.isEmpty && relativePath == '/') name = '/';
      
      DirectoryTreeNode node = DirectoryTreeNode(
        name: name,
        path: relativePath,
        directories: [],
      );
      
      nodeMap[fullPath] = node;
      
      // Find parent path
      int lastSlash = fullPath.lastIndexOf('/');
      if (lastSlash != -1) {
        String parentPath = fullPath.substring(0, lastSlash);
        if (nodeMap.containsKey(parentPath)) {
          nodeMap[parentPath]!.directories.add(node);
        } else {
          // No parent found in map, it's a root for our purposes
          // (though it might be deep in the filesystem)
          if (!roots.contains(node)) roots.add(node);
        }
      } else {
        roots.add(node);
      }
    }
    
    return roots;
  }

  /// Check module availability for operations
  bool isModuleAvailable(int moduleIndex) {
    if (cc1101Modules == null || moduleIndex >= cc1101Modules!.length) {
      return false;
    }
    
    final module = cc1101Modules![moduleIndex];
    final mode = module['mode']?.toString().toLowerCase() ?? 'unknown';
    
    // Module is available only if it's in Idle mode
    return mode == 'idle';
  }

  /// Get list of available modules
  List<int> getAvailableModules() {
    if (cc1101Modules == null) return [];
    
    final availableModules = <int>[];
    for (int i = 0; i < cc1101Modules!.length; i++) {
      if (isModuleAvailable(i)) {
        availableModules.add(i);
      }
    }
    
    return availableModules;
  }

  /// Get module state
  String getModuleStatus(int moduleIndex) {
    if (cc1101Modules == null || moduleIndex >= cc1101Modules!.length) {
      return 'Unknown';
    }
    
    return cc1101Modules![moduleIndex]['mode']?.toString() ?? 'Unknown';
  }

  /// Wait for device response — DEPRECATED, use Completer pattern instead\n  /// Kept only for backward compatibility; should not be used.\n  @Deprecated('Use Completer pattern like _pendingRenameCompleter instead')
  Future<Map<String, dynamic>?> _waitForResponse() async {
    final completer = Completer<Map<String, dynamic>?>();
    
    // Set timeout
    Timer timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    
    try {
      // In a real implementation, there should be a response waiting mechanism here
      // For now, return a stub
      await Future.delayed(const Duration(milliseconds: 100));
      return {'type': 'success', 'success': true};
    } finally {
      timeout.cancel();
    }
  }

  /// Save file to signals directory with chosen name
  Future<void> saveFileToSignalsWithName(String sourcePath, String targetName, {int pathType = 1, DateTime? preserveDate}) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    try {
      // Use FirmwareBinaryProtocol to create properly formatted command
      final command = FirmwareBinaryProtocol.createSaveToSignalsWithNameCommand(
        sourcePath, 
        targetName, 
        pathType: pathType,
        preserveDate: preserveDate,
      );
      
      await sendBinaryCommand(command);
      _log('info', 'File save with name command sent', details: 'Source: $sourcePath, Target: $targetName, PathType: $pathType${preserveDate != null ? ", Date: $preserveDate" : ""}');
    } catch (e) {
      _log('error', 'Failed to send save with name command', details: e.toString());
      rethrow;
    }
  }

  /// Start frequency search for module
  Future<void> startFrequencySearch(int module, {int minRssi = -65}) async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    try {
      // Set pending frequency searching flag (will be confirmed by ModeSwitch)
      isFrequencySearching[module] = true;
      notifyListeners();
      
      final command = FirmwareBinaryProtocol.createFrequencySearchCommand(module, minRssi);
      await sendBinaryCommand(command);
      _log('info', 'Frequency search command sent', details: 'Module: $module, MinRSSI: $minRssi');
    } catch (e) {
      // Reset flag on error
      isFrequencySearching[module] = false;
      notifyListeners();
      _log('error', 'Failed to start frequency search', details: e.toString());
      rethrow;
    }
  }

  @override
  void dispose() {
    // Cancel all BLE stream subscriptions
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _rxValueSubscription?.cancel();
    _otaReconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }
}

