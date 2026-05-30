import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AWS 后端配置存储服务
///
/// 存储用户在 API 配置页面填写的 AWS 后端信息。
/// 所有功能默认走本地处理，只有配置了后端才尝试云端调用。
class BackendConfigService {
  static const String _keyEndpoint = 'backend_api_endpoint';
  static const String _keyRegion = 'backend_aws_region';
  static const String _keyUserPoolId = 'backend_user_pool_id';
  static const String _keyClientId = 'backend_client_id';
  static const String _keyS3Bucket = 'backend_s3_bucket';
  static const String _keyEnabled = 'backend_enabled';

  static final BackendConfigService _instance =
      BackendConfigService._internal();
  factory BackendConfigService() => _instance;
  BackendConfigService._internal();

  String? _endpoint;
  String? _region;
  String? _userPoolId;
  String? _clientId;
  String? _s3Bucket;
  bool _enabled = false;
  bool? _connectionVerified;

  String? get endpoint => _endpoint;
  String? get region => _region;
  String? get userPoolId => _userPoolId;
  String? get clientId => _clientId;
  String? get s3Bucket => _s3Bucket;
  bool get enabled => _enabled;
  bool get isConfigured =>
      _enabled && _endpoint != null && _endpoint!.isNotEmpty;

  /// 加载配置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _endpoint = prefs.getString(_keyEndpoint);
    _region = prefs.getString(_keyRegion);
    _userPoolId = prefs.getString(_keyUserPoolId);
    _clientId = prefs.getString(_keyClientId);
    _s3Bucket = prefs.getString(_keyS3Bucket);
    _enabled = prefs.getBool(_keyEnabled) ?? false;
  }

  /// 保存配置
  Future<void> save({
    required String endpoint,
    String? region,
    String? userPoolId,
    String? clientId,
    String? s3Bucket,
  }) async {
    _endpoint = endpoint;
    _region = region;
    _userPoolId = userPoolId;
    _clientId = clientId;
    _s3Bucket = s3Bucket;
    _enabled = true;
    _connectionVerified = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndpoint, endpoint);
    if (region != null) await prefs.setString(_keyRegion, region);
    if (userPoolId != null) await prefs.setString(_keyUserPoolId, userPoolId);
    if (clientId != null) await prefs.setString(_keyClientId, clientId);
    if (s3Bucket != null) await prefs.setString(_keyS3Bucket, s3Bucket);
    await prefs.setBool(_keyEnabled, true);
  }

  /// 禁用后端
  Future<void> disable() async {
    _enabled = false;
    _connectionVerified = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
  }

  /// 清除所有配置
  Future<void> clear() async {
    _endpoint = null;
    _region = null;
    _userPoolId = null;
    _clientId = null;
    _s3Bucket = null;
    _enabled = false;
    _connectionVerified = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEndpoint);
    await prefs.remove(_keyRegion);
    await prefs.remove(_keyUserPoolId);
    await prefs.remove(_keyClientId);
    await prefs.remove(_keyS3Bucket);
    await prefs.remove(_keyEnabled);
  }

  /// 测试后端连接
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      final response = await http
          .get(Uri.parse('$_endpoint/health'))
          .timeout(const Duration(seconds: 5));

      _connectionVerified = response.statusCode == 200;
      return _connectionVerified!;
    } catch (_) {
      _connectionVerified = false;
      return false;
    }
  }
}
