import 'base_file_parser.dart';
import 'flipper_sub_parser.dart';
import 'tut_json_parser.dart';

/// Factory for creating signal file parsers
/// Provides a single entry point for creating parsers of various formats
class FileParserFactory {
  /// List of all available parsers
  static final List<BaseFileParser> _parsers = [
    FlipperSubParser(),
    TutJsonParser(),
  ];
  
  /// Get parser for file content
  /// [content] - file content
  /// Returns a suitable parser or null if none fits
  static BaseFileParser? getParserForContent(String content) {
    // Sort parsers by priority (higher = more priority)
    final sortedParsers = List<BaseFileParser>.from(_parsers);
    sortedParsers.sort((a, b) => b.getPriority().compareTo(a.getPriority()));
    
    for (final parser in sortedParsers) {
      if (parser.canParse(content)) {
        return parser;
      }
    }
    
    return null;
  }
  
  /// Get parser by file extension
  /// [extension] - file extension (e.g. '.sub', '.json')
  /// Returns a suitable parser or null if the format is not supported
  static BaseFileParser? getParserForExtension(String extension) {
    final cleanExtension = extension.startsWith('.') ? extension : '.$extension';
    
    for (final parser in _parsers) {
      if (parser.getSupportedExtensions().contains(cleanExtension)) {
        return parser;
      }
    }
    
    return null;
  }
  
  /// Get parser by filename
  /// [filename] - filename with extension
  /// Returns a suitable parser or null if the format is not supported
  static BaseFileParser? getParserForFilename(String filename) {
    final extension = filename.split('.').last;
    return getParserForExtension(extension);
  }
  
  /// Parse file with automatic format detection
  /// [content] - file content
  /// [filename] - filename (optional, as hint)
  /// Returns parse result
  static FileParseResult parseFile(String content, {String? filename}) {
    // First try to determine by content
    BaseFileParser? parser = getParserForContent(content);
    
    // If failed, try by filename
    if (parser == null && filename != null) {
      parser = getParserForFilename(filename);
    }
    
    if (parser == null) {
      return FileParseResult.error(
        errors: ['Unsupported file format. Supported formats: ${getSupportedExtensions().join(', ')}'],
        fileInfo: {
          'filename': filename,
          'size': content.length,
        },
      );
    }
    
    try {
      // Use parseWithResult method if available
      if (parser is FlipperSubParser) {
        return parser.parseWithResult(content);
      } else if (parser is TutJsonParser) {
        return parser.parseWithResult(content);
      } else {
        // Fallback to base method
        final signalData = parser.parse(content);
        return FileParseResult.success(signalData: signalData);
      }
    } catch (e) {
      return FileParseResult.error(
        errors: ['Failed to parse file: $e'],
        fileInfo: {
          'filename': filename,
          'size': content.length,
          'parser': parser.runtimeType.toString(),
        },
      );
    }
  }
  
  /// Get list of supported extensions
  /// Returns a list of all supported file extensions
  static List<String> getSupportedExtensions() {
    final extensions = <String>{};
    for (final parser in _parsers) {
      extensions.addAll(parser.getSupportedExtensions());
    }
    return extensions.toList()..sort();
  }
  
  /// Check if the extension is supported
  /// [extension] - file extension
  /// Returns true if the format is supported
  static bool isExtensionSupported(String extension) {
    return getParserForExtension(extension) != null;
  }
  
  /// Check if the content can be parsed
  /// [content] - file content
  /// Returns true if the content can be parsed
  static bool canParseContent(String content) {
    return getParserForContent(content) != null;
  }
  
  /// Get info about all parsers
  /// Returns info list about all available parsers
  static List<Map<String, dynamic>> getAllParsersInfo() {
    return _parsers.map((parser) => {
      'type': parser.runtimeType.toString(),
      'extensions': parser.getSupportedExtensions(),
      'description': parser.getFormatDescription(),
      'mimeType': parser.getMimeType(),
      'priority': parser.getPriority(),
    }).toList();
  }
  
  /// Get parser info for extension
  /// [extension] - file extension
  /// Returns parser info or null if not found
  static Map<String, dynamic>? getParserInfo(String extension) {
    final parser = getParserForExtension(extension);
    if (parser == null) return null;
    
    return {
      'type': parser.runtimeType.toString(),
      'extensions': parser.getSupportedExtensions(),
      'description': parser.getFormatDescription(),
      'mimeType': parser.getMimeType(),
      'priority': parser.getPriority(),
    };
  }
  
  /// Quick file validation
  /// [content] - file content
  /// [filename] - filename (optional)
  /// Returns true if the file is valid
  static bool isValidFile(String content, {String? filename}) {
    final parser = getParserForContent(content) ?? 
                  (filename != null ? getParserForFilename(filename) : null);
    
    if (parser == null) return false;
    
    try {
      // Use specialized methods if available
      if (parser is FlipperSubParser) {
        return parser.isValidFile(content);
      } else if (parser is TutJsonParser) {
        return parser.isValidFile(content);
      } else {
        // Fallback to base check
        return parser.canParse(content);
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Get file info without full parsing
  /// [content] - file content
  /// [filename] - filename (optional)
  /// Returns file info or null if indeterminate
  static Map<String, dynamic>? getFileInfo(String content, {String? filename}) {
    final parser = getParserForContent(content) ?? 
                  (filename != null ? getParserForFilename(filename) : null);
    
    if (parser == null) return null;
    
    try {
      // Use specialized methods if available
      if (parser is FlipperSubParser) {
        return parser.getFileInfo(content);
      } else if (parser is TutJsonParser) {
        return parser.getFileInfo(content);
      } else {
        // Fallback to base info
        return {
          'parser': parser.runtimeType.toString(),
          'extensions': parser.getSupportedExtensions(),
          'description': parser.getFormatDescription(),
          'size': content.length,
        };
      }
    } catch (e) {
      return {
        'error': e.toString(),
        'size': content.length,
      };
    }
  }
  
  /// Register a new parser
  /// [parser] - new parser to register
  static void registerParser(BaseFileParser parser) {
    // Check that parser is not already registered
    final existingParser = _parsers.firstWhere(
      (p) => p.runtimeType == parser.runtimeType,
      orElse: () => throw ArgumentError('Parser already registered'),
    );
    
    _parsers.add(parser);
  }
  
  /// Unregister parser
  /// [parserType] - parser type to remove
  static bool unregisterParser(Type parserType) {
    final initialLength = _parsers.length;
    _parsers.removeWhere((parser) => parser.runtimeType == parserType);
    return _parsers.length < initialLength;
  }
}

