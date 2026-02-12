import '../signal_processing/signal_data.dart';
import 'base_signal_generator.dart';
import 'flipper_sub_generator.dart';

/// Factory for creating signal generators
/// Provides a single entry point for creating generators of various formats
class SignalGeneratorFactory {
  /// Create generator by format type
  /// [format] - signal format type
  /// Returns the corresponding generator
  static BaseSignalGenerator createGenerator(SignalFormat format) {
    switch (format) {
      case SignalFormat.flipperSub:
        return FlipperSubGenerator();
      case SignalFormat.tutJson:
        throw UnsupportedError('TUT JSON generator not implemented yet');
      case SignalFormat.raw:
        throw UnsupportedError('RAW generator not implemented yet');
      case SignalFormat.custom:
        throw UnsupportedError('Custom generator not implemented yet');
    }
  }
  
  /// Create generator by file extension
  /// [extension] - file extension (e.g. '.sub', '.json')
  /// Returns the corresponding generator or null if format is not supported
  static BaseSignalGenerator? createGeneratorByExtension(String extension) {
    final format = SignalFormat.fromExtension(extension);
    if (format == null) return null;
    
    try {
      return createGenerator(format);
    } catch (e) {
      return null;
    }
  }
  
  /// Get list of supported formats
  /// Returns a list of all available formats
  static List<SignalFormat> getSupportedFormats() {
    return SignalFormat.values;
  }
  
  /// Get list of supported extensions
  /// Returns a list of all supported file extensions
  static List<String> getSupportedExtensions() {
    return SignalFormat.values.map((format) => format.extension).toList();
  }
  
  /// Check format support
  /// [extension] - file extension
  /// Returns true if the format is supported
  static bool isFormatSupported(String extension) {
    return SignalFormat.fromExtension(extension) != null;
  }
  
  /// Generate file from SignalData
  /// [signalData] - signal data
  /// [format] - desired format
  /// Returns generation result
  static SignalGenerationResult generateFromSignalData(
    SignalData signalData,
    SignalFormat format,
  ) {
    try {
      final generator = createGenerator(format);
      
      // Configure generator based on SignalData
      if (generator is FlipperSubGenerator) {
        final flipperGenerator = FlipperSubGenerator.fromSignalData(signalData);
        return flipperGenerator.generateResult();
      }
      
      // For other formats - basic configuration
      final content = generator.generate();
      return SignalGenerationResult.success(content: content);
    } catch (e) {
      return SignalGenerationResult.error(
        errors: ['Failed to generate file: $e'],
      );
    }
  }
  
  /// Automatic format selection based on content
  /// [signalData] - signal data
  /// Returns recommended format or null if indeterminate
  static SignalFormat? getRecommendedFormat(SignalData signalData) {
    // If FlipperZero preset data present - use .sub format
    if (signalData.preset != null && 
        signalData.preset!.contains('FuriHalSubGhz')) {
      return SignalFormat.flipperSub;
    }
    
    // If JSON data present - use .json format
    if (signalData.metadata != null && signalData.metadata!.isNotEmpty) {
      return SignalFormat.tutJson;
    }
    
    // If only raw data - use .sub format by default
    if (signalData.raw != null && signalData.raw!.isNotEmpty) {
      return SignalFormat.flipperSub;
    }
    
    return null;
  }
  
  /// Get format description
  /// [format] - format type
  /// Returns format description
  static String getFormatDescription(SignalFormat format) {
    return format.description;
  }
  
  /// Get MIME type for format
  /// [format] - format type
  /// Returns MIME type
  static String getMimeType(SignalFormat format) {
    switch (format) {
      case SignalFormat.flipperSub:
        return 'text/plain';
      case SignalFormat.tutJson:
        return 'application/json';
      case SignalFormat.raw:
        return 'application/octet-stream';
      case SignalFormat.custom:
        return 'text/plain';
    }
  }
  
  /// Get generator info
  /// [format] - format type
  /// Returns generator info
  static Map<String, dynamic> getGeneratorInfo(SignalFormat format) {
    try {
      final generator = createGenerator(format);
      
      return {
        'format': format.id,
        'extension': format.extension,
        'description': format.description,
        'supportedExtensions': generator.getSupportedExtensions(),
        'formatDescription': generator.getFormatDescription(),
        'mimeType': getMimeType(format),
      };
    } catch (e) {
      return {
        'format': format.id,
        'extension': format.extension,
        'description': format.description,
        'error': e.toString(),
      };
    }
  }
  
  /// Get info about all generators
  /// Returns info list about all available generators
  static List<Map<String, dynamic>> getAllGeneratorsInfo() {
    return SignalFormat.values.map(getGeneratorInfo).toList();
  }
}
