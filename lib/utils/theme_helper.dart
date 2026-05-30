import 'package:flutter/material.dart';

/// 主题辅助工具，方便在屏幕中获取暗色模式下的适配颜色
class ThemeHelper {
  final BuildContext context;

  ThemeHelper(this.context);

  /// 是否暗色模式
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  /// 主文字色
  Color get textColor =>
      isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

  /// 次级文字色
  Color get secondaryText =>
      isDark ? const Color(0xFFAEAEB2) : const Color(0xFF86868B);

  /// 卡片背景
  Color get cardColor => isDark ? const Color(0xFF1C1C1E) : Colors.white;

  /// 卡片边框
  Color get cardBorder =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);

  /// 输入框/填充背景
  Color get fillColor =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

  /// 页面背景
  Color get scaffoldBg =>
      isDark ? const Color(0xFF0F0F12) : const Color(0xFFFAFAFC);

  /// 分隔线
  Color get dividerColor =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);

  /// 禁用/弱化色
  Color get disabledColor =>
      isDark ? const Color(0xFF636366) : const Color(0xFFC7C7CC);

  /// 品牌色（蓝色）
  static const Color brandBlue = Color(0xFF5BCEFA);

  /// 品牌色（粉色）
  static const Color brandPink = Color(0xFFF5A9B8);

  /// 构建 AppBar 标题样式
  TextStyle get appBarTitleStyle => TextStyle(
        fontWeight: FontWeight.w800,
        color: textColor,
      );
}
