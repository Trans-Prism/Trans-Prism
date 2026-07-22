import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'glass_surface.dart';

/// Wiki 页面底部的开源协议声明
///
/// 支持一键关闭：本次会话隐藏 或 永久隐藏
class WikiLicenseNotice extends StatefulWidget {
  const WikiLicenseNotice({super.key});

  @override
  State<WikiLicenseNotice> createState() => _WikiLicenseNoticeState();
}

class _WikiLicenseNoticeState extends State<WikiLicenseNotice> {
  bool _visible = true;
  bool _initialised = false;

  static const _prefsKey = 'wiki_license_dismissed_permanently';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_prefsKey) ?? false;
    if (!mounted) return;
    setState(() {
      _visible = !dismissed;
      _initialised = true;
    });
  }

  Future<void> _dismissPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (!mounted) return;
    setState(() => _visible = false);
  }

  void _showDismissDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭许可声明'),
        content: const Text('您可以选择仅本次关闭（下次进入仍会显示）或以后都不显示。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _visible = false);
            },
            child: const Text('仅本次关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dismissPermanently();
            },
            child: const Text('不再显示'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) return const SizedBox.shrink();
    if (!_visible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: GlassSurface(
        solidColor: isDark ? const Color(0xFF24242C) : Colors.grey.shade50,
        borderColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance,
                    size: 20,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '内容与许可声明',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFFEDEDF0)
                            : Colors.grey.shade800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '关闭声明',
                  onPressed: _showDismissDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '内置的 MtF.Wiki、FtM.Wiki、RLE.Wiki、2345.lgbt 内容来源于 Project Trans：',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              '• MtF.Wiki、FtM.Wiki、RLE.Wiki 的网站内容采用\n'
              '  「署名—相同方式共享 4.0 协议国际版（CC BY-SA 4.0）」进行许可。',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              '• FtM.Wiki 的源代码采用 LGPLv3 许可证进行许可。',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                children: [
                  const TextSpan(text: '• MioMtFWiki（'),
                  TextSpan(
                    text: 'kitsumio.github.io/MioMtFWiki',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF5A9B8) : Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse(
                            'https://kitsumio.github.io/MioMtFWiki/'));
                      },
                  ),
                  const TextSpan(
                    text: '）内容采用「署名—禁止演绎 4.0 协议国际版（CC BY-ND 4.0）」进行许可。',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '允许转载、镜像、离线打包和重新分发；允许转换格式、建立索引、'
              '全文搜索、响应式排版等技术性处理；允许在应用程序中集成和展示；允许商业传播。'
              '但不得修改、删减、重写或翻译后再次发布项目内容。使用时须保留来源信息、'
              '标明 MioMtFWiki 项目链接并保留协议声明。',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              '您在分享、修改或二次发布相关内容时，须遵守相应协议要求，'
              '包括署名原作者、注明许可协议，并以相同方式共享衍生作品。',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
