import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/firmware_protocol.dart';
import '../widgets/transmit_file_dialog.dart';
import '../services/update_service.dart';
import '../services/flipper_subdb_service.dart';
import '../theme/app_colors.dart';
import 'debug_screen.dart';
import 'files_screen.dart';
import 'ota_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// True after we sync HW button config from device once.
  bool _hwConfigSynced = false;

  /// Navigates to DebugScreen on single tap.
  void _onDebugTap(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    if (settingsProvider.debugMode) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const DebugScreen()),
      );
    }
  }

  /// Disables debug mode and shows confirmation.
  void _onDisableDebug(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    settingsProvider.setDebugMode(false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.debugModeDisabled)),
    );
  }

  /// Map CC1101 TX power dBm to a user-friendly label.
  String _powerLabel(int dBm) {
    if (dBm <= -30) return '-30 dBm (Min)';
    if (dBm >= 10) return '+10 dBm (Max)';
    return '${dBm > 0 ? '+' : ''}$dBm dBm';
  }

  /// CC1101 discrete power levels in dBm.
  static const List<int> _powerLevels = [-30, -20, -15, -10, 0, 5, 7, 10];

  /// Snap a value to the nearest CC1101 power level.
  int _snapToPowerLevel(double value) {
    int closest = _powerLevels[0];
    double minDist = (value - closest).abs().toDouble();
    for (final lvl in _powerLevels) {
      final dist = (value - lvl).abs().toDouble();
      if (dist < minDist) {
        minDist = dist;
        closest = lvl;
      }
    }
    return closest;
  }

  void _showAboutDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'About',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: const _AboutPopup(),
          ),
        );
      },
    );
  }

  /// Check for app updates on GitHub and show dialog
  Future<void> _checkAppUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.checkingForAppUpdates),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final update = await UpdateService.checkAppUpdate(currentVersion);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appUpToDate(currentVersion)),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }

      // Show update available dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.system_update_alt, color: AppColors.primaryAccent),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.appUpdateAvailable,
                  style: const TextStyle(color: AppColors.primaryText, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.currentVersionLabel(currentVersion),
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              Text(AppLocalizations.of(context)!.latestVersionLabel(update.version),
                  style: const TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)!.changelogLabel, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(update.changelog,
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)!.later),
            ),
            if (update.apkUrl != null)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  _downloadAndInstallApk(context, update);
                },
                icon: const Icon(Icons.download, size: 16),
                label: Text(AppLocalizations.of(context)!.downloadAndInstall),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: AppColors.primaryBackground,
                ),
              ),
          ],
        ),
      );
    } on UpdateServiceException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.updateCheckFailed(e.message ?? '')),
              backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Download APK and trigger install
  Future<void> _downloadAndInstallApk(BuildContext context, AppUpdate update) async {
    if (update.apkUrl == null) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading APK...'), duration: Duration(seconds: 30)),
      );
      final apkPath = await UpdateService.downloadApk(update.apkUrl!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Open the APK for install
        final result = await Process.run('am', ['start', '-a', 'android.intent.action.VIEW',
            '-d', 'file://$apkPath', '-t', 'application/vnd.android.package-archive']);
        if (result.exitCode != 0) {
          // Fallback: try using content URI
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.apkSavedPleaseInstall(apkPath)),
                duration: const Duration(seconds: 5)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Compact header
          Container(
            height: 48,
            color: AppColors.secondaryBackground,
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.settings, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.settings,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                  ),
                ),
                // App Update check button
                IconButton(
                  icon: const Icon(Icons.system_update_alt,
                      size: 22, color: AppColors.warning),
                  tooltip: AppLocalizations.of(context)!.checkAppUpdate,
                  onPressed: () => _checkAppUpdate(context),
                ),
                // About button
                IconButton(
                  icon: const Icon(Icons.info_outline,
                      size: 22, color: AppColors.primaryAccent),
                  tooltip: AppLocalizations.of(context)!.about,
                  onPressed: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Consumer<BleProvider>(
              builder: (context, bleProvider, child) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== SDR MODE (prominent toggle) =====
                      _buildSdrModeSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== App Settings (Expandable, collapsed) =====
                      _buildAppSettingsSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== RF Settings (Expandable, collapsed) =====
                      _buildRFSettingsSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== HW Buttons (Expandable, collapsed) =====
                      _buildHwButtonsSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== nRF24 Settings (Expandable, collapsed) =====
                      _buildNrfSettingsSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== Firmware Update (Expandable, collapsed) =====
                      _buildFirmwareUpdateSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== Others (Expandable, collapsed) =====
                      _buildOthersSection(context, bleProvider),

                      const SizedBox(height: 12),

                      // ===== Device Management (name change, factory reset) =====
                      _buildDeviceManagementSection(context, bleProvider),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build SDR MODE toggle section — prominent card at the top of Settings.
  /// When SDR mode is active, other CC1101 operations (record, TX, detect,
  /// jam) are blocked on the firmware side. The app disables SubGhz controls.
  Widget _buildSdrModeSection(BuildContext context, BleProvider bleProvider) {
    final isActive = bleProvider.sdrModeActive;
    final isConnected = bleProvider.isConnected;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.warning : AppColors.borderDefault,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radar,
                  color: isActive ? AppColors.warning : AppColors.primaryAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.sdrMode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.warning : AppColors.primaryText,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isActive
                            ? AppLocalizations.of(context)!.sdrModeActiveSubtitle
                            : AppLocalizations.of(context)!.sdrModeInactiveSubtitle,
                        style: TextStyle(
                          color: isActive ? AppColors.warning : AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: isConnected
                      ? (value) async {
                          final cmd = value
                              ? FirmwareBinaryProtocol.createSdrEnableCommand()
                              : FirmwareBinaryProtocol.createSdrDisableCommand();
                          await bleProvider.sendBinaryCommand(cmd);
                          // Status update will arrive via MSG_SDR_STATUS (0xC4)
                        }
                      : null,
                  activeColor: AppColors.warning,
                  activeTrackColor: AppColors.warning.withValues(alpha: 0.4),
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Freq: ${bleProvider.sdrFrequencyMHz.toStringAsFixed(2)} MHz  •  '
                        'Mod: ${_modLabel(bleProvider.sdrModulation)}\n'
                        '${AppLocalizations.of(context)!.sdrConnectViaUsb}',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Map CC1101 modulation ID to display label.
  String _modLabel(int mod) {
    switch (mod) {
      case 0: return '2-FSK';
      case 1: return 'GFSK';
      case 2: return 'ASK/OOK';
      case 3: return '4-FSK';
      case 4: return 'MSK';
      default: return 'Unknown';
    }
  }

  /// Build App Settings expandable section (language, cache, permissions, debug).
  Widget _buildAppSettingsSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.phone_android, color: AppColors.primaryAccent),
          title: Text(
            AppLocalizations.of(context)!.appSettings,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.appSettingsSubtitle,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Selection
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, child) {
                      final l10n = AppLocalizations.of(context)!;
                      return Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: ListTile(
                          leading: const Icon(Icons.language),
                          title: Text(l10n.language),
                          subtitle: Text(
                              _getLanguageDisplayName(
                                  localeProvider.locale.languageCode,
                                  l10n)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showLanguageDialog(
                              context, localeProvider, l10n),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => bleProvider.clearFileCache(),
                        icon: const Icon(Icons.folder_delete),
                        label: Text(AppLocalizations.of(context)!.clearFileCache),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.recording,
                          foregroundColor: AppColors.primaryBackground,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showClearDeviceCacheDialog(context, bleProvider),
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: Text(AppLocalizations.of(context)!.clearDeviceCache),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: AppColors.primaryBackground,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: bleProvider.isConnected
                            ? () => bleProvider.rebootDevice()
                            : null,
                        icon: const Icon(Icons.restart_alt),
                        label: Text(AppLocalizations.of(context)!.rebootDevice),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: AppColors.primaryBackground,
                        ),
                      ),
                      // Debug-only buttons
                      Consumer<SettingsProvider>(
                        builder: (context, settingsProvider, child) {
                          if (!settingsProvider.debugMode) {
                            return const SizedBox.shrink();
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => bleProvider.requestPermissions(),
                                icon: const Icon(Icons.security),
                                label: Text(AppLocalizations.of(context)!.requestPermissions),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _resetTransmitConfirmation(context),
                                icon: const Icon(Icons.refresh),
                                label: Text(AppLocalizations.of(context)!.resetTransmitConfirmation),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.info,
                                  foregroundColor: AppColors.primaryBackground,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _onDebugTap(context),
                                icon: const Icon(Icons.bug_report),
                                label: Text(AppLocalizations.of(context)!.debug),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                  foregroundColor: AppColors.primaryBackground,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _onDisableDebug(context),
                                icon: const Icon(Icons.bug_report_outlined),
                                label: Text(AppLocalizations.of(context)!.disableDbg),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: AppColors.primaryBackground,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the RF Settings expandable section with Bruteforce + Radio sub-sections.
  Widget _buildRFSettingsSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.radio, color: AppColors.primaryAccent),
          title: Text(
            AppLocalizations.of(context)!.rfSettings,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            bleProvider.settingsSynced ? AppLocalizations.of(context)!.syncedWithDevice : AppLocalizations.of(context)!.localOnly,
            style: TextStyle(
              color: bleProvider.settingsSynced
                  ? AppColors.success
                  : AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.divider, height: 1),

            // --- Bruteforce Settings ---
            _buildSubSectionHeader(
                Icons.flash_on, AppLocalizations.of(context)!.bruteforceSettings, AppColors.warning),
            _buildBruteforceSettings(context, bleProvider),

            const SizedBox(height: 8),
            const Divider(
                color: AppColors.divider, indent: 16, endIndent: 16),

            // --- Radio Settings ---
            _buildSubSectionHeader(
                Icons.cell_tower, AppLocalizations.of(context)!.radioSettings, AppColors.primaryAccent),
            _buildRadioSettings(context, bleProvider),

            const SizedBox(height: 8),
            const Divider(
                color: AppColors.divider, indent: 16, endIndent: 16),

            // --- Scanner Settings ---
            _buildSubSectionHeader(
                Icons.search, AppLocalizations.of(context)!.scannerSettings, AppColors.searching),
            _buildScannerSettings(context, bleProvider),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSubSectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBruteforceSettings(
      BuildContext context, BleProvider bleProvider) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inter-frame delay
              Row(
                children: [
                  const Icon(Icons.timer,
                      size: 18, color: AppColors.secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.interFrameDelay(settingsProvider.bruterDelayMs),
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.delayBetweenTransmissions,
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Slider(
                value: settingsProvider.bruterDelayMs.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '${settingsProvider.bruterDelayMs} ms',
                activeColor: AppColors.warning,
                onChanged: (value) {
                  settingsProvider.setBruterDelayMs(value.round());
                  bleProvider.setBruterDelay(value.round());
                },
              ),
              Wrap(
                spacing: 8,
                children: [5, 10, 20, 50].map((ms) {
                  final isSelected = settingsProvider.bruterDelayMs == ms;
                  return ChoiceChip(
                    label: Text('${ms}ms'),
                    selected: isSelected,
                    onSelected: (_) {
                      settingsProvider.setBruterDelayMs(ms);
                      bleProvider.setBruterDelay(ms);
                    },
                    selectedColor:
                        AppColors.warning.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.warning
                          : AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Repeats per code
              Row(
                children: [
                  const Icon(Icons.repeat,
                      size: 18, color: AppColors.secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.repeatsCount(bleProvider.bruterRepeats),
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.transmissionsPerCode,
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Slider(
                value: bleProvider.bruterRepeats.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '${bleProvider.bruterRepeats}x',
                activeColor: AppColors.warning,
                onChanged: (value) {
                  bleProvider.sendSettingsToDevice(
                      bruterRepeats: value.round());
                },
              ),

              const SizedBox(height: 8),

              // Bruter TX power
              Row(
                children: [
                  const Icon(Icons.power,
                      size: 18, color: AppColors.secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.txPowerLevel(bleProvider.bruterPower),
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.bruterTxPowerDesc,
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Slider(
                value: bleProvider.bruterPower.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                label: 'Level ${bleProvider.bruterPower}',
                activeColor: AppColors.warning,
                onChanged: (value) {
                  bleProvider.sendSettingsToDevice(
                      bruterPower: value.round());
                },
              ),

              const SizedBox(height: 12),

              // Bruter module selection
              Row(
                children: [
                  const Icon(Icons.memory,
                      size: 18, color: AppColors.secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TX Module: ${settingsProvider.bruterModule == 0 ? "Module 1" : "Module 2"}',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'CC1101 module used for brute force',
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Module 1', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.looks_one, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Module 2', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.looks_two, size: 16),
                  ),
                ],
                selected: {settingsProvider.bruterModule},
                onSelectionChanged: (selected) {
                  final mod = selected.first;
                  settingsProvider.setBruterModule(mod);
                  bleProvider.setBruterModule(mod);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioSettings(BuildContext context, BleProvider bleProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module 1 TX Power
          _buildModulePowerSlider(
            label: 'CC1101 Module 1',
            currentValue: bleProvider.radioPowerMod1,
            moduleColor: AppColors.primaryAccent,
            onChanged: (value) {
              final snapped = _snapToPowerLevel(value);
              bleProvider.sendSettingsToDevice(radioPowerMod1: snapped);
            },
          ),

          const SizedBox(height: 8),

          // Module 2 TX Power
          _buildModulePowerSlider(
            label: 'CC1101 Module 2',
            currentValue: bleProvider.radioPowerMod2,
            moduleColor: AppColors.success,
            onChanged: (value) {
              final snapped = _snapToPowerLevel(value);
              bleProvider.sendSettingsToDevice(radioPowerMod2: snapped);
            },
          ),

          const SizedBox(height: 8),

          // Info card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.txPowerInfoDesc,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulePowerSlider({
    required String label,
    required int currentValue,
    required Color moduleColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: moduleColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: ${_powerLabel(currentValue)}',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: moduleColor,
            thumbColor: moduleColor,
            inactiveTrackColor: moduleColor.withValues(alpha: 0.2),
            overlayColor: moduleColor.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: currentValue.toDouble(),
            min: -30,
            max: 10,
            divisions: 40,
            label: _powerLabel(currentValue),
            onChanged: onChanged,
          ),
        ),
        // Power level chips
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _powerLevels.map((lvl) {
            final isSelected = currentValue == lvl;
            return ChoiceChip(
              label: Text('${lvl > 0 ? '+' : ''}$lvl'),
              selected: isSelected,
              onSelected: (_) => onChanged(lvl.toDouble()),
              selectedColor: moduleColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? moduleColor : AppColors.secondaryText,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScannerSettings(BuildContext context, BleProvider bleProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.signal_cellular_alt,
                  size: 18, color: AppColors.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.rssiThreshold(bleProvider.scannerRssi),
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.minSignalStrengthDesc,
                      style: const TextStyle(
                          color: AppColors.secondaryText, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: bleProvider.scannerRssi.toDouble(),
            min: -120,
            max: -20,
            divisions: 100,
            label: '${bleProvider.scannerRssi} dBm',
            activeColor: AppColors.searching,
            onChanged: (value) {
              bleProvider.sendSettingsToDevice(scannerRssi: value.round());
            },
          ),
          Wrap(
            spacing: 8,
            children: [-90, -80, -70, -60, -50].map((rssi) {
              final isSelected = bleProvider.scannerRssi == rssi;
              return ChoiceChip(
                label: Text('$rssi'),
                selected: isSelected,
                onSelected: (_) {
                  bleProvider.sendSettingsToDevice(scannerRssi: rssi);
                },
                selectedColor:
                    AppColors.searching.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.searching
                      : AppColors.secondaryText,
                  fontSize: 11,
                ),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Build nRF24 Settings expandable section.
  Widget _buildNrfSettingsSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.wifi_tethering, color: Color(0xFF00BCD4)),
          title: Text(
            AppLocalizations.of(context)!.nrf24Settings,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.nrf24SettingsSubtitle,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.divider, height: 1),
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: AppColors.secondaryText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.nrf24ConfigDesc,
                                style: const TextStyle(
                                    color: AppColors.secondaryText, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PA Level
                      Row(
                        children: [
                          const Icon(Icons.power_settings_new,
                              size: 18, color: AppColors.secondaryText),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.paLevel(_nrfPaLabel(settingsProvider.nrfPaLevel)),
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        AppLocalizations.of(context)!.transmissionPowerDesc,
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [0, 1, 2, 3].map((lvl) {
                          final isSelected = settingsProvider.nrfPaLevel == lvl;
                          return ChoiceChip(
                            label: Text(_nrfPaLabel(lvl)),
                            selected: isSelected,
                            onSelected: (_) => settingsProvider.setNrfPaLevel(lvl),
                            selectedColor: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF00BCD4) : AppColors.secondaryText,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Data Rate
                      Row(
                        children: [
                          const Icon(Icons.speed,
                              size: 18, color: AppColors.secondaryText),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.nrfDataRate(_nrfDataRateLabel(settingsProvider.nrfDataRate)),
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        AppLocalizations.of(context)!.radioDataRateDesc,
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [0, 1, 2].map((dr) {
                          final isSelected = settingsProvider.nrfDataRate == dr;
                          return ChoiceChip(
                            label: Text(_nrfDataRateLabel(dr)),
                            selected: isSelected,
                            onSelected: (_) => settingsProvider.setNrfDataRate(dr),
                            selectedColor: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF00BCD4) : AppColors.secondaryText,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Channel
                      Row(
                        children: [
                          const Icon(Icons.tune,
                              size: 18, color: AppColors.secondaryText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.defaultChannel(settingsProvider.nrfChannel),
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${2400 + settingsProvider.nrfChannel} MHz (0-125)',
                                  style: const TextStyle(
                                      color: AppColors.secondaryText, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settingsProvider.nrfChannel.toDouble(),
                        min: 0,
                        max: 125,
                        divisions: 125,
                        label: 'Ch ${settingsProvider.nrfChannel} (${2400 + settingsProvider.nrfChannel} MHz)',
                        activeColor: const Color(0xFF00BCD4),
                        onChanged: (value) {
                          settingsProvider.setNrfChannel(value.round());
                        },
                      ),

                      const SizedBox(height: 12),

                      // Auto-Retransmit
                      Row(
                        children: [
                          const Icon(Icons.repeat,
                              size: 18, color: AppColors.secondaryText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.autoRetransmit(settingsProvider.nrfAutoRetransmit),
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.retransmitCountDesc,
                                  style: const TextStyle(
                                      color: AppColors.secondaryText, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settingsProvider.nrfAutoRetransmit.toDouble(),
                        min: 0,
                        max: 15,
                        divisions: 15,
                        label: '${settingsProvider.nrfAutoRetransmit}x',
                        activeColor: const Color(0xFF00BCD4),
                        onChanged: (value) {
                          settingsProvider.setNrfAutoRetransmit(value.round());
                        },
                      ),

                      const SizedBox(height: 12),

                      // Send to device button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: bleProvider.isConnected
                              ? () => _sendNrfSettings(context, bleProvider, settingsProvider)
                              : null,
                          icon: const Icon(Icons.send),
                          label: Text(AppLocalizations.of(context)!.sendToDevice),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BCD4),
                            foregroundColor: AppColors.primaryBackground,
                            disabledBackgroundColor:
                                const Color(0xFF00BCD4).withValues(alpha: 0.3),
                            disabledForegroundColor: AppColors.disabledText,
                          ),
                        ),
                      ),
                      if (!bleProvider.isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            AppLocalizations.of(context)!.connectToDeviceToApply,
                            style: const TextStyle(
                                color: AppColors.secondaryText, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _nrfPaLabel(int level) {
    switch (level) {
      case 0: return 'MIN (-18dBm)';
      case 1: return 'LOW (-12dBm)';
      case 2: return 'HIGH (-6dBm)';
      case 3: return 'MAX (0dBm)';
      default: return 'Unknown';
    }
  }

  String _nrfDataRateLabel(int rate) {
    switch (rate) {
      case 0: return '1 Mbps';
      case 1: return '2 Mbps';
      case 2: return '250 Kbps';
      default: return 'Unknown';
    }
  }

  void _sendNrfSettings(BuildContext context, BleProvider bleProvider,
      SettingsProvider settingsProvider) async {
    try {
      // Send NRF settings as a settings sync command
      // Using MSG_SETTINGS_UPDATE (0xC1) with extended NRF payload
      final cmd = FirmwareBinaryProtocol.createNrfSettingsCommand(
        settingsProvider.nrfPaLevel,
        settingsProvider.nrfDataRate,
        settingsProvider.nrfChannel,
        settingsProvider.nrfAutoRetransmit,
      );
      await bleProvider.sendBinaryCommand(cmd);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.nrf24SettingsSent),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSendNrf24Settings(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Build Firmware Update expandable section.
  /// Currently only shows a "Check FW Version" button that queries the device.
  Widget _buildFirmwareUpdateSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.system_update, color: AppColors.warning),
          title: Text(
            AppLocalizations.of(context)!.firmwareUpdate,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            bleProvider.firmwareVersion.isNotEmpty
                ? AppLocalizations.of(context)!.deviceFwVersion(bleProvider.firmwareVersion)
                : AppLocalizations.of(context)!.notConnected,
            style: TextStyle(
              color: bleProvider.firmwareVersion.isNotEmpty
                  ? AppColors.success
                  : AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: AppColors.secondaryText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.updateFirmwareDesc,
                            style: const TextStyle(
                                color: AppColors.secondaryText, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // FW version display
                  if (bleProvider.firmwareVersion.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.memory,
                              size: 20, color: AppColors.success),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.currentFirmware,
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'v${bleProvider.firmwareVersion}',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Check button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: bleProvider.isConnected
                          ? () => _checkFirmwareVersion(context, bleProvider)
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.checkFwVersion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.primaryBackground,
                        disabledBackgroundColor:
                            AppColors.warning.withValues(alpha: 0.3),
                        disabledForegroundColor: AppColors.disabledText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // OTA Update button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OtaScreen()),
                        );
                      },
                      icon: const Icon(Icons.system_update),
                      label: Text(AppLocalizations.of(context)!.otaUpdate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.primaryBackground,
                      ),
                    ),
                  ),
                  if (!bleProvider.isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        AppLocalizations.of(context)!.connectToADeviceFirst,
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Others section (FlipperZero SubGHz DB cloning, etc.)
  Widget _buildOthersSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.miscellaneous_services, color: AppColors.primaryAccent),
          title: const Text(
            'Others',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            'Additional tools and utilities',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // FlipperZero SubGHz DB Cloning
                  _buildSubGhzDbCloneButton(context, bleProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubGhzDbCloneButton(BuildContext context, BleProvider bleProvider) {
    return Card(
      color: AppColors.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download, size: 22, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FlipperZero SubGHz Database',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Download .sub files from Zero-Sploit repo and save to device SDCard in "SUB Files" folder',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: bleProvider.isConnected
                    ? () => _startSubGhzDbCloning(context, bleProvider)
                    : null,
                icon: const Icon(Icons.download, size: 18),
                label: Text('Clone SubGHz DB to SDCard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
            if (!bleProvider.isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Connect to device first',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSubGhzDbCloning(BuildContext context, BleProvider bleProvider) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_download, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Clone SubGHz Database'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will:'),
            const SizedBox(height: 8),
            _cloneInfoRow('1.', 'Download FlipperZero SubGHz DB from GitHub'),
            _cloneInfoRow('2.', 'Extract .sub files keeping folder structure'),
            _cloneInfoRow('3.', 'Create "SUB Files" folder on device SDCard'),
            _cloneInfoRow('4.', 'Upload all .sub files to the device'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This may take several minutes. Files are uploaded one at a time via BLE to avoid conflicts.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.download, size: 18),
            label: Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show progress dialog
    _showSubGhzCloneProgress(context, bleProvider);
  }

  Widget _cloneInfoRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(number,
                style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(color: AppColors.primaryText, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showSubGhzCloneProgress(BuildContext context, BleProvider bleProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SubGhzCloneDialog(bleProvider: bleProvider),
    );
  }

  /// Build Device Management section (Device Name, Factory Reset).
  Widget _buildDeviceManagementSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.build_circle, color: AppColors.info),
          title: const Text(
            'Device Management',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            bleProvider.isConnected
                ? 'Name: ${bleProvider.deviceName}'
                : 'Not connected',
            style: TextStyle(
              color: bleProvider.isConnected
                  ? AppColors.success
                  : AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Device Name ──
                  const Text(
                    'BLE Device Name',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Change the Bluetooth name of your device. Takes effect after reboot.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Text(
                            bleProvider.deviceName,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: bleProvider.isConnected
                            ? () => _showChangeNameDialog(context, bleProvider)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: AppColors.primaryBackground,
                          disabledBackgroundColor: AppColors.primaryAccent.withValues(alpha: 0.3),
                        ),
                        child: const Text('Change'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Factory Reset ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text(
                              'Factory Reset',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Erase all settings and data from the device flash memory and reboot with factory defaults. This cannot be undone.',
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: bleProvider.isConnected
                                ? () => _showFactoryResetDialog(context, bleProvider)
                                : null,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Factory Reset'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!bleProvider.isConnected)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Connect to a device first',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to change BLE device name.
  void _showChangeNameDialog(BuildContext context, BleProvider bleProvider) {
    final controller = TextEditingController(text: bleProvider.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        title: const Text('Change BLE Name', style: TextStyle(color: AppColors.primaryText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a new name (1-20 characters). Device will need a reboot for the change to take effect.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 20,
              style: const TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                hintText: 'EvilCrow_RF2',
                hintStyle: const TextStyle(color: AppColors.disabledText),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || name.length > 20) return;
              Navigator.of(ctx).pop();
              final success = await bleProvider.setDeviceName(name);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Device name set to "$name". Reboot to apply.'
                        : 'Failed to set device name.'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: AppColors.primaryBackground,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show factory reset confirmation dialog with Yes/No.
  void _showFactoryResetDialog(BuildContext context, BleProvider bleProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text('Factory Reset', style: TextStyle(color: AppColors.error)),
          ],
        ),
        content: const Text(
          'Are you sure you want to erase ALL settings and data?\n\n'
          'This will:\n'
          '  - Delete all configuration\n'
          '  - Reset BLE name to default\n'
          '  - Remove all flag files\n'
          '  - Reboot the device\n\n'
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.primaryText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No', style: TextStyle(color: AppColors.secondaryText, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await bleProvider.factoryReset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Factory reset initiated. Device will reboot.'
                        : 'Failed to send factory reset command.'),
                    backgroundColor: success ? AppColors.warning : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Reset', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  /// Build HW Buttons configuration section.
  Widget _buildHwButtonsSection(BuildContext context, BleProvider bleProvider) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.touch_app, color: AppColors.info),
          title: Text(
            AppLocalizations.of(context)!.hwButtons,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.configureHwButtonActions,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.divider, height: 1),
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, child) {
                // Reset sync flag on disconnect so we re-sync next time
                if (_hwConfigSynced && !bleProvider.isConnected) {
                  _hwConfigSynced = false;
                }
                // Sync HW button config from device once, when 0xC8 arrives
                if (!_hwConfigSynced && bleProvider.deviceBtn1Action >= 0) {
                  _hwConfigSynced = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    settingsProvider.syncButtonsFromDevice(
                      btn1Action: bleProvider.deviceBtn1Action,
                      btn2Action: bleProvider.deviceBtn2Action,
                      btn1PathType: bleProvider.deviceBtn1PathType,
                      btn2PathType: bleProvider.deviceBtn2PathType,
                    );
                  });
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: AppColors.secondaryText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.hwButtonsDesc,
                                style: const TextStyle(
                                    color: AppColors.secondaryText, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Button 1
                      _buildButtonConfig(
                        label: AppLocalizations.of(context)!.button1Gpio34,
                        action: settingsProvider.button1Action,
                        color: AppColors.primaryAccent,
                        replayPath: settingsProvider.button1ReplayPath,
                        onPickReplayFile: () => _pickReplaySubFile(context, settingsProvider, 1),
                        onChanged: (action) {
                          settingsProvider.setButton1Action(action);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Button 2
                      _buildButtonConfig(
                        label: AppLocalizations.of(context)!.button2Gpio35,
                        action: settingsProvider.button2Action,
                        color: AppColors.warning,
                        replayPath: settingsProvider.button2ReplayPath,
                        onPickReplayFile: () => _pickReplaySubFile(context, settingsProvider, 2),
                        onChanged: (action) {
                          settingsProvider.setButton2Action(action);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Send to device button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: bleProvider.isConnected
                              ? () => _sendButtonConfig(
                                  context, bleProvider, settingsProvider)
                              : null,
                          icon: const Icon(Icons.send),
                          label: Text(AppLocalizations.of(context)!.sendToDevice),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            foregroundColor: AppColors.primaryBackground,
                            disabledBackgroundColor:
                                AppColors.info.withValues(alpha: 0.3),
                            disabledForegroundColor: AppColors.disabledText,
                          ),
                        ),
                      ),
                      if (!bleProvider.isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            AppLocalizations.of(context)!.connectToDeviceToApply,
                            style: const TextStyle(
                                color: AppColors.secondaryText, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonConfig({
    required String label,
    required HwButtonAction action,
    required Color color,
    required String? replayPath,
    required VoidCallback onPickReplayFile,
    required ValueChanged<HwButtonAction> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: HwButtonAction.values.map((a) {
            final isSelected = action == a;
            return GestureDetector(
              onTap: () => onChanged(a),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderDefault,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icon,
                        size: 14,
                        color: isSelected ? color : AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      a.label,
                      style: TextStyle(
                        color: isSelected ? color : AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (action == HwButtonAction.replayLast) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  replayPath == null || replayPath.isEmpty
                      ? 'No .sub file selected'
                      : replayPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onPickReplayFile,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Select .sub'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickReplaySubFile(
    BuildContext context,
    SettingsProvider settingsProvider,
    int buttonId,
  ) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const FilesScreen(
          pickMode: true,
          allowedExtensions: {'sub'},
        ),
      ),
    );

    if (result == null) return;

    final path = result['path']?.toString();
    final pathType = (result['pathType'] as int?) ?? 1;
    if (path == null || path.isEmpty) return;

    if (buttonId == 1) {
      await settingsProvider.setButton1ReplayFile(path, pathType);
    } else {
      await settingsProvider.setButton2ReplayFile(path, pathType);
    }
  }

  void _sendButtonConfig(BuildContext context, BleProvider bleProvider,
      SettingsProvider settingsProvider) async {
    try {
      final cmd1 = FirmwareBinaryProtocol.createHwButtonConfigCommand(
      1,
      settingsProvider.button1Action.index,
      replayPathType: settingsProvider.button1Action == HwButtonAction.replayLast
        ? settingsProvider.button1ReplayPathType
        : null,
      replayPath: settingsProvider.button1Action == HwButtonAction.replayLast
        ? settingsProvider.button1ReplayPath
        : null,
      );
      await bleProvider.sendBinaryCommand(cmd1);

      final cmd2 = FirmwareBinaryProtocol.createHwButtonConfigCommand(
      2,
      settingsProvider.button2Action.index,
      replayPathType: settingsProvider.button2Action == HwButtonAction.replayLast
        ? settingsProvider.button2ReplayPathType
        : null,
      replayPath: settingsProvider.button2Action == HwButtonAction.replayLast
        ? settingsProvider.button2ReplayPath
        : null,
      );
      await bleProvider.sendBinaryCommand(cmd2);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.buttonConfigSent),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSendConfig(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Request firmware version from device and show popup.
  void _checkFirmwareVersion(BuildContext context, BleProvider bleProvider) {
    // The FW sends version on getState; request state refresh
    bleProvider.sendGetStateCommand();

    // Show current info (may already be populated from initial connect)
    final version = bleProvider.firmwareVersion;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.memory, color: AppColors.primaryAccent),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.firmwareInfo,
                  style: const TextStyle(color: AppColors.primaryText)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (version.isNotEmpty) ...[
                Text(
                  AppLocalizations.of(context)!.versionLabel(version),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.fwVersionDetails(bleProvider.fwMajor, bleProvider.fwMinor, bleProvider.fwPatch),
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 12),
                ),
              ] else
                Text(
                  AppLocalizations.of(context)!.waitingForDeviceResponse,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppLocalizations.of(context)!.tapOtaUpdateDesc,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OtaScreen()),
                );
              },
              child: Text(AppLocalizations.of(context)!.otaUpdate),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageDisplayName(
      String languageCode, AppLocalizations l10n) {
    switch (languageCode) {
      case 'en':
        return l10n.english;
      case 'ru':
        return l10n.russian;
      default:
        return l10n.systemDefault;
    }
  }

  void _showLanguageDialog(BuildContext context,
      LocaleProvider localeProvider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final currentLocale = localeProvider.locale;
        return AlertDialog(
          title: Text(
            l10n.selectLanguage,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(
                  l10n.english,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                value: 'en',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLocale(Locale(value));
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  l10n.russian,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                value: 'ru',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLocale(Locale(value));
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showClearDeviceCacheDialog(
      BuildContext context, BleProvider bleProvider) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.clearDeviceCache,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          content: Text(
            l10n.clearDeviceCacheDescription,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await bleProvider.clearDeviceCache();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.clearDeviceCache)),
                );
              },
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

  void _resetTransmitConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await TransmitFileDialog.resetDontShowAgain();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.transmitConfirmationReset),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

// ============================================================================
// About Popup — Animated developer showcase
// ============================================================================

/// Developer card data model.
/// To add a new developer, create a DevProfile and add it to _devProfiles
/// in _AboutPopupState. See docs/session/ for detailed instructions.
class DevProfile {
  final String name;
  final String role;
  final String githubUrl;
  final String? donateUrl;
  final String? avatarAsset; // Optional: path under assets/images/
  final IconData fallbackIcon;

  const DevProfile({
    required this.name,
    required this.role,
    required this.githubUrl,
    this.donateUrl,
    this.avatarAsset,
    this.fallbackIcon = Icons.person,
  });
}

/// Contributor credit entry for the Special Thanks card.
class _ContributorCredit {
  final String name;
  final String description;
  final String githubUrl;
  final Color nameColor;

  const _ContributorCredit({
    required this.name,
    required this.description,
    required this.githubUrl,
    required this.nameColor,
  });
}

class _AboutPopup extends StatefulWidget {
  const _AboutPopup();

  @override
  State<_AboutPopup> createState() => _AboutPopupState();
}

class _AboutPopupState extends State<_AboutPopup>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  static const List<DevProfile> _devProfiles = [
    DevProfile(
      name: 'Senape3000',
      role: 'Creator & Developer',
      githubUrl: 'https://github.com/Senape3000',
      donateUrl: 'https://ko-fi.com/senape3000',
      avatarAsset: 'assets/images/Senape3000_LOGO_resize.png',
      fallbackIcon: Icons.code,
    ),
  ];

  static const List<_ContributorCredit> _contributors = [
    _ContributorCredit(
      name: 'joelsernamoreno',
      description: 'Hardware design, original firmware, project idea & community',
      githubUrl: 'https://github.com/joelsernamoreno/EvilCrowRF-V2',
      nameColor: Color(0xFFFF6B6B),
    ),
    _ContributorCredit(
      name: 'tutejshy-bit',
      description: 'Original project, first app & firmware version',
      githubUrl: 'https://github.com/tutejshy-bit/tut-rf/',
      nameColor: Color(0xFF64B5F6),
    ),
    _ContributorCredit(
      name: 'realdaveblanch',
      description: 'Original Bruter & DeBruijn sequence features',
      githubUrl: 'https://github.com/realdaveblanch/EvilCrowRf-Bruter',
      nameColor: Color(0xFFFFD54F),
    ),
  ];

  /// Total pages = dev profiles + 1 (contributors card)
  int get _totalPages => _devProfiles.length + 1;

  late AnimationController _shimmerController;
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = 'v${info.version}');
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 520,
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.primaryAccent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryAccent.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  children: [
                    // Animated title with shimmer
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                AppColors.primaryAccent,
                                Colors.white,
                                AppColors.primaryAccent,
                              ],
                              stops: [
                                (_shimmerController.value - 0.3)
                                    .clamp(0.0, 1.0),
                                _shimmerController.value,
                                (_shimmerController.value + 0.3)
                                    .clamp(0.0, 1.0),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'EvilCrow RF V2',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.appTagline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primaryAccent
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _appVersion,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Dev cards carousel (dev profiles + contributors card)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _totalPages,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    if (index < _devProfiles.length) {
                      return _buildDevCard(_devProfiles[index], index);
                    } else {
                      return _buildContributorsCard();
                    }
                  },
                ),
              ),

              // Page indicator dots
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryAccent
                            : AppColors.borderDefault,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the Special Thanks / Contributors card with scrollable list.
  Widget _buildContributorsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceElevated,
              const Color(0xFFFF6B6B).withValues(alpha: 0.03),
              const Color(0xFF64B5F6).withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Section title with shimmer
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: const [
                        Color(0xFFFF6B6B),
                        Color(0xFF64B5F6),
                        Color(0xFFFFD54F),
                        Color(0xFFFF6B6B),
                      ],
                      stops: [
                        (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                        (_shimmerController.value - 0.1).clamp(0.0, 1.0),
                        (_shimmerController.value + 0.1).clamp(0.0, 1.0),
                        (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds);
                  },
                  child: Text(
                    AppLocalizations.of(context)!.specialThanks,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.standingOnShoulders,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.divider, indent: 20, endIndent: 20, height: 1),
            // Scrollable contributor list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _contributors.length,
                separatorBuilder: (_, __) => const Divider(
                  color: AppColors.divider, height: 12, indent: 8, endIndent: 8,
                ),
                itemBuilder: (context, index) {
                  final c = _contributors[index];
                  return _buildContributorTile(c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single contributor tile with glowing name.
  Widget _buildContributorTile(_ContributorCredit c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Glowing initial circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.nameColor.withValues(alpha: 0.3),
                  c.nameColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: c.nameColor.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: c.nameColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                c.name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.nameColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing name
                Text(
                  c.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: c.nameColor,
                    shadows: [
                      Shadow(color: c.nameColor.withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.description,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // GitHub button
          IconButton(
            icon: Icon(Icons.code, size: 18, color: c.nameColor.withValues(alpha: 0.8)),
            tooltip: 'GitHub',
            onPressed: () => _launchUrl(c.githubUrl),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildDevCard(DevProfile dev, int index) {
    final cardColors = [
      AppColors.primaryAccent,
      AppColors.success,
      AppColors.warning,
    ];
    final accent = cardColors[index % cardColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceElevated,
              accent.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.3),
                    accent.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                    color: accent.withValues(alpha: 0.5), width: 2),
              ),
              child: dev.avatarAsset != null
                  ? ClipOval(
                      child: Image.asset(
                        dev.avatarAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildInitialAvatar(dev, accent),
                      ),
                    )
                  : _buildInitialAvatar(dev, accent),
            ),

            const SizedBox(height: 16),

            // Name
            Text(
              dev.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 4),

            // Role badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dev.role,
                style: TextStyle(
                  fontSize: 12,
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // GitHub link button
            OutlinedButton.icon(
              onPressed: () => _launchUrl(dev.githubUrl),
              icon: const Icon(Icons.code, size: 16),
              label: Text(AppLocalizations.of(context)!.githubProfile),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),

            if (dev.donateUrl != null) ...[
              const SizedBox(height: 8),
              // Donate link button
              OutlinedButton.icon(
                onPressed: () => _launchUrl(dev.donateUrl!),
                icon: const Icon(Icons.favorite, size: 16, color: Color(0xFFFF6B6B)),
                label: Text(AppLocalizations.of(context)!.donate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: BorderSide(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(DevProfile dev, Color accent) {
    return Center(
      child: Text(
        dev.name.isNotEmpty ? dev.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: accent,
        ),
      ),
    );
  }
}

/// Dialog that handles the full SubGHz DB clone workflow with progress.
class _SubGhzCloneDialog extends StatefulWidget {
  final BleProvider bleProvider;
  const _SubGhzCloneDialog({required this.bleProvider});

  @override
  State<_SubGhzCloneDialog> createState() => _SubGhzCloneDialogState();
}

class _SubGhzCloneDialogState extends State<_SubGhzCloneDialog> {
  String _phase = 'init';
  String _statusText = 'Preparing...';
  double _progress = 0.0;
  int _totalFiles = 0;
  int _uploadedFiles = 0;
  int _failedFiles = 0;
  bool _isDone = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startCloning();
  }

  Future<void> _startCloning() async {
    try {
      // Phase 1 & 2: Download and extract
      setState(() {
        _phase = 'download';
        _statusText = 'Downloading SubGHz database from GitHub...';
        _progress = 0.0;
      });

      final subFiles = await FlipperSubDbService.downloadAndExtract(
        onProgress: (phase, detail, fraction) {
          if (mounted) {
            setState(() {
              _phase = phase;
              _statusText = detail;
              _progress = fraction;
            });
          }
        },
      );

      if (subFiles.isEmpty) {
        setState(() {
          _isDone = true;
          _hasError = true;
          _errorMessage = 'No .sub files found in the repository';
        });
        return;
      }

      _totalFiles = subFiles.length;

      // Phase 3: Create base directory on SDCard
      setState(() {
        _phase = 'upload';
        _statusText = 'Creating "SUB Files" folder on SDCard...';
        _progress = 0.0;
      });

      await widget.bleProvider.createDirectory(
          FlipperSubDbService.sdTargetFolder, pathType: 5);
      await Future.delayed(const Duration(milliseconds: 200));

      // Collect all unique subdirectories and create them
      final subdirs = <String>{};
      for (final file in subFiles) {
        final parts = file.relativePath.split('/');
        if (parts.length > 1) {
          // Build cumulative subdir paths
          for (int i = 1; i < parts.length; i++) {
            final subdir = '${FlipperSubDbService.sdTargetFolder}/${parts.sublist(0, i).join('/')}';
            subdirs.add(subdir);
          }
        }
      }

      // Create subdirectories (sorted so parents come first)
      final sortedDirs = subdirs.toList()..sort();
      for (final dir in sortedDirs) {
        setState(() {
          _statusText = 'Creating folder: $dir';
        });
        try {
          await widget.bleProvider.createDirectory(dir, pathType: 5);
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // Directory might already exist, continue
        }
      }

      // Phase 4: Upload files one at a time
      for (int i = 0; i < subFiles.length; i++) {
        final file = subFiles[i];
        final targetPath =
            '${FlipperSubDbService.sdTargetFolder}/${file.relativePath}';

        if (mounted) {
          setState(() {
            _uploadedFiles = i;
            _statusText = 'Uploading (${i + 1}/$_totalFiles): ${file.relativePath}';
            _progress = i / _totalFiles;
          });
        }

        try {
          await widget.bleProvider.uploadFileFromBytes(
            file.content,
            targetPath,
            pathType: 5,
          );
          // Pace uploads to avoid BLE congestion
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          _failedFiles++;
          // Log but continue with other files
          print('Failed to upload ${file.relativePath}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isDone = true;
          _uploadedFiles = _totalFiles;
          _progress = 1.0;
          _statusText = _failedFiles > 0
              ? 'Completed with $_failedFiles errors'
              : 'All $_totalFiles files uploaded successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDone = true;
          _hasError = true;
          _errorMessage = e.toString();
          _statusText = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isDone
                ? (_hasError ? Icons.error_outline : Icons.check_circle)
                : Icons.cloud_download,
            color: _isDone
                ? (_hasError ? AppColors.error : AppColors.success)
                : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isDone
                  ? (_hasError ? 'Clone Failed' : 'Clone Complete')
                  : 'Cloning SubGHz Database',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase indicator
          if (!_isDone) ...[
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _phase == 'download'
                      ? 'Phase 1/3: Downloading'
                      : _phase == 'extract'
                          ? 'Phase 2/3: Extracting'
                          : 'Phase 3/3: Uploading to SDCard',
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Status text
          Text(
            _statusText,
            style: TextStyle(
              color: _hasError ? AppColors.error : AppColors.primaryText,
              fontSize: 12,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _isDone ? 1.0 : (_progress > 0 ? _progress : null),
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasError
                    ? AppColors.error
                    : _isDone
                        ? AppColors.success
                        : Colors.orange,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // File counter (during upload phase)
          if (_phase == 'upload' || _isDone)
            Text(
              '$_uploadedFiles / $_totalFiles files'
              '${_failedFiles > 0 ? ' ($_failedFiles failed)' : ''}',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),

          // Error message
          if (_hasError && _errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(color: AppColors.error, fontSize: 11),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isDone)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
      ],
    );
  }
}
