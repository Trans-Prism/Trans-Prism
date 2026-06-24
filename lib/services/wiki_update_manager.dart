import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_service.dart' show baseUpdateUrl;
import 'wiki_offline_service.dart';

/// R2 统一的 Wiki 热更新引擎（无镜像站、无 IP 分流）
///
/// ## 架构变更
///
/// **旧方案（已废弃）**：
/// - GitHub API → 镜像站容错链 → IP 地理分流
///
/// **新方案**：
/// - R2 latest.json 版本协商 → 直链下载
///
/// ## 更新检查
///
/// 向 `${BASE_UPDATE_URL}/builder/latest/latest.json` 发起 GET 请求，
/// 获取最新 ZIP 文件名，通过正则萃取日期戳，与本地版本比对。
///
/// ## 下载
///
/// 拼接 `${BASE_UPDATE_URL}/builder/latest/{latest_file}` 直链，
/// 通过 Dio 流式下载到临时目录，解压后原子交换至文档目录。
class WikiUpdateManager {
  final String owner = "daanser";
  final String repo = "Trans-Prism-Builder";

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _downloadTimeout = Duration(minutes: 5);

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
  // R2 按类型 JSON → 版本协商
  // ==================================================================

  /// 从 R2 获取指定 wiki 的版本信息 JSON。
  ///
  /// URL 格式：`{baseUpdateUrl}/builder/latest/{wikiType}_latest.json`
  ///
  /// JSON 格式：
  /// ```json
  /// {
  ///   "latest_file": "ftm-site-2026-06-24.zip",
  ///   "tag": "ftm-2026-06-24",
  ///   "update_time": "2026-06-24T02:57:29Z"
  /// }
  /// ```
  Future<_R2BuilderLatestJson?> _fetchLatestJson(String wikiType) async {
    try {
      final url = '$baseUpdateUrl/builder/latest/${wikiType}_latest.json';
      debugPrint('[$wikiType] 正在从 R2 获取版本信息: $url');

      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[$wikiType] R2 返回非 200: ${response.statusCode}');
        return null;
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final latestFile = body['latest_file'] as String?;
      final tag = body['tag'] as String?;

      if (latestFile == null || latestFile.isEmpty) {
        debugPrint('[$wikiType] latest_file 字段缺失');
        return null;
      }

      debugPrint('[$wikiType] R2 版本信息: file=$latestFile, tag=$tag');
      return _R2BuilderLatestJson(
        latestFile: latestFile,
        tag: tag ?? '',
      );
    } catch (e) {
      debugPrint('[$wikiType] R2 请求失败: $e');
      return null;
    }
  }

  /// 从 tag 中萃取日期戳（格式：`wikiType-YYYY-MM-DD` → `YYYY-MM-DD`）
  String? _extractDateFromTag(String tag) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(tag);
    return match?.group(1);
  }

  /// 检查指定 wiki 是否有新版本可用。
  ///
  /// 返回 `(latestDate, downloadUrl)` 或 `null`（无更新或网络错误）。
  Future<(String date, String url)?> checkForUpdate(String wikiType) async {
    try {
      // 1. 读取本地版本
      final localVersion = await WikiOfflineService.readVersion(wikiType);

      // 2. 从 R2 获取云端最新信息
      final remote = await _fetchLatestJson(wikiType);
      if (remote == null) return null;

      // 3. 从 tag 中萃取日期
      final remoteDate = _extractDateFromTag(remote.tag);
      if (remoteDate == null) {
        debugPrint('[$wikiType] 无法从 tag 中萃取日期: ${remote.tag}');
        return null;
      }

      // 4. 拼接下载直链
      final downloadUrl = '$baseUpdateUrl/builder/latest/${remote.latestFile}';

      // 5. 无本地版本 → 需要下载
      if (localVersion == null) {
        return (remoteDate, downloadUrl);
      }

      // 6. 比对日期
      if (remoteDate.compareTo(localVersion) > 0) {
        return (remoteDate, downloadUrl);
      }

      return null;
    } catch (e) {
      debugPrint('[$wikiType] 检查更新异常: $e');
      return null;
    }
  }

  // ==================================================================
  // 后台静默热更新
  // ==================================================================

  Future<void> checkAndPerformHotUpdate(String wikiType) async {
    try {
      final result = await checkForUpdate(wikiType);
      if (result == null) return;

      final (remoteDate, downloadUrl) = result;
      await _downloadAndSaveZip(wikiType, downloadUrl, remoteDate, null, null);
    } catch (_) {}
  }

  // ==================================================================
  // 前台下载（用户主动开启离线时调用）
  // ==================================================================

  /// 前台带进度下载最新 Wiki 离线 ZIP。
  Future<bool> downloadWithProgress(
    String wikiType, {
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('正在获取版本信息...');

    final result = await checkForUpdate(wikiType);
    if (result == null) return false;

    final (remoteDate, downloadUrl) = result;
    return await _downloadAndSaveZip(
        wikiType, downloadUrl, remoteDate, onProgress, onStatus);
  }

  /// 静默下载更新（无进度回调，完成后 Toast）
  Future<bool> downloadUpdateSilently(
      String wikiType, String downloadUrl, String latestDate) async {
    try {
      return await _downloadAndSaveZip(
          wikiType, downloadUrl, latestDate, null, null);
    } catch (_) {
      return false;
    }
  }

  // ==================================================================
  // 内部方法
  // ==================================================================

  /// 从 R2 直链下载 ZIP → 写版本日志 → 删除旧 ZIP → 重命名
  ///
  /// ### 下载策略（已简化）
  ///
  /// **旧方案**：根据 IP 归属地走镜像站容错链或直连 GitHub
  /// **新方案**：统一使用 R2 边缘节点直链下载，无分流、无镜像
  Future<bool> _downloadAndSaveZip(
    String wikiType,
    String downloadUrl,
    String remoteDate,
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

      // ── R2 直链下载（无镜像、无分流）──
      onStatus?.call('正在连接 R2 边缘节点...');
      debugPrint("[$wikiType] 从 R2 直链下载: $downloadUrl");

      await _dio.download(downloadUrl, tempPath,
          options: Options(
            connectTimeout: _timeout,
            sendTimeout: _timeout,
            receiveTimeout: _downloadTimeout,
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

      debugPrint("[$wikiType] R2 下载成功");

      if (onProgress != null) onProgress(1.0);
      onStatus?.call('写入版本信息...');

      // 写版本日志
      await WikiOfflineService.writeVersion(wikiType, remoteDate);

      // 删除旧 ZIP
      final finalPath = await WikiOfflineService.zipPath(wikiType);
      final finalFile = File(finalPath);
      if (finalFile.existsSync()) finalFile.deleteSync();

      // 重命名 temp → 正式名
      await tempFile.rename(finalPath);

      onStatus?.call('完成');
      debugPrint("[$wikiType] 下载完成，版本: $remoteDate");
      return true;
    } catch (e) {
      debugPrint("[$wikiType] 下载异常: $e");
      return false;
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

/// R2 builder 按类型 JSON 结构
///
/// ```json
/// {
///   "latest_file": "ftm-site-2026-06-24.zip",
///   "tag": "ftm-2026-06-24",
///   "update_time": "2026-06-24T02:57:29Z"
/// }
/// ```
class _R2BuilderLatestJson {
  final String latestFile;
  final String tag;

  const _R2BuilderLatestJson({
    required this.latestFile,
    required this.tag,
  });
}
