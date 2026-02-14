import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Entry representing a .sub file extracted from the FlipperZero SubGHz DB.
class SubFileEntry {
  /// Relative path preserving subfolder structure (e.g. "Garage/CAME/gate.sub")
  final String relativePath;

  /// Raw file content bytes
  final Uint8List content;

  const SubFileEntry({required this.relativePath, required this.content});
}

/// Service for downloading and extracting FlipperZero SubGHz .sub files
/// from the Zero-Sploit/FlipperZero-Subghz-DB GitHub repository.
class FlipperSubDbService {
  static const String _repoZipUrl =
      'https://github.com/Zero-Sploit/FlipperZero-Subghz-DB/archive/refs/heads/main.zip';

  /// Target folder name on the device SDCard
  static const String sdTargetFolder = 'SUB Files';

  /// Download the repository ZIP and extract all .sub files.
  ///
  /// Returns a list of [SubFileEntry] with relative paths and content.
  /// [onProgress] callback receives (phase, detail, fraction):
  ///   - phase "download": downloading ZIP from GitHub
  ///   - phase "extract": extracting .sub files from ZIP
  static Future<List<SubFileEntry>> downloadAndExtract({
    void Function(String phase, String detail, double fraction)? onProgress,
  }) async {
    // --- Phase 1: Download ZIP ---
    onProgress?.call('download', 'Connecting to GitHub...', 0.0);

    final request = http.Request('GET', Uri.parse(_repoZipUrl));
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );

    if (streamedResponse.statusCode != 200) {
      throw Exception(
          'Failed to download repository: HTTP ${streamedResponse.statusCode}');
    }

    final totalBytes = streamedResponse.contentLength ?? 0;
    final List<int> zipBytes = [];
    int received = 0;

    await for (final chunk in streamedResponse.stream) {
      zipBytes.addAll(chunk);
      received += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(
          'download',
          '${(received / 1024 / 1024).toStringAsFixed(1)} MB downloaded',
          received / totalBytes,
        );
      }
    }

    onProgress?.call('download', 'Download complete', 1.0);

    // --- Phase 2: Extract .sub files ---
    onProgress?.call('extract', 'Decompressing ZIP...', 0.0);

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final subFiles = <SubFileEntry>[];

    // The ZIP contains a root folder like "FlipperZero-Subghz-DB-main/"
    // We strip that prefix to get clean relative paths.
    String? rootPrefix;

    int processed = 0;
    final total = archive.files.length;

    for (final file in archive.files) {
      processed++;
      if (file.isFile) {
        final name = file.name;

        // Determine root prefix from first file
        rootPrefix ??= _extractRootPrefix(name);

        // Only include .sub files (skip README, LICENSE, etc.)
        if (name.toLowerCase().endsWith('.sub')) {
          String relativePath = name;
          if (rootPrefix != null && relativePath.startsWith(rootPrefix)) {
            relativePath = relativePath.substring(rootPrefix.length);
          }
          // Skip empty paths
          if (relativePath.isNotEmpty) {
            subFiles.add(SubFileEntry(
              relativePath: relativePath,
              content: Uint8List.fromList(file.content as List<int>),
            ));
          }
        }
      }

      if (total > 0) {
        onProgress?.call(
          'extract',
          'Extracting files... (${subFiles.length} .sub files found)',
          processed / total,
        );
      }
    }

    onProgress?.call(
      'extract',
      '${subFiles.length} .sub files extracted',
      1.0,
    );

    return subFiles;
  }

  /// Extract the root folder prefix from a ZIP entry path.
  /// e.g., "FlipperZero-Subghz-DB-main/folder/file.sub" → "FlipperZero-Subghz-DB-main/"
  static String? _extractRootPrefix(String path) {
    final slashIndex = path.indexOf('/');
    if (slashIndex > 0) {
      return path.substring(0, slashIndex + 1);
    }
    return null;
  }
}
