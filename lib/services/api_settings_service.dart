import 'package:shared_preferences/shared_preferences.dart';

/// API 设置存储服务
///
/// 存储 OpenAI 兼容 API 的 endpoint 和 key
/// 用于 AI 鼓励消息等功能
class ApiSettingsService {
  static const String _keyEndpoint = 'ai_api_endpoint';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyModel = 'ai_api_model';

  static final ApiSettingsService _instance = ApiSettingsService._internal();
  factory ApiSettingsService() => _instance;
  ApiSettingsService._internal();

  String? _endpoint;
  String? _apiKey;
  String _model = 'gpt-4o-mini';

  /// OpenAI 兼容 API 端点
  String? get endpoint => _endpoint;

  /// API Key
  String? get apiKey => _apiKey;

  /// 模型名称
  String get model => _model;

  /// 是否已配置 API
  bool get isConfigured =>
      _endpoint != null &&
      _endpoint!.isNotEmpty &&
      _apiKey != null &&
      _apiKey!.isNotEmpty;

  /// 加载设置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _endpoint = prefs.getString(_keyEndpoint);
    _apiKey = prefs.getString(_keyApiKey);
    _model = prefs.getString(_keyModel) ?? 'gpt-4o-mini';
  }

  /// 保存设置
  Future<void> save({
    required String endpoint,
    required String apiKey,
    String model = 'gpt-4o-mini',
  }) async {
    _endpoint = endpoint;
    _apiKey = apiKey;
    _model = model;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndpoint, endpoint);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyModel, model);
  }

  /// 清除设置
  Future<void> clear() async {
    _endpoint = null;
    _apiKey = null;
    _model = 'gpt-4o-mini';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEndpoint);
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyModel);
  }
}
