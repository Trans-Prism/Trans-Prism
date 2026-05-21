import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/wiki_config.dart';
import '../storage/wiki_sync_store.dart';
import 'dns_safe_network_service.dart';

/// 与 GitHub 源码版本对比后的展示策略
enum WikiCacheStrategy {
  /// 源码未变或无法连 GitHub：优先 WebView 磁盘缓存
  preferLocal,

  /// 源码已更新：先展示在线站点，并在后台刷新缓存
  preferRemote,
}

class WikiSyncSnapshot {
  final WikiCacheStrategy strategy;
  final String? remoteFingerprint;
  final String? cachedFingerprint;
  final bool githubReachable;

  const WikiSyncSnapshot({
    required this.strategy,
    this.remoteFingerprint,
    this.cachedFingerprint,
    required this.githubReachable,
  });
}

/// 启动时后台戳 GitHub，对比 Wiki 源码版本
///
/// 使用抗 DNS 污染的 [DnsSafeNetworkService] 访问 GitHub API，
/// 防止因 DNS 劫持/污染导致版本校验失败。
class WikiSyncService {
  WikiSyncService._();

  static final WikiSyncService instance = WikiSyncService._();

  final WikiSyncStore _store = WikiSyncStore();
  final DnsSafeNetworkService _safeNet = DnsSafeNetworkService();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'TransToolbox-WikiSync',
      },
    ),
  );

  final Map<String, WikiSyncSnapshot> _snapshots = {};

  /// App 每次打开时在后台执行，不阻塞 UI
  void syncAllInBackground() {
    for (final wikiId in WikiCatalog.syncableIds) {
      unawaited(_refreshSnapshot(wikiId));
    }
  }

  WikiSyncSnapshot snapshotFor(String wikiId) {
    return _snapshots[wikiId] ??
        const WikiSyncSnapshot(
          strategy: WikiCacheStrategy.preferLocal,
          githubReachable: false,
        );
  }

  Future<WikiSyncSnapshot> resolveForOpen(String wikiId) async {
    if (_snapshots.containsKey(wikiId)) {
      return _snapshots[wikiId]!;
    }
    return _refreshSnapshot(wikiId);
  }

  Future<WikiSyncSnapshot> _refreshSnapshot(String wikiId) async {
    final config = WikiCatalog.require(wikiId);
    final cachedSha = await _store.getCachedSha(wikiId);

    if (!config.hasGithubSource) {
      final snap = WikiSyncSnapshot(
        strategy: WikiCacheStrategy.preferRemote,
        cachedFingerprint: cachedSha,
        githubReachable: true,
      );
      _snapshots[wikiId] = snap;
      return snap;
    }

    try {
      final remoteSha = await _fetchFingerprint(config);
      final isSame = cachedSha != null && cachedSha == remoteSha;
      final snap = WikiSyncSnapshot(
        strategy: isSame
            ? WikiCacheStrategy.preferLocal
            : WikiCacheStrategy.preferRemote,
        remoteFingerprint: remoteSha,
        cachedFingerprint: cachedSha,
        githubReachable: true,
      );
      _snapshots[wikiId] = snap;
      return snap;
    } catch (_) {
      final snap = WikiSyncSnapshot(
        strategy: WikiCacheStrategy.preferLocal,
        cachedFingerprint: cachedSha,
        githubReachable: false,
      );
      _snapshots[wikiId] = snap;
      return snap;
    }
  }

  /// WebView 在线页加载完成后，将本地指纹更新为远端（完成后台缓存对齐）
  Future<void> markContentCached(String wikiId, String fingerprint) async {
    await _store.saveCachedSha(wikiId, fingerprint);
    _snapshots[wikiId] = WikiSyncSnapshot(
      strategy: WikiCacheStrategy.preferLocal,
      remoteFingerprint: fingerprint,
      cachedFingerprint: fingerprint,
      githubReachable: true,
    );
  }

  Future<String> _fetchFingerprint(WikiConfig config) async {
    final contentSha = await _fetchCommitSha(config.githubCommitsApi);
    final frontendApi = config.frontendCommitsApi;
    if (frontendApi == null) return contentSha;
    final frontendSha = await _fetchCommitSha(frontendApi);
    return '${contentSha}_$frontendSha';
  }

  /// 通过抗 DNS 污染的方式获取 GitHub commit SHA
  Future<String> _fetchCommitSha(String apiUrl) async {
    // 优先使用 DnsSafeNetworkService（DoH 解析 → IP 直连）
    try {
      final body = await _safeNet.fetchSafe(apiUrl);
      // 从 JSON 响应中提取 sha 字段
      final decoded = _extractShaFromJson(body);
      if (decoded != null) return decoded;
    } catch (_) {
      // DoH 失败，降级到标准 DNS 直连
    }

    // 兜底：标准 DNS 直连
    final response = await _dio.get<Map<String, dynamic>>(apiUrl);
    final sha = response.data?['sha'];
    if (sha is! String || sha.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'GitHub 响应缺少 sha',
      );
    }
    return sha;
  }

  /// 从 DnsSafeNetworkService 返回的 JSON 字符串中提取 sha
  String? _extractShaFromJson(String body) {
    try {
      // 尝试解析最外层的 sha
      final map = _parseJsonMap(body);
      if (map == null) return null;
      final sha = map['sha'];
      if (sha is String && sha.isNotEmpty) return sha;
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseJsonMap(String body) {
    // 使用 dart:convert 解析
    try {
      // 简单的 JSON 解析：寻找第一个 '{' 和最后一个 '}'
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      final jsonStr = body.substring(start, end + 1);
      // 用 dart:convert 的 json.decode
      return (const JsonDecoder().convert(jsonStr) as Map<String, dynamic>?)
          ?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
