import 'package:shared_preferences/shared_preferences.dart';

import '../models/gender_identity.dart';

/// 本地持久化存储用户性别认同
class GenderIdentityRepository {
  static const String _storageKey = 'gender_identity';

  Future<String?> getIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);
    return GenderIdentity.isValid(value) ? value : null;
  }

  Future<bool> hasIdentity() async {
    return (await getIdentity()) != null;
  }

  Future<void> saveIdentity(String identity) async {
    if (!GenderIdentity.isValid(identity)) {
      throw ArgumentError('无效的性别认同: $identity');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, identity);
  }

  Future<void> clearIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
