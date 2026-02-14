import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Data model for a bruter protocol entry
class BruterProtocol {
  final int menuId;
  final String name;
  final String category;
  final double frequencyMhz;
  final int bits;
  final String encoding;
  final IconData icon;
  /// Timing element in microseconds (shortest pulse duration)
  final int te;
  /// Ratio of long pulse to short pulse (e.g. 3 means 1:3)
  final int ratio;

  const BruterProtocol({
    required this.menuId,
    required this.name,
    required this.category,
    required this.frequencyMhz,
    required this.bits,
    required this.encoding,
    required this.icon,
    this.te = 300,
    this.ratio = 3,
  });

  /// Whether this protocol uses De Bruijn mode (menu 35-40)
  bool get isDeBruijn => menuId >= 35 && menuId <= 40;

  /// Whether this protocol is compatible with De Bruijn attack.
  /// Requires binary encoding and n <= 16 bits.
  bool get deBruijnCompatible =>
      encoding == 'binary' && bits <= 16;

  /// Estimated time for full keyspace brute force
  /// Formula: keyspace * (delay_ms * repetitions + singleCodeTime_ms) / 1000
  /// Default: delay=10ms, repetitions=4, singleCodeTime≈2ms per repetition
  String estimatedTimeWithDelay(int delayMs) {
    // De Bruijn protocols are ~90x faster
    if (isDeBruijn) {
      return _estimatedTimeDeBruijn();
    }
    final keyspace = encoding.contains('tristate')
        ? _pow3(bits)
        : (1 << bits);
    // Each code: repetitions * (inter_frame_delay + ~2ms RF transmission time)
    const int repetitions = 4;
    const double singleTxMs = 2.0; // Approximate RF transmission time per repetition
    double totalPerCodeMs = repetitions * (delayMs + singleTxMs);
    double totalSeconds = keyspace * totalPerCodeMs / 1000.0;
    
    if (totalSeconds < 60) return '< 1 min';
    if (totalSeconds < 3600) return '~${(totalSeconds / 60).round()} min';
    if (totalSeconds < 86400) return '~${(totalSeconds / 3600).round()} hrs';
    return '~${(totalSeconds / 86400).round()} days';
  }

  /// Estimated time for De Bruijn attack (vastly faster)
  String _estimatedTimeDeBruijn() {
    if (menuId == 40) return '~3 min'; // Universal sweep: 96 configs × ~2s
    // B(2,n) sequence = n + 2^n - 1 bits, ~300µs per bit, 3-5 repeats
    final seqLen = bits + (1 << bits) - 1;
    const double usPerBit = 300.0; // Approximate OOK bit time
    const int repeats = 5;
    double totalSec = seqLen * usPerBit * repeats / 1e6;
    if (totalSec < 60) return '~${totalSec.round()} sec';
    return '~${(totalSec / 60).round()} min';
  }

  /// Legacy estimatedTime getter (uses default 10ms delay)
  String get estimatedTime => estimatedTimeWithDelay(10);

  int _pow3(int n) {
    int result = 1;
    for (int i = 0; i < n; i++) {
      result *= 3;
    }
    return result;
  }

  String get frequencyLabel {
    if (frequencyMhz == 433.92) return '433.92 MHz';
    if (frequencyMhz == 433.42) return '433.42 MHz';
    if (frequencyMhz == 868.35) return '868.35 MHz';
    if (frequencyMhz == 315.0) return '315 MHz';
    if (frequencyMhz == 318.0) return '318 MHz';
    if (frequencyMhz == 300.0) return '300 MHz';
    return '${frequencyMhz.toStringAsFixed(2)} MHz';
  }
}

/// All supported bruter protocols
const List<BruterProtocol> bruterProtocols = [
  // EU Garage Remotes
  BruterProtocol(menuId: 1, name: 'CAME', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 320, ratio: 2),
  BruterProtocol(menuId: 2, name: 'Princeton', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'tristate', icon: Icons.garage, te: 350, ratio: 3),
  BruterProtocol(menuId: 3, name: 'NiceFlo', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 700, ratio: 2),
  BruterProtocol(menuId: 6, name: 'Holtek', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 430, ratio: 2),
  BruterProtocol(menuId: 8, name: 'Ansonic', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 555, ratio: 2),
  BruterProtocol(menuId: 11, name: 'FAAC', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 400, ratio: 3),
  BruterProtocol(menuId: 12, name: 'BFT', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 400, ratio: 2),
  BruterProtocol(menuId: 13, name: 'SMC5326', category: 'EU Garage', frequencyMhz: 433.42, bits: 12, encoding: 'tristate', icon: Icons.garage, te: 320, ratio: 3),
  BruterProtocol(menuId: 14, name: 'Clemsa', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 400, ratio: 2),
  BruterProtocol(menuId: 15, name: 'GateTX', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 350, ratio: 2),
  BruterProtocol(menuId: 16, name: 'Phox', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 400, ratio: 2),
  BruterProtocol(menuId: 17, name: 'Phoenix V2', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 500, ratio: 2),
  BruterProtocol(menuId: 18, name: 'Prastel', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 400, ratio: 2),
  BruterProtocol(menuId: 19, name: 'Doitrand', category: 'EU Garage', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.garage, te: 400, ratio: 2),

  // US Garage Remotes
  BruterProtocol(menuId: 4, name: 'Chamberlain', category: 'US Garage', frequencyMhz: 315.0, bits: 12, encoding: 'binary', icon: Icons.door_sliding, te: 430, ratio: 2),
  BruterProtocol(menuId: 5, name: 'Linear', category: 'US Garage', frequencyMhz: 300.0, bits: 10, encoding: 'binary', icon: Icons.door_sliding, te: 500, ratio: 3),
  BruterProtocol(menuId: 7, name: 'LiftMaster', category: 'US Garage', frequencyMhz: 315.0, bits: 12, encoding: 'binary', icon: Icons.door_sliding, te: 400, ratio: 2),
  BruterProtocol(menuId: 23, name: 'Firefly', category: 'US Garage', frequencyMhz: 300.0, bits: 10, encoding: 'binary', icon: Icons.door_sliding, te: 400, ratio: 2),
  BruterProtocol(menuId: 24, name: 'Linear MegaCode', category: 'US Garage', frequencyMhz: 318.0, bits: 24, encoding: 'binary', icon: Icons.door_sliding, te: 500, ratio: 2),

  // Home Automation
  BruterProtocol(menuId: 20, name: 'Dooya', category: 'Home Auto', frequencyMhz: 433.92, bits: 24, encoding: 'binary', icon: Icons.blinds, te: 350, ratio: 2),
  BruterProtocol(menuId: 21, name: 'Nero', category: 'Home Auto', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.blinds, te: 450, ratio: 2),
  BruterProtocol(menuId: 22, name: 'Magellen', category: 'Home Auto', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.blinds, te: 400, ratio: 2),

  // Alarm / Sensors
  BruterProtocol(menuId: 9, name: 'EV1527', category: 'Alarm', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.security, te: 320, ratio: 3),
  BruterProtocol(menuId: 10, name: 'Honeywell', category: 'Alarm', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.security, te: 300, ratio: 2),
  BruterProtocol(menuId: 29, name: 'EV1527 24b', category: 'Alarm', frequencyMhz: 433.92, bits: 24, encoding: 'binary', icon: Icons.security, te: 320, ratio: 3),

  // 868 MHz
  BruterProtocol(menuId: 25, name: 'Hörmann', category: '868 MHz', frequencyMhz: 868.35, bits: 12, encoding: 'binary', icon: Icons.radio, te: 500, ratio: 2),
  BruterProtocol(menuId: 26, name: 'Marantec', category: '868 MHz', frequencyMhz: 868.35, bits: 12, encoding: 'binary', icon: Icons.radio, te: 600, ratio: 2),
  BruterProtocol(menuId: 27, name: 'Berner', category: '868 MHz', frequencyMhz: 868.35, bits: 12, encoding: 'binary', icon: Icons.radio, te: 400, ratio: 2),

  // Misc
  BruterProtocol(menuId: 28, name: 'Intertechno V3', category: 'Misc', frequencyMhz: 433.92, bits: 32, encoding: 'binary', icon: Icons.power, te: 250, ratio: 5),
  BruterProtocol(menuId: 30, name: 'StarLine', category: 'Misc', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.key, te: 500, ratio: 2),
  BruterProtocol(menuId: 31, name: 'Tedsen', category: 'Misc', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.key, te: 600, ratio: 2),
  BruterProtocol(menuId: 32, name: 'Airforce', category: 'Misc', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.key, te: 350, ratio: 3),
  BruterProtocol(menuId: 33, name: 'Unilarm', category: 'Misc', frequencyMhz: 433.42, bits: 12, encoding: 'binary', icon: Icons.key, te: 350, ratio: 3),
  BruterProtocol(menuId: 34, name: 'ELKA', category: 'Misc', frequencyMhz: 433.92, bits: 12, encoding: 'binary', icon: Icons.key, te: 400, ratio: 2),

  // De Bruijn protocols (~90x faster for binary ≤16 bits)
  BruterProtocol(menuId: 35, name: 'DeBruijn Generic 433', category: 'De Bruijn', frequencyMhz: 433.92, bits: 12, encoding: 'debruijn', icon: Icons.bolt, te: 300, ratio: 3),
  BruterProtocol(menuId: 36, name: 'DeBruijn Generic 315', category: 'De Bruijn', frequencyMhz: 315.0, bits: 12, encoding: 'debruijn', icon: Icons.bolt, te: 300, ratio: 3),
  BruterProtocol(menuId: 37, name: 'DeBruijn Holtek', category: 'De Bruijn', frequencyMhz: 433.92, bits: 12, encoding: 'debruijn', icon: Icons.bolt, te: 430, ratio: 2),
  BruterProtocol(menuId: 38, name: 'DeBruijn Linear', category: 'De Bruijn', frequencyMhz: 300.0, bits: 10, encoding: 'debruijn', icon: Icons.bolt, te: 500, ratio: 3),
  BruterProtocol(menuId: 39, name: 'DeBruijn EV1527', category: 'De Bruijn', frequencyMhz: 433.92, bits: 12, encoding: 'debruijn', icon: Icons.bolt, te: 320, ratio: 3),
  BruterProtocol(menuId: 40, name: 'Universal Sweep', category: 'De Bruijn', frequencyMhz: 433.92, bits: 12, encoding: 'debruijn', icon: Icons.radar, te: 300, ratio: 3),
];

/// Get unique category list preserving order
List<String> get bruterCategories {
  final seen = <String>{};
  final result = <String>[];
  for (final p in bruterProtocols) {
    if (seen.add(p.category)) {
      result.add(p.category);
    }
  }
  return result;
}

/// Brute force attack screen
class BruteScreen extends StatefulWidget {
  const BruteScreen({super.key});

  @override
  State<BruteScreen> createState() => _BruteScreenState();
}

/// Map from standard protocol menuId to its De Bruijn equivalent menuId.
/// NOTE: This map is kept for reference only. In De Bruijn mode, the app now
/// sends a custom 0xFD command with the protocol's own Te, ratio, bits, and
/// frequency — ensuring correct per-protocol timing and frequency.
/// The hardcoded De Bruijn menus (35-39) remain available as standalone entries.
// ignore: unused_element
const Map<int, int> _standardToDeBruijnMap = {
  // CAME, NiceFlo, FAAC, BFT, Clemsa, GateTX, Phox, PhoenixV2, Prastel,
  // Doitrand, Nero, Magellen, Ansonic, EV1527 12b, Honeywell, StarLine,
  // Tedsen, Airforce → DeBruijn Generic 433 (menu 35)
  1: 35, 3: 35, 8: 35, 9: 35, 10: 35, 11: 35, 12: 35,
  14: 35, 15: 35, 16: 35, 17: 35, 18: 35, 19: 35,
  21: 35, 22: 35, 30: 35, 31: 35, 32: 35, 34: 35,
  // Chamberlain, LiftMaster → DeBruijn Generic 315 (menu 36)
  4: 36, 7: 36,
  // Holtek → DeBruijn Holtek (menu 37)
  6: 37,
  // Linear, Firefly → DeBruijn Linear (menu 38)
  5: 38, 23: 38,
  // Hörmann, Marantec, Berner → DeBruijn Generic 433 (closest match at 868 via universal)
  25: 35, 26: 35, 27: 35,
};

class _BruteScreenState extends State<BruteScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _completionShown = false;
  /// When true, compatible protocols launch in De Bruijn mode (~90x faster)
  bool _useDeBruijnMode = false;

  List<BruterProtocol> get _filteredProtocols {
    var list = bruterProtocols.toList();

    // In De Bruijn mode, hide the dedicated De Bruijn entries and show
    // only standard protocols that are compatible (auto-mapped to DB).
    // In Standard mode, show all protocols including De Bruijn entries.
    if (_useDeBruijnMode) {
      list = list.where((p) => !p.isDeBruijn && p.deBruijnCompatible).toList();
    }

    if (_selectedCategory != 'All') {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.frequencyLabel.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BleProvider, SettingsProvider>(
      builder: (context, bleProvider, settingsProvider, child) {
        final isRunning = bleProvider.isBruterRunning;
        final activeProto = bleProvider.bruterActiveProtocol;
        final delayMs = settingsProvider.bruterDelayMs;

        // Show completion notification
        if (bleProvider.lastBruterCompletionStatus >= 0 && !_completionShown) {
          _completionShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final status = bleProvider.lastBruterCompletionStatus;
            final menuId = bleProvider.lastBruterCompletionMenuId;
            final protoName = bruterProtocols
                .where((p) => p.menuId == menuId)
                .map((p) => p.name)
                .firstOrNull ?? 'Unknown';
            
            final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
            final l10n = AppLocalizations.of(context)!;
            if (status == 0) {
              notificationProvider.showSuccess(l10n.bruteForceCompleted(protoName));
            } else if (status == 1) {
              notificationProvider.showInfo(l10n.bruteForceCancelled(protoName));
            } else {
              notificationProvider.showError(l10n.bruteForceErrorMsg(protoName));
            }
            bleProvider.clearBruterCompletion();
            _completionShown = false;
          });
        } else if (bleProvider.lastBruterCompletionStatus < 0) {
          _completionShown = false;
        }

        return Column(
          children: [
            // Unified attack banner (running OR paused state)
            if (isRunning || bleProvider.bruterSavedStateAvailable)
              _buildAttackBanner(context, bleProvider, isRunning, activeProto),

            // Category filter chips
            _buildCategoryFilter(),

            // Search bar
            _buildSearchBar(),

            // Standard / De Bruijn mode toggle
            _buildModeToggle(),

            // Protocol list
            Expanded(
              child: _filteredProtocols.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: _filteredProtocols.length,
                      itemBuilder: (context, index) {
                        final protocol = _filteredProtocols[index];
                        final isActive = isRunning && activeProto == protocol.menuId;
                        return _buildProtocolCard(context, bleProvider, protocol, isActive, isRunning, delayMs);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Unified banner for running, paused, and resumable attack states
  Widget _buildAttackBanner(BuildContext context, BleProvider bleProvider, bool isRunning, int activeProto) {
    final bool isPaused = !isRunning && bleProvider.bruterSavedStateAvailable;

    // Determine protocol name and progress values
    final int displayMenuId = isPaused ? bleProvider.bruterSavedMenuId : activeProto;
    final activeName = bruterProtocols
        .where((p) => p.menuId == displayMenuId)
        .map((p) => p.name)
        .firstOrNull ?? 'Protocol $displayMenuId';

    final isDeBruijn = displayMenuId >= 35 && displayMenuId <= 40;
    final unitLabel = isDeBruijn ? 'bits' : 'codes';
    final rateLabel = isDeBruijn ? 'b/s' : 'c/s';

    final int currentCode = isPaused ? bleProvider.bruterSavedCurrentCode : bleProvider.bruterCurrentCode;
    final int totalCodes = isPaused ? bleProvider.bruterSavedTotalCodes : bleProvider.bruterTotalCodes;
    final int percentage = isPaused ? bleProvider.bruterSavedPercentage : bleProvider.bruterPercentage;
    final int codesPerSec = isPaused ? 0 : bleProvider.bruterCodesPerSec;

    // Calculate ETA (only when running)
    String etaStr = '';
    if (isRunning && codesPerSec > 0 && totalCodes > currentCode) {
      final remainingCodes = totalCodes - currentCode;
      final remainingSecs = remainingCodes / codesPerSec;
      if (remainingSecs < 60) {
        etaStr = '< 1 min';
      } else if (remainingSecs < 3600) {
        etaStr = '~${(remainingSecs / 60).round()} min';
      } else {
        etaStr = '~${(remainingSecs / 3600).round()} hrs';
      }
    }

    // Colors based on state
    final Color bannerColor = isPaused ? Colors.blue : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isRunning)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(bannerColor),
                  ),
                )
              else
                Icon(Icons.pause_circle_outline, size: 20, color: bannerColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaused ? AppLocalizations.of(context)!.pausedProtocol(activeName) : AppLocalizations.of(context)!.bruteForceRunning(activeName),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: bannerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (totalCodes > 0)
                      Text(
                        '$currentCode / $totalCodes $unitLabel ($percentage%)'
                        '${codesPerSec > 0 ? ' · $codesPerSec $rateLabel' : ''}'
                        '${etaStr.isNotEmpty ? ' · ETA: $etaStr' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: bannerColor.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // PAUSE / RESUME toggle button
              ElevatedButton.icon(
                onPressed: isPaused
                    ? () => _resumeAttack(context, bleProvider)
                    : () => _pauseAttack(context, bleProvider),
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                label: Text(isPaused ? AppLocalizations.of(context)!.bruteResume : AppLocalizations.of(context)!.brutePause),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaused ? Colors.blue : AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _cancelAttack(context, bleProvider),
                icon: const Icon(Icons.stop, size: 18),
                label: Text(AppLocalizations.of(context)!.bruteStop),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalCodes > 0 ? currentCode / totalCodes : null,
              backgroundColor: bannerColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(bannerColor),
              minHeight: 6,
            ),
          ),
          if (isPaused) ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.resumeInfo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: bannerColor.withValues(alpha: 0.6),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', ...bruterCategories];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
              },
              selectedColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primaryAccent : AppColors.borderDefault,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchProtocols,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 16, color: AppColors.secondaryText),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.attackMode,
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text(AppLocalizations.of(context)!.standardMode, style: const TextStyle(fontSize: 11)),
                icon: const Icon(Icons.linear_scale, size: 14),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text(AppLocalizations.of(context)!.deBruijnMode, style: const TextStyle(fontSize: 11)),
                icon: const Icon(Icons.bolt, size: 14, color: Color(0xFFFFE600)),
              ),
            ],
            selected: {_useDeBruijnMode},
            onSelectionChanged: (selected) {
              setState(() => _useDeBruijnMode = selected.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ),
          ),
          if (_useDeBruijnMode) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: AppLocalizations.of(context)!.deBruijnTooltip,
              child: Icon(Icons.info_outline, size: 14, color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.disabledText),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noProtocolsFound,
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(
    BuildContext context,
    BleProvider bleProvider,
    BruterProtocol protocol,
    bool isActive,
    bool isAnyRunning,
    int delayMs,
  ) {
    // Vivid yellow tint for DeBruijn protocol cards
    final bool isDeBruijnCard = protocol.isDeBruijn && !isActive;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isActive
          ? AppColors.warning.withValues(alpha: 0.08)
          : isDeBruijnCard
              ? const Color(0xFFFFE600).withValues(alpha: 0.10)
              : AppColors.secondaryBackground,
      shape: isDeBruijnCard
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: Color(0xAAFFE600), width: 1.0),
            )
          : null,
      child: InkWell(
        onTap: isAnyRunning ? null : () => _confirmAndStart(context, bleProvider, protocol),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Protocol icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : protocol.isDeBruijn
                          ? const Color(0xFFFFE600).withValues(alpha: 0.18)
                          : AppColors.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  protocol.icon,
                  size: 20,
                  color: isActive
                      ? AppColors.warning
                      : protocol.isDeBruijn
                          ? const Color(0xFFFFE600) // Bright yellow for DeBruijn protocols
                          : AppColors.primaryAccent,
                ),
              ),
              const SizedBox(width: 12),

              // Protocol info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            protocol.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.warning
                                  : protocol.isDeBruijn
                                      ? const Color(0xFFFFE600) // Bright yellow for DeBruijn
                                      : AppColors.primaryText,
                            ),
                          ),
                        ),
                        // Frequency badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getFrequencyColor(protocol.frequencyMhz).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            protocol.frequencyLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _getFrequencyColor(protocol.frequencyMhz),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${protocol.bits}-bit ${protocol.encoding} · ${protocol.estimatedTimeWithDelay(delayMs)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        // De Bruijn compatibility badge for standard protocols
                        if (!protocol.isDeBruijn && protocol.deBruijnCompatible)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.deBruijnCompatible,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action indicator
              if (isActive)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                  ),
                )
              else if (!isAnyRunning)
                Icon(
                  Icons.play_arrow,
                  size: 20,
                  color: AppColors.primaryAccent.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFrequencyColor(double mhz) {
    if (mhz >= 868) return Colors.deepPurple;
    if (mhz >= 433) return AppColors.primaryAccent;
    if (mhz >= 315) return Colors.teal;
    return Colors.orange;
  }

  Future<void> _confirmAndStart(
    BuildContext context,
    BleProvider bleProvider,
    BruterProtocol protocol,
  ) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final delayMs = settingsProvider.bruterDelayMs;

    // Determine if we should use custom De Bruijn (per-protocol timing/freq)
    // instead of hardcoded De Bruijn menus which have fixed frequencies.
    bool useCustomDeBruijn = false;
    int actualMenuId = protocol.menuId;
    String modeSuffix = '';
    if (_useDeBruijnMode && !protocol.isDeBruijn && protocol.deBruijnCompatible) {
      useCustomDeBruijn = true;
      modeSuffix = ' (DeBruijn)';
    }

    final estTime = protocol.estimatedTimeWithDelay(delayMs);

    // Show confirmation dialog with protocol details
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.startBruteForceSuffix(modeSuffix)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(AppLocalizations.of(context)!.protocol, '${protocol.name}$modeSuffix'),
            _infoRow(AppLocalizations.of(context)!.frequency, protocol.frequencyLabel),
            _infoRow(AppLocalizations.of(context)!.keySpace, '${protocol.bits}-bit ${protocol.encoding}'),
            if (modeSuffix.isNotEmpty)
              _infoRow(AppLocalizations.of(context)!.modeLabel, AppLocalizations.of(context)!.deBruijnFaster),
            _infoRow(AppLocalizations.of(context)!.delay, '$delayMs ms'),
            _infoRow(AppLocalizations.of(context)!.estTime, estTime),
            const SizedBox(height: 12),
            if (protocol.bits >= 24)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.largeKeyspaceWarning(protocol.bits, estTime),
                        style: TextStyle(color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.deviceWillTransmit,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text(AppLocalizations.of(context)!.start),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      if (useCustomDeBruijn) {
        // Send custom De Bruijn command with per-protocol timing and frequency
        await bleProvider.sendCustomDeBruijnCommand(
          bits: protocol.bits,
          te: protocol.te,
          ratio: protocol.ratio,
          frequencyMhz: protocol.frequencyMhz,
        );
      } else {
        await bleProvider.sendBruterCommand(actualMenuId);
      }

      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showSuccess(
          AppLocalizations.of(context)!.bruteForceStarted('${protocol.name}$modeSuffix'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError(AppLocalizations.of(context)!.failedToStart('$e'));
      }
    }
  }

  Future<void> _pauseAttack(BuildContext context, BleProvider bleProvider) async {
    try {
      await bleProvider.sendBruterPauseCommand();

      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showInfo(AppLocalizations.of(context)!.bruteForcePausing);
      }
    } catch (e) {
      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError(AppLocalizations.of(context)!.failedToPause('$e'));
      }
    }
  }

  Future<void> _resumeAttack(BuildContext context, BleProvider bleProvider) async {
    try {
      await bleProvider.sendBruterResumeCommand();

      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showSuccess(AppLocalizations.of(context)!.bruteForceResumed);
      }
    } catch (e) {
      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError(AppLocalizations.of(context)!.failedToResume('$e'));
      }
    }
  }

  Future<void> _discardSavedState(BuildContext context, BleProvider bleProvider) async {
    // Discard the saved state by sending a cancel (which clears LittleFS state)
    try {
      await bleProvider.sendBruterCancelCommand();

      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showInfo(AppLocalizations.of(context)!.savedStateDiscarded);
      }
    } catch (e) {
      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError(AppLocalizations.of(context)!.failedToDiscard('$e'));
      }
    }
  }

  Future<void> _cancelAttack(BuildContext context, BleProvider bleProvider) async {
    try {
      await bleProvider.sendBruterCancelCommand();

      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showSuccess(AppLocalizations.of(context)!.bruteForceStopped);
      }
    } catch (e) {
      if (context.mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError(AppLocalizations.of(context)!.failedToStop('$e'));
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
