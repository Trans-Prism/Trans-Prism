import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wiki_config.dart';
import '../services/wiki_offline_service.dart';
import '../services/wiki_update_manager.dart';
import '../widgets/gradient_icon.dart';
import '../widgets/wiki_license_notice.dart';
import 'offline_wiki_screen.dart';
import 'wiki_web_screen.dart';

/// =============================================================================
/// WikiTab — 百科 Tab
///
/// 展示 MtF.Wiki / FtM.Wiki / RLE.Wiki 等知识库列表及离线开关。
/// 原为 ResourceLibraryScreen._WikiListTab，现直接作为独立 Tab。
/// =============================================================================
class WikiTab extends StatefulWidget {
  final String identity;

  const WikiTab({super.key, required this.identity});

  @override
  State<WikiTab> createState() => _WikiTabState();
}

class _WikiTabState extends State<WikiTab> {
  /// 离线开关状态缓存
  final Map<String, bool> _offlineEnabled = {};

  /// 当前离线版本日期缓存
  final Map<String, String?> _offlineVersions = {};

  /// 静默下载中标记
  final Map<String, bool> _updating = {};

  /// 下载进度状态：null = 不在下载，0.0~1.0 = 下载中
  final Map<String, double?> _downloadProgress = {};

  /// 下载状态文字
  final Map<String, String> _downloadStatus = {};

  /// Wiki 配置：显示标题 → (wikiType, localSiteDirName, localIndexPath, onlineUrl)
  static const _wikiConfigs = {
    'MtF.Wiki': (
      'mtf',
      'mtf-wiki-site',
      '/zh-cn/docs/index.html',
      'https://mtf.wiki/zh-cn/',
    ),
    'FtM.Wiki': (
      'ftm',
      'ftm-wiki-site',
      '/index.html',
      'https://ftm.wiki/zh-cn/',
    ),
    'RLE.Wiki': (
      'rle',
      'rle-wiki-site',
      '/index.html',
      'https://rle.wiki/',
    ),
    'MioMtFWiki': (
      'miomtfwiki',
      'miomtfwiki-wiki-site',
      '/index.html',
      'https://kitsumio.github.io/MioMtFWiki/',
    ),
  };

  static const _prefsWikiHintDismissed = 'wiki_offline_hint_dismissed_forever';

  @override
  void initState() {
    super.initState();
    _loadOfflineStates();
  }

  /// 异步加载每个 wiki 的离线开关状态 + 版本信息
  Future<void> _loadOfflineStates() async {
    for (final displayTitle in _wikiConfigs.keys) {
      final (wikiType, _, _, _) = _wikiConfigs[displayTitle]!;
      final enabled = await WikiOfflineService.isOfflineEnabled(wikiType);
      final version =
          enabled ? await WikiOfflineService.readVersion(wikiType) : null;
      if (mounted) {
        setState(() {
          _offlineEnabled[wikiType] = enabled;
          _offlineVersions[wikiType] = version;
        });
      }
    }
    // 加载完成后批量检查更新 + 首次引导
    _checkAndUpdateAll();
    _showOnboardingHint();
  }

  /// 首次进入 Wiki 列表页时的引导提示
  Future<void> _showOnboardingHint() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsWikiHintDismissed) == true) return;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_for_offline, color: Color(0xFF5BCEFA)),
            SizedBox(width: 8),
            Text('离线版下载'),
          ],
        ),
        content: const Text(
          '每个知识库右侧的「下载」开关可开启离线版。\n\n'
          '开启后会自动下载最新离线包，之后即使没有网络也能正常阅读。\n\n'
          '如需关闭，再次点击开关即可删除离线数据。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('本次关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setBool(_prefsWikiHintDismissed, true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5BCEFA),
            ),
            child: const Text('不再提示'),
          ),
        ],
      ),
    );
  }

  /// 批量检查所有已开启离线的 wiki 是否有更新
  Future<void> _checkAndUpdateAll() async {
    for (final displayTitle in _wikiConfigs.keys) {
      final (wikiType, _, _, _) = _wikiConfigs[displayTitle]!;
      if (!(_offlineEnabled[wikiType] ?? false)) continue;

      final result = await WikiUpdateManager().checkForUpdate(wikiType);
      if (result == null || !mounted) continue;

      final (latestDate, downloadUrl) = result;
      if (_updating[wikiType] == true) continue; // 已在更新中

      setState(() => _updating[wikiType] = true);

      final success = await WikiUpdateManager()
          .downloadUpdateSilently(wikiType, downloadUrl, latestDate);

      if (!mounted) return;

      setState(() {
        _updating[wikiType] = false;
        if (success) {
          _offlineVersions[wikiType] = latestDate;
        }
      });

      if (success) {
        _showSnackBar('$displayTitle 已更新至 $latestDate');
      }
    }
  }

  /// 获取 wiki 类型对应的显示标题
  String? _displayTitleForType(String wikiType) {
    for (final entry in _wikiConfigs.entries) {
      final (wt, _, _, _) = entry.value;
      if (wt == wikiType) return entry.key;
    }
    return null;
  }

  /// 处理离线开关切换
  Future<void> _handleOfflineToggle(String wikiType, bool newValue) async {
    if (newValue) {
      // ── 开启离线模式：触发下载 ──
      await _startDownload(wikiType);
    } else {
      // ── 关闭离线模式：确认弹窗 → 删除 ──
      await _confirmDisableOffline(wikiType);
    }
  }

  /// 开启离线：前台下载带进度
  Future<void> _startDownload(String wikiType) async {
    setState(() {
      _downloadProgress[wikiType] = 0.0;
      _downloadStatus[wikiType] = '准备中...';
    });

    final success = await WikiUpdateManager().downloadWithProgress(
      wikiType,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _downloadProgress[wikiType] = progress);
        }
      },
      onStatus: (status) {
        if (mounted) {
          setState(() => _downloadStatus[wikiType] = status);
        }
      },
    );

    if (!mounted) return;

    if (success) {
      await WikiOfflineService.setOfflineEnabled(wikiType, true);
      setState(() {
        _offlineEnabled[wikiType] = true;
        _downloadProgress.remove(wikiType);
        _downloadStatus.remove(wikiType);
      });
      _showSnackBar('${_displayTitleForType(wikiType) ?? wikiType} 离线版已就绪');
    } else {
      setState(() {
        _downloadProgress.remove(wikiType);
        _downloadStatus.remove(wikiType);
      });
      _showSnackBar('下载失败，请检查网络后重试');
    }
  }

  /// 关闭离线：确认弹窗
  Future<void> _confirmDisableOffline(String wikiType) async {
    // 计算预计节省空间
    final sizeStr =
        await WikiOfflineService.getOfflineDiskSizeFormatted(wikiType);
    final displayTitle = _displayTitleForType(wikiType) ?? wikiType;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭离线版'),
        content: Text(
          '确定关闭 $displayTitle 离线版？\n\n'
          '删除后将节省约 $sizeStr 空间，'
          '但后续将无法离线访问该 Wiki。\n\n'
          '确定要关闭吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 删除离线数据
    await WikiOfflineService.deleteAllOfflineData(wikiType);
    await WikiOfflineService.setOfflineEnabled(wikiType, false);

    setState(() {
      _offlineEnabled[wikiType] = false;
    });

    _showSnackBar('已删除 $displayTitle 离线版，节省约 $sizeStr 空间');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        // ── 根据身份显示对应 Wiki ──
        if (widget.identity == 'mtf') ...[
          _buildWikiTile('MtF.Wiki', '跨性别女性进阶指南 (推荐)', Icons.star),
          _buildWikiTile('RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book),
          _buildWikiTile('MioMtFWiki', '社区驱动的跨性别知识项目', Icons.auto_stories),
        ],
        if (widget.identity == 'ftm') ...[
          _buildWikiTile('FtM.Wiki', '跨性别男性进阶指南 (推荐)', Icons.star),
          _buildWikiTile('RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book),
        ],
        if (widget.identity == 'nb') ...[
          _buildWikiTile('MtF.Wiki', '跨性别女性进阶指南', Icons.star),
          _buildWikiTile('FtM.Wiki', '跨性别男性进阶指南', Icons.star),
          _buildWikiTile('RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book),
          _buildWikiTile('MioMtFWiki', '社区驱动的跨性别知识项目', Icons.auto_stories),
        ],
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            '其他参考资源',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
        if (widget.identity == 'ftm')
          _buildWikiTile('MtF.Wiki (已折叠)', '跨性别女性指南', Icons.folder_open),
        if (widget.identity == 'mtf')
          _buildWikiTile('FtM.Wiki (已折叠)', '跨性别男性指南', Icons.folder_open),
        if (widget.identity == 'ftm')
          _buildWikiTile('MioMtFWiki', '社区驱动的跨性别知识项目', Icons.auto_stories),
        _buildWikiTile('2345.lgbt', '跨性别友好资源导航页', Icons.explore),
        _buildWikiTile('维基百科 (Wikipedia)', '中文维基百科跨性别词条', Icons.language),
        const WikiLicenseNotice(),
      ],
    );
  }

  Widget _buildWikiTile(
    String displayTitle,
    String subtitle,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 判断是否为可离线的 wiki
    final hasOffline = _wikiConfigs.containsKey(displayTitle);
    final wikiType = hasOffline ? _wikiConfigs[displayTitle]!.$1 : null;

    // 下载进度
    final downloading =
        wikiType != null && _downloadProgress.containsKey(wikiType);
    final progress = wikiType != null ? _downloadProgress[wikiType] : null;
    final statusText = wikiType != null ? _downloadStatus[wikiType] : null;

    // 静默更新中
    final updating = wikiType != null && (_updating[wikiType] ?? false);

    // 离线开关状态（仅对可离线 wiki 有效）
    final switchValue =
        wikiType != null ? (_offlineEnabled[wikiType] ?? false) : false;

    // 版本信息
    final version = wikiType != null ? _offlineVersions[wikiType] : null;

    // 动态 subtitle
    String effectiveSubtitle = subtitle;
    if (updating) {
      effectiveSubtitle = '正在更新...';
    } else if (switchValue && version != null) {
      effectiveSubtitle = '离线版 · $version';
    }

    Widget trailing;
    if (downloading) {
      // 下载中：显示进度条 + 状态文字
      trailing = SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress != null)
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 3,
                ),
              ),
            if (statusText != null)
              Text(
                statusText,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    } else if (updating) {
      // 静默更新中：小进度圈
      trailing = const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    } else if (hasOffline) {
      // 可离线的 wiki：显示 Switch + 提示文字
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            switchValue ? '当前模式：离线' : '当前模式：在线',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: switchValue ? '已开启离线版' : '点击开启离线版下载',
            child: Transform.scale(
              scale: 0.75,
              child: CupertinoSwitch(
                value: switchValue,
                onChanged: (v) => _handleOfflineToggle(wikiType!, v),
                activeColor: const Color(0xFF5BCEFA),
              ),
            ),
          ),
        ],
      );
    } else {
      // 不可离线的 wiki：显示箭头
      trailing = Icon(Icons.chevron_right,
          color: isDark ? Colors.grey.shade600 : null);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: ListTile(
        leading: GradientIcon(icon, size: 28),
        title: Text(displayTitle,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF5F5F7) : null)),
        subtitle: Text(effectiveSubtitle,
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.grey.shade400 : null)),
        trailing: trailing,
        onTap: () => _openWikiReader(context, displayTitle),
      ),
    );
  }

  void _openWikiReader(BuildContext context, String displayTitle) {
    // 可离线的 wiki（MtF / FtM / RLE）→ 统一 OfflineWikiScreen
    if (_wikiConfigs.containsKey(displayTitle)) {
      final (wikiType, siteDir, indexPath, onlineUrl) =
          _wikiConfigs[displayTitle]!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfflineWikiScreen(
            wikiType: wikiType,
            title: displayTitle,
            onlineUrl: onlineUrl,
            localSiteDirName: siteDir,
            localIndexPath: indexPath,
          ),
        ),
      );
      return;
    }

    // 其他 wiki → WikiWebScreen
    final config = WikiCatalog.fromDisplayTitle(displayTitle);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂不支持该知识库')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WikiWebScreen(
          wikiId: config.id,
          title: displayTitle,
        ),
      ),
    );
  }
}
