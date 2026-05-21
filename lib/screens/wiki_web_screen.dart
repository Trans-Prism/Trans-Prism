import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../models/wiki_config.dart';
import '../services/wiki_sync_service.dart';
import '../widgets/loading_indicator.dart';

/// 内嵌完整 Wiki 站点（与 Next-MtF-wiki 部署的在线版一致）
class WikiWebScreen extends StatefulWidget {
  final String wikiId;
  final String title;

  const WikiWebScreen({
    super.key,
    required this.wikiId,
    required this.title,
  });

  @override
  State<WikiWebScreen> createState() => _WikiWebScreenState();
}

class _WikiWebScreenState extends State<WikiWebScreen> {
  final WikiSyncService _sync = WikiSyncService.instance;
  WebViewController? _controller;
  bool _isInitializing = true;
  String? _errorMessage;
  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      final config = WikiCatalog.require(widget.wikiId);
      final snapshot = await _sync.resolveForOpen(widget.wikiId);
      final preferLocal = snapshot.strategy == WikiCacheStrategy.preferLocal;

      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => _onPageFinished(snapshot),
            onWebResourceError: (error) {
              if (!mounted) return;
              if (error.isForMainFrame != true) return;
              setState(() {
                _errorMessage = error.description;
              });
            },
          ),
        );

      await controller.loadRequest(
        Uri.parse(config.webUrl),
        headers: preferLocal ? const {} : const {'Cache-Control': 'no-cache'},
      );

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }

  Future<void> _onPageFinished(WikiSyncSnapshot snapshot) async {
    if (snapshot.strategy == WikiCacheStrategy.preferRemote &&
        snapshot.remoteFingerprint != null) {
      await _sync.markContentCached(widget.wikiId, snapshot.remoteFingerprint!);
    }
  }

  Future<void> _retryWithNetwork() async {
    final config = WikiCatalog.require(widget.wikiId);
    final controller = _controller;
    if (controller == null) return;

    setState(() => _errorMessage = null);
    await controller.loadRequest(
      Uri.parse(config.webUrl),
      headers: const {'Cache-Control': 'no-cache'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
    if (_isInitializing) {
      return const LoadingIndicator(
        subtitle: '正在打开 Wiki',
        icon: Icons.menu_book_rounded,
      );
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
                onPressed: _retryWithNetwork,
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
