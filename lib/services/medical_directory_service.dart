import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/medical_directory.dart';
import '../storage/medical_directory_repository.dart';
import 'dns_safe_network_service.dart';

/// 友善医疗名录 — 服务层
///
/// 职责：
/// 1. 加载种子数据 + 本地缓存，合并后统一暴露
/// 2. 提供搜索、按科室筛选、按省份分组等查询能力
/// 3. GitHub 版本同步：戳 GitHub Commits API 比对 SHA → 有更新则拉取 raw JSON → 缓存本地
/// 4. 管理收藏状态（委托给 Repository）
///
/// 数据同步策略（与 WikiSyncService 一致）：
/// - 优先使用 DnsSafeNetworkService 抗 DNS 污染访问 GitHub API
/// - 失败则 Dio 标准 DNS 直连兜底
/// - GitHub 不可达时使用本地缓存，首次安装无缓存则用种子数据
class MedicalDirectoryService {
  MedicalDirectoryService._internal();
  static final MedicalDirectoryService _instance =
      MedicalDirectoryService._internal();
  factory MedicalDirectoryService() => _instance;

  final MedicalDirectoryRepository _repository = MedicalDirectoryRepository();
  final DnsSafeNetworkService _safeNet = DnsSafeNetworkService();

  List<FriendlyInstitution> _allInstitutions = [];
  bool _initialized = false;

  /// 获取所有机构列表（已合并收藏状态）
  List<FriendlyInstitution> get allInstitutions =>
      List.unmodifiable(_allInstitutions);

  // ---------- GitHub 仓库配置 ----------

  // medical_directory.json 存放在项目仓库根目录
  // 维护者定期更新此文件即可，客户端启动时会自动比对 SHA 并拉取
  static const String _githubOwner = 'daanser';
  static const String _githubRepo = 'Trans-Prism';
  static const String _githubBranch = 'main';
  static const String _dataFilePath = 'medical_directory.json';

  /// GitHub Commits API: 获取最新 commit SHA
  static String get _commitsApiUrl =>
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/commits/$_githubBranch';

  /// GitHub Raw Content URL: 直接下载 JSON 文件
  static String get _rawJsonUrl =>
      'https://raw.githubusercontent.com/$_githubOwner/$_githubRepo/$_githubBranch/$_dataFilePath';

  /// 上次同步结果
  SyncResult? _lastSyncResult;

  SyncResult? get lastSyncResult => _lastSyncResult;

  // ---------- 初始化 ----------

  /// 初始化：加载种子数据 + 缓存数据 + 应用收藏状态
  ///
  /// 启动时自动在后台执行 [checkAndSync]，不阻塞 UI。
  Future<void> init() async {
    if (_initialized) return;

    // 1. 加载种子数据（兜底）
    final seedList = await _repository.loadSeedData();

    // 2. 加载远程缓存
    final cachedList = await _repository.loadCachedData();

    // 3. 合并：缓存优先于种子（远程数据更完整/更新）
    final mergedMap = <String, FriendlyInstitution>{};
    for (final inst in seedList) {
      mergedMap[inst.id] = inst;
    }
    if (cachedList != null) {
      for (final inst in cachedList) {
        // 缓存版本覆盖种子版本的同 id 记录
        mergedMap[inst.id] = inst;
      }
    }

    // 4. 应用收藏状态
    final favoriteIds = await _repository.getFavoriteIds();
    for (final inst in mergedMap.values) {
      inst.isFavorite = favoriteIds.contains(inst.id);
    }

    _allInstitutions = mergedMap.values.toList();
    _initialized = true;

    // 5. 后台异步检查 GitHub 更新（不阻塞 UI）
    unawaited(checkAndSync());
  }

  // ---------- GitHub 版本同步 ----------

  /// 检查 GitHub 是否有更新，有则拉取新数据
  ///
  /// 返回 [SyncResult] 描述同步结果。
  Future<SyncResult> checkAndSync() async {
    try {
      // 1. 戳 GitHub 获取最新 commit SHA
      final remoteSha = await _fetchRemoteCommitSha();

      // 2. 对比本地 SHA
      final cachedSha = await _repository.loadCachedSha();
      if (cachedSha != null && cachedSha == remoteSha) {
        _lastSyncResult = const SyncResult(
          status: SyncStatus.upToDate,
          githubReachable: true,
        );
        return _lastSyncResult!;
      }

      // 3. SHA 不同 → 下载新 JSON
      final institutions = await _fetchAndParseRawJson();

      // 4. 缓存新数据 + 新 SHA
      await _repository.saveCachedData(institutions);
      await _repository.saveCachedSha(remoteSha);

      // 5. 合并到内存（保留收藏状态）
      final favoriteIds = await _repository.getFavoriteIds();
      final mergedMap = <String, FriendlyInstitution>{};
      for (final inst in _allInstitutions) {
        mergedMap[inst.id] = inst;
      }
      for (final inst in institutions) {
        inst.isFavorite = favoriteIds.contains(inst.id);
        mergedMap[inst.id] = inst;
      }
      _allInstitutions = mergedMap.values.toList();

      _lastSyncResult = SyncResult(
        status: SyncStatus.updated,
        githubReachable: true,
        institutionCount: institutions.length,
      );
      return _lastSyncResult!;
    } on SyncException catch (e) {
      // GitHub 不可达
      _lastSyncResult = SyncResult(
        status: e.shaCheckFailed
            ? SyncStatus.githubUnreachable
            : SyncStatus.githubUnreachable,
        githubReachable: false,
      );
      return _lastSyncResult!;
    } catch (e) {
      _lastSyncResult = const SyncResult(
        status: SyncStatus.githubUnreachable,
        githubReachable: false,
      );
      return _lastSyncResult!;
    }
  }

  /// 获取远程仓库最新 commit SHA
  ///
  /// 复用 WikiSyncService 的抗 DNS 污染模式：
  /// 1. DnsSafeNetworkService (DoH → IP 直连)
  /// 2. Dio 标准 DNS 直连兜底
  Future<String> _fetchRemoteCommitSha() async {
    // 方式 1: 抗 DNS 污染
    try {
      final body = await _safeNet.fetchSafe(_commitsApiUrl);
      final sha = _extractShaFromJson(body);
      if (sha != null && sha.isNotEmpty) return sha;
    } catch (_) {
      // 失败，降级到标准直连
    }

    // 方式 2: 标准 DNS 直连
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'TransToolbox-MedDir',
        },
      ));
      final response = await dio.get<Map<String, dynamic>>(_commitsApiUrl);
      final sha = response.data?['sha'];
      if (sha is String && sha.isNotEmpty) return sha;
      throw const SyncException('GitHub 响应缺少 sha', shaCheckFailed: true);
    } catch (e) {
      if (e is SyncException) rethrow;
      throw SyncException('无法访问 GitHub: $e', shaCheckFailed: true);
    }
  }

  /// 从 JSON 响应中提取 SHA
  String? _extractShaFromJson(String body) {
    try {
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      final jsonStr = body.substring(start, end + 1);
      final map = const JsonDecoder().convert(jsonStr) as Map<String, dynamic>?;
      final sha = map?['sha'];
      return (sha is String && sha.isNotEmpty) ? sha : null;
    } catch (_) {
      return null;
    }
  }

  /// 下载 raw JSON 并解析为机构列表
  Future<List<FriendlyInstitution>> _fetchAndParseRawJson() async {
    String rawJson;

    // 方式 1: 抗 DNS 污染
    try {
      rawJson = await _safeNet.fetchSafe(_rawJsonUrl);
    } catch (_) {
      // 方式 2: 标准直连
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/vnd.github.raw+json',
            'User-Agent': 'TransToolbox-MedDir',
          },
        ));
        final response = await dio.get(_rawJsonUrl);
        rawJson = response.data is String
            ? response.data as String
            : response.data.toString();
      } catch (e) {
        throw SyncException('无法下载数据文件: $e');
      }
    }

    try {
      final List<dynamic> jsonList = jsonDecode(rawJson) as List<dynamic>;
      return jsonList
          .map((e) => FriendlyInstitution.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw SyncException('JSON 解析失败: $e');
    }
  }

  /// 强制刷新并重建列表（用于 UI 手动触发同步后）
  Future<void> refresh() async {
    _lastSyncResult = null;
    await checkAndSync();
  }

  // ---------- 搜索结果 ----------

  /// 搜索结果：包含匹配的机构列表 + 高亮关键词
  SearchResult search(String query) {
    if (query.trim().isEmpty) {
      return SearchResult(
        institutions: _allInstitutions,
        highlight: '',
      );
    }

    final q = query.trim().toLowerCase();
    final matched = _allInstitutions.where((inst) {
      return inst.name.toLowerCase().contains(q) ||
          inst.city.toLowerCase().contains(q) ||
          inst.province.toLowerCase().contains(q) ||
          inst.tags.any((t) => t.toLowerCase().contains(q)) ||
          inst.departmentLabels.toLowerCase().contains(q) ||
          inst.notes?.toLowerCase().contains(q) == true ||
          inst.doctors.any((d) => d.name.toLowerCase().contains(q));
    }).toList();

    return SearchResult(
      institutions: matched,
      highlight: query.trim(),
    );
  }

  // ---------- 筛选 ----------

  /// 按科室类型筛选
  List<FriendlyInstitution> filterByDepartment(String departmentId) {
    if (departmentId.isEmpty) return _allInstitutions;
    return _allInstitutions
        .where((inst) => inst.departmentIds.contains(departmentId))
        .toList();
  }

  /// 按标签筛选（支持多标签交集）
  List<FriendlyInstitution> filterByTags(List<String> tags) {
    if (tags.isEmpty) return _allInstitutions;
    return _allInstitutions.where((inst) {
      return tags.every((t) =>
          inst.tags.any((tag) => tag.toLowerCase().contains(t.toLowerCase())));
    }).toList();
  }

  /// 仅查看收藏
  List<FriendlyInstitution> getFavorites() {
    return _allInstitutions.where((inst) => inst.isFavorite).toList();
  }

  /// 按省份分组
  static Map<String, List<FriendlyInstitution>> groupByProvince(
      List<FriendlyInstitution> institutions) {
    final grouped = <String, List<FriendlyInstitution>>{};
    for (final inst in institutions) {
      grouped.putIfAbsent(inst.province, () => []).add(inst);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final k in sortedKeys) k: grouped[k]!};
  }

  // ---------- 收藏操作 ----------

  /// 切换收藏状态，返回新的状态
  Future<bool> toggleFavorite(String institutionId) async {
    final newState = await _repository.toggleFavorite(institutionId);
    final idx = _allInstitutions.indexWhere((i) => i.id == institutionId);
    if (idx != -1) {
      _allInstitutions[idx].isFavorite = newState;
    }
    return newState;
  }

  /// 获取可用的省份列表
  List<String> get availableProvinces {
    final provinces = _allInstitutions.map((i) => i.province).toSet().toList();
    provinces.sort();
    return provinces;
  }

  /// 获取可用的科室类型列表
  List<DepartmentType> get availableDepartments {
    final ids =
        _allInstitutions.expand((i) => i.departmentIds).toSet().toList();
    return ids
        .map((id) => DepartmentType.fromId(id))
        .whereType<DepartmentType>()
        .toList();
  }
}

// ─── 同步结果模型 ───

/// GitHub 同步状态
enum SyncStatus {
  /// 数据已是最新（GitHub SHA 与本地一致）
  upToDate,

  /// 已拉取到新数据
  updated,

  /// GitHub 不可达，使用缓存/种子数据
  githubUnreachable,
}

/// 同步结果
class SyncResult {
  final SyncStatus status;
  final bool githubReachable;
  final int? institutionCount; // 仅 updated 时有值

  const SyncResult({
    required this.status,
    required this.githubReachable,
    this.institutionCount,
  });

  String get message {
    switch (status) {
      case SyncStatus.upToDate:
        return '数据已是最新';
      case SyncStatus.updated:
        return '已更新，共 ${institutionCount ?? 0} 家机构';
      case SyncStatus.githubUnreachable:
        return '无法连接 GitHub，已使用本地缓存数据';
    }
  }
}

/// 同步异常
class SyncException implements Exception {
  final String message;
  final bool shaCheckFailed;

  const SyncException(this.message, {this.shaCheckFailed = false});

  @override
  String toString() => 'SyncException: $message';
}

/// 搜索结果
class SearchResult {
  final List<FriendlyInstitution> institutions;
  final String highlight;

  const SearchResult({
    required this.institutions,
    required this.highlight,
  });
}
