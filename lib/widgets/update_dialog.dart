import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 优雅的品牌化版本更新弹窗
///
/// 大圆角、Pastel 蓝粉渐变品牌色系、微光图标。
/// 展示最新版本号与 GitHub Releases 的更新日志 (body)。
class UpdateDialog extends StatelessWidget {
  final String version;
  final String? releaseNotes;
  final String? apkDownloadUrl;

  const UpdateDialog({
    super.key,
    required this.version,
    this.releaseNotes,
    this.apkDownloadUrl,
  });

  /// 在指定 [context] 上展示更新弹窗。
  static Future<void> show(
    BuildContext context, {
    required String version,
    String? releaseNotes,
    String? apkDownloadUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        version: version,
        releaseNotes: releaseNotes,
        apkDownloadUrl: apkDownloadUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5BCEFA).withOpacity(0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 顶部渐变品牌图标区域 ──
            _buildHeader(),
            // ── 标题 ──
            _buildTitle(),
            // ── 更新日志 ──
            _buildReleaseNotes(context),
            // ── 按钮组 ──
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  /// 顶部 Pastel 蓝粉渐变 + 微光图标
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 32, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // 微光圆形图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.25),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.system_update_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // 微光小圆点装饰
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlowDot(const Color(0xFF5BCEFA)),
              const SizedBox(width: 6),
              _buildGlowDot(const Color(0xFFF5A9B8)),
              const SizedBox(width: 6),
              _buildGlowDot(Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlowDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.7),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
        ],
      ),
    );
  }

  /// 标题：发现新版本 [version]
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Text(
        '发现新版本 $version',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1D1D1F),
          letterSpacing: -0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 更新日志内容区域
  Widget _buildReleaseNotes(BuildContext context) {
    final notes = releaseNotes;
    if (notes == null || notes.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Text(
          '快去下载最新版本体验新功能吧！',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF86868B),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Text(
          notes,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF3A3A3C),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  /// 底部按钮组：「稍后再说」+「立即更新」
  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        children: [
          // 稍后再说
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF86868B),
                side: const BorderSide(color: Color(0xFFD1D1D6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '稍后再说',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 立即更新
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _handleUpdateNow(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BCEFA),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: const Color(0xFF5BCEFA).withOpacity(0.3),
              ),
              child: const Text(
                '立即更新',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 点击「立即更新」：使用外部浏览器打开 APK 下载链接
  Future<void> _handleUpdateNow(BuildContext context) async {
    final url = apkDownloadUrl;
    if (url == null || url.isEmpty) {
      // 无 APK 链接时降级到 GitHub Releases 页面
      const fallbackUrl =
          'https://github.com/daanser/Trans-Prism/releases/latest';
      await _launchUrl(fallbackUrl);
    } else {
      await _launchUrl(url);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 静默失败：拉起浏览器失败就不做任何事
    }
  }
}
