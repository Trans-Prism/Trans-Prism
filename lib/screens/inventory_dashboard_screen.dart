import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/drug_model.dart';
import '../services/notification_service.dart';
import '../widgets/branded_toast.dart';
import '../widgets/loading_indicator.dart';

/// 药物存量仪表盘与本地用药提醒系统
class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  static const String _storageKey = 'drug_inventory_list';

  List<Drug> _drugs = [];
  bool _isLoading = true;
  bool _notificationPermissionRequested = false;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadDrugs();
    _setupNotificationCallback();
  }

  Future<void> _loadDrugs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      _drugs = Drug.listFromJson(jsonStr);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    _rescheduleAllReminders();
  }

  Future<void> _saveDrugs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, Drug.listToJson(_drugs));
  }

  void _setupNotificationCallback() {
    _notificationService.onDoseRecorded = (drugId) {
      final index = _drugs.indexWhere((d) => d.id == drugId);
      if (index == -1) return;
      setState(() {
        _drugs[index].recordDose();
      });
      _saveDrugs();
    };
  }

  Future<void> _rescheduleAllReminders() async {
    for (final drug in _drugs) {
      await _notificationService.scheduleMedicineReminder(drug);
    }
  }

  Future<bool> _ensureNotificationPermission() async {
    final hasPermission = await _notificationService.hasPermission();
    if (hasPermission) return true;
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      final granted = await _notificationService.requestPermission();
      return granted;
    }
    return false;
  }

  Future<void> _addDrug() async {
    final result = await _DrugFormSheet.show(context);
    if (result == null) return;
    setState(() {
      _drugs.add(result);
    });
    await _saveDrugs();
    await _notificationService.scheduleMedicineReminder(result);
  }

  Future<void> _editDrug(int index) async {
    final drug = _drugs[index];
    final result = await _DrugFormSheet.show(context, existingDrug: drug);
    if (result == null) return;
    setState(() {
      _drugs[index] = result;
    });
    await _saveDrugs();
    await _notificationService.scheduleMedicineReminder(result);
  }

  Future<void> _deleteDrug(int index) async {
    final drug = _drugs[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除药物'),
        content: Text('确定要删除 "${drug.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _drugs.removeAt(index);
    });
    await _saveDrugs();
    await _notificationService.cancelDrugReminders(drug.id);
  }

  Future<void> _toggleReminder(int index, bool enabled) async {
    setState(() {
      _drugs[index].reminderEnabled = enabled;
    });
    await _saveDrugs();
    if (enabled) {
      await _ensureNotificationPermission();
      await _notificationService.scheduleMedicineReminder(_drugs[index]);
    } else {
      await _notificationService.cancelDrugReminders(_drugs[index].id);
    }
  }

  Future<void> _recordDose(int index) async {
    final drug = _drugs[index];
    setState(() {
      drug.recordDose();
    });
    await _saveDrugs();
    await _notificationService.scheduleMedicineReminder(drug);
    if (!mounted) return;
    BrandedToast.doseRecorded(context, drug.name);
  }

  Future<void> _addStock(int index) async {
    final drug = _drugs[index];
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('补仓'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前库存：${drug.currentStock.toStringAsFixed(1)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '增加数量',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value == null || value <= 0) {
                BrandedToast.error(ctx, '请输入有效数量');
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    setState(() {
      _drugs[index].addStock(amount);
    });
    await _saveDrugs();
  }

  // ==================== 主 UI ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '💊 药物存量仪表盘',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D1D1F),
          ),
        ),
      ),
      body: _drugs.isEmpty ? _buildEmptyState() : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDrug,
        backgroundColor: const Color(0xFF5BCEFA),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('添加药物'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_liquid_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有药物记录',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加你的第一种药物\n开始追踪存量与用药提醒',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _addDrug,
              icon: const Icon(Icons.add),
              label: const Text('添加第一种药物'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    double totalStockPercentage = 0;
    int minRunwayDays = 999;

    if (_drugs.isNotEmpty) {
      double totalStock = 0;
      double totalBurn = 0;
      for (final drug in _drugs) {
        totalStock += drug.currentStock;
        totalBurn += drug.dailyBurnRate;
        if (drug.runwayDays < minRunwayDays) {
          minRunwayDays = drug.runwayDays;
        }
      }
      if (totalBurn > 0) {
        final thirtyDayNeed = totalBurn * 30;
        totalStockPercentage = (totalStock / thirtyDayNeed).clamp(0.0, 1.0);
      } else {
        totalStockPercentage = 1.0;
      }
    }

    if (minRunwayDays == 999) minRunwayDays = 0;
    if (_drugs.isEmpty) minRunwayDays = 0;

    return RefreshIndicator(
      onRefresh: _loadDrugs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _buildSummaryCard(totalStockPercentage, minRunwayDays),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '药物清单 (${_drugs.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
          ...List.generate(_drugs.length, (i) => _buildDrugCard(i)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double percentage, int runwayDays) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 7,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFF5A9B8),
                    ),
                  ),
                ),
                Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '安全续航',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$runwayDays',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: runwayDays <= 3
                            ? Colors.red.shade400
                            : const Color(0xFF1D1D1F),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '天',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  runwayDays <= 3 ? '⚠️ 库存紧张，请及时补仓' : '你的稳态库存量充足',
                  style: TextStyle(
                    fontSize: 12,
                    color: runwayDays <= 3
                        ? Colors.red.shade400
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugCard(int index) {
    final drug = _drugs[index];
    final drugPercentage = drug.stockPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '库存: ${drug.currentStock.toStringAsFixed(1)} · ${drug.cycleLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '提醒',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Switch(
                    value: drug.reminderEnabled,
                    onChanged: (val) => _toggleReminder(index, val),
                    activeColor: const Color(0xFF5BCEFA),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (drug.nextDoseTime != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '下次: ${drug.nextDoseLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: drugPercentage,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          drug.runwayDays <= 3
                              ? Colors.red.shade300
                              : const Color(0xFF5BCEFA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '续航 ${drug.runwayDays} 天 · 日消耗 ${drug.dailyBurnRate.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSmallActionButton(
                icon: Icons.remove_circle_outline,
                label: '服药',
                color: const Color(0xFF5BCEFA),
                onTap: () => _recordDose(index),
              ),
              const SizedBox(width: 6),
              _buildSmallActionButton(
                icon: Icons.add_circle_outline,
                label: '补仓',
                color: const Color(0xFFF5A9B8),
                onTap: () => _addStock(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _editDrug(index),
                child: Text(
                  '编辑',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _deleteDrug(index),
                child: Text(
                  '删除',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade300,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 添加/编辑药物表单 — 独立 StatefulWidget 确保触摸事件正常工作
// =============================================================================

class _DrugFormSheet extends StatefulWidget {
  final Drug? existingDrug;

  const _DrugFormSheet({this.existingDrug});

  /// 显示 ModalBottomSheet 并返回创建/编辑后的 Drug
  static Future<Drug?> show(BuildContext context, {Drug? existingDrug}) {
    return showModalBottomSheet<Drug>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DrugFormSheet(existingDrug: existingDrug),
    );
  }

  @override
  State<_DrugFormSheet> createState() => _DrugFormSheetState();
}

class _DrugFormSheetState extends State<_DrugFormSheet> {
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _dosageController = TextEditingController();
  final _cycleValueController = TextEditingController();

  late List<String> _reminderTimes;
  DateTime? _nextDoseTime;
  late CycleUnit _selectedCycleUnit;

  bool get _isEditing => widget.existingDrug != null;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingDrug;
    _nameController.text = existing?.name ?? '';
    _stockController.text = existing?.currentStock.toStringAsFixed(1) ?? '';
    _dosageController.text = existing?.dosage.toStringAsFixed(1) ?? '';
    _reminderTimes =
        List<String>.from(existing?.reminderTimes ?? ['08:00', '20:00']);
    _nextDoseTime = existing?.nextDoseTime;
    _selectedCycleUnit = existing?.cycleUnit ?? CycleUnit.hours;

    if (existing != null) {
      _cycleValueController.text =
          existing.cycleValue == existing.cycleValue.roundToDouble()
              ? existing.cycleValue.toInt().toString()
              : existing.cycleValue.toStringAsFixed(1);
    } else {
      _cycleValueController.text = '12';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _cycleValueController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final stock = double.tryParse(_stockController.text.trim());
    final dosage = double.tryParse(_dosageController.text.trim());
    final cycleVal = double.tryParse(_cycleValueController.text.trim());

    if (name.isEmpty) {
      BrandedToast.error(context, '请输入药物名称');
      return;
    }
    if (stock == null || stock < 0) {
      BrandedToast.error(context, '请输入有效的库存数量');
      return;
    }
    if (dosage == null || dosage <= 0) {
      BrandedToast.error(context, '请输入有效的每次剂量');
      return;
    }
    if (cycleVal == null || cycleVal <= 0) {
      BrandedToast.error(context, '请输入有效的周期数值');
      return;
    }

    final drug = Drug(
      id: widget.existingDrug?.id ?? _uuid.v4(),
      name: name,
      currentStock: stock,
      dosage: dosage,
      cycleValue: cycleVal,
      cycleUnit: _selectedCycleUnit,
      nextDoseTime: _nextDoseTime,
      reminderTimes: List<String>.from(_reminderTimes),
      reminderEnabled: widget.existingDrug?.reminderEnabled ?? true,
    );
    Navigator.pop(context, drug);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 拖拽指示条 ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── 标题 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              children: [
                Text(
                  _isEditing ? '编辑药物' : '添加药物',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── 表单内容 ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FilledField(
                    controller: _nameController,
                    label: '药物名称',
                    hint: '如：雌二醇片',
                  ),
                  const SizedBox(height: 14),

                  // 当前库存 + 每次剂量（并排）
                  Row(
                    children: [
                      Expanded(
                        child: _FilledField(
                          controller: _stockController,
                          label: '当前库存',
                          hint: '如：60',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FilledField(
                          controller: _dosageController,
                          label: '每次剂量',
                          hint: '如：2',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── 周期选择 ──
                  _buildCycleSection(),
                  const SizedBox(height: 14),

                  // ── 下次给药时间 ──
                  _buildNextDoseSection(),
                  const SizedBox(height: 14),

                  // ── 每日提醒时间 ──
                  _buildTimeSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── 底部全宽 CTA ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5BCEFA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(_isEditing ? '保存更改' : '添加药物'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 周期选择 ──
  Widget _buildCycleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            '给药周期',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：「每」+ 数值输入框
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '每',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _cycleValueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 第二行：单位 chips
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: CycleUnit.values.map((unit) {
                  final isSelected = unit == _selectedCycleUnit;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCycleUnit = unit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5BCEFA)
                            : Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5BCEFA)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        unit.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 下次给药时间 ──
  Widget _buildNextDoseSection() {
    final displayText = _nextDoseTime != null
        ? '${_nextDoseTime!.year}/${_nextDoseTime!.month}/${_nextDoseTime!.day}  '
            '${_nextDoseTime!.hour.toString().padLeft(2, '0')}:${_nextDoseTime!.minute.toString().padLeft(2, '0')}'
        : '立即开始（不设置）';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            '下次给药时间',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Material(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _nextDoseTime ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xFF5BCEFA),
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date == null) return;
              if (!context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: _nextDoseTime != null
                    ? TimeOfDay.fromDateTime(_nextDoseTime!)
                    : TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xFF5BCEFA),
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (time == null) return;
              setState(() {
                _nextDoseTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: _nextDoseTime != null
                        ? const Color(0xFF5BCEFA)
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _nextDoseTime != null
                            ? const Color(0xFF1D1D1F)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  if (_nextDoseTime != null)
                    GestureDetector(
                      onTap: () => setState(() => _nextDoseTime = null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 每日提醒时间 ──
  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            '每日提醒时间（短周期可选）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._reminderTimes.map((time) {
                    return Chip(
                      label: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      onDeleted: () {
                        setState(() {
                          _reminderTimes.remove(time);
                        });
                      },
                      backgroundColor:
                          const Color(0xFF5BCEFA).withOpacity(0.08),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                  ActionChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Color(0xFF5BCEFA),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '添加提醒时间',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5BCEFA),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      final now = TimeOfDay.now();
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: now,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme:
                                  Theme.of(context).colorScheme.copyWith(
                                        primary: const Color(0xFF5BCEFA),
                                      ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        final formatted = picked.format(context);
                        if (!_reminderTimes.contains(formatted)) {
                          setState(() {
                            _reminderTimes.add(formatted);
                            _reminderTimes.sort((a, b) => a.compareTo(b));
                          });
                        }
                      }
                    },
                    backgroundColor: const Color(0xFFF5A9B8).withOpacity(0.12),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 无边框填充式输入框
class _FilledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _FilledField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1D1D1F),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade300,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
