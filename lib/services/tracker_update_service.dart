import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'update_service.dart' show baseUpdateUrl;

/// R2 统一的 HRT Tracker 热更新服务
///
/// ## 架构变更
///
/// **旧方案（已废弃）**：
/// - 从 GitHub Release 下载 version.json → 比对 hash → 下载 ZIP
///
/// **新方案**：
/// - 从 R2 边缘节点获取 builder/latest/tracker_latest.json → 解析 latest_file →
///   拼接直链下载 ZIP → 原子级目录交换
///
/// ## R2 tracker_latest.json 格式
///
/// ```json
/// {
///   "latest_file": "hrt_tracker_update-2026-06-24.zip",
///   "tag": "tracker-2026-06-24",
///   "update_time": "2026-06-24T02:57:29Z"
/// }
/// ```
class TrackerUpdateService {
  TrackerUpdateService._();
  static final TrackerUpdateService instance = TrackerUpdateService._();

  static const String _prefsKeyHash = 'tracker_hash';

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  /// 原子级安全更新：
  ///   1. 从 R2 获取 latest.json → 比对本地 hash
  ///   2. 下载 ZIP 到临时目录
  ///   3. 解压到 staging 临时目录
  ///   4. 验证 index.html 完整性
  ///   5. 重命名交换（旧版 → backup，staging → 正式）
  ///   6. 删除 backup
  ///   7. 任意步骤失败 → 旧版本原地保留，不丢失
  Future<void> checkAndUpdate() async {
    if (_isUpdating) {
      debugPrint('[TrackerUpdateService] Update already in progress.');
      return;
    }
    _isUpdating = true;
    try {
      // ── 自愈: 检测之前原子交换是否在中途崩溃 ──
      await _recoverFromCrash();

      // ── Step 1: 从 R2 获取 tracker 版本信息 ──
      final latestJsonUrl = '$baseUpdateUrl/builder/latest/tracker_latest.json';
      debugPrint(
          '[TrackerUpdateService] Checking for updates at $latestJsonUrl...');

      final response = await http
          .get(Uri.parse(latestJsonUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint(
            '[TrackerUpdateService] Failed to fetch tracker_latest.json: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final String latestFile = data['latest_file'] ?? '';
      final String tag = data['tag'] ?? '';

      if (latestFile.isEmpty) {
        debugPrint(
            '[TrackerUpdateService] Invalid tracker_latest.json: missing latest_file.');
        return;
      }

      if (tag.isEmpty) {
        debugPrint(
            '[TrackerUpdateService] Invalid tracker_latest.json: missing tag.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentHash = prefs.getString(_prefsKeyHash) ?? '';

      if (tag == currentHash) {
        debugPrint('[TrackerUpdateService] Already up to date: $currentHash');
        return;
      }

      // ── Step 2: 拼接直链并下载 ZIP ──
      final zipUrl = '$baseUpdateUrl/builder/latest/$latestFile';
      debugPrint(
          '[TrackerUpdateService] New update found. Remote: $tag. Downloading from $zipUrl...');

      final tempDir = await getTemporaryDirectory();
      final tempZipFile = File('${tempDir.path}/hrt_tracker_update.zip');

      final zipResponse =
          await http.get(Uri.parse(zipUrl)).timeout(const Duration(minutes: 5));
      if (zipResponse.statusCode != 200) {
        debugPrint(
            '[TrackerUpdateService] Failed to download zip: ${zipResponse.statusCode}');
        return;
      }

      await tempZipFile.writeAsBytes(zipResponse.bodyBytes, flush: true);
      debugPrint(
          '[TrackerUpdateService] Downloaded zip to ${tempZipFile.path}. Unzipping...');

      // ── Step 3: 分阶段解压到 staging 目录 ──
      final docDir = await getApplicationDocumentsDirectory();
      final stagingDir = Directory('${docDir.path}/hrt_tracker_staging');

      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);

      try {
        final bytes = await tempZipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final fileData = file.content as List<int>;
            final outFile = File('${stagingDir.path}/$filename');
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(fileData, flush: true);
          } else {
            final outDir = Directory('${stagingDir.path}/$filename');
            await outDir.create(recursive: true);
          }
        }
      } catch (e) {
        debugPrint(
            '[TrackerUpdateService] Extraction failed, cleaning up staging: $e');
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
        rethrow;
      }

      // ── Step 4: 验证解压完整性 ──
      final stagingIndex = File('${stagingDir.path}/index.html');
      if (!await stagingIndex.exists()) {
        debugPrint(
            '[TrackerUpdateService] Validation failed: index.html missing in extracted archive');
        await stagingDir.delete(recursive: true);
        return;
      }

      // ── Step 5: 原子级目录交换 ──
      final targetDir = Directory('${docDir.path}/hrt_tracker');
      final backupDir = Directory('${docDir.path}/hrt_tracker_backup');

      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }

      if (await targetDir.exists()) {
        await targetDir.rename(backupDir.path);
      }

      await stagingDir.rename(targetDir.path);

      // ── Step 6: 清理 backup ──
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }

      try {
        await tempZipFile.delete();
      } catch (_) {}

      await prefs.setString(_prefsKeyHash, tag);
      debugPrint(
          '[TrackerUpdateService] Successfully updated hrt_tracker to tag $tag');
    } catch (e) {
      debugPrint('[TrackerUpdateService] Error during check/update: $e');
    } finally {
      _isUpdating = false;
    }
  }

  /// 崩溃自愈
  Future<void> _recoverFromCrash() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}/hrt_tracker');
      final backupDir = Directory('${docDir.path}/hrt_tracker_backup');
      final stagingDir = Directory('${docDir.path}/hrt_tracker_staging');

      if (await backupDir.exists() && !await targetDir.exists()) {
        await backupDir.rename(targetDir.path);
        debugPrint(
            '[TrackerUpdateService] Crash recovery: restored previous version from backup');
      }

      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint(
          '[TrackerUpdateService] Recovery cleanup error (non-fatal): $e');
    }
  }
}
