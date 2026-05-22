// ============================================================
// Embedded Oyama's HRT Tracker via local HTTP server + WebView
// https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker
//
// The React SPA built output (dist/) is bundled as Flutter assets.
// At runtime, assets are copied to a temp directory and served
// via a lightweight dart:io HttpServer on 127.0.0.1.
// The WebView loads the local URL for full in-app PK simulation.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Maps file extensions to MIME types for the static file server.
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
// 本地静态资源服务器
// ========================

class _LocalAssetServer {
  HttpServer? _server;
  String? _baseDir;
  bool _started = false;

  /// Ensure assets are copied and the server is bound.
  /// Returns the full URL like `http://127.0.0.1:PORT`.
  Future<String> ensureStarted() async {
    if (_started && _server != null && _baseDir != null) {
      return 'http://${_server!.address.host}:${_server!.port}';
    }

    final tempDir = await getApplicationDocumentsDirectory();
    _baseDir = '${tempDir.path}/oyama_hrt';

    // Copy assets from bundle to filesystem (one-time)
    final indexFile = File('$_baseDir/index.html');
    if (!await indexFile.exists()) {
      await _copyAssets();
    }

    // Bind to random available port on loopback
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _started = true;

    _server!.listen(_handleRequest, onError: (err) {
      debugPrint('[OyamaServer] error: $err');
    });

    debugPrint(
        '[OyamaServer] listening on http://${_server!.address.host}:${_server!.port}');
    return 'http://${_server!.address.host}:${_server!.port}';
  }

  Future<void> _copyAssets() async {
    final dir = Directory(_baseDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Read AssetManifest.json to discover all bundled files
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;

    const prefix = 'assets/oyama_hrt/';
    final tasks = <Future>[];

    for (final entry in manifest.entries) {
      final assetPath = entry.key;
      if (!assetPath.startsWith(prefix)) continue;

      final relativePath = assetPath.substring(prefix.length);
      if (relativePath.isEmpty) continue;

      final targetFile = File('$_baseDir/$relativePath');

      // Create parent directories if needed
      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Only copy if not already present
      if (!await targetFile.exists()) {
        tasks.add(
          rootBundle.load(assetPath).then((data) async {
            await targetFile.writeAsBytes(data.buffer.asUint8List());
          }),
        );
      }
    }

    await Future.wait(tasks);
    debugPrint('[OyamaServer] copied ${tasks.length} asset files to $_baseDir');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Decode the path; default SPA fallback → index.html
    String requestPath = request.uri.path;

    // Normalise: strip leading slash, treat root/empty as index.html
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }
    if (requestPath.isEmpty || requestPath == '/') {
      requestPath = 'index.html';
    }

    final file = File('$_baseDir/$requestPath');

    // SPA fallback: if file not found, serve index.html
    if (!await file.exists()) {
      final indexFile = File('$_baseDir/index.html');
      if (await indexFile.exists()) {
        final bytes = await indexFile.readAsBytes();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.parse(_mimeFor('index.html'))
          ..add(bytes);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.parse(_mimeFor(requestPath))
        ..headers.set('Cache-Control', 'max-age=3600')
        ..add(bytes);
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
    }
    await request.response.close();
  }

  Future<void> stop() async {
    _started = false;
    await _server?.close(force: true);
    _server = null;
    debugPrint('[OyamaServer] stopped');
  }
}

// ========================
// 共享的单例服务器（多个页面访问同一服务器）
// ========================

_LocalAssetServer? _sharedServer;
Future<_LocalAssetServer> _getSharedServer() async {
  _sharedServer ??= _LocalAssetServer();
  return _sharedServer!;
}

// ========================
// PK Simulation Screen
// ========================

class PKSimulationScreen extends StatefulWidget {
  final String genderIdentity;
  const PKSimulationScreen({super.key, required this.genderIdentity});

  @override
  State<PKSimulationScreen> createState() => _PKSimulationScreenState();
}

class _PKSimulationScreenState extends State<PKSimulationScreen>
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
    // NOTE: we intentionally keep the shared server alive
    // so that returning to this screen is instant.
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
              debugPrint('[OyamaWebView] error: ${err.description}');
              if (mounted && _loading) {
                setState(() => _error = '加载失败: ${err.description}');
              }
            },
          ),
        );

      await ctrl.loadRequest(Uri.parse('$baseUrl/index.html'));

      if (!mounted) return;
      setState(() {
        _controller = ctrl;
      });
    } catch (e) {
      debugPrint('[OyamaWebView] init error: $e');
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
    final isTransfem = widget.genderIdentity != 'ftm';
    final clr = isTransfem ? const Color(0xFFF5A9B8) : const Color(0xFF5BCEFA);

    return Scaffold(
      appBar: AppBar(
        title: const Text('血药浓度模拟'),
        backgroundColor: clr.withOpacity(0.1),
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
          if (_licenseInitialised && _licenseVisible) _buildLicenseNotice(),
        ],
      ),
    );
  }

  Widget _buildLicenseNotice() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
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
