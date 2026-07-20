import 'package:flutter/material.dart';

import '../constants/injection_templates.dart';
import '../services/medication_service.dart';
import '../storage/medication_profile_repository.dart';

/// 注射部位智能选择器
///
/// 核心职责（读心术 + 调教系统）：
/// 1. 监听药物名称，自动查找是否已绑定轮换模板
/// 2. 已绑定 → 渲染 ChoiceChip Wrap，智能推荐并高亮默认选中
/// 3. 未绑定 → 显示「开启注射部位轮换」按钮，引导用户选择模板
///
/// [onSiteSelected] 当用户选择/取消部位时的回调
/// [onTemplateBound] 当首次绑定模板成功时的回调（用于外部持久化）
class InjectionSiteSelector extends StatefulWidget {
  /// 当前药物名称（受控，由外部传入或通过 onDrugNameChanged 更新）
  final String drugName;

  /// 部位选择回调：选中的部位名称，null 表示取消选择
  final ValueChanged<String?>? onSiteSelected;

  /// 模板首次绑定回调：绑定成功时调用，传出模板 ID
  final ValueChanged<String>? onTemplateBound;

  const InjectionSiteSelector({
    super.key,
    required this.drugName,
    this.onSiteSelected,
    this.onTemplateBound,
  });

  @override
  State<InjectionSiteSelector> createState() => _InjectionSiteSelectorState();
}

class _InjectionSiteSelectorState extends State<InjectionSiteSelector> {
  final MedicationProfileRepository _profileRepo =
      MedicationProfileRepository();

  /// 加载状态
  bool _loading = true;

  /// 当前绑定的模板 ID（null = 未绑定）
  String? _templateId;

  /// 绑定的模板部位列表
  List<String> _sites = [];

  /// 推荐的下一个部位
  String? _recommendedSite;

  /// 当前选中的部位
  String? _selectedSite;

  /// 是否正在绑定（防止重复点击）
  bool _bindingInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadBinding();
  }

  @override
  void didUpdateWidget(InjectionSiteSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drugName != oldWidget.drugName) {
      _selectedSite = null;
      // ⚠️ 不能在 didUpdateWidget（build 阶段）直接调用 widget.onSiteSelected，
      //    该回调会触发父级 RecordDoseDialog.setState，导致
      //    「Tried to build dirty widget in the wrong build scope」。
      //    延迟到当前帧构建完成后再通知父级。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSiteSelected?.call(null);
        }
      });
      _loadBinding();
    }
  }

  /// 加载模板绑定状态并计算推荐部位
  Future<void> _loadBinding() async {
    setState(() => _loading = true);

    final name = widget.drugName.trim();
    if (name.isEmpty) {
      setState(() {
        _loading = false;
        _templateId = null;
        _sites = [];
        _recommendedSite = null;
      });
      return;
    }

    final templateId = await _profileRepo.getTemplateIdForDrug(name);
    if (templateId != null && injectionTemplates.containsKey(templateId)) {
      final sites = List<String>.from(injectionTemplates[templateId]!);
      // 使用智能推荐算法计算下一部位
      final recommended = await MedicationService.calculateNextSiteByName(name);

      if (mounted) {
        // ⚠️ 关键：widget.onSiteSelected 会触发父级 RecordDoseDialog.setState，
        //    必须在 setState 外部调用，否则会触发
        //    「Tried to build dirty widget in the wrong build scope」错误。
        String? siteToNotify;
        setState(() {
          _loading = false;
          _templateId = templateId;
          _sites = sites;
          _recommendedSite = recommended;
          if (_selectedSite == null && recommended != null) {
            _selectedSite = recommended;
            siteToNotify = recommended;
          }
        });
        // 在 setState 回调之后、当前帧构建完成前通知父级
        if (siteToNotify != null) {
          widget.onSiteSelected?.call(siteToNotify);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
          _templateId = null;
          _sites = [];
          _recommendedSite = null;
        });
      }
    }
  }

  /// 显示模板选择弹窗
  Future<void> _showTemplatePicker() async {
    if (_bindingInProgress) return;
    setState(() => _bindingInProgress = true);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    final templateId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '选择轮换模板',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: injectionTemplates.entries.map((entry) {
                final tid = entry.key;
                final label = injectionTemplateLabels[tid] ?? tid;
                final siteCount = entry.value.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color:
                        isDark ? const Color(0xFF24242C) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(ctx, tid),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.swap_horiz_rounded,
                              color: Color(0xFFF5A9B8),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5A9B8).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$siteCount 部位',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF5A9B8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (!mounted) {
      setState(() => _bindingInProgress = false);
      return;
    }

    if (templateId != null) {
      // 绑定成功后立即更新本地状态
      final sites = List<String>.from(injectionTemplates[templateId]!);
      setState(() {
        _templateId = templateId;
        _sites = sites;
        _recommendedSite = sites.isNotEmpty ? sites.first : null;
        _selectedSite = sites.isNotEmpty ? sites.first : null;
      });
      widget.onSiteSelected?.call(_selectedSite);
      widget.onTemplateBound?.call(templateId);
    }

    setState(() => _bindingInProgress = false);
  }

  @override
  Widget build(BuildContext context) {
    // 药物名称为空时不显示任何内容
    if (widget.drugName.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // ── 已绑定模板 → 渲染 ChoiceChip Wrap ──
    if (_templateId != null && _sites.isNotEmpty) {
      return _buildSiteChips();
    }

    // ── 未绑定模板 → 显示开启按钮 ──
    return _buildBindButton();
  }

  /// 已绑定模板：渲染 ChoiceChip 部位选择区
  Widget _buildSiteChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = injectionTemplateLabels[_templateId] ?? _templateId;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 模板标题
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: Color(0xFFF5A9B8),
              ),
              const SizedBox(width: 4),
              Text(
                '轮换模板: $label',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              // 更换模板按钮
              GestureDetector(
                onTap: _bindingInProgress ? null : _showTemplatePicker,
                child: const Text(
                  '更换',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF5A9B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 推荐标签
          if (_recommendedSite != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: Color(0xFFF5A9B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '推荐: $_recommendedSite',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF5A9B8),
                    ),
                  ),
                ],
              ),
            ),
          // 部位 ChoiceChip
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sites.map((site) {
              final isRecommended = site == _recommendedSite;
              final isSelected = site == _selectedSite;

              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRecommended)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFF5A9B8),
                        ),
                      ),
                    Text(site),
                  ],
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFF5A9B8),
                backgroundColor:
                    isDark ? const Color(0xFF24242C) : Colors.grey.shade100,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isRecommended ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFEDEDF0) : null),
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedSite = selected ? site : null;
                  });
                  widget.onSiteSelected?.call(selected ? site : null);
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 未绑定模板：低调的「开启部位轮换」按钮
  Widget _buildBindButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: TextButton.icon(
        onPressed: _bindingInProgress ? null : _showTemplatePicker,
        icon: Icon(
          Icons.add_rounded,
          size: 16,
          color: _bindingInProgress ? Colors.grey : const Color(0xFFF5A9B8),
        ),
        label: Text(
          _bindingInProgress ? '加载中...' : '开启注射部位轮换（仅限注射剂）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _bindingInProgress ? Colors.grey : const Color(0xFFF5A9B8),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
