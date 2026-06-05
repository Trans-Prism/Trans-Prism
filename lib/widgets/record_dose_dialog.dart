import 'package:flutter/material.dart';

import '../models/drug_model.dart';
import '../services/medication_service.dart';
import '../storage/medication_profile_repository.dart';
import 'branded_toast.dart';
import 'injection_site_selector.dart';

/// 用药记录确认对话框
///
/// 在用户点击「服药」时弹出，提供：
/// 1. 注射部位智能选择（已绑定模板时显示 ChoiceChip）
/// 2. 首次绑定模板引导（未绑定时显示开启按钮）
/// 3. 确认后执行 executeMedicationDose + 自动学习模板绑定
///
/// 使用方式：
/// ```dart
/// final recorded = await RecordDoseDialog.show(context, drug: drug);
/// if (recorded == true) { /* UI 刷新 */ }
/// ```
class RecordDoseDialog extends StatefulWidget {
  final Drug drug;

  const RecordDoseDialog({super.key, required this.drug});

  /// 弹出对话框，返回 true 表示成功记录用药
  static Future<bool?> show(BuildContext context, {required Drug drug}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordDoseDialog(drug: drug),
    );
  }

  @override
  State<RecordDoseDialog> createState() => _RecordDoseDialogState();
}

class _RecordDoseDialogState extends State<RecordDoseDialog> {
  final MedicationProfileRepository _profileRepo =
      MedicationProfileRepository();

  /// 用户选择的注射部位（null = 未选择）
  String? _selectedSite;

  /// 是否为首次绑定（需要持久化到 userMedicationProfiles）
  bool _isFirstBinding = false;

  /// 新绑定的模板 ID（仅在首次绑定时非空）
  String? _newTemplateId;

  /// 是否正在提交
  bool _submitting = false;

  /// 部位选择回调
  void _onSiteSelected(String? site) {
    setState(() => _selectedSite = site);
  }

  /// 模板首次绑定回调
  void _onTemplateBound(String templateId) {
    _isFirstBinding = true;
    _newTemplateId = templateId;
  }

  /// 确认用药
  Future<void> _confirmDose() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // ── 1. 如果是首次绑定，先持久化模板映射 ──
      if (_isFirstBinding && _newTemplateId != null) {
        await _profileRepo.setTemplateForDrug(
          widget.drug.name,
          _newTemplateId!,
        );
        debugPrint('💊 [TP-RDD] 首次绑定: ${widget.drug.name} → $_newTemplateId');
      }

      // ── 2. 执行核心用药动作（纯数据层） ──
      final log = await MedicationService.executeMedicationDose(
        widget.drug.id,
        site: _selectedSite,
      );

      if (log == null) {
        if (mounted) {
          BrandedToast.error(context, '用药记录失败，请重试');
        }
        return;
      }

      debugPrint('💊 [TP-RDD] 用药记录成功: id=${log.id}, site=$_selectedSite');

      if (mounted) {
        BrandedToast.doseRecorded(context, widget.drug.name);
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('💊 [TP-RDD] ❌ 用药记录异常: $e');
      if (mounted) {
        BrandedToast.error(context, '记录失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final secondaryTextColor =
        isDark ? const Color(0xFF98989E) : const Color(0xFF86868B);

    final drug = widget.drug;

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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BCEFA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_outlined,
                    color: Color(0xFF5BCEFA),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '记录用药',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        drug.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 药物信息摘要
                  _buildInfoRow(
                    isDark: isDark,
                    icon: Icons.inventory_2_outlined,
                    label: '当前库存',
                    value: '${drug.currentStock.toStringAsFixed(1)} 单位',
                    valueColor: textColor,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    isDark: isDark,
                    icon: Icons.colorize_outlined,
                    label: '本次剂量',
                    value: '${drug.dosage.toStringAsFixed(1)} 单位',
                    valueColor: textColor,
                  ),
                  const SizedBox(height: 8),
                  if (drug.nextDoseTime != null)
                    _buildInfoRow(
                      isDark: isDark,
                      icon: Icons.schedule_rounded,
                      label: '下次计划',
                      value: drug.nextDoseLabel,
                      valueColor: const Color(0xFFF5A9B8),
                    ),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 16),

                  // ── 注射部位选择器 ──
                  Text(
                    '注射部位（可选）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InjectionSiteSelector(
                    drugName: drug.name,
                    onSiteSelected: _onSiteSelected,
                    onTemplateBound: _onTemplateBound,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── 底部按钮 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: secondaryTextColor,
                        side: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _confirmDose,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5BCEFA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(_submitting ? '记录中...' : '确认服药'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
