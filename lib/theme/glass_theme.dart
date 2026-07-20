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

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => tokens != oldWidget.tokens;
}
