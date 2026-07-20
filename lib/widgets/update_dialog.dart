import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 版本更新弹窗 — Claude 风格克制版
///
/// 去掉渐变 Header 与装饰性光点，改为纯文字标题 + 品牌色版本号标签。
/// 整体视觉安静，让用户专注于「更新内容」本身。
class UpdateDialog extends StatelessWidget {
  final String version;
  final String? releaseNotes;

  /// R2 单一直链下载 URL
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.version,
    this.releaseNotes,
    required this.downloadUrl,
  });

  /// 在指定 [context] 上展示更新弹窗。
  static Future<void> show(
    BuildContext context, {
    required String version,
    String? releaseNotes,
    required String downloadUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        version: version,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);
    final cardColor = isDark ? const Color(0xFF24242C) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5);
    final notesBg = isDark ? const Color(0xFF191920) : const Color(0xFFFAFAF7);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题区：版本号标签 + 标题 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 品牌色版本号小标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5A9B8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v$version',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF5A9B8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '发现新版本',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            _buildReleaseNotes(context, secondaryColor, notesBg, borderColor),
            _buildActions(context, textColor, secondaryColor, borderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseNotes(
    BuildContext context,
    Color secondaryColor,
    Color notesBg,
    Color borderColor,
  ) {
    final notes = releaseNotes;
    if (notes == null || notes.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Text(
          '快去下载最新版本体验新功能吧。',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: secondaryColor,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notesBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Text(
          notes,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: secondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: secondaryColor,
                side: BorderSide(color: borderColor, width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '稍后再说',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _handleUpdateNow(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF191920)
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '立即更新',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 点击「立即更新」：直接打开 R2 直链下载
  Future<void> _handleUpdateNow(BuildContext context) async {
    if (downloadUrl.isEmpty) {
      const fallbackUrl =
          'https://github.com/Trans-Prism/Trans-Prism/releases/latest';
      await _launchUrl(fallbackUrl);
    } else {
      await _launchUrl(downloadUrl);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 尝试打开 URL
  Future<bool> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    } catch (_) {
      return false;
    }
  }
}
