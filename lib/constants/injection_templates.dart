/// 预设注射部位轮换模板
///
/// 每个模板定义一组可轮换的注射部位，
/// 键为模板 ID，值为部位名称列表。
///
/// 使用方式：
/// ```dart
/// // 获取模板所有部位
/// final sites = injectionTemplates['arms_2']; // ['左臂', '右臂']
///
/// // 获取所有可用模板列表
/// final templateIds = injectionTemplates.keys.toList();
/// ```
const Map<String, List<String>> injectionTemplates = {
  // ── 双臂（2 部位） ──
  'arms_2': ['左臂', '右臂'],

  // ── 双臀（2 部位） ──
  'glutes_2': ['左臀', '右臀'],

  // ── 腹部（4 部位） ──
  'belly_4': ['左下腹', '右下腹', '左大腿', '右大腿'],

  // ── 大腿（4 部位） ──
  'thighs_4': ['左大腿外侧', '右大腿外侧', '左大腿内侧', '右大腿内侧'],

  // ── 腹部 + 大腿（6 部位） ──
  'belly_thighs_6': [
    '左下腹',
    '右下腹',
    '左大腿外侧',
    '右大腿外侧',
    '左大腿内侧',
    '右大腿内侧',
  ],
};

/// 获取模板的中文名称（用于 UI 展示）
const Map<String, String> injectionTemplateLabels = {
  'arms_2': '双臂（2 部位）',
  'glutes_2': '双臀（2 部位）',
  'belly_4': '腹部-大腿（4 部位）',
  'thighs_4': '双腿（4 部位）',
  'belly_thighs_6': '腹部+双腿（6 部位）',
};

/// 获取指定模板 ID 对应的部位列表
///
/// 如果模板不存在，返回空列表。
List<String> getTemplateSites(String templateId) {
  return List<String>.from(injectionTemplates[templateId] ?? []);
}

/// 根据当前已使用的部位列表，推荐下一个应注射的部位
///
/// [templateId] 使用的模板 ID
/// [usedSites] 近期已使用的部位列表（最近的在前或无序均可）
/// 返回推荐的下一个部位；如果无法推荐则返回 null。
String? recommendNextSite(String templateId, List<String> usedSites) {
  final sites = injectionTemplates[templateId];
  if (sites == null || sites.isEmpty) return null;

  // 统计每个部位的使用次数
  final usageCount = <String, int>{};
  for (final site in sites) {
    usageCount[site] = 0;
  }
  for (final used in usedSites) {
    if (usageCount.containsKey(used)) {
      usageCount[used] = usageCount[used]! + 1;
    }
  }

  // 找到使用次数最少的部位
  int minCount = usageCount.values.isNotEmpty
      ? usageCount.values.reduce(
          (a, b) => a < b ? a : b,
        )
      : 0;

  final candidates = usageCount.entries
      .where((e) => e.value == minCount)
      .map((e) => e.key)
      .toList();

  if (candidates.isEmpty) return null;

  // 如果有多个最少使用的部位，优先推荐最近未使用过的
  if (candidates.length > 1 && usedSites.isNotEmpty) {
    for (final site in usedSites.reversed) {
      if (candidates.contains(site)) continue;
      return site; // 推荐不是最近使用的候选部位
    }
  }

  return candidates.first;
}
