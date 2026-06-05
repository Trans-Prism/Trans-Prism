import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/drug_model.dart';
import '../services/medication_service.dart';
import '../services/notification_service.dart';
import '../services/permission_manager.dart';
import '../widgets/battery_optimization_dialog.dart';
import '../widgets/branded_toast.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/medication_card.dart';

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
    // 按下次服药时间升序排列（最紧急的在前，未设置的在最后）
    _drugs.sort((a, b) {
      final aTime = a.nextDoseTime;
      final bTime = b.nextDoseTime;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    _rescheduleAllReminders();
    // 加载完成后检查通知权限
    _checkNotificationPermission();
  }

  /// 检查通知权限，未授权时弹出说明对话框
  Future<void> _checkNotificationPermission() async {
    final hasPerm = await _notificationService.hasPermission();
    if (hasPerm) {
      debugPrint('🔔 [TP-Perm] 通知权限已授予');
      return;
    }
    if (!mounted) return;
    debugPrint('🔔 [TP-Perm] 通知权限未授予，弹出说明对话框');
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded,
                color: Color(0xFF5BCEFA), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '开启用药提醒',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trans Prism 需要通知权限来为您提供本地用药提醒服务。',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 18, color: Color(0xFF5BCEFA)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '不授予权限仍可使用药物库存等其他功能',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security_rounded,
                    size: 18, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trans Prism 是非盈利软件，绝不会推送任何广告或垃圾信息',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不开启', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5BCEFA),
            ),
            child: const Text('允许通知'),
          ),
        ],
      ),
    );
    if (granted == true && mounted) {
      await _notificationService.requestPermission();
    }
  }

  Future<void> _saveDrugs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, Drug.listToJson(_drugs));
  }

  void _setupNotificationCallback() {
    // 通知回调：用户从通知栏点击"已服药"
    // 此处无 UI，直接通过 MedicationService 执行纯数据操作
    _notificationService.onDoseRecorded = (drugId) async {
      debugPrint('💊 [TP-Dash] ========== onDoseRecorded(通知) ==========');
      debugPrint('💊 [TP-Dash] drugId=$drugId');

      await MedicationService.executeMedicationDose(drugId);

      // 重新加载最新数据更新 UI
      await _loadDrugs();
      debugPrint('💊 [TP-Dash] ========== onDoseRecorded 完成 ==========');
    };

    _notificationService.onSnoozeRequested = (drugId) async {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return;
      final drugs = Drug.listFromJson(jsonStr);
      final index = drugs.indexWhere((d) => d.id == drugId);
      if (index == -1) return;
      final drug = drugs[index];
      drug.setNextDoseTime(DateTime.now().add(const Duration(minutes: 5)));
      await prefs.setString(_storageKey, Drug.listToJson(drugs));
      if (mounted) {
        setState(() {
          _drugs = drugs;
        });
      }
      await _notificationService.scheduleMedicineReminder(drug);
      if (mounted) {
        BrandedToast.success(context, '已设置5分钟后提醒 💊');
      }
    };
  }

  Future<void> _rescheduleAllReminders() async {
    for (final drug in _drugs) {
      await _notificationService.scheduleMedicineReminder(drug);
    }
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
    final drug = _drugs[index];
    setState(() {
      _drugs[index].reminderEnabled = enabled;
    });
    await _saveDrugs();
    if (enabled) {
      // 1. 检查通知权限
      final hasPerm = await _notificationService.hasPermission();
      if (!hasPerm && mounted) {
        await _checkNotificationPermission();
      }

      // 2. 检查电池优化状态，未授权时弹出醒目保活引导
      if (mounted) {
        final permStatuses =
            await PermissionManager().checkPermissionStatuses();
        final batteryOptGranted = permStatuses['battery_optimization'] ?? false;
        if (!batteryOptGranted && mounted) {
          await BatteryOptimizationDialog.show(context);
        }
      }

      // 3. 调度提醒
      await _notificationService.scheduleMedicineReminder(drug);
    } else {
      await _notificationService.cancelDrugReminders(drug.id);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '💊 药物存量仪表盘',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_liquid_outlined,
              size: 72,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有药物记录',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加你的第一种药物\n开始追踪存量与用药提醒',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          ...List.generate(_drugs.length, (i) {
            final drug = _drugs[i];
            return MedicationCard(
              key: ValueKey(drug.id),
              drug: drug,
              onDoseRecorded: () {
                // 服药成功后重新加载数据
                _loadDrugs();
              },
              onToggleReminder: (enabled) {
                _toggleReminder(i, enabled);
              },
              onEdit: () {
                _editDrug(i);
              },
              onDelete: () {
                _deleteDrug(i);
              },
              onAddStock: () {
                _addStock(i);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double percentage, int runwayDays) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
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
                        color:
                            runwayDays <= 3 ? Colors.red.shade400 : textColor,
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
}

// =============================================================================
// 添加/编辑药物表单 — 独立 StatefulWidget
// =============================================================================

class _DrugFormSheet extends StatefulWidget {
  final Drug? existingDrug;

  const _DrugFormSheet({this.existingDrug});

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
  final _intervalValueController = TextEditingController();

  late List<String> _dailyReminderTimes;
  DateTime? _nextDoseTime;
  late IntervalUnit _selectedIntervalUnit;
  bool _isDiscreteMode = false;

  bool get _isEditing => widget.existingDrug != null;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingDrug;
    _nameController.text = existing?.name ?? '';
    _stockController.text = existing?.currentStock.toStringAsFixed(1) ?? '';
    _dosageController.text = existing?.dosage.toStringAsFixed(1) ?? '';
    _dailyReminderTimes =
        List<String>.from(existing?.dailyReminderTimes ?? ['08:00', '20:00']);
    _nextDoseTime = existing?.nextDoseTime;
    _selectedIntervalUnit = existing?.intervalUnit ?? IntervalUnit.hours;
    _isDiscreteMode = existing?.dailyReminderTimes.isNotEmpty ?? false;

    if (existing != null) {
      _intervalValueController.text = existing.intervalValue.toString();
    } else {
      _intervalValueController.text = '12';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _intervalValueController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final stock = double.tryParse(_stockController.text.trim());
    final dosage = double.tryParse(_dosageController.text.trim());

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

    if (_isDiscreteMode) {
      if (_dailyReminderTimes.isEmpty) {
        BrandedToast.error(context, '请至少添加一个提醒时间');
        return;
      }
      final drug = Drug(
        id: widget.existingDrug?.id ?? _uuid.v4(),
        name: name,
        currentStock: stock,
        dosage: dosage,
        intervalValue: 24,
        intervalUnit: IntervalUnit.hours,
        nextDoseTime: _nextDoseTime,
        dailyReminderTimes: List<String>.from(_dailyReminderTimes),
        reminderEnabled: widget.existingDrug?.reminderEnabled ?? true,
      );
      Navigator.pop(context, drug);
    } else {
      final intervalVal = int.tryParse(_intervalValueController.text.trim());
      if (intervalVal == null || intervalVal <= 0) {
        BrandedToast.error(context, '请输入有效的间隔数值');
        return;
      }
      final drug = Drug(
        id: widget.existingDrug?.id ?? _uuid.v4(),
        name: name,
        currentStock: stock,
        dosage: dosage,
        intervalValue: intervalVal,
        intervalUnit: _selectedIntervalUnit,
        nextDoseTime: _nextDoseTime,
        dailyReminderTimes: [],
        reminderEnabled: widget.existingDrug?.reminderEnabled ?? true,
      );
      Navigator.pop(context, drug);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
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
                    isDark: isDark,
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
                          isDark: isDark,
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
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── 模式切换 ──
                  _buildModeSwitch(isDark: isDark),
                  const SizedBox(height: 16),

                  // ── 周期选择（仅固定间隔模式） ──
                  if (!_isDiscreteMode) _buildCycleSection(isDark: isDark),
                  if (!_isDiscreteMode) const SizedBox(height: 14),

                  // ── 下次给药时间 ──
                  _buildNextDoseSection(isDark: isDark),
                  const SizedBox(height: 14),

                  // ── 每日提醒时间（仅日内离散模式） ──
                  if (_isDiscreteMode) _buildTimeSection(isDark: isDark),
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

  // ── 模式切换 ──
  Widget _buildModeSwitch({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF5BCEFA).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDiscreteMode ? '日内离散模式' : '固定间隔模式',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF5F5F7)
                        : const Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isDiscreteMode
                      ? '一日多次用药，如每日 08:00、20:00'
                      : '一天一次及以上，按固定间隔重复',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isDiscreteMode,
            onChanged: (val) => setState(() => _isDiscreteMode = val),
            activeColor: const Color(0xFF5BCEFA),
          ),
        ],
      ),
    );
  }

  // ── 周期选择 ──
  Widget _buildCycleSection({required bool isDark}) {
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

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
            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
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
                  Text(
                    '每',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _intervalValueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
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
                children: IntervalUnit.values.map((unit) {
                  final isSelected = unit == _selectedIntervalUnit;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIntervalUnit = unit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5BCEFA)
                            : (isDark
                                ? const Color(0xFF3A3A3C)
                                : Colors.white.withOpacity(0.7)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5BCEFA)
                              : (isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        unit.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : textColor,
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
  Widget _buildNextDoseSection({required bool isDark}) {
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
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
          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
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
                builder: (ctx, child) {
                  return Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx).colorScheme.copyWith(
                            primary: const Color(0xFF5BCEFA),
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (!context.mounted) return;
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
                            ? textColor
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
  Widget _buildTimeSection({required bool isDark}) {
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            '每日提醒时间',
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
            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
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
                  ..._dailyReminderTimes.map((time) {
                    return Chip(
                      label: Text(
                        time,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      onDeleted: () {
                        setState(() {
                          _dailyReminderTimes.remove(time);
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
                        // 统一 24h 格式避免 AM/PM 解析问题
                        final formatted =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        if (!_dailyReminderTimes.contains(formatted)) {
                          setState(() {
                            _dailyReminderTimes.add(formatted);
                            _dailyReminderTimes.sort((a, b) => a.compareTo(b));
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
  final bool isDark;

  const _FilledField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
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
        fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
