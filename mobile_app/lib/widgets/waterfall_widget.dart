import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A single data point for the waterfall display.
class WaterfallEntry {
  final DateTime timestamp;
  final double frequencyMhz;
  final int rssi; // typically –100 … 0 dBm
  final int module;

  const WaterfallEntry({
    required this.timestamp,
    required this.frequencyMhz,
    required this.rssi,
    required this.module,
  });
}

/// Real-time signal-activity waterfall / spectrogram widget.
///
/// Vertical axis = time (newest at bottom), horizontal axis = frequency,
/// colour = RSSI strength. Each detection is painted as a small rectangle
/// whose colour goes from blue (weak, ≤ –70 dBm) through green/yellow to
/// red (strong, ≥ –25 dBm).
class WaterfallWidget extends StatelessWidget {
  /// The list of detection events to display.
  final List<WaterfallEntry> entries;

  /// Height of the rendered area.
  final double height;

  /// Whether the device is currently recording / searching.
  final bool isLive;

  /// If provided, only entries for this module are drawn.
  final int? filterModule;

  const WaterfallWidget({
    super.key,
    required this.entries,
    this.height = 160,
    this.isLive = false,
    this.filterModule,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filterModule != null
        ? entries.where((e) => e.module == filterModule).toList()
        : entries;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive
              ? AppColors.success.withValues(alpha: 0.6)
              : AppColors.borderDefault.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: filtered.isEmpty
            ? Center(
                child: Text(
                  isLive ? 'Waiting for signals…' : 'No signal data',
                  style: TextStyle(
                    color: AppColors.secondaryText.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              )
            : CustomPaint(
                painter: _WaterfallPainter(
                  entries: filtered,
                  isLive: isLive,
                ),
                size: Size.infinite,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _WaterfallPainter extends CustomPainter {
  final List<WaterfallEntry> entries;
  final bool isLive;

  _WaterfallPainter({required this.entries, required this.isLive});

  /// Map RSSI (dBm) to a colour.
  /// –80 dBm → deep blue (very weak)
  /// –50 dBm → green / cyan
  /// –30 dBm → yellow
  /// –15 dBm → red (very strong)
  Color _rssiColor(int rssi) {
    // Clamp to useful range
    final clamped = rssi.clamp(-80, -15).toDouble();
    // Normalise 0 … 1 (0 = weak, 1 = strong)
    final t = (clamped + 80) / 65.0;

    if (t < 0.33) {
      // blue → cyan
      return Color.lerp(
          const Color(0xFF0D47A1), const Color(0xFF00BCD4), t / 0.33)!;
    } else if (t < 0.66) {
      // cyan → yellow
      return Color.lerp(const Color(0xFF00BCD4), const Color(0xFFFFEB3B),
          (t - 0.33) / 0.33)!;
    } else {
      // yellow → red
      return Color.lerp(
          const Color(0xFFFFEB3B), const Color(0xFFFF1744), (t - 0.66) / 0.34)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    // ── Determine axis ranges ──
    double minFreq = double.infinity;
    double maxFreq = double.negativeInfinity;
    DateTime earliest = entries.first.timestamp;
    DateTime latest = entries.first.timestamp;

    for (final e in entries) {
      if (e.frequencyMhz < minFreq) minFreq = e.frequencyMhz;
      if (e.frequencyMhz > maxFreq) maxFreq = e.frequencyMhz;
      if (e.timestamp.isBefore(earliest)) earliest = e.timestamp;
      if (e.timestamp.isAfter(latest)) latest = e.timestamp;
    }

    // Add small padding so single-frequency data still has width
    if ((maxFreq - minFreq).abs() < 0.5) {
      minFreq -= 1.0;
      maxFreq += 1.0;
    }

    // Time window: at least 10 seconds so we don't zoom into nothing
    final durationMs = math.max(
      latest.difference(earliest).inMilliseconds.toDouble(),
      10000.0,
    );

    final freqRange = maxFreq - minFreq;
    const double dotH = 4.0; // height of each signal dot (pixels)
    const double dotMinW = 6.0; // minimum width

    // ── Draw grid lines + labels ──
    final gridPaint = Paint()..color = Colors.white10;
    final labelStyle = TextStyle(
      color: Colors.white24,
      fontSize: 9,
      fontFamily: 'monospace',
    );

    // Horizontal time gridlines (every ~20% of height)
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Frequency labels at top
    _drawText(canvas, '${minFreq.toStringAsFixed(1)}', Offset(2, 2), labelStyle);
    _drawText(canvas, '${maxFreq.toStringAsFixed(1)} MHz',
        Offset(size.width - 70, 2), labelStyle);

    // ── Draw entries ──
    for (final entry in entries) {
      final tNorm =
          (entry.timestamp.difference(earliest).inMilliseconds) / durationMs;
      final fNorm = (entry.frequencyMhz - minFreq) / freqRange;

      final x = fNorm * (size.width - dotMinW);
      final y = tNorm * (size.height - dotH);

      final color = _rssiColor(entry.rssi);
      final paint = Paint()..color = color;

      // Width proportional to RSSI (stronger = wider glow)
      final strength = ((entry.rssi + 80) / 65.0).clamp(0.15, 1.0);
      final w = dotMinW + strength * 14;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, dotH),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    // ── Live indicator ──
    if (isLive) {
      final livePaint = Paint()
        ..color = AppColors.success
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(0, size.height - 1),
        Offset(size.width, size.height - 1),
        livePaint,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter old) {
    return entries.length != old.entries.length || isLive != old.isLive;
  }
}
