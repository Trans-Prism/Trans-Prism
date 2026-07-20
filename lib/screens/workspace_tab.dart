import 'package:flutter/material.dart';

import '../widgets/gradient_icon.dart';
import 'bra_calculator_page.dart';
import 'hormone_converter_screen.dart';
import 'image_converter_screen.dart';
import 'medical_directory/medical_directory_list_screen.dart';
import 'svg_resource_gallery_screen.dart';
import 'tracker_screen.dart';
import 'voice_training/voice_training_home.dart';

/// =============================================================================
/// WorkspaceTab — 工作台 Tab
///
/// 功能：
/// 1. 顶部提供扁平风格（Claude style）搜索框
/// 2. 分类标签过滤器（动态构建、横向滑动）
/// 3. 以下按键遵循黄金分割比 (1.618)，具备极简弥散阴影
/// =============================================================================

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;
  final String category;

  _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconSize = 24,
    required this.onTap,
    required this.category,
  });
}

class WorkspaceTab extends StatefulWidget {
  final String genderIdentity;

  const WorkspaceTab({super.key, required this.genderIdentity});

  @override
  State<WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<WorkspaceTab> {
  String _searchQuery = '';
  String _selectedCategory = '全部';

  final List<String> _categories = ['全部', '健康测算', '视觉资源', '实用指引'];

  List<_ToolItem> _getToolItems(BuildContext context) {
    return [
      _ToolItem(
        title: '主题图标库',
        subtitle: '浏览与导出高清无损的主题图标与标志',
        icon: Icons.wallpaper_rounded,
        iconSize: 42,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SvgResourceGalleryScreen(),
            ),
          );
        },
        category: '视觉资源',
      ),
      _ToolItem(
        title: '图片格式转换',
        subtitle: '支持多种常见图片格式的高清互转与缩放',
        icon: Icons.swap_horiz_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImageConverterScreen(),
            ),
          );
        },
        category: '视觉资源',
      ),
      _ToolItem(
        title: '激素换算器',
        subtitle: 'E2/T/PRL 等单位实时双向换算',
        icon: Icons.balance_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HormoneConverterScreen(),
            ),
          );
        },
        category: '健康测算',
      ),
      _ToolItem(
        title: '血药浓度模拟',
        subtitle: "Oyama's HRT Tracker · PK 药代动学测算",
        icon: Icons.stacked_line_chart_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TrackerScreen(genderIdentity: widget.genderIdentity),
            ),
          );
        },
        category: '健康测算',
      ),
      _ToolItem(
        title: '罩杯计算器',
        subtitle: '基于 MtF.wiki 算法 · 发育记录追踪',
        icon: Icons.straighten_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BraCalculatorPage(),
            ),
          );
        },
        category: '健康测算',
      ),
      _ToolItem(
        title: '友善医疗名录',
        subtitle: '全国跨性别友善医疗机构',
        icon: Icons.local_hospital_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MedicalDirectoryListScreen(),
            ),
          );
        },
        category: '实用指引',
      ),
      _ToolItem(
        title: '声音训练辅助',
        subtitle: '基于 VFS Tracker 的嗓音训练工具',
        icon: Icons.mic_external_on_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VoiceTrainingHomeScreen(),
            ),
          );
        },
        category: '实用指引',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 温润纸张调色
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);
    final searchBgColor =
        isDark ? const Color(0xFF2A2A28) : const Color(0xFFF0EFEC);

    final allItems = _getToolItems(context);
    final filteredItems = allItems.where((item) {
      final matchCategory =
          _selectedCategory == '全部' || item.category == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ====== 顶部无边框静谧搜索条 ======
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: TextStyle(color: textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: '搜索功能或工具...',
              hintStyle: TextStyle(color: secondaryColor, fontSize: 15),
              prefixIcon:
                  Icon(Icons.search_rounded, color: secondaryColor, size: 20),
              filled: true,
              fillColor: searchBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // ====== 分类标签 (胶囊过滤器) ======
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = _selectedCategory == _categories[index];
              return _buildCategoryPill(
                _categories[index],
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  setState(() {
                    _selectedCategory = _categories[index];
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ====== 功能卡片列表 ======
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text(
                    '没有找到相关工具',
                    style: TextStyle(color: secondaryColor, fontSize: 14),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.618,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildMenuCard(
                      context,
                      title: item.title,
                      subtitle: item.subtitle,
                      icon: item.icon,
                      iconSize: item.iconSize,
                      onTap: item.onTap,
                      isDark: isDark,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 构建液态无界分类胶囊（Claude 风格：去边框，淡灰底）
  Widget _buildCategoryPill(String title,
      {required bool isSelected,
      required bool isDark,
      required VoidCallback onTap}) {
    final defaultSecondary =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);
    final unselectedBg =
        isDark ? const Color(0xFF2A2A28) : const Color(0xFFF0EFEC);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF333333))
              : unselectedBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : defaultSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建工具卡片
  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    double iconSize = 24,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);
    final cardColor = isDark ? const Color(0xFF24242C) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.035),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 圆底图标（Claude 风格） ──
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF333338) : const Color(0xFFEFEFEF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: iconSize > 26 ? 20 : iconSize.clamp(16, 20),
                  color: secondaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: secondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
