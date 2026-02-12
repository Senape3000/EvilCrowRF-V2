import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../theme/app_colors.dart';

class QuickConnectWidget extends StatelessWidget {
  const QuickConnectWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final children = <Widget>[];
        
        // Connection Status Header
        if (bleProvider.isConnected) {
          children.add(
            Row(
              children: [
                const Icon(
                  Icons.bluetooth_connected,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.connected(bleProvider.savedDeviceName),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  bleProvider.savedDeviceId ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => bleProvider.disconnect(),
                    icon: const Icon(Icons.bluetooth_disabled),
                    iconSize: 20,
                    tooltip: AppLocalizations.of(context)!.disconnect,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          );
          children.add(const SizedBox(height: 8));
        }
        
        // Status Message (only show when not connected)
        if (!bleProvider.isConnected && bleProvider.statusMessage.isNotEmpty) {
          children.add(
            Text(
              _getLocalizedStatusMessage(context, bleProvider.statusMessage),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _getStatusColor(bleProvider.statusMessage),
              ),
            ),
          );
          children.add(const SizedBox(height: 12));
        }
        
        // Device List (only show when not connected)
        if (!bleProvider.isConnected) {
          children.add(_buildDeviceList(context, bleProvider));
        }
        
        // If no children, return empty container with minimum size
        if (children.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }

  Widget _buildDeviceList(BuildContext context, BleProvider bleProvider) {
    if (bleProvider.isScanning) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text(AppLocalizations.of(context)!.connecting),
        ),
      );
    } else if (bleProvider.savedDeviceId != null) {
      // Show saved device in simple list
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bluetooth_connected,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bleProvider.savedDeviceName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        bleProvider.savedDeviceId!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _canConnect(bleProvider) ? () => bleProvider.quickConnect() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: AppColors.primaryBackground,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(AppLocalizations.of(context)!.connect),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => bleProvider.startScan(),
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(AppLocalizations.of(context)!.scanForNewDevices),
            ),
          ),
        ],
      );
    } else {
      // No saved devices - show scan button or scan results
      List<dynamic> supportedDevices = bleProvider.supportedScanResults;
      if (supportedDevices.isNotEmpty) {
        // Show found supported devices
        return Column(
          children: [
            Text(
              AppLocalizations.of(context)!.foundSupportedDevicesCount(supportedDevices.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            ...supportedDevices.map((result) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderDefault),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bluetooth,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.device.name.isNotEmpty ? result.device.name : AppLocalizations.of(context)!.unknownDevice,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          result.device.id.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _canConnect(bleProvider) ? () => _connectToDevice(bleProvider, result.device) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: AppColors.primaryBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(AppLocalizations.of(context)!.connect),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => bleProvider.startScan(),
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.scanAgain),
              ),
            ),
          ],
        );
      } else {
        // Show scan button
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canConnect(bleProvider) ? () => bleProvider.startScan() : null,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(AppLocalizations.of(context)!.scanForDevices),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: AppColors.primaryBackground,
            ),
          ),
        );
      }
    }
  }

  Future<void> _connectToDevice(BleProvider bleProvider, dynamic device) async {
    try {
      await bleProvider.connectToDevice(device);
      // Save this device for future quick connections
      await bleProvider.saveKnownDevice(device.id.toString());
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  bool _canConnect(BleProvider bleProvider) {
    return !bleProvider.isScanning && 
           !bleProvider.isConnected &&
           !_isPermissionError(bleProvider.statusMessage);
  }

  bool _isPermissionError(String status) {
    return status.contains('permissions denied') || 
           status.contains('not granted') ||
           status.contains('error');
  }

  String _getLocalizedStatusMessage(BuildContext context, String statusKey) {
    final l10n = AppLocalizations.of(context)!;
    
    // Handle keys with parameters (format: "key:value")
    if (statusKey.contains(':')) {
      final parts = statusKey.split(':');
      final key = parts[0];
      final value = parts.length > 1 ? parts[1] : '';
      
      switch (key) {
        case 'foundSupportedDevices':
          final count = int.tryParse(value) ?? 0;
          return l10n.foundSupportedDevices(count);
        default:
          return statusKey; // Return as-is if not a known key
      }
    }
    
    // Handle simple keys without parameters
    switch (statusKey) {
      case 'connecting':
        return l10n.connecting;
      case 'connectingToKnownDevice':
        return l10n.connectingToKnownDevice;
      case 'disconnected':
        return l10n.disconnected;
      case 'scanningForDevices':
        return l10n.scanningForDevices;
      case 'transmittingSignal':
        return l10n.transmittingSignal;
      default:
        // If contains "Transmitting signal...", also localize
        if (statusKey.contains('Transmitting signal')) {
          return l10n.transmittingSignal;
        }
        return statusKey; // Return as-is if not a known key
    }
  }

  Color _getStatusColor(String status) {
    if (_isPermissionError(status)) return AppColors.error;
    if (status.contains('Connected')) return AppColors.success;
    if (status.contains('Scanning') || status.contains('Connecting') || 
        status == 'connecting' || status == 'connectingToKnownDevice' || 
        status == 'scanningForDevices' || status.startsWith('foundSupportedDevices:')) {
      return AppColors.info;
    }
    return AppColors.secondaryText;
  }
}
