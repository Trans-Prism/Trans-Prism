import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/medical_directory.dart';
import '../../services/medical_directory_service.dart';
import '../../widgets/loading_indicator.dart';
import 'institution_detail_screen.dart';

/// 友善医疗名录 — 主列表页面
class MedicalDirectoryListScreen extends StatefulWidget {
  const MedicalDirectoryListScreen({super.key});

  @override
  State<MedicalDirectoryListScreen> createState() =>
      _MedicalDirectoryListScreenState();
}

class _MedicalDirectoryListScreenState
    extends State<MedicalDirectoryListScreen> {
  final MedicalDirectoryService _service = MedicalDirectoryService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedDepartment = '';
  List<FriendlyInstitution>? _searchResults;
  bool _favoritesOnly = false;

  bool _isLoading = true;
  String? _errorMessage;

  /// 同步状态
  bool _isSyncing = false;
  SyncResult? _syncResult;

  static const String _disclaimerKey = 'medical_directory_disclaimer_dismissed';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _service.init();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncResult = _service.lastSyncResult;
        });
      }
      _checkDisclaimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载数据失败: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FriendlyInstitution> get _displayList {
    var list = _service.allInstitutions;
    if (_favoritesOnly) {
      list = list.where((i) => i.isFavorite).toList();
    }
    if (_selectedDepartment.isNotEmpty) {
      list = _service.filterByDepartment(_selectedDepartment);
    }
    if (_searchResults != null) {
      return _searchResults!;
    }
    return list;
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _searchResults = null;
      } else {
        _searchResults = _service.search(query).institutions;
      }
    });
  }

  Future<void> _toggleFavorite(String id) async {
    await _service.toggleFavorite(id);
    setState(() {});
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    final result = await _service.checkAndSync();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _syncResult = result;
    });
    final icon = switch (result.status) {
      SyncStatus.upToDate => Icons.check_circle,
      SyncStatus.updated => Icons.cloud_done,
      SyncStatus.githubUnreachable => Icons.cloud_off,
    };
    final color = switch (result.status) {
      SyncStatus.upToDate => Colors.green,
      SyncStatus.updated => const Color(0xFFF5A9B8),
      SyncStatus.githubUnreachable => Colors.orange,
    };
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(result.message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _checkDisclaimer() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_disclaimerKey) ?? false;
    if (dismissed) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFFFB74D)),
            SizedBox(width: 8),
            Text('友善医疗名录'),
          ],
        ),
        content: const Text(
          '本名录功能尚在开发中，当前数据来源于 mtf.wiki 等社区 Wiki，'
          '内容可能不完整或不准确，仅供参考。\n\n'
          '最终医疗决策请咨询专业医师。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('本次关闭'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB74D),
            ),
            onPressed: () async {
              await prefs.setBool(_disclaimerKey, true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('以后关闭'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '友善医疗名录',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
                tooltip: '检查更新',
                onPressed: _isSyncing ? null : _manualSync,
              ),
              if (_syncResult != null && !_isSyncing)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (_syncResult!.status) {
                        SyncStatus.upToDate => Colors.green,
                        SyncStatus.updated => const Color(0xFFF5A9B8),
                        SyncStatus.githubUnreachable => Colors.orange,
                      },
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadData();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final list = _displayList;
    return Column(
      children: [
        if (_syncResult != null &&
            _syncResult!.status == SyncStatus.githubUnreachable)
          _buildOfflineBanner(),
        _buildSearchBar(),
        _buildFilterBar(),
        _buildResultInfo(list.length),
        Expanded(child: _buildGroupedList(list)),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isDark
          ? const Color(0xFF3E2723).withOpacity(0.6)
          : Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade400),
          const SizedBox(width: 6),
          Text(
            '无法连接 GitHub，使用本地缓存数据',
            style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? Colors.orange.shade300 : Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: '搜索机构、城市、医生、标签...',
          hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          prefixIcon: Icon(Icons.search,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF24242C) : Colors.grey.shade100,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final departments = _service.availableDepartments;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _buildFilterChip('全部', '', departments.isEmpty),
          ...departments.map((d) => _buildFilterChip(d.label, d.id, false)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String id, bool isOnly) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedDepartment == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86)),
          ),
        ),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedDepartment = selected ? '' : id);
        },
        backgroundColor: isDark ? const Color(0xFF24242C) : Colors.white,
        selectedColor: const Color(0xFFF5A9B8),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: selected
              ? const Color(0xFFF5A9B8)
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildResultInfo(int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Text(
            '共 $count 家机构',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: _favoritesOnly
                      ? const Color(0xFFF5A9B8)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '仅收藏',
                  style: TextStyle(
                    fontSize: 12,
                    color: _favoritesOnly
                        ? const Color(0xFFF5A9B8)
                        : Colors.grey.shade500,
                    fontWeight:
                        _favoritesOnly ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<FriendlyInstitution> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = MedicalDirectoryService.groupByProvince(list);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _favoritesOnly ? '还没有收藏的机构' : '没有找到匹配的机构',
              style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final entry in grouped.entries) ...[
          _buildProvinceHeader(entry.key),
          for (final institution in entry.value)
            _buildInstitutionCard(institution),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildProvinceHeader(String province) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            province,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionCard(FriendlyInstitution institution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? const Color(0xFF24242C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isDark ? const Color(0xFF333338) : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(institution),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      institution.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFEDEDF0)
                            : const Color(0xFF333333),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleFavorite(institution.id),
                    child: Icon(
                      institution.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: institution.isFavorite
                          ? const Color(0xFFF5A9B8)
                          : (isDark
                              ? const Color(0xFF6B6B76)
                              : Colors.grey.shade300),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 13,
                      color: isDark
                          ? const Color(0xFF6B6B76)
                          : Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '${institution.city}${institution.address != null ? ' · ${institution.address}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF8E8E96)
                          : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: institution.departments.map((d) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5A9B8).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      d.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF5A9B8),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (institution.tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: institution.tags.map((tag) {
                    return Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF6B6B76)
                            : Colors.grey.shade400,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(FriendlyInstitution institution) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstitutionDetailScreen(
          institution: institution,
          onFavoriteToggled: () => setState(() {}),
        ),
      ),
    ).then((_) => setState(() {}));
  }
}
