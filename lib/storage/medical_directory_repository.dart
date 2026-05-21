import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medical_directory.dart';

/// 友善医疗名录 — 本地存储层
///
/// 职责：
/// - 加载打包在 assets 中的种子 JSON 数据
/// - 管理收藏列表（SharedPreferences）
/// - 缓存从 GitHub 同步的远程数据 + 版本 SHA
class MedicalDirectoryRepository {
  static const String _favoritesKey = 'medical_directory_favorites';
  static const String _cachedDataKey = 'medical_directory_cached_data';
  static const String _cachedShaKey = 'medical_directory_cached_sha';

  // ---------- 种子数据 ----------

  /// 从 assets/data/medical_directory.json 加载机构列表
  Future<List<FriendlyInstitution>> loadSeedData() async {
    final jsonString =
        await rootBundle.loadString('assets/data/medical_directory.json');
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => FriendlyInstitution.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- 远程缓存（GitHub 同步结果） ----------

  /// 保存从 GitHub 拉取的最新数据
  Future<void> saveCachedData(List<FriendlyInstitution> institutions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = institutions.map((e) => e.toJson()).toList();
    await prefs.setString(_cachedDataKey, jsonEncode(jsonList));
  }

  /// 加载本地缓存的远程数据
  Future<List<FriendlyInstitution>?> loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cachedDataKey);
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => FriendlyInstitution.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ---------- 版本追踪（GitHub commit SHA） ----------

  /// 保存当前已缓存数据对应的 GitHub commit SHA
  Future<void> saveCachedSha(String sha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedShaKey, sha);
  }

  /// 读取本地缓存的 commit SHA（null = 从未同步过）
  Future<String?> loadCachedSha() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cachedShaKey);
  }

  // ---------- 收藏管理 ----------

  /// 获取已收藏的机构 ID 列表
  Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_favoritesKey);
    if (jsonString == null) return {};
    try {
      final List<dynamic> ids = jsonDecode(jsonString) as List<dynamic>;
      return ids.map((e) => e as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// 切换收藏状态，返回新的收藏状态
  Future<bool> toggleFavorite(String institutionId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getFavoriteIds();
    if (current.contains(institutionId)) {
      current.remove(institutionId);
    } else {
      current.add(institutionId);
    }
    await prefs.setString(_favoritesKey, jsonEncode(current.toList()));
    return current.contains(institutionId);
  }

  /// 设置收藏状态
  Future<void> setFavorite(String institutionId, bool favorite) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getFavoriteIds();
    if (favorite) {
      current.add(institutionId);
    } else {
      current.remove(institutionId);
    }
    await prefs.setString(_favoritesKey, jsonEncode(current.toList()));
  }
}
