import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 录音状态
enum RecorderState { idle, recording, stopped }

/// 录音回调
///
/// [filePath] 录音文件的本地路径
typedef OnRecordingComplete = void Function(String filePath);

/// 音频录音组件
///
/// 从 vfs-tracker Recorder.jsx 移植。
/// 使用 record 包提供的平台原生录音功能。
class AudioRecorderWidget extends StatefulWidget {
  /// 录音完成回调
  final OnRecordingComplete onRecordingComplete;

  /// 开始录音回调
  final VoidCallback? onStartRecording;

  /// 停止录音回调
  final VoidCallback? onStopRecording;

  /// 放弃录音回调
  final VoidCallback? onDiscardRecording;

  /// 最大录音时长（秒）
  final int maxDurationSec;

  /// 录音标签（用于显示当前步骤说明）
  final String label;

  const AudioRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onStartRecording,
    this.onStopRecording,
    this.onDiscardRecording,
    this.maxDurationSec = 60,
    this.label = '',
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  RecorderState _state = RecorderState.idle;
  double _elapsedSec = 0;
  double _amplitude = 0;
  String? _filePath;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能录音')),
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/voice_test_$timestamp.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 48000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _state = RecorderState.recording;
        _elapsedSec = 0;
        _filePath = path;
      });

      widget.onStartRecording?.call();

      // 启动计时器更新已录制时间
      _timer?.cancel();
      final startTime = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        if (!mounted) return;
        setState(() => _elapsedSec = elapsed);

        // 获取振幅显示
        try {
          final amp = await _recorder.getAmplitude();
          setState(() => _amplitude = amp.current);
        } catch (_) {}

        if (elapsed >= widget.maxDurationSec) {
          _stopRecording();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      setState(() {
        _state = RecorderState.stopped;
        _filePath = path;
      });
      widget.onStopRecording?.call();
      if (path != null) {
        widget.onRecordingComplete(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音停止失败: $e')),
        );
      }
    }
  }

  Future<void> _discardRecording() async {
    _timer?.cancel();
    try {
      await _recorder.cancel();
      setState(() {
        _state = RecorderState.idle;
        _elapsedSec = 0;
        _amplitude = 0;
        _filePath = null;
      });
      widget.onDiscardRecording?.call();
    } catch (e) {
      // ignore cancel errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _elapsedSec / widget.maxDurationSec;
    final remaining = widget.maxDurationSec - _elapsedSec;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标签
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // 进度条
        if (_state == RecorderState.recording) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已录制 ${_elapsedSec.toStringAsFixed(1)}s',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              Text(
                '剩余 ${remaining.toStringAsFixed(1)}s',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 振幅可视化
          if (_amplitude > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 40,
                child: CustomPaint(
                  size: const Size(double.infinity, 40),
                  painter: _AmplitudePainter(amplitude: _amplitude),
                ),
              ),
            ),
        ],

        // 状态文字
        if (_state == RecorderState.recording)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEF5350),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '正在录音...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        if (_state == RecorderState.stopped)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    size: 18, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(
                  '录音完成（${_elapsedSec.toStringAsFixed(1)}s）',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),

        // 按钮
        const SizedBox(height: 8),
        if (_state == RecorderState.idle)
          _buildButton(
            label: '开始录音',
            icon: Icons.mic,
            color: const Color(0xFF14B8A6),
            onPressed: _startRecording,
          ),

        if (_state == RecorderState.recording)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(
                label: '停止录音',
                icon: Icons.stop,
                color: const Color(0xFFEF5350),
                onPressed: _stopRecording,
              ),
              const SizedBox(width: 12),
              _buildButton(
                label: '放弃',
                icon: Icons.close,
                color: Colors.grey,
                onPressed: _discardRecording,
                outlined: true,
              ),
            ],
          ),

        if (_state == RecorderState.stopped)
          _buildButton(
            label: '重新录制',
            icon: Icons.replay,
            color: const Color(0xFFFF9800),
            onPressed: () {
              setState(() {
                _state = RecorderState.idle;
                _elapsedSec = 0;
                _amplitude = 0;
                _filePath = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(30),
      elevation: outlined ? 0 : 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(30),
            border: outlined ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: outlined ? color : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: outlined ? color : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmplitudePainter extends CustomPainter {
  final double amplitude;

  _AmplitudePainter({required this.amplitude});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;
    final normalizedAmp = amplitude.clamp(0.0, 1.0);

    for (double x = 0; x < size.width; x++) {
      final t = x / size.width;
      final wave = sin(t * 2 * pi * 3 + normalizedAmp * 10) *
          normalizedAmp *
          centerY *
          0.8;
      final y = centerY + wave;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AmplitudePainter oldDelegate) =>
      oldDelegate.amplitude != amplitude;
}
