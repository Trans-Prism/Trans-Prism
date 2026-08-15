import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/tracker_port_config.dart';
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

  /// 本次进程内已确定的端口（static：App 进程存活期间固定）。
  /// 端口配置（智能/自定义）变更在**重启应用后**才生效——即使 TrackerScreen
  /// 销毁重建，进程内也继续复用本端口，避免中途换 origin 导致数据"消失"。
  static int? _sessionPort;

  /// 端口由 TrackerPortConfig 统一管理（智能/自定义），确保 WebView origin
  /// 跨启动尽量不变，localStorage 持续可用。
  Future<String> ensureStarted() async {
    if (_started && _server != null) {
      return 'http://${_server!.address.host}:${_server!.port}';
    }

    // 进程内已有固定端口 → 直接复用（配置变更仅重启后生效）
    final sessionPort = _sessionPort;
    int port;
    if (sessionPort != null) {
      port = sessionPort;
    } else {
      // 首次启动：读取端口配置（智能/自定义，见 TrackerPortConfig）
      final mode = await TrackerPortConfig.readMode();
      final lastBound = await TrackerPortConfig.readBoundPort();

      if (mode == TrackerPortConfig.modeCustom) {
        // 自定义模式：直接使用用户指定端口；被占/非法则回退智能顺延保证可用
        final custom = await TrackerPortConfig.readCustomPort();
        if (TrackerPortConfig.isValidCustomPort(custom) &&
            await TrackerPortConfig.canBindPort(custom)) {
          port = custom;
        } else {
          port = await TrackerPortConfig.findSmartPort(preferred: lastBound);
        }
      } else {
        // 智能模式：优先复用上次端口，其次基准 53140 起顺延（53140~53159），
        // 全部被占则由 bind(0) 绑定随机端口
        port = await TrackerPortConfig.findSmartPort(preferred: lastBound);
      }
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _started = true;
    _sessionPort = _server!.port;

    // 持久化实际绑定端口，后续启动复用（保持 origin 稳定）
    await TrackerPortConfig.saveBoundPort(_server!.port);

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
        ..setBackgroundColor(Colors.white);

      ctrl.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
            _injectSpacingFix(ctrl);
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

  /// 修复 SPA 顶部空白。只针对 body/root 级容器精准操作，不破坏内部布局。
  Future<void> _injectSpacingFix(WebViewController controller) async {
    const script = '''
(function() {
  function fix() {
    var root = document.getElementById("root")
             || document.getElementById("app")
             || document.body;

    // 1) Reset body and root: remove padding-top, margin-top, min-height
    [document.body, root].forEach(function(el) {
      if (!el) return;
      el.style.setProperty("padding-top", "0", "important");
      el.style.setProperty("margin-top", "0", "important");
      el.style.setProperty("min-height", "0", "important");
    });

    // 2) Reset first 3 levels of children: padding-top + margin-top only
    function fixTopLevels(el, depth) {
      if (!el || depth > 3) return;
      el.style.setProperty("padding-top", "0", "important");
      el.style.setProperty("margin-top", "0", "important");
      var ch = el.children;
      for (var i = 0; ch && i < ch.length; i++) fixTopLevels(ch[i], depth + 1);
    }
    fixTopLevels(root, 0);
  }

  fix();
  var obs = new MutationObserver(function() { fix(); });
  obs.observe(document.body, {childList: true, subtree: true, attributes: true, attributeFilter: ["style", "class"]});
  [500, 1500, 3000].forEach(function(ms) { setTimeout(fix, ms); });
})();
''';
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint("[TrackerWebView] spacing fix error: $e");
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
