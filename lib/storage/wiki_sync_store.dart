import 'package:shared_preferences/shared_preferences.dart';

/// 本地记录各 Wiki 已缓存内容对应的 GitHub 版本指纹
class WikiSyncStore {
  static String _shaKey(String wikiId) => 'wiki_cached_sha_$wikiId';

  Future<String?> getCachedSha(String wikiId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shaKey(wikiId));
  }

  Future<void> saveCachedSha(String wikiId, String sha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shaKey(wikiId), sha);
  }
}
