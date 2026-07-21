import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃 AppBar —— 双模自适应
///
/// - **液态玻璃模式**：全宽玻璃栏，由 [`LiquidGlassLens`] 接管折射/模糊/
///   光学边框（Impeller 独立采样实时背景，内容从其下滚动透出）。
///   保持全宽 edge-to-edge 布局，与简约风栏位置一致。
/// - **简约风模式**：退化为与 [`appBarTheme`](Trans-Prism/lib/main.dart:129)
///   一致的实色 [`AppBar`]。
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
    var tokens = GlassTheme.of(context);
    if (tokens.isEnabled && MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }

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

    // 液态玻璃：全宽玻璃栏
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    final style = tokens.toLiquidGlassStyle(cornerRadius: 0).copyWith(
          appearance: LiquidGlassAppearance(
            color: bg,
            saturation: tokens.saturationBoost.clamp(0.0, 3.0),
            blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
          ),
        );

    return RepaintBoundary(
      child: LiquidGlassLens(
        style: style,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: toolbarHeight,
            child: NavigationToolbar(
              leading: leading,
              middle: DefaultTextStyle.merge(
                style: TextStyle(
                  color: fg,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
                child: title ?? const SizedBox.shrink(),
              ),
              trailing: actions != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    )
                  : null,
              centerMiddle: centerTitle,
              middleSpacing: 16,
            ),
          ),
        ),
      ),
    );
  }
}
