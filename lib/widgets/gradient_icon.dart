import 'package:flutter/material.dart';

/// =============================================================================
/// GradientIcon — 品牌图标封装组件（Claude 风格克制版）
///
/// 设计理念：
///   Claude 风格强调克制，图标不再使用全屏 ShaderMask 渐变填充。
///   默认改为单色 `Icon`，颜色取自主题的 `iconTheme`（亮色 #6B6B76 / 暗色 #8E8E96），
///   让图标安静地服务于信息层级，而非抢夺视觉焦点。
///
///   保留 `gradientColors` 参数以兼容现有调用，但默认不再渲染渐变——
///   仅当显式传入非空渐变色且 `useGradient=true` 时才叠加 ShaderMask，
///   用于极少数「签名时刻」（如品牌 Logo 展示）。
/// =============================================================================
class GradientIcon extends StatelessWidget {
  /// 图标数据
  final IconData icon;

  /// 图标尺寸（宽高一致，默认 24）
  final double size;

  /// 渐变颜色列表（保留兼容；默认不渲染渐变）
  final List<Color> gradientColors;

  /// 渐变方向起点（默认左上）
  final Alignment begin;

  /// 渐变方向终点（默认右下）
  final Alignment end;

  /// 是否启用渐变渲染（默认 false = 单色克制）
  final bool useGradient;

  /// 单色模式下的图标颜色（null 时跟随主题 iconTheme）
  final Color? color;

  const GradientIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.gradientColors = const [
      Color(0xFFF5A9B8), // 品牌浅蓝
      Color(0xFFF5A9B8), // 品牌粉紫
    ],
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.useGradient = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // ── 克制模式：单色图标，跟随主题 ──
    if (!useGradient) {
      return Icon(
        icon,
        size: size,
        color: color ?? IconTheme.of(context).color,
      );
    }

    // ── 签名模式：仅在显式要求时叠加品牌渐变 ──
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
