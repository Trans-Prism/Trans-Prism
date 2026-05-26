import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

import '../services/wiki_offline_service.dart';
import '../services/wiki_update_manager.dart';

/// 统一的在线/离线双模 Wiki 阅读器
///
/// - 离线模式：启动本地 HTTP Server 提供静态文件 + WebView localhost
/// - 在线模式：WebView 直接加载在线 URL
///
/// 模式选择由 [WikiOfflineService] 的开关状态 + 离线数据是否存在共同决定。
class OfflineWikiScreen extends StatefulWidget {
  /// wiki 类型标识：'mtf' / 'ftm' / 'rle'
  final String wikiType;

  /// AppBar 标题
  final String title;

  /// 在线模式的 URL
  final String onlineUrl;

  /// 本地离线站点子目录名（如 'mtf-wiki-site'）
  final String localSiteDirName;

  /// 本地 index 路径（如 '/zh-cn/docs/index.html'）
  final String localIndexPath;

  const OfflineWikiScreen({
    super.key,
    required this.wikiType,
    required this.title,
    required this.onlineUrl,
    required this.localSiteDirName,
    this.localIndexPath = '/index.html',
  });

  @override
  State<OfflineWikiScreen> createState() => _OfflineWikiScreenState();
}

class _OfflineWikiScreenState extends State<OfflineWikiScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isOfflineMode = false;
  HttpServer? _localServer;
  String? _errorMessage;

  /// 各 wiki 的本地服务器端口
  int get _port {
    switch (widget.wikiType) {
      case 'mtf':
        return 8080;
      case 'ftm':
        return 8081;
      case 'rle':
        return 8082;
      default:
        return 8083;
    }
  }

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    debugPrint('[${widget.wikiType}] _initScreen 开始');
    try {
      // 检查离线开关状态
      final offlineEnabled =
          await WikiOfflineService.isOfflineEnabled(widget.wikiType);
      debugPrint('[${widget.wikiType}] 离线开关: $offlineEnabled');

      if (offlineEnabled &&
          await WikiOfflineService.hasOfflineZip(widget.wikiType)) {
        // ── 阅后即焚：现场解压 ZIP → 启动本地服务器 ──
        final sitePath =
            await WikiOfflineService.extractZipToTemp(widget.wikiType);
        if (sitePath != null) {
          debugPrint('[${widget.wikiType}] 离线模式，sitePath: $sitePath');
          await _initOfflineMode(sitePath);
          return;
        }
        // 解压失败，降级在线
        debugPrint('[${widget.wikiType}] 解压失败，降级在线');
      }

      // ── 在线模式 ──
      if (offlineEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('离线数据不可用，已切换为在线访问'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
      await _initOnlineMode();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化失败: $e';
      });
    }
  }

  /// 初始化离线模式：启动本地 HTTP 服务器
  Future<void> _initOfflineMode(String sitePath) async {
    // ── 自动探测站点中实际存在的首页路径 ──
    final effectiveIndexPath = _detectIndexPath(sitePath);
    debugPrint('[${widget.wikiType}] 探测到的首页路径: $effectiveIndexPath');

    final staticHandler =
        createStaticHandler(sitePath, defaultDocument: 'index.html');

    // 上帝视角拦截器 + 中文 URL 解码
    Future<Response> smartHandler(Request request) async {
      var response = await staticHandler(request);

      // 对文本类内容：剥离 https:// 引用，干掉 SSL 错误日志
      if (response.statusCode == 200) {
        final ct = response.headers['content-type'] ?? '';
        if (ct.contains('text/html') ||
            ct.contains('text/css') ||
            ct.contains('application/javascript') ||
            ct.contains('text/javascript')) {
          try {
            final body = await response.readAsString();
            final cleaned = body.replaceAll('https://', 'http://0.0.0.0/');
            return Response.ok(cleaned, headers: {
              ...response.headers,
              'content-type': ct,
            });
          } catch (_) {}
        }
      }

      if (response.statusCode == 404) {
        // 先把 %E4%B8%AD... 乱码还原成真正的中文
        final path = Uri.decodeComponent(request.url.path);

        // 尝试精准物理抢救
        final exactFile = File('$sitePath/$path');
        if (exactFile.existsSync()) {
          return Response.ok(exactFile.openRead(),
              headers: {'content-type': 'text/html; charset=utf-8'});
        }

        // 404 调试页面
        final dir = Directory(sitePath);
        String html =
            "<html lang='zh'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'></head>";
        html +=
            "<body style='background:#1e1e2e;color:#cdd6f4;padding:20px;font-family:sans-serif;'>";
        html += "<h2>💩 404 案发现场</h2>";
        html += "<p>WebView 试图寻找: <br><b style='color:#f38ba8;'>/$path</b></p>";
        html += "<p>但它不存在！下面是你手机沙盒里<b style='color:#a6e3a1;'>真实存在</b>的文件：</p>";
        html +=
            "<ul style='font-size:12px;color:#bac2de;word-break:break-all;'>";

        if (dir.existsSync()) {
          final files =
              dir.listSync(recursive: true).whereType<File>().take(50);
          if (files.isEmpty) {
            html +=
                "<li style='color:#f38ba8;'>⚠️ 警报：沙盒里空空如也！(Zip解压绝对失败了！)</li>";
          } else {
            for (var f in files) {
              html += "<li>${f.path.replaceFirst(sitePath, '')}</li>";
            }
          }
        } else {
          html += "<li style='color:#f38ba8;'>⚠️ 警报：连沙盒根目录都不存在！</li>";
        }
        html += "</ul></body></html>";

        return Response.ok(html,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }
      return response;
    }

    ;

    _localServer = await io.serve(smartHandler, 'localhost', _port);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://localhost:$_port$effectiveIndexPath'));

    if (!mounted) return;
    setState(() {
      _controller = controller;
      _isLoading = false;
      _isOfflineMode = true;
    });
  }

  /// 探测站点中实际存在的首页路径
  ///
  /// 先试配置路径，再试常见的备选路径，确保能找到可用的首页。
  String _detectIndexPath(String sitePath) {
    // 备选路径列表（按优先级）
    final candidates = <String>[
      widget.localIndexPath, // /zh-cn/docs/index.html
      '/zh-cn/index.html', // 无 docs 层
      '/index.html', // 根目录
    ];

    for (final path in candidates) {
      if (File('$sitePath$path').existsSync()) {
        debugPrint('[${widget.wikiType}] 探测到首页: $path');
        return path;
      }
    }

    // 兜底：在 zh-cn 下递归找任意 index.html
    try {
      final zhCnDir = Directory('$sitePath/zh-cn');
      if (zhCnDir.existsSync()) {
        final files = zhCnDir.listSync(recursive: true);
        for (final f in files) {
          if (f is File && f.path.endsWith('/index.html')) {
            final relative = f.path.replaceFirst(sitePath, '');
            final path = relative.startsWith('/') ? relative : '/$relative';
            debugPrint('[${widget.wikiType}] zh-cn 下找到首页: $path');
            return path;
          }
        }
      }
    } catch (_) {}

    // 最后兜底返回配置路径
    return widget.localIndexPath;
  }

  /// 初始化在线模式：WebView 直接加载 URL
  Future<void> _initOnlineMode() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame != true) return;
            setState(() {
              _errorMessage = error.description;
            });
          },
        ),
      );

    await controller.loadRequest(Uri.parse(widget.onlineUrl));

    if (!mounted) return;
    setState(() {
      _controller = controller;
      _isLoading = false;
      _isOfflineMode = false;
    });
  }

  @override
  void dispose() {
    _localServer?.close(force: true);
    // 阅后即焚：关闭时删除临时解压目录，保留 ZIP
    if (_isOfflineMode) {
      WikiOfflineService.cleanupExtracted(widget.wikiType);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOfflineMode ? '${widget.title} (离线版)' : widget.title),
        actions: [
          if (_controller != null)
            IconButton(
              tooltip: '后退',
              onPressed: () async {
                if (await _controller!.canGoBack()) {
                  await _controller!.goBack();
                }
              },
              icon: const Icon(Icons.arrow_back),
            ),
          if (_controller != null)
            IconButton(
              tooltip: '刷新',
              onPressed: () => _controller!.reload(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initScreen();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: Text('WebView 未就绪'));
    }

    return WebViewWidget(controller: controller);
  }
}
