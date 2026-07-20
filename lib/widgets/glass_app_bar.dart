import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃 AppBar —— 双模自适应
///
/// - **液态玻璃模式**：透明背景 + `BackdropFilter`，内容从其下滚动透出；
///   底部用渐变蒙版做"滚动边缘效果"（§12 Scroll edge effects）替代 1px 分隔线。
/// - **简约风模式**：退化为与 [`appBarTheme`](Trans-Prism/lib/main.dart:129)
///   一致的实色 AppBar。
///
/// 用法：在 `Scaffold.appBar` 处用 `GlassAppBar(title: ...)` 替代 `AppBar(...)`。
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.toolbarHeight = kToolbarHeight,
    this.blurSigma,
    this.surfaceColor,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double toolbarHeight;
  final double? blurSigma;
  final Color? surfaceColor;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTheme.of(context);

    // 简约风退化：直接用主题 AppBar 的实色外观
    if (!tokens.isEnabled) {
      return AppBar(
        title: title,
        leading: leading,
        actions: actions,
        centerTitle: centerTitle,
        toolbarHeight: toolbarHeight,
      );
    }

    // 液态玻璃：浮动半透明 + 模糊 + 底部渐变边缘
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;

    return PreferredSize(
      preferredSize: preferredSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 0.5,
              color: Colors.white
                  .withValues(alpha: tokens.highlightEdgeAlpha * 0.6),
            ),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                // 底部渐变蒙版：内容接触浮动 chrome 处淡出（§12）
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: toolbarHeight,
                  child: NavigationToolbar(
                    leading: leading,
                    middle: title,
                    trailing: actions != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min, children: actions!)
                        : null,
                    centerMiddle: centerTitle,
                    middleSpacing: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
