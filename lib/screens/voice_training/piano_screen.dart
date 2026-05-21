import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/piano_sound_service.dart';
import '../../services/voice_training_service.dart';

/// 独立钢琴页面
///
/// 全屏 88 键钢琴键盘，支持横屏模式。
/// 点击琴键播放程序生成的钢琴音色。
class PianoScreen extends StatefulWidget {
  const PianoScreen({super.key});

  @override
  State<PianoScreen> createState() => _PianoScreenState();
}

class _PianoScreenState extends State<PianoScreen> {
  final PianoSoundService _piano = PianoSoundService();
  bool _ready = false;
  bool _showLabels = true;
  int? _pressedKey;

  static const int _startMidi = 21; // A0
  static const int _endMidi = 108; // C8

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _piano.init();
    if (mounted) setState(() => _ready = true);
  }

  void _play(int midi) {
    _piano.playNote(midi);
    setState(() => _pressedKey = midi);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _pressedKey == midi) {
        setState(() => _pressedKey = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('钢琴'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
                _showLabels ? Icons.text_fields : Icons.text_fields_outlined),
            tooltip: _showLabels ? '隐藏音名' : '显示音名',
            onPressed: () => setState(() => _showLabels = !_showLabels),
          ),
        ],
      ),
      body: _ready
          ? _buildKeyboard()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildKeyboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        // 白键数量: 52
        const whiteCount = 52;
        final whiteKeyWidth = isLandscape
            ? constraints.maxWidth / whiteCount
            : (constraints.maxWidth - 16) / whiteCount;
        final blackKeyWidth = whiteKeyWidth * 0.6;
        final whiteKeyHeight = isLandscape ? constraints.maxHeight - 80 : 280.0;
        final blackKeyHeight = whiteKeyHeight * 0.62;
        final visibleRange = _getVisibleRange(isLandscape);

        return SingleChildScrollView(
          scrollDirection: isLandscape ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: isLandscape
                ? whiteKeyWidth * whiteCount + 8
                : constraints.maxWidth,
            height: isLandscape ? constraints.maxHeight : whiteKeyHeight + 16,
            child: Stack(
              children: [
                // 白键
                Row(
                  children: List.generate(whiteCount, (i) {
                    final midi = _startMidi + _whiteKeyIndexToMidiOffset(i);
                    final isPressed = _pressedKey == midi;
                    return GestureDetector(
                      onTapDown: (_) => _play(midi),
                      child: Container(
                        width: whiteKeyWidth,
                        height: whiteKeyHeight,
                        decoration: BoxDecoration(
                          color: isPressed
                              ? const Color(0xFFB2DFDB)
                              : Colors.white,
                          border:
                              Border.all(color: Colors.grey[300]!, width: 0.5),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                          boxShadow: isPressed
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _showLabels
                            ? FittedBox(
                                child: Text(
                                  '${VoiceTrainingService.midiToNoteName(midi)}${midi <= 39 ? '\n${midiToHz(midi).toStringAsFixed(0)}Hz' : ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ),
                // 黑键
                ...List.generate(whiteCount - 1, (i) {
                  final midi = _startMidi + _whiteKeyIndexToMidiOffset(i);
                  final nextMidi =
                      _startMidi + _whiteKeyIndexToMidiOffset(i + 1);
                  final blackMidi = _getBlackKeyBetween(midi, nextMidi);
                  if (blackMidi == null) return const SizedBox.shrink();

                  final left = (i + 1) * whiteKeyWidth - blackKeyWidth / 2;
                  final isPressed = _pressedKey == blackMidi;

                  return Positioned(
                    left: left,
                    top: 0,
                    child: GestureDetector(
                      onTapDown: (_) => _play(blackMidi),
                      child: Container(
                        width: blackKeyWidth,
                        height: blackKeyHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isPressed
                                ? [
                                    const Color(0xFF424242),
                                    const Color(0xFF616161)
                                  ]
                                : [
                                    const Color(0xFF2D2D3A),
                                    const Color(0xFF1A1A2E)
                                  ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                          boxShadow: isPressed
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    offset: const Offset(0, 3),
                                    blurRadius: 6,
                                  ),
                                ],
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _showLabels
                            ? FittedBox(
                                child: Text(
                                  VoiceTrainingService.midiToNoteName(
                                      blackMidi),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  int _whiteKeyIndexToMidiOffset(int index) {
    // 找到第 index 个白键对应的 MIDI 偏移
    int midi = _startMidi;
    int whiteCount = 0;
    while (whiteCount < index) {
      midi++;
      if (!_isBlack(midi)) whiteCount++;
    }
    return midi - _startMidi;
  }

  bool _isBlack(int midi) {
    const blacks = {1, 3, 6, 8, 10};
    return blacks.contains(midi % 12);
  }

  int? _getBlackKeyBetween(int whiteMidi1, int whiteMidi2) {
    for (int m = whiteMidi1 + 1; m < whiteMidi2; m++) {
      if (_isBlack(m)) return m;
    }
    return null;
  }

  int? _getVisibleRange(bool landscape) {
    return null; // 全部显示
  }

  double midiToHz(int midi) {
    return 440 * pow(1.059463, midi - 69).toDouble();
  }
}
