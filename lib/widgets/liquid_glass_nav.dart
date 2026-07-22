import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_tokens.dart';

/// iOS 26 风格 Liquid Glass 底部导航。
///
/// 交互（对照 Apple WWDC25 Liquid Glass tab bar）：
/// - **平时**：不显示玻璃块，仅选中项文字/图标高亮（品牌色 + 填充图标）。
/// - **按下**：手指位置出现一个比导航栏更高的玻璃块，其**左边缘**对齐手指 x
///   （非中心对齐），并随按压增高。
/// - **拖动**：玻璃块左边缘跟随手指 x 无极移动。
/// - **松手**：玻璃块吸附到最近项（中心对齐该标签）并淡出，切换到该标签。
///
/// 视觉：底层为整条低模糊玻璃胶囊（通透，不糊住）；顶层为按压时出现的玻璃指示
/// 块——几乎透明 + 边缘折射（LiquidGlassStyle 光学边框），高度比导航栏高、底边
/// 对齐导航栏底边向上溢出。
class LiquidGlassNav extends StatefulWidget {
  const LiquidGlassNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.destinations,
    required this.tokens,
    required this.themeColor,
    required this.unselectedColor,
    this.barHeight = 60,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<({IconData icon, IconData selectedIcon, String label})>
      destinations;
  final GlassTokens tokens;
  final Color themeColor;
  final Color unselectedColor;
  final double barHeight;

  @override
  State<LiquidGlassNav> createState() => _LiquidGlassNavState();
}

class _LiquidGlassNavState extends State<LiquidGlassNav>
    with SingleTickerProviderStateMixin {
  /// 指示块左边缘 x（像素）。仅按压/拖动时有意义。
  double _indicatorLeft = 0;

  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  int get _n => widget.destinations.length;

  /// 由指示块中心推算最近标签索引。
  ///
  /// 标签 i 的中心位于 `(i + 0.5) * slot`，故最近索引为
  /// `round((center - slot/2) / slot)`——避免 `round(center/slot)` 在标签中心
  /// 处向上取整导致偏右吸附。
  int _nearestFromLeft(double left, double slot, double indicatorWidth) {
    final center = left + indicatorWidth / 2;
    return ((center - slot / 2) / slot).round().clamp(0, _n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barH = widget.barHeight;
    // 容器高度容纳最大指示块（idle +8、press 再 +10），避免被外层 Stack 裁剪。
    final containerH = barH + 8 + 10 + 6;

    // 导航栏玻璃：低模糊（通透，不糊住），表面色局部降低 alpha 避免与指示块叠加发白。
    const barBlur = 8.0;
    final barColor = isDark ? const Color(0x281C1C1E) : const Color(0x33FFFFFF);
    final barStyle = tokens.toLiquidGlassStyle(cornerRadius: 30).copyWith(
          appearance: LiquidGlassAppearance(
            color: barColor,
            saturation: tokens.saturationBoost.clamp(0.0, 3.0),
            blur: const LiquidGlassBlur(sigmaX: barBlur, sigmaY: barBlur),
          ),
        );

    // 指示块：近乎全透明（极低 alpha ~2%）+ blur 0（不重模糊导航栏玻璃，避免发白）+
    // 强色散边缘折射（chromaticAberration 拉高，呈现彩色折射边）。
    final indicatorColor =
        isDark ? const Color(0x061C1C1E) : const Color(0x06FFFFFF);
    final indicatorStyle = tokens.toLiquidGlassStyle(cornerRadius: 22).copyWith(
          appearance: LiquidGlassAppearance(
            color: indicatorColor,
            saturation: tokens.saturationBoost.clamp(0.0, 3.0),
            blur: const LiquidGlassBlur(sigmaX: 0, sigmaY: 0),
          ),
          refraction: const LiquidGlassRefraction(
            distortion: 0.16,
            distortionWidth: 32,
            chromaticAberration: 0.03,
            refractionType: OpticalRefraction(
              refraction: 1.5,
              refractionWidth: 30,
              depth: 0.75,
            ),
          ),
        );

    return SizedBox(
      height: containerH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final slot = width / _n;
          final indicatorWidth = slot * 0.78;
          final maxLeft = width - indicatorWidth;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              setState(() {
                // 玻璃块几何中心对齐手指 x。
                _indicatorLeft = (d.localPosition.dx - indicatorWidth / 2)
                    .clamp(0.0, maxLeft);
              });
              _press.forward();
            },
            onPanUpdate: (d) {
              setState(() {
                _indicatorLeft = (d.localPosition.dx - indicatorWidth / 2)
                    .clamp(0.0, maxLeft);
              });
            },
            onPanEnd: (_) {
              final nearest =
                  _nearestFromLeft(_indicatorLeft, slot, indicatorWidth);
              // 吸附：指示块中心对齐最近标签，然后淡出。
              final snappedLeft = nearest * slot + (slot - indicatorWidth) / 2;
              setState(() {
                _indicatorLeft = snappedLeft;
              });
              _press.reverse();
              widget.onChanged(nearest);
            },
            onPanCancel: () {
              _press.reverse();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── 底层：整条玻璃胶囊（底边对齐容器底边）+ 4 个标签 ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: barH,
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadowColor,
                            blurRadius: tokens.shadowBlur,
                            offset: tokens.shadowOffset,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: LiquidGlassLens(
                          style: barStyle,
                          child: Row(
                            children: List.generate(_n, (i) {
                              final d = widget.destinations[i];
                              final sel = i == widget.currentIndex;
                              return Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      sel ? d.selectedIcon : d.icon,
                                      size: 22,
                                      color: sel
                                          ? widget.themeColor
                                          : widget.unselectedColor,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      d.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: sel
                                            ? widget.themeColor
                                            : widget.unselectedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── 顶层：按压时出现的玻璃指示块（平时隐藏，中心对齐导航栏上下对称超出）──
                AnimatedBuilder(
                  animation: _press,
                  builder: (context, child) {
                    // 平时（_press==0）不渲染玻璃块，避免无谓 BackdropFilter。
                    if (_press.value < 0.01) return const SizedBox.shrink();
                    final h = barH + 8 + 10 * _press.value;
                    return Positioned(
                      left: _indicatorLeft,
                      // 中心对齐导航栏中心：bottom 为负时向下溢出，上下对称超出
                      bottom: (barH - h) / 2,
                      child: Opacity(
                        opacity: _press.value,
                        child: SizedBox(
                          width: indicatorWidth,
                          height: h,
                          child: child!,
                        ),
                      ),
                    );
                  },
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: LiquidGlassLens(
                        style: indicatorStyle,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
