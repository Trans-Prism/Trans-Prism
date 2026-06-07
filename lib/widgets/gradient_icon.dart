import 'package:flutter/material.dart';

/// =============================================================================
/// GradientIcon — 统一渐变图标封装组件
///
/// 使用 [ShaderMask] 为 [Icon] 叠加品牌渐变色调，确保工作台网格内所有图标
/// 在颜色质感上完全统一，符合 Quiet Luxury 的克制感。
///
/// 默认使用 Trans Prism 品牌色系渐变：
///   - 浅蓝 (#5BCEFA) → 粉紫 (#F5A9B8)
/// =============================================================================
class GradientIcon extends StatelessWidget {
  /// 图标数据
  final IconData icon;

  /// 图标尺寸（宽高一致，默认 44）
  final double size;

  /// 渐变颜色列表（默认：浅蓝 → 粉紫）
  final List<Color> gradientColors;

  /// 渐变方向起点（默认左上）
  final Alignment begin;

  /// 渐变方向终点（默认右下）
  final Alignment end;

  const GradientIcon(
    this.icon, {
    super.key,
    this.size = 44,
    this.gradientColors = const [
      Color(0xFF5BCEFA), // 品牌浅蓝
      Color(0xFFF5A9B8), // 品牌粉紫
    ],
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradientColors,
        begin: begin,
        end: end,
      ).createShader(bounds),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}
