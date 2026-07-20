import 'package:flutter/material.dart';

/// OVHS-9 嗓音不便指数问卷页面
///
/// 从 vfs-tracker SurveyOVHS9.jsx 移植。
/// 9 项问卷，每项 0-4 分。
/// 功能(F)、情感(E)、生理(P) 各3项。
class OVHS9SurveyScreen extends StatefulWidget {
  final List<int>? initialScores;
  final ValueChanged<List<int>> onSave;

  const OVHS9SurveyScreen({
    super.key,
    this.initialScores,
    required this.onSave,
  });

  @override
  State<OVHS9SurveyScreen> createState() => _OVHS9SurveyScreenState();
}

class _OVHS9SurveyScreenState extends State<OVHS9SurveyScreen> {
  late List<int> _scores;

  static const List<_OVHS9Item> _items = [
    // 功能 F
    _OVHS9Item('F1', '我在嘈杂环境下很难让别人清楚地听到我的声音。'),
    _OVHS9Item('F2', '我的声音问题影响了工作/学习或社交效率。'),
    _OVHS9Item('F3', '我需要重复或提高音量才能被听清。'),
    // 情感 E
    _OVHS9Item('E1', '我的声音让我感到尴尬或不自在。'),
    _OVHS9Item('E2', '因为声音问题，我感到焦虑或担心被误解。'),
    _OVHS9Item('E3', '我因声音问题而回避打电话或当众发言。'),
    // 生理 P
    _OVHS9Item('P1', '说话一段时间后，我的喉咙会感到疲劳或疼痛。'),
    _OVHS9Item('P2', '我需要用很大力气才能发声或保持音量。'),
    _OVHS9Item('P3', '早晨或长时间不用声后，我的嗓音更差，需要热嗓才能正常说话。'),
  ];

  @override
  void initState() {
    super.initState();
    _scores = widget.initialScores != null &&
            widget.initialScores!.length == _items.length
        ? List.from(widget.initialScores!)
        : List.filled(_items.length, -1);
  }

  bool get _isComplete => _scores.every((s) => s >= 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final introTitle =
        isDark ? const Color(0xFFE1BEE7) : const Color(0xFF7B1FA2);
    final introText =
        isDark ? const Color(0xFFE5E5EA) : const Color(0xFF616161);
    final sectionText =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF757575);
    return Scaffold(
      appBar: AppBar(
        title: const Text('OVHS-9 问卷'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF352040) : const Color(0xFFF3E5F5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OVHS-9 嗓音不便指数（开放短版）',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: introTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请根据您的情况，对以下各项进行 0-4 分评分。',
                  style: TextStyle(fontSize: 13, color: introText),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length + 3, // items + 3 section headers
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('功能方面',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sectionText)),
                  );
                }
                if (index == 4) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text('情感方面',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sectionText)),
                  );
                }
                if (index == 7) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text('生理方面',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sectionText)),
                  );
                }

                final itemIndex = index -
                    (index > 6
                        ? 2
                        : index > 3
                            ? 1
                            : 0);
                if (itemIndex >= _items.length) return const SizedBox.shrink();
                return _buildQuestionCard(itemIndex);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24242C) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isComplete
                      ? () {
                          widget.onSave(List.from(_scores));
                          Navigator.pop(context);
                        }
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(
                    _isComplete
                        ? '保存评分（总分: ${_scores.fold(0, (a, b) => a + b)}/36）'
                        : '请完成所有项目',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = _items[index];
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    return Card(
      color: isDark ? const Color(0xFF24242C) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF333338) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7B1FA2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildRatingChip(index, 0, '从不'),
                const SizedBox(width: 4),
                _buildRatingChip(index, 1, '几乎不'),
                const SizedBox(width: 4),
                _buildRatingChip(index, 2, '有时'),
                const SizedBox(width: 4),
                _buildRatingChip(index, 3, '经常'),
                const SizedBox(width: 4),
                _buildRatingChip(index, 4, '总是'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingChip(int index, int value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _scores[index] == value;
    final inactiveValue =
        isDark ? const Color(0xFFE5E5EA) : const Color(0xFF757575);
    final inactiveLabel =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8E8E93);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _scores[index] = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF7B1FA2).withOpacity(0.15)
                : isDark
                    ? const Color(0xFF24242C)
                    : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF7B1FA2) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF7B1FA2) : inactiveValue,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? const Color(0xFF7B1FA2) : inactiveLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OVHS9Item {
  final String id;
  final String text;
  const _OVHS9Item(this.id, this.text);
}
