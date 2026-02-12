import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import 'quick_connect_widget.dart';
import 'module_status_widget.dart';

class StatusBarWidget extends StatefulWidget {
  const StatusBarWidget({super.key});

  @override
  State<StatusBarWidget> createState() => _StatusBarWidgetState();
}

class _StatusBarWidgetState extends State<StatusBarWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Compact status bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBackground.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left part: status icons (5-6 icons)
                  _buildStatusIcons(context),
                  
                  // Separator
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                  ),
                  
                  // Right part: notification area
                  Expanded(
                    child: _buildNotificationArea(context),
                  ),
                  
                  // Expand icon
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        
        // Expanded content with background shading
        if (_isExpanded) ...[
          // Background dimming
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = false;
                });
              },
              child: Container(
                color: AppColors.primaryBackground.withOpacity(0.5),
              ),
            ),
          ),
          // Content above dimming
          Positioned(
            top: 36,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBackground.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick Connect Widget (device widget with disconnect button)
                    const QuickConnectWidget(),
                    
                    const SizedBox(height: 12),
                    
                    // Module Status Widget
                    Consumer<BleProvider>(
                      builder: (context, bleProvider, child) {
                        if (bleProvider.isConnected && bleProvider.cc1101Modules != null) {
                          return ModuleStatusWidget(
                            cc1101Modules: bleProvider.cc1101Modules!,
                            deviceInfo: {'freeHeap': bleProvider.freeHeap ?? 0},
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcons(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. BLE Connection Status
              _StatusIcon(
                icon: bleProvider.isConnected 
                    ? Icons.bluetooth_connected 
                    : Icons.bluetooth_disabled,
                color: bleProvider.isConnected 
                    ? const Color(0xFF42A5F5) // Blue for connected
                    : const Color(0xFFEF5350).withOpacity(0.5), // Dim red for disconnected
                tooltip: bleProvider.isConnected 
                    ? AppLocalizations.of(context)!.connectedToDevice(bleProvider.connectedDevice?.platformName ?? AppLocalizations.of(context)!.unknown)
                    : AppLocalizations.of(context)!.notConnected,
              ),
              
              const SizedBox(width: 6),
              
              // 2. Module 0 Status
              if (bleProvider.isConnected && bleProvider.cc1101Modules != null && bleProvider.cc1101Modules!.isNotEmpty)
                _StatusIcon(
                  icon: Icons.settings_input_antenna,
                  color: _getModuleColorFromMode(bleProvider.cc1101Modules![0]['mode'] ?? 'Idle'),
                  tooltip: '${AppLocalizations.of(context)!.subGhzModule(1)}: ${bleProvider.cc1101Modules![0]['mode'] ?? AppLocalizations.of(context)!.unknown}',
                  label: '1',
                ),
              
              const SizedBox(width: 6),
              
              // 3. Module 1 Status
              if (bleProvider.isConnected && bleProvider.cc1101Modules != null && bleProvider.cc1101Modules!.length > 1)
                _StatusIcon(
                  icon: Icons.settings_input_antenna,
                  color: _getModuleColorFromMode(bleProvider.cc1101Modules![1]['mode'] ?? 'Idle'),
                  tooltip: '${AppLocalizations.of(context)!.subGhzModule(2)}: ${bleProvider.cc1101Modules![1]['mode'] ?? AppLocalizations.of(context)!.unknown}',
                  label: '2',
                ),
              
              const SizedBox(width: 6),
              
              // 4. NRF24 Module Status
              if (bleProvider.isConnected && bleProvider.nrfInitialized)
                _StatusIcon(
                  icon: Icons.router,
                  color: _getNrfStatusColor(bleProvider),
                  tooltip: _getNrfStatusTooltip(bleProvider),
                  label: 'N',
                ),
              
              const SizedBox(width: 6),
              
              // 5. SD Card Status (always available when connected)
              if (bleProvider.isConnected)
                _StatusIcon(
                  icon: Icons.sd_card,
                  color: AppColors.primaryText,
                  tooltip: AppLocalizations.of(context)!.sdCardReady,
                ),
              
              const SizedBox(width: 6),
              
              // 6. Battery Status
              if (bleProvider.isConnected && bleProvider.hasBatteryInfo)
                _BatteryStatusIcon(
                  percentage: bleProvider.batteryPercent,
                  charging: bleProvider.batteryCharging,
                  voltage: bleProvider.batteryVoltage,
                ),
              
              const SizedBox(width: 6),
              
              // 7. Memory Status
              if (bleProvider.isConnected && bleProvider.freeHeap != null)
                _MemoryStatusIcon(freeHeap: bleProvider.freeHeap!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationArea(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final notification = notificationProvider.currentNotification;
        final hasHistory = notificationProvider.notificationHistory.isNotEmpty;
        
        // Show either current notification or button to view history
        if (notification == null) {
          if (!hasHistory) {
            return const SizedBox(width: 1, height: 36);
          }
          // Show button to view history
          return InkWell(
            onTap: () => _showNotificationList(context, notificationProvider),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${notificationProvider.notificationHistory.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return InkWell(
          onTap: () => _showNotificationList(context, notificationProvider),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              notification.message,
              style: TextStyle(
                fontSize: 12,
                color: notification.color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  void _showNotificationList(BuildContext context, NotificationProvider notificationProvider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final hasHistory = provider.notificationHistory.isNotEmpty;
            print('Notification history length: ${provider.notificationHistory.length}, hasHistory: $hasHistory');
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.notifications),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              body: !hasHistory
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noNotifications,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        if (hasHistory)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    provider.clearHistory();
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: Text(AppLocalizations.of(context)!.clearAll),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.notificationHistory.length,
                            itemBuilder: (context, index) {
                              final notif = provider.notificationHistory[index];
                              return _NotificationListItem(notification: notif);
                            },
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
        fullscreenDialog: false,
      ),
    );
  }

  IconData _getModuleIcon(int state) {
    switch (state) {
      case 0: return Icons.circle_outlined; // Idle
      case 1: return Icons.sensors; // Detecting
      case 2: return Icons.radio_button_checked; // Recording
      case 3: return Icons.send; // Transmitting
      default: return Icons.help_outline; // Unknown
    }
  }

  Color _getModuleColor(int state) {
    switch (state) {
      case 0: return AppColors.idle; // Idle
      case 1: return AppColors.searching; // Detecting
      case 2: return AppColors.recording; // Recording
      case 3: return AppColors.transmitting; // Transmitting
      default: return AppColors.disabledText; // Unknown
    }
  }

  String _getModuleStateName(int state) {
    final l10n = AppLocalizations.of(context)!;
    switch (state) {
      case 0: return l10n.stateIdle;
      case 1: return l10n.stateDetecting;
      case 2: return l10n.stateRecording;
      case 3: return l10n.stateTransmitting;
      default: return l10n.stateUnknown;
    }
  }

  Color _getModuleColorFromMode(String mode) {
    final statusLower = mode.toLowerCase();
    // For Idle use primaryText (like SD and Heap)
    if (statusLower == 'idle') {
      return AppColors.primaryText;
    }
    // For transmitting/sendsignal use green
    if (statusLower == 'sendsignal' || statusLower == 'transmitting') {
      return AppColors.success;
    }
    // For other statuses use standard function
    return AppColors.getModuleStatusColor(mode);
  }

  /// NRF24 status color: orange when busy, green-white when idle
  Color _getNrfStatusColor(BleProvider bleProvider) {
    if (bleProvider.nrfJammerRunning ||
        bleProvider.nrfScanning ||
        bleProvider.nrfAttacking ||
        bleProvider.nrfSpectrumRunning) {
      return const Color(0xFFFF9100); // Bright orange — very visible
    }
    return AppColors.primaryText; // Idle — same as SD card
  }

  /// NRF24 tooltip text describing current state
  String _getNrfStatusTooltip(BleProvider bleProvider) {
    final l10n = AppLocalizations.of(context)!;
    if (bleProvider.nrfJammerRunning) return l10n.nrf24Jamming;
    if (bleProvider.nrfScanning)      return l10n.nrf24Scanning;
    if (bleProvider.nrfAttacking)     return l10n.nrf24Attacking;
    if (bleProvider.nrfSpectrumRunning) return l10n.nrf24SpectrumActive;
    return l10n.nrf24Idle;
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final String? label;

  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          if (label != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1),
                ),
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryStatusIcon extends StatelessWidget {
  final int freeHeap;

  const _MemoryStatusIcon({required this.freeHeap});

  @override
  Widget build(BuildContext context) {
    final freeKB = freeHeap / 1024;
    final color = freeKB > 50 ? AppColors.success : freeKB > 30 ? AppColors.primaryText : AppColors.error;
    final l10n = AppLocalizations.of(context)!;
    
    return Tooltip(
      message: l10n.freeHeap(freeKB.toStringAsFixed(1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.memory,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${freeKB.toStringAsFixed(0)}K',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Battery status icon with percentage and charging indicator.
class _BatteryStatusIcon extends StatelessWidget {
  final int percentage;
  final bool charging;
  final int voltage;

  const _BatteryStatusIcon({
    required this.percentage,
    required this.charging,
    required this.voltage,
  });

  IconData _getBatteryIcon() {
    if (charging) return Icons.battery_charging_full;
    if (percentage >= 90) return Icons.battery_full;
    if (percentage >= 70) return Icons.battery_6_bar;
    if (percentage >= 50) return Icons.battery_5_bar;
    if (percentage >= 35) return Icons.battery_4_bar;
    if (percentage >= 20) return Icons.battery_3_bar;
    if (percentage >= 10) return Icons.battery_2_bar;
    if (percentage >= 5) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  Color _getBatteryColor() {
    if (charging) return AppColors.info;
    if (percentage > 50) return AppColors.success;
    if (percentage > 20) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBatteryColor();
    final volts = (voltage / 1000.0).toStringAsFixed(2);
    return Tooltip(
      message: AppLocalizations.of(context)!.batteryTooltip(percentage, volts, charging ? AppLocalizations.of(context)!.chargingIndicator : ''),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBatteryIcon(),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  final AppNotification notification;

  const _NotificationListItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(context, notification.timestamp);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              notification.icon,
              size: 20,
              color: notification.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  maxLines: null,
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final l10n = AppLocalizations.of(context)!;
    
    if (difference.inSeconds < 60) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}${l10n.minutesAgo}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}${l10n.hoursAgo}';
    } else {
      return '${difference.inDays}${l10n.daysAgo}';
    }
  }
}

