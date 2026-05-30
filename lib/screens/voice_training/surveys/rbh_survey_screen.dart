import 'package:flutter/material.dart';

import '../../../models/voice_training/voice_event.dart';

/// RBH 量表问卷页面
///
/// 从 vfs-tracker SurveyRBH.jsx 移植。
/// R: 粗糙度 (Roughness)
/// B: 气息感 (Breathiness)
/// H: 嘶哑度 (Hoarseness)
/// 每项 0-3 分
class RBHSurveyScreen extends StatefulWidget {
  final RBHScore? initialScore;
  final ValueChanged<RBHScore> onSave;

  const RBHSurveyScreen({
    super.key,
    this.initialScore,
    required this.onSave,
  });

  @override
  State<RBHSurveyScreen> createState() => _RBHSurveyScreenState();
}

class _RBHSurveyScreenState extends State<RBHSurveyScreen> {
  late int _roughness;
  late int _breathiness;
  late int _hoarseness;

  @override
  void initState() {
    super.initState();
    _roughness = widget.initialScore?.roughness ?? -1;
    _breathiness = widget.initialScore?.breathiness ?? -1;
    _hoarseness = widget.initialScore?.hoarseness ?? -1;
  }

  bool get _isComplete =>
      _roughness >= 0 && _breathiness >= 0 && _hoarseness >= 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final introBg = isDark ? const Color(0xFF352040) : const Color(0xFFF3E5F5);
    final introTitle =
        isDark ? const Color(0xFFE1BEE7) : const Color(0xFF7B1FA2);
    final introText =
        isDark ? const Color(0xFFE5E5EA) : const Color(0xFF616161);
    return Scaffold(
      appBar: AppBar(
        title: const Text('RBH 量表'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: introBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RBH 量表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: introTitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请对您的声音进行 0-3 分的评价：\n'
                    '0 = 无，1 = 轻度，2 = 中度，3 = 重度',
                    style: TextStyle(
                      fontSize: 14,
                      color: introText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildRatingCard('R (粗糙度)', _roughness, (v) {
              setState(() => _roughness = v);
            }),
            const SizedBox(height: 16),
            _buildRatingCard('B (气息感)', _breathiness, (v) {
              setState(() => _breathiness = v);
            }),
            const SizedBox(height: 16),
            _buildRatingCard('H (嘶哑度)', _hoarseness, (v) {
              setState(() => _hoarseness = v);
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isComplete
                    ? () {
                        widget.onSave(RBHScore(
                          roughness: _roughness,
                          breathiness: _breathiness,
                          hoarseness: _hoarseness,
                        ));
                        Navigator.pop(context);
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('保存评分'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final inactiveValue =
        isDark ? const Color(0xFFE5E5EA) : const Color(0xFF757575);
    final inactiveLabel =
        isDark ? const Color(0xFFAEAEB2) : const Color(0xFF8E8E93);
    const ratings = [
      {'value': 0, 'label': '无', 'color': Color(0xFF4CAF50)},
      {'value': 1, 'label': '轻度', 'color': Color(0xFFFFC107)},
      {'value': 2, 'label': '中度', 'color': Color(0xFFFF9800)},
      {'value': 3, 'label': '重度', 'color': Color(0xFFF44336)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: ratings.map((r) {
              final isSelected = value == r['value'];
              final color = r['color'] as Color;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => onChanged(r['value'] as int),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.15)
                            : isDark
                                ? const Color(0xFF2C2C2E)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${r['value']}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : inactiveValue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? color : inactiveLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
