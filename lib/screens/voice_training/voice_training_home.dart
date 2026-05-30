import 'package:flutter/material.dart';

import '../../models/voice_training/voice_event.dart';
import '../../services/ai_encouragement_service.dart';
import '../../services/api_settings_service.dart';
import '../../services/voice_training_service.dart';
import '../../widgets/vfs_license_notice.dart';
import 'quick_f0_test_screen.dart';
import 'surveys/rbh_survey_screen.dart';
import 'surveys/tvqg_survey_screen.dart';
import 'note_frequency_tool_screen.dart';
import 'training_history_screen.dart';
import 'voice_test_wizard_screen.dart';
import 'scale_practice_screen.dart';
import 'api_settings_screen.dart';
import 'piano_screen.dart';

/// 嗓音训练辅助主页
///
/// 从 vfs-tracker 的主要功能整合而来，提供以下入口：
/// - 快速基频测试 (QuickF0Test)
/// - RBH 量表评估 (SurveyRBH)
/// - TVQ-G 问卷 (SurveyTVQG)
/// - Hz-音符转换器 (NoteFrequencyTool)
/// - 训练记录查看
class VoiceTrainingHomeScreen extends StatelessWidget {
  const VoiceTrainingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final introTextColor =
        isDark ? const Color(0xFFE5E5EA) : const Color(0xFF616161);
    return Scaffold(
      appBar: AppBar(
        title: const Text('声音训练辅助'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 头部说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF14B8A6).withOpacity(0.1),
                  const Color(0xFF0D9488).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF14B8A6).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mic_external_on_rounded,
                    color: Color(0xFF14B8A6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '提供嗓音训练辅助工具，包括基频检测、主观评估、音高转换等功能。',
                        style: TextStyle(
                          fontSize: 12,
                          color: introTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            '嗓音测试',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.manage_search,
            title: '嗓音综合测试向导',
            subtitle: '8步完整嗓音评估：校准→元音→滑音→朗读→量表→报告',
            gradientColors: const [Color(0xFF00897B), Color(0xFF00695C)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const VoiceTestWizardScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.mic,
            title: '快速基频测试',
            subtitle: '实时检测您的基频（F0），可视化音高变化趋势',
            gradientColors: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const QuickF0TestScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.scale,
            title: '音阶练习',
            subtitle: '6种模式音阶练习，实时检测音高准确度',
            gradientColors: const [Color(0xFFFF7043), Color(0xFFE64A19)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ScalePracticeScreen()),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            '主观评估',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.assignment,
            title: 'RBH 量表',
            subtitle: '评估嗓音粗糙度、气息感、嘶哑度（0-3分）',
            gradientColors: const [Color(0xFF7B1FA2), Color(0xFF6A1B9A)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RBHSurveyScreen(
                  onSave: (score) {
                    _saveVoiceTrainingEvent(context, rbhScore: score);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.quiz,
            title: 'TVQ-G 通用嗓音问卷',
            subtitle: '12项嗓音相关问题评估（0-4分）',
            gradientColors: const [Color(0xFF7B1FA2), Color(0xFF6A1B9A)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TVQGSurveyScreen(
                  onSave: (scores) {
                    _saveVoiceTrainingEvent(context, tvqgScores: scores);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            '工具',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.piano,
            title: '钢琴',
            subtitle: '88键全键盘钢琴，支持横屏模式，点击发声',
            gradientColors: const [Color(0xFF5C6BC0), Color(0xFF3949AB)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PianoScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.transform,
            title: 'Hz-音符转换器',
            subtitle: '频率与音名双向转换，带钢琴键盘可视化',
            gradientColors: const [Color(0xFFFF7043), Color(0xFFE64A19)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NoteFrequencyToolScreen()),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'AI 与云端',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.auto_awesome,
            title: 'AI 鼓励消息',
            subtitle: '配置 OpenAI 兼容 API 后获取个性化训练鼓励',
            gradientColors: const [Color(0xFF7C4DFF), Color(0xFF651FFF)],
            onTap: () => _showAiEncouragement(context),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.cloud_outlined,
            title: '云端服务（需部署）',
            subtitle: '嗓音分析/文件上传/PDF报告 - 需后端部署',
            gradientColors: const [Color(0xFF546E7A), Color(0xFF37474F)],
            onTap: () => _showCloudServices(context),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.settings,
            title: 'API 配置',
            subtitle: '配置 OpenAI 兼容 API 端点与密钥',
            gradientColors: const [Color(0xFF607D8B), Color(0xFF455A64)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ApiSettingsScreen()),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            '记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.history,
            title: '训练记录',
            subtitle: '查看所有嗓音测试和训练记录',
            gradientColors: const [Color(0xFF5C6BC0), Color(0xFF3949AB)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TrainingHistoryScreen()),
            ),
          ),
          const VfsLicenseNotice(),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFAEAEB2) : const Color(0xFF757575);
    final chevronColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFFBDBDBD);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: chevronColor),
          ],
        ),
      ),
    );
  }

  void _saveVoiceTrainingEvent(
    BuildContext context, {
    RBHScore? rbhScore,
    List<int>? tvqgScores,
  }) async {
    final event = VoiceEvent.voiceTraining(
      rbhScore: rbhScore,
      tvqgScores: tvqgScores,
    );
    await VoiceTrainingService().saveEvent(event);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('评估结果已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAiEncouragement(BuildContext context) async {
    final settings = ApiSettingsService();
    await settings.load();
    if (!settings.isConfigured) {
      if (!context.mounted) return;
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('API 未配置'),
                content: const Text(
                    '请先在"API 配置"中填写 OpenAI 兼容 API 的 endpoint 和 key。\n\n支持任何兼容 OpenAI Chat Completions 格式的 API。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ApiSettingsScreen()));
                      },
                      child: const Text('去配置')),
                ],
              ));
      return;
    }
    if (!context.mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在生成鼓励消息...')
                    ])))));
    final aiService = AiEncouragementService();
    await aiService.init(
        endpoint: settings.endpoint!,
        apiKey: settings.apiKey!,
        model: settings.model);
    final message = await aiService.getEncouragement(
        context: {'averageF0': '--', 'testType': '嗓音训练', 'notes': '完成了嗓音训练评估'});
    if (context.mounted) {
      Navigator.pop(context);
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Row(children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF)),
                  SizedBox(width: 8),
                  Text('AI 鼓励')
                ]),
                content: Text(message,
                    style: const TextStyle(fontSize: 15, height: 1.5)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'))
                ],
              ));
    }
  }

  void _showCloudServices(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFAEAEB2) : const Color(0xFF757575);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('云端服务'),
              content: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    const Text(
                        '以下功能需要部署云端后端服务（AWS Lambda + API Gateway + S3）才能使用：',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    _cloudTile('🎤 在线嗓音分析',
                        '对应 vfs-tracker 的 online-praat-analysis Lambda。\n上传录音计算 F0/Jitter/Shimmer/HNR 等指标。'),
                    const SizedBox(height: 12),
                    _cloudTile('📁 文件上传', '对应 vfs-tracker 的 S3 预签名 URL 上传流程。'),
                    const SizedBox(height: 12),
                    _cloudTile('📄 PDF 报告', '生成包含图表和指标的嗓音分析 PDF 报告。'),
                    const SizedBox(height: 16),
                    Text('部署参考: github.com/Ethanlita/vfs-tracker',
                        style: TextStyle(fontSize: 11, color: secondaryText)),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'))
              ],
            ));
  }

  Widget _cloudTile(String title, String description) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 4),
      Text(description, style: const TextStyle(fontSize: 12, height: 1.4)),
    ]);
  }
}
