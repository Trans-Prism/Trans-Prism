import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// IP 地理位置检测服务
///
/// 通过访问免费 IP 地理定位 API 判断用户是否位于中国大陆地区，
/// 用于决定更新下载时走镜像站还是直连 GitHub。
///
/// ## 缓存
///
/// 检测结果会缓存到内存中，避免重复请求。
/// 如需刷新可调用 [invalidate] 清除缓存。
class RegionDetector {
  RegionDetector._();

  static final RegionDetector instance = RegionDetector._();

  /// 缓存的主地区结果
  _RegionResult? _cached;

  /// 是否位于中国大陆
  bool get isInMainlandChina => _cached?.isChina ?? false;

  /// 是否已完成检测
  bool get hasDetected => _cached != null;

  /// 检测并缓存用户所在地区。
  ///
  /// 返回 `true` = 中国大陆，`false` = 非中国大陆。
  ///
  /// ## IP 地理定位 API
  ///
  /// 使用 `ip-api.com` 的免费 JSON API（无需 API Key，限 45 次/分钟）。
  /// 响应中的 `countryCode` 字段判断是否为中国大陆（`CN`）。
  ///
  /// ## 失败兜底
  ///
  /// 如果 API 请求失败（网络不可达、超时等），默认返回 `true`（视为中国大陆），
  /// 这样会走镜像站路径，对受限网络更友好。
  Future<bool> detect() async {
    if (_cached != null) return _cached!.isChina;

    try {
      debugPrint('🌐 [RegionDetector] 正在检测 IP 地理位置...');
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final countryCode = (data['countryCode'] as String?)?.toUpperCase();
        final query = data['query'] as String? ?? 'unknown';

        final isChina = countryCode == 'CN';
        _cached = _RegionResult(isChina: isChina, ip: query);
        debugPrint('🌐 [RegionDetector] IP: $query, 地区: $countryCode, '
            '中国大陆: $isChina');
        return isChina;
      } else {
        debugPrint('🌐 [RegionDetector] API 返回非 200: ${response.statusCode}，'
            '默认走镜像站');
        _cached = const _RegionResult(isChina: true);
        return true;
      }
    } catch (e) {
      debugPrint('🌐 [RegionDetector] 检测失败 ($e)，默认走镜像站');
      _cached = const _RegionResult(isChina: true);
      return true;
    }
  }

  /// 清除缓存，下次调用 [detect] 时会重新请求 API。
  void invalidate() {
    _cached = null;
  }

  /// 同步检查是否位于中国大陆（仅在已检测过时有效）。
  bool get isChina => _cached?.isChina ?? true;
}

/// 地区检测结果
class _RegionResult {
  final bool isChina;
  final String? ip;

  const _RegionResult({required this.isChina, this.ip});
}
