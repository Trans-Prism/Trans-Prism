import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃 BottomSheet 容器 —— 双模自适应
///
/// 用于包装 `showModalBottomSheet` 的 builder 内容。提供：
/// - 拖拽条 + 顶部圆角玻璃面（液态模式，由 [`LiquidGlassLens`] 接管折射/模糊）
/// - 简约风退化：实色圆角顶 Sheet（与既有 [`bottomSheetTheme`](Trans-Prism/lib/main.dart:494) 一致）
///
/// 用法：
/// ```dart
/// showModalBottomSheet(
///   backgroundColor: Colors.transparent,
///   builder: (_) => GlassSheet(child: ...),
/// );
/// ```
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.title,
    this.blurSigma,
    this.surfaceColor,
    this.topRadius = 24,
    this.showGrabHandle = true,
  });

  final Widget child;
  final Widget? title;
  final double? blurSigma;
  final Color? surfaceColor;
  final double topRadius;
  final bool showGrabHandle;

  @override
  Widget build(BuildContext context) {
    var tokens = GlassTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 简约风退化：实色 Sheet
    if (!tokens.isEnabled) {
      return Container(
        decoration: BoxDecoration(
          color:
              surfaceColor ?? (isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        ),
        child: _content(context),
      );
    }

    if (MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }

    // 液态玻璃 Sheet
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;

    final style = tokens.toLiquidGlassStyle(cornerRadius: topRadius).copyWith(
          appearance: LiquidGlassAppearance(
            color: bg,
            saturation: tokens.saturationBoost.clamp(0.0, 3.0),
            blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
          ),
        );

    return RepaintBoundary(
      child: LiquidGlassLens(
        style: style,
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showGrabHandle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DefaultTextStyle.merge(
              style:
                  Theme.of(context).textTheme.titleLarge ?? const TextStyle(),
              child: title!,
            ),
          ),
        child,
        const SizedBox(height: 24),
      ],
    );
  }
}
