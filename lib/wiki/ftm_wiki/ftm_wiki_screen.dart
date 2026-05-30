import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'ftm_wiki_manager.dart';

class FtmWikiScreen extends StatefulWidget {
  const FtmWikiScreen({super.key});

  @override
  State<FtmWikiScreen> createState() => _FtmWikiScreenState();
}

class _FtmWikiScreenState extends State<FtmWikiScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _showMenuHint = false;
  HttpServer? _localServer;

  static const String _prefsWikiMenuHintDismissed =
      'ftm_wiki_menu_hint_dismissed';

  @override
  void initState() {
    super.initState();
    _initWikiWithHardcoreServer();
  }

  /// 将 HTML/JS/CSS 中所有 `https://` 替换为 `http://0.0.0.0/`
  ///
  /// 这样 WebView 会尝试 HTTP 连接一个不存在的本地地址，
  /// 不会发起任何 SSL 握手，彻底杜绝 ssl_client_socket_impl.cc 错误日志。
  static String _stripExternalHttps(String content) {
    return content.replaceAll('https://', 'http://0.0.0.0/');
  }

  Future<void> _initWikiWithHardcoreServer() async {
    await FtmWikiManager.initLocalWiki();
    final sitePath = await FtmWikiManager.effectiveSitePath;
    if (sitePath == null || !mounted) return;

    final staticHandler =
        createStaticHandler(sitePath, defaultDocument: 'index.html');

    // 🚀 上帝视角拦截器 + 中文 URL 解码
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
            final cleaned = _stripExternalHttps(body);
            return Response.ok(cleaned, headers: {
              ...response.headers,
              'content-type': ct,
            });
          } catch (_) {}
        }
      }

      if (response.statusCode == 404) {
        // 🔑 先把 %E4%B8%AD... 乱码还原成真正的中文！
        final path = Uri.decodeComponent(request.url.path);

        // 尝试精准物理抢救
        final exactFile = File('$sitePath/$path');
        if (exactFile.existsSync()) {
          return Response.ok(exactFile.openRead(),
              headers: {'content-type': 'text/html; charset=utf-8'});
        }

        // 💥 抢救失败，启动透视模式！生成一个网页显示硬盘到底有啥
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

    _localServer = await io.serve(smartHandler, 'localhost', 8081);
    debugPrint('🚀 物理截胡版服务器已启动: http://localhost:${_localServer!.port}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://localhost:8081/index.html'));

    setState(() {
      _isLoading = false;
    });

    // 页面加载完成后，检查是否需要显示菜单引导提示
    await _checkMenuHint();
  }

  /// 检查是否需要显示左上角菜单引导提示
  Future<void> _checkMenuHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_prefsWikiMenuHintDismissed) ?? false;
    if (!dismissed && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => _showMenuHint = true);
      }
    }
  }

  void _dismissHintOnce() {
    setState(() => _showMenuHint = false);
  }

  Future<void> _dismissHintForever() async {
    setState(() => _showMenuHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsWikiMenuHintDismissed, true);
  }

  @override
  void dispose() {
    _localServer?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FtM.Wiki (离线版)'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: _controller),
          if (_showMenuHint) _buildMenuHintOverlay(),
        ],
      ),
    );
  }

  Widget _buildMenuHintOverlay() {
    return GestureDetector(
      onTap: _dismissHintOnce,
      child: Container(
        color: Colors.black.withOpacity(0.35),
        child: Stack(
          children: [
            Positioned(
              top: 75,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 28,
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF5BCEFA).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Color(0xFF5BCEFA),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '页面导航提示',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '本知识库的目录 / 菜单按钮在页面左上角的 '
                            '☰ 三个横线中，点击即可浏览所有章节内容。',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF3A3A3C),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: _dismissHintOnce,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF86868B),
                                      side: const BorderSide(
                                          color: Color(0xFFD1D1D6)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '本次关闭',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: FilledButton(
                                    onPressed: _dismissHintForever,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF5BCEFA),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '不再提示',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
