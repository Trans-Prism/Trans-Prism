import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'dns_safe_network_exception.dart';

/// 抗 DNS 污染的网络请求服务
///
/// 流程：DoH 解析真实 IP（含 CNAME 追踪）→ 逐个 IP 直连 → 失败则标准 DNS 直连兜底
class DnsSafeNetworkService {
  static const Duration dohTimeout = Duration(seconds: 8);
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int _maxCnameDepth = 6;

  static const String _aliDohBase = 'https://dns.alidns.com/resolve';
  static const String _tencentDohBase = 'https://doh.pub/dns-query';

  final Dio _dohDio;

  DnsSafeNetworkService({Dio? dohDio})
      : _dohDio = dohDio ??
            Dio(
              BaseOptions(
                connectTimeout: dohTimeout,
                receiveTimeout: dohTimeout,
                headers: {'Accept': 'application/dns-json'},
              ),
            );

  /// 通过 DoH 解析并安全获取 URL 响应正文
  Future<String> fetchSafe(String targetUrl) async {
    final uri = _parseTargetUri(targetUrl);
    final host = uri.host;

    final errors = <String>[];

    try {
      final ips = await resolveAllIpv4(host);
      for (final ip in ips) {
        try {
          return await _fetchViaResolvedIp(uri: uri, ip: ip);
        } catch (e) {
          errors.add('IP $ip: $e');
        }
      }
    } catch (e) {
      errors.add('DoH: $e');
    }

    try {
      return await _fetchDirect(uri);
    } catch (e) {
      errors.add('直连: $e');
    }

    throw DnsSafeNetworkException(
      '所有请求方式均失败 (${errors.join(' | ')})',
      host: host,
      uri: uri.toString(),
    );
  }

  /// 解析域名全部 IPv4（依次尝试阿里 / 腾讯 DoH，支持 CNAME 追踪）
  Future<List<String>> resolveAllIpv4(String hostname) async {
    final normalized = hostname.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw DnsSafeNetworkException('域名为空', host: hostname);
    }

    final errors = <String>[];

    try {
      final ips = await _resolveViaAliDns(normalized);
      if (ips.isNotEmpty) return ips;
    } catch (e) {
      errors.add('阿里 DNS: $e');
    }

    try {
      final ips = await _resolveViaTencentDns(normalized);
      if (ips.isNotEmpty) return ips;
    } catch (e) {
      errors.add('腾讯 DNS: $e');
    }

    throw DnsSafeNetworkException(
      '所有 DoH 解析均失败: ${errors.join(' | ')}',
      host: normalized,
    );
  }

  /// 兼容旧 API：返回第一个 IPv4
  Future<String> resolveHost(String hostname) async {
    final ips = await resolveAllIpv4(hostname);
    return ips.first;
  }

  Future<List<String>> _resolveViaAliDns(String hostname, {int depth = 0}) async {
    if (depth > _maxCnameDepth) {
      throw DnsSafeNetworkException('CNAME 链路过深', host: hostname);
    }
    try {
      final response = await _dohDio.get<dynamic>(
        _aliDohBase,
        queryParameters: {'name': hostname, 'type': 1},
        options: Options(responseType: ResponseType.json),
      );
      return _collectIpv4FromDoh(
        _asJsonMap(response.data),
        hostname: hostname,
        provider: '阿里 DNS',
        depth: depth,
        resolver: _resolveViaAliDns,
      );
    } on DioException catch (e) {
      throw DnsSafeNetworkException(
        '阿里 DNS 请求失败: ${_dioErrorMessage(e)}',
        host: hostname,
        cause: e,
      );
    }
  }

  Future<List<String>> _resolveViaTencentDns(String hostname, {int depth = 0}) async {
    if (depth > _maxCnameDepth) {
      throw DnsSafeNetworkException('CNAME 链路过深', host: hostname);
    }
    try {
      final response = await _dohDio.get<dynamic>(
        _tencentDohBase,
        queryParameters: {'name': hostname, 'type': 'A'},
        options: Options(
          responseType: ResponseType.json,
          headers: {'Accept': 'application/dns-json'},
        ),
      );
      return _collectIpv4FromDoh(
        _asJsonMap(response.data),
        hostname: hostname,
        provider: '腾讯 DNS',
        depth: depth,
        resolver: _resolveViaTencentDns,
      );
    } on DioException catch (e) {
      throw DnsSafeNetworkException(
        '腾讯 DNS 请求失败: ${_dioErrorMessage(e)}',
        host: hostname,
        cause: e,
      );
    }
  }

  Future<List<String>> _collectIpv4FromDoh(
    Map<String, dynamic>? json, {
    required String hostname,
    required String provider,
    required int depth,
    required Future<List<String>> Function(String host, {int depth}) resolver,
  }) async {
    if (json == null) {
      throw DnsSafeNetworkException('$provider 返回空响应', host: hostname);
    }

    final status = json['Status'];
    if (status != 0 && status != '0') {
      throw DnsSafeNetworkException(
        '$provider 查询失败 (Status=$status)',
        host: hostname,
      );
    }

    final ips = <String>{};
    final cnames = <String>{};

    for (final section in ['Answer', 'Additional']) {
      final records = json[section];
      if (records is! List) continue;
      for (final entry in records) {
        final record = _asJsonMap(entry);
        if (record == null) continue;

        if (_isARecord(record['type'])) {
          final data = record['data'];
          if (data is String && _isIpv4(data)) {
            ips.add(data);
          }
        } else if (_isCnameRecord(record['type'])) {
          final data = record['data'];
          if (data is String && data.isNotEmpty) {
            cnames.add(_normalizeHostname(data));
          }
        }
      }
    }

    if (ips.isNotEmpty) return ips.toList();

    for (final cname in cnames) {
      if (cname == hostname) continue;
      final nested = await resolver(cname, depth: depth + 1);
      ips.addAll(nested);
      if (ips.isNotEmpty) return ips.toList();
    }

    throw DnsSafeNetworkException('$provider 未找到有效 A 记录', host: hostname);
  }

  Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }

  String _normalizeHostname(String name) {
    final trimmed = name.trim().toLowerCase();
    return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  bool _isARecord(dynamic type) {
    if (type == 1 || type == '1') return true;
    if (type is String && type.toUpperCase() == 'A') return true;
    return false;
  }

  bool _isCnameRecord(dynamic type) {
    if (type == 5 || type == '5') return true;
    if (type is String && type.toUpperCase() == 'CNAME') return true;
    return false;
  }

  bool _isIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// 标准 DNS 直连（作为 CDN / 多 IP 场景的兜底）
  Future<String> _fetchDirect(Uri uri) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.plain,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
        headers: {
          HttpHeaders.userAgentHeader: 'TransToolbox/1.0',
          HttpHeaders.acceptHeader: 'text/plain, text/markdown, application/json, */*',
        },
      ),
    );

    try {
      final response = await dio.getUri(uri);
      return _extractBody(response, uri);
    } on DioException catch (e) {
      throw DnsSafeNetworkException(
        _dioErrorMessage(e),
        host: uri.host,
        uri: uri.toString(),
        cause: e,
      );
    } finally {
      dio.close();
    }
  }

  Future<String> _fetchViaResolvedIp({
    required Uri uri,
    required String ip,
  }) async {
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

    final fetchDio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.plain,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
        headers: {
          HttpHeaders.userAgentHeader: 'TransToolbox/1.0',
          HttpHeaders.acceptHeader: 'text/plain, text/markdown, application/json, */*',
        },
      ),
    );

    fetchDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = true;
        client.connectionFactory = (Uri requestUri, String? proxyHost, int? proxyPort) {
          return Socket.startConnect(ip, port);
        };
        return client;
      },
    );

    try {
      final response = await fetchDio.getUri(
        uri,
        options: Options(
          headers: {HttpHeaders.hostHeader: host},
          responseType: ResponseType.plain,
        ),
      );
      return _extractBody(response, uri);
    } on DioException catch (e) {
      throw DnsSafeNetworkException(
        _dioErrorMessage(e),
        host: host,
        uri: uri.toString(),
        cause: e,
      );
    } on SocketException catch (e) {
      throw DnsSafeNetworkException(
        'Socket 连接失败: ${e.message}',
        host: host,
        uri: uri.toString(),
        cause: e,
      );
    } on HandshakeException catch (e) {
      throw DnsSafeNetworkException(
        'TLS 握手失败: ${e.message}',
        host: host,
        uri: uri.toString(),
        cause: e,
      );
    } catch (e) {
      throw DnsSafeNetworkException(
        '请求异常: $e',
        host: host,
        uri: uri.toString(),
        cause: e,
      );
    } finally {
      fetchDio.close();
    }
  }

  String _extractBody(Response<dynamic> response, Uri uri) {
    final body = response.data;
    final text = body is String ? body : body?.toString();
    if (text == null || text.trim().isEmpty) {
      throw DnsSafeNetworkException(
        '响应正文为空 (HTTP ${response.statusCode})',
        host: uri.host,
        uri: uri.toString(),
      );
    }
    return text;
  }

  Uri _parseTargetUri(String targetUrl) {
    final trimmed = targetUrl.trim();
    if (trimmed.isEmpty) {
      throw const DnsSafeNetworkException('URL 不能为空');
    }

    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e) {
      throw DnsSafeNetworkException('URL 解析失败', uri: trimmed, cause: e);
    }

    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw DnsSafeNetworkException('仅支持 http / https 协议', uri: trimmed);
    }

    if (uri.host.isEmpty) {
      throw DnsSafeNetworkException('URL 缺少有效域名', uri: trimmed);
    }

    return uri;
  }

  String _dioErrorMessage(DioException e) {
    final detail = e.error?.toString() ?? e.message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时${detail != null ? ': $detail' : ''}';
      case DioExceptionType.sendTimeout:
        return '发送超时${detail != null ? ': $detail' : ''}';
      case DioExceptionType.receiveTimeout:
        return '接收超时${detail != null ? ': $detail' : ''}';
      case DioExceptionType.connectionError:
        return '连接错误: $detail';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode ?? "未知"}';
      case DioExceptionType.badCertificate:
        return '证书校验失败: $detail';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.unknown:
        return detail ?? '未知网络错误';
      default:
        return detail ?? '网络错误 (${e.type})';
    }
  }
}
