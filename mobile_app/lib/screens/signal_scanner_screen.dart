import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/firmware_protocol.dart';
import '../models/detected_signal.dart';
import '../theme/app_colors.dart';

class SignalScannerScreen extends StatefulWidget {
  const SignalScannerScreen({super.key});

  @override
  State<SignalScannerScreen> createState() => _SignalScannerScreenState();
}

class _SignalScannerScreenState extends State<SignalScannerScreen>
    with TickerProviderStateMixin {

  // Scanning modes
  bool _isListMode = true;
  bool _isScanning = false;
  int _selectedModule = 0; // 0 or 1 (displayed as 1 or 2)

  // List mode parameters
  double _rssiThreshold = 80.0; // RSSI threshold (0-100, default -80 dBm)

  // Animations for the spectrogram
  late AnimationController _spectrumAnimationController;

  // Dynamic spectrogram state: frequency → current RSSI level (decays over time)
  final Map<double, double> _spectrumLevels = {};
  Timer? _decayTimer;
  int _lastSignalCount = 0; // Track signal list changes

  // All 18 frequencies matching the firmware's signalDetectionFrequencies[]
  final List<double> _scanFrequencies = [
    300.00, 303.87, 304.25, 310.00, 315.00, 318.00,
    390.00, 418.00, 433.07, 433.92, 434.42, 434.77,
    438.90, 868.35, 868.87, 868.95, 915.00, 925.00,
  ];

  @override
  void initState() {
    super.initState();
    // Initialize spectrum levels
    for (final freq in _scanFrequencies) {
      _spectrumLevels[freq] = -120.0;
    }
    _spectrumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..addListener(() {
        if (!_isListMode) setState(() {}); // Rebuild spectrogram on tick
      });
  }

  @override
  void dispose() {
    // Stop scanning on the firmware when leaving this screen
    if (_isScanning) {
      _stopScanning();
    }
    _decayTimer?.cancel();
    _spectrumAnimationController.dispose();
    super.dispose();
  }

  // ── Scanning control ──────────────────────────────────────────────

  Future<void> _startScanning() async {
    if (_isScanning) return;
    final bleProvider = Provider.of<BleProvider>(context, listen: false);

    setState(() => _isScanning = true);
    if (!_isListMode) _spectrumAnimationController.repeat();

    // Start decay timer for dynamic spectrogram
    _startDecayTimer();

    try {
      final int rssiThresholdInt = -_rssiThreshold.toInt();
      if (_selectedModule == -1) {
        // Both modules: send scan command to module 0 and module 1
        final cmd0 = FirmwareBinaryProtocol.createRequestScanCommand(rssiThresholdInt, 0);
        final cmd1 = FirmwareBinaryProtocol.createRequestScanCommand(rssiThresholdInt, 1);
        await bleProvider.sendBinaryCommand(cmd0);
        await bleProvider.sendBinaryCommand(cmd1);
      } else {
        final command = FirmwareBinaryProtocol.createRequestScanCommand(
            rssiThresholdInt, _selectedModule);
        await bleProvider.sendBinaryCommand(command);
      }
    } catch (e) {
      setState(() => _isScanning = false);
      _spectrumAnimationController.stop();
      _decayTimer?.cancel();
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .showError(AppLocalizations.of(context)!.errorStartingScan('$e'));
      }
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) return;
    final bleProvider = Provider.of<BleProvider>(context, listen: false);

    setState(() => _isScanning = false);
    _spectrumAnimationController.stop();
    _decayTimer?.cancel();

    try {
      if (_selectedModule == -1) {
        // Stop both modules
        final cmd0 = FirmwareBinaryProtocol.createRequestIdleCommand(0);
        final cmd1 = FirmwareBinaryProtocol.createRequestIdleCommand(1);
        await bleProvider.sendBinaryCommand(cmd0);
        await bleProvider.sendBinaryCommand(cmd1);
      } else {
        final command = FirmwareBinaryProtocol.createRequestIdleCommand(
            _selectedModule);
        await bleProvider.sendBinaryCommand(command);
      }
    } catch (e) {
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .showError(AppLocalizations.of(context)!.errorStoppingScan('$e'));
      }
    }
  }

  void _clearSignals() {
    Provider.of<BleProvider>(context, listen: false)
        .updateDetectedSignals([]);
  }

  /// Re-send scan command with updated RSSI threshold while scanning
  Future<void> _restartScanningWithNewRssi() async {
    if (!_isScanning) return;
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    try {
      final int rssiThresholdInt = -_rssiThreshold.toInt();
      if (_selectedModule == -1) {
        final cmd0 = FirmwareBinaryProtocol.createRequestScanCommand(rssiThresholdInt, 0);
        final cmd1 = FirmwareBinaryProtocol.createRequestScanCommand(rssiThresholdInt, 1);
        await bleProvider.sendBinaryCommand(cmd0);
        await bleProvider.sendBinaryCommand(cmd1);
      } else {
        final command = FirmwareBinaryProtocol.createRequestScanCommand(
            rssiThresholdInt, _selectedModule);
        await bleProvider.sendBinaryCommand(command);
      }
    } catch (_) {}
  }

  // ── Build spectrum data from detected signals ─────────────────────

  /// For each scan frequency, find the strongest matching signal (±0.5 MHz).
  Map<double, double> _buildSpectrum(List<DetectedSignal> signals) {
    final Map<double, double> spectrum = {};
    for (final freq in _scanFrequencies) {
      double bestRssi = -120.0;
      for (final sig in signals) {
        final sigFreq = double.tryParse(sig.frequency) ?? 0;
        if ((sigFreq - freq).abs() < 0.5 && sig.rssi > bestRssi) {
          bestRssi = sig.rssi.toDouble();
        }
      }
      spectrum[freq] = bestRssi;
    }
    return spectrum;
  }

  /// Start a periodic timer that:
  /// 1. Updates spectrum levels from newly detected signals (peaks rise)
  /// 2. Applies decay so bars gradually decrease when no new signal arrives
  void _startDecayTimer() {
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted || !_isScanning) return;

      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      final signals = bleProvider.detectedSignals;

      // Build fresh snapshot from recent signals (last 3 seconds)
      final now = DateTime.now();
      final recentSignals = signals.where(
        (s) => now.difference(s.timestamp).inMilliseconds < 3000,
      ).toList();
      final freshSpectrum = _buildSpectrum(recentSignals);

      // Update spectrum levels: peak-hold with decay
      for (final freq in _scanFrequencies) {
        final fresh = freshSpectrum[freq] ?? -120.0;
        final current = _spectrumLevels[freq] ?? -120.0;

        if (fresh > current) {
          // New peak — jump up instantly
          _spectrumLevels[freq] = fresh;
        } else {
          // Decay: drop 3 dBm per tick (~10 dBm/sec)
          _spectrumLevels[freq] = math.max(-120.0, current - 3.0);
        }
      }

      setState(() {});
    });
  }

  // ── Main build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          body: Column(
            children: [
              // ── Compact dark header ──
              Container(
                height: 48,
                color: AppColors.secondaryBackground,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.radar, size: 20, color: AppColors.primaryAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.scanner,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all, color: AppColors.primaryText),
                      onPressed: _clearSignals,
                      tooltip: AppLocalizations.of(context)!.clearList,
                    ),
                    IconButton(
                      icon: Icon(
                        _isScanning ? Icons.stop : Icons.play_arrow,
                        color: _isScanning ? AppColors.error : AppColors.success,
                      ),
                      onPressed: _isScanning ? _stopScanning : _startScanning,
                      tooltip: _isScanning ? AppLocalizations.of(context)!.stop : AppLocalizations.of(context)!.start,
                    ),
                  ],
                ),
              ),
              // ── Content ──
              Expanded(
                child: Column(
                  children: [
                    _buildControlPanel(),
                    _buildModeSwitch(),
                    Expanded(
                      child: _isListMode
                          ? _buildListView(bleProvider)
                          : _buildSpectrumView(bleProvider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Control panel (dark) ──────────────────────────────────────────

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        children: [
          // Module selection
          Row(
            children: [
              Text(AppLocalizations.of(context)!.moduleLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text('M1', style: const TextStyle(fontSize: 11))),
                    ButtonSegment(value: 1, label: Text('M2', style: const TextStyle(fontSize: 11))),
                    const ButtonSegment(value: -1, label: Text('1+2', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_selectedModule},
                  onSelectionChanged: _isScanning ? null : (s) {
                    setState(() => _selectedModule = s.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // RSSI threshold
          if (_isListMode)
            Row(
              children: [
                const Text('RSSI:', style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primaryText, fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: _rssiThreshold,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '-${_rssiThreshold.toInt()} dBm',
                    activeColor: AppColors.primaryAccent,
                    onChanged: (v) {
                      setState(() => _rssiThreshold = v);
                      // Re-send scan command with new RSSI threshold in real-time
                      if (_isScanning) {
                        _restartScanningWithNewRssi();
                      }
                    },
                  ),
                ),
                Text('-${_rssiThreshold.toInt()} dBm',
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 12)),
              ],
            ),
          // Scanning indicator
          Row(
            children: [
              Icon(
                _isScanning ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _isScanning ? AppColors.success : AppColors.disabledText,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _isScanning ? AppLocalizations.of(context)!.scanningActive : AppLocalizations.of(context)!.scanningStopped,
                style: TextStyle(
                  color: _isScanning ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mode switch (dark pill) ───────────────────────────────────────

  Widget _buildModeSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: AppColors.surfaceElevated,
      ),
      child: Row(
        children: [
          _modeSwitchTab(AppLocalizations.of(context)!.signalList, isSelected: _isListMode, onTap: () {
            setState(() => _isListMode = true);
          }),
          _modeSwitchTab(AppLocalizations.of(context)!.spectrogramView, isSelected: !_isListMode, onTap: () {
            setState(() => _isListMode = false);
          }),
        ],
      ),
    );
  }

  Widget _modeSwitchTab(String label, {required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          onTap();
          // Start/stop animation controller when switching to/from spectrogram
          if (!_isListMode && _isScanning) {
            _spectrumAnimationController.repeat();
          } else {
            _spectrumAnimationController.stop();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: isSelected ? AppColors.primaryAccent : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : AppColors.secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ── Signal list (dark cards) ──────────────────────────────────────

  Widget _buildListView(BleProvider bleProvider) {
    if (bleProvider.detectedSignals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_cellular_off, size: 56, color: AppColors.disabledText),
            const SizedBox(height: 12),
            Text(
              _isScanning ? AppLocalizations.of(context)!.searchingForSignals : AppLocalizations.of(context)!.pressStartToScan,
              style: const TextStyle(fontSize: 15, color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bleProvider.detectedSignals.length,
      itemBuilder: (context, index) {
        final signal = bleProvider.detectedSignals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: AppColors.secondaryBackground,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRssiColor(signal.rssi),
              child: Text(
                '${signal.module}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            title: Text(
              signal.frequencyFormatted,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RSSI: ${signal.rssiFormatted}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                Text('Time: ${signal.timeFormatted}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ],
            ),
            trailing: Icon(
              _getSignalStrengthIcon(signal.rssi),
              color: _getRssiColor(signal.rssi),
            ),
          ),
        );
      },
    );
  }

  // ── Spectrogram view (dark, populated from detected signals) ──────

  Widget _buildSpectrumView(BleProvider bleProvider) {
    // Use the dynamic spectrum levels (with decay) instead of static snapshot
    final spectrum = Map<double, double>.from(_spectrumLevels);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.signalSpectrogram,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildSpectrumEqualizer(spectrum)),
          _buildSpectrumLegend(),
        ],
      ),
    );
  }

  Widget _buildSpectrumEqualizer(Map<double, double> spectrum) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.logBackground,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barAreaHeight = constraints.maxHeight - 40; // Reserve space for labels
          return Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Y-axis labels
                    SizedBox(
                      width: 32,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('-20', style: TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                          Text('-50', style: TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                          Text('-80', style: TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                          Text('-120', style: TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                    // Bars
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _scanFrequencies.map((freq) {
                          final rssi = spectrum[freq] ?? -120.0;
                          // Normalize: -120 dBm = 0%, -20 dBm = 100%
                          final pct = ((rssi + 120) / 100).clamp(0.0, 1.0);
                          final barH = math.max(2.0, pct * (barAreaHeight > 0 ? barAreaHeight : 150));
                          final color = _getRssiColor(rssi.toInt());

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                height: barH,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [color.withOpacity(0.6), color],
                                  ),
                                  boxShadow: pct > 0.15
                                      ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Frequency labels
              Row(
                children: [
                  const SizedBox(width: 32), // Y-axis offset
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _scanFrequencies.map((freq) {
                        // Compact label for 18 bars: drop decimal for integers, abbreviate
                        final label = freq >= 100
                            ? (freq == freq.roundToDouble()
                                ? freq.toInt().toString()
                                : freq.toStringAsFixed(0))
                            : freq.toStringAsFixed(0);
                        return Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 7,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpectrumLegend() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.red, AppLocalizations.of(context)!.signalStrengthStrong),
          _buildLegendItem(Colors.orange, AppLocalizations.of(context)!.signalStrengthMedium),
          _buildLegendItem(Colors.green, AppLocalizations.of(context)!.signalStrengthWeak),
          _buildLegendItem(AppColors.disabledText, AppLocalizations.of(context)!.signalStrengthNone),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Color _getRssiColor(int rssi) {
    if (rssi >= -30) return Colors.red;
    if (rssi >= -50) return Colors.orange;
    if (rssi >= -70) return Colors.yellow;
    if (rssi >= -90) return Colors.green;
    return AppColors.disabledText;
  }

  IconData _getSignalStrengthIcon(int rssi) {
    if (rssi >= -30) return Icons.signal_cellular_4_bar;
    if (rssi >= -50) return Icons.network_cell;
    if (rssi >= -70) return Icons.signal_cellular_alt_2_bar;
    if (rssi >= -90) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_off;
  }
}
