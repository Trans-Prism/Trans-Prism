import 'dart:async';

import 'package:flutter/material.dart';

import '../models/drug_model.dart';
import '../services/medication_service.dart';
import 'branded_toast.dart';
import 'record_dose_dialog.dart';

/// 药物卡片 — 支持基于周期的动态形态
///
/// 视觉层级（自上而下）：
/// 1. 头部：药名 + 提醒开关 + 更多操作(PopupMenu)
/// 2. 时间区：短周期→倒计时 / 长周期→日历+进度环
/// 3. 推荐注射部位：低调文字行（如有）
/// 4. 库存信息面板：灰底圆角容器，整合进度条+库存+续航+日消耗
/// 5. 底部操作：主按钮「打卡 / 服用」+ 次级按钮「补仓」
class MedicationCard extends StatefulWidget {
  final Drug drug;

  /// 服药成功后回调（用于父级刷新列表）
  final VoidCallback? onDoseRecorded;

  /// 提醒开关切换
  final ValueChanged<bool>? onToggleReminder;

  /// 编辑
  final VoidCallback? onEdit;

  /// 删除
  final VoidCallback? onDelete;

  /// 补仓
  final VoidCallback? onAddStock;

  const MedicationCard({
    super.key,
    required this.drug,
    this.onDoseRecorded,
    this.onToggleReminder,
    this.onEdit,
    this.onDelete,
    this.onAddStock,
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard> {
  Timer? _countdownTimer;
  Duration _timeUntilNext = Duration.zero;

  /// 推荐的下次注射部位
  String? _recommendedSite;
  bool _recommendationLoaded = false;

  @override
  void initState() {
    super.initState();
    _updateTimeUntilNext();
    _loadRecommendedSite();
    if (_isShortCycle) {
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateTimeUntilNext(),
      );
    }
  }

  @override
  void didUpdateWidget(MedicationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drug.id != oldWidget.drug.id ||
        widget.drug.nextDoseTime != oldWidget.drug.nextDoseTime) {
      _updateTimeUntilNext();
      _loadRecommendedSite();
      _countdownTimer?.cancel();
      if (_isShortCycle) {
        _countdownTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _updateTimeUntilNext(),
        );
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateTimeUntilNext() {
    final next = widget.drug.nextDoseTime;
    setState(() {
      _timeUntilNext =
          next != null ? next.difference(DateTime.now()) : Duration.zero;
    });
  }

  Future<void> _loadRecommendedSite() async {
    final site = await MedicationService.calculateNextSiteByName(
      widget.drug.name,
    );
    if (mounted) {
      setState(() {
        _recommendedSite = site;
        _recommendationLoaded = true;
      });
    }
  }

  // ─────────────────── 周期判断 ───────────────────

  static const int _shortCycleThresholdDays = 14;

  double get _intervalInDays {
    if (widget.drug.isDiscreteMode) return 1;
    switch (widget.drug.intervalUnit) {
      case IntervalUnit.hours:
        return widget.drug.intervalValue / 24.0;
      case IntervalUnit.days:
        return widget.drug.intervalValue.toDouble();
      case IntervalUnit.weeks:
        return widget.drug.intervalValue * 7.0;
      case IntervalUnit.months:
        return widget.drug.intervalValue * 30.0;
    }
  }

  bool get _isShortCycle => _intervalInDays < _shortCycleThresholdDays;
  bool get _isLongCycle => !_isShortCycle;

  double get _progressValue {
    final next = widget.drug.nextDoseTime;
    if (next == null) return 0.0;
    final now = DateTime.now();
    final interval = Duration(hours: (_intervalInDays * 24).round());
    if (interval.inSeconds <= 0) return 1.0;
    final elapsed = now.difference(next.subtract(interval));
    return (elapsed.inSeconds / interval.inSeconds).clamp(0.0, 1.0);
  }

  // ─────────────────── 打卡 ───────────────────

  Future<void> _handleDoseTap() async {
    final recorded = await RecordDoseDialog.show(context, drug: widget.drug);
    if (recorded == true && mounted) {
      // 在底部弹出层关闭后，使用 MedicationCard 的 context 展示 Toast。
      // 此 context 在卡片生命周期内始终有效，避免在 OverlayEntry 插入
      // 与 Navigator.pop 之间产生竞态条件。
      BrandedToast.doseRecorded(context, widget.drug.name);
      widget.onDoseRecorded?.call();
    }
  }

  // ─────────────────── 倒计时格式化 ───────────────────

  String get _countdownText {
    if (_timeUntilNext.isNegative) return '已过期';
    if (_timeUntilNext.inDays > 0) {
      final hours = _timeUntilNext.inHours % 24;
      return '剩余 ${_timeUntilNext.inDays}天 $hours小时';
    }
    if (_timeUntilNext.inHours > 0) {
      final minutes = _timeUntilNext.inMinutes % 60;
      return '剩余 ${_timeUntilNext.inHours}小时 $minutes分钟';
    }
    if (_timeUntilNext.inMinutes > 0) {
      final seconds = _timeUntilNext.inSeconds % 60;
      return '剩余 ${_timeUntilNext.inMinutes}分钟 $seconds秒';
    }
    if (_timeUntilNext.inSeconds > 0) {
      return '剩余 ${_timeUntilNext.inSeconds}秒';
    }
    return '即将开始';
  }

  Color _countdownColor(BuildContext context) {
    if (_timeUntilNext.isNegative) return Colors.red.shade400;
    if (_timeUntilNext.inHours < 1) return Colors.red.shade400;
    if (_timeUntilNext.inDays < 1) return Colors.orange.shade400;
    return Theme.of(context).colorScheme.primary;
  }

  String get _nextDateText {
    final next = widget.drug.nextDoseTime;
    if (next == null) return '未设置';
    return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════
  // 构建
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drug = widget.drug;
    final drugPercentage = drug.stockPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24242C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══════ 1. 头部 ═══════
          _buildHeader(isDark, drug),

          // ═══════ 2. 时间区 ═══════
          if (drug.nextDoseTime != null) ...[
            const SizedBox(height: 8),
            if (_isShortCycle) _buildCountdownRow(isDark),
            if (_isLongCycle) _buildCalendarRow(isDark),
          ],

          // ═══════ 3. 推荐注射部位（低调文字行） ═══════
          if (_recommendationLoaded && _recommendedSite != null) ...[
            const SizedBox(height: 6),
            _buildSiteRow(isDark),
          ],

          // ═══════ 4. 库存信息面板 ═══════
          const SizedBox(height: 10),
          _buildStockPanel(isDark, drugPercentage, drug),

          // ═══════ 5. 底部操作 ═══════
          const SizedBox(height: 12),
          _buildActions(isDark),
        ],
      ),
    );
  }

  // ──────── 1. 头部 ────────

  Widget _buildHeader(bool isDark, Drug drug) {
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    return Row(
      children: [
        // 药名
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                drug.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                drug.cycleLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        // 提醒开关 + 更多菜单
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: drug.reminderEnabled,
              onChanged: (val) => widget.onToggleReminder?.call(val),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isDark ? const Color(0xFF24242C) : Colors.white,
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    widget.onEdit?.call();
                  case 'delete':
                    widget.onDelete?.call();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: textColor),
                      const SizedBox(width: 8),
                      Text('编辑', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ──────── 2a. 短周期：倒计时行 ────────

  Widget _buildCountdownRow(bool isDark) {
    final countdownColor = _countdownColor(context);

    return Row(
      children: [
        Icon(Icons.alarm_rounded, size: 16, color: countdownColor),
        const SizedBox(width: 4),
        Text(
          _countdownText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: countdownColor,
          ),
        ),
        const Spacer(),
        Text(
          _formatTime(widget.drug.nextDoseTime),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ──────── 2b. 长周期：日历行 ────────

  Widget _buildCalendarRow(bool isDark) {
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final progress = _progressValue;

    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('下次日期',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text(
                _nextDateText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          _formatTime(widget.drug.nextDoseTime),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ──────── 3. 推荐注射部位（低调文字行） ────────

  Widget _buildSiteRow(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.healing_outlined,
          size: 16,
          color: isDark
              ? Colors.grey.shade500
              : Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '下次推荐部位：$_recommendedSite',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.grey.shade400
                : Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ──────── 4. 库存信息面板（灰底圆角） ────────

  Widget _buildStockPanel(bool isDark, double percentage, Drug drug) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24242C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                drug.runwayDays <= 3
                    ? Colors.red.shade300
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 紧凑信息行
          Row(
            children: [
              _infoCell('库存', '${drug.currentStock.toStringAsFixed(1)} 单位'),
              _infoDivider(),
              _infoCell('续航', '${drug.runwayDays} 天'),
              _infoDivider(),
              _infoCell('日消耗', '${drug.dailyBurnRate.toStringAsFixed(1)} 单位'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '|',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  // ──────── 5. 底部操作 ────────

  Widget _buildActions(bool isDark) {
    return Row(
      children: [
        // 主按钮：打卡/服用
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: _handleDoseTap,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                '打卡 / 服用',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 次级按钮：补仓
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => widget.onAddStock?.call(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              '补仓',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              side: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────── 辅助 ────────

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
