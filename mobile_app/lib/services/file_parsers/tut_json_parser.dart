import 'dart:convert';
import '../signal_processing/signal_data.dart';
import 'base_file_parser.dart';

/// Parser for TUT JSON files
/// Processes files in TUT JSON format for signals
class TutJsonParser extends BaseFileParser {
  /// Required fields in JSON file
  static const List<String> _requiredFields = ['frequency', 'raw'];
  
  /// Supported fields
  static const List<String> _supportedFields = [
    'frequency',
    'raw',
    'binary',
    'smoothed',
    'dataRate',
    'deviation',
    'modulation',
    'pulseDuration',
    'samplesCount',
    'rxBandwidth',
    'preset',
  ];
  
  @override
  bool canParse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Check required fields
      for (final field in _requiredFields) {
        if (!json.containsKey(field)) {
          return false;
        }
      }
      
      // Check data types
      if (json['frequency'] is! num) return false;
      if (json['raw'] is! String) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  SignalData parse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Check required fields
      for (final field in _requiredFields) {
        if (!json.containsKey(field)) {
          throw FormatException('Missing required field: $field');
        }
      }
      
      // Extract data
      final frequency = (json['frequency'] as num).toDouble();
      final raw = json['raw'] as String;
      
      if (frequency <= 0) {
        throw FormatException('Invalid frequency: $frequency');
      }
      
      if (raw.trim().isEmpty) {
        throw const FormatException('Raw data is empty');
      }
      
      // Extract optional fields
      final binary = json['binary'] as String?;
      final smoothed = json['smoothed'] as String?;
      final dataRate = json['dataRate'] != null 
          ? (json['dataRate'] as num).toDouble() 
          : null;
      final deviation = json['deviation'] != null 
          ? (json['deviation'] as num).toDouble() 
          : null;
      final modulation = json['modulation'] as String?;
      final pulseDuration = json['pulseDuration'] != null 
          ? (json['pulseDuration'] as num).toDouble() 
          : null;
      final samplesCount = json['samplesCount'] as int?;
      final rxBandwidth = json['rxBandwidth'] != null 
          ? (json['rxBandwidth'] as num).toDouble() 
          : null;
      final preset = json['preset'] as String?;
      
      // Create metadata from unknown fields
      final metadata = <String, dynamic>{};
      for (final entry in json.entries) {
        if (!_supportedFields.contains(entry.key)) {
          metadata[entry.key] = entry.value;
        }
      }
      
      return SignalData(
        frequency: frequency,
        raw: raw,
        binary: binary,
        smoothed: smoothed,
        dataRate: dataRate,
        deviation: deviation,
        modulation: modulation,
        pulseDuration: pulseDuration,
        samplesCount: samplesCount,
        rxBandwidth: rxBandwidth,
        preset: preset,
        metadata: metadata.isNotEmpty ? metadata : null,
      );
      
    } catch (e) {
      throw FormatException('Failed to parse TUT JSON: $e');
    }
  }
  
  @override
  List<String> getSupportedExtensions() => ['.json'];
  
  @override
  String getFormatDescription() => 'TUT JSON Signal File';
  
  @override
  String getMimeType() => 'application/json';
  
  @override
  int getPriority() => 80; // Medium priority for JSON files
  
  /// Get parse result with error handling
  FileParseResult parseWithResult(String content) {
    try {
      final signalData = parse(content);
      return FileParseResult.success(signalData: signalData);
    } catch (e) {
      return FileParseResult.error(
        errors: ['Failed to parse TUT JSON: $e'],
      );
    }
  }
  
  /// Validate JSON structure
  bool isValidJson(String content) {
    try {
      final json = jsonDecode(content);
      return json is Map<String, dynamic>;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate file without full parsing
  bool isValidFile(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Check required fields
      for (final field in _requiredFields) {
        if (!json.containsKey(field)) {
          return false;
        }
      }
      
      // Check basic types
      if (json['frequency'] is! num) return false;
      if (json['raw'] is! String) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get file info without full parsing
  Map<String, dynamic>? getFileInfo(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      final frequency = json['frequency'] as num?;
      final hasRaw = json.containsKey('raw') && json['raw'] is String;
      final hasBinary = json.containsKey('binary');
      final hasSmoothed = json.containsKey('smoothed');
      
      return {
        'filetype': 'TUT JSON',
        'frequency': frequency?.toDouble(),
        'hasRaw': hasRaw,
        'hasBinary': hasBinary,
        'hasSmoothed': hasSmoothed,
        'fieldCount': json.keys.length,
        'isValid': frequency != null && hasRaw,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Create JSON from SignalData
  String createJson(SignalData signalData) {
    final json = <String, dynamic>{};
    
    if (signalData.frequency != null) {
      json['frequency'] = signalData.frequency;
    }
    
    if (signalData.raw != null) {
      json['raw'] = signalData.raw;
    }
    
    if (signalData.binary != null) {
      json['binary'] = signalData.binary;
    }
    
    if (signalData.smoothed != null) {
      json['smoothed'] = signalData.smoothed;
    }
    
    if (signalData.dataRate != null) {
      json['dataRate'] = signalData.dataRate;
    }
    
    if (signalData.deviation != null) {
      json['deviation'] = signalData.deviation;
    }
    
    if (signalData.modulation != null) {
      json['modulation'] = signalData.modulation;
    }
    
    if (signalData.pulseDuration != null) {
      json['pulseDuration'] = signalData.pulseDuration;
    }
    
    if (signalData.samplesCount != null) {
      json['samplesCount'] = signalData.samplesCount;
    }
    
    if (signalData.rxBandwidth != null) {
      json['rxBandwidth'] = signalData.rxBandwidth;
    }
    
    if (signalData.preset != null) {
      json['preset'] = signalData.preset;
    }
    
    if (signalData.metadata != null) {
      json.addAll(signalData.metadata!);
    }
    
    return const JsonEncoder.withIndent('  ').convert(json);
  }
  
  /// Validate SignalData for JSON creation
  List<String> validateSignalData(SignalData signalData) {
    final errors = <String>[];
    
    if (signalData.frequency == null || signalData.frequency! <= 0) {
      errors.add('Frequency is required and must be positive');
    }
    
    if (signalData.raw == null || signalData.raw!.trim().isEmpty) {
      errors.add('Raw data is required');
    }
    
    return errors;
  }
}

