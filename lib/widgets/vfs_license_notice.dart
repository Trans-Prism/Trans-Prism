import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 嗓音训练模块的开源许可证声明
///
/// 遵循 VFS Tracker 项目的 CC BY-NC-SA 4.0 许可证。
/// 支持一键关闭：本次会话隐藏 或 永久隐藏。
class VfsLicenseNotice extends StatefulWidget {
  const VfsLicenseNotice({super.key});

  @override
  State<VfsLicenseNotice> createState() => _VfsLicenseNoticeState();
}

class _VfsLicenseNoticeState extends State<VfsLicenseNotice> {
  bool _visible = true;
  bool _initialised = false;

  static const _prefsKey = 'vfs_license_dismissed_permanently';

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

    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '开源许可证声明',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800),
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
              '嗓音训练模块基于 VFS Tracker 项目开发，遵循 '
              'Attribution-NonCommercial-ShareAlike 4.0 International Public License '
              '(CC BY-NC-SA 4.0) 进行许可。',
              style: TextStyle(
                  fontSize: 13, height: 1.55, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        const Text('https://github.com/Ethanlita/vfs-tracker'),
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(label: '复制', onPressed: () {}),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, size: 12, color: Colors.blue),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text('https://github.com/Ethanlita/vfs-tracker',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '您在分享、修改或二次发布相关内容时，须遵守 CC BY-NC-SA 4.0 协议要求，'
              '包括署名原作者、注明许可协议、非商业使用，并以相同方式共享衍生作品。',
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
