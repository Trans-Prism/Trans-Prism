import 'package:flutter/material.dart';

import '../../models/voice_training/voice_event.dart';
import '../../services/voice_training_service.dart';

/// 嗓音训练记录查看页面
///
/// 显示所有嗓音测试和训练记录列表。
class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({super.key});

  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  final VoiceTrainingService _service = VoiceTrainingService();
  List<VoiceEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await _service.loadEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(String id) async {
    await _service.deleteEvent(id);
    setState(() => _events.removeWhere((e) => e.id == id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('记录已删除'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练记录'),
        centerTitle: true,
        actions: [
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清除所有记录',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认清除'),
                    content: const Text('确定要清除所有训练记录吗？此操作不可撤销。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.clearAll();
                  _loadEvents();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无训练记录',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '完成一次快速基频测试或评估问卷后，\n记录将出现在这里。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) =>
                        _buildEventCard(_events[index]),
                  ),
                ),
    );
  }

  Widget _buildEventCard(VoiceEvent event) {
    IconData icon;
    Color color;
    String title;
    String subtitle;
    String? detail;

    switch (event.type) {
      case VoiceEventType.quickF0Test:
        final f0 = event.f0TestResult;
        icon = Icons.mic;
        color = const Color(0xFF14B8A6);
        title = '快速基频测试';
        if (f0 != null) {
          subtitle = '平均 F0: ${f0.averageF0.toStringAsFixed(2)} Hz';
          detail =
              '范围: ${f0.minF0.toStringAsFixed(1)}-${f0.maxF0.toStringAsFixed(1)} Hz | '
              '数据点: ${f0.dataPoints.length}';
        } else {
          subtitle = '（数据不完整）';
          detail = null;
        }
        break;
      case VoiceEventType.voiceTraining:
        icon = Icons.fitness_center;
        color = const Color(0xFF7B1FA2);
        title = '嗓音训练';
        final parts = <String>[];
        if (event.rbhScore != null) {
          parts.add(
              'RBH: ${event.rbhScore!.roughness}/${event.rbhScore!.breathiness}/${event.rbhScore!.hoarseness}');
        }
        if (event.tvqgScores != null) {
          final total =
              event.tvqgScores!.where((s) => s >= 0).fold(0, (a, b) => a + b);
          parts.add('TVQ-G: $total/48');
        }
        subtitle = parts.isNotEmpty ? parts.join(' | ') : '主观评估';
        detail = null;
        break;
      case VoiceEventType.selfPractice:
        icon = Icons.track_changes;
        color = const Color(0xFFFF9800);
        title = '自我练习';
        subtitle = event.notes ?? '';
        detail = null;
        break;
      case VoiceEventType.surgery:
        icon = Icons.local_hospital;
        color = const Color(0xFFF44336);
        title = '嗓音手术';
        subtitle = event.notes ?? '';
        detail = null;
        break;
      case VoiceEventType.feelingLog:
        icon = Icons.chat;
        color = const Color(0xFF2196F3);
        title = '感受记录';
        subtitle = event.notes ?? '';
        detail = null;
        break;
    }

    final monthStr = '${event.date.month}月';
    final dayStr = '${event.date.day}日';
    final timeStr =
        '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧时间线：日期 + 圆点 + 竖线
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(monthStr,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                  Text(dayStr,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D1D1F))),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(width: 2, color: Colors.grey[200]),
                  ),
                ],
              ),
            ),
            // 右侧事件卡片
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onLongPress: () => _deleteEvent(event.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const Spacer(),
                        Text(timeStr,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ]),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                      if (detail != null && detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(detail,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
