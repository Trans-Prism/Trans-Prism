import 'package:flutter/material.dart';

import '../../services/piano_sound_service.dart';
import '../../services/voice_training_service.dart';

/// Hz-音符转换工具页面
///
/// 从 vfs-tracker NoteFrequencyTool.jsx 移植。
/// 支持 Hz ↔ 音名双向转换，显示钢琴键盘布局。
class NoteFrequencyToolScreen extends StatefulWidget {
  const NoteFrequencyToolScreen({super.key});

  @override
  State<NoteFrequencyToolScreen> createState() =>
      _NoteFrequencyToolScreenState();
}

class _NoteFrequencyToolScreenState extends State<NoteFrequencyToolScreen> {
  final TextEditingController _hzController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final PianoSoundService _pianoService = PianoSoundService();
  String _hzResult = '';
  String _noteResult = '';
  int? _highlightedMidi;
  String? _hzError;
  String? _noteError;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _initPiano();
  }

  Future<void> _initPiano() async {
    await _pianoService.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hzController.dispose();
    _noteController.dispose();
    _pianoService.dispose();
    super.dispose();
  }

  void _playNote(int midi) {
    if (!_soundEnabled) return;
    _pianoService.playNote(midi);
  }

  void _convertHzToNote() {
    final input = _hzController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _hzResult = '';
        _hzError = null;
        _highlightedMidi = null;
      });
      return;
    }

    final hz = double.tryParse(input);
    if (hz == null || hz <= 0) {
      setState(() {
        _hzResult = '';
        _hzError = '请输入有效的频率值（正数）';
        _highlightedMidi = null;
      });
      return;
    }

    final noteName = VoiceTrainingService.frequencyToNoteName(hz);
    final midi = VoiceTrainingService.frequencyToMidi(hz).round();

    final clampedMidi = midi.clamp(21, 108);
    setState(() {
      _hzResult = '$hz Hz → $noteName（MIDI $midi）';
      _hzError = null;
      _highlightedMidi = clampedMidi;
    });
    _playNote(clampedMidi);
  }

  void _convertNoteToHz() {
    final input = _noteController.text.trim().toUpperCase();
    if (input.isEmpty) {
      setState(() {
        _noteResult = '';
        _noteError = null;
        _highlightedMidi = null;
      });
      return;
    }

    final noteMatch = RegExp(r'^([A-G])([#B]?)(-?\d+)$').firstMatch(input);
    if (noteMatch == null) {
      setState(() {
        _noteResult = '';
        _noteError = '音名格式不正确，请输入例如 C4、F#3、Bb5';
        _highlightedMidi = null;
      });
      return;
    }

    const noteBases = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    final letter = noteMatch.group(1)!;
    final accidental = noteMatch.group(2) ?? '';
    final octave = int.parse(noteMatch.group(3)!);

    final base = noteBases[letter] ?? 0;
    int semitone = base;
    if (accidental == '#') {
      semitone++;
    } else if (accidental == 'B') {
      semitone--;
    }

    final midi = (octave + 1) * 12 + semitone;
    if (midi < 0 || midi > 127) {
      setState(() {
        _noteResult = '';
        _noteError = '音高超出 MIDI 范围（0-127）';
        _highlightedMidi = null;
      });
      return;
    }

    final hz = VoiceTrainingService.midiToFrequency(midi);

    setState(() {
      _noteResult = '$input → ${hz.toStringAsFixed(2)} Hz';
      _noteError = null;
      _highlightedMidi = midi;
    });
    _playNote(midi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hz-音符转换器'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
                _soundEnabled ? Icons.music_note : Icons.music_note_outlined,
                color: _soundEnabled ? const Color(0xFF14B8A6) : Colors.grey),
            tooltip: _soundEnabled ? '关闭钢琴音色' : '开启钢琴音色',
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 钢琴键盘
            _buildKeyboard(),
            const SizedBox(height: 24),

            // Hz → 音符
            _buildConversionCard(
              icon: Icons.speed,
              title: '频率 (Hz) → 音名',
              controller: _hzController,
              result: _hzResult,
              error: _hzError,
              onConvert: _convertHzToNote,
              hint: '例如: 440',
            ),
            const SizedBox(height: 16),

            // 音符 → Hz
            _buildConversionCard(
              icon: Icons.music_note,
              title: '音名 → 频率 (Hz)',
              controller: _noteController,
              result: _noteResult,
              error: _noteError,
              onConvert: _convertNoteToHz,
              hint: '例如: A4, C#5, Bb3',
            ),
            const SizedBox(height: 24),

            // 常见嗓音频率参考
            _buildReferenceTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const int startMidi = 21; // A0
          const int endMidi = 108; // C8
          const totalKeys = endMidi - startMidi + 1;
          final whiteKeyWidth = constraints.maxWidth / 52; // 52 white keys
          final blackKeyWidth = whiteKeyWidth * 0.6;

          return Stack(
            children: [
              // 白键
              Row(
                children: List.generate(totalKeys, (index) {
                  final midi = startMidi + index;
                  final isBlack = _isBlackKey(midi);
                  if (isBlack) return const SizedBox.shrink();

                  final isHighlighted = _highlightedMidi == midi;
                  return Container(
                    width: whiteKeyWidth,
                    height: 140,
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? const Color(0xFF14B8A6)
                          : Colors.white,
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 0.5,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: isHighlighted
                        ? Text(
                            VoiceTrainingService.midiToNoteName(midi),
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                }),
              ),
              // 黑键
              ...List.generate(totalKeys, (index) {
                final midi = startMidi + index;
                if (!_isBlackKey(midi)) return const SizedBox.shrink();

                final whiteKeysBefore =
                    midi - startMidi - _countBlackKeys(startMidi, midi);
                final left =
                    whiteKeysBefore * whiteKeyWidth - blackKeyWidth / 2;
                final isHighlighted = _highlightedMidi == midi;

                return Positioned(
                  left: left + whiteKeyWidth,
                  top: 0,
                  child: Container(
                    width: blackKeyWidth,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? const Color(0xFF0D9488)
                          : const Color(0xFF2D2D3A),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: isHighlighted
                        ? Text(
                            VoiceTrainingService.midiToNoteName(midi),
                            style: const TextStyle(
                              fontSize: 7,
                              color: Colors.white70,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  bool _isBlackKey(int midi) {
    const blackKeys = {1, 3, 6, 8, 10};
    return blackKeys.contains(midi % 12);
  }

  int _countBlackKeys(int from, int to) {
    int count = 0;
    for (int m = from; m < to; m++) {
      if (_isBlackKey(m)) count++;
    }
    return count;
  }

  Widget _buildConversionCard({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required String result,
    required String? error,
    required VoidCallback onConvert,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final resultBg = isDark ? const Color(0xFF1E4D4F) : const Color(0xFFE0F7FA);
    final resultFg = isDark ? const Color(0xFF80DEEA) : const Color(0xFF00838F);
    final errorFg = isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF7B1FA2)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFFBDBDBD),
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => onConvert(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onConvert,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('转换'),
              ),
            ],
          ),
          if (result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: resultBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  result,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: resultFg,
                  ),
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 13,
                  color: errorFg,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferenceTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryText =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF616161);
    const references = [
      {'range': '男性说话嗓音', 'min': '85', 'max': '180'},
      {'range': '女性说话嗓音', 'min': '165', 'max': '255'},
      {'range': '跨性别女性（目标）', 'min': '180', 'max': '250'},
      {'range': '钢琴 C4 (中央 C)', 'min': '261.63', 'max': ''},
      {'range': '钢琴 A4 (标准音)', 'min': '440', 'max': ''},
    ];

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: secondaryText),
              const SizedBox(width: 8),
              Text(
                '嗓音频率参考',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...references.map((ref) {
            final range = ref['range']!;
            final min = ref['min']!;
            final max = ref['max']!;
            final freqStr = max.isEmpty ? '$min Hz' : '$min-$max Hz';
            final noteMin = max.isEmpty
                ? VoiceTrainingService.frequencyToNoteName(double.parse(min))
                : VoiceTrainingService.frequencyToNoteName(double.parse(min));
            final noteMax = max.isNotEmpty
                ? VoiceTrainingService.frequencyToNoteName(double.parse(max))
                : '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(
                      range,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      max.isEmpty
                          ? '$freqStr ($noteMin)'
                          : '$freqStr ($noteMin-$noteMax)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
