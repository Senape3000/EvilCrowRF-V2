import 'package:flutter/material.dart';

/// Centralized color system — Matrix green dark theme
/// Palette derived from Logo_App.png (89% pure green, hue 120°)
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ========== Background (dark with subtle green tint) ==========
  static const Color primaryBackground = Color(0xFF040804); // Deep black, green tint
  static const Color secondaryBackground = Color(0xFF081008); // Panels, cards (darker)
  static const Color surfaceElevated = Color(0xFF0E1A0E); // Elements above cards (darker)

  // ========== Text ==========
  static const Color primaryText = Color(0xFFD4EED4); // Soft green-white
  static const Color secondaryText = Color(0xFF7A9E7A); // Muted green
  static const Color disabledText = Color(0xFF3E5E3E); // Disabled elements

  // ========== Accent (Matrix green) ==========
  static const Color primaryAccent = Color(0xFF00E676); // Bright Matrix green
  static const Color accentHover = Color(0xFF69F0AE); // On hover — lighter
  static const Color accentPressed = Color(0xFF00C853); // On press — deeper

  // ========== Statuses ==========
  static const Color success = Color(0xFF00E676); // Ready, success
  static const Color warning = Color(0xFFFFD600); // Warning, in progress
  static const Color error = Color(0xFFFF1744); // Error, critical
  static const Color info = Color(0xFF00E676); // Info (green)

  // ========== RF module specific ==========
  static const Color recording = Color(0xFFFF1744); // Signal recording (red)
  static const Color transmitting = Color(0xFF00E676); // Transmitting (green)
  static const Color jamming = Color(0xFFFFD600); // Jamming (yellow)
  static const Color idle = Color(0xFF69F0AE); // Ready (light green)
  static const Color searching = Color(0xFF39FF14); // Frequency scanning (neon green)

  // ========== Borders ==========
  static const Color borderDefault = Color(0xFF1B3A1B);
  static const Color borderFocus = Color(0xFF00E676);
  static const Color divider = Color(0xFF1A2A1A);

  // ========== Logs / Console ==========
  static const Color logBackground = Color(0xFF020A02);
  static const Color logText = Color(0xFF00FF41); // Classic Matrix green
  static const Color logError = Color(0xFFFF1744);
  static const Color logSystem = Color(0xFF00E676);
  static const Color logUserInput = Color(0xFFD4EED4);

  // ========== Colors for Material ColorScheme ==========
  
  /// Get ColorScheme for dark theme
  static ColorScheme get darkColorScheme {
    return const ColorScheme.dark(
      primary: primaryAccent,
      onPrimary: primaryBackground,
      secondary: primaryAccent,
      onSecondary: primaryBackground,
      error: error,
      onError: primaryText,
      surface: secondaryBackground,
      onSurface: primaryText,
      surfaceContainerHighest: surfaceElevated,
      outline: borderDefault,
      outlineVariant: divider,
    );
  }

  /// Get color for module status
  static Color getModuleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return idle;
      case 'recordsignal':
      case 'recording':
        return recording;
      case 'sendsignal':
      case 'transmitting':
        return transmitting;
      case 'jamming':
        return jamming;
      case 'detectsignal':
      case 'searching':
        return searching;
      default:
        return secondaryText;
    }
  }
}

