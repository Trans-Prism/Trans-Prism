import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

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
    var tokens = GlassTheme.of(context);
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

    if (MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }

    // 液态玻璃胶囊：轻材质（更小模糊，§12）
    final blur = (blurSigma ?? tokens.blurSigma) * 0.6;
    final bg = selected
        ? (selectedColor ?? theme.colorScheme.primary).withValues(alpha: 0.85)
        : (surfaceColor ?? tokens.surfaceColor);

    final style =
        tokens.toLiquidGlassStyle(cornerRadius: borderRadius).copyWith(
              appearance: LiquidGlassAppearance(
                color: bg,
                saturation: tokens.saturationBoost.clamp(0.0, 3.0),
                blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
              ),
            );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: LiquidGlassLens(
          style: style,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
