import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 数据迁移服务：导出/导入 App 中的所有本地数据。
///
/// # 导出流程
/// 1. 将 SharedPreferences 保存为临时文件 (part1_tp)
/// 2. 通过 JavaScript 静默导出 Oyama SPA 的内存数据，保存为临时文件 (part2_oyama)
/// 3. 用分隔符 `__TP_OYAMA_SEPARATOR__` 合并两个 JSON 文件
/// 4. 让用户保存合并后的文件
/// 5. 删除临时文件
///
/// # 导入流程
/// 1. 用户选择合并文件
/// 2. 按分隔符拆分数据
/// 3. 第一部分 → 恢复 SharedPreferences
/// 4. 第二部分 → 通过 JavaScript 注入 Oyama SPA
class DataMigrationService {
  DataMigrationService._();

  static const String _defaultFileName = 'trans_prism_backup.json';
  static const String _oyamaDataKey = '__oyama_hrt_storage__';

  /// 分隔符：用于在单个文件中区分 Trans Prism 数据与 Oyama 数据
  static const String _separator = '\n<<<__TP_OYAMA_SEPARATOR__>>>\n';

  static WebViewController? _oyamaWebViewController;

  /// 是否有可用的 Oyama SPA WebView 控制器
  static bool get hasOyamaController => _oyamaWebViewController != null;

  static void registerOyamaController(WebViewController? controller) {
    _oyamaWebViewController = controller;
  }

  // ==================== 导出 ====================

  /// 导出所有数据。
  ///
  /// 返回 `true` 表示用户已选择保存文件（可能并不包含 Oyama 部分）。
  static Future<bool> exportData() async {
    try {
      // ── 1. 获取 SharedPreferences 数据 ──
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      if (allKeys.isEmpty) return false;

      final Map<String, dynamic> tpData = {};
      for (final key in allKeys) {
        tpData[key] = prefs.get(key);
      }

      // ── 2. 获取 Oyama SPA 的导出数据 ──
      final Map<String, dynamic>? oyamaData = await _extractOyamaExportData();

      // ── 3. 获取临时目录 ──
      final tempDir = await getTemporaryDirectory();
      final tpFile = File('${tempDir.path}/.tp_export_part1.json');
      final oyamaFile = File('${tempDir.path}/.tp_export_part2.json');
      final mergedFile = File('${tempDir.path}/.tp_export_merged.json');

      // ── 4. 写入第一部分 (Trans Prism SharedPreferences) ──
      final tpJson = const JsonEncoder.withIndent('  ').convert(tpData);
      await tpFile.writeAsString(tpJson, flush: true);

      // ── 5. 写入第二部分 (Oyama 导出数据) ──
      String oyamaJson = '{}';
      if (oyamaData != null) {
        oyamaJson = const JsonEncoder.withIndent('  ').convert(oyamaData);
      }
      await oyamaFile.writeAsString(oyamaJson, flush: true);

      // ── 6. 合并两个文件（用分隔符隔开） ──
      final mergedContent = '$tpJson$_separator$oyamaJson';
      await mergedFile.writeAsString(mergedContent, flush: true);

      // ── 7. 让用户保存合并后的文件 ──
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '选择备份文件保存位置',
        fileName: _defaultFileName,
        bytes: utf8.encode(mergedContent),
      );

      // ── 8. 清理临时文件 ──
      try {
        await tpFile.delete();
        await oyamaFile.delete();
        await mergedFile.delete();
      } catch (_) {
        // 忽略删除失败
      }

      return result != null;
    } catch (e) {
      debugPrint('[DataMigration] exportData error: $e');
      return false;
    }
  }

  // ==================== 导入 ====================

  /// 从备份文件导入数据。
  static Future<bool> importData() async {
    try {
      // ── 1. 用户选择文件 ──
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份文件（trans_prism_backup.json）',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return false;

      final pickedFile = result.files.first;
      String fullContent;
      if (pickedFile.path != null) {
        fullContent = await File(pickedFile.path!).readAsString();
      } else if (pickedFile.bytes != null) {
        fullContent = utf8.decode(pickedFile.bytes!);
      } else {
        return false;
      }
      if (fullContent.trim().isEmpty) return false;

      // ── 2. 按分隔符拆分数据 ──
      String tpJsonPart;
      String oyamaJsonPart;

      final separatorIndex = fullContent.indexOf(_separator);
      if (separatorIndex >= 0) {
        // 新版格式：有分隔符
        tpJsonPart = fullContent.substring(0, separatorIndex).trim();
        oyamaJsonPart =
            fullContent.substring(separatorIndex + _separator.length).trim();
      } else {
        // 旧版格式：无分隔符，整个文件是 SharedPreferences
        tpJsonPart = fullContent.trim();
        oyamaJsonPart = '{}';
      }

      // ── 3. 解析并导入 Trans Prism 数据 ──
      if (tpJsonPart.isNotEmpty) {
        final Map<String, dynamic> tpData;
        try {
          tpData = jsonDecode(tpJsonPart) as Map<String, dynamic>;
        } catch (_) {
          return false;
        }

        final prefs = await SharedPreferences.getInstance();
        for (final entry in tpData.entries) {
          if (entry.key == _oyamaDataKey) continue;
          await _setValue(prefs, entry.key, entry.value);
        }
      }

      // ── 4. 导入 Oyama SPA 数据 ──
      if (oyamaJsonPart.isNotEmpty && oyamaJsonPart != '{}') {
        Map<String, dynamic>? oyamaData;
        try {
          oyamaData = jsonDecode(oyamaJsonPart) as Map<String, dynamic>;
        } catch (_) {
          oyamaData = null;
        }

        if (oyamaData != null && oyamaData.isNotEmpty) {
          await _importOyamaData(oyamaData);
        }
      }

      return true;
    } catch (e) {
      debugPrint('[DataMigration] importData error: $e');
      return false;
    }
  }

  // ==================== Oyama SPA 数据提取（导出用） ====================

  /// 从 Oyama SPA 中提取导出格式的数据（events、labResults、weight、localStorage）。
  ///
  /// 返回的 Map 结构等同于 Oyama SPA 自带的 JSON 导出格式：
  /// ```json
  /// {
  ///   "events": [...],
  ///   "labResults": [...],
  ///   "weight": ...,
  ///   "localStorage": { "key": "value", ... }
  /// }
  /// ```
  static Future<Map<String, dynamic>?> _extractOyamaExportData() async {
    final controller = _oyamaWebViewController;
    if (controller == null) return null;

    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(function() {
  var output = {};

  // 1. 读取 localStorage（SPA 原生的持久化机制）
  try {
    var ls = {};
    for (var i = 0; i < localStorage.length; i++) {
      var k = localStorage.key(i);
      ls[k] = localStorage.getItem(k);
    }
    output.localStorage = ls;
  } catch(e) {
    output._lsError = e.message;
  }

  // 2. 通过 React fiber 树提取应用状态（events / labResults / weight）
  try {
    var root = document.getElementById('root');
    var fiberKey = Object.keys(root).find(function(k) {
      return k.startsWith('__reactFiber$');
    });
    if (fiberKey) {
      var queue = [root[fiberKey]];
      var visited = new Set();
      while (queue.length > 0) {
        var f = queue.shift();
        if (!f || visited.has(f)) continue;
        visited.add(f);

        if (f.memoizedState) {
          var hook = f.memoizedState;
          while (hook) {
            var val = hook.memoizedState;
            if (val && typeof val === 'object') {
              var str = JSON.stringify(val);
              // events: 包含 timeH 字段的数组
              if (str && str.indexOf('"timeH"') >= 0) {
                if (Array.isArray(val)) {
                  output.events = val;
                } else if (val.events) {
                  output.events = val.events;
                }
              }
              // labResults: 包含 date + estradiol 的对象
              if (str && str.indexOf('"date"') >= 0 && str.indexOf('"estradiol"') >= 0) {
                if (val.labResults) output.labResults = val.labResults;
                else output.labResults = Array.isArray(val) ? val : null;
              }
              // weight
              if (val.weight !== undefined) {
                output.weight = val.weight;
              }
            }
            hook = hook.next;
          }
        }
        if (f.child) queue.push(f.child);
        if (f.sibling) queue.push(f.sibling);
        if (f.return && !visited.has(f.return)) queue.push(f.return);
      }
    }
  } catch(e) {
    output._reactError = e.message;
  }

  return JSON.stringify(output);
})();
''');
      final raw = result.toString();
      if (raw.isNotEmpty && raw != 'null') {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          // 只保留干净的数据字段
          decoded.remove('_lsError');
          decoded.remove('_reactError');
          if (decoded.isEmpty) return null;
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('[DataMigration] _extractOyamaExportData error: $e');
    }
    return null;
  }

  // ==================== Oyama SPA 数据恢复（导入用） ====================

  /// 将导出的 Oyama 数据恢复到 SPA 中。
  ///
  /// 1. 恢复 localStorage（SPA 原生方式）
  /// 2. 通过 React dispatch 注入 events / labResults / weight
  static Future<void> _importOyamaData(Map<String, dynamic> data) async {
    final controller = _oyamaWebViewController;
    if (controller == null) return;

    // 提取数据
    final events = data['events'];
    final labResults = data['labResults'];
    final weight = data['weight'];
    final localStorageData = data['localStorage'];

    final List<String> jsParts = [];

    jsParts.add(r'''
(function() {
  try {
    var root = document.getElementById('root');
    var fiberKey = Object.keys(root).find(function(k) {
      return k.startsWith('__reactFiber$');
    });
    if (!fiberKey) return;

    // 1. 恢复 localStorage
'''[1]);

    if (localStorageData is Map<String, dynamic>) {
      final lsJson = jsonEncode(localStorageData);
      final escaped = lsJson.replaceAll("'", "\\'");
      jsParts.add("""
    try {
      var lsData = JSON.parse('$escaped');
      for (var key in lsData) {
        if (lsData.hasOwnProperty(key)) localStorage.setItem(key, lsData[key]);
      }
    } catch(e) {}
""");
    }

    jsParts.add(r'''
    // 2. 遍历 fiber 树，找到对应的 state dispatch 并注入数据
    var queue = [root[fiberKey]];
    var visited = new Set();
    while (queue.length > 0) {
      var f = queue.shift();
      if (!f || visited.has(f)) continue;
      visited.add(f);

      if (f.memoizedState) {
        var hook = f.memoizedState;
        while (hook) {
          var val = hook.memoizedState;
          var dispatch = hook.queue && hook.queue.dispatch;
          if (!dispatch) { hook = hook.next; continue; }
'''[1]);

    // 注入 events
    if (events != null) {
      final eventsJson = jsonEncode(events);
      final eventsEscaped = eventsJson.replaceAll("'", "\\'");
      jsParts.add("""
          if (val && typeof val === 'object') {
            var str = JSON.stringify(val);
            if (str.indexOf('"timeH"') >= 0) {
              if (Array.isArray(val) && val.length === 0) {
                dispatch(JSON.parse('$eventsEscaped'));
              } else if (Array.isArray(val) && val.length > 0 && val[0].timeH !== undefined) {
                dispatch(JSON.parse('$eventsEscaped'));
              } else if (val.events) {
                var newState = Object.assign({}, val);
                newState.events = JSON.parse('$eventsEscaped');
                dispatch(newState);
              }
            }
          }
""");
    }

    // 注入 weight
    if (weight != null) {
      jsParts.add("""
          if (val && typeof val === 'object' && val.weight !== undefined) {
            var newState = Object.assign({}, val);
            newState.weight = $weight;
            dispatch(newState);
          }
""");
    }

    // 注入 labResults
    if (labResults != null) {
      final lrJson = jsonEncode(labResults);
      final lrEscaped = lrJson.replaceAll("'", "\\'");
      jsParts.add("""
          if (val && typeof val === 'object' && val.labResults !== undefined) {
            var newState = Object.assign({}, val);
            newState.labResults = JSON.parse('$lrEscaped');
            dispatch(newState);
          }
""");
    }

    jsParts.add('''
          hook = hook.next;
        }
      }
      if (f.child) queue.push(f.child);
      if (f.sibling) queue.push(f.sibling);
      if (f.return && !visited.has(f.return)) queue.push(f.return);
    }
  } catch(e) {
    console.error('[OyamaBridge] inject error:', e);
  }
})();
''');

    final fullJs = jsParts.join('');
    await controller.runJavaScript(fullJs);
  }

  // ==================== SharedPreferences 写入辅助 ====================

  static Future<void> _setValue(
      SharedPreferences prefs, String key, dynamic value) async {
    if (value == null) {
      await prefs.remove(key);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((e) => e.toString()).toList());
    } else {
      await prefs.setString(key, jsonEncode(value));
    }
  }
}
