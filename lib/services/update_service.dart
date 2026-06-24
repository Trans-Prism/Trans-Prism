import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// R2 边缘节点全局加速域名
const String baseUpdateUrl = 'https://updates.55114514.xyz';

/// 更新检测结果
class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseNotes;

  /// 单一直链下载 URL（R2 边缘节点直连）
  final String? downloadUrl;

  /// 最新文件的文件名（用于拼接直链）
  final String? latestFile;

  /// 是否因网络错误导致检测失败
  final bool networkError;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.latestFile,
    this.networkError = false,
  });
}

/// R2 统一更新检测与下载服务
///
/// ## R2 latest.json 格式
///
/// ```json
/// {
///   "latest_file": "TransPrism_v1.3.1_Beta.apk",
///   "tag": "v1.3.1-beta.1",
///   "update_time": "2026-06-24T03:04:54Z"
/// }
/// ```
///
/// 文件名中的版本号通过正则提取：
/// - APK: `TransPrism_v1.3.1_Beta.apk` → 版本 `1.3.1`
class UpdateService {
  /// API 请求超时
  static const _apiTimeout = Duration(seconds: 10);

  /// 下载超时（大型文件）
  static const _downloadTimeout = Duration(minutes: 5);

  // ──────────────────────────────────────────────
  // 公开方法
  // ──────────────────────────────────────────────

  /// 检查 App 自身是否有新版本可用。
  ///
  /// 向 R2 边缘节点发起 HTTP GET 请求，获取 `app/latest/latest.json`。
  /// 静默执行：所有网络异常均返回 [UpdateCheckResult.hasUpdate] = false，
  /// 并设置 [UpdateCheckResult.networkError] = true。
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 1. 获取 R2 云端 latest.json
      final remote = await _fetchLatestJson('app');
      if (remote == null) {
        return const UpdateCheckResult(hasUpdate: false, networkError: true);
      }

      // 2. 本地版本号
      final localVersion = await _getLocalVersion();
      if (localVersion == null) {
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 3. 从 latest_file 中萃取版本号
      final remoteVersion = _extractVersion(remote.latestFile);
      if (remoteVersion == null) {
        debugPrint('⚠️ 无法从文件名萃取出版本号: ${remote.latestFile}');
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 4. 版本号比对
      if (!_isNewer(remoteVersion, localVersion)) {
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 5. 从 tag 提取显示版本号（去 v 前缀）
      final displayVersion = _stripVPrefix(remote.tag);

      // 6. 拼接下载直链
      final downloadUrl = '$baseUpdateUrl/app/latest/${remote.latestFile}';

      return UpdateCheckResult(
        hasUpdate: true,
        latestVersion: displayVersion,
        releaseNotes: null,
        downloadUrl: downloadUrl,
        latestFile: remote.latestFile,
      );
    } catch (e) {
      debugPrint('🚨 更新检测失败详细日志: $e');
      return const UpdateCheckResult(hasUpdate: false, networkError: true);
    }
  }

  /// 下载 APK 文件到临时目录。
  ///
  /// 返回下载后的文件路径，失败返回 null。
  Future<String?> downloadApk(String downloadUrl,
      {void Function(double progress)? onProgress}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last;
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      debugPrint('📥 开始下载 APK: $downloadUrl');

      final response =
          await http.get(Uri.parse(downloadUrl)).timeout(_downloadTimeout);

      if (response.statusCode != 200) {
        debugPrint('⚠️ 下载失败: HTTP ${response.statusCode}');
        return null;
      }

      await file.writeAsBytes(response.bodyBytes, flush: true);
      onProgress?.call(1.0);

      debugPrint('✅ APK 下载完成: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('🚨 APK 下载异常: $e');
      return null;
    }
  }

  /// 下载 ZIP 文件到临时目录。
  ///
  /// 返回下载后的文件路径，失败返回 null。
  Future<String?> downloadZip(String downloadUrl,
      {void Function(double progress)? onProgress}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last;
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      debugPrint('📥 开始下载 ZIP: $downloadUrl');

      final response =
          await http.get(Uri.parse(downloadUrl)).timeout(_downloadTimeout);

      if (response.statusCode != 200) {
        debugPrint('⚠️ 下载失败: HTTP ${response.statusCode}');
        return null;
      }

      await file.writeAsBytes(response.bodyBytes, flush: true);
      onProgress?.call(1.0);

      debugPrint('✅ ZIP 下载完成: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('🚨 ZIP 下载异常: $e');
      return null;
    }
  }

  /// 流式下载（带进度回调），用于大文件。
  ///
  /// 返回下载后的文件路径，失败返回 null。
  Future<String?> downloadWithProgress(
    String downloadUrl, {
    required void Function(double progress) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last;
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      debugPrint('📥 开始流式下载: $downloadUrl');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        debugPrint('⚠️ 下载失败: HTTP ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength ?? -1;
      int bytesReceived = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          onProgress(bytesReceived / contentLength);
        }
      }

      await sink.flush();
      await sink.close();
      onProgress(1.0);

      debugPrint('✅ 流式下载完成: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('🚨 流式下载异常: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // R2 API 交互
  // ──────────────────────────────────────────────

  /// 从 R2 获取指定类型的 latest.json
  Future<_R2LatestJson?> _fetchLatestJson(String type) async {
    try {
      final url = '$baseUpdateUrl/$type/latest/latest.json';
      debugPrint('🔍 正在检查 $type 更新: $url');

      final response = await http.get(Uri.parse(url)).timeout(_apiTimeout);

      if (response.statusCode != 200) {
        debugPrint('⚠️ R2 返回非 200: ${response.statusCode}');
        return null;
      }

      debugPrint('✅ $type 版本信息获取成功');
      return _parseLatestJson(response.body);
    } on SocketException catch (e) {
      debugPrint('🚨 网络连接失败 (SocketException): $e');
      return null;
    } on HttpException catch (e) {
      debugPrint('🚨 HTTP 协议异常 (HttpException): $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('🚨 JSON 解析失败 (FormatException): $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('🚨 API 请求超时 (TimeoutException): $e');
      return null;
    } catch (e) {
      debugPrint('🚨 未预期的异常: $e');
      return null;
    }
  }

  /// 解析 R2 latest.json
  _R2LatestJson? _parseLatestJson(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      final latestFile = json['latest_file'] as String?;
      if (latestFile == null || latestFile.isEmpty) {
        debugPrint('⚠️ latest_file 字段缺失');
        return null;
      }

      final tag = json['tag'] as String? ?? '';

      if (tag.isEmpty) {
        debugPrint('⚠️ tag 字段缺失');
        return null;
      }

      return _R2LatestJson(
        latestFile: latestFile,
        tag: tag,
      );
    } on FormatException catch (e) {
      debugPrint('🚨 JSON 解析异常: $e');
      return null;
    } catch (e) {
      debugPrint('🚨 解析异常: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // 版本号工具
  // ──────────────────────────────────────────────

  Future<String?> _getLocalVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      debugPrint('🚨 获取本地版本号失败: $e');
      return null;
    }
  }

  /// 从文件名中萃取版本号或日期。
  ///
  /// 支持格式：
  /// - `TransPrism_v1.3.0_Beta.apk` → `1.3.0`
  /// - `TransPrism_v1.3.0.apk` → `1.3.0`
  /// - `miomtfwiki-site-2026-06-23.zip` → `2026-06-23`
  String? _extractVersion(String fileName) {
    // 优先匹配语义化版本号（如 1.3.0, 2.0.1）
    final semverMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(fileName);
    if (semverMatch != null) {
      return semverMatch.group(1);
    }

    // 其次匹配日期戳（如 2026-06-23）
    final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(fileName);
    if (dateMatch != null) {
      return dateMatch.group(1);
    }

    return null;
  }

  /// 去版本号 v 前缀和 -beta 后缀
  String _stripVPrefix(String tag) {
    var v = tag;
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final dashIdx = v.indexOf('-');
    if (dashIdx != -1) {
      v = v.substring(0, dashIdx);
    }
    return v;
  }

  /// 比对两个版本号（支持语义化版本和日期版本）。
  ///
  /// 语义化版本：`1.3.0` → `[1, 3, 0]`
  /// 日期版本：`2026-06-23` → `[2026, 6, 23]`
  bool _isNewer(String remote, String local) {
    try {
      // 如果是日期格式（YYYY-MM-DD），直接用字符串比较
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(remote) &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(local)) {
        return remote.compareTo(local) > 0;
      }

      // 语义化版本：按段比较
      final remoteParts = remote.split('.').map(int.parse).toList();
      final localParts = local.split('.').map(int.parse).toList();
      final maxLen = remoteParts.length > localParts.length
          ? remoteParts.length
          : localParts.length;

      for (int i = 0; i < maxLen; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 版本号比对异常: $e');
      return false;
    }
  }
}

/// R2 latest.json 结构
///
/// ```json
/// {
///   "latest_file": "TransPrism_v1.3.1_Beta.apk",
///   "tag": "v1.3.1-beta.1",
///   "update_time": "2026-06-24T03:04:54Z"
/// }
/// ```
class _R2LatestJson {
  final String latestFile;
  final String tag;

  const _R2LatestJson({
    required this.latestFile,
    required this.tag,
  });
}
