import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_settings_service.dart';
import '../../services/backend_config_service.dart';

/// AI API 配置页面
///
/// 允许用户配置 OpenAI 兼容 API 的 endpoint 和 key。
class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final ApiSettingsService _settings = ApiSettingsService();
  final BackendConfigService _backend = BackendConfigService();
  final _endpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController(text: 'gpt-4o-mini');
  final _beEndpointController = TextEditingController();
  final _beRegionController = TextEditingController();
  final _beUserPoolController = TextEditingController();
  final _beClientIdController = TextEditingController();
  final _beS3Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.load();
    await _backend.load();
    _endpointController.text = _settings.endpoint ?? '';
    _apiKeyController.text = _settings.apiKey ?? '';
    _modelController.text = _settings.model;
    _beEndpointController.text = _backend.endpoint ?? '';
    _beRegionController.text = _backend.region ?? '';
    _beUserPoolController.text = _backend.userPoolId ?? '';
    _beClientIdController.text = _backend.clientId ?? '';
    _beS3Controller.text = _backend.s3Bucket ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 保存 AI 配置
    await _settings.save(
      endpoint: _endpointController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? 'gpt-4o-mini'
          : _modelController.text.trim(),
    );

    // 保存 AWS 后端配置
    final beEp = _beEndpointController.text.trim();
    if (beEp.isNotEmpty) {
      await _backend.save(
        endpoint: beEp,
        region: _beRegionController.text.trim(),
        userPoolId: _beUserPoolController.text.trim(),
        clientId: _beClientIdController.text.trim(),
        s3Bucket: _beS3Controller.text.trim(),
      );
    } else {
      await _backend.disable();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _testConnection() async {
    final endpoint = _endpointController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (endpoint.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写 endpoint 和 API Key'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在测试连接...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final chatEndpoint = endpoint.endsWith('/chat/completions')
          ? endpoint
          : '${endpoint.replaceAll(RegExp(r'/*$'), '')}/chat/completions';

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _modelController.text.trim().isEmpty
                  ? 'gpt-4o-mini'
                  : _modelController.text.trim(),
              'messages': [
                {'role': 'user', 'content': 'Hello'}
              ],
              'max_tokens': 5,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 连接成功！API 配置可用'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 连接失败 (${response.statusCode}): ${response.body}'),
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 连接错误: $e'),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('API 配置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 配置'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 鼓励消息配置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '配置 OpenAI 兼容 API 后可获得 AI 生成的个性化嗓音训练鼓励消息。'
                    '支持任何兼容 OpenAI Chat Completions 格式的 API（如 OpenAI、'
                    'Azure OpenAI、Together AI、vLLM 等）。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1565C0),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _endpointController,
              decoration: InputDecoration(
                labelText: 'API Endpoint',
                hintText: 'https://api.openai.com/v1',
                helperText: 'OpenAI 兼容 API 地址',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v != null && v.isNotEmpty && !v.startsWith('http')) {
                  return '请输入有效的 URL（以 http 开头）';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 8) {
                  return 'API Key 格式不正确';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: '模型名称',
                hintText: 'gpt-4o-mini',
                helperText: '默认为 gpt-4o-mini',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.memory),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.cloud, size: 18, color: Color(0xFFF57C00)),
                    SizedBox(width: 8),
                    Text('AWS 后端配置（可选）',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100))),
                  ]),
                  SizedBox(height: 8),
                  Text('配置后端后，嗓音测试向导等将优先使用云端 API 进行专业声学分析。\n不配置则使用本地分析模式。',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFBF360C), height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _beEndpointController,
              decoration: InputDecoration(
                labelText: 'API Endpoint',
                hintText: 'https://api.your-domain.com',
                helperText: '后端 API 地址（不含 /chat/completions）',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.dns),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _beRegionController,
              decoration: InputDecoration(
                labelText: 'AWS Region（可选）',
                hintText: 'us-east-1',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextFormField(
                controller: _beUserPoolController,
                decoration: InputDecoration(
                  labelText: 'User Pool ID（可选）',
                  hintText: 'us-east-1_xxxxx',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                controller: _beClientIdController,
                decoration: InputDecoration(
                  labelText: 'Client ID（可选）',
                  hintText: 'xxxxxxxxxx',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _beS3Controller,
              decoration: InputDecoration(
                labelText: 'S3 Bucket（可选）',
                hintText: 'your-bucket',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.storage),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('测试 AI 连接'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final beEp = _beEndpointController.text.trim();
                  if (beEp.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('请先填写后端 API Endpoint'),
                          behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()));
                  await _backend.save(
                      endpoint: beEp, region: _beRegionController.text.trim());
                  final ok = await _backend.testConnection();
                  if (context.mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '✅ 后端连接成功' : '❌ 后端连接失败，请检查地址和部署状态'),
                      backgroundColor: ok
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.cloud),
                label: const Text('测试后端连接'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
