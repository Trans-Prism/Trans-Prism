import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃 BottomSheet 容器 —— 双模自适应
///
/// 用于包装 `showModalBottomSheet` 的 builder 内容。提供：
/// - 拖拽条 + 顶部高光边 + 背景模糊（液态模式）
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
    final tokens = GlassTheme.of(context);
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

    // 液态玻璃 Sheet
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: tokens.borderColor, width: 0.5),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(topRadius)),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(topRadius)),
            border: Border(
              top: BorderSide(
                width: 1,
                color:
                    Colors.white.withValues(alpha: tokens.highlightEdgeAlpha),
              ),
            ),
          ),
          child: _content(context),
        ),
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
