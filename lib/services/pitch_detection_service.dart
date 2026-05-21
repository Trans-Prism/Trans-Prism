import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';
import 'package:record/record.dart';

import '../models/voice_training/f0_result.dart';

/// 音高检测服务
///
/// 从 vfs-tracker 的 QuickF0Test.jsx 和 utils/ 移植。
/// 使用 record 包获取麦克风流 PCM16 数据，
/// 使用 pitch_detector_dart (YIN 算法) 检测基频。
class PitchDetectionService {
  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector = PitchDetector(
    audioSampleRate: 44100.0,
    bufferSize: 2048,
  );

  StreamSubscription<Uint8List>? _streamSubscription;
  bool _isRecording = false;
  final List<F0Result> _results = [];
  DateTime? _startTime;

  /// 是否正在录音检测
  bool get isRecording => _isRecording;

  /// 获取当前检测到的所有结果
  List<F0Result> get results => List.unmodifiable(_results);

  /// 清除结果
  void clearResults() {
    _results.clear();
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  /// 开始实时音高检测
  ///
  /// [onPitchDetected] 每次检测到有效音高时的回调，用于实时 UI 更新
  /// [onError] 错误回调
  Stream<F0Result> startDetection({
    void Function(F0Result)? onPitchDetected,
    void Function(Object)? onError,
  }) async* {
    if (_isRecording) {
      throw StateError('音高检测已经在运行中');
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw StateError('麦克风权限未授予');
    }

    _isRecording = true;
    _startTime = DateTime.now();
    _results.clear();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );

    // 音频数据处理缓冲区
    final List<double> floatBuffer = [];

    _streamSubscription = stream.listen(
      (Uint8List data) {
        if (!_isRecording) return;

        try {
          // PCM16 小端字节序转 double 列表
          for (int i = 0; i + 1 < data.length; i += 2) {
            int sample = data[i] | (data[i + 1] << 8);
            if (sample >= 0x8000) sample -= 0x10000;
            floatBuffer.add(sample / 32768.0);
          }

          // 积累足够样本后检测音高
          while (floatBuffer.length >= _detector.bufferSize) {
            final chunk = floatBuffer.sublist(0, _detector.bufferSize);
            floatBuffer.removeRange(
                0, _detector.bufferSize ~/ 2); // 50% overlap

            _detectPitch(chunk, onPitchDetected);
          }
        } catch (e) {
          onError?.call(e);
        }
      },
      onError: (error) {
        onError?.call(error);
        _isRecording = false;
      },
      onDone: () {
        _isRecording = false;
      },
    );

    // 持续 yield 结果
    await for (final result in _resultController.stream) {
      yield result;
    }
  }

  final StreamController<F0Result> _resultController =
      StreamController<F0Result>.broadcast();

  void _detectPitch(
    List<double> floatBuffer,
    void Function(F0Result)? onPitchDetected,
  ) async {
    try {
      final PitchDetectorResult result =
          await _detector.getPitchFromFloatBuffer(floatBuffer);

      final elapsed = _startTime != null
          ? DateTime.now().difference(_startTime!).inMilliseconds.toDouble()
          : 0.0;

      // 有效音高范围：50Hz-1000Hz（人类嗓音范围），概率 > 0.85
      // 参考 vfs-tracker QuickF0Test.jsx: clarity > 0.95 && pitch > 50 && pitch < 1000
      final bool isValid = result.pitched &&
          result.pitch > 50 &&
          result.pitch < 1000 &&
          result.probability > 0.85;

      final f0Result = F0Result(
        pitch: isValid ? result.pitch : 0,
        probability: result.probability,
        pitched: isValid,
        timestampMs: elapsed,
      );

      _results.add(f0Result);
      _resultController.add(f0Result);
      onPitchDetected?.call(f0Result);
    } catch (e) {
      // 忽略检测错误，继续处理下一帧
    }
  }

  /// 停止检测
  Future<void> stopDetection() async {
    _isRecording = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // 忽略停止错误
    }
  }

  /// 计算测试汇总结果
  QuickF0TestResult computeResult() {
    final validF0s = _results.where((r) => r.pitched && r.pitch > 0).toList();

    if (validF0s.isEmpty) {
      return QuickF0TestResult(
        averageF0: 0,
        medianF0: 0,
        minF0: 0,
        maxF0: 0,
        durationMs: 0,
        dataPoints: List.from(_results),
        testTime: _startTime ?? DateTime.now(),
      );
    }

    final pitches = validF0s.map((r) => r.pitch).toList();
    pitches.sort();

    final sum = pitches.fold<double>(0, (a, b) => a + b);
    final average = sum / pitches.length;
    final median = pitches[pitches.length ~/ 2];
    final min = pitches.first;
    final max = pitches.last;

    final duration = _results.isNotEmpty
        ? _results.last.timestampMs - _results.first.timestampMs
        : 0.0;

    return QuickF0TestResult(
      averageF0: double.parse(average.toStringAsFixed(2)),
      medianF0: double.parse(median.toStringAsFixed(2)),
      minF0: double.parse(min.toStringAsFixed(2)),
      maxF0: double.parse(max.toStringAsFixed(2)),
      durationMs: duration,
      dataPoints: List.from(_results),
      testTime: _startTime ?? DateTime.now(),
    );
  }

  /// 显示平滑器（从 vfs-tracker createDisplayPitchSmoother 移植）
  /// 用于实时 UI 上抑制视觉抖动
  static DisplayPitchSmoother createDisplayPitchSmoother({
    int medianWindow = 5,
    double octaveCentThreshold = 600,
    int confirmCount = 2,
    double pendingMatchCents = 200,
  }) {
    return DisplayPitchSmoother(
      medianWindow: medianWindow,
      octaveCentThreshold: octaveCentThreshold,
      confirmCount: confirmCount,
      pendingMatchCents: pendingMatchCents,
    );
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopDetection();
    await _resultController.close();
  }
}

/// 显示平滑器（从 vfs-tracker createDisplayPitchSmoother 移植）
///
/// 滚动中值平滑 + 八度跳跃锁存，抑制 pitch 检测的视觉抖动
class DisplayPitchSmoother {
  final int medianWindow;
  final double octaveCentThreshold;
  final int confirmCount;
  final double pendingMatchCents;

  late List<double> _buffer;
  double _displayed;
  double _pendingPitch;
  int _pendingCount;

  DisplayPitchSmoother({
    this.medianWindow = 5,
    this.octaveCentThreshold = 600,
    this.confirmCount = 2,
    this.pendingMatchCents = 200,
  })  : _buffer = [],
        _displayed = 0,
        _pendingPitch = 0,
        _pendingCount = 0;

  double get value => _displayed;

  double push(double rawPitch) {
    if (!rawPitch.isFinite || rawPitch <= 0) {
      _buffer.clear();
      _pendingPitch = 0;
      _pendingCount = 0;
      _displayed = 0;
      return 0;
    }

    if (_displayed == 0) {
      _buffer.add(rawPitch);
      if (_buffer.length > medianWindow) _buffer.removeAt(0);
      _pendingPitch = 0;
      _pendingCount = 0;
      _displayed = _median(_buffer);
      return _displayed;
    }

    final cents = 1200 * log(rawPitch / _displayed) / log(2);
    if (cents.abs() > octaveCentThreshold) {
      if (_pendingPitch > 0 &&
          (1200 * log(rawPitch / _pendingPitch) / log(2)).abs() <
              pendingMatchCents) {
        _pendingPitch = rawPitch;
        _pendingCount++;
        if (_pendingCount >= confirmCount) {
          _buffer = [rawPitch];
          _displayed = rawPitch;
          _pendingPitch = 0;
          _pendingCount = 0;
        }
      } else {
        _pendingPitch = rawPitch;
        _pendingCount = 1;
      }
      return _displayed;
    }

    _pendingPitch = 0;
    _pendingCount = 0;
    _buffer.add(rawPitch);
    if (_buffer.length > medianWindow) _buffer.removeAt(0);
    _displayed = _median(_buffer);
    return _displayed;
  }

  void reset() {
    _buffer.clear();
    _pendingPitch = 0;
    _pendingCount = 0;
    _displayed = 0;
  }

  double _median(List<double> arr) {
    if (arr.isEmpty) return 0;
    final sorted = List<double>.from(arr)..sort();
    return sorted[sorted.length ~/ 2];
  }
}
