
/// Base class for signal generators
/// Defines common interface for all generators
abstract class BaseSignalGenerator {
  /// Generate file content
  /// Returns a string with the file content
  String generate();
  
  /// Validate data before generation
  /// Returns true if data is valid
  bool validate();
  
  /// Get list of validation errors
  /// Returns list of error descriptions
  List<String> getErrors();
  
  /// Get supported file extensions
  List<String> getSupportedExtensions();
  
  /// Get format description
  String getFormatDescription();
}

/// Signal generation result
class SignalGenerationResult {
  /// Generation success
  final bool success;
  
  /// File content (if successful)
  final String? content;
  
  /// List of errors (if any)
  final List<String> errors;
  
  /// Generated file type
  final String? fileType;
  
  /// Recommended file extension
  final String? fileExtension;
  
  SignalGenerationResult({
    required this.success,
    this.content,
    this.errors = const [],
    this.fileType,
    this.fileExtension,
  });
  
  /// Create successful result
  factory SignalGenerationResult.success({
    required String content,
    String? fileType,
    String? fileExtension,
  }) {
    return SignalGenerationResult(
      success: true,
      content: content,
      fileType: fileType,
      fileExtension: fileExtension,
    );
  }
  
  /// Create error result
  factory SignalGenerationResult.error({
    required List<String> errors,
  }) {
    return SignalGenerationResult(
      success: false,
      errors: errors,
    );
  }
  
  @override
  String toString() {
    return 'SignalGenerationResult('
        'success: $success, '
        'content: ${content?.length ?? 0} chars, '
        'errors: ${errors.length})';
  }
}

/// Signal format types
enum SignalFormat {
  flipperSub('flipper_sub', '.sub', 'FlipperZero SubGhz'),
  tutJson('tut_json', '.json', 'TUT JSON'),
  raw('raw', '.raw', 'RAW Data'),
  custom('custom', '.txt', 'Custom Format');
  
  const SignalFormat(this.id, this.extension, this.description);
  
  final String id;
  final String extension;
  final String description;
  
  /// Get format by ID
  static SignalFormat? fromId(String id) {
    for (final format in SignalFormat.values) {
      if (format.id == id) {
        return format;
      }
    }
    return null;
  }
  
  /// Get format by extension
  static SignalFormat? fromExtension(String extension) {
    final cleanExtension = extension.startsWith('.') ? extension : '.$extension';
    
    for (final format in SignalFormat.values) {
      if (format.extension == cleanExtension) {
        return format;
      }
    }
    return null;
  }
}

