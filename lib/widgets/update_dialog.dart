import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 优雅的品牌化版本更新弹窗
///
/// 支持多镜像站容错：[apkDownloadUrls] 提供一个 URL 列表，
/// 依次尝试打开直到成功。
class UpdateDialog extends StatelessWidget {
  final String version;
  final String? releaseNotes;

  /// 多镜像站下载链接列表（按优先级排列）
  final List<String> apkDownloadUrls;

  const UpdateDialog({
    super.key,
    required this.version,
    this.releaseNotes,
    this.apkDownloadUrls = const [],
  });

  /// 在指定 [context] 上展示更新弹窗。
  static Future<void> show(
    BuildContext context, {
    required String version,
    String? releaseNotes,
    List<String> apkDownloadUrls = const [],
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        version: version,
        releaseNotes: releaseNotes,
        apkDownloadUrls: apkDownloadUrls,
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 点击「立即更新」：依次尝试每个镜像站 URL
  Future<void> _handleUpdateNow(BuildContext context) async {
    if (apkDownloadUrls.isEmpty) {
      const fallbackUrl =
          'https://github.com/daanser/Trans-Prism/releases/latest';
      await _launchUrl(fallbackUrl);
    } else {
      // 依次尝试每个镜像 URL，只要有一个成功打开就停止
      for (final url in apkDownloadUrls) {
        final opened = await _launchUrl(url);
        if (opened) break;
      }
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 尝试打开 URL，返回是否成功
  Future<bool> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true; // launchUrl 不抛异常即视为成功
    } catch (_) {
      return false;
    }
  }
}
