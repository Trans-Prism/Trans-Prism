import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/glass_theme.dart';

/// 液态玻璃底部导航 —— 双模自适应
///
/// - **液态玻璃模式**：浮动胶囊形玻璃条，由 [`LiquidGlassLens`] 接管折射/
///   模糊/光学边框（Impeller 独立采样实时背景）。选中项用品牌色 + 轻微放大。
/// - **简约风模式**：退化为与 [`navigationBarTheme`](Trans-Prism/lib/main.dart:153)
///   一致的实色 [`NavigationBar`]。
class GlassNav extends StatelessWidget {
  const GlassNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.height = 64,
    this.blurSigma,
    this.surfaceColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final double height;
  final double? blurSigma;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    var tokens = GlassTheme.of(context);
    final theme = Theme.of(context);

    // 简约风退化：直接用主题 NavigationBar
    if (!tokens.isEnabled) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        height: height,
      );
    }

    if (MediaQuery.of(context).accessibleNavigation) {
      tokens = tokens.toReducedTransparency();
    }

    // 液态玻璃：浮动胶囊条
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;
    final primary = theme.colorScheme.primary;

    final style = tokens.toLiquidGlassStyle(cornerRadius: 28).copyWith(
          appearance: LiquidGlassAppearance(
            color: bg,
            saturation: tokens.saturationBoost.clamp(0.0, 3.0),
            blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
          ),
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowColor,
                  blurRadius: tokens.shadowBlur,
                  offset: tokens.shadowOffset,
                ),
              ],
            ),
            child: LiquidGlassLens(
              style: style,
              child: SizedBox(
                height: height,
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _GlassNavItem(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          primaryColor: primary,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.destination,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? primaryColor : Theme.of(context).hintColor;
    // 选中项轻微放大（弹簧手感由外层重建自然产生）
    final iconScale = selected ? 1.08 : 1.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: iconScale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: IconTheme.merge(
              data: IconThemeData(color: color, size: 24),
              child: selected
                  ? (destination.selectedIcon ?? destination.icon)
                  : destination.icon,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: color,
              height: 1.3,
            ),
            child: Text(destination.label),
          ),
        ],
      ),
    );
  }
}
