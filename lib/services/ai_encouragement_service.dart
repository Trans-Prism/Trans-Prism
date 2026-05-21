import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI 鼓励消息服务
///
/// 使用 OpenAI 兼容 API 格式生成嗓音训练鼓励消息。
/// 需用户自行配置 API endpoint 和 key。
///
/// API 格式：POST {endpoint}/chat/completions
/// 请求体：{"model": "...", "messages": [...], "temperature": 0.7}
/// 响应体：{"choices": [{"message": {"content": "..."}}]}
class AiEncouragementService {
  static const String _cacheKey = 'ai_encouragement_cache';

  static final AiEncouragementService _instance =
      AiEncouragementService._internal();
  factory AiEncouragementService() => _instance;
  AiEncouragementService._internal();

  String? _endpoint;
  String? _apiKey;
  String _model = 'gpt-4o-mini';

  /// 初始化
  Future<void> init({
    required String endpoint,
    required String apiKey,
    String model = 'gpt-4o-mini',
  }) async {
    _endpoint = endpoint.endsWith('/chat/completions')
        ? endpoint
        : '${endpoint.replaceAll(RegExp(r'/*$'), '')}/chat/completions';
    _apiKey = apiKey;
    _model = model;
  }

  bool get isConfigured =>
      _endpoint != null && _endpoint!.isNotEmpty && _apiKey != null;

  /// 获取嗓音训练鼓励消息
  ///
  /// [context] 训练上下文信息，如平均 F0、RBH 评分等
  Future<String> getEncouragement({
    required Map<String, dynamic> context,
  }) async {
    if (!isConfigured) {
      return _getFallbackMessage(context);
    }

    try {
      final systemPrompt = _buildSystemPrompt();
      final userMessage = _buildUserMessage(context);

      final response = await http
          .post(
            Uri.parse(_endpoint!),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userMessage},
              ],
              'temperature': 0.8,
              'max_tokens': 300,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return content.trim();
          }
        }
      }
      return _getFallbackMessage(context);
    } catch (e) {
      return _getFallbackMessage(context);
    }
  }

  String _buildSystemPrompt() {
    return '你是一位专业且温暖的跨性别嗓音训练教练。'
        '你的任务是：\n'
        '1. 根据用户提供的嗓音训练数据，给出鼓励和支持\n'
        '2. 提供专业但亲切的嗓音训练建议\n'
        '3. 回复控制在100字以内\n'
        '4. 使用温暖、积极的语气\n'
        '5. 可以提及具体的数据（如平均基频），但要保持人性化';
  }

  String _buildUserMessage(Map<String, dynamic> context) {
    final parts = <String>['我刚刚完成了嗓音训练，以下是我的训练数据：'];

    if (context['averageF0'] != null) {
      parts.add('- 平均基频 (F0): ${context['averageF0']} Hz');
    }
    if (context['minF0'] != null) {
      parts.add('- 最低基频: ${context['minF0']} Hz');
    }
    if (context['maxF0'] != null) {
      parts.add('- 最高基频: ${context['maxF0']} Hz');
    }
    if (context['testType'] != null) {
      parts.add('- 测试类型: ${context['testType']}');
    }
    if (context['notes'] != null) {
      parts.add('- 备注: ${context['notes']}');
    }

    parts.add('\n请给我一些鼓励和训练建议。');
    return parts.join('\n');
  }

  /// 离线备用鼓励消息
  String _getFallbackMessage(Map<String, dynamic> context) {
    final f0 = context['averageF0'];
    final messages = _defaultMessages;

    if (f0 != null) {
      final f0Num = (f0 as num).toDouble();
      if (f0Num >= 180) {
        return '🎉 太棒了！您的平均基频达到 ${f0Num.toStringAsFixed(0)} Hz，'
            '这在女性化嗓音的目标范围内（180-250 Hz）。继续保持，'
            '注意气息支撑和共鸣的配合。每一次练习都在让您的声音更接近目标！';
      } else if (f0Num >= 160) {
        return '💪 做得好！平均基频 ${f0Num.toStringAsFixed(0)} Hz，'
            '已经接近女性化范围了。建议多练习音高控制，'
            '尝试在说话时保持这个音高，让它成为习惯。加油！';
      } else {
        return '🌟 坚持练习就是进步！当前平均基频 ${f0Num.toStringAsFixed(0)} Hz。'
            '每天坚持15分钟的音高练习，慢慢提升。'
            '嗓音训练是一个过程，您已经在路上了！';
      }
    }

    return messages[DateTime.now().millisecondsSinceEpoch % messages.length];
  }

  static const List<String> _defaultMessages = [
    '🌟 每一次练习都是对自己的关爱。嗓音训练需要耐心，您已经在变好的路上了！',
    '💪 坚持就是胜利！今天的声音比昨天更接近您想要的样子。继续加油！',
    '🎵 嗓音就像乐器，需要不断调音和练习。您的努力一定会有回报！',
    '🌸 请记住，您的价值不在于声音如何，而在于您是谁。训练是为了让您更自在地做自己！',
    '✨ 每一步进步都值得庆祝。今天您为自己的声音付出了努力，这本身就是一种勇气！',
  ];
}
