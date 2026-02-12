import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/log_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/quick_connect_widget.dart';
import '../widgets/module_status_widget.dart';
import '../widgets/status_bar_widget.dart';
import '../theme/app_colors.dart';
import 'brute_screen.dart';
import 'files_screen.dart';
import 'settings_screen.dart';
import 'record_screen.dart';
import 'signal_scanner_screen.dart';
import 'subghz_screen.dart';
import 'nrf_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _settingsTapCount = 0;
  Timer? _tapTimer;
  BleProvider? _bleProvider; // Saved reference for safe dispose

  final List<Widget> _screens = [
    const HomeTab(),
    const SubGhzScreen(),
    const NrfScreen(),
    const FilesScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Set callback for logging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bleProvider = Provider.of<BleProvider>(context, listen: false);
      final logProvider = Provider.of<LogProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      
      // Listen for connection state changes
      _bleProvider!.addListener(_onConnectionStateChanged);
      
      // Forward BLE events to notification provider (status bar feedback)
      _bleProvider!.setNotificationCallback((level, message) {
        switch (level) {
          case 'success':
            notificationProvider.showSuccess(message);
            break;
          case 'error':
            notificationProvider.showError(message);
            break;
          case 'warning':
            notificationProvider.showWarning(message);
            break;
          default:
            notificationProvider.showInfo(message);
            break;
        }
      });
      
      _bleProvider!.setLogCallback((level, message, {details}) {
        switch (level) {
          case 'command':
            logProvider.addCommandLog(message);
            break;
          case 'response':
            logProvider.addResponseLog(message);
            break;
          case 'info':
            logProvider.addInfoLog(message);
            break;
          case 'error':
            logProvider.addErrorLog(message);
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _bleProvider?.removeListener(_onConnectionStateChanged);
    _tapTimer?.cancel();
    super.dispose();
  }

  void _startTapTimer() {
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 2), _resetTapCount);
  }

  void _resetTapCount() {
    _settingsTapCount = 0;
    _tapTimer?.cancel();
  }

  bool _settingsSyncShown = false;

  void _onConnectionStateChanged() {
    if (!mounted) return;
    final ble = _bleProvider;
    if (ble != null) {
      // Show a SnackBar once when settings are synced after BLE connect
      if (ble.settingsSynced && !_settingsSyncShown) {
        _settingsSyncShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.settingsSyncedWithDevice),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // Reset flag when disconnected so it shows again on next connect
      if (!ble.isConnected) {
        _settingsSyncShown = false;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with top padding for toolbar
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: _screens[_currentIndex],
            ),
            
            // Status bar overlay (above content)
            const StatusBarWidget(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          final bleProvider = Provider.of<BleProvider>(context, listen: false);
          
          // Allow Home (index 0) and Settings (index 4) without connection
          // Block Sub-GHz (1), NRF (2) and Files (3) if not connected
          if (!bleProvider.isConnected && index != 0 && index != 4) {
            // Show connection required dialog
            final l10n = AppLocalizations.of(context)!;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  l10n.connectionRequired,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                content: Text(
                  l10n.connectionRequiredMessage,
                  style: const TextStyle(color: AppColors.primaryText),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            );
            return;
          }
          
          // Handle debug mode activation on Settings tap
          if (index == 4) {
            _settingsTapCount++;
            if (_settingsTapCount == 1) {
              _startTapTimer();
            }
            if (_settingsTapCount >= 5) {
              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
              settingsProvider.setDebugMode(true);
              _resetTapCount();
              // Optional: show a snackbar to confirm
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.debugModeEnabled)),
              );
            }
          } else {
            _resetTapCount();
          }
          
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_input_antenna),
            label: AppLocalizations.of(context)!.subGhzTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.wifi_tethering),
            label: AppLocalizations.of(context)!.nrfTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder),
            label: AppLocalizations.of(context)!.files,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        // When connected, show scanner as main home content
        if (bleProvider.isConnected) {
          return Column(
            children: [
              // Compact connection status bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_connected, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      'RF Scanner',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Signal Scanner takes the rest of the space
              const Expanded(child: SignalScannerScreen()),
            ],
          );
        }

        // When not connected, show quick connect + permission errors
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick Connect Widget
              const QuickConnectWidget(),
              
              // Permissions Status (only show if there are errors)
              if (_isPermissionError(bleProvider.statusMessage)) ...[
                Card(
                  color: AppColors.error,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error,
                              color: AppColors.primaryText,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.permissionError,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getLocalizedStatusMessage(context, bleProvider.statusMessage),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _isPermissionError(String status) {
    return status.contains('permission') || 
           status.contains('Permission') ||
           status.contains('denied') ||
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
}