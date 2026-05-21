/// DNS 安全网络请求相关异常
class DnsSafeNetworkException implements Exception {
  final String message;
  final String? host;
  final String? uri;
  final Object? cause;

  const DnsSafeNetworkException(
    this.message, {
    this.host,
    this.uri,
    this.cause,
  });

  @override
  String toString() {
    final buffer = StringBuffer('DnsSafeNetworkException: $message');
    if (host != null) buffer.write(' (host: $host)');
    if (uri != null) buffer.write(' (uri: $uri)');
    if (cause != null) buffer.write(' [cause: $cause]');
    return buffer.toString();
  }
}
