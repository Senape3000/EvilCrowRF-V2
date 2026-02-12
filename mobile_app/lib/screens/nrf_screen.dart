import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/firmware_protocol.dart';
import '../theme/app_colors.dart';

/// NRF target model for scanned devices
class NrfTarget {
  final String type;
  final int channel;
  final List<int> address;

  NrfTarget({required this.type, required this.channel, required this.address});

  String get addressHex =>
      address.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

  /// Convert device type code from firmware to human-readable string
  static String typeFromCode(int code) {
    switch (code) {
      case 1:  return 'Microsoft';
      case 2:  return 'MS Encrypted';
      case 3:  return 'Logitech';
      default: return 'Unknown';
    }
  }
}

/// Full NRF24 screen with three tabs: MouseJack, Spectrum, Jammer.
class NrfScreen extends StatefulWidget {
  const NrfScreen({super.key});

  @override
  State<NrfScreen> createState() => _NrfScreenState();
}

class _NrfScreenState extends State<NrfScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initializing = false;
  bool _initFailed = false;

  // Local UI state (not data)
  int _selectedTargetIndex = -1;
  final TextEditingController _stringController = TextEditingController();
  final TextEditingController _duckyPathController = TextEditingController();

  // Jammer UI controls (local until sent to firmware)
  int _jamMode = 0;
  int _jamChannel = 50;
  int _hopStart = 0;
  int _hopStop = 80;
  int _hopStep = 2;

  // MouseJack filter
  bool _hideUnknown = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    // Send NRF_STOP_ALL to firmware to cleanly release SPI bus
    // when user navigates away from NRF screen
    _cleanupNrf();
    _tabController.dispose();
    _stringController.dispose();
    _duckyPathController.dispose();
    super.dispose();
  }

  /// Stop all NRF tasks when leaving this screen so CC1101 (SubGhz)
  /// operations can resume without SPI bus contention.
  void _cleanupNrf() {
    try {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      if (bleProvider.isConnected) {
        final cmd = FirmwareBinaryProtocol.createNrfStopAllCommand();
        bleProvider.sendBinaryCommand(cmd);
      }
    } catch (_) {
      // Ignore errors during dispose — widget tree may be torn down
    }
  }

  // ── NRF Initialization ──────────────────────────────────────

  Future<void> _initNrf() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    if (!bleProvider.isConnected) return;

    setState(() => _initializing = true);

    try {
      final cmd = FirmwareBinaryProtocol.createNrfInitCommand();
      await bleProvider.sendBinaryCommand(cmd);
      await Future.delayed(const Duration(milliseconds: 500));
      bleProvider.nrfInitialized = true;
      bleProvider.notifyListeners();
      setState(() => _initializing = false);
    } catch (e) {
      setState(() {
        _initializing = false;
        _initFailed = true;
      });
    }
  }

  // ── MouseJack Commands ──────────────────────────────────────

  Future<void> _startScan() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfScanStartCommand();
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfScanning = true;
    bleProvider.notifyListeners();
  }

  Future<void> _stopScan() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfScanStopCommand();
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfScanning = false;
    bleProvider.notifyListeners();
  }

  Future<void> _attackString(int targetIndex) async {
    if (_stringController.text.isEmpty) return;
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfAttackStringCommand(
      targetIndex, _stringController.text,
    );
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfAttacking = true;
    bleProvider.notifyListeners();
  }

  Future<void> _attackDucky(int targetIndex) async {
    if (_duckyPathController.text.isEmpty) return;
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfAttackDuckyCommand(
      targetIndex, _duckyPathController.text,
    );
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfAttacking = true;
    bleProvider.notifyListeners();
  }

  Future<void> _stopAttack() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfAttackStopCommand();
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfAttacking = false;
    bleProvider.notifyListeners();
  }

  Future<void> _requestScanStatus() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfScanStatusCommand();
    await bleProvider.sendBinaryCommand(cmd);
  }

  // ── Spectrum Commands ───────────────────────────────────────

  Future<void> _startSpectrum() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfSpectrumStartCommand();
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfSpectrumRunning = true;
    bleProvider.notifyListeners();
  }

  Future<void> _stopSpectrum() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfSpectrumStopCommand();
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfSpectrumRunning = false;
    bleProvider.nrfSpectrumLevels = List.filled(126, 0);
    bleProvider.notifyListeners();
  }

  // ── Jammer Commands ─────────────────────────────────────────

  Future<void> _startJammer() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    Uint8List cmd;
    if (_jamMode == 8) {
      // Single channel mode
      cmd = FirmwareBinaryProtocol.createNrfJamStartCommand(
          _jamMode, channel: _jamChannel);
    } else if (_jamMode == 9) {
      // Custom hopper mode
      cmd = FirmwareBinaryProtocol.createNrfJamStartCommand(
          _jamMode, hopStart: _hopStart, hopStop: _hopStop, hopStep: _hopStep);
    } else {
      cmd = FirmwareBinaryProtocol.createNrfJamStartCommand(_jamMode);
    }
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfJammerRunning = true;
    bleProvider.notifyListeners();
  }

  Future<void> _stopJammer() async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    final cmd = FirmwareBinaryProtocol.createNrfJamStopCommand();
    await bleProvider.sendBinaryCommand(cmd);
    bleProvider.nrfJammerRunning = false;
    bleProvider.notifyListeners();
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        if (!bleProvider.isConnected) {
          return _buildNotConnected();
        }
        if (!bleProvider.nrfInitialized) {
          return _buildInitScreen();
        }
        return _buildMainScreen(bleProvider);
      },
    );
  }

  Widget _buildNotConnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: AppColors.disabledText),
          const SizedBox(height: 16),
          Text('Connect to device first',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInitScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.memory, size: 72, color: AppColors.primaryAccent),
          const SizedBox(height: 24),
          Text('nRF24L01 Module',
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('MouseJack / Spectrum / Jammer',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
          const SizedBox(height: 32),
          _initializing
              ? const CircularProgressIndicator(color: AppColors.primaryAccent)
              : ElevatedButton.icon(
                  onPressed: _initNrf,
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Initialize NRF24'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.primaryBackground,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                ),
          if (_initFailed && !_initializing)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('nRF24L01 module not detected',
                    style: TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainScreen(BleProvider bleProvider) {
    return Column(
      children: [
        Container(
          color: AppColors.secondaryBackground,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryAccent,
            labelColor: AppColors.primaryAccent,
            unselectedLabelColor: AppColors.secondaryText,
            tabs: const [
              Tab(icon: Icon(Icons.search), text: 'MouseJack'),
              Tab(icon: Icon(Icons.graphic_eq), text: 'Spectrum'),
              Tab(icon: Icon(Icons.wifi_tethering), text: 'Jammer'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMouseJackTab(bleProvider),
              _buildSpectrumTab(bleProvider),
              _buildJammerTab(bleProvider),
            ],
          ),
        ),
      ],
    );
  }

  // ── MouseJack Tab ───────────────────────────────────────────

  Widget _buildMouseJackTab(BleProvider bleProvider) {
    final allTargets = bleProvider.nrfTargets;
    final targets = _hideUnknown
        ? allTargets.where((t) {
            final code = t['deviceType'] ?? 0;
            return NrfTarget.typeFromCode(code) != 'Unknown';
          }).toList()
        : allTargets;
    final isScanning = bleProvider.nrfScanning;
    final isAttacking = bleProvider.nrfAttacking;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan controls
          _buildSectionCard(
            title: 'Scan',
            icon: Icons.radar,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isScanning ? _stopScan : _startScan,
                        icon: Icon(isScanning ? Icons.stop : Icons.play_arrow),
                        label: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isScanning
                              ? AppColors.error
                              : AppColors.primaryAccent,
                          foregroundColor: isScanning
                              ? Colors.white
                              : AppColors.primaryBackground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _requestScanStatus,
                      icon: const Icon(Icons.refresh,
                          color: AppColors.primaryAccent),
                      tooltip: 'Refresh targets',
                    ),
                  ],
                ),
                // Hide Unknown toggle
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 36,
                        child: Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: _hideUnknown,
                            onChanged: (v) => setState(() {
                              _hideUnknown = v;
                              _selectedTargetIndex = -1;
                            }),
                            activeColor: AppColors.primaryAccent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Hide Unknown',
                          style: TextStyle(
                              color: AppColors.secondaryText, fontSize: 12)),
                      if (_hideUnknown && allTargets.length != targets.length)
                        Text(
                          '  (${allTargets.length - targets.length} hidden)',
                          style: TextStyle(
                              color: AppColors.disabledText, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (isScanning)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      color: AppColors.primaryAccent,
                      backgroundColor:
                          AppColors.primaryAccent.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Targets list
          _buildSectionCard(
            title: 'Targets (${targets.length})',
            icon: Icons.devices,
            child: targets.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No devices found yet',
                        style: TextStyle(
                            color: AppColors.disabledText, fontSize: 13)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: targets.length,
                    itemBuilder: (ctx, idx) => _buildTargetTile(idx, targets),
                  ),
          ),
          const SizedBox(height: 12),

          // Attack controls (visible when target selected)
          if (_selectedTargetIndex >= 0 &&
              _selectedTargetIndex < targets.length)
            _buildAttackSection(isAttacking),
        ],
      ),
    );
  }

  Widget _buildTargetTile(int index, List<Map<String, dynamic>> targets) {
    final t = targets[index];
    final typeName = NrfTarget.typeFromCode(t['deviceType'] ?? 0);
    final channel = t['channel'] ?? 0;
    final address = t['address'] as List? ?? [];
    final addressHex = address.map((b) =>
        (b as int).toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
    final isSelected = _selectedTargetIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTargetIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent.withValues(alpha: 0.1)
              : AppColors.surfaceElevated,
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : AppColors.borderDefault,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              typeName == 'Microsoft' || typeName == 'MS Encrypted'
                  ? Icons.window
                  : typeName == 'Logitech'
                      ? Icons.keyboard
                      : Icons.device_unknown,
              color: AppColors.primaryAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeName,
                      style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold)),
                  Text('CH: $channel  Addr: $addressHex',
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primaryAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildAttackSection(bool isAttacking) {
    return _buildSectionCard(
      title: 'Attack',
      icon: Icons.bolt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // String injection
          Text('Inject Text',
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stringController,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    hintText: 'Text to inject...',
                    hintStyle: TextStyle(color: AppColors.disabledText),
                    filled: true,
                    fillColor: AppColors.primaryBackground,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isAttacking
                    ? null
                    : () => _attackString(_selectedTargetIndex),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.primaryBackground),
                child: const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // DuckyScript
          Text('DuckyScript',
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _duckyPathController,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    hintText: '/DATA/DUCKY/payload.txt',
                    hintStyle: TextStyle(color: AppColors.disabledText),
                    filled: true,
                    fillColor: AppColors.primaryBackground,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isAttacking
                    ? null
                    : () => _attackDucky(_selectedTargetIndex),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.primaryBackground),
                child: const Text('Run'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stop button
          if (isAttacking)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _stopAttack,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Attack'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // ── Spectrum Tab ────────────────────────────────────────────

  Widget _buildSpectrumTab(BleProvider bleProvider) {
    final spectrumRunning = bleProvider.nrfSpectrumRunning;
    final spectrumLevels = bleProvider.nrfSpectrumLevels;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: spectrumRunning ? _stopSpectrum : _startSpectrum,
                  icon: Icon(
                      spectrumRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(spectrumRunning ? 'Stop' : 'Start Analyzer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: spectrumRunning
                        ? AppColors.error
                        : AppColors.primaryAccent,
                    foregroundColor: spectrumRunning
                        ? Colors.white
                        : AppColors.primaryBackground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Frequency labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('2.400 GHz',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
              Text('2.462 GHz',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
              Text('2.525 GHz',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          // Spectrum bar chart
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                border: Border.all(color: AppColors.borderDefault),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: _SpectrumPainter(spectrumLevels),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CH 0',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 10)),
              Text('CH 25',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 10)),
              Text('CH 50',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 10)),
              Text('CH 75',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 10)),
              Text('CH 100',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 10)),
              Text('CH 125',
                  style: TextStyle(color: AppColors.disabledText, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Jammer Tab ──────────────────────────────────────────────

  Widget _buildJammerTab(BleProvider bleProvider) {
    final jammerRunning = bleProvider.nrfJammerRunning;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Legal disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For educational use only. Jamming may be illegal in your jurisdiction.',
                    style: TextStyle(color: AppColors.error, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mode selector
          _buildSectionCard(
            title: 'Mode',
            icon: Icons.tune,
            child: Column(
              children: [
                _buildModeOption(0, 'Full Spectrum', '1-124 channels', jammerRunning),
                _buildModeOption(1, 'WiFi', '2.4 GHz WiFi channels', jammerRunning),
                _buildModeOption(2, 'BLE', 'BLE data channels', jammerRunning),
                _buildModeOption(3, 'BLE Advertising', 'BLE advert channels', jammerRunning),
                _buildModeOption(4, 'Bluetooth', 'Classic BT channels', jammerRunning),
                _buildModeOption(5, 'USB Wireless', 'USB wireless channels', jammerRunning),
                _buildModeOption(6, 'Video Streaming', 'Video channels', jammerRunning),
                _buildModeOption(7, 'RC Controllers', 'RC channels', jammerRunning),
                _buildModeOption(8, 'Single Channel', 'One specific channel', jammerRunning),
                _buildModeOption(9, 'Custom Hopper', 'Custom range + step', jammerRunning),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Single channel config
          if (_jamMode == 8)
            _buildSectionCard(
              title: 'Channel',
              icon: Icons.radio,
              child: Column(
                children: [
                  Text('Channel: $_jamChannel (${2400 + _jamChannel} MHz)',
                      style: TextStyle(color: AppColors.primaryText)),
                  Slider(
                    value: _jamChannel.toDouble(),
                    min: 0,
                    max: 124,
                    divisions: 124,
                    activeColor: AppColors.primaryAccent,
                    onChanged: (v) =>
                        setState(() => _jamChannel = v.round()),
                  ),
                ],
              ),
            ),

          // Custom hopper config
          if (_jamMode == 9)
            _buildSectionCard(
              title: 'Hopper Config',
              icon: Icons.swap_horiz,
              child: Column(
                children: [
                  _buildSliderRow(
                      'Start', _hopStart, 0, 124,
                      (v) => setState(() => _hopStart = v.round())),
                  _buildSliderRow(
                      'Stop', _hopStop, 0, 124,
                      (v) => setState(() => _hopStop = v.round())),
                  _buildSliderRow(
                      'Step', _hopStep, 1, 10,
                      (v) => setState(() => _hopStep = v.round())),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Start/Stop button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: jammerRunning ? _stopJammer : _startJammer,
              icon: Icon(jammerRunning ? Icons.stop : Icons.play_arrow),
              label: Text(jammerRunning ? 'Stop Jammer' : 'Start Jammer'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    jammerRunning ? AppColors.error : AppColors.jamming,
                foregroundColor: AppColors.primaryBackground,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(int mode, String title, String subtitle, bool jammerRunning) {
    final isSelected = _jamMode == mode;
    return GestureDetector(
      onTap: jammerRunning ? null : () => setState(() => _jamMode = mode),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : AppColors.borderDefault,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primaryAccent : AppColors.disabledText,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(
      String label, int value, int min, int max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            activeColor: AppColors.primaryAccent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 30,
          child: Text('$value',
              style: TextStyle(color: AppColors.primaryText, fontSize: 12)),
        ),
      ],
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────

  Widget _buildSectionCard(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
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
}

// ── Spectrum bar-chart painter ────────────────────────────────────

class _SpectrumPainter extends CustomPainter {
  final List<int> levels;
  _SpectrumPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final barWidth = size.width / levels.length;
    const maxLevel = 125.0;

    for (int i = 0; i < levels.length; i++) {
      final level = levels[i].toDouble();
      final barHeight = (level / maxLevel) * size.height;
      final x = i * barWidth;

      // Gradient color depending on energy level
      final t = level / maxLevel;
      final color = Color.lerp(
        AppColors.primaryAccent.withValues(alpha: 0.4),
        AppColors.primaryAccent,
        t,
      )!;

      canvas.drawRect(
        Rect.fromLTWH(x, size.height - barHeight, barWidth - 1, barHeight),
        Paint()..color = color,
      );

      // Grid lines every 10 channels
      if (i % 10 == 0) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = AppColors.borderDefault.withValues(alpha: 0.5)
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
