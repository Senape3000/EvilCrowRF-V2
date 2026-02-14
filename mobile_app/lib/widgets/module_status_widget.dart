import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/cc1101/cc1101_calculator.dart';
import '../theme/app_colors.dart';

/// Compact widget for displaying CC1101 module status
class ModuleStatusWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cc1101Modules;
  final Map<String, dynamic>? deviceInfo;
  // nRF24 status
  final bool nrfPresent;
  final bool nrfInitialized;
  final bool nrfJammerRunning;
  final bool nrfScanning;
  final bool nrfAttacking;
  final bool nrfSpectrumRunning;
  // SD card status
  final bool sdMounted;
  final int sdTotalMB;
  final int sdFreeMB;

  const ModuleStatusWidget({
    super.key,
    required this.cc1101Modules,
    this.deviceInfo,
    this.nrfPresent = false,
    this.nrfInitialized = false,
    this.nrfJammerRunning = false,
    this.nrfScanning = false,
    this.nrfAttacking = false,
    this.nrfSpectrumRunning = false,
    this.sdMounted = false,
    this.sdTotalMB = 0,
    this.sdFreeMB = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with device info
            _buildHeader(context),
            const SizedBox(height: 12),
            
            // Module info
            ...cc1101Modules.asMap().entries.map((entry) {
              final index = entry.key;
              final module = entry.value;
              return _buildModuleCard(context, index, module);
            }),

            // nRF24 module status
            _buildNrfCard(context),

            // SD card status
            _buildSdCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final freeHeap = deviceInfo?['freeHeap'] ?? 0;
    
    return Row(
      children: [
        Icon(
          Icons.memory,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context)!.deviceStatus,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${(freeHeap / 1024).toStringAsFixed(1)} KB',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(BuildContext context, int index, Map<String, dynamic> module) {
    final moduleId = module['id'] ?? index;
    final mode = module['mode'] ?? 'Unknown';
    final settings = module['settings'] ?? '';
    
    // Parse module settings
    CC1101Config? config;
    try {
      if (settings.isNotEmpty) {
        config = parseSettingsFromString(settings);
      }
    } catch (e) {
      // If parsing failed, show error
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module header
          Row(
            children: [
              Icon(
                Icons.settings_input_antenna,
                size: 18,
                color: _getModeColor(context, mode),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.subGhzModule(moduleId + 1),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const Spacer(),
              _buildModeChip(context, mode),
            ],
          ),
          
          if (config != null) ...[
            const SizedBox(height: 8),
            _buildConfigInfo(context, config),
          ] else if (settings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSettingsError(context, settings),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChip(BuildContext context, String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getModeColor(context, mode).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getLocalizedMode(context, mode),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: _getModeColor(context, mode),
        ),
      ),
    );
  }

  Widget _buildConfigInfo(BuildContext context, CC1101Config config) {
    return Column(
      children: [
        // Frequency and modulation
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.graphic_eq,
                '${config.frequency.toStringAsFixed(1)} ${AppLocalizations.of(context)!.mhz}',
                AppLocalizations.of(context)!.frequency,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.radio,
                _getLocalizedModulationName(context, config.modulationName),
                AppLocalizations.of(context)!.modulation,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        
        // Data Rate and Bandwidth
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.speed,
                '${(config.dataRate / 1000).toStringAsFixed(1)} ${AppLocalizations.of(context)!.kbps}',
                AppLocalizations.of(context)!.dataRate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoItem(
                context,
                Icons.straighten,
                '${(config.bandwidth / 1000).toStringAsFixed(1)} ${AppLocalizations.of(context)!.khz}',
                AppLocalizations.of(context)!.bandwidth,
              ),
            ),
          ],
        ),
        // Deviation for FSK modulations (2-FSK or GFSK)
        if (config.modulation == 0 || config.modulation == 1) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
              child: _buildInfoItem(
                context,
                Icons.tune,
                '${(config.deviation / 1000).toStringAsFixed(2)} ${AppLocalizations.of(context)!.khz}',
                AppLocalizations.of(context)!.deviation,
              ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsError(BuildContext context, String settings) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.settingsParseError,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                Text(
                  'Raw: ${settings.substring(0, 50)}${settings.length > 50 ? '...' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedMode(BuildContext context, String mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode.toLowerCase()) {
      case 'idle':
        return l10n.statusIdle;
      case 'record':
      case 'recording':
      case 'recordsignal':
        return l10n.statusRecording;
      case 'transmit':
      case 'transmitting':
        return l10n.statusTransmitting;
      case 'scan':
      case 'scanning':
      case 'detectsignal':
        return l10n.statusScanning;
      default:
        return mode;
    }
  }

  String _getLocalizedModulationName(BuildContext context, String modulationName) {
    final l10n = AppLocalizations.of(context)!;
    switch (modulationName) {
      case 'ASK/OOK':
        return l10n.modulationAskOok;
      case '2-FSK':
        return l10n.modulation2Fsk;
      case '4-FSK':
        return l10n.modulation4Fsk;
      case 'GFSK':
        return l10n.modulationGfsk;
      case 'MSK':
        return l10n.modulationMsk;
      default:
        return modulationName;
    }
  }

  Color _getModeColor(BuildContext context, String mode) {
    return AppColors.getModuleStatusColor(mode);
  }

  // ── nRF24 module status card ──────────────────────────────────

  Widget _buildNrfCard(BuildContext context) {
    // Determine nRF state string and color
    String stateStr;
    Color stateColor;
    if (!nrfPresent) {
      stateStr = 'Not Present';
      stateColor = AppColors.disabledText;
    } else if (!nrfInitialized) {
      stateStr = 'Not Initialized';
      stateColor = AppColors.warning;
    } else if (nrfJammerRunning) {
      stateStr = 'Jamming';
      stateColor = AppColors.error;
    } else if (nrfScanning) {
      stateStr = 'Scanning';
      stateColor = AppColors.info;
    } else if (nrfAttacking) {
      stateStr = 'Attacking';
      stateColor = const Color(0xFFFF9100);
    } else if (nrfSpectrumRunning) {
      stateStr = 'Spectrum';
      stateColor = AppColors.info;
    } else {
      stateStr = 'Idle';
      stateColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.router,
            size: 18,
            color: stateColor,
          ),
          const SizedBox(width: 8),
          Text(
            'nRF24L01+',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: stateColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              stateStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: stateColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SD card status card ───────────────────────────────────────

  Widget _buildSdCard(BuildContext context) {
    final Color iconColor;
    final String statusText;

    if (!sdMounted) {
      iconColor = AppColors.disabledText;
      statusText = 'Not Inserted';
    } else {
      iconColor = AppColors.success;
      statusText = '${sdFreeMB} MB free / ${sdTotalMB} MB';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sd_card,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Text(
            'SD Card',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
