import 'dart:async';

import 'package:flutter/material.dart';

/// 全应用统一加载指示器
///
/// 显示"少女祈祷中"加动态三个点动画（. → .. → ... → 循环），
/// 配合柔和脉冲图标，取代原始的 [CircularProgressIndicator]。
class LoadingIndicator extends StatefulWidget {
  /// 可选的副标题（显示在主文本下方）
  final String? subtitle;

  /// 图标
  final IconData icon;

  const LoadingIndicator({
    super.key,
    this.subtitle,
    this.icon = Icons.auto_awesome,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  int _dotCount = 0;
  Timer? _dotTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 三个点动画：每 500ms 切换一次
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });

    // 脉冲动画：缓慢呼吸效果
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String get _dots {
    switch (_dotCount) {
      case 0:
        return '';
      case 1:
        return '.';
      case 2:
        return '..';
      case 3:
        return '...';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 脉冲图标（克制单色） ──
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 28,
                color: secondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 主文字 + 动态点 ──
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
              letterSpacing: 0.3,
              height: 1.4,
            ),
            child: Text.rich(
              TextSpan(
                text: '少女祈祷中',
                children: [
                  TextSpan(
                    text: _dots,
                    style: const TextStyle(letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),

          // ── 副标题 ──
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: secondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
