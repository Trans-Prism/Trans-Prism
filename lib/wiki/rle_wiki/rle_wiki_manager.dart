import 'dart:async';
import 'package:trans_prism/services/wiki_offline_service.dart';
import 'package:trans_prism/services/wiki_update_manager.dart';

class RleWikiManager {
  /// 初始化离线 Wiki：解压 ZIP 到临时目录
  static Future<String?> initLocalWiki() async {
    return WikiOfflineService.extractZipToTemp('rle');
  }

  /// 获取离线站点路径（优先返回热更新缓存）
  ///
  /// 返回 `null` 表示无可用离线数据，调用方应使用在线模式。
  static Future<String?> get effectiveSitePath async {
    final sandboxPath =
        await WikiUpdateManager.getSandboxedSitePath('rle', 'rle-wiki-site');
    if (sandboxPath != null) return sandboxPath;
    return WikiOfflineService.extractZipToTemp('rle');
  }
}
