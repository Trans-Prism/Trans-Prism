import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wiki 离线模式服务（阅后即焚版）
///
/// 文件布局：
/// ```
/// {appDocDir}/
///   offline_wiki/
///     mtf-wiki-site.zip           ← 标准命名的 ZIP（只保留压缩包）
///     .mtf-wiki-site.version      ← 版本日志："2026-05-24"
///     ftm-wiki-site.zip
///     .ftm-wiki-site.version
///     rle-wiki-site.zip
///     .rle-wiki-site.version
///   live_mtf_site/                ← 临时解压（打开时创建，关闭即焚）
///   live_ftm_site/
///   live_rle_site/
/// ```
class WikiOfflineService {
  WikiOfflineService._();

  static final WikiOfflineService instance = WikiOfflineService._();

  // ==================================================================
  // 路径
  // ==================================================================

  /// 离线 ZIP 统一存放目录
  static Future<Directory> get offlineWikiDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/offline_wiki');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// ZIP 文件路径
  static Future<String> zipPath(String wikiType) async {
    final dir = await offlineWikiDir;
    return '${dir.path}/${wikiType}-wiki-site.zip';
  }

  /// 版本日志路径
  static Future<String> versionLogPath(String wikiType) async {
    final dir = await offlineWikiDir;
    return '${dir.path}/.${wikiType}-wiki-site.version';
  }

  /// 临时解压目录
  static Future<String> extractRootPath(String wikiType) async {
    final docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}/live_${wikiType}_site';
  }

  // ==================================================================
  // 离线开关
  // ==================================================================

  static Future<bool> isOfflineEnabled(String wikiType) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('wiki_offline_enabled_$wikiType') ?? false;
  }

  static Future<void> setOfflineEnabled(String wikiType, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wiki_offline_enabled_$wikiType', enabled);
  }

  // ==================================================================
  // 版本管理
  // ==================================================================

  /// 读取当前离线版本日期
  static Future<String?> readVersion(String wikiType) async {
    try {
      final f = File(await versionLogPath(wikiType));
      if (await f.exists()) return await f.readAsString();
    } catch (_) {}
    return null;
  }

  /// 写入当前离线版本日期
  static Future<void> writeVersion(String wikiType, String date) async {
    try {
      // 确保目录存在
      await offlineWikiDir;
      await File(await versionLogPath(wikiType)).writeAsString(date);
    } catch (_) {}
  }

  // ==================================================================
  // 阅后即焚：现场解压 / 清理
  // ==================================================================

  /// 判断 ZIP 文件是否存在
  static Future<bool> hasOfflineZip(String wikiType) async {
    try {
      return await File(await zipPath(wikiType)).exists();
    } catch (_) {
      return false;
    }
  }

  /// 现场解压 ZIP 到临时目录，返回实际站点路径
  ///
  /// 返回的 sitePath 会自动探测 ZIP 内是否含版本号子目录
  /// （如 `rle-wiki-site-2026-05-24/`），指向真正含 index.html 的目录。
  /// 如果 ZIP 不存在或解压失败，返回 `null`。
  static Future<String?> extractZipToTemp(String wikiType) async {
    try {
      final zipFile = File(await zipPath(wikiType));
      if (!await zipFile.exists()) return null;

      // 清理上一次解压残留
      await cleanupExtracted(wikiType);

      final extractDir = await extractRootPath(wikiType);

      // 解压
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive) {
        if (f.isFile) {
          File('$extractDir/${f.name}')
            ..createSync(recursive: true)
            ..writeAsBytesSync(f.content as List<int>);
        } else {
          Directory('$extractDir/${f.name}').createSync(recursive: true);
        }
      }

      // ── 精准探测站点根目录 ──
      // 已知 ZIP 内部可能有 `mtf-wiki-site-2026-05-26/` 这样的版本号外壳，
      // 也可能直接裸露。我们需要找到真正的网站根目录。
      final rootDir = Directory(extractDir);

      // 1. 先找直接包含 index.html 的子目录（处理版本号外壳）
      final entries = rootDir.listSync();
      for (final entry in entries) {
        if (entry is Directory &&
            File('${entry.path}/index.html').existsSync()) {
          print('[$wikiType] 探测到内容目录: ${entry.path.split('/').last}');
          return entry.path;
        }
      }

      // 2. 根目录直接有 index.html
      if (File('$extractDir/index.html').existsSync()) {
        return extractDir;
      }

      // 3. 找包含 assets/ 目录的层级（这是 MkDocs 站点根目录的可靠标志）
      //    用广度遍历逐层搜索，优先找最浅的 assets/
      String? siteRoot;
      int bestDepth = 99999;
      final allEntities = rootDir.listSync(recursive: true);
      for (final entity in allEntities) {
        if (entity is Directory && entity.path.endsWith('/assets')) {
          final parent = entity.parent;
          final depth =
              parent.path.replaceFirst(extractDir, '').split('/').length;
          if (depth < bestDepth) {
            bestDepth = depth;
            siteRoot = parent.path;
          }
        }
      }
      if (siteRoot != null) {
        print('[$wikiType] 通过 assets/ 探测到站点根目录: '
            '${siteRoot.replaceFirst(extractDir, '')}');
        return siteRoot;
      }

      // 4. 最后兜底：找任意 index.html 的父目录
      final allFiles = rootDir.listSync(recursive: true);
      String? bestDir;
      int bestDepth2 = 99999;
      for (final f in allFiles) {
        if (f is File && f.path.endsWith('/index.html')) {
          final parentDir = f.parent.path;
          final depth =
              parentDir.replaceFirst(extractDir, '').split('/').length;
          if (depth < bestDepth2) {
            bestDepth2 = depth;
            bestDir = parentDir;
          }
        }
      }
      if (bestDir != null) {
        print('[$wikiType] 递归探测到最浅内容目录: '
            '${bestDir.replaceFirst(extractDir, '')}');
        return bestDir;
      }

      return extractDir;
    } catch (e) {
      print('[$wikiType] 解压失败: $e');
      return null;
    }
  }

  /// 删除临时解压目录（阅后即焚）
  static Future<void> cleanupExtracted(String wikiType) async {
    try {
      final dir = Directory(await extractRootPath(wikiType));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // ==================================================================
  // 完整删除（关闭离线时调用）
  // ==================================================================

  /// 删除 ZIP + 版本日志 + 解压残留
  static Future<void> deleteAllOfflineData(String wikiType) async {
    try {
      // 删 ZIP
      final zip = File(await zipPath(wikiType));
      if (await zip.exists()) await zip.delete();
    } catch (_) {}

    try {
      // 删版本日志
      final log = File(await versionLogPath(wikiType));
      if (await log.exists()) await log.delete();
    } catch (_) {}

    // 删解压残留
    await cleanupExtracted(wikiType);
  }

  // ==================================================================
  // 磁盘空间计算
  // ==================================================================

  /// 计算 ZIP + 解压文件的大小
  static Future<int> getOfflineDiskSizeBytes(String wikiType) async {
    int total = 0;
    try {
      final zip = File(await zipPath(wikiType));
      if (await zip.exists()) total += await zip.length();
    } catch (_) {}

    try {
      final dir = Directory(await extractRootPath(wikiType));
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}

    return total;
  }

  static Future<String> getOfflineDiskSizeFormatted(String wikiType) async {
    final bytes = await getOfflineDiskSizeBytes(wikiType);
    return _formatBytes(bytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
