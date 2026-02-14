import 'dart:typed_data';

/// Binary message types from firmware (0x80-0xFF)
enum BinaryMessageType {
  modeSwitch(0x80),
  status(0x81),
  heartbeat(0x82),
  signalDetected(0x90),
  signalRecorded(0x91),
  signalSent(0x92),
  signalSendError(0x93),
  // NOTE: 0x94 (frequencySearch) was never sent by firmware.
  // Frequency search results arrive via signalDetected (0x90) using the same
  // CC1101Worker::detectSignal → signalDetectedCallback pipeline.
  // Enum kept for protocol documentation only.
  frequencySearch(0x94),
  fileContent(0xA0), // RAW file content (NO JSON!)
  fileList(0xA1),    // File list BINARY
  directoryTree(0xA2),
  fileActionResult(0xA3),
  bruterProgress(0xB0),  // Brute force progress update
  bruterComplete(0xB1),  // Brute force attack finished
  bruterPaused(0xB2),    // Brute force attack paused (state saved)
  bruterResumed(0xB3),   // Brute force attack resumed from saved state
  bruterStateAvail(0xB4),// A resumable saved state exists on device
  settingsSync(0xC0),    // Device settings sync (sent on connect)
  versionInfo(0xC2),     // Firmware version info (sent on connect)
  batteryStatus(0xC3),   // Battery voltage and percentage (periodic + on connect)
  sdrStatus(0xC4),        // SDR mode status (active, submode, freq, mod)
  // NRF24 notifications (0xD0-0xD5)
  nrfDeviceFound(0xD0),     // MouseJack target discovered
  nrfAttackComplete(0xD1),  // NRF attack finished
  nrfScanComplete(0xD2),    // MouseJack scan completed
  nrfScanStatus(0xD3),      // Scan status / target list
  nrfSpectrumData(0xD4),    // Spectrum analyzer 126-channel levels (full 2.4 GHz ISM band)
  nrfJamStatus(0xD5),       // Jammer status update
  nrfJamModeConfig(0xD6),   // Per-mode config response/update
  nrfJamModeInfo(0xD7),     // Mode info (name, description, channels)
  // OTA notifications (0xE0-0xE2)
  otaProgress(0xE0),        // OTA write progress
  otaComplete(0xE1),        // OTA finished successfully
  otaError(0xE2),           // OTA error
  // Device identity
  deviceName(0xC7),         // BLE device name from device
  // Device status extensions (sent on connect / GetState)
  hwButtonStatus(0xC8),     // HW button config sync
  sdStatus(0xC9),           // SD card storage info
  nrfModuleStatus(0xCA),    // nRF24 module presence/state
  error(0xF0),
  lowMemory(0xF1),
  commandSuccess(0xF2),
  commandError(0xF3);

  final int value;
  const BinaryMessageType(this.value);

  static BinaryMessageType? fromValue(int value) {
    for (var type in BinaryMessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// File entry from binary format
class BinaryFileEntry {
  final String name;
  final bool isDirectory;
  final int size;       // Only for files
  final int timestamp;  // Only for files (Unix timestamp in seconds)

  BinaryFileEntry({
    required this.name,
    required this.isDirectory,
    this.size = 0,
    this.timestamp = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': isDirectory ? 'directory' : 'file',
      'size': size,
      'date': timestamp.toString(),
    };
  }
}

/// File list message - STREAMING BINARY PROTOCOL (no JSON!)
/// 
/// Format (each message):
/// [0xA1][pathLen:1][path:pathLen][flags:1][totalFiles:2][fileCount:1][files...]
///
/// flags byte:
///   bit 0 (0x01): hasMore - 1=more messages coming, 0=last message
///   bit 7 (0x80): error - if set, bits 0-6 contain error code
///
/// totalFiles: total number of files in directory (for progress calculation)
/// fileCount: number of files in THIS message
///
/// For each file:
///   [nameLen:1][name:nameLen][fileFlags:1]
///   If file (fileFlags & 0x01 == 0):
///     [size:4][date:4]  (little-endian)
class BinaryFileList {
  final String path;
  final bool hasMore;         // true if more messages coming
  final bool isError;         // true if this is an error response
  final int errorCode;        // Error code (valid only if isError)
  final int totalFiles;       // Total files in directory (for progress)
  final List<BinaryFileEntry> files;

  BinaryFileList({
    required this.path,
    required this.hasMore,
    required this.isError,
    required this.errorCode,
    required this.totalFiles,
    required this.files,
  });

  factory BinaryFileList.parse(Uint8List data) {
    if (data.length < 6) {
      throw Exception('Invalid BinaryFileList data length: ${data.length}');
    }

    int offset = 1; // Skip 0xA1
    int pathLen = data[offset++];
    
    // Header: type + pathLen + path + flags + totalFiles(2) + fileCount
    if (data.length < 2 + pathLen + 4) {
      throw Exception('Invalid BinaryFileList: insufficient data for header');
    }
    
    String path = String.fromCharCodes(data.sublist(offset, offset + pathLen));
    offset += pathLen;
    
    int flags = data[offset++];
    bool hasMore = (flags & 0x01) != 0;
    bool isError = (flags & 0x80) != 0;
    int errorCode = isError ? (flags & 0x7F) : 0;
    
    // Total files (2 bytes, little-endian)
    int totalFiles = data[offset] | (data[offset + 1] << 8);
    offset += 2;
    
    int fileCount = data[offset++];
    
    // Parse file entries
    List<BinaryFileEntry> files = [];
    
    if (!isError) {
      for (int i = 0; i < fileCount && offset < data.length; i++) {
        if (offset >= data.length) break;
        
        int nameLen = data[offset++];
        if (offset + nameLen > data.length) break;
        
        String name = String.fromCharCodes(data.sublist(offset, offset + nameLen));
        offset += nameLen;
        
        if (offset >= data.length) break;
        int fileFlags = data[offset++];
        bool isDirectory = (fileFlags & 0x01) != 0;
        
        int size = 0;
        int timestamp = 0;
        
        if (!isDirectory) {
          if (offset + 8 > data.length) break;
          // Read size (4 bytes, little-endian)
          size = data[offset] | 
                 (data[offset + 1] << 8) | 
                 (data[offset + 2] << 16) | 
                 (data[offset + 3] << 24);
          offset += 4;
          // Read date (4 bytes, little-endian)
          timestamp = data[offset] | 
                      (data[offset + 1] << 8) | 
                      (data[offset + 2] << 16) | 
                      (data[offset + 3] << 24);
          offset += 4;
        }
        
        files.add(BinaryFileEntry(
          name: name,
          isDirectory: isDirectory,
          size: size,
          timestamp: timestamp,
        ));
      }
    }

    return BinaryFileList(
      path: path,
      hasMore: hasMore,
      isError: isError,
      errorCode: errorCode,
      totalFiles: totalFiles,
      files: files,
    );
  }

  /// Convert to format compatible with existing code
  Map<String, dynamic> toJson() {
    if (isError) {
      return {
        'action': 'list',
        'error': _getErrorMessage(errorCode),
        'files': [],
        'streaming': false,
        'totalFiles': 0,
      };
    }
    
    return {
      'action': 'list',
      'files': files.map((f) => f.toJson()).toList(),
      'streaming': hasMore,
      'totalFiles': totalFiles,
    };
  }
  
  static String _getErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1: return 'Insufficient memory';
      case 2: return 'Failed to create directory';
      case 3: return 'Failed to open directory';
      case 4: return 'Path is not a directory';
      case 5: return 'Unknown error';
      default: return 'Error code: $errorCode';
    }
  }
}

/// File content message (variable length)
/// Format: [0xA0][pathLen:1][path:variable][fileSize:4][content:variable]
class BinaryFileContent {
  final String path;
  final int fileSize;
  final Uint8List content;

  BinaryFileContent({
    required this.path,
    required this.fileSize,
    required this.content,
  });

  factory BinaryFileContent.parse(Uint8List data) {
    if (data.length < 6) {
      throw Exception('Invalid BinaryFileContent data length: ${data.length}');
    }

    int offset = 1; // Skip 0xA0
    int pathLen = data[offset++];
    
    if (data.length < 2 + pathLen + 4) {
      throw Exception('Invalid BinaryFileContent: insufficient data for path and size');
    }
    
    String path = String.fromCharCodes(data.sublist(offset, offset + pathLen));
    offset += pathLen;
    
    // Read file size (4 bytes, little-endian)
    int fileSize = data[offset] | 
                   (data[offset + 1] << 8) | 
                   (data[offset + 2] << 16) | 
                   (data[offset + 3] << 24);
    offset += 4;
    
    // Read file content
    Uint8List content = data.sublist(offset);

    return BinaryFileContent(
      path: path,
      fileSize: fileSize,
      content: content,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': 'load',
      'path': path,
      'size': fileSize,
      'success': true,
      'content': String.fromCharCodes(content), // Convert bytes to string
    };
  }
}

/// Signal detected message (12 bytes)
class BinarySignalDetected {
  final int module;
  final int frequency;
  final int rssi;

  BinarySignalDetected({
    required this.module,
    required this.frequency,
    required this.rssi,
  });

  factory BinarySignalDetected.parse(Uint8List data) {
    if (data.length < 12) {
      throw Exception('Invalid BinarySignalDetected data length: ${data.length}');
    }

    final byteData = ByteData.sublistView(data);
    return BinarySignalDetected(
      module: data[1],
      frequency: byteData.getUint32(4, Endian.little),
      rssi: byteData.getInt16(8, Endian.little),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module.toString(),
      'frequency': (frequency / 1000000).toStringAsFixed(2),
      'rssi': rssi.toString(),
      'isBackgroundScanner': 'false', // Default for now
    };
  }
}

/// Signal recorded message
class BinarySignalRecorded {
  final int module;
  final String filename;

  BinarySignalRecorded({
    required this.module,
    required this.filename,
  });

  factory BinarySignalRecorded.parse(Uint8List data) {
    if (data.length < 3) {
      throw Exception('Invalid BinarySignalRecorded data length: ${data.length}');
    }

    int module = data[1];
    int nameLen = data[2];
    String name = String.fromCharCodes(data.sublist(3, 3 + nameLen));

    return BinarySignalRecorded(
      module: module,
      filename: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'module': module,
    };
  }
}

/// Signal sent message
class BinarySignalSent {
  final int module;
  final String filename;

  BinarySignalSent({
    required this.module,
    required this.filename,
  });

  factory BinarySignalSent.parse(Uint8List data) {
    if (data.length < 3) {
      return BinarySignalSent(module: 0, filename: '');
    }
    int module = data[1];
    int nameLen = data[2];
    if (data.length < 3 + nameLen) {
      return BinarySignalSent(module: module, filename: '');
    }
    String name = String.fromCharCodes(data.sublist(3, 3 + nameLen));

    return BinarySignalSent(module: module, filename: name);
  }

  Map<String, dynamic> toJson() {
    return {
      'file': filename,
      'module': module,
    };
  }
}

/// File action result message
class BinaryFileActionResult {
  final int action;
  final bool success;
  final int errorCode;
  final String path;

  BinaryFileActionResult({
    required this.action,
    required this.success,
    required this.errorCode,
    required this.path,
  });

  factory BinaryFileActionResult.parse(Uint8List data) {
    int action = data[1];
    bool success = data[2] == 0;
    int errorCode = data[3];
    int pathLen = data[4];
    String path = '';
    if (pathLen > 0) {
      path = String.fromCharCodes(data.sublist(5, 5 + pathLen));
    }

    return BinaryFileActionResult(
      action: action,
      success: success,
      errorCode: errorCode,
      path: path,
    );
  }

  String getActionString() {
    switch (action) {
      case 1: return 'delete';
      case 2: return 'rename';
      case 3: return 'create-directory';
      case 4: return 'copy';
      case 5: return 'move';
      case 6: return 'tree';
      case 7: return 'load';
      default: return 'unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'action': getActionString(),
      'success': success,
      'path': path,
      'error': success ? null : _getErrorMessage(errorCode),
    };
  }

  static String _getErrorMessage(int code) {
    switch (code) {
      case 1: return 'Insufficient data';
      case 2: return 'Path length mismatch';
      case 3: return 'Not found';
      case 4: return 'Delete failed';
      case 5: return 'To length missing';
      case 6: return 'Rename failed';
      case 7: return 'Mkdir failed';
      case 13: return 'Failed to open file';
      case 14: return 'Path too long';
      case 15: return 'BLE adapter not found';
      default: return 'Error $code';
    }
  }
}

/// Directory tree message - STREAMING BINARY PROTOCOL
/// 
/// Format (each message):
/// [0xA2][pathType:1][flags:1][totalDirs:2][dirCount:2][paths...]
///
/// flags byte:
///   bit 0 (0x01): hasMore - 1=more messages coming, 0=last message
///   bit 7 (0x80): error - if set, bits 0-6 contain error code
///
/// totalDirs: total number of directories (for progress calculation)
/// dirCount: number of directories in THIS message (2 bytes, little-endian)
///
/// For each path:
///   [pathLen:1][path:pathLen]
class BinaryDirectoryTree {
  final int pathType;
  final bool hasMore;         // true if more messages coming
  final bool isError;         // true if this is an error response
  final int errorCode;        // Error code (valid only if isError)
  final int totalDirs;        // Total directories (for progress)
  final List<String> paths;

  BinaryDirectoryTree({
    required this.pathType,
    required this.hasMore,
    required this.isError,
    required this.errorCode,
    required this.totalDirs,
    required this.paths,
  });

  factory BinaryDirectoryTree.parse(Uint8List data) {
    if (data.length < 7) {
      throw Exception('Invalid BinaryDirectoryTree data length: ${data.length}');
    }

    int pathType = data[1];
    int flags = data[2];
    bool hasMore = (flags & 0x01) != 0;
    bool isError = (flags & 0x80) != 0;
    int errorCode = isError ? (flags & 0x7F) : 0;
    
    // Total dirs (2 bytes, little-endian)
    int totalDirs = data[3] | (data[4] << 8);
    
    // Dir count (2 bytes, little-endian)
    int dirCount = data[5] | (data[6] << 8);
    
    int offset = 7;
    List<String> paths = [];

    if (!isError) {
      for (int i = 0; i < dirCount && offset < data.length; i++) {
        if (offset >= data.length) break;
        
        int pathLen = data[offset++];
        if (offset + pathLen > data.length) break;
        
        paths.add(String.fromCharCodes(data.sublist(offset, offset + pathLen)));
        offset += pathLen;
      }
    }

    return BinaryDirectoryTree(
      pathType: pathType,
      hasMore: hasMore,
      isError: isError,
      errorCode: errorCode,
      totalDirs: totalDirs,
      paths: paths,
    );
  }

  Map<String, dynamic> toJson() {
    if (isError) {
      return {
        'pathType': pathType,
        'error': _getErrorMessage(errorCode),
        'paths': [],
        'streaming': false,
        'totalDirs': 0,
      };
    }
    
    return {
      'pathType': pathType,
      'paths': paths,
      'streaming': hasMore,
      'totalDirs': totalDirs,
    };
  }
  
  static String _getErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1: return 'Insufficient memory';
      case 5: return 'Unknown error';
      default: return 'Error code: $errorCode';
    }
  }
}

/// Mode switch message (4 bytes)
class BinaryModeSwitch {
  final int module;
  final int currentMode;
  final int previousMode;

  BinaryModeSwitch({
    required this.module,
    required this.currentMode,
    required this.previousMode,
  });

  factory BinaryModeSwitch.parse(Uint8List data) {
    if (data.length < 4) {
      throw Exception('Invalid BinaryModeSwitch data length: ${data.length}');
    }

    return BinaryModeSwitch(
      module: data[1],
      currentMode: data[2],
      previousMode: data[3],
    );
  }

  String getModeString(int mode) {
    switch (mode) {
      case 0: return 'Idle';
      case 1: return 'DetectSignal';
      case 2: return 'RecordSignal';
      case 3: return 'Transmitting';
      case 4: return 'Analyzing';
      case 5: return 'Jamming';
      default: return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module.toString(),
      'mode': getModeString(currentMode),
      'previousMode': getModeString(previousMode),
    };
  }
}

/// Status message with CC1101 registers.
/// Legacy: [type:1][mode0:1][mode1:1][numRegs:1][heap:4][regs0:47][regs1:47] (102 bytes)
/// Extended: [type:1][mode0:1][mode1:1][numRegs:1][heap:4][cpuTempDeciC:2][core0Mhz:2][core1Mhz:2][regs0:47][regs1:47] (108 bytes)
class BinaryStatus {
  final int module0Mode;
  final int module1Mode;
  final int numRegisters;
  final int freeHeap;
  final double? cpuTempC;
  final int? core0Mhz;
  final int? core1Mhz;
  final List<int> module0Registers;
  final List<int> module1Registers;

  BinaryStatus({
    required this.module0Mode,
    required this.module1Mode,
    required this.numRegisters,
    required this.freeHeap,
    this.cpuTempC,
    this.core0Mhz,
    this.core1Mhz,
    required this.module0Registers,
    required this.module1Registers,
  });

  factory BinaryStatus.parse(Uint8List data) {
    if (data.length < 102) {
      throw Exception('Invalid BinaryStatus data length: ${data.length}, expected >= 102');
    }

    final hasCpuTelemetry = data.length >= 108;
    final registersStart = hasCpuTelemetry ? 14 : 8;

    final byteData = ByteData.sublistView(data);
    final freeHeap = byteData.getUint32(4, Endian.little);

    double? cpuTempC;
    int? core0Mhz;
    int? core1Mhz;
    if (hasCpuTelemetry) {
      final deciC = byteData.getInt16(8, Endian.little);
      cpuTempC = deciC / 10.0;
      core0Mhz = byteData.getUint16(10, Endian.little);
      core1Mhz = byteData.getUint16(12, Endian.little);
    }

    return BinaryStatus(
      module0Mode: data[1],
      module1Mode: data[2],
      numRegisters: data[3],
      freeHeap: freeHeap,
      cpuTempC: cpuTempC,
      core0Mhz: core0Mhz,
      core1Mhz: core1Mhz,
      module0Registers: data.sublist(registersStart, registersStart + 47).toList(),
      module1Registers: data.sublist(registersStart + 47, registersStart + 94).toList(),
    );
  }

  String getModeString(int mode) {
    switch (mode) {
      case 0: return 'Idle';
      case 1: return 'DetectSignal';
      case 2: return 'RecordSignal';
      case 3: return 'Transmitting';
      case 4: return 'Analyzing';
      case 5: return 'Jamming';
      default: return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    // Convert to format compatible with existing code
    return {
      'device': {
        'freeHeap': freeHeap,
        if (cpuTempC != null) 'cpuTempC': cpuTempC,
        if (core0Mhz != null) 'core0Mhz': core0Mhz,
        if (core1Mhz != null) 'core1Mhz': core1Mhz,
      },
      'cc1101': [
        {
          'id': 0,
          'mode': getModeString(module0Mode),
          'settings': _registersToHexString(module0Registers),
        },
        {
          'id': 1,
          'mode': getModeString(module1Mode),
          'settings': _registersToHexString(module1Registers),
        },
      ],
    };
  }

  String _registersToHexString(List<int> registers) {
    final buffer = StringBuffer();
    for (int i = 0; i < registers.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(i.toRadixString(16).padLeft(2, '0').toUpperCase());
      buffer.write(' ');
      buffer.write(registers[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }
}

/// Heartbeat message (5 bytes)
class BinaryHeartbeat {
  final int uptimeMs;

  BinaryHeartbeat({required this.uptimeMs});

  factory BinaryHeartbeat.parse(Uint8List data) {
    if (data.length < 5) {
      throw Exception('Invalid BinaryHeartbeat data length: ${data.length}');
    }

    final byteData = ByteData.sublistView(data);
    return BinaryHeartbeat(
      uptimeMs: byteData.getUint32(1, Endian.little),
    );
  }
}

/// Binary message parser utility
class BinaryMessageParser {
  /// Check if data is a binary message (first byte is 0x80-0xFF)
  static bool isBinaryMessage(Uint8List data) {
    if (data.isEmpty) return false;
    return data[0] >= 0x80;
  }

  /// Parse binary message and return as Map compatible with existing code
  static Map<String, dynamic>? parseBinaryMessage(Uint8List data) {
    if (data.isEmpty) return null;

    final messageType = BinaryMessageType.fromValue(data[0]);
    if (messageType == null) return null;

    try {
      switch (messageType) {
        case BinaryMessageType.modeSwitch:
          final msg = BinaryModeSwitch.parse(data);
          return {
            'type': 'ModeSwitch',
            'data': msg.toJson(),
          };

        case BinaryMessageType.status:
          final msg = BinaryStatus.parse(data);
          return {
            'type': 'State',
            'data': msg.toJson(),
          };

        case BinaryMessageType.heartbeat:
          final msg = BinaryHeartbeat.parse(data);
          return {
            'type': 'Heartbeat',
            'data': {'uptime': msg.uptimeMs},
          };

        case BinaryMessageType.fileContent:
          final msg = BinaryFileContent.parse(data);
          return {
            'type': 'FileSystem',
            'data': msg.toJson(),
          };

        case BinaryMessageType.fileList:
          final msg = BinaryFileList.parse(data);
          // Return the parsed JSON directly (it already contains action, files, etc.)
          return {
            'type': 'FileSystem',
            'data': msg.toJson(),
          };

        case BinaryMessageType.directoryTree:
          final msg = BinaryDirectoryTree.parse(data);
          return {
            'type': 'DirectoryTree',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalDetected:
          final msg = BinarySignalDetected.parse(data);
          return {
            'type': 'SignalDetected',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalRecorded:
          final msg = BinarySignalRecorded.parse(data);
          return {
            'type': 'SignalRecorded',
            'data': msg.toJson(),
          };

        case BinaryMessageType.signalSent:
          final msg = BinarySignalSent.parse(data);
          return {
            'type': 'SignalSent',
            'data': msg.toJson(),
          };

        case BinaryMessageType.frequencySearch:
          // 0x94 is never sent by firmware — frequency search results arrive
          // via signalDetected (0x90). This case is kept for forward-compat only.
          return null;

        case BinaryMessageType.signalSendError:
          // Format: [MSG_SIGNAL_SEND_ERROR][module][errorCode][filenameLength][filename...]
          // Matches C++ struct BinarySignalSendError (packed)
          int module = data.length > 1 ? data[1] : 0;
          int code = data.length > 2 ? data[2] : 0;
          String errorMessage;
          switch (code) {
            case 1:
              errorMessage = 'Insufficient data';
              break;
            case 2:
              errorMessage = 'Path length mismatch';
              break;
            case 3:
              errorMessage = 'Failed to post task';
              break;
            case 4:
              errorMessage = 'No idle module available';
              break;
            case 5:
              errorMessage = 'Module is not idle';
              break;
            default:
              errorMessage = 'Error code: $code';
          }
          // If there's more data, extract filename
          String? filename;
          if (data.length > 3) {
            int filenameLength = data[3];
            if (data.length >= 4 + filenameLength) {
              filename = String.fromCharCodes(data.sublist(4, 4 + filenameLength));
            }
          }
          return {
            'type': 'SignalSendingError',
            'data': {
              'module': module,
              'errorCode': code,
              'error': errorMessage,
              if (filename != null) 'filename': filename,
            },
          };

        case BinaryMessageType.fileActionResult:
          final msg = BinaryFileActionResult.parse(data);
          return {
            'type': 'FileSystem',
            'data': msg.toJson(),
          };

        case BinaryMessageType.commandSuccess:
          return {
            'type': 'CommandResult',
            'data': {'success': true},
          };

        case BinaryMessageType.commandError:
          return {
            'type': 'CommandResult',
            'data': {'success': false, 'errorCode': data.length > 1 ? data[1] : 0},
          };

        case BinaryMessageType.error:
          int code = data.length > 1 ? data[1] : 0;
          String msg = '';
          if (data.length > 2) {
            msg = String.fromCharCodes(data.sublist(2));
          }
          return {
            'type': 'error',
            'error': msg.isNotEmpty ? msg : 'Error $code',
            'errorCode': code,
          };

        case BinaryMessageType.lowMemory:
          return {
            'type': 'error',
            'error': 'Device low memory',
            'errorCode': 0xF1,
          };

        case BinaryMessageType.bruterProgress:
          // [0xB0][currentCode:4][totalCodes:4][menuId:1][percentage:1][codesPerSec:2] = 13 bytes
          if (data.length < 13) return null;
          int currentCode = data[1] | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
          int totalCodes = data[5] | (data[6] << 8) | (data[7] << 16) | (data[8] << 24);
          int menuId = data[9];
          int percentage = data[10];
          int codesPerSec = data[11] | (data[12] << 8);
          return {
            'type': 'BruterProgress',
            'data': {
              'currentCode': currentCode,
              'totalCodes': totalCodes,
              'menuId': menuId,
              'percentage': percentage,
              'codesPerSec': codesPerSec,
            },
          };

        case BinaryMessageType.bruterComplete:
          // [0xB1][menuId:1][status:1][reserved:1][totalSent:4] = 8 bytes
          if (data.length < 8) return null;
          return {
            'type': 'BruterComplete',
            'data': {
              'menuId': data[1],
              'status': data[2], // 0=completed, 1=cancelled, 2=error
              'totalSent': data[4] | (data[5] << 8) | (data[6] << 16) | (data[7] << 24),
            },
          };

        case BinaryMessageType.bruterPaused:
          // [0xB2][menuId:1][currentCode:4LE][totalCodes:4LE][percentage:1][reserved:2] = 13 bytes
          if (data.length < 13) return null;
          return {
            'type': 'BruterPaused',
            'data': {
              'menuId': data[1],
              'currentCode': data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24),
              'totalCodes': data[6] | (data[7] << 8) | (data[8] << 16) | (data[9] << 24),
              'percentage': data[10],
            },
          };

        case BinaryMessageType.bruterResumed:
          // [0xB3][menuId:1][resumeCode:4LE][totalCodes:4LE][reserved:3] = 13 bytes
          if (data.length < 13) return null;
          return {
            'type': 'BruterResumed',
            'data': {
              'menuId': data[1],
              'resumeCode': data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24),
              'totalCodes': data[6] | (data[7] << 8) | (data[8] << 16) | (data[9] << 24),
            },
          };

        case BinaryMessageType.bruterStateAvail:
          // [0xB4][menuId:1][currentCode:4LE][totalCodes:4LE][percentage:1][reserved:2] = 13 bytes
          if (data.length < 13) return null;
          return {
            'type': 'BruterStateAvail',
            'data': {
              'menuId': data[1],
              'currentCode': data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24),
              'totalCodes': data[6] | (data[7] << 8) | (data[8] << 16) | (data[9] << 24),
              'percentage': data[10],
            },
          };

        case BinaryMessageType.settingsSync:
          // [0xC0][scannerRssi:int8][bruterPower:u8][delayLo:u8][delayHi:u8][bruterRepeats:u8][radioPowerMod1:int8][radioPowerMod2:int8][cpuTempOffsetLo:u8][cpuTempOffsetHi:u8] = 10 bytes
          // Legacy 6-byte payloads are still accepted (radio power defaults to 10 dBm)
          if (data.length < 6) return null;
          int? cpuTempOffsetDeciC;
          if (data.length >= 10) {
            int raw = data[8] | (data[9] << 8);
            if (raw >= 32768) raw -= 65536;
            cpuTempOffsetDeciC = raw;
          }
          return {
            'type': 'SettingsSync',
            'data': {
              'scannerRssi': data[1] >= 128 ? data[1] - 256 : data[1],  // int8_t
              'bruterPower': data[2],
              'bruterDelay': data[3] | (data[4] << 8),
              'bruterRepeats': data[5],
              'radioPowerMod1': data.length >= 7 ? (data[6] >= 128 ? data[6] - 256 : data[6]) : 10,
              'radioPowerMod2': data.length >= 8 ? (data[7] >= 128 ? data[7] - 256 : data[7]) : 10,
              if (cpuTempOffsetDeciC != null) 'cpuTempOffsetDeciC': cpuTempOffsetDeciC,
            },
          };

        case BinaryMessageType.versionInfo:
          // [0xC2][major:u8][minor:u8][patch:u8] = 4 bytes
          if (data.length < 4) return null;
          return {
            'type': 'VersionInfo',
            'data': {
              'major': data[1],
              'minor': data[2],
              'patch': data[3],
              'version': '${data[1]}.${data[2]}.${data[3]}',
            },
          };

        case BinaryMessageType.batteryStatus:
          // [0xC3][voltage_mv:2 LE][percentage:1][charging:1] = 5 bytes
          if (data.length < 5) return null;
          int battVoltage = data[1] | (data[2] << 8);
          return {
            'type': 'BatteryStatus',
            'data': {
              'voltage_mv': battVoltage,
              'percentage': data[3],
              'charging': data[4] != 0,
            },
          };

        case BinaryMessageType.deviceName:
          // [0xC7][nameLen:1][name...] — BLE device name from firmware
          if (data.length < 2) return null;
          int dnameLen = data[1];
          if (data.length < 2 + dnameLen) return null;
          String devName = String.fromCharCodes(data.sublist(2, 2 + dnameLen));
          return {
            'type': 'DeviceName',
            'data': {
              'name': devName,
            },
          };

        case BinaryMessageType.hwButtonStatus:
          // [0xC8][btn1Action:1][btn2Action:1][btn1PathType:1][btn2PathType:1] = 5 bytes
          if (data.length < 5) return null;
          return {
            'type': 'HwButtonStatus',
            'data': {
              'btn1Action': data[1],
              'btn2Action': data[2],
              'btn1PathType': data[3],
              'btn2PathType': data[4],
            },
          };

        case BinaryMessageType.sdStatus:
          // [0xC9][mounted:1][totalMB:2LE][freeMB:2LE] = 6 bytes
          if (data.length < 6) return null;
          return {
            'type': 'SdStatus',
            'data': {
              'mounted': data[1] != 0,
              'totalMB': data[2] | (data[3] << 8),
              'freeMB': data[4] | (data[5] << 8),
            },
          };

        case BinaryMessageType.nrfModuleStatus:
          // [0xCA][present:1][initialized:1][activeState:1] = 4 bytes
          if (data.length < 4) return null;
          return {
            'type': 'NrfModuleStatus',
            'data': {
              'present': data[1] != 0,
              'initialized': data[2] != 0,
              'activeState': data[3],
            },
          };

        // ── NRF24 notifications ────────────────────────────────

        case BinaryMessageType.nrfDeviceFound:
          // [0xD0][type:1][channel:1][addrLen:1][addr:addrLen]
          if (data.length < 4) return null;
          int devType = data[1];
          int channel = data[2];
          int addrLen = data[3];
          List<int> address = [];
          if (data.length >= 4 + addrLen) {
            address = data.sublist(4, 4 + addrLen).toList();
          }
          return {
            'type': 'NrfDeviceFound',
            'data': {
              'deviceType': devType,
              'channel': channel,
              'address': address,
            },
          };

        case BinaryMessageType.nrfAttackComplete:
          // [0xD1][targetIndex:1][status:1]
          if (data.length < 3) return null;
          return {
            'type': 'NrfAttackComplete',
            'data': {
              'targetIndex': data[1],
              'status': data[2], // 0=success, 1=fail
            },
          };

        case BinaryMessageType.nrfScanComplete:
          // [0xD2][totalTargets:1]
          if (data.length < 2) return null;
          return {
            'type': 'NrfScanComplete',
            'data': {
              'totalTargets': data[1],
            },
          };

        case BinaryMessageType.nrfScanStatus:
          // [0xD3][state:1][targetCount:1][{type:1,channel:1,addrLen:1,addr:addrLen}...]
          if (data.length < 3) return null;
          int scanState = data[1];
          int count = data[2];
          List<Map<String, dynamic>> targets = [];
          int offset = 3;
          for (int i = 0; i < count && offset < data.length; i++) {
            if (offset + 3 > data.length) break;
            int t = data[offset++];
            int ch = data[offset++];
            int aLen = data[offset++];
            List<int> addr = [];
            if (offset + aLen <= data.length) {
              addr = data.sublist(offset, offset + aLen).toList();
              offset += aLen;
            }
            targets.add({'deviceType': t, 'channel': ch, 'address': addr});
          }
          return {
            'type': 'NrfScanStatus',
            'data': {
              'state': scanState,
              'targetCount': count,
              'targets': targets,
            },
          };

        case BinaryMessageType.nrfSpectrumData:
          // [0xD4][levels:126 bytes] — full nRF24L01+ channel range
          // Accept 81+ bytes for backward compat, parse all available levels
          if (data.length < 2) return null;
          final specLen = data.length - 1; // all bytes after msg type
          return {
            'type': 'NrfSpectrumData',
            'data': {
              'levels': data.sublist(1, 1 + specLen).toList(),
            },
          };

        case BinaryMessageType.nrfJamStatus:
          // [0xD5][running:1][mode:1][dwellLo:1][dwellHi:1]
          // FW sends exactly 5 bytes. Old 4-byte format is also accepted.
          if (data.length < 4) return null;
          {
            int jamDwell = 0;
            int jamCh = 0;
            if (data.length >= 5) {
              // New format: [running][mode][dwellLo][dwellHi][channel?]
              jamDwell = data[3] | (data[4] << 8);
              jamCh = data.length >= 6 ? data[5] : 0;
            } else {
              jamCh = data[3];
            }
            return {
              'type': 'NrfJamStatus',
              'data': {
                'running': data[1] != 0,
                'mode': data[2],
                'dwellTimeMs': jamDwell,
                'channel': jamCh,
              },
            };
          }

        case BinaryMessageType.nrfJamModeConfig:
          // [0xD6][mode:1][pa:1][dr:1][dwellLo:1][dwellHi:1][flood:1][bursts:1]
          if (data.length < 8) return null;
          return {
            'type': 'NrfJamModeConfig',
            'data': {
              'mode': data[1],
              'paLevel': data[2],
              'dataRate': data[3],
              'dwellTimeMs': data[4] | (data[5] << 8),
              'useFlooding': data[6] != 0,
              'floodBursts': data[7],
            },
          };

        case BinaryMessageType.nrfJamModeInfo:
          // [0xD7][mode][freqStartHi][freqStartLo][freqEndHi][freqEndLo]
          //       [channelCount:1][nameLen:1][name...][descLen:1][desc...]
          if (data.length < 9) return null;
          {
            int infoMode = data[1];
            int freqStart = (data[2] << 8) | data[3];
            int freqEnd = (data[4] << 8) | data[5];
            int chCount = data[6];
            int nLen = data[7];
            String modeName = '';
            String modeDesc = '';
            int off = 8;
            if (off + nLen <= data.length) {
              modeName = String.fromCharCodes(data.sublist(off, off + nLen));
              off += nLen;
            }
            if (off < data.length) {
              int dLen = data[off++];
              if (off + dLen <= data.length) {
                modeDesc = String.fromCharCodes(data.sublist(off, off + dLen));
              }
            }
            return {
              'type': 'NrfJamModeInfo',
              'data': {
                'mode': infoMode,
                'freqStartMHz': freqStart,
                'freqEndMHz': freqEnd,
                'channelCount': chCount,
                'name': modeName,
                'description': modeDesc,
              },
            };
          }

        case BinaryMessageType.sdrStatus:
          // [0xC4][active:1][module:1][freqKhz:4LE][modulation:1] = 8 bytes
          if (data.length < 8) return null;
          int freqKhz = data[3] | (data[4] << 8) | (data[5] << 16) | (data[6] << 24);
          return {
            'type': 'SdrStatus',
            'data': {
              'active': data[1] != 0,
              'module': data[2],
              'freqKhz': freqKhz,
              'modulation': data[7],
            },
          };

        // ── OTA notifications ──────────────────────────────────

        case BinaryMessageType.otaProgress:
          // FW format: [0xE0][received:4LE][total:4LE][percentage:1] = 10 bytes
          if (data.length < 10) return null;
          int received = data[1] | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
          int total = data[5] | (data[6] << 8) | (data[7] << 16) | (data[8] << 24);
          int pct = data[9];
          return {
            'type': 'OtaProgress',
            'data': {
              'percentage': pct,
              'bytesWritten': received,
              'totalSize': total,
            },
          };

        case BinaryMessageType.otaComplete:
          // FW format: [0xE1] — 1 byte only (no status byte)
          // Accept both 1-byte (FW current) and 2-byte (future) formats
          return {
            'type': 'OtaComplete',
            'data': {
              'status': data.length >= 2 ? data[1] : 0, // 0=success (default)
            },
          };

        case BinaryMessageType.otaError:
          // FW format: [0xE2][errorMessage...] — raw string starting at byte 1
          if (data.length < 2) return null;
          String errorMsg = String.fromCharCodes(data.sublist(1));
          return {
            'type': 'OtaError',
            'data': {
              'errorCode': 0xFF, // Generic error (FW sends message only)
              'message': errorMsg.isNotEmpty ? errorMsg : 'Unknown OTA error',
            },
          };

        default:
          print('Unsupported binary message type: 0x${data[0].toRadixString(16)}');
          return null;
      }
    } catch (e) {
      print('Error parsing binary message: $e');
      return null;
    }
  }
}

