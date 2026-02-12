import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import '../providers/ble_provider.dart';
import '../providers/firmware_protocol.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'dart:math';
import 'dart:io';

/// OTA firmware update screen — BLE OTA transfer with GitHub release integration.
class OtaScreen extends StatefulWidget {
  const OtaScreen({super.key});

  @override
  State<OtaScreen> createState() => _OtaScreenState();
}

class _OtaScreenState extends State<OtaScreen> with TickerProviderStateMixin {
  // Current device firmware version (from VersionInfo 0xC2)
  String _currentVersion = 'Unknown';

  // GitHub release info
  bool _checkingUpdate = false;
  String? _latestVersion;
  String? _latestChangelog;
  String? _firmwareUrl;
  String? _firmwareMd5;
  bool _updateAvailable = false;

  // OTA transfer state
  bool _downloading = false;
  bool _transferring = false;
  double _transferProgress = 0.0;
  String _statusMessage = '';
  bool _transferComplete = false;
  bool _transferError = false;
  String _errorMessage = '';
  DateTime? _transferStartTime;
  String _transferSpeed = '';

  // Downloaded firmware binary
  Uint8List? _firmwareBin;

  // Structured changelog data from changelog.json
  List<Map<String, String>>? _latestChanges;

  // Pulse animation for update-available sparkle effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Local binary flash (debug mode only)
  String? _localBinPath;
  Uint8List? _localBin;
  bool _localTransferring = false;
  double _localTransferProgress = 0.0;
  String _localStatusMessage = '';
  bool _localTransferComplete = false;
  bool _localTransferError = false;
  String _localErrorMessage = '';

  @override
  void initState() {
    super.initState();
    // Pulse animation for sparkle effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Try to get current version from BleProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentVersion();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _loadCurrentVersion() {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final version = bleProvider.firmwareVersion;
    if (version.isNotEmpty) {
      setState(() => _currentVersion = version);
    }
  }

  // ── GitHub Release Check ────────────────────────────────────

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingUpdate = true;
      _updateAvailable = false;
      _latestVersion = null;
      _latestChangelog = null;
      _firmwareUrl = null;
      _firmwareMd5 = null;
      _statusMessage = '';
    });

    try {
      final update =
          await UpdateService.checkFirmwareUpdate(_currentVersion);

      if (update == null) {
        setState(() {
          _checkingUpdate = false;
          _statusMessage = 'No new version available.';
        });
        return;
      }

      // Download MD5 hash if available
      String? md5Hash;
      if (update.md5Url != null) {
        md5Hash = await UpdateService.downloadMd5(update.md5Url!);
      }

      setState(() {
        _latestVersion = update.version;
        _latestChangelog = update.changelog;
        _latestChanges = update.structuredChanges;
        _firmwareUrl = update.binUrl;
        _firmwareMd5 = md5Hash;
        _updateAvailable = update.binUrl != null;
        _checkingUpdate = false;
      });

      // Start sparkle animation when update is available
      if (_updateAvailable) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    } on UpdateServiceException catch (e) {
      setState(() {
        _checkingUpdate = false;
        _statusMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _checkingUpdate = false;
        _statusMessage = 'API Error: $e';
      });
    }
  }

  // ── Download Firmware Binary ────────────────────────────────

  Future<void> _downloadFirmware() async {
    if (_firmwareUrl == null) return;

    setState(() {
      _downloading = true;
      _statusMessage = 'Downloading firmware...';
    });

    try {
      final response = await http.get(Uri.parse(_firmwareUrl!));
      if (response.statusCode == 200) {
        _firmwareBin = response.bodyBytes;

        // Verify MD5 if available
        if (_firmwareMd5 != null) {
          final digest = _calculateMd5(_firmwareBin!);
          if (digest != _firmwareMd5) {
            setState(() {
              _downloading = false;
              _transferError = true;
              _errorMessage = 'MD5 mismatch!\nExpected: $_firmwareMd5\nGot: $digest';
              _firmwareBin = null;
            });
            return;
          }
        }

        setState(() {
          _downloading = false;
          _statusMessage = 'Download complete (${_firmwareBin!.length} bytes)';
        });
      } else {
        setState(() {
          _downloading = false;
          _statusMessage = 'Download failed: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _downloading = false;
        _statusMessage = 'Download error: $e';
      });
    }
  }

  /// Calculate MD5 hash of firmware bytes
  String _calculateMd5(Uint8List data) {
    return md5.convert(data).toString();
  }

  // ── BLE OTA Transfer ───────────────────────────────────────

  /// Format duration as m:ss
  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startOtaTransfer() async {
    if (_firmwareBin == null) return;

    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    if (!bleProvider.isConnected) return;

    // Keep screen on during transfer
    WakelockPlus.enable();

    setState(() {
      _transferring = true;
      _transferProgress = 0.0;
      _transferComplete = false;
      _transferError = false;
      _transferStartTime = DateTime.now();
      _transferSpeed = '';
      _statusMessage = 'Starting OTA transfer...';
    });

    try {
      // Step 1: Send OTA_BEGIN with firmware size and MD5 (with response for reliability)
      final md5Str = _firmwareMd5 ?? '';
      final beginCmd = FirmwareBinaryProtocol.createOtaBeginCommand(
        _firmwareBin!.length, md5Str,
      );
      await bleProvider.sendBinaryCommand(beginCmd);
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: Send firmware data in chunks using writeWithoutResponse for speed
      const chunkSize = 480; // Fits within 512 MTU with protocol overhead
      final totalChunks = (_firmwareBin!.length / chunkSize).ceil();
      final totalBytes = _firmwareBin!.length;

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = min(start + chunkSize, totalBytes);
        final chunk = _firmwareBin!.sublist(start, end);

        final dataCmd = FirmwareBinaryProtocol.createOtaDataCommand(
          Uint8List.fromList(chunk),
        );
        // Use writeWithoutResponse for much faster throughput
        await bleProvider.sendBinaryCommand(dataCmd, withoutResponse: true);

        // Update UI every 20 chunks to reduce setState overhead
        if (i % 20 == 0 || i == totalChunks - 1) {
          final elapsed = DateTime.now().difference(_transferStartTime!);
          final bytesSent = end;
          final speedKBs = elapsed.inMilliseconds > 0
              ? (bytesSent / 1024) / (elapsed.inMilliseconds / 1000)
              : 0.0;
          final remaining = speedKBs > 0
              ? Duration(seconds: ((totalBytes - bytesSent) / 1024 / speedKBs).round())
              : Duration.zero;

          setState(() {
            _transferProgress = (i + 1) / totalChunks;
            _transferSpeed = '${speedKBs.toStringAsFixed(1)} KB/s';
            _statusMessage = 'Chunk ${i + 1}/$totalChunks · '
                '$_transferSpeed · '
                'ETA ${_formatDuration(remaining)}';
          });
        }

        // Small delay to prevent BLE buffer overflow
        // 6ms is ~3-4x faster than the previous 30ms
        await Future.delayed(const Duration(milliseconds: 6));
      }

      // Step 3: Send OTA_END (with response for reliability)
      final endCmd = FirmwareBinaryProtocol.createOtaEndCommand();
      await bleProvider.sendBinaryCommand(endCmd);

      final totalTime = DateTime.now().difference(_transferStartTime!);
      setState(() {
        _transferring = false;
        _transferComplete = true;
        _statusMessage = 'OTA complete! '
            '${(totalBytes / 1024).toStringAsFixed(0)} KB in '
            '${_formatDuration(totalTime)} · '
            'Device will reboot.';
      });
    } catch (e) {
      setState(() {
        _transferring = false;
        _transferError = true;
        _errorMessage = 'Transfer failed: $e';
        _statusMessage = 'OTA transfer failed';
      });

      // Send abort to firmware
      try {
        final abortCmd = FirmwareBinaryProtocol.createOtaAbortCommand();
        await bleProvider.sendBinaryCommand(abortCmd);
      } catch (_) {}
    } finally {
      // Release wake lock
      WakelockPlus.disable();
    }
  }

  // ── Local Binary Flash (Debug Mode) ──────────────────────────

  Future<void> _pickLocalBinary() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _localBinPath = result.files.single.name;
          _localBin = result.files.single.bytes;
          _localStatusMessage = 'Selected: $_localBinPath (${_localBin!.length} bytes)';
          _localTransferComplete = false;
          _localTransferError = false;
        });
      }
    } catch (e) {
      setState(() {
        _localStatusMessage = 'File picker error: $e';
      });
    }
  }

  Future<void> _flashLocalBinary() async {
    if (_localBin == null) return;

    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    if (!bleProvider.isConnected) return;

    // Keep screen on during transfer
    WakelockPlus.enable();

    setState(() {
      _localTransferring = true;
      _localTransferProgress = 0.0;
      _localTransferComplete = false;
      _localTransferError = false;
      _localStatusMessage = 'Starting local OTA transfer...';
    });

    final startTime = DateTime.now();

    try {
      // Calculate MD5 of local binary
      final localMd5 = _calculateMd5(_localBin!);

      // Step 1: Send OTA_BEGIN with firmware size and MD5
      final beginCmd = FirmwareBinaryProtocol.createOtaBeginCommand(
        _localBin!.length, localMd5,
      );
      await bleProvider.sendBinaryCommand(beginCmd);
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: Send firmware data in chunks using writeWithoutResponse
      const chunkSize = 480;
      final totalChunks = (_localBin!.length / chunkSize).ceil();
      final totalBytes = _localBin!.length;

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = min(start + chunkSize, totalBytes);
        final chunk = _localBin!.sublist(start, end);

        final dataCmd = FirmwareBinaryProtocol.createOtaDataCommand(
          Uint8List.fromList(chunk),
        );
        await bleProvider.sendBinaryCommand(dataCmd, withoutResponse: true);

        // Update UI every 20 chunks
        if (i % 20 == 0 || i == totalChunks - 1) {
          final elapsed = DateTime.now().difference(startTime);
          final bytesSent = end;
          final speedKBs = elapsed.inMilliseconds > 0
              ? (bytesSent / 1024) / (elapsed.inMilliseconds / 1000)
              : 0.0;
          final remaining = speedKBs > 0
              ? Duration(seconds: ((totalBytes - bytesSent) / 1024 / speedKBs).round())
              : Duration.zero;

          setState(() {
            _localTransferProgress = (i + 1) / totalChunks;
            _localStatusMessage = 'Chunk ${i + 1}/$totalChunks · '
                '${speedKBs.toStringAsFixed(1)} KB/s · '
                'ETA ${_formatDuration(remaining)}';
          });
        }

        await Future.delayed(const Duration(milliseconds: 6));
      }

      // Step 3: Send OTA_END
      final endCmd = FirmwareBinaryProtocol.createOtaEndCommand();
      await bleProvider.sendBinaryCommand(endCmd);

      final totalTime = DateTime.now().difference(startTime);
      setState(() {
        _localTransferring = false;
        _localTransferComplete = true;
        _localStatusMessage = 'Local OTA complete! '
            '${(totalBytes / 1024).toStringAsFixed(0)} KB in '
            '${_formatDuration(totalTime)}';
      });
    } catch (e) {
      setState(() {
        _localTransferring = false;
        _localTransferError = true;
        _localErrorMessage = 'Local transfer failed: $e';
        _localStatusMessage = 'Local OTA transfer failed';
      });

      try {
        final abortCmd = FirmwareBinaryProtocol.createOtaAbortCommand();
        await bleProvider.sendBinaryCommand(abortCmd);
      } catch (_) {}
    } finally {
      WakelockPlus.disable();
    }
  }

  Future<void> _rebootDevice() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    if (!bleProvider.isConnected) return;

    // Notify BLE provider to auto-reconnect after reboot
    bleProvider.notifyOtaReboot();
    
    final cmd = FirmwareBinaryProtocol.createOtaRebootCommand();
    await bleProvider.sendBinaryCommand(cmd);

    if (!mounted) return;

    // Show reboot dialog with animated timer
    final goHome = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _RebootDialog(),
    );

    if (goHome == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDebugMode = settingsProvider.debugMode;

    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        // Keep current version in sync with BLE provider
        if (bleProvider.firmwareVersion.isNotEmpty && _currentVersion == 'Unknown') {
          _currentVersion = bleProvider.firmwareVersion;
        }
        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.otaUpdate),
            backgroundColor: AppColors.secondaryBackground,
            foregroundColor: AppColors.primaryText,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVersionCard(bleProvider),
                const SizedBox(height: 16),
                _buildUpdateCheckCard(),
                if (_updateAvailable && _latestChangelog != null) ...[
                  const SizedBox(height: 16),
                  _buildChangelogCard(),
                ],
                if (_firmwareBin != null || _transferring || _transferComplete) ...[
                  const SizedBox(height: 16),
                  _buildTransferCard(),
                ],
                if (_transferError) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(),
                ],
                // Local binary flash — only visible in debug mode
                if (isDebugMode) ...[
                  const SizedBox(height: 24),
                  _buildLocalFlashCard(bleProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionCard(BleProvider bleProvider) {
    return _buildCard(
      title: AppLocalizations.of(context)!.deviceInfo,
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(AppLocalizations.of(context)!.currentFirmware, _currentVersion),
          if (bleProvider.freeHeap != null)
            _buildInfoRow('Free Heap', '${bleProvider.freeHeap} bytes'),
          _buildInfoRow(AppLocalizations.of(context)!.connection, bleProvider.isConnected ? AppLocalizations.of(context)!.connectedStatus : AppLocalizations.of(context)!.disconnectedStatus),
        ],
      ),
    );
  }

  Widget _buildUpdateCheckCard() {
    return _buildCard(
      title: AppLocalizations.of(context)!.firmwareUpdate,
      icon: Icons.system_update,
      child: Column(
        children: [
          if (_latestVersion != null) ...[
            _buildInfoRow(AppLocalizations.of(context)!.latestVersion, _latestVersion!),
            _updateAvailable
                ? _buildUpdateAvailableRow()
                : _buildInfoRow(AppLocalizations.of(context)!.updateAvailable, AppLocalizations.of(context)!.upToDate),
            if (_firmwareMd5 != null)
              GestureDetector(
                onTap: () => _showMd5Dialog(),
                child: _buildInfoRow('MD5', '${_firmwareMd5!.substring(0, min(16, _firmwareMd5!.length))}…'),
              ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _checkingUpdate ? null : _checkForUpdates,
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryAccent))
                      : const Icon(Icons.refresh),
                  label: Text(_checkingUpdate ? AppLocalizations.of(context)!.checking : AppLocalizations.of(context)!.checkForUpdates),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.primaryBackground,
                  ),
                ),
              ),
              if (_updateAvailable && _firmwareBin == null && !_downloading) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warning.withValues(alpha: 0.3 + 0.35 * _pulseAnimation.value),
                              blurRadius: 6 + 8 * _pulseAnimation.value,
                              spreadRadius: 1 + 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: _downloadFirmware,
                      icon: const Icon(Icons.download),
                      label: Text(AppLocalizations.of(context)!.download),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.primaryBackground,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_downloading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                color: AppColors.primaryAccent,
                backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              ),
            ),
          if (_statusMessage.isNotEmpty && !_transferring && !_transferComplete)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_statusMessage,
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildChangelogCard() {
    return _buildCard(
      title: AppLocalizations.of(context)!.changelogVersion(_latestVersion ?? ''),
      icon: Icons.description,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_latestChanges != null && _latestChanges!.isNotEmpty)
                ..._latestChanges!.map((change) {
                  final type = (change['type'] ?? 'improvement').toUpperCase();
                  final text = change['text'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getChangeTypeColor(type).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: _getChangeTypeColor(type),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(color: AppColors.primaryText, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                })
              else
                Text(
                  _latestChangelog ?? '',
                  style: TextStyle(color: AppColors.primaryText, fontSize: 13, height: 1.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferCard() {
    return _buildCard(
      title: AppLocalizations.of(context)!.otaTransfer,
      icon: Icons.upload,
      child: Column(
        children: [
          if (_transferring) ...[
            Text(_statusMessage,
                style: TextStyle(color: AppColors.primaryText, fontSize: 13)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _transferProgress,
                minHeight: 12,
                color: AppColors.primaryAccent,
                backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 8),
            Text('${(_transferProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
          if (_transferComplete) ...[
            const Center(
              child: Icon(Icons.check_circle, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(AppLocalizations.of(context)!.firmwareUploadedSuccess,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(AppLocalizations.of(context)!.deviceWillVerify,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _rebootDevice,
              icon: const Icon(Icons.restart_alt),
              label: Text(AppLocalizations.of(context)!.rebootDevice),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.primaryBackground,
              ),
            ),
          ],
          if (!_transferring && !_transferComplete && _firmwareBin != null) ...[
            Text(AppLocalizations.of(context)!.firmwareReady(_firmwareBin!.length),
                style: TextStyle(color: AppColors.primaryText, fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startOtaTransfer,
                icon: const Icon(Icons.upload),
                label: Text(AppLocalizations.of(context)!.startOtaUpdate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: AppColors.primaryBackground,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.error,
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_errorMessage,
              style: TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  /// Debug-only card: pick a local .bin file and flash via BLE OTA.
  Widget _buildLocalFlashCard(BleProvider bleProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(Icons.developer_mode, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.flashLocalBinary,
                    style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('DEBUG',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.borderDefault, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.selectBinFileDesc,
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_localTransferring) ? null : _pickLocalBinary,
                        icon: const Icon(Icons.folder_open),
                        label: Text(AppLocalizations.of(context)!.selectBin),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: AppColors.primaryBackground,
                        ),
                      ),
                    ),
                    if (_localBin != null && !_localTransferring && !_localTransferComplete) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: bleProvider.isConnected ? _flashLocalBinary : null,
                          icon: const Icon(Icons.flash_on),
                          label: Text(AppLocalizations.of(context)!.flash),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_localBinPath != null && !_localTransferring && !_localTransferComplete)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('File: $_localBinPath',
                        style: TextStyle(color: AppColors.primaryText, fontSize: 12)),
                  ),
                if (_localTransferring) ...[
                  const SizedBox(height: 12),
                  Text(_localStatusMessage,
                      style: TextStyle(color: AppColors.primaryText, fontSize: 13)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _localTransferProgress,
                      minHeight: 12,
                      color: AppColors.warning,
                      backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(_localTransferProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
                if (_localTransferComplete) ...[
                  const SizedBox(height: 12),
                  Icon(Icons.check_circle, color: AppColors.success, size: 40),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.localFirmwareUploaded,
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _rebootDevice,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(AppLocalizations.of(context)!.rebootDevice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.primaryBackground,
                    ),
                  ),
                ],
                if (_localTransferError) ...[
                  const SizedBox(height: 8),
                  Text(_localErrorMessage,
                      style: TextStyle(color: AppColors.error, fontSize: 12)),
                ],
                if (_localStatusMessage.isNotEmpty && !_localTransferring && !_localTransferComplete)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_localStatusMessage,
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryAccent, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
          Divider(color: AppColors.borderDefault, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ── Helper: Update Available row with sparkle ─────────────────

  Widget _buildUpdateAvailableRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppLocalizations.of(context)!.updateAvailable,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent
                      .withValues(alpha: 0.1 + 0.12 * _pulseAnimation.value),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent
                          .withValues(alpha: 0.35 * _pulseAnimation.value),
                      blurRadius: 10 * _pulseAnimation.value,
                      spreadRadius: 1 * _pulseAnimation.value,
                    ),
                  ],
                ),
                child: Text(
                  AppLocalizations.of(context)!.yes,
                  style: const TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Helper: MD5 popup dialog ────────────────────────────────

  void _showMd5Dialog() {
    if (_firmwareMd5 == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDefault),
        ),
        title: Row(
          children: [
            const Icon(Icons.fingerprint, color: AppColors.primaryAccent, size: 20),
            const SizedBox(width: 8),
            const Text('MD5 Checksum',
                style: TextStyle(color: AppColors.primaryAccent, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: SelectableText(
                _firmwareMd5!,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Long press to select and copy',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _firmwareMd5!));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('MD5 copied to clipboard'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy', style: TextStyle(color: AppColors.primaryAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.secondaryText)),
          ),
        ],
      ),
    );
  }

  // ── Helper: Color for changelog change type ─────────────────

  Color _getChangeTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'FIX':
        return AppColors.error;
      case 'FEATURE':
        return AppColors.primaryAccent;
      case 'IMPROVEMENT':
        return const Color(0xFF42A5F5); // Blue
      case 'BREAKING':
        return AppColors.warning;
      case 'SECURITY':
        return const Color(0xFFAB47BC); // Purple
      default:
        return AppColors.secondaryText;
    }
  }
}

// ── Reboot dialog with animated timer and version check ───────────

class _RebootDialog extends StatefulWidget {
  const _RebootDialog();

  @override
  State<_RebootDialog> createState() => _RebootDialogState();
}

class _RebootDialogState extends State<_RebootDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        // Consider reconnected after at least 3 seconds and firmware version is available
        final isReconnected = bleProvider.isConnected &&
            bleProvider.firmwareVersion.isNotEmpty &&
            _elapsed > 3;

        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          title: Text(
            isReconnected ? 'Update Complete!' : 'Rebooting Device...',
            style: const TextStyle(color: AppColors.primaryAccent, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isReconnected) ...[
                RotationTransition(
                  turns: _spinController,
                  child: const Icon(Icons.refresh,
                      size: 48, color: AppColors.primaryAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reboot in progress...\n${_elapsed}s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.primaryText, fontSize: 14),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  color: AppColors.primaryAccent,
                  backgroundColor:
                      AppColors.primaryAccent.withValues(alpha: 0.2),
                ),
              ] else ...[
                const Icon(Icons.check_circle,
                    size: 56, color: AppColors.success),
                const SizedBox(height: 16),
                Text(
                  'Firmware updated to\nv${bleProvider.firmwareVersion}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (isReconnected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.primaryBackground,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ),
          ],
        );
      },
    );
  }
}
