import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub Releases 更新检测响应体（原始远端数据）
class _GitHubRelease {
  final String tagName;
  final String? body;

  /// GitHub 原始 APK 下载链接（https://github.com/.../xxx.apk）
  final String? rawApkDownloadUrl;

  _GitHubRelease({
    required this.tagName,
    this.body,
    this.rawApkDownloadUrl,
  });
}

/// 更新检测结果
///
/// [apkDownloadUrl] 已经过镜像代理加速，可直接拉起浏览器下载。
class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseNotes;

  /// 已拼接代理前缀的 APK 下载链接（非原始 GitHub 直链）
  final String? apkDownloadUrl;

  /// 是否因网络错误导致检测失败。
  ///
  /// 为 `true` 时表示直连 API 失败（超时/DNS/连接拒绝等），
  /// 调用方可以据此提示用户检查网络，而非仅告知"已是最新版"。
  final bool networkError;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.networkError = false,
  });
}

/// 静默自动更新检测服务（查下分离架构）
///
/// ## 查下分离原则
///
/// - **查（API 获取版本信息）**：必须直连 `api.github.com`，绝不拼接代理前缀。
///   代理服务器通常不支持 GitHub API 接口转发，拼接代理反而导致请求失败。
///   超时设为 10 秒，应对国内访问 API 偶尔的缓慢。
///
/// - **下（APK 下载链接）**：从 API 返回的 JSON 中提取 `browser_download_url` 后，
///   统一拼接加速代理前缀（如 `https://ghp.ci/`），让用户通过镜像满速下载。
///
/// ## 容错原则
///
/// 所有网络异常、解析异常均静默处理，绝不阻塞用户。
/// 异常详情通过 `debugPrint` 输出到终端，方便调试。
class UpdateService {
  // ── GitHub API（必须直连，不拼代理）──
  static const _apiUrl =
      'https://api.github.com/repos/daanser/Trans-Prism/releases/latest';

  // ── GitHub Releases 页面（无 APK 资产时的降级页）──
  static const _releasesPageUrl =
      'https://github.com/daanser/Trans-Prism/releases/latest';

  // ── 下载加速代理（仅用于 APK 下载链接）──
  static const _downloadProxy = 'https://ghp.ci/';

  /// API 请求超时：10 秒（国内直连 GitHub API 较慢但通常能通）
  static const _apiTimeout = Duration(seconds: 10);

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'Trans-Prism-App',
  };

  // ──────────────────────────────────────────────
  // 公开方法
  // ──────────────────────────────────────────────

  /// 检查是否有新版本可用。
  ///
  /// API 请求走纯直连；下载链接走代理加速。
  /// 静默执行：所有网络异常均返回 [UpdateCheckResult.hasUpdate] = false，
  /// 并设置 [UpdateCheckResult.networkError] = true。
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 1. 直连 GitHub API 获取远端最新 Release 信息
      final release = await _fetchLatestRelease();
      if (release == null) {
        return const UpdateCheckResult(hasUpdate: false, networkError: true);
      }

      // 2. 获取本地版本号
      final localVersion = await _getLocalVersion();
      if (localVersion == null) {
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 3. 版本号比对
      final remoteVersion = _stripVPrefix(release.tagName);
      if (!_isNewer(remoteVersion, localVersion)) {
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 4. 为 APK 下载链接拼接代理前缀
      final proxiedApkUrl = _buildProxiedDownloadUrl(release.rawApkDownloadUrl);

      return UpdateCheckResult(
        hasUpdate: true,
        latestVersion: release.tagName,
        releaseNotes: release.body,
        apkDownloadUrl: proxiedApkUrl,
      );
    } catch (e) {
      debugPrint('🚨 更新检测失败详细日志: $e');
      return const UpdateCheckResult(hasUpdate: false, networkError: true);
    }
  }

  // ──────────────────────────────────────────────
  // API 直连请求
  // ──────────────────────────────────────────────

  /// 直连 GitHub API 获取最新 Release 信息。
  ///
  /// **不使用任何代理前缀**，直接请求 `api.github.com`。
  Future<_GitHubRelease?> _fetchLatestRelease() async {
    try {
      debugPrint('🔍 正在直连 GitHub API 检查更新...');
      final response = await http
          .get(Uri.parse(_apiUrl), headers: _headers)
          .timeout(_apiTimeout);

      if (response.statusCode != 200) {
        debugPrint('⚠️ GitHub API 返回非 200 状态码: ${response.statusCode}');
        return null;
      }

      debugPrint('✅ GitHub API 请求成功，正在解析...');
      return _parseReleaseJson(response.body);
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

  /// 解析 GitHub Releases API JSON → [_GitHubRelease]
  _GitHubRelease? _parseReleaseJson(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String?;
      if (tagName == null || tagName.isEmpty) {
        debugPrint('⚠️ JSON 中缺少 tag_name 字段');
        return null;
      }

      final releaseBody = json['body'] as String?;

      // 从 assets 中提取 .apk 下载链接
      final assets = json['assets'] as List<dynamic>?;
      String? apkUrl;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            debugPrint('📦 找到 APK 资产: $name');
            break;
          }
        }
      }

      if (apkUrl == null) {
        debugPrint('⚠️ 未找到 .apk 资产，将降级到 Releases 页面');
      }

      return _GitHubRelease(
        tagName: tagName,
        body: releaseBody,
        rawApkDownloadUrl: apkUrl,
      );
    } on FormatException catch (e) {
      debugPrint('🚨 JSON 解析异常 (FormatException): $e');
      return null;
    } catch (e) {
      debugPrint('🚨 解析 Release JSON 时未预期异常: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // 代理下载链接构建
  // ──────────────────────────────────────────────

  /// 为原始 APK 下载链接拼接代理前缀。
  ///
  /// 只有这一步走代理！例如：
  /// `https://ghp.ci/https://github.com/.../app-release.apk`
  ///
  /// 若 [rawUrl] 为空，降级返回代理后的 Releases 页面链接。
  String? _buildProxiedDownloadUrl(String? rawUrl) {
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final proxied = '$_downloadProxy$rawUrl';
      debugPrint('🔗 下载链接已代理加速: $proxied');
      return proxied;
    }

    // 无 APK 资产 → 降级到 Releases 页面（同样走代理）
    const fallback = '$_downloadProxy$_releasesPageUrl';
    debugPrint('🔗 无 APK，降级到 Releases 页面: $fallback');
    return fallback;
  }

  // ──────────────────────────────────────────────
  // 版本号工具
  // ──────────────────────────────────────────────

  /// 获取当前 App 版本号（不含构建号），如 "1.0.0"。
  Future<String?> _getLocalVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      debugPrint('🚨 获取本地版本号失败: $e');
      return null;
    }
  }

  /// 去除版本号前的 "v" 前缀，如 "v1.0.1" → "1.0.1"。
  String _stripVPrefix(String version) {
    if (version.startsWith('v') || version.startsWith('V')) {
      return version.substring(1);
    }
    return version;
  }

  /// 语义化版本号比较：remote > local 返回 true。
  ///
  /// 支持 "1.0.0"、"1.0"、"1" 等格式。
  bool _isNewer(String remote, String local) {
    try {
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
      return false; // 版本相同
    } catch (e) {
      debugPrint('🚨 版本号比对异常: $e');
      return false;
    }
  }
}
