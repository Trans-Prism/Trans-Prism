import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracker（血药浓度模拟）端口配置
///
/// 负责「智能 / 自定义」两种端口模式的读取与写入，以及智能模式下从基准端口
/// 开始顺延探测可用端口的算法。
///
/// 背景（对齐 ADR-006）：HRT Tracker SPA 的 localStorage 按 origin
/// （`http://localhost:{port}`）隔离，换端口会导致旧端口数据在新端口下不可见
/// （数据未删除、仅被隔离；切回原端口可恢复）。因此端口变更必须在 UI 明确
/// 警告，并引导用户**先在血药浓度模拟页面用其内置导出功能备份**——App 侧
/// Dart 代码无法代为导出 SPA 的 localStorage 数据。
class TrackerPortConfig {
  TrackerPortConfig._();

  // ── 端口模式 ──
  static const String modeSmart = 'smart';
  static const String modeCustom = 'custom';

  // ── SharedPreferences keys ──
  static const String _prefsModeKey = 'tracker_port_mode';
  static const String _prefsCustomPortKey = 'tracker_custom_port';

  /// 实际绑定端口 key（沿用旧版本 `_tracker_server_port`，保持既有 origin 兼容）
  static const String prefsBoundPortKey = '_tracker_server_port';

  // ── 端口范围 ──
  /// 智能模式基准端口（沿用历史固定端口 53140，兼容旧版本 origin）
  static const int basePort = 53140;

  /// 智能模式顺延个数：53140 ~ 53159 共 20 个
  static const int smartScanCount = 20;

  /// 自定义端口下限
  static const int minPort = 1024;

  /// 自定义端口上限
  static const int maxPort = 65535;

  // ── 读取 ──

  /// 读取端口模式（默认智能）
  static Future<String> readMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsModeKey) ?? modeSmart;
  }

  /// 读取自定义端口（默认基准端口）
  static Future<int> readCustomPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsCustomPortKey) ?? basePort;
  }

  /// 读取上次实际绑定端口（0 = 从未绑定）
  static Future<int> readBoundPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefsBoundPortKey) ?? 0;
  }

  // ── 写入 ──

  /// 保存端口配置（模式 + 自定义端口值）
  static Future<void> save({
    required String mode,
    required int customPort,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsModeKey, mode);
    await prefs.setInt(_prefsCustomPortKey, customPort);
  }

  /// 保存实际绑定端口（智能模式下动态计算的值，供下次启动复用）
  static Future<void> saveBoundPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsBoundPortKey, port);
  }

  // ── 校验 / 探测 ──

  /// 自定义端口是否合法（1024 ~ 65535）
  static bool isValidCustomPort(int port) => port >= minPort && port <= maxPort;

  /// 端口当前是否可绑定
  static Future<bool> canBindPort(int port) async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      await server.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 智能模式端口探测：优先复用 [preferred]（上次绑定端口，保持 origin 稳定），
  /// 不可用则从 [basePort] 起顺延 [smartScanCount] 个；全部被占返回 0
  /// （由调用方绑定随机端口）。
  static Future<int> findSmartPort({int preferred = 0}) async {
    if (preferred > 0 && await canBindPort(preferred)) {
      return preferred;
    }
    for (var i = 0; i < smartScanCount; i++) {
      final p = basePort + i;
      if (await canBindPort(p)) {
        return p;
      }
    }
    return 0;
  }
}
