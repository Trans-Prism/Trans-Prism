import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bra_calculator.dart';
import '../services/growth_record_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/glass_surface.dart';

/// 罩杯计算器 — 完整 Light/Dark 自适应 · iOS 风格
///
/// 双风格：简约风（实色 Container）/ 毛玻璃（GlassSurface）按当前主题切换。
class BraCalculatorPage extends StatefulWidget {
  const BraCalculatorPage({super.key});

  @override
  State<BraCalculatorPage> createState() => _BraCalculatorPageState();
}

class _BraCalculatorPageState extends State<BraCalculatorPage> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _c4 = TextEditingController();
  final _c5 = TextEditingController();

  BraResult? _result;
  String? _errorMessage;
  bool _calculating = false;

  static const _stepHints = [
    '下胸围（吸气）cm',
    '下胸围（呼气）cm',
    '上胸围（直立）cm',
    '上胸围（45°）cm',
    '上胸围（90°）cm',
  ];

  List<TextEditingController> get _controllers => [_c1, _c2, _c3, _c4, _c5];

  // ---- 当前风格（build 顶部缓存）----
  bool _isLiquid = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final v = double.tryParse(trimmed);
    if (v == null || v < 0) return null;
    return v;
  }

  void _calculate() {
    final v1 = _parseInput(_c1.text);
    final v2 = _parseInput(_c2.text);
    final v3 = _parseInput(_c3.text);
    final v4 = _parseInput(_c4.text);
    final v5 = _parseInput(_c5.text);

    if (v1 == null || v2 == null || v3 == null || v4 == null || v5 == null) {
      setState(() {
        _result = null;
        _errorMessage = '请完整填写 5 项测量数值';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _calculating = true;
    });

    try {
      final result = BraCalculator.calculate(
        underbustRelaxed: v1,
        underbustExhaled: v2,
        overbustStanding: v3,
        overbust45: v4,
        overbust90: v5,
      );

      // 持久化到本地发育记录（GrowthRecord 对象）
      GrowthRecordService.instance.saveRecord(
        GrowthRecord(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          underbustRelaxed: v1,
          underbustExhaled: v2,
          overbustStanding: v3,
          overbust45: v4,
          overbust90: v5,
          result: result,
        ),
      );

      setState(() {
        _result = result;
        _calculating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '计算出错：$e';
        _calculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _isLiquid = GlassTheme.of(context).isEnabled;

    // ── 动态色板 ──
    final scaffoldBg = isDark ? Colors.black : Colors.grey[50]!;
    final cardBg = isDark ? const Color(0xFF24242C) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? Colors.white54 : Colors.black45;
    final tertiaryText =
        isDark ? const Color(0xFF6B6B76) : const Color(0xFF8E8E93);
    final inputFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final hintColor = isDark ? Colors.white54 : Colors.black38;
    final iconColor = isDark ? Colors.white : Colors.black;
    final dividerColor =
        isDark ? const Color(0xFF333338) : const Color(0xFFC6C6C8);
    final buttonBg = isDark ? Colors.white : Colors.black;
    final buttonText = isDark ? Colors.black : Colors.white;
    final brandBlue = const Color(0xFFF5A9B8);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── 顶层 Row：返回键 ↔ 历史记录 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: iconColor, size: 28),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.history_rounded, color: iconColor),
                    tooltip: '发育记录',
                    onPressed: () => _showGrowthHistory(isDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text('罩杯计算器',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black)),
            ),
            const SizedBox(height: 24),

            // ── 5 个输入项 ──
            _inputGroup(
                1,
                _stepTitle('直立放松 · 乳房下缘 ', ' 水平绕量', primaryText,
                    decoration: TextDecoration.underline),
                _c1,
                _stepHints[0],
                inputFill,
                hintColor,
                primaryText),
            const SizedBox(height: 24),
            _inputGroup(
                2,
                Text('呼气后 · 同法再测一次',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: primaryText)),
                _c2,
                _stepHints[1],
                inputFill,
                hintColor,
                primaryText),
            const SizedBox(height: 24),
            _inputGroup(
                3,
                _stepTitle('直立 · 经过乳头 ', ' 水平绕量', primaryText,
                    decoration: TextDecoration.lineThrough),
                _c3,
                _stepHints[2],
                inputFill,
                hintColor,
                primaryText),
            const SizedBox(height: 24),
            _inputGroup(
                4,
                Text('俯身 45° · 绕量胸部',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: primaryText)),
                _c4,
                _stepHints[3],
                inputFill,
                hintColor,
                primaryText),
            const SizedBox(height: 24),
            _inputGroup(
                5,
                Text('鞠躬 90° · 绕量胸部',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: primaryText)),
                _c5,
                _stepHints[4],
                inputFill,
                hintColor,
                primaryText),

            const SizedBox(height: 28),

            // ── 计算按钮（分发）──
            _buildCalculateButton(buttonBg, buttonText),
            const SizedBox(height: 16),

            // ── 错误提示（共用）──
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE57373).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Color(0xFFE57373)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFFE57373)))),
                    ],
                  ),
                ),
              ),

            // ── 结果卡片 —— 分发 ──
            AnimatedSize(
              duration: const Duration(milliseconds: 500),
              curve: Curves.fastLinearToSlowEaseIn,
              alignment: Alignment.topCenter,
              child: _result != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _buildResultCard(
                        _result!,
                        isDark: isDark,
                        cardBg: cardBg,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        tertiaryText: tertiaryText,
                        dividerColor: dividerColor,
                        brandBlue: brandBlue,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '核心算法与测量文案参考自 MtF.wiki (CC BY-SA 4.0) 及网络公开经验数据',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // 步骤标题（两套共用）
  // =======================================================================
  Widget _stepTitle(String prefix, String suffix, Color color,
      {TextDecoration decoration = TextDecoration.none}) {
    return RichText(
        text: TextSpan(children: [
      TextSpan(
          text: prefix,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color,
              decoration: decoration,
              decorationColor: const Color(0xFFF5A9B8),
              decorationThickness: 2.0)),
      TextSpan(
          text: suffix,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: color.withValues(alpha: 0.7))),
    ]));
  }

  // =======================================================================
  // 输入项 —— 分发
  // =======================================================================
  Widget _inputGroup(int step, Widget title, TextEditingController controller,
      String hint, Color inputFill, Color hintColor, Color primaryText) {
    return _isLiquid
        ? _inputGroupLiquid(
            step, title, controller, hint, inputFill, hintColor, primaryText)
        : _inputGroupMinimal(
            step, title, controller, hint, inputFill, hintColor, primaryText);
  }

  Widget _inputGroupMinimal(
      int step,
      Widget title,
      TextEditingController controller,
      String hint,
      Color inputFill,
      Color hintColor,
      Color primaryText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 简约风：实色粉色圆序号。
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0x26FF1493),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$step',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.pinkAccent)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 8),
                // 简约风：实色填充 Container + 简约边框。
                Container(
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF333338)
                          : const Color(0xFFD1D1D6),
                      width: 0.5,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))
                    ],
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(fontSize: 14, color: hintColor),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: primaryText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputGroupLiquid(
      int step,
      Widget title,
      TextEditingController controller,
      String hint,
      Color inputFill,
      Color hintColor,
      Color primaryText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 毛玻璃：GlassSurface 圆形玻璃序号。
          GlassSurface(
            shadow: false,
            borderRadius: 12,
            padding: EdgeInsets.zero,
            solidColor: const Color(0x26FF1493),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Text('$step',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.pinkAccent)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 8),
                // 毛玻璃：GlassSurface 子表面。
                GlassSurface(
                  solidColor: inputFill,
                  borderRadius: 14,
                  shadow: false,
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))
                    ],
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(fontSize: 14, color: hintColor),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: primaryText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // 计算按钮 —— 分发
  // =======================================================================
  Widget _buildCalculateButton(Color buttonBg, Color buttonText) {
    if (_isLiquid) {
      // 毛玻璃：GlassSurface 玻璃按钮 + 品牌色半透叠加。
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: GlassSurface(
            onTap: _calculating ? null : _calculate,
            solidColor: buttonBg,
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: Center(
              child: _calculating
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: buttonText))
                  : Text('开始计算',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: buttonText)),
            ),
          ),
        ),
      );
    }
    // 简约风：实色品牌色按钮。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: buttonBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _calculating ? null : _calculate,
            child: Center(
              child: _calculating
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: buttonText))
                  : Text('开始计算',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: buttonText)),
            ),
          ),
        ),
      ),
    );
  }

  // =======================================================================
  // 结果卡片 —— 分发
  // =======================================================================
  Widget _buildResultCard(
    BraResult result, {
    required bool isDark,
    required Color cardBg,
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
    required Color dividerColor,
    required Color brandBlue,
  }) {
    return _isLiquid
        ? _buildResultCardLiquid(
            result,
            isDark: isDark,
            cardBg: cardBg,
            primaryText: primaryText,
            secondaryText: secondaryText,
            tertiaryText: tertiaryText,
            dividerColor: dividerColor,
            brandBlue: brandBlue,
          )
        : _buildResultCardMinimal(
            result,
            isDark: isDark,
            cardBg: cardBg,
            primaryText: primaryText,
            secondaryText: secondaryText,
            tertiaryText: tertiaryText,
            dividerColor: dividerColor,
            brandBlue: brandBlue,
          );
  }

  Widget _buildResultCardMinimal(
    BraResult result, {
    required bool isDark,
    required Color cardBg,
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
    required Color dividerColor,
    required Color brandBlue,
  }) {
    final privacyBg =
        isDark ? const Color(0xFF24242C) : const Color(0xFFF2F2F7);
    // 简约风：实色卡 + 品牌色标题块 + 深度阴影。
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF333338) : const Color(0xFFD1D1D6),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: _buildResultCardContent(
          result: result,
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          tertiaryText: tertiaryText,
          dividerColor: dividerColor,
          brandBlue: brandBlue,
          privacyBg: privacyBg,
        ),
      ),
    );
  }

  Widget _buildResultCardLiquid(
    BraResult result, {
    required bool isDark,
    required Color cardBg,
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
    required Color dividerColor,
    required Color brandBlue,
  }) {
    final privacyBg =
        isDark ? const Color(0xFF24242C) : const Color(0xFFF2F2F7);
    // 毛玻璃：GlassSurface 卡 + 品牌色折射边。
    return GlassSurface(
      solidColor: cardBg,
      borderColor: result.needsBra ? brandBlue : null,
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: _buildResultCardContent(
        result: result,
        isDark: isDark,
        primaryText: primaryText,
        secondaryText: secondaryText,
        tertiaryText: tertiaryText,
        dividerColor: dividerColor,
        brandBlue: brandBlue,
        privacyBg: privacyBg,
      ),
    );
  }

  /// 结果卡片公共内容（两套共用）。
  Widget _buildResultCardContent({
    required BraResult result,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color tertiaryText,
    required Color dividerColor,
    required Color brandBlue,
    required Color privacyBg,
  }) {
    final needsBra = result.needsBra;
    final sizeDisplay = result.fullSize.isNotEmpty ? result.fullSize : '--';
    return Column(
      children: [
        if (needsBra) ...[
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5A9B8), Color(0xFFF5A9B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
                child: Text(sizeDisplay,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
          ),
          const SizedBox(height: 10),
          Text('中国内衣尺码 (CN)',
              style: TextStyle(fontSize: 12, color: secondaryText)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (result.usSize.isNotEmpty)
                _capsuleTag('俗称  ${result.usSize}', isDark),
              if (result.usSize.isNotEmpty && result.euSize.isNotEmpty)
                const SizedBox(width: 10),
              if (result.euSize.isNotEmpty)
                _capsuleTag('欧洲  ${result.euSize}', isDark),
            ],
          ),
        ] else ...[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF81C784).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.eco_rounded,
                size: 36, color: Color(0xFF81C784)),
          ),
          const SizedBox(height: 10),
          Text(result.message ?? '',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF81C784))),
        ],
        const SizedBox(height: 16),
        Divider(height: 1, thickness: 0.5, color: dividerColor),
        const SizedBox(height: 14),
        _dr('下胸围均值', '${result.underbustAvg.toStringAsFixed(1)} cm',
            primaryText, tertiaryText),
        const SizedBox(height: 8),
        _dr('上胸围均值', '${result.overbustAvg.toStringAsFixed(1)} cm', primaryText,
            tertiaryText),
        const SizedBox(height: 8),
        _dr('胸围差', '${result.difference.toStringAsFixed(1)} cm', primaryText,
            tertiaryText,
            accent: needsBra, accentColor: brandBlue),
        if (needsBra) ...[
          const SizedBox(height: 8),
          _dr('底围（取整）', '${result.bandSize} cm', primaryText, tertiaryText)
        ],
        if (result.message != null && needsBra) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: brandBlue),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(result.message!,
                        style: TextStyle(fontSize: 12, color: brandBlue))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: privacyBg, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: Color(0xFF81C784)),
              SizedBox(width: 8),
              Flexible(
                child: Text('运算及记录均在您的设备本地完成，绝不会收集或上传任何数据。',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E8E93))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dr(String label, String value, Color primaryText, Color tertiaryText,
      {bool accent = false, Color accentColor = const Color(0xFFF5A9B8)}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: tertiaryText)),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: accent ? accentColor : primaryText)),
      ],
    );
  }

  Widget _capsuleTag(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333338) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54)),
    );
  }

  // =======================================================================
  // 发育记录 BottomSheet —— 分发
  // =======================================================================
  Future<void> _showGrowthHistory(bool isDark) async {
    final records = await GrowthRecordService.instance.loadRecords();
    if (!mounted) return;

    final bg = isDark ? Colors.black : Colors.grey[50]!;
    final card = isDark ? const Color(0xFF24242C) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final secondary = isDark ? Colors.white54 : Colors.black45;
    const brandBlue = Color(0xFFF5A9B8);

    if (_isLiquid) {
      // 毛玻璃：GlassSheet 包裹。
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: GlassTheme.modalBarrierColor(context),
        builder: (ctx) => GlassSheet(
          title: Text('发育记录',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: text)),
          child: _buildGrowthHistoryList(
            records: records,
            isDark: isDark,
            card: card,
            text: text,
            secondary: secondary,
            brandBlue: brandBlue,
            useGlass: true,
            setSheetState: (_) {},
          ),
        ),
      );
      return;
    }

    // 简约风：实色 Sheet。
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                                color: secondary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Text('发育记录',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: text)),
                            const Spacer(),
                            if (records.isNotEmpty)
                              _buildClearButton(card, text, secondary,
                                  () async {
                                final confirmed = await _confirmClear(
                                    context, card, text, secondary);
                                if (confirmed == true) {
                                  await GrowthRecordService.instance.clearAll();
                                  setSheetState(() {});
                                }
                              }),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildGrowthHistoryList(
                          records: records,
                          isDark: isDark,
                          card: card,
                          text: text,
                          secondary: secondary,
                          brandBlue: brandBlue,
                          useGlass: false,
                          setSheetState: setSheetState,
                          scrollController: scrollController,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildClearButton(
      Color card, Color text, Color secondary, VoidCallback onPressed) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Icon(Icons.delete_sweep_outlined, size: 22, color: secondary),
    );
  }

  Future<bool?> _confirmClear(
      BuildContext context, Color card, Color text, Color secondary) {
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: card,
        title: Text('确认清除', style: TextStyle(color: text)),
        content:
            Text('清除后无法恢复，确定要删除所有发育记录吗？', style: TextStyle(color: secondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child:
                  const Text('取消', style: TextStyle(color: Color(0xFFF5A9B8)))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('确认清除',
                  style: TextStyle(color: Color(0xFFE57373)))),
        ],
      ),
    );
  }

  /// 发育记录列表（两套共用，useGlass 控制列表项材质）。
  Widget _buildGrowthHistoryList({
    required List records,
    required bool isDark,
    required Color card,
    required Color text,
    required Color secondary,
    required Color brandBlue,
    required bool useGlass,
    required void Function(VoidCallback) setSheetState,
    ScrollController? scrollController,
  }) {
    if (records.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 48, color: secondary),
        const SizedBox(height: 12),
        Text('还没有测量记录\n开始计算后会自动保存',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: secondary)),
      ]));
    }
    return StatefulBuilder(
      builder: (context, ss) {
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final rec = records[index];
            final child = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: Text(
                          rec.result.fullSize.isNotEmpty
                              ? rec.result.fullSize
                              : '--',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF5A9B8)))),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(rec.formattedDate,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: text)),
                      const SizedBox(height: 2),
                      Text(
                          '下 ${rec.underbustRelaxed.toStringAsFixed(1)}/${rec.underbustExhaled.toStringAsFixed(1)}  ·  '
                          '上 ${rec.overbustStanding.toStringAsFixed(1)}/${rec.overbust45.toStringAsFixed(1)}/${rec.overbust90.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 12, color: secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ])),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(Icons.delete_outline, size: 20, color: secondary),
                  onPressed: () async {
                    await GrowthRecordService.instance
                        .deleteRecord(rec.timestamp);
                    ss(() {});
                  },
                ),
              ]),
            );
            if (useGlass) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassSurface(
                  solidColor: card,
                  borderRadius: 14,
                  shadow: false,
                  padding: EdgeInsets.zero,
                  child: child,
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 1),
              color: card,
              child: child,
            );
          },
        );
      },
    );
  }
}
