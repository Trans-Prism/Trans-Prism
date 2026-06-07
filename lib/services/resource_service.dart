import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/resource_item.dart';

/// 资源管理服务 — JSON 驱动，泛搜索，内存缓存
///
/// 职责：
///   1. 加载 assets/resource_metadata.json 并解析为 [List<ResourceItem>]
///   2. 提供 [searchResources] 泛搜索方法
///   3. 内存缓存，避免重复解析
class ResourceService {
  // ─── 单例 ─────────────────────────────────────────────────
  static final ResourceService _instance = ResourceService._internal();
  factory ResourceService() => _instance;
  ResourceService._internal();

  /// 内存缓存
  List<ResourceItem>? _cachedResources;

  /// 是否已初始化
  bool get isInitialized => _cachedResources != null;

  /// 获取所有资源（未过滤）
  ///
  /// 未初始化时返回空列表，避免调用方崩溃。
  List<ResourceItem> get allResources => _cachedResources ?? [];

  // ─── 初始化 ─────────────────────────────────────────────────

  /// 初始化：从 assets 加载 resource_metadata.json
  ///
  /// 可安全重复调用 — 已缓存时直接返回。
  Future<void> initialize() async {
    if (_cachedResources != null) return;

    try {
      final jsonString =
          await rootBundle.loadString('assets/resource_metadata.json');
      debugPrint('📄 [ResourceService] 已读取 JSON, 长度=${jsonString.length}');
      debugPrint('📄 [ResourceService] 前 80 字: ${jsonString.substring(0, 80)}');

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      debugPrint('📄 [ResourceService] JSON 数组长度: ${jsonList.length}');

      _cachedResources = jsonList
          .map((e) => ResourceItem.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('📦 [ResourceService] ✓ 已加载 ${_cachedResources!.length} 个资源:');
      for (final r in _cachedResources!) {
        debugPrint(
            '   - ${r.id}: "${r.displayName}" (${r.styles.length} styles)');
      }
    } catch (e, s) {
      debugPrint('❌ [ResourceService] 加载失败: $e');
      debugPrint('❌ [ResourceService] 堆栈: $s');
      // 不设置 _cachedResources，保持为 null，以便下次调用时可重试
    }
  }

  // ─── 泛搜索 ─────────────────────────────────────────────────

  /// 泛搜索资源
  ///
  /// 搜索规则：
  ///   - [query] 为空 → 返回全量列表
  ///   - [query] 转为小写并去除首尾空格后匹配
  ///   - 匹配 [displayName]（忽略大小写）
  ///   - 匹配 [searchKeywords] 中任意元素（忽略大小写，支持 Emoji）
  List<ResourceItem> searchResources(String query) {
    final trimmed = query.trim().toLowerCase();

    // 空查询返回全量
    if (trimmed.isEmpty) {
      return List.unmodifiable(allResources);
    }

    return allResources.where((item) {
      // 匹配 displayName
      if (item.displayName.toLowerCase().contains(trimmed)) {
        return true;
      }
      // 匹配 searchKeywords
      for (final keyword in item.searchKeywords) {
        if (keyword.toLowerCase().contains(trimmed)) {
          return true;
        }
      }
      return false;
    }).toList();
  }
}
