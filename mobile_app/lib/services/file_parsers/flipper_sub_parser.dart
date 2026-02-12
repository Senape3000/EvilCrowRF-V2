import '../signal_processing/signal_data.dart';
import 'base_file_parser.dart';

/// Parser for FlipperZero .sub files
/// Processes files in FlipperZero SubGhz format
class FlipperSubParser extends BaseFileParser {
  /// Supported FlipperZero presets
  static const Map<String, Map<String, dynamic>> _presets = {
    'FuriHalSubGhzPresetOok270Async': {
      'modulation': 2,
      'rxBandwidth': 270.83,
    },
    'FuriHalSubGhzPresetOok650Async': {
      'modulation': 2,
      'rxBandwidth': 650.0,
    },
    'FuriHalSubGhzPreset2FSKDev238Async': {
      'modulation': 0,
      'deviation': 2.38,
      'dataRate': 4.8,
      'rxBandwidth': 270.83,
    },
    'FuriHalSubGhzPreset2FSKDev476Async': {
      'modulation': 0,
      'deviation': 47.6,
      'dataRate': 4.8,
      'rxBandwidth': 270.83,
    },
  };
  
  /// Supported file types
  static const List<String> _supportedFileTypes = [
    'Flipper SubGhz Key File',
    'Flipper SubGhz RAW File',
  ];
  
  @override
  bool canParse(String content) {
    try {
      final lines = content.split('\n');
      if (lines.isEmpty) return false;
      
      final firstLine = lines.first.trim();
      if (!firstLine.startsWith('Filetype:')) return false;
      
      final filetype = firstLine.split(':').length > 1 
          ? firstLine.split(':')[1].trim() 
          : '';
      
      return _supportedFileTypes.any((type) => filetype.contains(type));
    } catch (e) {
      return false;
    }
  }
  
  @override
  SignalData parse(String content) {
    try {
      final lines = content.split('\n');
      final filteredLines = lines
          .where((line) => !line.trim().startsWith('#'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      
      if (filteredLines.isEmpty) {
        throw const FormatException('Empty file content');
      }
      
      // Parse header
      final filetype = _parseFiletype(filteredLines[0]);
      if (!_supportedFileTypes.contains(filetype)) {
        throw FormatException('Unsupported file type: $filetype');
      }
      
      final version = _parseVersion(filteredLines[1]);
      if (version != 1) {
        throw FormatException('Unsupported version: $version');
      }
      
      final frequency = _parseFrequency(filteredLines[2]);
      
      // Parse remaining content
      final remainingLines = filteredLines.skip(3).toList();
      return _parseV1(remainingLines, frequency);
      
    } catch (e) {
      throw FormatException('Failed to parse .sub file: $e');
    }
  }
  
  @override
  List<String> getSupportedExtensions() => ['.sub'];
  
  @override
  String getFormatDescription() => 'FlipperZero SubGhz RAW File';
  
  @override
  String getMimeType() => 'text/plain';
  
  @override
  int getPriority() => 100; // High priority for .sub files
  
  /// Parse file version 1
  SignalData _parseV1(List<String> lines, double frequency) {
    final result = <String, dynamic>{};
    final rawData = <List<int>>[];
    String? preset;
    String? protocol;
    
    // Variables for Bit_Raw format
    int? bitCount;
    int? te;
    int? bitRaw;
    List<int>? dataRawHex;
    String? binaryString;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      
      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();
      
      switch (key) {
        case 'Preset':
          preset = value;
          if (_presets.containsKey(value)) {
            final presetData = _presets[value]!;
            result.addAll(presetData);
          } else {
            throw FormatException('Unknown preset: $value');
          }
          break;
          
        case 'Protocol':
          protocol = value;
          result['protocol'] = value;
          break;
          
        case 'Bit':
          bitCount = int.tryParse(value);
          if (bitCount != null) {
            result['bit'] = bitCount;
          }
          break;
          
        case 'TE':
          te = int.tryParse(value);
          if (te != null) {
            result['te'] = te;
          }
          break;
          
        case 'Bit_RAW':
          bitRaw = int.tryParse(value);
          if (bitRaw != null) {
            result['bit_raw'] = bitRaw;
          }
          break;
          
        case 'Data_RAW':
          // Parse hex values from Data_RAW
          try {
            final hexValues = value.split(' ')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => int.tryParse(s, radix: 16) ?? 0)
                .toList();
            if (hexValues.isNotEmpty) {
              dataRawHex = hexValues;
              // Convert hex data to binary string
              binaryString = _convertHexToBinary(hexValues, bitRaw ?? hexValues.length * 8);
              result['data_raw'] = hexValues.map((v) => v.toRadixString(16).padLeft(2, '0')).join(' ');
            }
          } catch (e) {
            // Ignore invalid data
            continue;
          }
          break;
          
        case 'RAW_Data':
          try {
            final numbers = value.split(' ')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => int.tryParse(s) ?? 0)
                .toList();
            if (numbers.isNotEmpty) {
              rawData.add(numbers);
            }
          } catch (e) {
            // Ignore invalid data
            continue;
          }
          break;
          
        case 'Custom_preset_module':
        case 'Custom_preset_data':
          // Ignore custom presets (complex to parse)
          break;
          
        default:
          // Save unknown fields to metadata
          result[key.toLowerCase()] = value;
          break;
      }
    }
    
    // If BinRAW protocol, generate RAW_Data from Bit_Raw
    if (protocol == 'BinRAW' && bitRaw != null && te != null && dataRawHex != null && binaryString != null) {
      final pulseData = _generatePulseDataFromBitRaw(dataRawHex, bitRaw, te);
      if (pulseData.isNotEmpty) {
        rawData.add(pulseData);
      }
      result['binary'] = binaryString;
    }
    
    // Combine all RAW_Data into one string
    String? rawString;
    if (rawData.isNotEmpty) {
      rawString = rawData
          .expand((row) => row)
          .join(' ');
    }
    
    // If binary string exists, use it
    if (binaryString != null && rawString == null) {
      rawString = binaryString;
    }
    
    return SignalData(
      frequency: frequency,
      preset: preset,
      protocol: protocol,
      modulation: _getModulationName(result['modulation']),
      rxBandwidth: result['rxBandwidth']?.toDouble(),
      dataRate: result['dataRate']?.toDouble(),
      deviation: result['deviation']?.toDouble(),
      raw: rawString,
      binary: binaryString,
      rawData: rawData.isNotEmpty ? rawData : null,
      metadata: result.isNotEmpty ? result : null,
    );
  }
  
  /// Convert hex values to binary string
  String _convertHexToBinary(List<int> hexValues, int bitCount) {
    final buffer = StringBuffer();
    int bitsProcessed = 0;
    
    for (int byteValue in hexValues) {
      if (bitsProcessed >= bitCount) break;
      
      for (int i = 7; i >= 0; i--) {
        if (bitsProcessed >= bitCount) break;
        final bit = (byteValue >> i) & 0x01;
        buffer.write(bit.toString());
        bitsProcessed++;
      }
    }
    
    return buffer.toString();
  }
  
  /// Generate pulse data from Bit_Raw format (as in C++ code)
  List<int> _generatePulseDataFromBitRaw(List<int> rawData, int bitRaw, int te) {
    final pulseData = <int>[];
    bool currentState = false;
    int currentDuration = 0;
    
    for (int i = 0; i < bitRaw; i++) {
      final byteIndex = i ~/ 8;
      if (byteIndex >= rawData.length) break;
      
      final bitIndex = 7 - (i % 8);
      final bit = (rawData[byteIndex] >> bitIndex) & 0x01;
      final boolState = bit == 1;
      
      if (boolState == currentState) {
        currentDuration += te;
      } else {
        if (currentDuration > 0) {
          pulseData.add(currentState ? currentDuration : -currentDuration);
        }
        currentState = boolState;
        currentDuration = te;
      }
    }
    
    // Add last pulse
    if (currentDuration > 0) {
      pulseData.add(currentState ? currentDuration : -currentDuration);
    }
    
    return pulseData;
  }
  
  /// Parse file type
  String _parseFiletype(String line) {
    final parts = line.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid filetype line: $line');
    }
    return parts[1].trim();
  }
  
  /// Parse version
  int _parseVersion(String line) {
    final parts = line.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid version line: $line');
    }
    return int.tryParse(parts[1].trim()) ?? 1;
  }
  
  /// Parse frequency
  double _parseFrequency(String line) {
    final parts = line.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid frequency line: $line');
    }
    
    final frequencyStr = parts[1].trim();
    final frequency = int.tryParse(frequencyStr);
    if (frequency == null) {
      throw FormatException('Invalid frequency value: $frequencyStr');
    }
    
    return frequency.toDouble() / 1000000; // Convert to MHz
  }
  
  /// Get modulation name by number
  String _getModulationName(int? modulation) {
    if (modulation == null) return 'Unknown';
    
    switch (modulation) {
      case 0:
        return '2-FSK';
      case 1:
        return 'GFSK';
      case 2:
        return 'ASK/OOK';
      case 3:
        return 'ASK/OOK';
      case 4:
        return '4-FSK';
      case 7:
        return 'MSK';
      default:
        return 'Unknown';
    }
  }
  
  /// Get parse result with error handling
  FileParseResult parseWithResult(String content) {
    try {
      final signalData = parse(content);
      return FileParseResult.success(signalData: signalData);
    } catch (e) {
      return FileParseResult.error(
        errors: ['Failed to parse .sub file: $e'],
      );
    }
  }
  
  /// Validate file
  bool isValidFile(String content) {
    try {
      final lines = content.split('\n');
      if (lines.length < 3) return false;
      
      final filetype = _parseFiletype(lines[0]);
      if (!_supportedFileTypes.contains(filetype)) return false;
      
      final version = _parseVersion(lines[1]);
      if (version != 1) return false;
      
      _parseFrequency(lines[2]);
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get file info without full parsing
  Map<String, dynamic>? getFileInfo(String content) {
    try {
      final lines = content.split('\n');
      if (lines.length < 3) return null;
      
      final filetype = _parseFiletype(lines[0]);
      final version = _parseVersion(lines[1]);
      final frequency = _parseFrequency(lines[2]);
      
      return {
        'filetype': filetype,
        'version': version,
        'frequency': frequency,
        'isValid': true,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
      };
    }
  }
}

