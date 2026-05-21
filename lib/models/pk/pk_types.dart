/// 模拟激素/药物类型
enum SimulatedHormone {
  estradiol,
  testosterone,
  antiandrogen;

  /// 默认浓度单位
  String get concentrationUnit {
    switch (this) {
      case estradiol:
        return 'pg/mL';
      case testosterone:
        return 'ng/dL';
      case antiandrogen:
        return 'ng/mL';
    }
  }

  /// 浓度换算比例 (amount_MG → concentration)
  double get concentrationScale {
    switch (this) {
      case estradiol:
        return 1e9;
      case testosterone:
        return 1e8;
      case antiandrogen:
        return 1e6;
    }
  }

  /// Chart 默认颜色
  int get chartColor {
    switch (this) {
      case estradiol:
        return 0xFFF5A9B8;
      case testosterone:
        return 0xFF4A90D9;
      case antiandrogen:
        return 0xFF7B68EE;
    }
  }
}

/// 给药途径
enum DoseRoute {
  injection,
  patchApply,
  patchRemove,
  gel,
  oral,
  sublingual;
}

/// 雌激素种类
enum Ester {
  e2,
  eb,
  ev,
  ec,
  en;
}

/// 抗雄激素药物类型
enum Antiandrogen {
  cpa,
  spironolactone,
  canrenone,
}

/// 睾酮酯类
enum TestosteroneEster {
  t,
  tc,
  te,
  tu;
}

/// 附加参数字段
enum ExtraKey {
  concentrationMGmL,
  areaCM2,
  releaseRateUGPerDay,
  sublingualTheta,
  sublingualTier,
}

/// 舌下含服等级
enum SublingualTier {
  quick,
  casual,
  standard,
  strict;
}

/// 单次给药事件
class DoseEvent {
  final String id;
  final DoseRoute route;
  final double timeH; // 自 epoch 的小时数
  final double doseMG; // 活性成分等效剂量 (mg)
  final SimulatedHormone hormone;
  final Ester? ester; // 雌激素类
  final TestosteroneEster? tEster; // 睾酮类
  final Antiandrogen? antiandrogen; // 抗雄激素类
  final Map<ExtraKey, double> extras;

  const DoseEvent({
    required this.id,
    required this.route,
    required this.timeH,
    required this.doseMG,
    required this.hormone,
    this.ester,
    this.tEster,
    this.antiandrogen,
    this.extras = const {},
  });

  /// 获取化合物标识字符串
  String get compoundKey {
    if (ester != null) return ester!.name;
    if (tEster != null) return tEster!.name;
    if (antiandrogen != null) return antiandrogen!.name;
    return 'unknown';
  }

  DoseEvent copyWith({
    String? id,
    DoseRoute? route,
    double? timeH,
    double? doseMG,
    SimulatedHormone? hormone,
    Ester? ester,
    TestosteroneEster? tEster,
    Antiandrogen? antiandrogen,
    Map<ExtraKey, double>? extras,
  }) {
    return DoseEvent(
      id: id ?? this.id,
      route: route ?? this.route,
      timeH: timeH ?? this.timeH,
      doseMG: doseMG ?? this.doseMG,
      hormone: hormone ?? this.hormone,
      ester: ester ?? this.ester,
      tEster: tEster ?? this.tEster,
      antiandrogen: antiandrogen ?? this.antiandrogen,
      extras: extras ?? this.extras,
    );
  }
}

/// 模拟结果
class SimulationResult {
  final List<double> timeH;
  final List<double> concentrations;
  final double auc;
  final SimulatedHormone hormone;

  const SimulationResult({
    required this.timeH,
    required this.concentrations,
    required this.auc,
    required this.hormone,
  });

  List<double> get concPGmL =>
      hormone == SimulatedHormone.estradiol ? concentrations : [];
  List<double> get concNgDL =>
      hormone == SimulatedHormone.testosterone ? concentrations : [];
}
