import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/cc1101/cc1101_values.dart';

/// Widget for signal preview
class SignalPreviewWidget extends StatelessWidget {
  final String rawData;
  final double? frequency;
  final String? modulation;
  final double? dataRate;
  final double? deviation;

  const SignalPreviewWidget({
    super.key,
    required this.rawData,
    this.frequency,
    this.modulation,
    this.dataRate,
    this.deviation,
  });

  @override
  Widget build(BuildContext context) {
    if (rawData.trim().isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              AppLocalizations.of(context)!.noSignalDataToPreview,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.signalPreview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Signal info
            _buildSignalInfo(context),
            
            const SizedBox(height: 16),
            
            // Data visualization
            _buildDataVisualization(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (frequency != null)
          _buildInfoRow(l10n.frequencyLabel, '${frequency!.toStringAsFixed(2)} MHz'),
        if (modulation != null)
          _buildInfoRow(l10n.modulationLabel, modulation!),
        if (dataRate != null)
          _buildInfoRow(l10n.dataRateLabel, '${dataRate!.toStringAsFixed(2)} kBaud'),
        if (deviation != null)
          _buildInfoRow(l10n.deviationLabel, '${deviation!.toStringAsFixed(2)} kHz'),
        _buildInfoRow(l10n.dataLength, l10n.sampleCount(rawData.split(' ').length)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDataVisualization(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final samples = rawData.split(' ').where((s) => s.isNotEmpty).toList();
    if (samples.isEmpty) return const SizedBox.shrink();

    // Show first 20 values
    final displaySamples = samples.take(20).toList();
    final hasMore = samples.length > 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sampleData,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            ...displaySamples.map((sample) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                sample,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            )),
            if (hasMore)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  l10n.moreSamples(samples.length - 20),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Widget for file loading
class FileLoadWidget extends StatelessWidget {
  final VoidCallback? onLoadFile;
  final bool enabled;

  const FileLoadWidget({
    super.key,
    this.onLoadFile,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.loadSignalFile,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: enabled ? onLoadFile : null,
                    icon: const Icon(Icons.file_upload),
                    label: Text(AppLocalizations.of(context)!.selectFile),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? () => _showSupportedFormats(context) : null,
                    icon: const Icon(Icons.help_outline),
                    label: Text(AppLocalizations.of(context)!.formats),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              AppLocalizations.of(context)!.supportedFormatsShort,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportedFormats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.supportedFileFormats),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.flipperSubGhzFormat,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(AppLocalizations.of(context)!.flipperSubGhzDetails),
            
            const SizedBox(height: 16),
            
            Text(
              AppLocalizations.of(context)!.tutJsonFormat,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(AppLocalizations.of(context)!.tutJsonDetails),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying transmission status
class TransmitStatusWidget extends StatelessWidget {
  final bool isTransmitting;
  final String? statusMessage;
  final int? progress;

  const TransmitStatusWidget({
    super.key,
    required this.isTransmitting,
    this.statusMessage,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isTransmitting 
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isTransmitting ? Icons.send : Icons.pause_circle,
                  color: isTransmitting ? Colors.orange : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTransmitting ? AppLocalizations.of(context)!.transmittingEllipsis : AppLocalizations.of(context)!.readyToTransmit,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (statusMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (isTransmitting && progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress! / 100.0,
                backgroundColor: Colors.grey.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.percentComplete(progress!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget for validating transmission configuration
class TransmitValidationWidget extends StatelessWidget {
  final List<String> errors;
  final List<String> warnings;

  const TransmitValidationWidget({
    super.key,
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty && warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: errors.isNotEmpty 
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  errors.isNotEmpty ? Icons.error : Icons.warning,
                  color: errors.isNotEmpty 
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  errors.isNotEmpty ? AppLocalizations.of(context)!.validationErrors : AppLocalizations.of(context)!.warnings,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: errors.isNotEmpty 
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (errors.isNotEmpty) ...[
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(error)),
                  ],
                ),
              )),
            ],
            
            if (warnings.isNotEmpty) ...[
              ...warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠ ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(warning)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying transmission history
class TransmitHistoryWidget extends StatelessWidget {
  final List<TransmitHistoryItem> history;

  const TransmitHistoryWidget({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              AppLocalizations.of(context)!.noTransmissionHistory,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.transmissionHistory,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  leading: Icon(
                    item.success ? Icons.check_circle : Icons.error,
                    color: item.success ? Colors.green : Colors.red,
                  ),
                  title: Text('${item.frequency.toStringAsFixed(2)} MHz'),
                  subtitle: Text(
                    AppLocalizations.of(context)!.transmitHistorySubtitle(
                      item.timestamp.toString().substring(11, 19),
                      item.module + 1,
                      item.repeatCount,
                    ),
                  ),
                  trailing: Text(
                    item.success ? AppLocalizations.of(context)!.success : AppLocalizations.of(context)!.failed,
                    style: TextStyle(
                      color: item.success ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Transmission history item
class TransmitHistoryItem {
  final DateTime timestamp;
  final double frequency;
  final int module;
  final int repeatCount;
  final bool success;
  final String? errorMessage;

  TransmitHistoryItem({
    required this.timestamp,
    required this.frequency,
    required this.module,
    required this.repeatCount,
    required this.success,
    this.errorMessage,
  });
}






















