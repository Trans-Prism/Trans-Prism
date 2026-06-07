import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

import '../models/resource_item.dart';
import '../models/wiki_config.dart';
import '../services/permission_manager.dart';
import '../services/resource_service.dart';
import '../services/wiki_offline_service.dart';
import '../services/wiki_update_manager.dart';
import '../widgets/wiki_license_notice.dart';
import 'offline_wiki_screen.dart';
import 'wiki_web_screen.dart';
import 'svg_preview_screen.dart';

/// =============================================================================
/// ResourceLibraryScreen — 资源库主页
///
/// 包含两个 Tab：
///   - 知识库 (Wiki)：原有 WikiListPage 逻辑，展示 MtF.Wiki / FtM.Wiki 等
///   - 图解资源 (SVG)：展示本地内置 SVG 资源的网格列表
/// =============================================================================
class ResourceLibraryScreen extends StatefulWidget {
  final String identity;

  const ResourceLibraryScreen({super.key, required this.identity});

  @override
  State<ResourceLibraryScreen> createState() => _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends State<ResourceLibraryScreen> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final themeColor = const Color(0xFF5BCEFA);

    // ── 与下方卡片边距完全对齐 (卡片使用 EdgeInsets.all(16)) ──
    const double contentPadding = 16;

    // ── 深色模式配色：极简奢华 ──
    // 底座：比 scaffold 背景略深一点
    final Color segBg =
        isDark ? const Color(0xFF1A1A1E) : const Color(0xFFE8E8ED);
    // 滑块：微凸起质感深灰（绝不使用主题色）
    final Color segThumb = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '资源库',
          style: TextStyle(color: textColor),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: contentPadding),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  // primaryColor 控制选中文字颜色，不影响 thumbColor
                  primaryColor: themeColor,
                  brightness: isDark ? Brightness.dark : Brightness.light,
                ),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedSegment,
                  thumbColor: segThumb,
                  backgroundColor: segBg,
                  onValueChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSegment = value);
                    }
                  },
                  children: <int, Widget>{
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '知识库',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedSegment == 0
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedSegment == 0
                              ? themeColor
                              : (isDark
                                  ? const Color(0xFF636366)
                                  : const Color(0xFF8E8E93)),
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '图解资源',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedSegment == 1
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedSegment == 1
                              ? themeColor
                              : (isDark
                                  ? const Color(0xFF636366)
                                  : const Color(0xFF8E8E93)),
                        ),
                      ),
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedSegment,
        children: [
          _WikiListTab(identity: widget.identity),
          _SvgResourceTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: 知识库 (Wiki) — 从 main.dart WikiListPage 迁移
// =============================================================================

class _WikiListTab extends StatefulWidget {
  final String identity;

  const _WikiListTab({required this.identity});

  @override
  State<_WikiListTab> createState() => _WikiListTabState();
}

class _WikiListTabState extends State<_WikiListTab> {
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
      padding: const EdgeInsets.all(16),
      children: [
        // ── 根据身份显示对应 Wiki ──
        if (widget.identity == 'mtf') ...[
          _buildWikiTile('MtF.Wiki', '跨性别女性进阶指南 (推荐)', Icons.star, Colors.pink),
          _buildWikiTile(
              'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book, Colors.blueGrey),
        ],
        if (widget.identity == 'ftm') ...[
          _buildWikiTile('FtM.Wiki', '跨性别男性进阶指南 (推荐)', Icons.star, Colors.blue),
          _buildWikiTile(
              'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book, Colors.blueGrey),
        ],
        if (widget.identity == 'nb') ...[
          _buildWikiTile('MtF.Wiki', '跨性别女性进阶指南', Icons.star, Colors.pink),
          _buildWikiTile('FtM.Wiki', '跨性别男性进阶指南', Icons.star, Colors.blue),
          _buildWikiTile(
              'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book, Colors.blueGrey),
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
          _buildWikiTile(
              'MtF.Wiki (已折叠)', '跨性别女性指南', Icons.folder_open, Colors.grey),
        if (widget.identity == 'mtf')
          _buildWikiTile(
              'FtM.Wiki (已折叠)', '跨性别男性指南', Icons.folder_open, Colors.grey),
        _buildWikiTile('2345.lgbt', '跨性别友好资源导航页', Icons.explore, Colors.teal),
        _buildWikiTile(
            '维基百科 (Wikipedia)', '中文维基百科跨性别词条', Icons.language, Colors.grey),
        const WikiLicenseNotice(),
      ],
    );
  }

  Widget _buildWikiTile(
    String displayTitle,
    String subtitle,
    IconData icon,
    Color color,
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
              color: switchValue
                  ? const Color(0xFF5BCEFA)
                  : (isDark ? Colors.grey.shade500 : Colors.grey),
            ),
          ),
          Tooltip(
            message: switchValue ? '已开启离线版' : '点击开启离线版下载',
            child: Switch(
              value: switchValue,
              onChanged: (v) => _handleOfflineToggle(wikiType!, v),
              activeColor: const Color(0xFF5BCEFA),
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
        leading: Icon(icon, color: color),
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

// =============================================================================
// Tab 2: 图解资源 (SVG Resource Grid)
// =============================================================================

class _SvgResourceTab extends StatefulWidget {
  @override
  State<_SvgResourceTab> createState() => _SvgResourceTabState();
}

class _SvgResourceTabState extends State<_SvgResourceTab> {
  List<ResourceItem> _allResources = [];
  List<ResourceItem> _filteredResources = [];
  bool _isLoading = true;

  /// 搜索关键词
  String _searchQuery = '';

  /// 当前厂牌样式
  String _preferredStyle = 'twemoji';

  /// 厂牌显示名称映射
  static const Map<String, String> _styleLabels = {
    'twemoji': 'Twemoji (推特风)',
    'openmoji': 'OpenMoji (极简风)',
    'noto': 'Noto (谷歌风)',
  };

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    if (!ResourceService().isInitialized) {
      await ResourceService().initialize();
    }
    // ── 进入图解资源页面：静默查询相册/存储权限，无则索要 ──
    if (!await PermissionManager().checkStoragePermission()) {
      await PermissionManager().requestStoragePermission();
    }
    if (mounted) {
      setState(() {
        _allResources = ResourceService().allResources;
        _filteredResources = _allResources;
        _isLoading = false;
      });
    }
  }

  /// 执行搜索
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredResources = ResourceService().searchResources(query);
    });
  }

  /// 显示厂牌切换 BottomSheet
  void _showStylePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 拖拽指示条 ──
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '选择图标风格',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ..._styleLabels.entries.map((entry) {
                final selected = _preferredStyle == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: selected
                          ? const BorderSide(
                              color: Color(0xFF5BCEFA), width: 1.5)
                          : BorderSide.none,
                    ),
                    tileColor: selected
                        ? const Color(0xFF5BCEFA).withOpacity(0.06)
                        : (isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey.shade50),
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? const Color(0xFF5BCEFA) : textColor,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF5BCEFA), size: 22)
                        : null,
                    onTap: () {
                      setState(() => _preferredStyle = entry.key);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── 搜索与控制栏 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              // 搜索框
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: '搜索资源...',
                    onChanged: _performSearch,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFF5F5F7)
                          : const Color(0xFF1D1D1F),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 厂牌切换按钮
              SizedBox(
                height: 36,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => _showStylePicker(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.style,
                        size: 16,
                        color: isDark
                            ? const Color(0xFFF5F5F7)
                            : const Color(0xFF1D1D1F),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _styleLabels[_preferredStyle] ?? _preferredStyle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFF5F5F7)
                              : const Color(0xFF1D1D1F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 资源网格 + 许可页脚 ──
        Expanded(
          child: _filteredResources.isEmpty
              ? _buildEmptyState(context)
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.95,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final resource = _filteredResources[index];
                            return _SvgResourceCard(
                              resource: resource,
                              isDark: isDark,
                              preferredStyle: _preferredStyle,
                            );
                          },
                          childCount: _filteredResources.length,
                        ),
                      ),
                    ),
                    // 页脚：SVG 图标来源许可声明
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '图标来源许可',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF636366)
                                    : const Color(0xFF8E8E93),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _licenseText(
                              'Twemoji (推特) — CC-BY 4.0',
                              isDark,
                            ),
                            const SizedBox(height: 4),
                            _licenseText(
                              'OpenMoji (开源社区) — CC BY-SA 4.0',
                              isDark,
                            ),
                            const SizedBox(height: 4),
                            _licenseText(
                              'Google Noto Emoji — Apache License 2.0',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _licenseText(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.image_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配资源' : '暂无图解资源',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '尝试其他关键词搜索',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SVG 资源卡片（高密度 Quiet Luxury）
class _SvgResourceCard extends StatelessWidget {
  final ResourceItem resource;
  final bool isDark;
  final String preferredStyle;

  const _SvgResourceCard({
    required this.resource,
    required this.isDark,
    required this.preferredStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isDark ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SvgPreviewScreen(
                allResources: [resource],
                initialIndex: 0,
                initialStyle: preferredStyle,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── SVG 图标区域（居中） ──
              Expanded(
                child: SvgPicture.asset(
                  resource.getSvgPath(preferredStyle: preferredStyle),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              // ── 名称标签（居中，紧凑） ──
              Text(
                resource.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF98989E)
                      : const Color(0xFF8E8E93),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
