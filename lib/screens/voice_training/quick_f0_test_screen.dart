import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/voice_training/f0_result.dart';
import '../../models/voice_training/voice_event.dart';
import '../../services/pitch_detection_service.dart';
import '../../services/voice_training_service.dart';
import '../../widgets/f0_meter.dart';

/// 快速基频测试页面
///
/// 从 vfs-tracker QuickF0Test.jsx 移植。
/// 实时检测麦克风输入并显示当前基频（F0），
/// 测试结束后显示平均基频并支持保存结果。
class QuickF0TestScreen extends StatefulWidget {
  const QuickF0TestScreen({super.key});

  @override
  State<QuickF0TestScreen> createState() => _QuickF0TestScreenState();
}

class _QuickF0TestScreenState extends State<QuickF0TestScreen> {
  final PitchDetectionService _pitchService = PitchDetectionService();
  final _smoother = PitchDetectionService.createDisplayPitchSmoother();

  bool _isRecording = false;
  bool _isFinished = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  double _currentDisplayF0 = 0;
  double _averageF0 = 0;
  double _minF0 = double.infinity;
  double _maxF0 = 0;
  final List<double> _f0History = [];

  StreamSubscription<F0Result>? _detectionSubscription;

  @override
  void dispose() {
    _detectionSubscription?.cancel();
    _pitchService.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    setState(() {
      _isRecording = true;
      _isFinished = false;
      _errorMessage = null;
      _successMessage = null;
      _averageF0 = 0;
      _minF0 = double.infinity;
      _maxF0 = 0;
      _currentDisplayF0 = 0;
      _f0History.clear();
      _smoother.reset();
      _pitchService.clearResults();
    });

    try {
      final stream = _pitchService.startDetection(
        onPitchDetected: (result) {
          final smoothed = _smoother.push(result.pitch);
          setState(() {
            _currentDisplayF0 = smoothed;
            if (result.pitched && result.pitch > 0) {
              _f0History.add(result.pitch);
              if (result.pitch < _minF0) _minF0 = result.pitch;
              if (result.pitch > _maxF0) _maxF0 = result.pitch;
            }
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = '检测出错: $error';
            _isRecording = false;
          });
        },
      );

      _detectionSubscription = stream.listen((result) {
        // 流数据已经在 onPitchDetected 中处理
      });
    } catch (e) {
      setState(() {
        _errorMessage = '无法启动测试: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _stopTest() async {
    await _pitchService.stopDetection();
    _detectionSubscription?.cancel();
    _detectionSubscription = null;

    final result = _pitchService.computeResult();
    setState(() {
      _isRecording = false;
      _isFinished = true;
      _averageF0 = result.averageF0;
      if (result.minF0 > 0 && result.minF0 < _minF0) _minF0 = result.minF0;
      if (result.maxF0 > _maxF0) _maxF0 = result.maxF0;
    });
  }

  Future<void> _saveResult() async {
    if (_averageF0 <= 0) {
      setState(() => _errorMessage = '没有有效的测试结果可以保存');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = _pitchService.computeResult();
      final event = VoiceEvent.quickF0Test(
        result: result,
        notes: '快速基频测试，平均F0: ${result.averageF0.toStringAsFixed(2)} Hz',
      );
      await VoiceTrainingService().saveEvent(event);
      setState(() {
        _successMessage = '测试结果已保存！';
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '保存失败: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryText =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF757575);
    final effectiveMinF0 = _minF0 == double.infinity ? null : _minF0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('快速基频测试'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // F0 显示屏
            F0Meter(
              currentF0: _currentDisplayF0,
              isActive: _isRecording,
              minF0: effectiveMinF0,
              maxF0: _maxF0 > 0 ? _maxF0 : null,
            ),

            const SizedBox(height: 20),

            // 历史图表
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24242C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '音高趋势',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PitchHistoryChart(
                    f0History: _f0History,
                    averageF0: _averageF0 > 0 ? _averageF0 : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 完成状态显示平均 F0
            if (_isFinished && _averageF0 > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E4D4F)
                      : const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF2AA7B0)
                          : const Color(0xFFB2EBF2)),
                ),
                child: Column(
                  children: [
                    Text(
                      '测试完成',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF80DEEA)
                            : const Color(0xFF00838F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_averageF0.toStringAsFixed(2)} Hz',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF80DEEA)
                            : const Color(0xFF00838F),
                      ),
                    ),
                    Text(
                      '平均基频',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

            // 消息提示
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF173522)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _successMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A1D1D)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFFF8A80)
                          : const Color(0xFFC62828),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton(
                  label: _isFinished ? '重新测试' : '开始测试',
                  icon: Icons.mic,
                  color: const Color(0xFF14B8A6),
                  onPressed: (!_isRecording && !_isSaving) ? _startTest : null,
                ),
                if (_isRecording) ...[
                  const SizedBox(width: 16),
                  _buildButton(
                    label: '停止测试',
                    icon: Icons.stop,
                    color: const Color(0xFFEF5350),
                    onPressed: _stopTest,
                  ),
                ],
                if (_isFinished && _averageF0 > 0) ...[
                  const SizedBox(width: 16),
                  _buildButton(
                    label: _isSaving ? '保存中...' : '保存结果',
                    icon: Icons.save,
                    color: const Color(0xFF5C6BC0),
                    onPressed: _isSaving ? null : _saveResult,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledBg =
        isDark ? const Color(0xFF24242C) : const Color(0xFFEEEEEE);
    final disabledFg =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFFBDBDBD);
    return Material(
      borderRadius: BorderRadius.circular(14),
      elevation: isDisabled ? 0 : 2,
      shadowColor: color.withOpacity(0.3),
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: isDisabled
                ? null
                : LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isDisabled ? disabledBg : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDisabled ? disabledFg : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDisabled ? disabledFg : Colors.white,
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
