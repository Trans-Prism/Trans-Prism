import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 关于页面
///
/// 展示应用信息、Logo 及第三方开源许可声明。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _appVersion = 'v1.1.1+1');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final secondaryTextColor =
        isDark ? const Color(0xFF98989E) : const Color(0xFF86868B);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorderColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '关于',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo 与标题区域
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cardBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/logo_foreground.png',
                      width: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Trans Prism (TP) 🌈',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '为跨性别社群打造的全能工具箱',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appVersion,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'https://github.com/Trans-Prism/Trans-Prism'),
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(label: '复制', onPressed: () {}),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new,
                            size: 14, color: Colors.blue.shade400),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'https://github.com/Trans-Prism/Trans-Prism',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── 原创代码许可 ──
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cardBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_rounded,
                          size: 18, color: secondaryTextColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Trans Prism 原创代码许可',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CC BY-NC-SA 4.0',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '本应用原创代码（含 Flutter UI、业务逻辑、资产资源编排等）采用 '
                    'Creative Commons Attribution-NonCommercial-ShareAlike 4.0 '
                    'International (CC BY-NC-SA 4.0) 协议进行许可，区别于第三方开源库的各自有许可证。\n'
                    '详情参见：https://creativecommons.org/licenses/by-nc-sa/4.0/',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── 内容与数据许可 ──
          const SizedBox(height: 16),
          _SectionHeader(title: '内容与数据许可', isDark: isDark),
          _buildLicenseCard(
            context,
            icon: Icons.voice_chat,
            title: 'VFS Tracker（嗓音训练模块）',
            license: 'CC BY-NC-SA 4.0',
            copyright: 'VFS Tracker — Ethanlita',
            url: 'https://github.com/Ethanlita/vfs-tracker',
            description:
                '嗓音训练模块基于 VFS Tracker 项目开发，遵循 Attribution-NonCommercial-ShareAlike 4.0 International 许可。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.menu_book,
            title: 'Project Trans Wiki 内容',
            license: 'CC BY-SA 4.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans',
            description:
                '内置 Wiki 内容（MtF.Wiki、FtM.Wiki、RLE.Wiki 等）采用「署名—相同方式共享 4.0 协议国际版」许可。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.language,
            title: '2345.lgbt（跨性别友好资源导航站）',
            license: 'LGPL-3.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans/2345.LGBT',
            description: '跨性别友好资源导航页，源代码采用 LGPL-3.0 许可证。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.web,
            title: 'Next-MtF-wiki（MtF.Wiki 前端框架）',
            license: 'AGPL-3.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans/Next-MtF-wiki',
            description: 'MtF.Wiki 基于的前端框架，采用 AGPL-3.0 许可证。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.menu_book,
            title: 'FtM-wiki（FtM.Wiki 内容仓库）',
            license: 'LGPLv3 / CC BY-SA 4.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans/FtM-wiki',
            description: 'FtM.Wiki 的源代码采用 LGPLv3 许可，网站内容采用 CC BY-SA 4.0 许可。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.web,
            title: 'Oyama\'s HRT Tracker（血药浓度模拟前端）',
            license: 'MIT License',
            copyright: 'SmirnovaOyama',
            url: 'https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker',
            description:
                '血药浓度模拟的 Web 交互界面，基于 React + TypeScript + Vite 构建，以 WebView 方式嵌入应用。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.biotech,
            title: 'HRT-Recorder-PKcomponent-Test（PK 算法核心）',
            license: 'MIT License',
            copyright: 'LaoZhong-Mihari',
            url:
                'https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test',
            description:
                '血药浓度模拟的药代动力学算法来源，包含：三室模型解析解、两库注射动力学、Bateman 口服模型、舌下双通路模型、贴片零阶/一阶输入模型。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          // ── 图解资源许可 ──
          const SizedBox(height: 12),
          _SectionHeader(title: '图解资源许可', isDark: isDark),
          _buildLicenseCard(
            context,
            icon: Icons.emoji_emotions,
            title: 'Twemoji（推特表情符号）',
            license: 'CC-BY 4.0',
            copyright: 'Copyright 2020 Twitter, Inc and other contributors',
            url: 'https://github.com/twitter/twemoji',
            description:
                '部分 SVG 图标来源于 Twitter 的 Twemoji 项目。代码和图标采用 CC-BY 4.0 许可证发布。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.emoji_emotions,
            title: 'OpenMoji（开源表情符号）',
            license: 'CC BY-SA 4.0',
            copyright: 'Copyright 2021 OpenMoji — 开源表情符号项目',
            url: 'https://openmoji.org/',
            description: '部分 SVG 图标来源于 OpenMoji 项目，采用 CC BY-SA 4.0 许可证发布。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.emoji_emotions,
            title: 'Google Noto Emoji（谷歌表情符号）',
            license: 'Apache License 2.0',
            copyright: 'Copyright 2024 Google LLC',
            url: 'https://github.com/googlefonts/noto-emoji',
            description:
                '部分 SVG 图标来源于 Google 的 Noto Emoji 项目，采用 Apache License 2.0 许可证发布。',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          // ── 第三方开源许可 ──
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.article_outlined,
                  size: 20,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                '第三方开源许可',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 第三方许可列表
          _buildLicenseCard(
            context,
            icon: Icons.code,
            title: 'Flutter & Dart SDK',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2014 Flutter\nCopyright 2012 Dart',
            url: 'https://github.com/flutter/flutter',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.storage,
            title: 'shared_preferences',
            license: 'BSD 3-Clause License',
            copyright:
                'Copyright 2013 Flutter\nCopyright 2022 shared_preferences contributors',
            url: 'https://pub.dev/packages/shared_preferences',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.http,
            title: 'dio',
            license: 'MIT License',
            copyright: 'Copyright 2019-present flutterchina.club',
            url: 'https://pub.dev/packages/dio',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.folder,
            title: 'path_provider',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2013 Flutter',
            url: 'https://pub.dev/packages/path_provider',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.language,
            title: 'webview_flutter',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2013 Flutter',
            url: 'https://pub.dev/packages/webview_flutter',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.bar_chart,
            title: 'fl_chart',
            license: 'MIT License',
            copyright: 'Copyright 2018-2024 Iman Khoshabi',
            url: 'https://pub.dev/packages/fl_chart',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.mic,
            title: 'record',
            license: 'MIT License',
            copyright: 'Copyright 2021 Albert Yu (talent-jiang)',
            url: 'https://pub.dev/packages/record',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.graphic_eq,
            title: 'pitch_detector_dart',
            license: 'MIT License',
            copyright: 'Copyright 2024 sss-m5',
            url: 'https://pub.dev/packages/pitch_detector_dart',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.music_note,
            title: 'audioplayers',
            license: 'MIT License',
            copyright: 'Copyright 2021 luanpotter',
            url: 'https://pub.dev/packages/audioplayers',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.vpn_key,
            title: 'uuid',
            license: 'MIT License',
            copyright: 'Copyright 2019 Yulio',
            url: 'https://pub.dev/packages/uuid',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.http,
            title: 'http',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2014 Dart',
            url: 'https://pub.dev/packages/http',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildLicenseCard(
            context,
            icon: Icons.phone_android,
            title: 'cupertino_icons',
            license: 'MIT License',
            copyright: 'Copyright 2016 Flutter',
            url: 'https://pub.dev/packages/cupertino_icons',
            isDark: isDark,
            cardBg: cardBg,
            cardBorderColor: cardBorderColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 32),
          const SizedBox(height: 32),
          // 版权声明
          Center(
            child: Text(
              'Copyright © 2026 Trans Prism',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String license,
    required String copyright,
    required String url,
    String? description,
    required bool isDark,
    required Color cardBg,
    required Color cardBorderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: secondaryTextColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    license,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: secondaryTextColor,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              copyright,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(url),
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: '复制',
                      onPressed: () {},
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.open_in_new,
                      size: 12, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      url,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// 段落小标题
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF5BCEFA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
            ),
          ),
        ],
      ),
    );
  }
}
