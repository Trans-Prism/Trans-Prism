import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃对话框容器 —— 双模自适应
///
/// 用于包装 `showDialog` 的 builder 内容。提供：
/// - 半透明 + 模糊 + 顶部高光边 + 阴影（液态模式）
/// - 简约风退化：实色圆角对话框（与既有 [`dialogTheme`](Trans-Prism/lib/main.dart:325) 一致）
///
/// 用法：
/// ```dart
/// showDialog(
///   builder: (_) => GlassDialog(child: ...),
/// );
/// ```
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.child,
    this.blurSigma,
    this.surfaceColor,
    this.radius = 20,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final double? blurSigma;
  final Color? surfaceColor;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 简约风退化：实色对话框
    if (!tokens.isEnabled) {
      return Container(
        decoration: BoxDecoration(
          color:
              surfaceColor ?? (isDark ? const Color(0xFF24242C) : Colors.white),
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: padding,
        child: child,
      );
    }

    // 液态玻璃对话框
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowColor,
                blurRadius: tokens.shadowBlur,
                offset: tokens.shadowOffset,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: tokens.borderColor, width: 0.5),
                  borderRadius: BorderRadius.circular(radius),
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border(
                    top: BorderSide(
                      width: 1,
                      color: Colors.white.withValues(
                        alpha: tokens.highlightEdgeAlpha,
                      ),
                    ),
                  ),
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
