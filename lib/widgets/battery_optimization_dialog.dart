import 'package:flutter/material.dart';

import '../services/permission_manager.dart';

// =============================================================================
// BatteryOptimizationDialog — 「如何确保不错过吃药时间？」醒目弹窗
//
// 触发时机：
//   用户开启某个药物的用药提醒时，检测到「忽略电池优化」未授权
//
// 视觉风格：
//   顶部大号警告图标 + 醒目的标题 + 分步引导 + 强调色 CTA 按钮
// =============================================================================
class BatteryOptimizationDialog {
  /// 弹出保活配置引导弹窗
  ///
  /// 返回 `true` 表示用户点击了「去配置」，`false` 表示「稍后再说」
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 强提醒，不可点击外部关闭
      builder: (ctx) => const _BatteryOptimizationDialogBody(),
    );
  }
}

class _BatteryOptimizationDialogBody extends StatefulWidget {
  const _BatteryOptimizationDialogBody();

  @override
  State<_BatteryOptimizationDialogBody> createState() =>
      _BatteryOptimizationDialogBodyState();
}

class _BatteryOptimizationDialogBodyState
    extends State<_BatteryOptimizationDialogBody> {
  final PermissionManager _permManager = PermissionManager();

  /// 是否正在跳转设置
  bool _navigating = false;

  Future<void> _handleGoSettings() async {
    setState(() => _navigating = true);
    // 先尝试请求忽略电池优化
    final granted = await _permManager.requestIgnoreBatteryOptimization();
    // 如果系统对话框被拒绝，打开系统设置页
    if (!granted && mounted) {
      await _permManager.openAppSettings();
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: surfaceColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 顶部大号警告图标 ──
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE57373).withOpacity(0.1),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              size: 40,
              color: Color(0xFFE57373),
            ),
          ),
          const SizedBox(height: 20),

          // ── 醒目标题 ──
          const Text(
            '如何确保不错过吃药时间？',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // ── 警告说明 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA726).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFA726).withOpacity(0.2),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Color(0xFFFFA726)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '安卓系统可能会为了省电而杀掉提醒，'
                        '导致您错过用药时间！',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Color(0xFFFFA726),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 分步引导 ──
          const Text(
            '请务必完成以下设置：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          _buildStep(
            number: '1',
            icon: Icons.battery_charging_full_outlined,
            title: '允许 App 后台运行及自启动',
            subtitle: '在系统设置中关闭电池优化',
          ),
          const SizedBox(height: 10),
          _buildStep(
            number: '2',
            icon: Icons.lock_outline,
            title: '在多任务界面将本 App 下划上锁 🔒',
            subtitle: '防止一键清理时被误杀',
          ),

          const SizedBox(height: 8),
        ],
      ),
      actions: [
        // ── 跳过按钮 ──
        TextButton(
          onPressed: _navigating ? null : () => Navigator.pop(context, false),
          child: Text(
            '稍后再说',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // ── 主按钮：去配置 ──
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _navigating ? null : _handleGoSettings,
              icon: _navigating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.settings_rounded, size: 20),
              label: Text(_navigating ? '跳转中...' : '去配置'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 步骤编号圆
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 步骤内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
}
