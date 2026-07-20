import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/voice_training/f0_result.dart';
import '../../services/pitch_detection_service.dart';
import '../../services/voice_training_service.dart';

/// 音阶难度模式
class _ScaleMode {
  final String name;
  final String difficulty;
  final List<int> patternOffsets; // 相对起始音的半音偏移
  final String description;

  const _ScaleMode({
    required this.name,
    required this.difficulty,
    required this.patternOffsets,
    required this.description,
  });
}

/// 音阶练习页面
///
/// 从 vfs-tracker ScalePractice.jsx 移植（简化版）。
/// 提供实时音高检测 + 目标音提示 + 准确度评分。
class ScalePracticeScreen extends StatefulWidget {
  const ScalePracticeScreen({super.key});

  @override
  State<ScalePracticeScreen> createState() => _ScalePracticeScreenState();
}

class _ScalePracticeScreenState extends State<ScalePracticeScreen> {
  final PitchDetectionService _pitchService = PitchDetectionService();
  final _smoother = PitchDetectionService.createDisplayPitchSmoother();

  // 音阶模式配置
  static const List<_ScaleMode> _modes = [
    _ScaleMode(
      name: '五声音阶上行',
      difficulty: '入门',
      patternOffsets: [0, 2, 4, 7, 9, 12],
      description: 'C-D-E-G-A-C 上行练习',
    ),
    _ScaleMode(
      name: '五声音阶下行',
      difficulty: '入门',
      patternOffsets: [12, 9, 7, 4, 2, 0],
      description: 'C-A-G-E-D-C 下行练习',
    ),
    _ScaleMode(
      name: '大调音阶上行',
      difficulty: '简单',
      patternOffsets: [0, 2, 4, 5, 7, 9, 11, 12],
      description: '全音阶上行 C-D-E-F-G-A-B-C',
    ),
    _ScaleMode(
      name: '大调音阶下行',
      difficulty: '简单',
      patternOffsets: [12, 11, 9, 7, 5, 4, 2, 0],
      description: '全音阶下行 C-B-A-G-F-E-D-C',
    ),
    _ScaleMode(
      name: '半音阶上行',
      difficulty: '一般',
      patternOffsets: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      description: '12个半音逐级上行',
    ),
    _ScaleMode(
      name: '滑音上行+下行',
      difficulty: '高级',
      patternOffsets: [0, 2, 4, 7, 12, 7, 4, 2, 0],
      description: '上滑到高八度后返回起始音',
    ),
  ];

  String _status = 'idle'; // idle, practicing, finished
  int _selectedMode = 0;
  int _startOffset = 0; // 相对 C4 的半音偏移
  int _currentTargetIndex = 0;
  bool _currentHit = false;
  double _currentF0 = 0;
  double _targetFrequency = 0;
  String _targetNote = '';
  int _score = 0;
  int _totalAttempts = 0;
  int _successfulHits = 0;
  List<bool> _noteResults = [];
  String? _errorMessage;
  StreamSubscription<F0Result>? _detectionSubscription;
  Timer? _noteTimer;

  _ScaleMode get _mode => _modes[_selectedMode];

  // C4 = 261.63 Hz
  double get _baseFrequency =>
      261.63 * pow(pow(2, 1 / 12), _startOffset).toDouble();

  double _getTargetFrequency(int offset) {
    return _baseFrequency * pow(pow(2, 1 / 12), offset).toDouble();
  }

  @override
  void dispose() {
    _detectionSubscription?.cancel();
    _noteTimer?.cancel();
    _pitchService.dispose();
    super.dispose();
  }

  Future<void> _startPractice() async {
    setState(() {
      _status = 'practicing';
      _currentTargetIndex = 0;
      _score = 0;
      _totalAttempts = 0;
      _successfulHits = 0;
      _noteResults = List.filled(_mode.patternOffsets.length, false);
      _errorMessage = null;
      _currentF0 = 0;
      _smoother.reset();
      _pitchService.clearResults();
      _updateTarget();
    });

    try {
      final stream = _pitchService.startDetection(
        onPitchDetected: (result) {
          if (!mounted) return;
          final smoothed = _smoother.push(result.pitch);
          setState(() {
            _currentF0 = result.pitched ? smoothed : 0;
            _checkPitch(smoothed);
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = '检测出错: $error';
            _status = 'idle';
          });
        },
      );

      _detectionSubscription = stream.listen((_) {});
    } catch (e) {
      setState(() {
        _errorMessage = '无法启动: $e';
        _status = 'idle';
      });
    }
  }

  void _updateTarget() {
    if (_currentTargetIndex >= _mode.patternOffsets.length) {
      _finishPractice();
      return;
    }

    final offset = _mode.patternOffsets[_currentTargetIndex];
    _targetFrequency = _getTargetFrequency(offset);
    _targetNote = VoiceTrainingService.frequencyToNoteName(_targetFrequency);
    _currentHit = false;
    _currentF0 = 0;

    // 每个目标音给 4 秒时间
    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_currentHit && _status == 'practicing') {
        // 超时未命中，自动跳转
        _nextNote(false);
      }
    });
  }

  void _checkPitch(double pitch) {
    if (_currentHit || pitch <= 0) return;

    // 允许 ±50 cents 的误差范围
    final targetCents = 1200 * log(pitch / _targetFrequency) / log(2);
    if (targetCents.abs() <= 50) {
      _currentHit = true;
      _successfulHits++;
      _score += _getScoreForAccuracy(targetCents.abs());
      _noteResults[_currentTargetIndex] = true;

      // 快速切换到下一个音
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _nextNote(true);
      });
    }
  }

  int _getScoreForAccuracy(double cents) {
    if (cents <= 10) return 100;
    if (cents <= 25) return 80;
    if (cents <= 40) return 60;
    return 40;
  }

  void _nextNote(bool hit) {
    if (!mounted) return;
    _noteTimer?.cancel();
    _totalAttempts++;
    setState(() {
      _currentTargetIndex++;
      if (_currentTargetIndex < _mode.patternOffsets.length) {
        _updateTarget();
      } else {
        _finishPractice();
      }
    });
  }

  Future<void> _finishPractice() async {
    _noteTimer?.cancel();
    await _pitchService.stopDetection();
    _detectionSubscription?.cancel();

    if (mounted) {
      setState(() => _status = 'finished');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音阶练习'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _status == 'idle'
            ? _buildSetupPage()
            : _status == 'practicing'
                ? _buildPracticePage()
                : _buildResultPage(),
      ),
    );
  }

  Widget _buildSetupPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryText =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF757575);
    final infoTitle =
        isDark ? const Color(0xFF80DEEA) : const Color(0xFF00838F);
    final infoText = isDark ? const Color(0xFFB2EBF2) : const Color(0xFF006064);
    final cardColor = isDark ? const Color(0xFF24242C) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFEEEEEE);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E4D4F) : const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '音阶练习说明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: infoTitle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '选择一个练习模式和起始音，然后跟随目标音提示进行发声。\n'
                '系统会实时检测您的音高并给出评分。\n'
                '每个目标音有4秒的尝试时间。',
                style: TextStyle(fontSize: 13, height: 1.5, color: infoText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('选择练习模式',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, color: primaryText)),
        const SizedBox(height: 12),
        ...List.generate(_modes.length, (index) {
          final mode = _modes[index];
          final isSelected = _selectedMode == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedMode = index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF14B8A6).withOpacity(0.1)
                      : cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF14B8A6) : borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF14B8A6)
                            : isDark
                                ? const Color(0xFF333338)
                                : Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(mode.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: primaryText)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _difficultyColor(mode.difficulty)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mode.difficulty,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _difficultyColor(mode.difficulty),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(mode.description,
                              style: TextStyle(
                                  fontSize: 12, color: secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        // 起始音选择
        Text('选择起始音',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, color: primaryText)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _startOffset > -12
                  ? () => setState(() => _startOffset -= 2)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Center(
                child: Column(
                  children: [
                    Text(
                      VoiceTrainingService.frequencyToNoteName(
                          _getTargetFrequency(0)),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                    Text(
                      '${_getTargetFrequency(0).toStringAsFixed(1)} Hz',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _startOffset < 12
                  ? () => setState(() => _startOffset += 2)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startPractice,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始练习'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: const Color(0xFF14B8A6),
            ),
          ),
        ),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child:
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildPracticePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF757575);
    final mutedText =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFFBDBDBD);
    final progress = _currentTargetIndex / _mode.patternOffsets.length;

    return Column(
      children: [
        // 进度
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                isDark ? const Color(0xFF24242C) : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('进度: $_currentTargetIndex/${_mode.patternOffsets.length}',
                style: TextStyle(fontSize: 12, color: secondaryText)),
            Text('得分: $_score',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14B8A6))),
          ],
        ),

        const SizedBox(height: 24),

        // 目标音显示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
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
            children: [
              Text('目标音', style: TextStyle(fontSize: 14, color: secondaryText)),
              const SizedBox(height: 8),
              Text(
                _targetNote,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: _currentHit
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF14B8A6),
                ),
              ),
              Text(
                '${_targetFrequency.toStringAsFixed(1)} Hz',
                style: TextStyle(fontSize: 14, color: secondaryText),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 当前 F0 显示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24242C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text('您的声音',
                  style: TextStyle(fontSize: 13, color: secondaryText)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currentF0 > 0 ? _currentF0.toStringAsFixed(1) : '--',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: _currentHit
                          ? const Color(0xFF4CAF50)
                          : _currentF0 > 0
                              ? const Color(0xFF14B8A6)
                              : mutedText,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(' Hz',
                        style: TextStyle(fontSize: 16, color: secondaryText)),
                  ),
                ],
              ),
              Text(
                _currentF0 > 0
                    ? VoiceTrainingService.frequencyToNoteName(_currentF0)
                    : '请发声',
                style: TextStyle(fontSize: 16, color: mutedText),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 音高指示器（显示与目标音的差距）
        if (_currentF0 > 0 && _targetFrequency > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24242C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('音高偏差',
                    style: TextStyle(fontSize: 13, color: secondaryText)),
                const SizedBox(height: 12),
                _buildPitchIndicator(),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 音符进度条
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_mode.patternOffsets.length, (index) {
            final isCurrent = index == _currentTargetIndex;
            final isDone = _noteResults[index];
            return Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? const Color(0xFF4CAF50)
                    : isCurrent
                        ? const Color(0xFF14B8A6)
                        : isDark
                            ? const Color(0xFF24242C)
                            : Colors.grey[200],
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 10,
                            color: isCurrent ? Colors.white : secondaryText,
                            fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ),

        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: () async {
            await _pitchService.stopDetection();
            _detectionSubscription?.cancel();
            _noteTimer?.cancel();
            if (mounted) setState(() => _status = 'idle');
          },
          icon: const Icon(Icons.stop),
          label: const Text('结束练习'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF5350),
            side: const BorderSide(color: Color(0xFFEF5350)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPitchIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cents = 1200 * log(_currentF0 / _targetFrequency) / log(2);
    final clampedCents = cents.clamp(-100.0, 100.0);
    final position = (clampedCents + 100) / 200; // 0..1

    return Column(
      children: [
        Stack(
          children: [
            // 背景条
            Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3F51B5), // 低
                    Color(0xFF4CAF50), // 准
                    Color(0xFF3F51B5), // 高
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // 指示器
            Positioned(
              left: position * (MediaQuery.of(context).size.width - 72) - 10,
              top: -6,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cents.abs() <= 50
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                  border: Border.all(
                      color: isDark ? const Color(0xFF24242C) : Colors.white,
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          cents.abs() <= 50
              ? '✅ 音准良好（${cents.toStringAsFixed(1)} cents）'
              : '偏差 ${cents.toStringAsFixed(1)} cents',
          style: TextStyle(
            fontSize: 12,
            color: cents.abs() <= 50
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryText =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF757575);
    final accuracy = _totalAttempts > 0
        ? (_successfulHits / _totalAttempts * 100).round()
        : 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF14B8A6).withOpacity(0.1),
                const Color(0xFF0D9488).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events,
                  size: 48, color: Color(0xFF14B8A6)),
              const SizedBox(height: 12),
              Text('练习完成！',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryText)),
              const SizedBox(height: 24),
              _buildStatRow('总得分', '$_score', const Color(0xFF14B8A6)),
              const SizedBox(height: 8),
              _buildStatRow('命中率', '$accuracy%', const Color(0xFF5C6BC0)),
              const SizedBox(height: 8),
              _buildStatRow('成功命中', '$_successfulHits/$_totalAttempts',
                  const Color(0xFF4CAF50)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 音符结果网格
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_mode.patternOffsets.length, (index) {
            final offset = _mode.patternOffsets[index];
            final freq = _getTargetFrequency(offset);
            final noteName = VoiceTrainingService.frequencyToNoteName(freq);
            final hit = _noteResults[index];
            return Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: hit
                    ? isDark
                        ? const Color(0xFF173522)
                        : const Color(0xFFE8F5E9)
                    : isDark
                        ? const Color(0xFF24242C)
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hit
                      ? const Color(0xFF4CAF50)
                      : isDark
                          ? const Color(0xFF333338)
                          : Colors.grey[300]!,
                ),
              ),
              child: Column(
                children: [
                  Text(noteName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              hit ? const Color(0xFF2E7D32) : secondaryText)),
                  const SizedBox(height: 2),
                  Icon(
                    hit ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: hit ? const Color(0xFF4CAF50) : secondaryText,
                  ),
                ],
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        FilledButton.icon(
          onPressed: () => setState(() => _status = 'idle'),
          icon: const Icon(Icons.replay),
          label: const Text('重新练习'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: const Color(0xFF14B8A6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF8E8E96)
                    : const Color(0xFF616161))),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case '入门':
        return const Color(0xFF4CAF50);
      case '简单':
        return const Color(0xFFFFC107);
      case '一般':
        return const Color(0xFFFF9800);
      case '高级':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }
}
