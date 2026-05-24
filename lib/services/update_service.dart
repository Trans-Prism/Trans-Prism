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

  /// GitHub 原始 APK 下载链接
  final String? rawApkDownloadUrl;

  _GitHubRelease({
    required this.tagName,
    this.body,
    this.rawApkDownloadUrl,
  });
}

/// 更新检测结果
///
/// [apkDownloadUrls] 是经过多镜像站容错探测后的可用下载链接列表，
/// 调用方可以依次尝试直到成功。
class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseNotes;

  /// 多镜像站 APK 下载链接列表（已通过连通性探测，按优先级排列）
  final List<String> apkDownloadUrls;

  /// 是否因网络错误导致检测失败
  final bool networkError;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseNotes,
    this.apkDownloadUrls = const [],
    this.networkError = false,
  });
}

/// 镜像站定义
class _MirrorDef {
  /// 前缀代理：直接拼在原始 URL 前面
  final String? prefix;

  /// 域名替换：将原始 URL 中的 `github.com` 替换为此域名
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

/// 静默自动更新检测服务（查下分离 + 多镜像站容错）
///
/// ## 查下分离原则
///
/// - **查（API 获取版本信息）**：必须直连 `api.github.com`，绝不拼接代理前缀。
/// - **下（APK 下载链接）**：从 API 提取 `browser_download_url` 后，
///   通过多镜像站容错链探测可用镜像，返回首个响应的镜像站 URL。
///
/// ## 镜像站容错链
///
/// 1. `ghp.ci` — 前缀代理，5s 超时
/// 2. `ghproxy.net` — 前缀代理，5s 超时
/// 3. `kkgithub.com` — 替换域名，5s 超时
/// 4. `githubfast.com` — 替换域名，5s 超时
/// 5. 原始 GitHub 直链 — 兜底（直连不被墙时可用）
class UpdateService {
  // ── GitHub API ──
  static const _apiUrl =
      'https://api.github.com/repos/daanser/Trans-Prism/releases';

  // ── GitHub Releases 页面（无 APK 资产时的降级页）──
  static const _releasesPageUrl =
      'https://github.com/daanser/Trans-Prism/releases/latest';

  // ── 镜像站容错链 ──
  static const List<_MirrorDef> _mirrors = [
    _MirrorDef(prefix: 'https://ghp.ci/'),
    _MirrorDef(prefix: 'https://ghproxy.net/'),
    _MirrorDef(replaceHost: 'kkgithub.com'),
    _MirrorDef(replaceHost: 'githubfast.com'),
  ];

  /// API 请求超时
  static const _apiTimeout = Duration(seconds: 10);

  /// 镜像站连通性探测超时（5 秒无响应就跳过）
  static const _mirrorProbeTimeout = Duration(seconds: 5);

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'Trans-Prism-App',
  };

  // ──────────────────────────────────────────────
  // 公开方法
  // ──────────────────────────────────────────────

  /// 检查是否有新版本可用。
  ///
  /// API 请求走纯直连；下载链接走多镜像站容错探测，返回首个可达的镜像 URL。
  /// 静默执行：所有网络异常均返回 [UpdateCheckResult.hasUpdate] = false，
  /// 并设置 [UpdateCheckResult.networkError] = true。
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 1. 直连 GitHub API
      final release = await _fetchLatestRelease();
      if (release == null) {
        return const UpdateCheckResult(hasUpdate: false, networkError: true);
      }

      // 2. 本地版本号
      final localVersion = await _getLocalVersion();
      if (localVersion == null) {
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 3. 版本号比对
      final remoteVersion = _stripVPrefix(release.tagName);
      if (!_isNewer(remoteVersion, localVersion)) {
        return const UpdateCheckResult(hasUpdate: false);
      }

      // 4. 多镜像站容错探测，拿到可用的下载链接列表
      final urls = await _findWorkingDownloadUrls(release.rawApkDownloadUrl);

      return UpdateCheckResult(
        hasUpdate: true,
        latestVersion: release.tagName,
        releaseNotes: release.body,
        apkDownloadUrls: urls,
      );
    } catch (e) {
      debugPrint('🚨 更新检测失败详细日志: $e');
      return const UpdateCheckResult(hasUpdate: false, networkError: true);
    }
  }

  // ──────────────────────────────────────────────
  // API 直连
  // ──────────────────────────────────────────────

  Future<_GitHubRelease?> _fetchLatestRelease() async {
    try {
      debugPrint('🔍 正在直连 GitHub API 检查更新...');
      final response = await http
          .get(Uri.parse(_apiUrl), headers: _headers)
          .timeout(_apiTimeout);

      if (response.statusCode != 200) {
        debugPrint('⚠️ GitHub API 返回非 200: ${response.statusCode}');
        return null;
      }

      debugPrint('✅ GitHub API 请求成功');
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

  _GitHubRelease? _parseReleaseJson(String body) {
    try {
      final json = jsonDecode(body) as List<dynamic>;
      if (json.isEmpty) {
        debugPrint('⚠️ releases 数组为空');
        return null;
      }

      final latest = json[0] as Map<String, dynamic>;
      final tagName = latest['tag_name'] as String?;
      if (tagName == null || tagName.isEmpty) {
        debugPrint('⚠️ tag_name 缺失');
        return null;
      }

      final releaseBody = latest['body'] as String?;
      final assets = latest['assets'] as List<dynamic>?;
      String? apkUrl;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            debugPrint('📦 找到 APK: $name');
            break;
          }
        }
      }

      if (apkUrl == null) {
        debugPrint('⚠️ 未找到 .apk，降级到 Releases 页面');
      }

      return _GitHubRelease(
        tagName: tagName,
        body: releaseBody,
        rawApkDownloadUrl: apkUrl,
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
  // 多镜像站容错探测
  // ──────────────────────────────────────────────

  /// 对原始 APK 下载链接进行多镜像站容错探测，
  /// 返回按优先级排列的可用 URL 列表（已通过连通性检查）。
  ///
  /// 如果 [rawUrl] 为空，降级返回 GitHub Releases 页面的镜像列表。
  Future<List<String>> _findWorkingDownloadUrls(String? rawUrl) async {
    final baseUrls = <String>[];

    if (rawUrl != null && rawUrl.isNotEmpty) {
      // 对每个镜像站生成 URL
      for (final mirror in _mirrors) {
        baseUrls.add(mirror.apply(rawUrl));
      }
      // 原始直链作为兜底
      baseUrls.add(rawUrl);
    } else {
      // 无 APK → 对 Releases 页面也走镜像
      for (final mirror in _mirrors) {
        baseUrls.add(mirror.apply(_releasesPageUrl));
      }
      baseUrls.add(_releasesPageUrl);
    }

    debugPrint('🔎 开始镜像站连通性探测 (${baseUrls.length} 个候选)...');

    // 逐个探测：向每个 URL 发 GET 请求（只检查响应头是否可达）
    final working = <String>[];
    for (int i = 0; i < baseUrls.length; i++) {
      final url = baseUrls[i];
      try {
        final probeUrl =
            url.endsWith('.apk') || url.contains('/releases/') ? url : url;
        final response = await http.get(Uri.parse(probeUrl), headers: {
          'User-Agent': 'Trans-Prism-App',
          'Range': 'bytes=0-0', // 只请求第一个字节，避免下载整个文件
        }).timeout(_mirrorProbeTimeout);

        // 206 Partial Content（支持 Range）或 200 都算可达
        if (response.statusCode == 206 ||
            response.statusCode == 200 ||
            response.statusCode == 302 ||
            response.statusCode == 301) {
          debugPrint('✅ 镜像[$i] 可达 ($url)');
          working.add(url);
        } else {
          debugPrint('⚠️ 镜像[$i] 返回 ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('⏱️ 镜像[$i] 超时/不可达: $url');
      }
    }

    if (working.isEmpty) {
      debugPrint('⚠️ 所有镜像均不可达，返回原始 URL 兜底');
      // 至少把原始 URL 放进去让用户试试
      return [rawUrl ?? _releasesPageUrl];
    }

    debugPrint('🎯 ${working.length} 个镜像可用: $working');
    return working;
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

  String _stripVPrefix(String version) {
    var v = version;
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final dashIdx = v.indexOf('-');
    if (dashIdx != -1) {
      v = v.substring(0, dashIdx);
    }
    return v;
  }

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
      return false;
    } catch (e) {
      debugPrint('🚨 版本号比对异常: $e');
      return false;
    }
  }
}
