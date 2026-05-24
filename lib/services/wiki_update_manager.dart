import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

/// 防爆全能版 Wiki 热更新引擎
///
/// ## 版本日志机制
///
/// 每次更新后，在 `{appDocDir}/.wiki_{wikiType}_version` 写入当前版本标签。
/// 下次打开时直接读日志文件内的日期与云端比对，完全不依赖 SharedPreferences。
///
/// - **无日志**（首次安装）：自动从云端下载最新离线包并创建日志
/// - **有日志**：对比日期，云端更新才下载
/// - **连不上**：静默吞掉异常，用内置包兜底，绝不卡住
///
/// ## 查下分离
///
/// - **查**：直连 `api.github.com`，绝不走代理
/// - **下**：多镜像站容错链，每个 5s 超时，逐个尝试
///
/// ## 镜像站容错链
///
/// 1. `ghp.ci` — 前缀代理
/// 2. `ghproxy.net` — 前缀代理
/// 3. `kkgithub.com` — 替换域名
/// 4. `githubfast.com` — 替换域名
///
/// 全部失败则静默返回，内置包兜底。
///
/// ## 三重防爆
///
/// 1. 下载前清理残留 ZIP
/// 2. 解压前粉碎旧缓存
/// 3. 解压完立即删除 ZIP
class WikiUpdateManager {
  final String owner = "daanser";
  final String repo = "Trans-Prism-Builder";

  /// 镜像站容错链（按优先级排列）
  ///
  /// 每个镜像定义两种变换方式：
  /// - `prefix`：直接拼在原始 URL 前面
  /// - `replaceHost`：将原始 URL 中的 `github.com` 替换为此域名
  static const List<_MirrorDef> _mirrors = [
    _MirrorDef(prefix: 'https://ghp.ci/'),
    _MirrorDef(prefix: 'https://ghproxy.net/'),
    _MirrorDef(replaceHost: 'kkgithub.com'),
    _MirrorDef(replaceHost: 'githubfast.com'),
  ];

  /// 每个镜像站的连接超时（5 秒无响应就切下一家）
  static const Duration _mirrorConnectTimeout = Duration(seconds: 5);

  /// API 嗅探超时
  static const Duration _apiTimeout = Duration(seconds: 15);

  final Dio _dio = Dio();

  // ==================================================================
  // 版本日志
  // ==================================================================

  static Future<String> _versionLogPath(String wikiType) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/.wiki_${wikiType}_version';
  }

  static Future<String?> readLocalTag(String wikiType) async {
    try {
      final f = File(await _versionLogPath(wikiType));
      if (await f.exists()) return await f.readAsString();
    } catch (_) {}
    return null;
  }

  static Future<void> writeLocalTag(String wikiType, String tag) async {
    try {
      await File(await _versionLogPath(wikiType)).writeAsString(tag);
    } catch (_) {}
  }

  // ==================================================================
  // 沙盒检测
  // ==================================================================

  static Future<bool> hasSandboxData(String wikiType) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/live_${wikiType}_site');
      return d.existsSync() && d.listSync().any((e) => e is File);
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
  // 热更新引擎
  // ==================================================================

  /// 静默检查并执行热更新。
  ///
  /// - **无日志（首次运行）**：直接从云端下载最新版
  /// - **有日志**：对比日期，云端更新才下载
  /// - **任何异常**：静默消化，不抛到调用方
  Future<void> checkAndPerformHotUpdate(String wikiType) async {
    // ── 读取本地版本日志 ──
    final localTag = await readLocalTag(wikiType);
    debugPrint("[$wikiType] 本地版本: ${localTag ?? '(无日志-首次运行)'}");

    // ── 嗅探云端 Release ──
    String? remoteTag;
    String? rawDownloadUrl;

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
      if (resp.statusCode != 200) return;

      final releases = resp.data as List<dynamic>;
      Map<String, dynamic>? target;
      for (final r in releases) {
        final tag = r['tag_name'] as String? ?? '';
        if (tag.startsWith('$wikiType-')) {
          target = r;
          break;
        }
      }
      if (target == null) return;

      remoteTag = target['tag_name'] as String? ?? '';
      final assets = target['assets'] as List<dynamic>? ?? [];
      if (assets.isEmpty) return;

      final zip = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').endsWith('.zip'),
      );
      rawDownloadUrl = zip['browser_download_url'] as String;
    } catch (e) {
      debugPrint("[$wikiType] 网络嗅探失败(已静默): $e");
      return;
    }

    // ── 版本决策 ──
    if (localTag != null) {
      final remoteDate = _extractDate(remoteTag);
      final localDate = _extractDate(localTag);
      if (remoteDate == null) return;
      if (localDate != null && !remoteDate.isAfter(localDate)) {
        debugPrint("[$wikiType] 已是最新 ($localTag)");
        return;
      }
    }

    // ── 多镜像站容错下载 + 解压 ──
    try {
      debugPrint("[$wikiType] 开始下载: $remoteTag");
      final dir = await getApplicationDocumentsDirectory();
      final zipPath = '${dir.path}/temp_$wikiType.zip';
      final extractDir = '${dir.path}/live_${wikiType}_site';

      // 防爆1
      final zipFile = File(zipPath);
      if (zipFile.existsSync()) zipFile.deleteSync();

      // ── 逐个镜像站尝试下载 ──
      bool downloaded = false;
      for (int i = 0; i < _mirrors.length; i++) {
        final mirror = _mirrors[i];
        final mirrorUrl = mirror.apply(rawDownloadUrl);

        try {
          debugPrint("[$wikiType] 尝试镜像[$i]: $mirrorUrl");
          await _dio.download(mirrorUrl, zipPath,
              options: Options(
                connectTimeout: _mirrorConnectTimeout,
                sendTimeout: _mirrorConnectTimeout,
                receiveTimeout: const Duration(seconds: 120),
              ));
          // 下载成功 → 退出循环
          downloaded = true;
          debugPrint("[$wikiType] 镜像[$i] 下载成功");
          break;
        } on DioException catch (e) {
          debugPrint("[$wikiType] 镜像[$i] 不可用: ${e.type}");
          // 继续尝试下一个镜像
        }
      }

      if (!downloaded) {
        debugPrint("[$wikiType] 所有镜像均不可用，放弃下载");
        return;
      }

      // 防爆2
      final old = Directory(extractDir);
      if (old.existsSync()) old.deleteSync(recursive: true);

      // 解压
      final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
      for (final f in archive) {
        if (f.isFile) {
          File('$extractDir/${f.name}')
            ..createSync(recursive: true)
            ..writeAsBytesSync(f.content as List<int>);
        } else {
          Directory('$extractDir/${f.name}').createSync(recursive: true);
        }
      }

      // 防爆3
      if (zipFile.existsSync()) zipFile.deleteSync();

      // 写日志
      await writeLocalTag(wikiType, remoteTag);
      debugPrint("[$wikiType] 热更新完成: $remoteTag");
    } catch (e) {
      debugPrint("[$wikiType] 热更新异常(已静默): $e");
    }
  }

  // ==================================================================
  // 工具
  // ==================================================================

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
      final f = File(await _versionLogPath(wikiType));
      if (f.existsSync()) f.deleteSync();
      final dir = await getApplicationDocumentsDirectory();
      final sd = Directory('${dir.path}/live_${wikiType}_site');
      if (sd.existsSync()) sd.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// 镜像站定义
class _MirrorDef {
  /// 前缀代理：直接拼在原始 URL 前面
  /// 例如 `https://ghp.ci/` → `https://ghp.ci/{rawUrl}`
  final String? prefix;

  /// 域名替换：将原始 URL 中的 `github.com` 替换为此域名
  /// 例如 `kkgithub.com` → `https://kkgithub.com/{...}`
  final String? replaceHost;

  const _MirrorDef({this.prefix, this.replaceHost});

  /// 将原始 URL 转换为镜像 URL
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
