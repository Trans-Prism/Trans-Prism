import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/voice_training_service.dart';

/// F0 实时显示组件
///
/// 从 vfs-tracker QuickF0Test.jsx 的当前基频显示移植。
/// 显示当前 F0 值（Hz）和对应音名。
class F0Meter extends StatelessWidget {
  final double currentF0;
  final bool isActive;
  final double? maxF0;
  final double? minF0;

  const F0Meter({
    super.key,
    required this.currentF0,
    required this.isActive,
    this.maxF0,
    this.minF0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValidF0 = currentF0 > 0 && currentF0.isFinite;
    final displayF0 = hasValidF0 ? currentF0.toStringAsFixed(1) : '--';
    final noteName =
        hasValidF0 ? VoiceTrainingService.frequencyToNoteName(currentF0) : '--';
    final color = hasValidF0 ? const Color(0xFF14B8A6) : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当前基频',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayF0,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  ' Hz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            noteName,
            style: TextStyle(
              fontSize: 22,
              fontFamily: 'monospace',
              color: Colors.grey[500],
            ),
          ),
          if (maxF0 != null || minF0 != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (minF0 != null)
                  _buildRangeBadge(
                    icon: Icons.arrow_downward,
                    label: '最低',
                    value: minF0!.toStringAsFixed(0),
                    color: Colors.blue,
                  ),
                if (minF0 != null && maxF0 != null) const SizedBox(width: 16),
                if (maxF0 != null)
                  _buildRangeBadge(
                    icon: Icons.arrow_upward,
                    label: '最高',
                    value: maxF0!.toStringAsFixed(0),
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
          if (isActive && !hasValidF0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '正在监听麦克风...请发出声音',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRangeBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label $value Hz',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 音高历史折线图组件
///
/// 从 vfs-tracker QuickF0Test.jsx 的 AreaChart 移植。
/// 使用 fl_chart 绘制 F0 历史趋势。
class PitchHistoryChart extends StatelessWidget {
  final List<double> f0History;
  final double? averageF0;
  final double minDisplayF0;
  final double maxDisplayF0;

  const PitchHistoryChart({
    super.key,
    required this.f0History,
    this.averageF0,
    this.minDisplayF0 = 60,
    this.maxDisplayF0 = 350,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = f0History;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _PitchChartPainter(
                data: data,
                averageF0: averageF0,
                minY: minDisplayF0,
                maxY: maxDisplayF0,
                lineColor: const Color(0xFF14B8A6),
                avgColor: const Color(0xFF0D9488),
              ),
              size: Size.infinite,
            ),
          ),
          if (data.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${minDisplayF0.toInt()} Hz',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                  Text(
                    '${maxDisplayF0.toInt()} Hz',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PitchChartPainter extends CustomPainter {
  final List<double> data;
  final double? averageF0;
  final double minY;
  final double maxY;
  final Color lineColor;
  final Color avgColor;

  _PitchChartPainter({
    required this.data,
    this.averageF0,
    required this.minY,
    required this.maxY,
    required this.lineColor,
    required this.avgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final yRange = maxY - minY;
    if (yRange <= 0) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.3),
          lineColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final maxPoints = 200;
    final step = data.length > maxPoints ? data.length / maxPoints : 1.0;
    final visibleData = <double>[];
    for (double i = 0; i < data.length; i += step) {
      visibleData.add(data[i.floor()]);
    }

    if (visibleData.isEmpty) return;

    for (int i = 0; i < visibleData.length; i++) {
      final x = (i / (visibleData.length - 1)) * size.width;
      final normalizedY = (visibleData[i] - minY) / yRange;
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // 绘制填充区域
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, gradientPaint);

    // 绘制线条
    canvas.drawPath(path, paint);

    // 绘制平均线
    if (averageF0 != null && averageF0! > 0) {
      final avgY = size.height - ((averageF0! - minY) / yRange) * size.height;
      final dashPaint = Paint()
        ..color = avgColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final avgPath = Path();
      avgPath.moveTo(0, avgY);
      // 虚线
      for (double x = 0; x < size.width; x += 12) {
        avgPath.moveTo(x, avgY);
        avgPath.lineTo(math.min(x + 6, size.width), avgY);
      }
      canvas.drawPath(avgPath, dashPaint);

      // 平均标签
      final textPainter = TextPainter(
        text: TextSpan(
          text: '平均 ${averageF0!.toStringAsFixed(1)} Hz',
          style: TextStyle(
            color: avgColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(size.width - textPainter.width - 4,
              avgY - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _PitchChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.averageF0 != averageF0;
  }
}
