import 'package:flutter/material.dart';

import '../widgets/gradient_icon.dart';
import 'bra_calculator_page.dart';
import 'hormone_converter_screen.dart';
import 'image_converter_screen.dart';
import 'medical_directory/medical_directory_list_screen.dart';
import 'tracker_screen.dart';
import 'svg_resource_gallery_screen.dart';
import 'voice_training/voice_training_home.dart';

/// =============================================================================
/// WorkspaceTab — 工作台 Tab
///
/// 以 GridView 网格展示所有纯工具类功能卡片：
///   - 图解资源 (SVG库)
///   - 图片格式转换
///   - 激素换算器
///   - 药物存量仪表盘
///   - 血药浓度模拟
///   - 友善医疗名录
///   - 声音训练辅助
///
/// 所有卡片图标使用统一的 [GradientIcon] 组件（品牌色浅蓝→粉紫渐变），
/// 确保视觉质感完全一致，符合 Quiet Luxury 的克制感。
/// =============================================================================
class WorkspaceTab extends StatelessWidget {
  final String genderIdentity;

  const WorkspaceTab({super.key, required this.genderIdentity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
        children: _buildToolCards(context, isDark),
      ),
    );
  }

  List<Widget> _buildToolCards(BuildContext context, bool isDark) {
    return [
      _buildMenuCard(
        context,
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
        isDark: isDark,
      ),
      _buildMenuCard(
        context,
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
        isDark: isDark,
      ),
      _buildMenuCard(
        context,
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
        isDark: isDark,
      ),
      _buildMenuCard(
        context,
        title: '血药浓度模拟',
        subtitle: "Oyama's HRT Tracker · PK 药代动力学测算",
        icon: Icons.stacked_line_chart_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TrackerScreen(genderIdentity: genderIdentity),
            ),
          );
        },
        isDark: isDark,
      ),
      _buildMenuCard(
        context,
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
        isDark: isDark,
      ),
      _buildMenuCard(
        context,
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
        isDark: isDark,
      ),
      _buildMenuCard(
        context,
        title: '声音训练辅助',
        subtitle: '基于 VFS Tracker 的嗓音训练工具集',
        icon: Icons.mic_external_on_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VoiceTrainingHomeScreen(),
            ),
          );
        },
        isDark: isDark,
      ),
    ];
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    double iconSize = 44,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 统一渐变图标：品牌色浅蓝 → 粉紫 ──
            GradientIcon(icon, size: iconSize),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color:
                    isDark ? const Color(0xFF98989E) : const Color(0xFF999999),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
