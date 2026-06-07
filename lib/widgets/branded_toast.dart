import 'package:flutter/material.dart';

/// 跨性别蓝粉白配色的品牌 Toast，从顶部滑入，自动消失
///
/// 通过 Overlay 实现全局 toast，不受 Scaffold 层级限制。
///
/// ⚠️ 安全使用规则：
/// 1. 不要在 `Navigator.pop(context)` 之前或之后立即调用 —— 此时 context
///    关联的 Overlay 正在移除路由条目，插入 OverlayEntry 会引发竞态条件：
///    「Tried to build dirty widget in the wrong build scope」以及
///    「_dependents.isEmpty」断言失败。
/// 2. 优先在发起弹出层的「调用方」context 上调用，而非弹出层内部的 context。
class BrandedToast {
  /// 显示一条品牌 Toast
  ///
  /// [context] 用于获取 Overlay
  /// [message] 显示的文字
  /// [icon] 可选的前置图标
  /// [backgroundColor] 默认使用 Trans 蓝粉色渐变
  /// [duration] 显示时长，默认 2 秒
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    _showToast(
      context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  /// 成功 Toast（带有 ✅ 图标）
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showToast(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  /// 错误 Toast（带有 ⚠️ 图标，红色调）
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showToast(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFE57373),
      duration: duration,
    );
  }

  /// 用药提醒 Toast（带有 💊 图标）
  static void doseRecorded(
    BuildContext context,
    String drugName, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showToast(
      context,
      message: '已记录 $drugName · 稳态加一',
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  static void _showToast(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? backgroundColor,
    required Duration duration,
  }) {
    // 🔐 使用 post-frame callback 确保 OverlayEntry 插入发生在当前帧构建阶段之后，
    //    避免在 Overlay 正在处理路由变更时插入条目引发竞态。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      // 优先使用 rootOverlay（Navigator 根层 Overlay），它在路由切换时不会被销毁
      final overlay = Overlay.of(context, rootOverlay: true);

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _BrandedToastWidget(
          message: message,
          icon: icon,
          backgroundColor: backgroundColor,
          onDismiss: () {
            // 安全移除：只有 entry 还挂载在 Overlay 中时才移除
            try {
              entry.remove();
            } catch (_) {
              // 忽略已卸载的 OverlayEntry 移除异常
            }
          },
          duration: duration,
        ),
      );

      overlay.insert(entry);
    });
  }
}

class _BrandedToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final VoidCallback onDismiss;
  final Duration duration;

  const _BrandedToastWidget({
    required this.message,
    this.icon,
    this.backgroundColor,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_BrandedToastWidget> createState() => _BrandedToastWidgetState();
}

class _BrandedToastWidgetState extends State<_BrandedToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    // 滑入
    _controller.forward();

    // 自动消失
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 默认使用 Trans 蓝粉渐变
    final effectiveBg = widget.backgroundColor;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: effectiveBg == null
                    ? const LinearGradient(
                        colors: [Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: effectiveBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5BCEFA).withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
