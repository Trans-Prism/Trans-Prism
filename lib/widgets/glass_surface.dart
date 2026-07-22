import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_theme.dart';
import '../theme/glass_tokens.dart';

/// 通用玻璃表面包装器 —— 双模自适应。
///
/// 用于把业务页中既有的实色卡片 `Container(decoration: BoxDecoration(color:
/// cardColor, borderRadius, border))` 一行替换为玻璃化容器：
/// - **液态玻璃模式**：由 [`LiquidGlassLens`] 接管折射/模糊/光学边框
///   （Impeller 独立采样实时背景），外层轻阴影。
/// - **简约风模式**：实色 `Container`（传入的 [solidColor] / [borderColor]），
///   与既有外观像素级一致。
///
/// 用法：
/// ```dart
/// GlassSurface(
///   solidColor: cardColor,        // 简约风底色
///   borderColor: borderColor,     // 简约风边框
///   borderRadius: 16,
///   padding: EdgeInsets.all(16),
///   onTap: onTap,
///   child: ...,
/// )
/// ```
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.solidColor,
    this.borderColor,
    this.borderRadius = 16,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.shadow = true,
  });

  final Widget child;
  final Color? solidColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    var tokens = GlassTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (tokens.isEnabled && MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }

    // 简约风：实色 Container
    if (!tokens.isEnabled) {
      final bg =
          solidColor ?? (isDark ? const Color(0xFF24242C) : Colors.white);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 0.5)
                  : null,
            ),
            child: child,
          ),
        ),
      );
    }

    // 液态玻璃：LiquidGlassLens + 轻阴影
    final style = tokens.toLiquidGlassStyle(cornerRadius: borderRadius);
    final radius = BorderRadius.circular(borderRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: RepaintBoundary(
          child: DecoratedBox(
            // 阴影渲染在裁剪之外，不会被裁掉（修复 GlassCard 阴影被裁问题）。
            decoration: shadow
                ? BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.shadowColor,
                        blurRadius: tokens.shadowBlur,
                        offset: tokens.shadowOffset,
                      ),
                    ],
                  )
                : const BoxDecoration(),
            child: ClipRRect(
              // 关键：把 LiquidGlassLens 的 BackdropFilter 采样矩形裁剪到
              // 圆角边界内，消除"半透明矩形溢出伪影"——玻璃面不再溢出圆角。
              borderRadius: radius,
              child: LiquidGlassLens(
                style: style,
                child: padding != null
                    ? Padding(padding: padding!, child: child)
                    : child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
