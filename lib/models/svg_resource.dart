/// SVG 资源元数据模型
///
/// 所有 SVG 资源通过硬编码列表定义，无需网络请求。
class SvgResource {
  /// 唯一标识
  final String id;

  /// 显示名称
  final String name;

  /// 简要描述
  final String description;

  /// assets 相对路径，如 'assets/svg_resources/example.svg'
  final String assetPath;

  /// 分类：'diagram'（图解）/ 'science'（科普）/ 'guide'（指南）
  final String category;

  const SvgResource({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    this.category = 'diagram',
  });
}

/// SVG 资源目录 — 所有本地内置 SVG 硬编码在此
class SvgResourceCatalog {
  SvgResourceCatalog._();

  /// 所有 SVG 资源列表
  static const List<SvgResource> all = [
    // ── 示例 SVG 资源（可替换为实际内容） ──
    // SvgResource(
    //   id: 'hrt_guide_01',
    //   name: 'HRT 用药流程图',
    //   description: '跨性别激素替代疗法用药流程概览',
    //   assetPath: 'assets/svg_resources/hrt_guide.svg',
    //   category: 'guide',
    // ),
  ];

  /// 按分类筛选
  static List<SvgResource> byCategory(String category) =>
      all.where((r) => r.category == category).toList();

  /// 按 ID 查找
  static SvgResource? findById(String id) {
    try {
      return all.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取所有可用分类
  static Set<String> get categories => all.map((r) => r.category).toSet();
}
