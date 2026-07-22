import 'package:flutter/material.dart';

import 'glass_tokens.dart';

/// 玻璃主题 InheritedWidget
///
/// 在 [`MaterialApp`](Trans-Prism/lib/main.dart:532) 上方注入，向下游暴露当前
/// [`GlassTokens`]。所有 `GlassXxx` 组件通过 [GlassTheme.of] 读取 Token，
/// 在 minimal 风格下自动退化为简约外观（`isEnabled == false`）。
///
/// 无障碍降级（§14）：当平台开启"减少透明度"时，自动用 [GlassTokens.toReducedTransparency]
/// 生成实心变体。
class GlassTheme extends InheritedWidget {
  const GlassTheme({
    super.key,
    required this.tokens,
    required super.child,
  });

  /// 当前生效的玻璃 Token（已按风格/亮暗/无障碍降级解析）。
  final GlassTokens tokens;

  /// 获取最近祖先的 [GlassTokens]。
  /// 若上游未注入，返回 [GlassTokens.minimalLight] 作为安全默认。
  static GlassTokens of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<GlassTheme>();
    return widget?.tokens ?? GlassTokens.minimalLight;
  }

  /// 是否当前处于液态玻璃模式（便捷判断）。
  static bool isEnabled(BuildContext context) => of(context).isEnabled;

  /// 模态遮罩色（用于 `showModalBottomSheet` / `showDialog` 的 barrierColor）。
  ///
  /// 液态玻璃模式下使用更浅的遮罩：[`LiquidGlassLens`] 的 BackdropFilter 会
  /// 采样"紧邻其后方"的像素，而模态路由的 barrier 恰好夹在 App 内容与 Sheet
  /// 之间。若 barrier 过暗（默认 `Colors.black54`），玻璃面会折射到暗 scrim，
  /// 导致整屏发暗、玻璃发脏。这里把液态模式 barrier 调浅，让玻璃能折射到真实
  /// App 内容；简约风退化为 Flutter 默认 `Colors.black54`。
  static Color modalBarrierColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return of(context).isEnabled
        ? Colors.black.withValues(alpha: isDark ? 0.35 : 0.22)
        : Colors.black54;
  }

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => tokens != oldWidget.tokens;
}
