import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/glass_surface.dart';

/// 相关链接页
///
/// 「我的 → 高级与系统 → 相关链接」的二级页面，集中展示官网 / 开源仓库等
/// 外部链接入口。
///
/// 架构边界（对齐 SYSTEM_MAP / ARCHITECTURE_DECISIONS）：
/// - 纯静态 UI + 用户主动跳转**系统浏览器**（`LaunchMode.externalApplication`）
/// - 不发起 App 内网络请求、不经过 R2 握手点 / `DnsSafeNetworkService`
/// - 无持久化、无状态管理、无新依赖（`url_launcher` 已有）
/// - 双模自适应：简约风实色卡 / 液态风由 `GlassSurface` 接管玻璃质感
class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  static const List<_LinkEntry> _links = [
    _LinkEntry(
      title: '官方网站',
      url: 'https://transprism.chengxi.moe',
      displayUrl: 'transprism.chengxi.moe',
      icon: Icons.language_rounded,
    ),
    _LinkEntry(
      title: '开源仓库',
      url: 'https://github.com/Trans-Prism/Trans-Prism',
      displayUrl: 'github.com/Trans-Prism/Trans-Prism',
      icon: Icons.code_rounded,
    ),
  ];

  /// 打开外部链接（失败兜底：SnackBar 提示）
  Future<void> _launch(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    const failMessage = '无法打开链接，请稍后再试';
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(const SnackBar(content: Text(failMessage)));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(failMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryTextColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);
    final cardBg = isDark ? const Color(0xFF24242C) : Colors.white;
    final cardBorderColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '相关链接',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── 说明 ──
          Text(
            '以下链接将跳转到系统浏览器打开',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          // ── 链接卡片 ──
          ..._links.map(
            (link) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassSurface(
                borderRadius: 16,
                solidColor: cardBg,
                borderColor: cardBorderColor,
                onTap: () => _launch(context, link.url),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF333338)
                            : const Color(0xFFEFEFEF),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(link.icon, size: 20, color: secondaryTextColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            link.displayUrl,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new_rounded,
                        size: 16, color: secondaryTextColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkEntry {
  const _LinkEntry({
    required this.title,
    required this.url,
    required this.displayUrl,
    required this.icon,
  });

  final String title;

  /// 实际打开的完整 URL
  final String url;

  /// 展示给用户的简洁 URL（去掉协议头）
  final String displayUrl;

  final IconData icon;
}
