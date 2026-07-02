import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'bra_calculator.dart';

/// 单条发育记录
class GrowthRecord {
  /// 记录时间戳（毫秒级 Unix 时间戳，便于排序）
  final int timestamp;

  /// 原始测量值（cm）
  final double underbustRelaxed;
  final double underbustExhaled;
  final double overbustStanding;
  final double overbust45;
  final double overbust90;

  /// 计算结果
  final BraResult result;

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  String get formattedDate {
    final dt = dateTime;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  const GrowthRecord({
    required this.timestamp,
    required this.underbustRelaxed,
    required this.underbustExhaled,
    required this.overbustStanding,
    required this.overbust45,
    required this.overbust90,
    required this.result,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'underbustRelaxed': underbustRelaxed,
        'underbustExhaled': underbustExhaled,
        'overbustStanding': overbustStanding,
        'overbust45': overbust45,
        'overbust90': overbust90,
        'result': result.toJson(),
      };

  factory GrowthRecord.fromJson(Map<String, dynamic> json) => GrowthRecord(
        timestamp: json['timestamp'] as int,
        underbustRelaxed: (json['underbustRelaxed'] as num).toDouble(),
        underbustExhaled: (json['underbustExhaled'] as num).toDouble(),
        overbustStanding: (json['overbustStanding'] as num).toDouble(),
        overbust45: (json['overbust45'] as num).toDouble(),
        overbust90: (json['overbust90'] as num).toDouble(),
        result: BraResult.fromJson(json['result'] as Map<String, dynamic>),
      );
}

/// 发育记录持久化服务
///
/// 使用 [SharedPreferences] 将计算记录以 JSON 数组形式持久化到设备本地。
/// 所有数据绝不离开本机。
class GrowthRecordService {
  GrowthRecordService._();
  static final GrowthRecordService instance = GrowthRecordService._();

  static const String _storageKey = 'bra_growth_records';

  /// 加载所有发育记录（按时间倒序）
  Future<List<GrowthRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final records = jsonList
          .map((e) => GrowthRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      // 按时间倒序排列
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    } catch (e) {
      debugPrint('⚠️ [GrowthRecordService] 解析失败: $e');
      return [];
    }
  }

  /// 保存一条新记录
  Future<void> saveRecord(GrowthRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    List<dynamic> existing;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        existing = jsonDecode(jsonStr) as List<dynamic>;
      } catch (_) {
        existing = <dynamic>[];
      }
    } else {
      existing = <dynamic>[];
    }

    existing.add(record.toJson());
    await prefs.setString(_storageKey, jsonEncode(existing));
  }

  /// 删除指定时间戳的记录
  Future<void> deleteRecord(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      jsonList.removeWhere(
          (e) => (e as Map<String, dynamic>)['timestamp'] == timestamp);
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('⚠️ [GrowthRecordService] 删除失败: $e');
    }
  }

  /// 清除所有记录
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
