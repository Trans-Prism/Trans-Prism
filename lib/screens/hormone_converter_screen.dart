import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_surface.dart';
import '../utils/hormone_converter_logic.dart';

/// 激素换算器页面
///
/// 支持双向实时绑定：输入任意一侧自动换算另一侧。
/// 参考范围卡片采用「全场焦点高亮」方案：
///   命中卡片 → 固态品牌色背景 + 1.02x 缩放 + 深度阴影 (Pop)
///   未命中卡片（有命中时）→ 灰度化/背景化 (Dim)
///   未命中卡片（无命中时）→ 常态微光背景 (Normal)
///
/// 色彩符号系统基于跨性别旗帜：
///   MtF → Pastel Pink (#F5A9B8)    FtM → Pastel Blue (#5BCEFA)
///   NB  → Off-white  (#EBEBED)
class HormoneConverterScreen extends StatefulWidget {
  const HormoneConverterScreen({super.key});

  @override
  State<HormoneConverterScreen> createState() => _HormoneConverterScreenState();
}

class _HormoneConverterScreenState extends State<HormoneConverterScreen> {
  // ---- 当前选中的激素 ----
  late HormoneType _selectedHormone;

  // ---- 单位选择 ----
  late String _fromUnit;
  late String _toUnit;

  // ---- 输入控制器 ----
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  // ---- 焦点追踪 ----
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  bool _fromFocused = false;
  bool _toFocused = false;

  // ---- 换算结果缓存 ----
  ConversionResult? _fromResult;
  ConversionResult? _toResult;

  @override
  void initState() {
    super.initState();
    _selectedHormone = getHormoneById(defaultHormoneId)!;
    final defaults = getDefaultUnits(_selectedHormone);
    _fromUnit = defaults.fromUnit;
    _toUnit = defaults.toUnit;

    _fromFocus.addListener(_onFromFocusChange);
    _toFocus.addListener(_onToFocusChange);
  }

  @override
  void dispose() {
    _fromFocus.removeListener(_onFromFocusChange);
    _toFocus.removeListener(_onToFocusChange);
    _fromController.dispose();
    _toController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _onFromFocusChange() {
    if (mounted && _fromFocused != _fromFocus.hasFocus) {
      setState(() => _fromFocused = _fromFocus.hasFocus);
    }
  }

  void _onToFocusChange() {
    if (mounted && _toFocused != _toFocus.hasFocus) {
      setState(() => _toFocused = _toFocus.hasFocus);
    }
  }

  // -----------------------------------------------------------------------
  // 激素切换
  // -----------------------------------------------------------------------
  void _selectHormone(HormoneType hormone) {
    if (hormone.id == _selectedHormone.id) return;

    setState(() {
      _selectedHormone = hormone;
      final defaults = getDefaultUnits(hormone);
      _fromUnit = defaults.fromUnit;
      _toUnit = defaults.toUnit;
      _fromController.clear();
      _toController.clear();
      _fromResult = null;
      _toResult = null;
    });
  }

  // -----------------------------------------------------------------------
  // 双向换算逻辑
  // -----------------------------------------------------------------------
  void _onFromChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _toController.clear();
        _fromResult = null;
        _toResult = null;
      });
      return;
    }

    final result = performConversion(
      value,
      _fromUnit,
      _toUnit,
      _selectedHormone.id,
    );

    setState(() {
      _fromResult = performConversion(
        value,
        _fromUnit,
        _fromUnit,
        _selectedHormone.id,
      );
      _toResult = result;
      if (result.isValid && !_toFocus.hasFocus) {
        _toController.text = formatValue(result.value);
      }
    });
  }

  void _onToChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _fromController.clear();
        _fromResult = null;
        _toResult = null;
      });
      return;
    }

    final result = performConversion(
      value,
      _toUnit,
      _fromUnit,
      _selectedHormone.id,
    );

    setState(() {
      _toResult = performConversion(
        value,
        _toUnit,
        _toUnit,
        _selectedHormone.id,
      );
      _fromResult = result;
      if (result.isValid && !_fromFocus.hasFocus) {
        _fromController.text = formatValue(result.value);
      }
    });
  }

  // -----------------------------------------------------------------------
  // 单位下拉切换
  // -----------------------------------------------------------------------
  void _onFromUnitChanged(String newUnit) {
    if (newUnit == _fromUnit) return;
    final currentText = _fromController.text;
    setState(() => _fromUnit = newUnit);
    if (currentText.isNotEmpty) _onFromChanged(currentText);

    if (areUnitsEquivalent(_selectedHormone, newUnit, _toUnit)) {
      for (final u in _selectedHormone.units) {
        if (!areUnitsEquivalent(_selectedHormone, newUnit, u.symbol)) {
          setState(() => _toUnit = u.symbol);
          if (currentText.isNotEmpty) _onFromChanged(currentText);
          break;
        }
      }
    }
  }

  void _onToUnitChanged(String newUnit) {
    if (newUnit == _toUnit) return;
    final currentText = _toController.text;
    setState(() => _toUnit = newUnit);
    if (currentText.isNotEmpty) _onToChanged(currentText);

    if (areUnitsEquivalent(_selectedHormone, newUnit, _fromUnit)) {
      for (final u in _selectedHormone.units) {
        if (!areUnitsEquivalent(_selectedHormone, newUnit, u.symbol)) {
          setState(() => _fromUnit = u.symbol);
          if (currentText.isNotEmpty) _onToChanged(currentText);
          break;
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // 互换 from/to
  // -----------------------------------------------------------------------
  void _swapUnits() {
    final fromText = _fromController.text;
    final toText = _toController.text;

    setState(() {
      final tempUnit = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = tempUnit;

      _fromController.text = toText;
      _toController.text = fromText;

      final tempResult = _fromResult;
      _fromResult = _toResult;
      _toResult = tempResult;
    });
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1C1C1A) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          '激素换算器',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color:
                  isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333)),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHormoneChips(),
              const SizedBox(height: 20),
              _buildConversionSection(),
              const SizedBox(height: 24),
              _buildReferenceRanges(),
              const SizedBox(height: 36),
              _buildAttribution(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // =======================================================================
  // 激素 Chips
  // =======================================================================
  Widget _buildHormoneChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hormones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hormone = hormones[index];
          final isSelected = hormone.id == _selectedHormone.id;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          // 玻璃药丸：液态模式下由 LiquidGlassLens 接管；简约风退化为实色/透明胶囊。
          return GlassSurface(
            onTap: () => _selectHormone(hormone),
            solidColor: isSelected
                ? (isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333))
                : Colors.transparent,
            borderRadius: 18,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              hormone.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? const Color(0xFF333333) : Colors.white)
                    : const Color(0xFF8E8E93),
              ),
            ),
          );
        },
      ),
    );
  }

  // =======================================================================
  // 换算输入区
  // =======================================================================
  Widget _buildConversionSection() {
    return Column(
      children: [
        _buildInputBlock(
          label: '输入',
          controller: _fromController,
          focusNode: _fromFocus,
          isFocused: _fromFocused,
          unit: _fromUnit,
          onChanged: _onFromChanged,
          onUnitChanged: _onFromUnitChanged,
        ),
        const SizedBox(height: 8),
        Center(
          child: GlassSurface(
            onTap: _swapUnits,
            solidColor: const Color(0xFFE5E5EA),
            borderRadius: 14,
            shadow: false,
            padding: EdgeInsets.zero,
            child: const SizedBox(
              width: 36,
              height: 28,
              child: Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: Color(0xFF6B6B76),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildInputBlock(
          label: '输出',
          controller: _toController,
          focusNode: _toFocus,
          isFocused: _toFocused,
          unit: _toUnit,
          onChanged: _onToChanged,
          onUnitChanged: _onToUnitChanged,
        ),
      ],
    );
  }

  Widget _buildInputBlock({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String unit,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onUnitChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    // 玻璃输入块：液态模式下由 LiquidGlassLens 接管折射/模糊；简约风退化为
    // 实色圆角块（聚焦态用更浅底色区分）。原聚焦粉色辉光在液态模式下由玻璃
    // 材质本身提供层次，不再手写 boxShadow。
    return GlassSurface(
      solidColor: isFocused
          ? (isDark ? const Color(0xFF333338) : const Color(0xFFEBEBED))
          : (isDark ? const Color(0xFF24242C) : const Color(0xFFEDEDF0)),
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8E8E96) : const Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.15,
                  ),
                  decoration: const InputDecoration(
                    hintText: '请输入数值',
                    hintStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF999999),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    isCollapsed: true,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildUnitDropdown(
                currentUnit: unit,
                onChanged: onUnitChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown({
    required String currentUnit,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final units = _selectedHormone.units;

    return PopupMenuButton<String>(
      initialValue: units.any((u) => u.symbol == currentUnit)
          ? currentUnit
          : units.first.symbol,
      offset: const Offset(0, 44),
      color: isDark ? const Color(0xFF24242C) : const Color(0xFFEDEDF0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onChanged,
      itemBuilder: (context) => units.map((u) {
        return PopupMenuItem<String>(
          value: u.symbol,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                u.symbol,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFEDEDF0)
                      : const Color(0xFF333333),
                ),
              ),
              if (u.isCommon) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5A9B8),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      // 单位触发器：GlassSurface(onTap:null) 不抢占手势，PopupMenuButton 的
      // 外层 InkWell 仍可正常接收点击弹出菜单。
      child: GlassSurface(
        solidColor: isDark ? const Color(0xFF333338) : const Color(0xFFE8E8ED),
        borderRadius: 12,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentUnit,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFC7C7CC) : const Color(0xFF6B6B76),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16,
                color:
                    isDark ? const Color(0xFF8E8E96) : const Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // 参考范围卡片 — 全场焦点高亮方案
  // =======================================================================
  Widget _buildReferenceRanges() {
    final matchedRanges = _toResult?.ranges ?? [];
    final visibleRanges =
        _selectedHormone.ranges.where((r) => r.isVisible).toList();

    if (visibleRanges.isEmpty) return const SizedBox.shrink();

    final matchedLabels = matchedRanges.map((r) => r.label).toSet();
    final hasAnyMatch = matchedLabels.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            '参考范围',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
        ),
        ...visibleRanges.map((range) {
          final isMatched = matchedLabels.contains(range.label);
          final convertedRange =
              convertRangeToUnit(range, _toUnit, _selectedHormone);
          return _buildRangeCard(
            range: range,
            isMatched: isMatched,
            hasAnyMatch: hasAnyMatch,
            convertedRange: convertedRange,
          );
        }),
      ],
    );
  }

  Widget _buildRangeCard({
    required HormoneRange range,
    required bool isMatched,
    required bool hasAnyMatch,
    required ({double min, double max})? convertedRange,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _resolveTransFlagPalette(range.iconType);

    // ---- 图标 ----
    final IconData icon;
    switch (range.iconType) {
      case 'male':
        icon = Icons.male_rounded;
        break;
      case 'female':
        icon = Icons.female_rounded;
        break;
      case 'target':
        icon = Icons.my_location_rounded;
        break;
      case 'warning':
        icon = Icons.warning_amber_rounded;
        break;
      default:
        icon = Icons.info_outline_rounded;
    }

    // ---- 范围文本 ----
    final rangeText = convertedRange != null
        ? formatRangeText(
            convertedRange.min,
            convertedRange.max,
            hideMax: range.hideMax,
          )
        : formatRangeText(range.min, range.max, hideMax: range.hideMax);

    // ---- 三态判定 ----
    final bool dimmed = !isMatched && hasAnyMatch;

    // 激活态颜色 — 微着色底 + 强调边框 (Tint & Stroke)
    final Color cardBg = isMatched
        ? palette.tintBg
        : dimmed
            ? (isDark ? const Color(0xFF24242C) : const Color(0xFFEBEBED))
            : (isDark ? const Color(0xFF24242C) : palette.bgNormal);
    final Color contentColor = isMatched
        ? palette.accent
        : (isDark ? const Color(0xFF8E8E96) : const Color(0xFF8E8E93));
    final Color labelColor = isMatched
        ? palette.onAccent
        : dimmed
            ? (isDark ? const Color(0xFF6B6B76) : const Color(0xFF999999))
            : (isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333));
    final Color badgeBg = isMatched
        ? palette.accent.withOpacity(0.12)
        : (isDark ? const Color(0xFF333338) : const Color(0xFFE5E5EA));
    final Color badgeTextColor = isMatched
        ? palette.accent
        : (isDark ? const Color(0xFF8E8E96) : const Color(0xFF999999));

    return AnimatedScale(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      scale: isMatched ? 1.02 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: isMatched ? 14 : 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border:
              isMatched ? Border.all(color: palette.solidBg, width: 2.0) : null,
          boxShadow: isMatched
              ? [
                  BoxShadow(
                    color: palette.solidBg.withOpacity(0.20),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 图标
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isMatched
                    ? palette.accent.withOpacity(0.18)
                    : (isDark
                        ? const Color(0xFF333338)
                        : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isMatched
                    ? palette.accent
                    : (isDark
                        ? const Color(0xFF6B6B76)
                        : const Color(0xFFB0B0B8)),
              ),
            ),
            const SizedBox(width: 14),
            // 标签与描述
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    range.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  if (range.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      range.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: contentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 范围数值
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$rangeText ${convertedRange != null ? _toUnit : range.unit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // 开源致谢
  // =======================================================================
  Widget _buildAttribution() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '换算算法及参考范围数据衍生自 MtF.wiki (CC BY-SA 4.0) 及网络公开经验数据',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }
}

// ===========================================================================
// 跨性别旗帜色彩符号系统
// ===========================================================================

/// 根据 iconType 解析对应的跨旗色彩对
_TransFlagPalette _resolveTransFlagPalette(String? iconType) {
  switch (iconType) {
    case 'female':
    case 'target':
      return _TransFlagPalette.mtf;
    case 'male':
      return _TransFlagPalette.ftm;
    default:
      return _TransFlagPalette.neutral;
  }
}

/// 跨性别旗帜色板
///
/// 三组色彩对，分别对应 MtF / FtM / NB 社群识别色。
/// 每组包含六种颜色：
///   solidBg   — 品牌色完全不透明（用于边框）
///   tintBg    — 品牌色 15% 透明度微着色（命中激活态背景）
///   bgNormal  — 常态微光背景
///   bgMatched — 保留兼容
///   accent    — 主色（图标/数值文字/装饰）
///   onAccent  — 深色（命中标签文字）
class _TransFlagPalette {
  final Color solidBg;
  final Color tintBg;
  final Color bgNormal;
  final Color bgMatched;
  final Color accent;
  final Color onAccent;

  const _TransFlagPalette({
    required this.solidBg,
    required this.tintBg,
    required this.bgNormal,
    required this.bgMatched,
    required this.accent,
    required this.onAccent,
  });

  /// MtF — Pastel Pink (#F5A9B8) 跨性别旗帜粉色
  static const mtf = _TransFlagPalette(
    solidBg: Color(0xFFF5A9B8),
    tintBg: Color(0x26F5A9B8),
    bgNormal: Color(0x14F5A9B8),
    bgMatched: Color(0x29F5A9B8),
    accent: Color(0xFFB86B79),
    onAccent: Color(0xFF9B5A68),
  );

  /// FtM — Pastel Blue (#5BCEFA) 跨性别旗帜蓝色
  static const ftm = _TransFlagPalette(
    solidBg: Color(0xFFF5A9B8),
    tintBg: Color(0x265BCEFA),
    bgNormal: Color(0x145BCEFA),
    bgMatched: Color(0x295BCEFA),
    accent: Color(0xFF3884A0),
    onAccent: Color(0xFF2B6B82),
  );

  /// NB / 过渡 — Off-white 中性色
  static const neutral = _TransFlagPalette(
    solidBg: Color(0xFFC7C7CC),
    tintBg: Color(0xFFEBEBED),
    bgNormal: Color(0xFFEBEBED),
    bgMatched: Color(0xFFDEDEE2),
    accent: Color(0xFF666666),
    onAccent: Color(0xFF555555),
  );
}
