import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drug_model.dart';
import '../screens/inventory_dashboard_screen.dart';

/// =============================================================================
/// MedicationStockSummary — 药物存量摘要卡片
///
/// 从 SharedPreferences 加载药物数据，计算总库存百分比与安全续航天数。
/// 适合嵌入首页作为核心状态模块，点击可跳转至完整仪表盘。
///
/// 卡片样式与首页其他卡片保持视觉一致性（圆角 16、投影柔和）。
/// =============================================================================
class MedicationStockSummary extends StatefulWidget {
  const MedicationStockSummary({super.key});

  @override
  State<MedicationStockSummary> createState() => _MedicationStockSummaryState();
}

class _MedicationStockSummaryState extends State<MedicationStockSummary> {
  static const String _storageKey = 'drug_inventory_list';

  List<Drug> _drugs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      _drugs = Drug.listFromJson(jsonStr);
      _drugs.sort((a, b) {
        final aTime = a.nextDoseTime;
        final bTime = b.nextDoseTime;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerCard(context);
    }
    return _buildSummaryCard(context);
  }

  Widget _buildShimmerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5);
    final cardColor = isDark ? const Color(0xFF24242C) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shimmerColor,
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 14,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 100,
                height: 36,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);
    final cardColor = isDark ? const Color(0xFF24242C) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5);
    final trackColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFE5E5E5);
    final warningColor =
        isDark ? const Color(0xFFE57373) : const Color(0xFFC44A4A);

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
    final isWarning = minRunwayDays <= 3 && _drugs.isNotEmpty;

    return InkWell(
      onTap: () => _openDashboard(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // ── 环形进度（细环克制） ──
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
                      value: totalStockPercentage,
                      strokeWidth: 4,
                      backgroundColor: trackColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isWarning
                            ? warningColor
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${(totalStockPercentage * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // ── 文字信息 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '安全续航',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryColor,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$minRunwayDays',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: isWarning ? warningColor : textColor,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '天',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _drugs.isEmpty
                        ? '暂无药物记录，点击添加'
                        : (isWarning ? '库存紧张，请及时补仓' : '你的稳态库存量充足'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: _drugs.isEmpty
                          ? secondaryColor
                          : (isWarning ? warningColor : secondaryColor),
                    ),
                  ),
                ],
              ),
            ),
            // ── 箭头 ──
            Icon(
              Icons.chevron_right,
              color: secondaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDashboard(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InventoryDashboardScreen(),
      ),
    );
    // 从仪表盘返回后刷新数据
    if (mounted) {
      setState(() => _isLoading = true);
      _loadDrugs();
    }
  }
}
