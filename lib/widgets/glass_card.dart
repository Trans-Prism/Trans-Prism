import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_theme.dart';
import '../theme/glass_tokens.dart';

/// 液态玻璃卡片 —— 双模自适应
///
/// - **液态玻璃模式**（`GlassTokens.isEnabled == true`）：
///   由 [`LiquidGlassLens`] 接管渲染——Impeller 下独立采样实时背景做
///   Snell 折射 + 光学边框 + 模糊 + 着色（§12 Materials & depth），
///   Skia/Web 无 [`LiquidGlassView`] 祖先时自动降级为 frosted（模糊+着色+边框）。
///   彻底消除 v1 手写 `Stack`+`Positioned.fill` 的高度塌陷问题。
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
    // 无障碍兜底：开启"减少动效/透明度"时玻璃面实心化（§14）。
    if (tokens.isEnabled && MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }
    final radius = borderRadius ?? tokens.borderRadius;

    final bg = surfaceColor ?? tokens.surfaceColor;
    final card = _buildSurface(context, tokens, radius, bg);

    return Container(
      margin: margin,
      child: DecoratedBox(
        // 阴影承载于最外层：Material 的 Clip.antiAlias 会裁剪其 child，若阴影
        // 放在 Material 内层 DecoratedBox 上会被裁掉，卡片将无阴影/扁平、丢失
        // 材质立体感（GlassSurface 已有同样注释）。置于外层则阴影始终可见。
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
        child: Material(
          // 简约风背景承载于 Material 上：InkWell 波纹与子级 ListTile 的 ink
          // splash 绘制在最近 Material 上，若背景放在内层 DecoratedBox 会被判定
          // 为遮挡而触发 "ListTile background color or ink splashes may be
          // invisible" 断言。液态风保持透明由 LiquidGlassLens 渲染。
          color: tokens.isEnabled ? Colors.transparent : bg,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(radius),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _buildSurface(
    BuildContext context,
    GlassTokens tokens,
    double radius,
    Color bg,
  ) {
    final blur = blurSigma ?? tokens.blurSigma;

    // 简约风退化：实心表面，无模糊，无高光边。
    // 背景色由外层 Material 承载、阴影由 build() 外层 DecoratedBox 承载，
    // 此处仅承载 padding，避免内层 DecoratedBox 遮挡子级 ListTile 的 ink splash。
    if (!tokens.isEnabled) {
      return Padding(padding: padding, child: child);
    }

    // 液态玻璃：LiquidGlassLens 接管折射/模糊/边框/光泽。
    // 阴影已由 build() 外层 DecoratedBox 承载（不被 Material 裁剪）。
    // RepaintBoundary 隔离重绘区域（§D 性能优化）。
    final style = tokens.toLiquidGlassStyle(cornerRadius: radius).copyWith(
          appearance: LiquidGlassAppearance(
            color: bg,
            saturation: tokens.saturationBoost.clamp(0.0, 3.0),
            blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
          ),
        );

    return RepaintBoundary(
      child: LiquidGlassLens(
        style: style,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// 色散边缘画笔 —— v1 手写实现，保留以兼容历史导入（liquid 模式现由
/// [`LiquidGlassLens`] 的光学边框接管，此类不再被组件使用）。
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
