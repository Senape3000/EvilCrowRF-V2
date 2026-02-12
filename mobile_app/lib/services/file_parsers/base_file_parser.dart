import '../signal_processing/signal_data.dart';

/// Base class for signal file parsers
/// Defines common interface for all parsers
abstract class BaseFileParser {
  /// Parse file content
  /// [content] - file content as a string
  /// Returns SignalData with parsed data
  SignalData parse(String content);
  
  /// Check if the file can be parsed
  /// [content] - file content to check
  /// Returns true if the file can be parsed by this parser
  bool canParse(String content);
  
  /// Get supported file extensions
  /// Returns a list of extensions (e.g. ['.sub', '.json'])
  List<String> getSupportedExtensions();
  
  /// Get format description
  /// Returns description of the supported format
  String getFormatDescription();
  
  /// Get MIME type
  /// Returns MIME type for files of this format
  String getMimeType();
  
  /// Get parser priority (higher = more priority)
  /// Used for selecting parser when multiple can handle the file
  int getPriority() => 50;
}

/// File parse result
class FileParseResult {
  /// Parsing success
  final bool success;
  
  /// Parsed signal data (if successful)
  final SignalData? signalData;
  
  /// List of errors (if any)
  final List<String> errors;
  
  /// Warnings (non-critical issues)
  final List<String> warnings;
  
  /// File info
  final Map<String, dynamic>? fileInfo;
  
  FileParseResult({
    required this.success,
    this.signalData,
    this.errors = const [],
    this.warnings = const [],
    this.fileInfo,
  });
  
  /// Create successful result
  factory FileParseResult.success({
    required SignalData signalData,
    List<String> warnings = const [],
    Map<String, dynamic>? fileInfo,
  }) {
    return FileParseResult(
      success: true,
      signalData: signalData,
      warnings: warnings,
      fileInfo: fileInfo,
    );
  }
  
  /// Create error result
  factory FileParseResult.error({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, dynamic>? fileInfo,
  }) {
    return FileParseResult(
      success: false,
      errors: errors,
      warnings: warnings,
      fileInfo: fileInfo,
    );
  }
  
  @override
  String toString() {
    return 'FileParseResult('
        'success: $success, '
        'signalData: ${signalData != null ? 'present' : 'null'}, '
        'errors: ${errors.length}, '
        'warnings: ${warnings.length})';
  }
}

/// File info
class FileInfo {
  /// File size in bytes
  final int size;
  
  /// Creation/modification date
  final DateTime? lastModified;
  
  /// MIME type
  final String? mimeType;
  
  /// Encoding (if known)
  final String? encoding;
  
  /// Additional metadata
  final Map<String, dynamic> metadata;
  
  FileInfo({
    required this.size,
    this.lastModified,
    this.mimeType,
    this.encoding,
    this.metadata = const {},
  });
  
  @override
  String toString() {
    return 'FileInfo('
        'size: $size bytes, '
        'lastModified: $lastModified, '
        'mimeType: $mimeType)';
  }
}

