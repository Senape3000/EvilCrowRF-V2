import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Firmware update metadata extracted from GitHub release asset filenames.
class FirmwareUpdate {
  final String version;
  final String? binUrl;
  final String? md5Url;
  final String changelog;
  final String? releaseDate;
  final List<Map<String, String>>? structuredChanges;

  FirmwareUpdate({
    required this.version,
    this.binUrl,
    this.md5Url,
    required this.changelog,
    this.releaseDate,
    this.structuredChanges,
  });
}

/// App update metadata extracted from GitHub release asset filenames.
class AppUpdate {
  final String version;
  final String? apkUrl;
  final String? md5Url;
  final String changelog;

  AppUpdate({
    required this.version,
    this.apkUrl,
    this.md5Url,
    required this.changelog,
  });
}

/// Service for checking and downloading updates from GitHub Releases.
///
/// **Version detection strategy:**
/// - Firmware: Looks for assets named `evilcrow-v2-fw-vX.Y.Z-OTA.bin`
///   (ignores `-full.bin` and `-TEST` builds).
/// - App: Looks for assets named `EvilCrowRF-vX.Y.Z.apk`
///   (ignores `-TEST` builds).
/// - Version is extracted from the **filename**, not the release tag.
/// - Release tags follow the maintainer's own numbering scheme.
///
/// See `docs/OTA_GitHub_Release_Guide.md` for the full setup guide.
class UpdateService {
  // ─────────────────────────────────────────────────────────────
  // CONFIGURATION — Set these to your GitHub repository
  // ─────────────────────────────────────────────────────────────
  static const String githubOwner = 'Senape3000';
  static const String githubRepo = 'EvilCrowRF-V2';
  // ─────────────────────────────────────────────────────────────

  static const String _apiBase =
      'https://api.github.com/repos/$githubOwner/$githubRepo';

  static const Duration _timeout = Duration(seconds: 15);

  // ── Filename patterns ──────────────────────────────────────

  /// Matches: evilcrow-v2-fw-v1.4.1-OTA.bin (capture version group)
  /// Ignores: *-TEST-OTA.bin, *-full.bin
  static final RegExp _fwOtaPattern = RegExp(
    r'evilcrow-v2-fw-v(\d+\.\d+\.\d+)-OTA\.bin$',
    caseSensitive: false,
  );

  /// Matches: EvilCrowRF-v1.0.0.apk (capture version group)
  /// Ignores: *-TEST.apk
  static final RegExp _apkPattern = RegExp(
    r'EvilCrowRF-v(\d+\.\d+\.\d+)\.apk$',
    caseSensitive: false,
  );

  /// Check for a new firmware release on GitHub.
  /// Scans ALL releases for the newest OTA binary by filename version.
  /// Returns [FirmwareUpdate] if a newer version exists, `null` otherwise.
  /// Throws [UpdateServiceException] on network/API errors.
  static Future<FirmwareUpdate?> checkFirmwareUpdate(
      String currentVersion) async {
    try {
      final releases = await _fetchReleases();
      // Fetch structured changelog from release assets
      final changelogData = await fetchChangelog(releases);

      String? bestVersion;
      Map<String, dynamic>? bestRelease;
      Map<String, dynamic>? bestAsset;
      Map<String, dynamic>? bestMd5Asset;

      for (final release in releases) {
        if (release['draft'] == true) continue;
        final assets = release['assets'] as List? ?? [];

        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          final match = _fwOtaPattern.firstMatch(name);
          if (match == null) continue;

          final fileVersion = match.group(1)!;
          if (bestVersion == null || _isNewer(fileVersion, bestVersion)) {
            bestVersion = fileVersion;
            bestRelease = release;
            bestAsset = asset;
            // Look for corresponding .md5 file in same release
            bestMd5Asset = _findMd5Asset(assets, name);
          }
        }
      }

      if (bestVersion == null || !_isNewer(bestVersion, currentVersion)) {
        return null;
      }

      // Prefer structured changelog from changelog.json, fall back to release body
      String changelogText;
      List<Map<String, String>>? structuredChanges;
      if (changelogData != null) {
        changelogText = buildChangelogText(changelogData, 'firmware', bestVersion);
        structuredChanges = getChangesForVersion(changelogData, 'firmware', bestVersion);
        if (changelogText.isEmpty) {
          changelogText = bestRelease?['body'] ?? 'No changelog available.';
        }
      } else {
        changelogText = bestRelease?['body'] ?? 'No changelog available.';
      }

      return FirmwareUpdate(
        version: bestVersion,
        binUrl: bestAsset?['browser_download_url'] as String?,
        md5Url: bestMd5Asset?['browser_download_url'] as String?,
        changelog: changelogText,
        releaseDate: bestRelease?['published_at'],
        structuredChanges: structuredChanges,
      );
    } on UpdateServiceException {
      rethrow;
    } catch (e) {
      throw UpdateServiceException('API Error: $e');
    }
  }

  /// Check for a new app release on GitHub.
  /// Scans ALL releases for the newest APK by filename version.
  /// Returns [AppUpdate] if a newer version exists, `null` otherwise.
  /// Throws [UpdateServiceException] on network/API errors.
  static Future<AppUpdate?> checkAppUpdate(String currentVersion) async {
    try {
      final releases = await _fetchReleases();
      // Fetch structured changelog from release assets
      final changelogData = await fetchChangelog(releases);

      String? bestVersion;
      Map<String, dynamic>? bestRelease;
      Map<String, dynamic>? bestAsset;
      Map<String, dynamic>? bestMd5Asset;

      for (final release in releases) {
        if (release['draft'] == true) continue;
        final assets = release['assets'] as List? ?? [];

        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          final match = _apkPattern.firstMatch(name);
          if (match == null) continue;

          final fileVersion = match.group(1)!;
          if (bestVersion == null || _isNewer(fileVersion, bestVersion)) {
            bestVersion = fileVersion;
            bestRelease = release;
            bestAsset = asset;
            bestMd5Asset = _findMd5Asset(assets, name);
          }
        }
      }

      if (bestVersion == null || !_isNewer(bestVersion, currentVersion)) {
        return null;
      }

      // Prefer structured changelog from changelog.json, fall back to release body
      String changelogText;
      if (changelogData != null) {
        changelogText = buildChangelogText(changelogData, 'app', bestVersion);
        if (changelogText.isEmpty) {
          changelogText = bestRelease?['body'] ?? 'No changelog available.';
        }
      } else {
        changelogText = bestRelease?['body'] ?? 'No changelog available.';
      }

      return AppUpdate(
        version: bestVersion,
        apkUrl: bestAsset?['browser_download_url'] as String?,
        md5Url: bestMd5Asset?['browser_download_url'] as String?,
        changelog: changelogText,
      );
    } on UpdateServiceException {
      rethrow;
    } catch (e) {
      throw UpdateServiceException('API Error: $e');
    }
  }

  /// Download firmware binary from URL.
  /// Verifies MD5 if [expectedMd5] is provided.
  /// Returns the firmware bytes or throws [UpdateServiceException].
  static Future<Uint8List> downloadFirmware(
    String binUrl, {
    String? expectedMd5,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(binUrl));
      final streamedResponse =
          await request.send().timeout(_timeout * 3); // 45s for download

      if (streamedResponse.statusCode != 200) {
        throw UpdateServiceException(
            'Download failed: HTTP ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      final List<int> bytes = [];
      int received = 0;

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(received / totalBytes);
        }
      }

      final firmwareBytes = Uint8List.fromList(bytes);

      // MD5 verification
      if (expectedMd5 != null && expectedMd5.isNotEmpty) {
        final calculatedMd5 = md5.convert(firmwareBytes).toString();
        if (calculatedMd5 != expectedMd5.trim().toLowerCase()) {
          throw UpdateServiceException(
              'MD5 mismatch!\nExpected: $expectedMd5\nGot: $calculatedMd5');
        }
      }

      return firmwareBytes;
    } on UpdateServiceException {
      rethrow;
    } catch (e) {
      throw UpdateServiceException('Download error: $e');
    }
  }

  /// Download the MD5 hash file content from a URL.
  /// Returns the hash string (first word of the file), or `null` on failure.
  static Future<String?> downloadMd5(String md5Url) async {
    try {
      final response =
          await http.get(Uri.parse(md5Url)).timeout(_timeout);
      if (response.statusCode == 200) {
        // MD5 file format: "hash  filename" or just "hash"
        return response.body.trim().split(RegExp(r'\s+')).first.toLowerCase();
      }
      return null;
    } catch (_) {
      return null; // Non-fatal — firmware will still verify on-device
    }
  }

  /// Download APK and save to temp directory for installation.
  /// Returns the local file path.
  static Future<String> downloadApk(
    String apkUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 120));

      if (streamedResponse.statusCode != 200) {
        throw UpdateServiceException(
            'APK download failed: HTTP ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      // Save APK to public Downloads directory (user-accessible)
      final downloadsDir = await _getDownloadsDirectory();
      final file = File('${downloadsDir.path}/EvilCrowRF_update.apk');
      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(received / totalBytes);
        }
      }

      await sink.close();
      return file.path;
    } on UpdateServiceException {
      rethrow;
    } catch (e) {
      throw UpdateServiceException('APK download error: $e');
    }
  }

  // ── Private helpers ──────────────────────────────────────────

  /// Get the public Downloads directory on Android, or temp as fallback.
  static Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final downloadsPath = '/storage/emulated/0/Download';
      final dir = Directory(downloadsPath);
      if (await dir.exists()) {
        return dir;
      }
    }
    // Fallback: temp directory
    return await getTemporaryDirectory();
  }

  /// Fetch the structured changelog from changelog.json in release assets.
  /// Searches through releases to find changelog.json as an asset.
  /// Returns a map with "firmware" and "app" lists parsed from the JSON.
  /// Returns null on failure (non-fatal — falls back to release body).
  static Future<Map<String, dynamic>?> fetchChangelog(List<dynamic> releases) async {
    // Try to find changelog.json in release assets (newest first)
    for (final release in releases) {
      if (release['draft'] == true) continue;
      final assets = release['assets'] as List? ?? [];
      
      // Look for changelog.json asset
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase() == 'changelog.json') {
          final downloadUrl = asset['browser_download_url'] as String?;
          if (downloadUrl == null) continue;
          
          try {
            final response = await http.get(
              Uri.parse(downloadUrl),
            ).timeout(_timeout);
            if (response.statusCode == 200) {
              return jsonDecode(response.body) as Map<String, dynamic>;
            }
          } catch (e) {
            // Continue searching in other releases
            continue;
          }
        }
      }
    }
    
    // Fallback: try legacy URL from main branch (for backward compatibility)
    try {
      const legacyUrl = 'https://raw.githubusercontent.com/$githubOwner/$githubRepo/main/releases/changelog.json';
      final response = await http.get(
        Uri.parse(legacyUrl),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Ignore fallback errors
    }
    
    return null;
  }

  /// Extract structured changes list for a specific version from changelog.json.
  /// Returns a list of maps with 'type' and 'text' keys, or null if not found.
  static List<Map<String, String>>? getChangesForVersion(
      Map<String, dynamic> changelog, String type, String version) {
    final entries = changelog[type] as List? ?? [];
    for (final entry in entries) {
      if (entry['version'] == version) {
        final changes = entry['changes'] as List? ?? [];
        return changes
            .map((c) => {
                  'type': (c['type'] as String? ?? 'improvement'),
                  'text': (c['text'] as String? ?? ''),
                })
            .toList();
      }
    }
    return null;
  }

  /// Build a human-readable changelog string for a specific version
  /// from the structured changelog.json data.
  /// [type] is either "firmware" or "app".
  static String buildChangelogText(
      Map<String, dynamic> changelog, String type, String version) {
    final entries = changelog[type] as List? ?? [];
    final buffer = StringBuffer();

    for (final entry in entries) {
      final ver = entry['version'] as String? ?? '';
      if (ver == version || buffer.isEmpty) {
        buffer.writeln('v$ver (${entry['date'] ?? ''})');
        final changes = entry['changes'] as List? ?? [];
        for (final change in changes) {
          final changeType = (change['type'] as String? ?? '').toUpperCase();
          final text = change['text'] as String? ?? '';
          buffer.writeln('  [$changeType] $text');
        }
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  /// Build a full changelog string showing all versions for a type.
  static String buildFullChangelog(
      Map<String, dynamic> changelog, String type) {
    final entries = changelog[type] as List? ?? [];
    final buffer = StringBuffer();

    for (final entry in entries) {
      final ver = entry['version'] as String? ?? '';
      buffer.writeln('v$ver (${entry['date'] ?? ''})');
      final changes = entry['changes'] as List? ?? [];
      for (final change in changes) {
        final changeType = (change['type'] as String? ?? '').toUpperCase();
        final text = change['text'] as String? ?? '';
        buffer.writeln('  [$changeType] $text');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// Fetch all releases from GitHub API.
  static Future<List<dynamic>> _fetchReleases() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/releases'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else if (response.statusCode == 404) {
        throw UpdateServiceException(
            'Repository not found: $githubOwner/$githubRepo');
      } else if (response.statusCode == 403) {
        throw UpdateServiceException(
            'API rate limit exceeded. Try again later.');
      } else {
        throw UpdateServiceException(
            'API Error: HTTP ${response.statusCode}');
      }
    } on UpdateServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw UpdateServiceException('Network error: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw UpdateServiceException('Connection timeout. Check your network.');
      }
      throw UpdateServiceException('API Error: $e');
    }
  }

  /// Find the download URL for an asset with a given extension.
  static String? _findAssetUrl(
      Map<String, dynamic> release, String extension) {
    final assets = release['assets'] as List? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith(extension)) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// Find the corresponding .md5 asset for a given binary asset name.
  /// E.g., for "evilcrow-v2-fw-v1.4.1-OTA.bin" → "...OTA.bin.md5"
  static Map<String, dynamic>? _findMd5Asset(
      List<dynamic> assets, String binName) {
    final md5Name = '$binName.md5';
    for (final asset in assets) {
      if ((asset['name'] as String? ?? '') == md5Name) {
        return asset as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Compare two semantic version strings (e.g., "1.2.3" vs "1.1.0").
  /// Returns true if [newVersion] is strictly newer than [currentVersion].
  static bool _isNewer(String newVersion, String currentVersion) {
    final newParts = newVersion.split('.').map(int.tryParse).toList();
    final curParts = currentVersion.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final n = i < newParts.length ? (newParts[i] ?? 0) : 0;
      final c = i < curParts.length ? (curParts[i] ?? 0) : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false; // Same version
  }
}

/// Exception thrown by [UpdateService] on errors.
class UpdateServiceException implements Exception {
  final String message;
  UpdateServiceException(this.message);

  @override
  String toString() => message;
}
