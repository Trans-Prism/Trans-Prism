import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 优雅的品牌化版本更新弹窗
///
/// 支持从 R2 边缘节点单一直链下载。
/// 点击「立即更新」后通过系统浏览器打开下载链接。
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildTitle(),
            _buildReleaseNotes(context),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8ECAE6), Color(0xFFE8AEBF)],
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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.20),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlowDot(const Color(0xFF8ECAE6)),
              const SizedBox(width: 6),
              _buildGlowDot(const Color(0xFFE8AEBF)),
              const SizedBox(width: 6),
              _buildGlowDot(Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlowDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.6),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Text(
        '发现新版本 $version',
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D1D1F),
          letterSpacing: -0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

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

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        children: [
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _handleUpdateNow(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8ECAE6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '立即更新',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
