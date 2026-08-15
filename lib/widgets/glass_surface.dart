import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_theme.dart';

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

    // 简约风：实色 Material（背景承载于 Material 上）
    // 若把背景色放在内层 Container（DecoratedBox）上，子级 ListTile 的
    // _debugCheckBackgroundIsHidden 会在"最近 Material 之前"撞见该带背景容器，
    // 断言报 "ListTile background color or ink splashes may be invisible"；
    // 且 InkWell 波纹绘制在 Material 上也会被内层背景遮挡。故背景必须上移。
    if (!tokens.isEnabled) {
      final bg =
          solidColor ?? (isDark ? const Color(0xFF24242C) : Colors.white);
      return Material(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
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
    // solidColor 语义在液态下同样生效：简约风"实色"（alpha==1）以
    // tokens.surfaceColor 的 alpha 掺入玻璃表面色，使"选中/实色"在液态下清晰
    // 可辨（否则被忽略——如工作台分类胶囊选中态深灰底不生效，白字落在白玻璃上
    // 对比度不足）；调用方已传半透明色（alpha<1，如 10% 白/15% 品红）则尊重其
    // 原 alpha。与 GlassCard 液态分支的 appearance 注入方式保持一致。
    final sc = solidColor;
    final glassColor = sc != null
        ? (sc.a >= 1.0 ? sc.withValues(alpha: tokens.surfaceColor.a) : sc)
        : tokens.surfaceColor;
    final style =
        tokens.toLiquidGlassStyle(cornerRadius: borderRadius).copyWith(
              appearance: LiquidGlassAppearance(
                color: glassColor,
                saturation: tokens.saturationBoost.clamp(0.0, 3.0),
                blur: LiquidGlassBlur(
                  sigmaX: tokens.blurSigma,
                  sigmaY: tokens.blurSigma,
                ),
              ),
            );
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
