import 'package:flutter/material.dart';

/// TVQ-G 通用嗓音问卷页面
///
/// 从 vfs-tracker SurveyTVQG.jsx 移植。
/// 12 项问卷，每项 0-4 分。
class TVQGSurveyScreen extends StatefulWidget {
  final List<int>? initialScores;
  final ValueChanged<List<int>> onSave;

  const TVQGSurveyScreen({
    super.key,
    this.initialScores,
    required this.onSave,
  });

  @override
  State<TVQGSurveyScreen> createState() => _TVQGSurveyScreenState();
}

class _TVQGSurveyScreenState extends State<TVQGSurveyScreen> {
  late List<int> _scores;

  static const List<_TVQGItem> _items = [
    // 沟通与负担
    _TVQGItem('C1', '我需要比别人更费力才能把话说清楚。'),
    _TVQGItem('C2', '长时间说话后，我不得不暂停或喝水才能继续。'),
    _TVQGItem('C3', '说话后，我的嗓音会变得嘶哑或沙哑。'),
    _TVQGItem('C4', '在打电话或线上会议中，我常被要求重复。'),
    // 社交与情绪
    _TVQGItem('S1', '我因为嗓音而减少社交或公开发言。'),
    _TVQGItem('S2', '我担心自己的声音让别人误以为我生病或情绪不好。'),
    _TVQGItem('S3', '嗓音问题影响了我的自信心。'),
    _TVQGItem('S4', '我在需要提高音量（如户外）时感到吃力。'),
    // 症状与自我管理
    _TVQGItem('P1', '我经常清嗓或咳嗽以获得更清晰的声音。'),
    _TVQGItem('P2', '早晨或久不说话后，声音明显更差。'),
    _TVQGItem('P3', '我说话时出现破音、断裂或不稳定。'),
    _TVQGItem('P4', '即使休息后，我的声音也很难完全恢复。'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('TVQ-G 问卷'),
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
                  'TVQ-G 通用嗓音问卷（12项开放版）',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: introTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请根据您的近期的嗓音情况，对以下各项进行评分。',
                  style: TextStyle(fontSize: 13, color: introText),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return _buildQuestionCard(index);
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
                        ? '保存评分（总分: ${_scores.where((s) => s >= 0).fold(0, (a, b) => a + b)}）'
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF333338) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRatingChip(index, 0, '从不'),
                const SizedBox(width: 4),
                _buildRatingChip(index, 1, '很少'),
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
        onTap: () {
          setState(() => _scores[index] = value);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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

class _TVQGItem {
  final String id;
  final String text;

  const _TVQGItem(this.id, this.text);
}
