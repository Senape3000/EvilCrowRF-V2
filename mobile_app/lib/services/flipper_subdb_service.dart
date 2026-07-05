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
    Future<void> Function(List<int> zipBytes)? onZipDownloaded,
  }) async {
    const maxRetries = 3;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _doDownloadAndExtract(
          onProgress: onProgress,
          onZipDownloaded: onZipDownloaded,
          attempt: attempt,
        );
      } on Exception catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          onProgress?.call(
            'download',
            'Connection lost — retrying (attempt ${attempt + 1}/$maxRetries)...',
            0.0,
          );
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }

    throw Exception(
      'Failed to download after $maxRetries attempts: $lastError',
    );
  }

  static Future<List<SubFileEntry>> _doDownloadAndExtract({
    void Function(String phase, String detail, double fraction)? onProgress,
    Future<void> Function(List<int> zipBytes)? onZipDownloaded,
    int attempt = 1,
  }) async {
    final client = http.Client();
    try {
      onProgress?.call('download', 'Connecting to GitHub...', 0.0);

      final request = http.Request('GET', Uri.parse(_repoZipUrl));
      request.headers['User-Agent'] = 'EvilCrowRF-App';
      request.headers['Accept'] = 'application/zip';

      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 60),
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

      await onZipDownloaded?.call(zipBytes);

      onProgress?.call('extract', 'Decompressing ZIP...', 0.0);

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final subFiles = <SubFileEntry>[];
      String? rootPrefix;
      const String subghzFolder = 'subghz/';

      int processed = 0;
      final total = archive.files.length;

      for (final file in archive.files) {
        processed++;
        if (file.isFile) {
          final name = file.name;
          rootPrefix ??= _extractRootPrefix(name);
          if (name.toLowerCase().endsWith('.sub')) {
            String relativePath = name;
            if (rootPrefix != null && relativePath.startsWith(rootPrefix)) {
              relativePath = relativePath.substring(rootPrefix.length);
            }
            if (relativePath.startsWith(subghzFolder)) {
              relativePath = relativePath.substring(subghzFolder.length);
            }
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

      onProgress?.call('extract', '${subFiles.length} .sub files extracted', 1.0);

      return subFiles;
    } finally {
      client.close();
    }
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

  // ---------------------------------------------------------------------------
  // Progress persistence for Pause / Resume
  // ---------------------------------------------------------------------------

  static const String _progressFileName = 'clone_progress.json';
  static const String _cachedZipFileName = 'clone_cached.zip';

  /// Return the app-data directory used for clone cache files.
  static Future<Directory> _cacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/clone_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Check whether a resumable clone session exists.
  static Future<bool> hasResumableSession() async {
    final dir = await _cacheDir();
    final progressFile = File('${dir.path}/$_progressFileName');
    final zipFile = File('${dir.path}/$_cachedZipFileName');
    return await progressFile.exists() && await zipFile.exists();
  }

  /// Load the set of already-uploaded relative paths from the progress file.
  static Future<Set<String>> loadCompletedFiles() async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/$_progressFileName');
    if (!await file.exists()) return {};
    try {
      final json = jsonDecode(await file.readAsString());
      return Set<String>.from(json['completed'] as List);
    } catch (_) {
      return {};
    }
  }

  /// Save the set of completed file paths (call after each successful upload).
  static Future<void> saveProgress(Set<String> completedPaths) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/$_progressFileName');
    await file.writeAsString(jsonEncode({'completed': completedPaths.toList()}));
  }

  /// Cache the raw ZIP bytes so we don't have to re-download on resume.
  static Future<void> cacheZipBytes(List<int> zipBytes) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/$_cachedZipFileName');
    await file.writeAsBytes(zipBytes);
  }

  /// Load cached ZIP bytes for resume.
  static Future<List<int>?> loadCachedZip() async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/$_cachedZipFileName');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  /// Delete all clone cache files (call on completion or manual reset).
  static Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Extract .sub files from already-downloaded ZIP bytes.
  /// Same logic as [downloadAndExtract] phase 2, but without downloading.
  static List<SubFileEntry> extractFromBytes(
    List<int> zipBytes, {
    void Function(String phase, String detail, double fraction)? onProgress,
  }) {
    onProgress?.call('extract', 'Decompressing cached ZIP...', 0.0);

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final subFiles = <SubFileEntry>[];
    String? rootPrefix;
    const String subghzFolder = 'subghz/';

    int processed = 0;
    final total = archive.files.length;

    for (final file in archive.files) {
      processed++;
      if (file.isFile) {
        final name = file.name;
        rootPrefix ??= _extractRootPrefix(name);

        if (name.toLowerCase().endsWith('.sub')) {
          String relativePath = name;
          if (rootPrefix != null && relativePath.startsWith(rootPrefix)) {
            relativePath = relativePath.substring(rootPrefix.length);
          }
          if (relativePath.startsWith(subghzFolder)) {
            relativePath = relativePath.substring(subghzFolder.length);
          }
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

    onProgress?.call('extract', '${subFiles.length} .sub files extracted', 1.0);
    return subFiles;
  }
}
