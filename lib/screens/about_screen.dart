import 'package:flutter/material.dart';

/// 关于页面
///
/// 展示应用信息、Logo 及第三方开源许可声明。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '关于',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D1D1F),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo 与标题区域
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
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
                  const Text(
                    'Trans Prism (TP) 🌈',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '为跨性别社群打造的全能工具箱',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0+1',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'https://github.com/daanser/Trans-Prism'),
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
                            'https://github.com/daanser/Trans-Prism',
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
          const SizedBox(height: 20),
          // 第三方开源许可标题
          Row(
            children: [
              Icon(Icons.article_outlined,
                  size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                '第三方开源许可',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
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
          ),
          _buildLicenseCard(
            context,
            icon: Icons.storage,
            title: 'shared_preferences',
            license: 'BSD 3-Clause License',
            copyright:
                'Copyright 2013 Flutter\nCopyright 2022 shared_preferences contributors',
            url: 'https://pub.dev/packages/shared_preferences',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.http,
            title: 'dio',
            license: 'MIT License',
            copyright: 'Copyright 2019-present flutterchina.club',
            url: 'https://pub.dev/packages/dio',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.folder,
            title: 'path_provider',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2013 Flutter',
            url: 'https://pub.dev/packages/path_provider',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.language,
            title: 'webview_flutter',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2013 Flutter',
            url: 'https://pub.dev/packages/webview_flutter',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.bar_chart,
            title: 'fl_chart',
            license: 'MIT License',
            copyright: 'Copyright 2018-2024 Iman Khoshabi',
            url: 'https://pub.dev/packages/fl_chart',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.mic,
            title: 'record',
            license: 'MIT License',
            copyright: 'Copyright 2021 Albert Yu (talent-jiang)',
            url: 'https://pub.dev/packages/record',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.graphic_eq,
            title: 'pitch_detector_dart',
            license: 'MIT License',
            copyright: 'Copyright 2024 sss-m5',
            url: 'https://pub.dev/packages/pitch_detector_dart',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.music_note,
            title: 'audioplayers',
            license: 'MIT License',
            copyright: 'Copyright 2021 luanpotter',
            url: 'https://pub.dev/packages/audioplayers',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.vpn_key,
            title: 'uuid',
            license: 'MIT License',
            copyright: 'Copyright 2019 Yulio',
            url: 'https://pub.dev/packages/uuid',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.http,
            title: 'http',
            license: 'BSD 3-Clause License',
            copyright: 'Copyright 2014 Dart',
            url: 'https://pub.dev/packages/http',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.phone_android,
            title: 'cupertino_icons',
            license: 'MIT License',
            copyright: 'Copyright 2016 Flutter',
            url: 'https://pub.dev/packages/cupertino_icons',
          ),
          const SizedBox(height: 12),
          // VFS Tracker / 嗓音训练 许可声明
          const _SectionHeader(title: '内容与数据许可'),
          _buildLicenseCard(
            context,
            icon: Icons.voice_chat,
            title: 'VFS Tracker（嗓音训练模块）',
            license: 'CC BY-NC-SA 4.0',
            copyright: 'VFS Tracker — Ethanlita',
            url: 'https://github.com/Ethanlita/vfs-tracker',
            description:
                '嗓音训练模块基于 VFS Tracker 项目开发，遵循 Attribution-NonCommercial-ShareAlike 4.0 International 许可。',
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
          ),
          _buildLicenseCard(
            context,
            icon: Icons.language,
            title: '2345.lgbt（跨性别友好资源导航站）',
            license: 'LGPL-3.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans/2345.LGBT',
            description: '跨性别友好资源导航页，源代码采用 LGPL-3.0 许可证。',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.web,
            title: 'Next-MtF-wiki（MtF.Wiki 前端框架）',
            license: 'AGPL-3.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans/Next-MtF-wiki',
            description: 'MtF.Wiki 基于的前端框架，采用 AGPL-3.0 许可证。',
          ),
          _buildLicenseCard(
            context,
            icon: Icons.menu_book,
            title: 'FtM-wiki（FtM.Wiki 内容仓库）',
            license: 'LGPLv3 / CC BY-SA 4.0',
            copyright: 'Project Trans',
            url: 'https://github.com/project-trans/FtM-wiki',
            description: 'FtM.Wiki 的源代码采用 LGPLv3 许可，网站内容采用 CC BY-SA 4.0 许可。',
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
          ),
          const SizedBox(height: 32),
          // 版权声明
          Center(
            child: Text(
              'Copyright © 2025 Trans Prism\n'
              'All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
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
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    license,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
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
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              copyright,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
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

  const _SectionHeader({required this.title});

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D1D1F),
            ),
          ),
        ],
      ),
    );
  }
}
