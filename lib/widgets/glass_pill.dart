import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃胶囊 —— 双模自适应
///
/// 小尺寸玻璃表面，用于标签/按钮/Chip。轻材质（§12：小元素用更轻的玻璃）。
/// 简约风下退化为实色圆角胶囊。
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.borderRadius = 20,
    this.blurSigma,
    this.surfaceColor,
    this.selected = false,
    this.selectedColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? blurSigma;
  final Color? surfaceColor;
  final bool selected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTheme.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 简约风退化：实色胶囊
    if (!tokens.isEnabled) {
      final bg = selected
          ? (selectedColor ?? theme.colorScheme.primary)
          : (surfaceColor ??
              (isDark ? const Color(0xFF24242C) : const Color(0xFFF2F2F7)));
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      );
    }

    // 液态玻璃胶囊：轻材质（更小模糊）
    final blur = (blurSigma ?? tokens.blurSigma) * 0.6;
    final bg = selected
        ? (selectedColor ?? theme.colorScheme.primary).withValues(alpha: 0.85)
        : (surfaceColor ?? tokens.surfaceColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: tokens.borderColor, width: 0.5),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
