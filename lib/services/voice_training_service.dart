import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/voice_training/voice_event.dart';

/// 嗓音训练存储服务
///
/// 使用 SharedPreferences 本地存储嗓音训练记录。
/// 与 vfs-tracker 后端的事件记录概念对应。
class VoiceTrainingService {
  static const String _storageKey = 'voice_training_events';

  static final VoiceTrainingService _instance =
      VoiceTrainingService._internal();
  factory VoiceTrainingService() => _instance;
  VoiceTrainingService._internal();

  List<VoiceEvent> _events = [];
  bool _loaded = false;

  /// 加载所有事件
  Future<List<VoiceEvent>> loadEvents() async {
    if (_loaded) return List.unmodifiable(_events);

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null && data.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
        _events = jsonList
            .map((e) => VoiceEvent.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {
        _events = [];
      }
    }
    _loaded = true;
    return List.unmodifiable(_events);
  }

  /// 保存事件
  Future<void> saveEvent(VoiceEvent event) async {
    await loadEvents(); // 确保已加载
    _events.insert(0, event);
    await _persist();
  }

  /// 删除事件
  Future<void> deleteEvent(String eventId) async {
    await loadEvents();
    _events.removeWhere((e) => e.id == eventId);
    await _persist();
  }

  /// 获取所有快速 F0 测试结果
  Future<List<VoiceEvent>> getF0TestEvents() async {
    await loadEvents();
    return _events.where((e) => e.type == VoiceEventType.quickF0Test).toList();
  }

  /// 获取所有嗓音训练事件
  Future<List<VoiceEvent>> getTrainingEvents() async {
    await loadEvents();
    return _events
        .where((e) => e.type == VoiceEventType.voiceTraining)
        .toList();
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    _events.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  // ─── 频率/音名转换工具（从 vfs-tracker 移植） ───

  /// 频率转音名
  static String frequencyToNoteName(double frequency) {
    if (!frequency.isFinite || frequency <= 0) return '--';
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    const a4 = 440.0;
    final midi = (69 + 12 * log(frequency / a4) / log(2)).round();
    final noteIndex = ((midi % 12) + 12) % 12;
    final octave = (midi / 12).floor() - 1;
    return '${noteNames[noteIndex]}$octave';
  }

  /// Hz 转 MIDI 音符编号
  static double frequencyToMidi(double frequency) {
    if (!frequency.isFinite || frequency <= 0) return -1;
    return 69 + 12 * log(frequency / 440.0) / log(2);
  }

  /// MIDI 音符编号转 Hz
  static double midiToFrequency(int midi) {
    return 440 * pow(2, (midi - 69) / 12).toDouble();
  }

  /// MIDI 转音名
  static String midiToNoteName(int midi) {
    if (midi < 0 || midi > 127) return '--';
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final noteIndex = ((midi % 12) + 12) % 12;
    final octave = (midi / 12).floor() - 1;
    return '${noteNames[noteIndex]}$octave';
  }
}
