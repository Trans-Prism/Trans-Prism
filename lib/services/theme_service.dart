import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式偏好管理
///
/// 将用户的亮/暗/系统跟随主题选择持久化到 SharedPreferences。
class ThemeService extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';
  static const String _colorPrefsKey = 'theme_color';

  ThemeMode _themeMode = ThemeMode.system;
  Color _themeColor = const Color(0xFFF5A9B8); // 默认跨旗粉

  ThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;

  /// 是否处于暗色模式（基于当前 themeMode 判断）
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// 加载持久化的主题偏好
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_prefsKey);
    if (savedMode != null) {
      _themeMode = _themeModeFromString(savedMode);
    }

    final savedColor = prefs.getInt(_colorPrefsKey);
    if (savedColor != null) {
      _themeColor = Color(savedColor);
    }

    notifyListeners();
  }

  /// 设置主题模式并持久化
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _themeModeToString(mode));
  }

  /// 设置主题色并持久化
  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorPrefsKey, color.value);
  }

  /// 切换亮/暗（如果当前是 system 则切换到亮）
  Future<void> toggle() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
