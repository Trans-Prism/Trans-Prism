import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

import 'region_detector.dart';
import 'wiki_offline_service.dart';

/// 防爆全能版 Wiki 热更新引擎（阅后即焚版）
///
/// ## 下载流程
///
/// 1. 戳 GitHub API 获取最新 Release 下载链接 + 版本日期（tag）
/// 2. 多镜像站容错链下载
/// 3. 写版本日志 `.xxx-wiki-site.version`
/// 4. 删除旧 ZIP
/// 5. 重命名临时文件为 `xxx-wiki-site.zip`
///
/// ## 更新检查
///
/// [checkForUpdate] 比对本地版本日志与 GitHub API 最新 tag，
/// 返回是否有更新。由 WikiListPage 批量调用。
///
/// ## 镜像站容错链
///
/// 1. `ghp.ci` — 前缀代理
/// 2. `ghproxy.net` — 前缀代理
/// 3. `kkgithub.com` — 替换域名
/// 4. `githubfast.com` — 替换域名
class WikiUpdateManager {
  final String owner = "daanser";
  final String repo = "Trans-Prism-Builder";

  /// 镜像站容错链（按优先级排列）
  static const List<_MirrorDef> _mirrors = [
    _MirrorDef(prefix: 'https://ghp.ci/'),
    _MirrorDef(prefix: 'https://ghproxy.net/'),
    _MirrorDef(replaceHost: 'kkgithub.com'),
    _MirrorDef(replaceHost: 'githubfast.com'),
  ];

  static const Duration _mirrorConnectTimeout = Duration(seconds: 5);
  static const Duration _apiTimeout = Duration(seconds: 15);

  final Dio _dio = Dio();

  // ==================================================================
  // 版本日志（兼容旧方法，委托到 WikiOfflineService）
  // ==================================================================

  static Future<String?> readLocalTag(String wikiType) {
    return WikiOfflineService.readVersion(wikiType);
  }

  static Future<void> writeLocalTag(String wikiType, String tag) {
    return WikiOfflineService.writeVersion(wikiType, tag);
  }

  // ==================================================================
  // 沙盒检测（兼容旧代码）
  // ==================================================================

  static Future<bool> hasSandboxData(String wikiType) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/live_${wikiType}_site');
      if (!d.existsSync()) return false;
      return d.listSync(recursive: true).any((e) => e is File);
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getSandboxedSitePath(
      String wikiType, String siteSubDir) async {
    try {
      if (!await hasSandboxData(wikiType)) return null;
      final dir = await getApplicationDocumentsDirectory();
      final p = '${dir.path}/live_${wikiType}_site/$siteSubDir';
      if (Directory(p).existsSync()) {
        debugPrint("[$wikiType] 命中热更新缓存: $p");
        return p;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==================================================================
  // 后台静默热更新（兼容旧备份 screen）
  // ==================================================================

  Future<void> checkAndPerformHotUpdate(String wikiType) async {
    // 静默后台检测：有更新则下载新版 ZIP
    try {
      final result = await _fetchLatestRelease(wikiType);
      if (result == null) return;

      final (remoteTag, downloadUrl, _) = result;
      final localTag = await readLocalTag(wikiType);

      if (localTag != null) {
        final remoteDate = _extractDate(remoteTag);
        final localDate = _extractDate(localTag);
        if (remoteDate == null) return;
        if (localDate != null && !remoteDate.isAfter(localDate)) {
          return;
        }
      }

      await _downloadAndSaveZip(wikiType, downloadUrl, remoteTag, null, null);
    } catch (_) {}
  }

  // ==================================================================
  // 前台下载（用户主动开启离线时调用）
  // ==================================================================

  /// 前台带进度下载最新 Wiki 离线 ZIP。
  ///
  /// 流程：
  /// 1. GitHub API 获取最新 Release
  /// 2. 镜像链下载到 `offline_wiki/temp_{type}.zip`
  /// 3. 写版本日志
  /// 4. 删除旧 `xxx-wiki-site.zip`
  /// 5. 重命名 temp → `xxx-wiki-site.zip`
  Future<bool> downloadWithProgress(
    String wikiType, {
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('正在获取版本信息...');

    final result = await _fetchLatestRelease(wikiType);
    if (result == null) return false;

    final (remoteTag, downloadUrl, _) = result;
    return await _downloadAndSaveZip(
        wikiType, downloadUrl, remoteTag, onProgress, onStatus);
  }

  // ==================================================================
  // 静默检查更新（列表页批量调用）
  // ==================================================================

  /// 检查指定 wiki 是否有新版本可用。
  ///
  /// 返回 `(latestDate, downloadUrl)` 或 `null`（网络不可达或无更新）。
  Future<(String date, String url)?> checkForUpdate(String wikiType) async {
    try {
      // 读取本地版本
      final localVersion = await WikiOfflineService.readVersion(wikiType);

      // 获取云端最新版本
      final result = await _fetchLatestRelease(wikiType);
      if (result == null) return null;

      final (remoteTag, downloadUrl, _) = result;
      final remoteDate = _extractDate(remoteTag);
      if (remoteDate == null) return null;

      final remoteDateStr =
          '${remoteDate.year}-${remoteDate.month.toString().padLeft(2, '0')}-${remoteDate.day.toString().padLeft(2, '0')}';

      // 无本地版本 → 新下载
      if (localVersion == null) {
        return (remoteDateStr, downloadUrl);
      }

      // 比对日期
      final localDate = _extractDate(localVersion);
      if (localDate == null || remoteDate.isAfter(localDate)) {
        return (remoteDateStr, downloadUrl);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// 静默下载更新（无进度回调，完成后 Toast）
  Future<bool> downloadUpdateSilently(
      String wikiType, String downloadUrl, String latestDate) async {
    try {
      final remoteTag = '$wikiType-$latestDate';
      return await _downloadAndSaveZip(
          wikiType, downloadUrl, remoteTag, null, null);
    } catch (_) {
      return false;
    }
  }

  // ==================================================================
  // 内部方法
  // ==================================================================

  /// 从 GitHub API 获取最新 Release 信息
  Future<(String tag, String url, String fileName)?> _fetchLatestRelease(
      String wikiType) async {
    try {
      final url =
          'https://api.github.com/repos/$owner/$repo/releases?per_page=10';
      final resp = await _dio.get(url,
          options: Options(
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Trans-Prism-App',
            },
            sendTimeout: _apiTimeout,
            receiveTimeout: _apiTimeout,
          ));
      if (resp.statusCode != 200) return null;

      final releases = resp.data as List<dynamic>;
      Map<String, dynamic>? target;
      for (final r in releases) {
        final tag = r['tag_name'] as String? ?? '';
        if (tag.startsWith('$wikiType-')) {
          target = r;
          break;
        }
      }
      if (target == null) return null;

      final tag = target['tag_name'] as String? ?? '';
      final assets = target['assets'] as List<dynamic>? ?? [];
      if (assets.isEmpty) return null;

      final zip = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').endsWith('.zip'),
      );
      final downloadUrl = zip['browser_download_url'] as String;
      final fileName = zip['name'] as String? ?? '${tag}.zip';

      return (tag, downloadUrl, fileName);
    } catch (e) {
      debugPrint("[$wikiType] 网络嗅探失败: $e");
      return null;
    }
  }

  /// 下载 ZIP → 写版本日志 → 删除旧 ZIP → 重命名
  ///
  /// ## IP 分流
  ///
  /// - **中国大陆用户**：走镜像站容错链下载
  /// - **非中国大陆用户**：直连 GitHub 下载，跳过镜像探测
  Future<bool> _downloadAndSaveZip(
    String wikiType,
    String rawDownloadUrl,
    String remoteTag,
    void Function(double)? onProgress,
    void Function(String)? onStatus,
  ) async {
    try {
      // 确保 offline_wiki 目录存在
      final offlineDir = await WikiOfflineService.offlineWikiDir;
      final offlineDirPath = offlineDir.path;

      // 清理残留 temp 文件
      final tempPath = '$offlineDirPath/temp_$wikiType.zip';
      final tempFile = File(tempPath);
      if (tempFile.existsSync()) tempFile.deleteSync();

      // ── IP 地理位置分流 ──
      final inChina = await RegionDetector.instance.detect();

      if (!inChina) {
        // 非中国大陆地区：直连 GitHub 下载
        onStatus?.call('正在直连下载...');
        debugPrint("[$wikiType] 非中国大陆地区，直连 GitHub 下载");
        await _dio.download(rawDownloadUrl, tempPath,
            options: Options(
              connectTimeout: _mirrorConnectTimeout,
              sendTimeout: _mirrorConnectTimeout,
              receiveTimeout: const Duration(seconds: 120),
            ),
            onReceiveProgress: onProgress != null
                ? (count, total) {
                    if (total > 0) {
                      onProgress(count / total.clamp(1, total));
                      onStatus?.call(
                          '下载中 ${(count * 100 / total).toStringAsFixed(0)}%...');
                    }
                  }
                : null);
        debugPrint("[$wikiType] 直连下载成功");
      } else {
        // 中国大陆地区：逐个镜像站尝试下载
        bool downloaded = false;
        for (int i = 0; i < _mirrors.length; i++) {
          final mirror = _mirrors[i];
          final mirrorUrl = mirror.apply(rawDownloadUrl);

          try {
            onStatus?.call('正在连接镜像 ${i + 1}/${_mirrors.length}...');
            debugPrint("[$wikiType] 尝试镜像[$i]: $mirrorUrl");
            await _dio.download(mirrorUrl, tempPath,
                options: Options(
                  connectTimeout: _mirrorConnectTimeout,
                  sendTimeout: _mirrorConnectTimeout,
                  receiveTimeout: const Duration(seconds: 120),
                ),
                onReceiveProgress: onProgress != null
                    ? (count, total) {
                        if (total > 0) {
                          onProgress(count / total.clamp(1, total));
                          onStatus?.call(
                              '下载中 ${(count * 100 / total).toStringAsFixed(0)}%...');
                        }
                      }
                    : null);
            downloaded = true;
            debugPrint("[$wikiType] 镜像[$i] 下载成功");
            break;
          } on DioException catch (e) {
            debugPrint("[$wikiType] 镜像[$i] 不可用: ${e.type}");
          }
        }

        if (!downloaded) {
          debugPrint("[$wikiType] 所有镜像均不可用，放弃下载");
          return false;
        }
      }

      if (onProgress != null) onProgress(1.0);
      onStatus?.call('写入版本信息...');

      // 提取版本日期
      final date = _extractDate(remoteTag);
      final dateStr = date != null
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : 'unknown';

      // 写版本日志
      await WikiOfflineService.writeVersion(wikiType, dateStr);

      // 删除旧 ZIP
      final finalPath = await WikiOfflineService.zipPath(wikiType);
      final finalFile = File(finalPath);
      if (finalFile.existsSync()) finalFile.deleteSync();

      // 重命名 temp → 正式名
      await tempFile.rename(finalPath);

      onStatus?.call('完成');
      debugPrint("[$wikiType] 下载完成，版本: $dateStr");
      return true;
    } catch (e) {
      debugPrint("[$wikiType] 下载异常: $e");
      return false;
    }
  }

  /// 从 tag 中提取日期
  DateTime? _extractDate(String tag) {
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(tag);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> resetHotUpdateState(String wikiType) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final sd = Directory('${docDir.path}/live_${wikiType}_site');
      if (sd.existsSync()) sd.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// 镜像站定义
class _MirrorDef {
  final String? prefix;
  final String? replaceHost;

  const _MirrorDef({this.prefix, this.replaceHost});

  String apply(String rawUrl) {
    if (prefix != null) {
      return '$prefix$rawUrl';
    }
    if (replaceHost != null) {
      return rawUrl.replaceFirst('github.com', replaceHost!);
    }
    return rawUrl;
  }
}
