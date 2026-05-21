import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 血药浓度模拟模块的开源许可证声明
///
/// 支持一键关闭：本次会话隐藏 或 永久隐藏（persist 到 shared_preferences）
class PKLicenseNotice extends StatefulWidget {
  const PKLicenseNotice({super.key});

  @override
  State<PKLicenseNotice> createState() => _PKLicenseNoticeState();
}

class _PKLicenseNoticeState extends State<PKLicenseNotice> {
  bool _visible = true;
  bool _initialised = false;

  static const _prefsKey = 'pk_license_dismissed_permanently';

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
        title: const Text('关闭开源声明'),
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

    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '开源许可证声明',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary),
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
            const SizedBox(height: 8),
            const Text(
              '血药浓度模拟模块的 PK 计算算法来自以下开源项目，遵循其原始许可证条款使用。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            _buildLinkRow('HRT-Recorder-PKcomponent-Test',
                'https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test'),
            const SizedBox(height: 4),
            _buildLinkRow('HRT-Recorder-online',
                'https://github.com/LaoZhong-Mihari/HRT-Recorder-online'),
            const SizedBox(height: 6),
            Text(
              '包含算法：三室模型解析解 · 两库注射动力学 · Bateman 口服模型 · 舌下双通路模型 · 贴片零阶/一阶输入模型',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkRow(String title, String url) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(url),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(label: '复制', onPressed: () {}),
          ),
        );
      },
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 12, color: Colors.blue),
          const SizedBox(width: 4),
          Flexible(
            child: Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
