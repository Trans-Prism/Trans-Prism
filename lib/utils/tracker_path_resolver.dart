import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum TrackerPathType { asset, file }

class TrackerPathResult {
  final TrackerPathType type;
  final String path;

  TrackerPathResult(this.type, this.path);
}

class TrackerPathResolver {
  TrackerPathResolver._();

  /// 检测 getApplicationDocumentsDirectory() 目录下是否存在 hrt_tracker/index.html。
  /// 若存在，返回该沙盒文件的绝对物理路径；若不存在，返回默认的 Flutter Asset 路径 assets/hrt_tracker/index.html。
  static Future<TrackerPathResult> getTrackerHtmlPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    final sandboxedIndex = File('${docDir.path}/hrt_tracker/index.html');
    if (await sandboxedIndex.exists()) {
      return TrackerPathResult(TrackerPathType.file, sandboxedIndex.path);
    } else {
      return TrackerPathResult(TrackerPathType.asset, 'assets/hrt_tracker/index.html');
    }
  }
}
