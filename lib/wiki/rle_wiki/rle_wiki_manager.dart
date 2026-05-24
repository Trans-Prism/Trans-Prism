import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:trans_prism/services/wiki_update_manager.dart';

class RleWikiManager {
  static Future<String> get localWikiPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/rle_wiki_site';
  }

  /// 获取最终有效的站点路径（优先返回热更新缓存）
  static Future<String> get effectiveSitePath async {
    final sandboxPath =
        await WikiUpdateManager.getSandboxedSitePath('rle', 'rle-wiki-site');
    if (sandboxPath != null) return sandboxPath;

    final basePath = await localWikiPath;
    return '$basePath/rle-wiki-site';
  }

  static Future<void> initLocalWiki() async {
    final path = await localWikiPath;
    final flagFile = File('$path/.extracted_v1.0.0'); // 标记位

    if (!await flagFile.exists()) {
      // 0. 清理旧解压目录，避免残留文件冲突
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      // 1. 读取 Assets 里的 zip
      final byteData =
          await rootBundle.load('assets/wiki_data/rle-wiki-site.zip');
      final bytes = byteData.buffer.asUint8List();

      // 2. 暴力解压
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('$path/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('$path/$filename').createSync(recursive: true);
        }
      }

      // 3. 写入标记，下次秒开
      flagFile.createSync(recursive: true);
    }

    // 🔥 防爆全能版热更新：fire-and-forget，绝不阻塞 Screen 启动
    unawaited(WikiUpdateManager().checkAndPerformHotUpdate('rle'));
  }
}
