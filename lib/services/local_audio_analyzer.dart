import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';

/// 本地音频分析结果
class LocalAnalysisResult {
  final String filePath;
  final String stepName;
  final double averageF0;
  final double medianF0;
  final double minF0;
  final double maxF0;
  final double voicedRatio;
  final double f0StdDev;
  final double durationSec;

  const LocalAnalysisResult({
    required this.filePath,
    required this.stepName,
    required this.averageF0,
    required this.medianF0,
    required this.minF0,
    required this.maxF0,
    required this.voicedRatio,
    required this.f0StdDev,
    required this.durationSec,
  });
}

/// 本地音频分析器
///
/// 读取录制的 WAV 文件，使用 pitch_detector_dart 进行 F0 分析。
/// 提供本地可用的基本声学分析，替代云端 Lambda 功能。
class LocalAudioAnalyzer {
  /// 分析单个 WAV 文件
  Future<LocalAnalysisResult> analyzeFile({
    required String filePath,
    required String stepName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 44) {
      throw Exception('无效的 WAV 文件');
    }

    final samples = _decodeWavToFloat(bytes);
    final sampleRate = _getWavSampleRate(bytes);

    final adjustedDetector = PitchDetector(
      audioSampleRate: sampleRate.toDouble(),
      bufferSize: 2048,
    );

    final validPitches = <double>[];
    int totalFrames = 0;
    const bufferSize = 2048;
    const hopSize = bufferSize ~/ 2;

    for (int i = 0; i + bufferSize <= samples.length; i += hopSize) {
      totalFrames++;
      final chunk = samples.sublist(i, i + bufferSize);
      try {
        final result = await adjustedDetector.getPitchFromFloatBuffer(chunk);
        if (result.pitched &&
            result.pitch > 50 &&
            result.pitch < 1000 &&
            result.probability > 0.85) {
          validPitches.add(result.pitch);
        }
      } catch (_) {}
    }

    final durationSec = samples.length / sampleRate;
    final voicedRatio =
        totalFrames > 0 ? validPitches.length / totalFrames : 0.0;

    double avg = 0, median = 0, minF = 0, maxF = 0, stdDev = 0;

    if (validPitches.isNotEmpty) {
      validPitches.sort();
      final sum = validPitches.fold<double>(0, (a, b) => a + b);
      avg = sum / validPitches.length;
      median = validPitches[validPitches.length ~/ 2];
      minF = validPitches.first;
      maxF = validPitches.last;

      final variance =
          validPitches.fold<double>(0, (acc, p) => acc + pow(p - avg, 2)) /
              validPitches.length;
      stdDev = sqrt(variance);
    }

    return LocalAnalysisResult(
      filePath: filePath,
      stepName: stepName,
      averageF0: double.parse(avg.toStringAsFixed(2)),
      medianF0: double.parse(median.toStringAsFixed(2)),
      minF0: double.parse(minF.toStringAsFixed(2)),
      maxF0: double.parse(maxF.toStringAsFixed(2)),
      voicedRatio: double.parse(voicedRatio.toStringAsFixed(3)),
      f0StdDev: double.parse(stdDev.toStringAsFixed(2)),
      durationSec: double.parse(durationSec.toStringAsFixed(2)),
    );
  }

  /// 批量分析多个文件
  Future<List<LocalAnalysisResult>> analyzeFiles({
    required List<Map<String, String>> files,
  }) async {
    final results = <LocalAnalysisResult>[];
    for (final f in files) {
      try {
        final result = await analyzeFile(
          filePath: f['path']!,
          stepName: f['stepName']!,
        );
        results.add(result);
      } catch (_) {}
    }
    return results;
  }

  /// 解码 WAV PCM 数据为 double 列表
  List<double> _decodeWavToFloat(Uint8List wavBytes) {
    final dataSize =
        ByteData.sublistView(wavBytes, 40).getUint32(0, Endian.little);
    final numChannels =
        ByteData.sublistView(wavBytes, 22).getUint16(0, Endian.little);
    final bitsPerSample =
        ByteData.sublistView(wavBytes, 34).getUint16(0, Endian.little);

    const dataStart = 44;
    final bytesPerSample = bitsPerSample ~/ 8;
    final sampleCount = dataSize ~/ (bytesPerSample * numChannels);
    final samples = List<double>.filled(sampleCount, 0.0);

    if (bitsPerSample == 16) {
      for (int i = 0; i < sampleCount; i++) {
        final offset = dataStart + i * numChannels * 2;
        if (offset + 1 >= wavBytes.length) break;
        int sample = wavBytes[offset] | (wavBytes[offset + 1] << 8);
        if (sample >= 0x8000) sample -= 0x10000;
        samples[i] = sample / 32768.0;
      }
    } else if (bitsPerSample == 8) {
      for (int i = 0; i < sampleCount; i++) {
        final offset = dataStart + i * numChannels;
        if (offset >= wavBytes.length) break;
        samples[i] = (wavBytes[offset] - 128) / 128.0;
      }
    }

    return samples;
  }

  int _getWavSampleRate(Uint8List wavBytes) {
    if (wavBytes.length < 44) return 48000;
    return ByteData.sublistView(wavBytes, 24).getUint32(0, Endian.little);
  }
}
