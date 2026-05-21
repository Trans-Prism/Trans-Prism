import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化：用户是否已同意全部免责声明（网络 + 血药浓度模拟）
class DisclaimerRepository {
  static const String _storageKey = 'network_disclaimer_accepted';

  Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKey) ?? false;
  }

  Future<void> setAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, true);
  }
}
