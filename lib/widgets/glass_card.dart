import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/glass_tokens.dart';

/// 液态玻璃卡片 —— 双模自适应
///
/// - **液态玻璃模式**（`GlassTokens.isEnabled == true`）：
///   `ClipRRect` → `BackdropFilter(blur)` → 半透明表面 + 顶部 1px 高光边
///   + 柔弥散阴影（§12 Materials & depth）。
/// - **简约风模式**（`isEnabled == false`）：
///   退化为实心白底/`#24242C` 底、无边框、原弥散阴影，
///   与既有 [`cardTheme`](Trans-Prism/lib/main.dart:145) 像素级一致。
///
/// 这样各业务页只需把 `Card` 换成 `GlassCard`，即可在两风格间无缝切换，
/// 无需改动调用代码。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.onTap,
    this.onLongPress,
    this.elevation,
    this.surfaceColor,
    this.blurSigma,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? elevation;
  final Color? surfaceColor;
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    var tokens = GlassTheme.of(context);
    // 无障碍兜底：组件内部检测 accessibleNavigation（外层 MaterialApp 已注入 MediaQuery），
    // 开启"减少动效/透明度"时玻璃面实心化（§14）。
    if (tokens.isEnabled && MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? tokens.borderRadius;

    final card = _buildSurface(context, tokens, isDark, radius);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius),
          child: card,
        ),
      ),
    );
  }

  Widget _buildSurface(
    BuildContext context,
    GlassTokens tokens,
    bool isDark,
    double radius,
  ) {
    final bg = surfaceColor ?? tokens.surfaceColor;
    final blur = blurSigma ?? tokens.blurSigma;

    // 简约风退化：实心表面，无模糊，无高光边
    if (!tokens.isEnabled) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: tokens.shadowColor,
              blurRadius: tokens.shadowBlur,
              offset: tokens.shadowOffset,
            ),
          ],
        ),
        padding: padding,
        child: child,
      );
    }

    // 液态玻璃：强模糊 + 高透明表面 + 光泽渐变
    // + 色散边缘 + 顶部高光边 + 柔弥散阴影（对照真实 iOS 截图）
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowColor,
            blurRadius: tokens.shadowBlur,
            offset: tokens.shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.loose,
          children: [
            // 装饰层：Positioned.fill 铺满，不影响 Stack 高度
            // 1. 背景模糊层
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: const SizedBox.expand(),
              ),
            ),
            // 2. 半透明表面填充（~20% alpha，背景色彩透出）
            Positioned.fill(child: ColoredBox(color: bg)),
            // 3. 表面光泽渐变（顶部亮 → 底部透明）
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: tokens.sheenGradient,
                    ),
                  ),
                ),
              ),
            ),
            // 4. 色散边缘（棱镜折射）
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ChromaticEdgePainter(
                    colors: tokens.chromaticEdgeColors,
                    radius: radius,
                    width: 0.8,
                  ),
                ),
              ),
            ),
            // 5. 顶部 1px 高光边
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border(
                      top: BorderSide(
                        width: 1.2,
                        color: Colors.white.withValues(
                          alpha: tokens.highlightEdgeAlpha,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 6. 内容（决定 Stack/ClipRRect 的实际高度）
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 色散边缘画笔 —— 沿圆角矩形边缘绘制多色渐变线，模拟棱镜色散。
///
/// 公开类，供 [GlassNav] 等其他玻璃组件复用。
class ChromaticEdgePainter extends CustomPainter {
  final List<Color> colors;
  final double radius;
  final double width;

  const ChromaticEdgePainter({
    required this.colors,
    required this.radius,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty || width <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(width / 2),
        Radius.circular(radius),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(ChromaticEdgePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.radius != radius ||
      oldDelegate.width != width;
}
