import 'package:flutter/material.dart';

import '../services/permission_manager.dart';
import 'gradient_icon.dart';

// =============================================================================
// BatteryOptimizationGuideCard — 「通知到达率优化」状态检测卡片
//
// 功能：
//   1. 动态检测并展示 3 项关键保活权限的状态
//   2. 点击「去设置」跳转对应的系统设置页
//   3. 图标 + 颜色直观反映状态（绿/红/橙）
// =============================================================================
class BatteryOptimizationGuideCard extends StatefulWidget {
  const BatteryOptimizationGuideCard({super.key});

  @override
  State<BatteryOptimizationGuideCard> createState() =>
      _BatteryOptimizationGuideCardState();
}

class _BatteryOptimizationGuideCardState
    extends State<BatteryOptimizationGuideCard> {
  final PermissionManager _permManager = PermissionManager();

  /// 当前权限状态缓存：true=已授权，false=未授权
  Map<String, bool> _statuses = {
    'notification': false,
    'exact_alarm': false,
    'battery_optimization': false,
  };

  /// 是否正在加载
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _loading = true);
    final statuses = await _permManager.checkPermissionStatuses();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorderColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorderColor),
      ),
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题行 ──
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF5BCEFA).withOpacity(0.15)
                        : const Color(0xFF5BCEFA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: GradientIcon(
                      Icons.notifications_active_rounded,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '通知到达率优化',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '确保系统不拦截您的用药提醒',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF98989E)
                              : const Color(0xFF86868B),
                        ),
                      ),
                    ],
                  ),
                ),
                // 刷新按钮
                IconButton(
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                        ),
                  onPressed: _loading ? null : _refreshStatuses,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 3 项状态条目 ──
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _buildStatusItem(
                isDark: isDark,
                icon: Icons.notifications_outlined,
                title: '系统通知权限',
                granted: _statuses['notification'] ?? false,
                grantedLabel: '已开启',
                deniedLabel: '去开启',
                onDeniedTap: () => _handlePermissionAction(
                  context,
                  'notification',
                  _permManager.requestNotificationPermission,
                ),
              ),
              const Divider(height: 1, indent: 0),
              _buildStatusItem(
                isDark: isDark,
                icon: Icons.battery_charging_full_outlined,
                title: '忽略电池优化',
                granted: _statuses['battery_optimization'] ?? false,
                grantedLabel: '已允许',
                deniedLabel: '去设置',
                onDeniedTap: () => _handlePermissionAction(
                  context,
                  'battery_optimization',
                  _permManager.requestIgnoreBatteryOptimization,
                ),
              ),
              const Divider(height: 1, indent: 0),
              _buildStatusItem(
                isDark: isDark,
                icon: Icons.power_settings_new_rounded,
                title: '厂商后台自启动',
                granted: _statuses['battery_optimization'] ?? false,
                grantedLabel: '已允许',
                deniedLabel: '强烈建议去设置',
                onDeniedTap: () => _handleOpenAutoStart(context),
                // 自启动无法通过 API 判断，跟随电池优化状态作为参考
                // 如果电池优化已允许，标记为黄色「建议确认」
                // 如果未允许，标记为红色「强烈建议」
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建单条状态条目
  Widget _buildStatusItem({
    required bool isDark,
    required IconData icon,
    required String title,
    required bool granted,
    required String grantedLabel,
    required String deniedLabel,
    required VoidCallback onDeniedTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: granted ? null : onDeniedTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // 状态图标
              Icon(
                granted ? Icons.check_circle : Icons.error_outline,
                size: 22,
                color:
                    granted ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
              ),
              const SizedBox(width: 12),
              // 标题
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFF5F5F7)
                        : const Color(0xFF1D1D1F),
                  ),
                ),
              ),
              // 状态文本 / 操作按钮
              if (granted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    grantedLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onDeniedTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE57373).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE57373).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          deniedLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE57373),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Color(0xFFE57373),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────── 交互逻辑 ──────────────

  /// 请求权限并刷新状态
  Future<void> _handlePermissionAction(
    BuildContext context,
    String permissionKey,
    Future<bool> Function() requestFn,
  ) async {
    final granted = await requestFn();
    if (mounted) {
      // 刷新状态
      _refreshStatuses();

      if (!granted) {
        // 如果用户拒绝，引导到系统设置
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE5E5EA)
                        : const Color(0xFF3A3A3C)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '需要手动授权',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: const Text(
              '系统拒绝了此次授权申请，请前往系统设置中手动开启。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('暂不'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5BCEFA),
                ),
                child: const Text('去系统设置'),
              ),
            ],
          ),
        );
        if (shouldOpenSettings == true && mounted) {
          await _permManager.openAppSettings();
        }
      }
    }
  }

  /// 引导用户前往自启动设置
  Future<void> _handleOpenAutoStart(BuildContext context) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.power_settings_new_rounded,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFE5E5EA)
                    : const Color(0xFF3A3A3C)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '厂商后台自启动',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '不同手机品牌（小米、华为、OPPO、vivo 等）的后台管理策略不同，'
              'APP 无法直接代码授权自启动。请按以下步骤操作：',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 12),
            _StepLabel(
              number: '1',
              text: '在系统设置中搜索「自启动」或「后台管理」',
            ),
            SizedBox(height: 6),
            _StepLabel(
              number: '2',
              text: '找到「Trans Prism」并开启自启动开关',
            ),
            SizedBox(height: 6),
            _StepLabel(
              number: '3',
              text: '在近期任务列表中将本应用下划锁定 🔒',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5BCEFA),
            ),
            child: const Text('去系统设置'),
          ),
        ],
      ),
    );
    if (shouldOpen == true && mounted) {
      await _permManager.openAutoStartSettings();
    }
  }
}

/// 步骤说明小部件
class _StepLabel extends StatelessWidget {
  final String number;
  final String text;

  const _StepLabel({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF5BCEFA).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5BCEFA),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}
