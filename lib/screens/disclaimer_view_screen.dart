import 'package:flutter/material.dart';

/// 免责声明查看页（仅供阅读，不强制同意）
///
/// 与首次启动的强制 [DisclaimerPage] 不同，此页面仅用于展示声明内容，
/// 不含倒计时、滚动到底部检测、勾选同意等强制流程。
class DisclaimerViewScreen extends StatelessWidget {
  const DisclaimerViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '免责声明',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ── 标题 ──
          Icon(Icons.gavel, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '免责与使用声明',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '在使用本应用前，请您仔细阅读以下全部声明。',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
          const SizedBox(height: 24),

          // ── 声明一：网络免责声明 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3E2723).withOpacity(0.6)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? Colors.red.shade800 : Colors.red.shade300,
                  width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color:
                            isDark ? Colors.red.shade300 : Colors.red.shade800,
                        size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '网络功能声明（请务必阅读）',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.red.shade200
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '本软件仅为本地文本阅读器和离线工具箱，绝不提供任何形式的 VPN、翻墙、代理或突破网络审查的功能。所有网络请求仅限于获取开源文本。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 声明一的补充说明 ──
          Text(
            '网络声明补充说明',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '• 本应用不会在后台建立任何隐蔽网络通道。\n'
            '• 您可随时在系统设置中撤销本应用的网络权限。\n'
            '• 继续使用即表示您理解并接受上述限制。',
            style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade800),
          ),
          const SizedBox(height: 28),

          // ── 声明二：血药浓度模拟免责声明 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3E2723).withOpacity(0.4)
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      isDark ? Colors.orange.shade800 : Colors.orange.shade300,
                  width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.healing,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                        size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '血药浓度模拟声明（请务必阅读）',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.orange.shade200
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '本软件内置的血药浓度模拟功能仅供医师参考，所有模拟结果均基于公开的数学模型估算，不构成任何医疗建议。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '请在医师指导下进行激素替代疗法（HRT），切勿仅凭模拟结果自行用药、调整剂量或更改用药方案。不当使用激素药物可能对健康造成严重危害。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '开发者不对因使用本血药浓度模拟功能而导致的任何直接或间接后果承担法律责任。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 声明二的补充说明 ──
          Text(
            '血药浓度模拟补充说明',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '• 模拟浓度仅为理论估算，实际血药浓度因个体差异（代谢、体重、肝功能等）会有显著差异。\n'
            '• 请定期进行血液检测，以实际检测结果为准。\n'
            '• 如果您正经历任何不适或副作用，请立即咨询医生。\n'
            '• 18 岁以下用户请在监护人及医生指导下使用。',
            style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade800),
          ),
          const SizedBox(height: 28),

          // ── 声明正文末尾 ──
          Center(
            child: Text(
              '— 声明结束 —',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
