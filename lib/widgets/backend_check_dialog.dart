import 'package:flutter/material.dart';

import '../services/backend_config_service.dart';
import '../screens/voice_training/api_settings_screen.dart';

/// 后端检查结果
enum BackendStatus { configured, notConfigured, connectionFailed }

/// 后端检查对话框
///
/// 在进入需要云端的页面之前调用此工具方法。
/// - 如果配置了后端且连接正常 → 返回 `configured`
/// - 如果未配置后端 → 弹提示框，返回 `notConfigured`
/// - 如果配置了但连接失败 → 弹提示框，返回 `connectionFailed`
Future<BackendStatus> checkBackendAndProceed(
  BuildContext context, {
  required String featureName,
  bool silent = false,
}) async {
  final backend = BackendConfigService();
  await backend.load();

  // 已启用后端
  if (backend.enabled && backend.isConfigured) {
    // 测试连接
    final ok = await backend.testConnection();
    if (ok) return BackendStatus.configured;

    // 连接失败
    if (!silent && context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.cloud_off, color: Color(0xFFF44336)),
            SizedBox(width: 8),
            Text('后端连接失败'),
          ]),
          content: const Text(
            '已检测到 AWS 后端配置，但无法连接到服务器。\n\n'
            '将使用本地模式进行分析，效果可能不如云端完整。\n'
            '如需使用云端完整功能，请检查后端服务是否已部署并运行。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('了解，继续本地模式'),
            ),
          ],
        ),
      );
    }
    return BackendStatus.connectionFailed;
  }

  // 未配置后端
  if (!silent && context.mounted) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.info_outline, color: Color(0xFFFF9800)),
          const SizedBox(width: 8),
          Text(featureName),
        ]),
        content: const Text(
          '您还没有配置 AWS 后端服务。\n\n'
          '当前将使用本地模式进行处理，效果可能不如云端完整分析。\n'
          '如需获得完整的声学分析、PDF报告等云端功能，请部署后端并配置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续本地模式'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ApiSettingsScreen()),
              );
            },
            child: const Text('配置后端'),
          ),
        ],
      ),
    );
  }

  return BackendStatus.notConfigured;
}
