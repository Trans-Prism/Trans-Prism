import 'package:flutter/material.dart';

/// 液态玻璃（Liquid Glass）主题 Token
///
/// 设计依据：Apple WWDC *Designing Fluid Interfaces* §12 Materials & depth
/// 及 WWDC25 Liquid Glass 视觉规范。
///
/// 关键视觉特征（对照真实 iOS 截图）：
/// 1. **高透明度**：表面 alpha 仅 ~20%，背景色彩清晰透出
/// 2. **强模糊**：sigma 30+，背景被高度模糊但仍保留色彩
/// 3. **色散/棱镜边缘**：边缘有微妙的彩虹色散折射
/// 4. **表面光泽**：顶部有微妙的光泽渐变（光从上方打来）
/// 5. **饱和度增强**：模糊后的背景色彩被提饱和（vibrancy）
///
/// 本类是不可变值对象。亮/暗各一套预设；并内建无障碍降级变体
///（§14：`prefers-reduced-transparency` / `prefers-contrast: more` 时实心化）。
@immutable
class GlassTokens {
  const GlassTokens({
    required this.isEnabled,
    required this.blurSigma,
    required this.surfaceColor,
    required this.borderColor,
    required this.borderRadius,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.highlightEdgeAlpha,
    required this.scrimColor,
    required this.sheenGradient,
    required this.chromaticEdgeColors,
    required this.saturationBoost,
  });

  /// 是否启用玻璃效果（minimal 风格下为 false，组件据此退化为简约外观）
  final bool isEnabled;

  /// 背景模糊强度（sigma）。降级时为 0。
  final double blurSigma;

  /// 半透明表面填充色（已含 alpha）。
  /// Apple Liquid Glass 的表面 alpha 仅 ~20%，背景色彩清晰透出。
  final Color surfaceColor;

  /// 边框色（已含 alpha）。玻璃顶部高光边由 [highlightEdgeAlpha] 控制。
  final Color borderColor;

  /// 默认圆角。
  final double borderRadius;

  /// 阴影色。
  final Color shadowColor;

  /// 阴影模糊半径。
  final double shadowBlur;

  /// 阴影偏移。
  final Offset shadowOffset;

  /// 顶部 1px 高光边的 alpha（光线打在材质上的反射，§12）。
  final double highlightEdgeAlpha;

  /// 模态遮罩色（用于 Sheet/Dialog 背后压暗，§12 Dim to focus）。
  final Color scrimColor;

  /// 表面光泽渐变（顶部亮 → 底部暗，模拟光从上方打来）。
  /// 叠加在模糊层之上、内容之下。
  final List<Color> sheenGradient;

  /// 色散边缘色（棱镜折射效果，从左到右的微妙彩虹渐变）。
  /// 用于边缘 1-2px 的渐变描边。
  final List<Color> chromaticEdgeColors;

  /// 饱和度增强倍率（1.0 = 不变，1.8 = Apple 典型 vibrancy）。
  /// 通过 ColorFilter.matrix 实现，叠加在 BackdropFilter 之上。
  final double saturationBoost;

  // ──────────────────────────────────────────────────────────
  //  预设
  // ──────────────────────────────────────────────────────────

  /// 简约风退化 Token —— 玻璃组件在 minimal 模式下使用此 Token，
  /// 退化为与既有简约卡片一致的外观（实心、无边框、柔弥散阴影）。
  static const GlassTokens minimalLight = GlassTokens(
    isEnabled: false,
    blurSigma: 0,
    surfaceColor: Color(0xFFFFFFFF),
    borderColor: Color(0x00000000),
    borderRadius: 16,
    shadowColor: Color(0x14000000),
    shadowBlur: 12,
    shadowOffset: Offset(0, 4),
    highlightEdgeAlpha: 0,
    scrimColor: Color(0x66000000),
    sheenGradient: [Color(0x00000000), Color(0x00000000)],
    chromaticEdgeColors: [Color(0x00000000)],
    saturationBoost: 1.0,
  );

  static const GlassTokens minimalDark = GlassTokens(
    isEnabled: false,
    blurSigma: 0,
    surfaceColor: Color(0xFF24242C),
    borderColor: Color(0x00000000),
    borderRadius: 16,
    shadowColor: Color(0x40000000),
    shadowBlur: 16,
    shadowOffset: Offset(0, 6),
    highlightEdgeAlpha: 0,
    scrimColor: Color(0x99000000),
    sheenGradient: [Color(0x00000000), Color(0x00000000)],
    chromaticEdgeColors: [Color(0x00000000)],
    saturationBoost: 1.0,
  );

  /// 液态玻璃 · 亮色预设
  ///
  /// 对照真实 iOS 截图：
  /// - 表面 alpha ~20%（0x33），背景色彩清晰透出
  /// - 模糊 sigma 30（强模糊但保留色彩）
  /// - 饱和度增强 1.8x（vibrancy）
  /// - 顶部光泽渐变：白 18% → 透明 → 白 6%
  /// - 色散边缘：微妙的红→黄→青→蓝渐变
  static const GlassTokens liquidLight = GlassTokens(
    isEnabled: true,
    blurSigma: 30,
    surfaceColor: Color(0x33FFFFFF), // ~20% 白
    borderColor: Color(0x66FFFFFF), // ~40% 亮边
    borderRadius: 20,
    shadowColor: Color(0x24000000), // ~14% 阴影
    shadowBlur: 30,
    shadowOffset: Offset(0, 10),
    highlightEdgeAlpha: 0.7,
    scrimColor: Color(0x40000000), // ~25% 压暗
    sheenGradient: [
      Color(0x2EFFFFFF), // 顶部 ~18% 白
      Color(0x0DFFFFFF), // 中部 ~5% 白
      Color(0x00FFFFFF), // 底部透明
    ],
    chromaticEdgeColors: [
      Color(0x22FF6B6B), // 红
      Color(0x22FFD93D), // 黄
      Color(0x226BCBFF), // 青
      Color(0x22A06BFF), // 蓝
    ],
    saturationBoost: 1.8,
  );

  /// 液态玻璃 · 暗色预设
  ///
  /// 暗色玻璃更厚：略高 alpha、更深阴影（§12 Bigger surfaces read as thicker）。
  /// 但仍保持高透明度，背景色彩透出。
  static const GlassTokens liquidDark = GlassTokens(
    isEnabled: true,
    blurSigma: 35,
    surfaceColor: Color(0x401C1C1E), // ~25% 深灰
    borderColor: Color(0x55FFFFFF), // 亮边在暗色上更明显
    borderRadius: 20,
    shadowColor: Color(0x50000000),
    shadowBlur: 36,
    shadowOffset: Offset(0, 12),
    highlightEdgeAlpha: 0.6,
    scrimColor: Color(0x66000000), // ~40% 压暗
    sheenGradient: [
      Color(0x24FFFFFF), // 顶部 ~14% 白
      Color(0x0AFFFFFF), // 中部 ~4% 白
      Color(0x00FFFFFF), // 底部透明
    ],
    chromaticEdgeColors: [
      Color(0x20FF6B6B),
      Color(0x20FFD93D),
      Color(0x206BCBFF),
      Color(0x20A06BFF),
    ],
    saturationBoost: 1.6,
  );

  // ──────────────────────────────────────────────────────────
  //  无障碍降级（§14）
  // ──────────────────────────────────────────────────────────

  /// 减少透明度降级 —— 玻璃面变实心：blur→0、surface 不透明、保留边框。
  GlassTokens toReducedTransparency() {
    if (!isEnabled) return this;
    return GlassTokens(
      isEnabled: true,
      blurSigma: 0,
      surfaceColor: surfaceColor.withAlpha(255),
      borderColor: borderColor.withAlpha(180),
      borderRadius: borderRadius,
      shadowColor: shadowColor,
      shadowBlur: shadowBlur,
      shadowOffset: shadowOffset,
      highlightEdgeAlpha: 0,
      scrimColor: scrimColor.withAlpha(220),
      sheenGradient: const [Color(0x00000000), Color(0x00000000)],
      chromaticEdgeColors: const [Color(0x00000000)],
      saturationBoost: 1.0,
    );
  }

  /// 构建饱和度增强 ColorFilter.matrix
  ///
  /// 将 RGB 各通道以灰度分量为中心做缩放：
  /// `out = gray + saturation * (channel - gray)`
  /// saturation = 1.0 时恒等，>1.0 增强饱和度。
  ColorFilter saturationColorFilter() {
    final s = saturationBoost;
    final sr = 0.3086;
    final sg = 0.6094;
    final sb = 0.0820;
    return ColorFilter.matrix([
      (1 - s) * sr + s, (1 - s) * sg, (1 - s) * sb, 0, 0, //
      (1 - s) * sr, (1 - s) * sg + s, (1 - s) * sb, 0, 0,
      (1 - s) * sr, (1 - s) * sg, (1 - s) * sb + s, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  /// 按亮度选择对应预设
  static GlassTokens resolve({
    required bool isLiquid,
    required bool isDark,
  }) {
    if (!isLiquid) return isDark ? minimalDark : minimalLight;
    return isDark ? liquidDark : liquidLight;
  }
}
