import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Hacker-style button
class HackerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;
  final bool isExpanded;

  const HackerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.icon,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
            foregroundColor: AppColors.primaryBackground,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: GoogleFonts.inter().fontFamily,
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryText,
            side: const BorderSide(color: AppColors.borderDefault, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: GoogleFonts.inter().fontFamily,
            ),
          );

    final button = icon != null
        ? (isPrimary
            ? ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: buttonStyle as ButtonStyle?,
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: buttonStyle as ButtonStyle?,
              ))
        : (isPrimary
            ? ElevatedButton(
                onPressed: onPressed,
                style: buttonStyle as ButtonStyle?,
                child: Text(label),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: buttonStyle as ButtonStyle?,
                child: Text(label),
              ));

    return isExpanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Hacker-style input field
class HackerTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputType? keyboardType;
  final int? maxLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  const HackerTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: AppColors.primaryText,
        fontSize: 14,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.secondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderFocus, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: AppColors.borderDefault.withOpacity(0.4),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: TextStyle(
          color: AppColors.disabledText,
          fontSize: 14,
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        labelStyle: TextStyle(
          color: AppColors.secondaryText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
      ),
    );
  }
}

/// Hacker-style card
class HackerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showBorder;

  const HackerCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: showBorder
            ? Border.all(color: AppColors.borderDefault, width: 1)
            : null,
      ),
      padding: padding ?? const EdgeInsets.all(12),
      child: child,
    );
  }
}

/// Status indicator with color
class StatusIndicator extends StatelessWidget {
  final String status;
  final String? label;
  final double size;

  const StatusIndicator({
    super.key,
    required this.status,
    this.label,
    this.size = 8,
  });

  Color _getStatusColor(String status) {
    return AppColors.getModuleStatusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    final indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: 6),
          Text(
            label!,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: GoogleFonts.inter().fontFamily,
            ),
          ),
        ],
      );
    }

    return indicator;
  }
}

/// Module status indicator with ring
class ModuleStatusRing extends StatelessWidget {
  final String status;
  final Widget child;
  final double ringSize;

  const ModuleStatusRing({
    super.key,
    required this.status,
    required this.child,
    this.ringSize = 24,
  });

  Color _getStatusColor(String status) {
    return AppColors.getModuleStatusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(child: child),
    );
  }
}

