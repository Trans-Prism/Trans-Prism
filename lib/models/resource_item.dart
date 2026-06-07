/// 资源条目数据模型
///
/// 对应 resource_metadata.json 中的单个资源对象。
/// 包含多厂牌 SVG 路径映射和搜索关键词，支持泛搜索。
class ResourceItem {
  /// 唯一标识
  final String id;

  /// 显示名称（如 "Blåhaj Shark"）
  final String displayName;

  /// 搜索关键词（支持中英文、Emoji）
  final List<String> searchKeywords;

  /// 厂牌样式 → SVG 路径映射
  /// 如 { "twemoji": "assets/svg_resources/xxx_twemoji.svg", ... }
  final Map<String, String> styles;

  const ResourceItem({
    required this.id,
    required this.displayName,
    required this.searchKeywords,
    required this.styles,
  });

  /// 从 JSON Map 构造
  ///
  /// 同时兼容 camelCase（displayName）和 snake_case（display_name）字段名，
  /// 以适应不同脚本生成的 JSON 格式。
  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    // displayName / display_name
    String displayName;
    if (json.containsKey('displayName')) {
      displayName = json['displayName'] as String;
    } else {
      displayName = json['display_name'] as String;
    }

    // searchKeywords / search_keywords
    List<String> searchKeywords;
    if (json.containsKey('searchKeywords')) {
      searchKeywords = (json['searchKeywords'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } else {
      searchKeywords = (json['search_keywords'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    }

    return ResourceItem(
      id: json['id'] as String,
      displayName: displayName,
      searchKeywords: searchKeywords,
      styles: (json['styles'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String)),
    );
  }

  /// 获取指定厂牌样式的 SVG 路径
  ///
  /// 优先返回 [preferredStyle] 的路径。
  /// 如果该厂牌不存在，则 fallback 到 styles 中第一个可用的路径，
  /// 确保图形一定能渲染出来。
  String getSvgPath({String preferredStyle = 'twemoji'}) {
    // 优先返回首选厂牌
    if (styles.containsKey(preferredStyle)) {
      final path = styles[preferredStyle]!;
      if (path.isNotEmpty) return path;
    }
    // fallback：返回第一个可用路径
    if (styles.isNotEmpty) {
      return styles.values.first;
    }
    throw StateError('Resource "$id" has no available SVG paths');
  }

  @override
  String toString() =>
      'ResourceItem(id: $id, displayName: $displayName, styles: ${styles.length})';
}
