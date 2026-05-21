import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// 钢琴音色播放服务
///
/// 使用 audioplayers 播放程序生成的钢琴音色 WAV 数据。
/// 在启动时预生成 C2-C7 范围的钢琴音色 WAV 文件保存到本地缓存。
class PianoSoundService {
  static final PianoSoundService _instance = PianoSoundService._internal();
  factory PianoSoundService() => _instance;
  PianoSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  final Map<int, String> _noteFiles = {};

  /// MIDI 音符编号范围
  static const int minMidi = 36; // C2
  static const int maxMidi = 96; // C7

  /// 初始化：生成钢琴音色 WAV 文件
  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final pianoDir = Directory('${dir.path}/piano_samples');
    if (!await pianoDir.exists()) {
      await pianoDir.create(recursive: true);
    }

    // 检查缓存是否存在
    final cacheOk = await _checkCache(pianoDir);
    if (cacheOk) {
      // 加载缓存文件路径
      for (int midi = minMidi; midi <= maxMidi; midi++) {
        _noteFiles[midi] = '${pianoDir.path}/note_$midi.wav';
      }
      _initialized = true;
      return;
    }

    // 生成音色文件
    for (int midi = minMidi; midi <= maxMidi; midi++) {
      final path = '${pianoDir.path}/note_$midi.wav';
      final wavData = _generatePianoWav(midi);
      await File(path).writeAsBytes(wavData);
      _noteFiles[midi] = path;
    }

    _initialized = true;
  }

  Future<bool> _checkCache(Directory dir) async {
    final sampleFile = File('${dir.path}/note_$minMidi.wav');
    return await sampleFile.exists();
  }

  /// 播放指定 MIDI 音符的钢琴音色
  Future<void> playNote(int midi) async {
    if (!_initialized) await init();
    if (midi < minMidi || midi > maxMidi) return;

    try {
      final path = _noteFiles[midi] ??
          '${(await getApplicationDocumentsDirectory()).path}/piano_samples/note_$midi.wav';
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (_) {}
  }

  /// 播放指定频率的钢琴音色（最接近的 MIDI 音符）
  Future<void> playFrequency(double frequency) async {
    if (frequency <= 0) return;
    final midi = (69 + 12 * log(frequency / 440.0) / log(2)).round();
    await playNote(midi.clamp(minMidi, maxMidi));
  }

  /// 生成钢琴音色 WAV 数据
  Uint8List _generatePianoWav(int midi) {
    const sampleRate = 44100;
    const durationSec = 2.0;
    final frequency = 440.0 * pow(2, (midi - 69) / 12);
    final numSamples = (sampleRate * durationSec).toInt();

    const harmonics = [
      1.0, // 基频振幅
      0.5, // 二次泛音
      0.3, // 三次泛音
      0.15, // 四次泛音
      0.08, // 五次泛音
    ];

    const decayRates = [
      1.0, // 基频衰减
      0.7, // 二次泛音
      0.5, // 三次泛音
      0.3, // 四次泛音
      0.2, // 五次泛音
    ];

    final samples = Float64List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sample = 0;

      for (int h = 0; h < harmonics.length; h++) {
        final freq = frequency * (h + 1);
        final decay = exp(-decayRates[h] * t);
        sample += harmonics[h] * decay * sin(2 * pi * freq * t);
      }

      // 琴槌噪音（前 50ms）
      if (t < 0.05) {
        sample += 0.1 * exp(-40 * t) * (Random().nextDouble() * 2 - 1);
      }

      samples[i] = sample * 0.4;
    }

    return _encodeWav(samples, sampleRate);
  }

  Uint8List _encodeWav(Float64List samples, int sampleRate) {
    const bytesPerSample = 2;
    const numChannels = 1;
    final dataSize = samples.length * bytesPerSample;
    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    void writeString(String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset++, s.codeUnitAt(i));
      }
    }

    writeString('RIFF');
    buffer.setUint32(offset, 36 + dataSize, Endian.little);
    offset += 4;
    writeString('WAVE');
    writeString('fmt ');
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little);
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(
        offset, sampleRate * bytesPerSample * numChannels, Endian.little);
    offset += 4;
    buffer.setUint16(offset, bytesPerSample * numChannels, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bytesPerSample * 8, Endian.little);
    offset += 2;
    writeString('data');
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    for (int i = 0; i < samples.length; i++) {
      final s = (samples[i] * 32767).clamp(-32767, 32767).toInt();
      buffer.setInt16(offset, s, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
