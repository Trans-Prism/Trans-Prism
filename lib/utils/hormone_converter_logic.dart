/// 激素单位换算核心逻辑
///
/// 换算算法及参考范围数据衍生自 mtf.wiki (CC BY-NC-SA 4.0)
/// 原始项目: https://github.com/project-trans/Next-MtF-wiki
///
/// 本文件仅包含纯数据与纯函数，不依赖任何 Flutter/UI 代码。
library;

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// 类型定义
// ---------------------------------------------------------------------------

/// 激素单位描述
class HormoneUnit {
  final String name; // 中文名，如 "皮克/毫升"
  final String symbol; // 符号，如 "pg/mL"
  final double multiplier; // 转换为基础单位的乘数
  final bool isCommon; // 是否为常用单位

  const HormoneUnit({
    required this.name,
    required this.symbol,
    required this.multiplier,
    this.isCommon = false,
  });
}

/// 参考范围来源
class RangeSource {
  final String name;
  final String url;

  const RangeSource({required this.name, required this.url});
}

/// 激素参考范围
class HormoneRange {
  final String label;
  final double min;
  final double max;
  final String unit;
  final String description;
  final String color; // 'info' | 'success' | 'warning' | 'error'
  final String? iconType;
  final RangeSource? source;
  final bool isVisible;
  final bool hideMax;

  const HormoneRange({
    required this.label,
    required this.min,
    required this.max,
    required this.unit,
    this.description = '',
    this.color = 'info',
    this.iconType,
    this.source,
    this.isVisible = true,
    this.hideMax = false,
  });
}

/// 激素类型定义
class HormoneType {
  final String id;
  final String name;
  final String baseUnit;
  final double? molecularWeight;
  final List<HormoneUnit> units;
  final List<HormoneRange> ranges;

  const HormoneType({
    required this.id,
    required this.name,
    required this.baseUnit,
    this.molecularWeight,
    required this.units,
    required this.ranges,
  });
}

/// 换算结果
class ConversionResult {
  final double value;
  final String unit;
  final bool isValid;
  final List<HormoneRange> ranges;

  const ConversionResult({
    required this.value,
    required this.unit,
    this.isValid = true,
    this.ranges = const [],
  });

  static const invalid = ConversionResult(value: 0, unit: '', isValid: false);
}

// ---------------------------------------------------------------------------
// 单位生成算法（与 mtf.wiki 完全一致）
// ---------------------------------------------------------------------------

/// 创建标准质量浓度和摩尔浓度单位
List<HormoneUnit> _createStandardMassAndMolarUnits(
  double molecularWeight,
  String baseUnit,
) {
  const massPrefixes = <String, _PrefixData>{
    'p': _PrefixData(name: '皮', factor: 1e-12),
    'n': _PrefixData(name: '纳', factor: 1e-9),
    'μ': _PrefixData(name: '微', factor: 1e-6),
  };
  const molarPrefixes = <String, _PrefixData>{
    'p': _PrefixData(name: '皮', factor: 1e-12),
    'n': _PrefixData(name: '纳', factor: 1e-9),
  };
  const volumes = <String, _PrefixData>{
    'mL': _PrefixData(name: '毫升', factor: 1e-3),
    'dL': _PrefixData(name: '分升', factor: 1e-1),
    'L': _PrefixData(name: '升', factor: 1),
  };

  final factorsToGL = <String, double>{};

  for (final p in massPrefixes.entries) {
    for (final v in volumes.entries) {
      final symbol = '${p.key}g/${v.key}';
      factorsToGL[symbol] = p.value.factor / v.value.factor;
    }
  }
  for (final p in molarPrefixes.entries) {
    for (final v in volumes.entries) {
      final symbol = '${p.key}mol/${v.key}';
      factorsToGL[symbol] = (p.value.factor * molecularWeight) / v.value.factor;
    }
  }

  final baseUnitFactorToGL = factorsToGL[baseUnit];
  if (baseUnitFactorToGL == null) {
    throw ArgumentError(
        'Base unit $baseUnit is not a standard mass/molar unit.');
  }

  final units = <HormoneUnit>[];
  for (final mp in massPrefixes.entries) {
    for (final vp in volumes.entries) {
      final symbol = '${mp.key}g/${vp.key}';
      units.add(HormoneUnit(
        name: '${mp.value.name}克/${vp.value.name}',
        symbol: symbol,
        multiplier: factorsToGL[symbol]! / baseUnitFactorToGL,
      ));
    }
  }
  for (final mp in molarPrefixes.entries) {
    for (final vp in volumes.entries) {
      final symbol = '${mp.key}mol/${vp.key}';
      units.add(HormoneUnit(
        name: '${mp.value.name}摩尔/${vp.value.name}',
        symbol: symbol,
        multiplier: factorsToGL[symbol]! / baseUnitFactorToGL,
      ));
    }
  }
  return units;
}

/// 从 IU 国际单位创建质量浓度单位
List<HormoneUnit> _createMassUnitsFromIU(double pgPerBaseUnit) {
  const massPrefixes = <String, _PrefixData>{
    'p': _PrefixData(name: '皮', factor: 1),
    'n': _PrefixData(name: '纳', factor: 1e3),
    'μ': _PrefixData(name: '微', factor: 1e6),
  };
  const volumes = <String, _PrefixData>{
    'mL': _PrefixData(name: '毫升', factor: 1),
    'dL': _PrefixData(name: '分升', factor: 100),
    'L': _PrefixData(name: '升', factor: 1000),
  };

  final baseMultiplier = 1 / pgPerBaseUnit;

  final units = <HormoneUnit>[];
  for (final mp in massPrefixes.entries) {
    for (final vp in volumes.entries) {
      units.add(HormoneUnit(
        name: '${mp.value.name}克/${vp.value.name}',
        symbol: '${mp.key}g/${vp.key}',
        multiplier: (mp.value.factor / vp.value.factor) * baseMultiplier,
      ));
    }
  }
  return units;
}

/// 标记常用单位
List<HormoneUnit> _markCommon(
  List<HormoneUnit> units,
  Set<String> commonSymbols,
) {
  return units
      .map((u) => HormoneUnit(
            name: u.name,
            symbol: u.symbol,
            multiplier: u.multiplier,
            isCommon: commonSymbols.contains(u.symbol),
          ))
      .toList();
}

class _PrefixData {
  final String name;
  final double factor;
  const _PrefixData({required this.name, required this.factor});
}

// ---------------------------------------------------------------------------
// 激素数据定义
// ---------------------------------------------------------------------------

/// 所有激素类型列表
final List<HormoneType> hormones = [
  // ---- 雌二醇 (E2) ----
  HormoneType(
    id: 'estradiol',
    name: '雌二醇 (E2)',
    baseUnit: 'pg/mL',
    molecularWeight: 272.38,
    units: _markCommon(
      _createStandardMassAndMolarUnits(272.38, 'pg/mL'),
      {'pg/mL', 'ng/L', 'pmol/L'},
    ),
    ranges: const [
      HormoneRange(
        label: '男性参考范围',
        min: 8,
        max: 35,
        unit: 'pg/mL',
        color: 'info',
        iconType: 'male',
        source: RangeSource(
          name: 'HRT 综述 - MtF.wiki',
          url: '/zh-cn/docs/medicine/overview',
        ),
      ),
      HormoneRange(
        label: '非针剂女性向 GAHT 目标范围',
        min: 100,
        max: 200,
        unit: 'pg/mL',
        color: 'success',
        iconType: 'target',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '女性卵泡期',
        min: 30,
        max: 100,
        unit: 'pg/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '女性黄体期',
        min: 70,
        max: 300,
        unit: 'pg/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
    ],
  ),

  // ---- 睾酮 (T) ----
  HormoneType(
    id: 'testosterone',
    name: '睾酮 (T)',
    baseUnit: 'ng/dL',
    molecularWeight: 288.43,
    units: _markCommon(
      _createStandardMassAndMolarUnits(288.43, 'ng/dL'),
      {'ng/dL', 'μg/L', 'ng/mL', 'nmol/L'},
    ),
    ranges: const [
      HormoneRange(
        label: '男性参考范围',
        min: 2.64,
        max: 9.16,
        unit: 'ng/mL',
        color: 'info',
        iconType: 'male',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '女性参考范围',
        min: 0.1,
        max: 0.55,
        unit: 'ng/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '女性向 GAHT 目标范围',
        min: 0,
        max: 0.55,
        unit: 'ng/mL',
        color: 'success',
        iconType: 'target',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/hrt',
        ),
      ),
    ],
  ),

  // ---- 泌乳素 (PRL) ----
  HormoneType(
    id: 'prolactin',
    name: '泌乳素 (PRL)',
    baseUnit: 'ng/mL',
    molecularWeight: 23000,
    units: () {
      final base = _createStandardMassAndMolarUnits(23000, 'ng/mL');
      final processed = _markCommon(base, {'ng/mL', 'μg/L'});
      return [
        ...processed,
        const HormoneUnit(
            name: '毫国际单位/毫升',
            symbol: 'mIU/mL',
            multiplier: 47.17,
            isCommon: true),
        const HormoneUnit(
            name: '毫国际单位/升',
            symbol: 'mIU/L',
            multiplier: 0.04717,
            isCommon: true),
        const HormoneUnit(
            name: '微国际单位/毫升',
            symbol: 'μIU/mL',
            multiplier: 0.04717,
            isCommon: true),
        const HormoneUnit(
            name: '微国际单位/升', symbol: 'μIU/L', multiplier: 0.00004717),
      ];
    }(),
    ranges: const [
      HormoneRange(
        label: '女性参考范围',
        min: 4.79,
        max: 23.3,
        unit: 'ng/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '显著升高',
        min: 69.9,
        max: 698.99,
        unit: 'ng/mL',
        description: '需要注意',
        color: 'warning',
        iconType: 'warning',
        hideMax: true,
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
    ],
  ),

  // ---- 孕酮 (P4) ----
  HormoneType(
    id: 'progesterone',
    name: '孕酮 (P4)',
    baseUnit: 'ng/mL',
    molecularWeight: 314.46,
    units: _markCommon(
      _createStandardMassAndMolarUnits(314.46, 'ng/mL'),
      {'ng/mL', 'μg/L', 'pmol/mL', 'nmol/L'},
    ),
    ranges: const [],
  ),

  // ---- 卵泡刺激素 (FSH) ----
  HormoneType(
    id: 'fsh',
    name: '卵泡刺激素 (FSH)',
    baseUnit: 'mIU/mL',
    units: [
      const HormoneUnit(
          name: '毫国际单位/毫升', symbol: 'mIU/mL', multiplier: 1, isCommon: true),
      const HormoneUnit(
          name: '国际单位/升', symbol: 'IU/L', multiplier: 1, isCommon: true),
      const HormoneUnit(name: '毫国际单位/升', symbol: 'mIU/L', multiplier: 0.001),
      ..._createMassUnitsFromIU(113880),
    ],
    ranges: const [
      HormoneRange(
        label: '女性卵泡期',
        min: 1.8,
        max: 11.2,
        unit: 'mIU/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '绝经后女性',
        min: 30,
        max: 120,
        unit: 'mIU/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
    ],
  ),

  // ---- 促黄体素 (LH) ----
  HormoneType(
    id: 'lh',
    name: '促黄体素 (LH)',
    baseUnit: 'mIU/mL',
    units: [
      const HormoneUnit(
          name: '毫国际单位/毫升', symbol: 'mIU/mL', multiplier: 1, isCommon: true),
      const HormoneUnit(
          name: '国际单位/升', symbol: 'IU/L', multiplier: 1, isCommon: true),
      const HormoneUnit(name: '毫国际单位/升', symbol: 'mIU/L', multiplier: 0.001),
      ..._createMassUnitsFromIU(46.56),
    ],
    ranges: const [
      HormoneRange(
        label: '女性卵泡期',
        min: 2.0,
        max: 9.0,
        unit: 'mIU/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '女性黄体期',
        min: 2.0,
        max: 11.0,
        unit: 'mIU/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
      HormoneRange(
        label: '绝经后女性',
        min: 20.0,
        max: 70.0,
        unit: 'mIU/mL',
        color: 'info',
        iconType: 'female',
        source: RangeSource(
          name: '治疗期间的监测 - MtF.wiki',
          url: '/zh-cn/docs/medicine/monitoring',
        ),
      ),
    ],
  ),
];

/// 默认激素 ID
const defaultHormoneId = 'estradiol';

// ---------------------------------------------------------------------------
// 核心换算函数
// ---------------------------------------------------------------------------

/// 根据 ID 查找激素类型
HormoneType? getHormoneById(String id) {
  return hormones.cast<HormoneType?>().firstWhere(
        (h) => h!.id == id,
        orElse: () => null,
      );
}

/// 根据符号查找单位
HormoneUnit? getUnitBySymbol(HormoneType hormone, String symbol) {
  return hormone.units.cast<HormoneUnit?>().firstWhere(
        (u) => u!.symbol == symbol,
        orElse: () => null,
      );
}

/// 执行单位转换（纯数值运算）
///
/// 转换逻辑：先换算为基准单位，再从基准单位换算到目标单位。
/// 公式：result = value * fromUnit.multiplier / toUnit.multiplier
double convertHormoneValue(
  double value,
  String fromUnit,
  String toUnit,
  HormoneType hormone,
) {
  final from = getUnitBySymbol(hormone, fromUnit);
  final to = getUnitBySymbol(hormone, toUnit);

  if (from == null || to == null) {
    throw ArgumentError('Invalid unit: $fromUnit or $toUnit');
  }

  final baseValue = value * from.multiplier;
  return baseValue / to.multiplier;
}

/// 检查数值落在哪些参考范围内
List<HormoneRange> checkValueRanges(
  double value,
  String unit,
  HormoneType hormone,
) {
  final unitInfo = getUnitBySymbol(hormone, unit);
  if (unitInfo == null) return [];

  final baseValue = value * unitInfo.multiplier;

  return hormone.ranges.where((range) {
    final rangeUnitInfo = getUnitBySymbol(hormone, range.unit);
    if (rangeUnitInfo == null) return false;

    final rangeMinBase = range.min * rangeUnitInfo.multiplier;
    final rangeMaxBase = range.max * rangeUnitInfo.multiplier;

    return baseValue >= rangeMinBase && baseValue <= rangeMaxBase;
  }).toList();
}

/// 执行完整转换并返回结果
ConversionResult performConversion(
  String inputValue,
  String fromUnit,
  String toUnit,
  String hormoneId,
) {
  final hormone = getHormoneById(hormoneId);
  if (hormone == null) return ConversionResult.invalid;

  final numValue = double.tryParse(inputValue);
  if (numValue == null || numValue < 0) return ConversionResult.invalid;

  try {
    final convertedValue =
        convertHormoneValue(numValue, fromUnit, toUnit, hormone);
    final ranges = checkValueRanges(convertedValue, toUnit, hormone);

    return ConversionResult(
      value: convertedValue,
      unit: toUnit,
      isValid: true,
      ranges: ranges,
    );
  } catch (_) {
    return ConversionResult.invalid;
  }
}

/// 将参考范围转换到指定单位
({double min, double max})? convertRangeToUnit(
  HormoneRange range,
  String targetUnit,
  HormoneType hormone,
) {
  try {
    final convertedMin =
        convertHormoneValue(range.min, range.unit, targetUnit, hormone);
    final convertedMax = range.max == double.infinity
        ? double.infinity
        : convertHormoneValue(range.max, range.unit, targetUnit, hormone);
    return (min: convertedMin, max: convertedMax);
  } catch (_) {
    return null;
  }
}

/// 检查两个单位是否等价（multiplier 相同，考虑浮点精度）
bool areUnitsEquivalent(
  HormoneType hormone,
  String unit1,
  String unit2,
) {
  final u1 = getUnitBySymbol(hormone, unit1);
  final u2 = getUnitBySymbol(hormone, unit2);
  if (u1 == null || u2 == null) return false;
  return (u1.multiplier - u2.multiplier).abs() < 1e-10;
}

// ---------------------------------------------------------------------------
// 数值格式化
// ---------------------------------------------------------------------------

/// 格式化数值显示（智能精度，最多 4 位有效数字）
String formatValue(double value) {
  if (value == 0) return '0';
  if (value.isNaN || value.isInfinite) return value.toString();

  // 使用有效数字格式化：最多 4 位有效数字
  if (value >= 1000) {
    return value.toStringAsFixed(1);
  }
  if (value >= 100) {
    return value.toStringAsFixed(1);
  }
  if (value >= 10) {
    return value.toStringAsFixed(2);
  }
  if (value >= 1) {
    return value.toStringAsFixed(3);
  }
  if (value >= 0.01) {
    // 0.01 ~ 1: 最多 4 位小数
    final str = value.toStringAsFixed(5);
    // 去除尾部零
    return str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  // 很小的小数：用科学记数法或保留有效数字
  final exp = (math.log(value.abs()) / math.ln10).floor();
  final significand = value / _pow10(-exp);
  return '${significand.toStringAsFixed(2)}e$exp';
}

double _pow10(int n) {
  double result = 1;
  if (n > 0) {
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
  } else {
    for (int i = 0; i < -n; i++) {
      result /= 10;
    }
  }
  return result;
}

/// 格式化参考范围显示文本
String formatRangeText(double min, double max, {bool hideMax = false}) {
  if (max == double.infinity || hideMax) {
    return '> ${formatValue(min)}';
  }
  return '${formatValue(min)} - ${formatValue(max)}';
}

/// 获取激素的默认常用单位组合（用于初始化界面）
({String fromUnit, String toUnit}) getDefaultUnits(HormoneType hormone) {
  final commonUnits = hormone.units.where((u) => u.isCommon).toList();

  if (commonUnits.length >= 2) {
    // 找两个不等价的常用单位
    final fromUnit = commonUnits[0];
    for (int i = 1; i < commonUnits.length; i++) {
      if (!areUnitsEquivalent(
          hormone, fromUnit.symbol, commonUnits[i].symbol)) {
        return (fromUnit: fromUnit.symbol, toUnit: commonUnits[i].symbol);
      }
    }
    return (fromUnit: fromUnit.symbol, toUnit: commonUnits[1].symbol);
  } else if (commonUnits.length == 1) {
    // 只有一个常用单位，从所有单位中找一个不等价的
    for (final u in hormone.units) {
      if (!areUnitsEquivalent(hormone, commonUnits[0].symbol, u.symbol)) {
        return (fromUnit: commonUnits[0].symbol, toUnit: u.symbol);
      }
    }
    // 没有不等价的，使用前两个
    return (
      fromUnit: commonUnits[0].symbol,
      toUnit: hormone.units.length > 1
          ? hormone.units[1].symbol
          : commonUnits[0].symbol,
    );
  } else {
    // 没有常用单位
    if (hormone.units.length >= 2) {
      return (
        fromUnit: hormone.units[0].symbol,
        toUnit: hormone.units[1].symbol
      );
    }
    return (fromUnit: hormone.units[0].symbol, toUnit: hormone.units[0].symbol);
  }
}
