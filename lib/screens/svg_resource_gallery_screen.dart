import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/resource_item.dart';
import '../services/permission_manager.dart';
import '../services/resource_service.dart';
import 'svg_preview_screen.dart';

/// =============================================================================
/// SvgResourceGalleryScreen — 图解资源独立页面（原 _SvgResourceTab 提取）
///
/// 供工作台 (WorkspaceTab) 导航使用。
/// =============================================================================
class SvgResourceGalleryScreen extends StatefulWidget {
  const SvgResourceGalleryScreen({super.key});

  @override
  State<SvgResourceGalleryScreen> createState() =>
      _SvgResourceGalleryScreenState();
}

class _SvgResourceGalleryScreenState extends State<SvgResourceGalleryScreen> {
  List<ResourceItem> _allResources = [];
  List<ResourceItem> _filteredResources = [];
  bool _isLoading = true;

  /// 搜索关键词
  String _searchQuery = '';

  /// 当前厂牌样式
  String _preferredStyle = 'twemoji';

  /// 厂牌显示名称映射
  static const Map<String, String> _styleLabels = {
    'twemoji': 'Twemoji (推特风)',
    'openmoji': 'OpenMoji (极简风)',
    'noto': 'Noto (谷歌风)',
  };

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    if (!ResourceService().isInitialized) {
      await ResourceService().initialize();
    }
    // ── 进入图解资源页面：静默查询相册/存储权限，无则索要 ──
    if (!await PermissionManager().checkStoragePermission()) {
      await PermissionManager().requestStoragePermission();
    }
    if (mounted) {
      setState(() {
        _allResources = ResourceService().allResources;
        _filteredResources = _allResources;
        _isLoading = false;
      });
    }
  }

  /// 执行搜索
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredResources = ResourceService().searchResources(query);
    });
  }

  /// 显示厂牌切换 BottomSheet
  void _showStylePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 拖拽指示条 ──
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '选择图标风格',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ..._styleLabels.entries.map((entry) {
                final selected = _preferredStyle == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: selected
                          ? const BorderSide(
                              color: Color(0xFFF5A9B8), width: 1.5)
                          : BorderSide.none,
                    ),
                    tileColor: selected
                        ? const Color(0xFFF5A9B8).withOpacity(0.06)
                        : (isDark
                            ? const Color(0xFF24242C)
                            : Colors.grey.shade50),
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? const Color(0xFFF5A9B8) : textColor,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFFF5A9B8), size: 22)
                        : null,
                    onTap: () {
                      setState(() => _preferredStyle = entry.key);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '图解资源',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: textColor,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── 搜索与控制栏 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: CupertinoSearchTextField(
                            controller: _searchController,
                            placeholder: '搜索资源...',
                            onChanged: _performSearch,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFEDEDF0)
                                  : const Color(0xFF333333),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: isDark
                              ? const Color(0xFF24242C)
                              : const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () => _showStylePicker(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.style,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFEDEDF0)
                                    : const Color(0xFF333333),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _styleLabels[_preferredStyle] ??
                                    _preferredStyle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFEDEDF0)
                                      : const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 资源网格 + 许可页脚 ──
                Expanded(
                  child: _filteredResources.isEmpty
                      ? _buildEmptyState(context)
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.95,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final resource = _filteredResources[index];
                                    return _SvgResourceCard(
                                      resource: resource,
                                      isDark: isDark,
                                      preferredStyle: _preferredStyle,
                                    );
                                  },
                                  childCount: _filteredResources.length,
                                ),
                              ),
                            ),
                            // 页脚：SVG 图标来源许可声明
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 24, 16, 40),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '图标来源许可',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF6B6B76)
                                            : const Color(0xFF8E8E93),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _licenseText(
                                      'Twemoji (推特) — CC-BY 4.0',
                                      isDark,
                                    ),
                                    const SizedBox(height: 4),
                                    _licenseText(
                                      'OpenMoji (开源社区) — CC BY-SA 4.0',
                                      isDark,
                                    ),
                                    const SizedBox(height: 4),
                                    _licenseText(
                                      'Google Noto Emoji — Apache License 2.0',
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _licenseText(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: isDark ? const Color(0xFF48484A) : const Color(0xFF8E8E96),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.image_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配资源' : '暂无图解资源',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '尝试其他关键词搜索',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SVG 资源卡片（高密度 Quiet Luxury）
class _SvgResourceCard extends StatelessWidget {
  final ResourceItem resource;
  final bool isDark;
  final String preferredStyle;

  const _SvgResourceCard({
    required this.resource,
    required this.isDark,
    required this.preferredStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isDark ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SvgPreviewScreen(
                allResources: [resource],
                initialIndex: 0,
                initialStyle: preferredStyle,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SvgPicture.asset(
                  resource.getSvgPath(preferredStyle: preferredStyle),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                resource.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF8E8E96)
                      : const Color(0xFF8E8E93),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
