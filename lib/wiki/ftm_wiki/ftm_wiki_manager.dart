import 'dart:async';
import 'package:trans_prism/services/wiki_update_manager.dart';

class FtmWikiManager {
  /// 获取离线站点路径（优先返回热更新缓存）
  ///
  /// 返回 `null` 表示无可用离线数据，调用方应使用在线模式。
  static Future<String?> get effectiveSitePath async {
    final sandboxPath =
        await WikiUpdateManager.getSandboxedSitePath('ftm', 'ftm-wiki-site');
    return sandboxPath;
  }
}
