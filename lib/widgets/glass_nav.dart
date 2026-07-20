import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import 'glass_card.dart' show ChromaticEdgePainter;

/// 液态玻璃底部导航 —— 双模自适应
///
/// - **液态玻璃模式**：浮动胶囊形玻璃条，与屏幕底边留间距，
///   选中项用品牌色 + 轻微放大（弹簧手感由调用方在 onDestinationSelected
///   触发重建实现）。
/// - **简约风模式**：退化为与 [`navigationBarTheme`](Trans-Prism/lib/main.dart:153)
///   一致的实色 NavigationBar。
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
    final tokens = GlassTheme.of(context);
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

    // 液态玻璃：浮动胶囊条
    final blur = blurSigma ?? tokens.blurSigma;
    final bg = surfaceColor ?? tokens.surfaceColor;
    final primary = theme.colorScheme.primary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // 1. 背景模糊
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: const SizedBox.expand(),
                ),
                // 3. 半透明表面
                ColoredBox(
                  color: bg,
                  child: const SizedBox.expand(),
                ),
                // 4. 光泽渐变
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: tokens.sheenGradient,
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                // 5. 色散边缘
                IgnorePointer(
                  child: CustomPaint(
                    painter: ChromaticEdgePainter(
                      colors: tokens.chromaticEdgeColors,
                      radius: 28,
                      width: 0.8,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                // 6. 顶部高光边
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border(
                        top: BorderSide(
                          width: 1.2,
                          color: Colors.white.withValues(
                            alpha: tokens.highlightEdgeAlpha,
                          ),
                        ),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                // 7. 导航内容
                SizedBox(
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
              ], // Stack children
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
