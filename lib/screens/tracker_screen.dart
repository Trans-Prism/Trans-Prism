import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../utils/data_migration_service.dart';

// ========================
// MIME 类型映射
// ========================
const _mimeTypes = <String, String>{
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.map': 'application/json',
};

String _mimeFor(String path) {
  final ext =
      path.lastIndexOf('.') >= 0 ? path.substring(path.lastIndexOf('.')) : '';
  return _mimeTypes[ext] ?? 'application/octet-stream';
}

// ========================
// 动态静态资源服务器 (解决 Vite SPA CORS 限制)
// ========================
class _LocalTrackerServer {
  HttpServer? _server;
  bool _started = false;

  /// 固定端口，确保 WebView origin 跨启动不变，localStorage 持续可用。
  /// 若被占用则自动回退到随机端口，并将实际端口持久化到 SharedPreferences。
  static const int _preferredPort = 53140;
  static const String _prefsPortKey = '_tracker_server_port';

  Future<String> ensureStarted() async {
    if (_started && _server != null) {
      return 'http://${_server!.address.host}:${_server!.port}';
    }

    // 优先使用持久化的端口（跨启动复用），其次尝试固定端口，最后回退到随机
    final prefs = await SharedPreferences.getInstance();
    int port = prefs.getInt(_prefsPortKey) ?? 0;

    if (port == 0) {
      // 无持久化记录：尝试固定端口
      try {
        final probe =
            await HttpServer.bind(InternetAddress.loopbackIPv4, _preferredPort);
        await probe.close();
        port = _preferredPort;
      } catch (_) {
        // 固定端口被占用（如 TIME_WAIT），使用随机端口
        port = 0;
      }
    } else {
      // 有持久化记录：尝试复用旧端口
      try {
        final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
        await probe.close();
      } catch (_) {
        // 旧端口不可用 → 尝试固定端口 → 最后随机
        port = 0;
        try {
          final probe = await HttpServer.bind(
              InternetAddress.loopbackIPv4, _preferredPort);
          await probe.close();
          port = _preferredPort;
        } catch (_) {
          port = 0;
        }
      }
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _started = true;

    // 持久化实际绑定的端口，后续启动复用
    await prefs.setInt(_prefsPortKey, _server!.port);

    _server!.listen(_handleRequest, onError: (err) {
      debugPrint('[TrackerServer] error: $err');
    });

    debugPrint(
        '[TrackerServer] listening on http://${_server!.address.host}:${_server!.port}');
    return 'http://${_server!.address.host}:${_server!.port}';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    String requestPath = request.uri.path;
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }
    if (requestPath.isEmpty || requestPath == '/') {
      requestPath = 'index.html';
    }

    final docDir = await getApplicationDocumentsDirectory();
    final sandboxedFile = File('${docDir.path}/hrt_tracker/$requestPath');

    // 1. 优先尝试从沙盒 (热更新目录) 读取
    if (await sandboxedFile.exists()) {
      try {
        final bytes = await sandboxedFile.readAsBytes();
        _sendBytes(request, bytes, requestPath);
        return;
      } catch (e) {
        debugPrint('[TrackerServer] Error reading sandboxed file: $e');
      }
    }

    // 2. 沙盒无文件，则从内置的 Assets 兜底读取
    try {
      final assetPath = 'assets/hrt_tracker/$requestPath';
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      _sendBytes(request, bytes, requestPath);
    } catch (e) {
      // SPA 路由容错：如果找不到，回退到 index.html
      if (requestPath != 'index.html') {
        try {
          final sandboxedIndex = File('${docDir.path}/hrt_tracker/index.html');
          if (await sandboxedIndex.exists()) {
            final bytes = await sandboxedIndex.readAsBytes();
            _sendBytes(request, bytes, 'index.html');
            return;
          }
          final byteData =
              await rootBundle.load('assets/hrt_tracker/index.html');
          final bytes = byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
          _sendBytes(request, bytes, 'index.html');
          return;
        } catch (_) {}
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  void _sendBytes(HttpRequest request, List<int> bytes, String path) {
    try {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.parse(_mimeFor(path))
        ..headers.set('Cache-Control', 'no-cache') // 确保热更新实时生效，不使用缓存
        ..add(bytes);
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
    }
    request.response.close();
  }

  Future<void> stop() async {
    _started = false;
    await _server?.close(force: true);
    _server = null;
    debugPrint('[TrackerServer] stopped');
  }
}

// 共享的单例服务器
_LocalTrackerServer? _sharedServer;
Future<_LocalTrackerServer> _getSharedServer() async {
  _sharedServer ??= _LocalTrackerServer();
  return _sharedServer!;
}

// ========================
// WebView 挂载界面
// ========================
class TrackerScreen extends StatefulWidget {
  final String genderIdentity;
  const TrackerScreen({super.key, required this.genderIdentity});

  /// 在后台静默初始化 Oyama SPA（无需显示 WebView）。
  /// 供导出/导入功能调用，确保通过 JavaScript 访问 SPA 数据时 WebView 控制器已就绪。
  static Future<void> ensureBackgroundInitialized() async {
    if (DataMigrationService.hasOyamaController) return;

    try {
      final server = await _getSharedServer();
      final baseUrl = await server.ensureStarted();

      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent);

      if (ctrl.platform is AndroidWebViewController) {
        await (ctrl.platform as AndroidWebViewController)
            .setAllowFileAccess(true);
      }

      final pageLoaded = Completer<void>();
      ctrl.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!pageLoaded.isCompleted) pageLoaded.complete();
          },
        ),
      );

      await ctrl.loadRequest(Uri.parse('$baseUrl/index.html'));

      await pageLoaded.future.timeout(const Duration(seconds: 15));
      DataMigrationService.registerOyamaController(ctrl);
    } catch (e) {
      debugPrint('[TrackerScreen] background init error: $e');
    }
  }

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  // ── 开源许可证声明 ──
  bool _licenseVisible = true;
  bool _licenseInitialised = false;
  static const _licensePrefsKey = 'pk_oyama_license_dismissed';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _loadLicensePrefs();
  }

  Future<void> _loadLicensePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_licensePrefsKey) ?? false;
    if (!mounted) return;
    setState(() {
      _licenseVisible = !dismissed;
      _licenseInitialised = true;
    });
  }

  Future<void> _dismissLicensePermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_licensePrefsKey, true);
    if (!mounted) return;
    setState(() => _licenseVisible = false);
  }

  void _showLicenseDismissDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭开源声明'),
        content: const Text('您可以选择仅本次关闭（下次进入仍会显示）或以后都不显示。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _licenseVisible = false);
            },
            child: const Text('仅本次关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dismissLicensePermanently();
            },
            child: const Text('不再显示'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WebView handles its own lifecycle via the platform plugin.
  }

  Future<void> _init() async {
    try {
      final server = await _getSharedServer();
      final baseUrl = await server.ensureStarted();

      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (url) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (err) {
              debugPrint('[TrackerWebView] error: ${err.description}');
              if (mounted && _loading) {
                setState(() => _error = '加载失败: ${err.description}');
              }
            },
          ),
        );

      if (ctrl.platform is AndroidWebViewController) {
        await (ctrl.platform as AndroidWebViewController)
            .setAllowFileAccess(true);
      }

      await ctrl.loadRequest(Uri.parse('$baseUrl/index.html'));

      // 注册 Oyama WebView 控制器到数据迁移服务，
      // 以便导出时能同步 SPA 内的 localStorage 数据
      DataMigrationService.registerOyamaController(ctrl);

      if (!mounted) return;
      setState(() {
        _controller = ctrl;
      });
    } catch (e) {
      debugPrint('[TrackerWebView] init error: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _loading = true;
      _controller = null;
    });
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('血药浓度模拟'),
        backgroundColor: const Color(0xFFF5F4F0),
        actions: [
          if (_loading && _error == null)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_licenseInitialised && _licenseVisible)
            Container(
              color: const Color(0xFFF5F4F0),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: _buildLicenseNotice(),
            ),
        ],
      ),
    );
  }

  Widget _buildLicenseNotice() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      elevation: 0,
      color: const Color(0xFFF5F4F0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8E6E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '开源许可证声明',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 15),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '关闭声明',
                  onPressed: _showLicenseDismissDialog,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '血药浓度模拟内嵌以下开源项目，均以 MIT License 许可：',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _buildLinkRow(
              'Oyama\'s HRT Tracker',
              'https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker',
            ),
            const SizedBox(height: 2),
            _buildLinkRow(
              'HRT-Recorder-PKcomponent-Test',
              'https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkRow(String title, String url) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(url, style: const TextStyle(fontSize: 12)),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 12, color: Colors.blue),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.blue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}
