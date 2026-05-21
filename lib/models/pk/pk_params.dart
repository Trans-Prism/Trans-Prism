import 'pk_types.dart';

/// 化合物分子量信息
class CompoundInfo {
  final String name;
  final double mw;
  final SimulatedHormone hormone;
  final double activeMw;

  const CompoundInfo({
    required this.name,
    required this.mw,
    required this.hormone,
    required this.activeMw,
  });

  /// 活性成分换算因子
  double get toActiveFactor => activeMw / mw;
}

/// 雌激素化合物信息
class EsterInfo {
  static const Map<Ester, CompoundInfo> values = {
    Ester.e2: CompoundInfo(
        name: 'Estradiol',
        mw: 272.38,
        hormone: SimulatedHormone.estradiol,
        activeMw: 272.38),
    Ester.eb: CompoundInfo(
        name: 'Estradiol Benzoate',
        mw: 376.50,
        hormone: SimulatedHormone.estradiol,
        activeMw: 272.38),
    Ester.ev: CompoundInfo(
        name: 'Estradiol Valerate',
        mw: 356.50,
        hormone: SimulatedHormone.estradiol,
        activeMw: 272.38),
    Ester.ec: CompoundInfo(
        name: 'Estradiol Cypionate',
        mw: 396.58,
        hormone: SimulatedHormone.estradiol,
        activeMw: 272.38),
    Ester.en: CompoundInfo(
        name: 'Estradiol Enanthate',
        mw: 384.56,
        hormone: SimulatedHormone.estradiol,
        activeMw: 272.38),
  };

  static double toE2Factor(Ester ester) {
    if (ester == Ester.e2) return 1.0;
    return values[Ester.e2]!.mw / values[ester]!.mw;
  }
}

/// 睾酮化合物信息
class TestosteroneEsterInfo {
  static const Map<TestosteroneEster, CompoundInfo> values = {
    TestosteroneEster.t: CompoundInfo(
        name: 'Testosterone',
        mw: 288.42,
        hormone: SimulatedHormone.testosterone,
        activeMw: 288.42),
    TestosteroneEster.tc: CompoundInfo(
        name: 'Testosterone Cypionate',
        mw: 412.61,
        hormone: SimulatedHormone.testosterone,
        activeMw: 288.42),
    TestosteroneEster.te: CompoundInfo(
        name: 'Testosterone Enanthate',
        mw: 400.59,
        hormone: SimulatedHormone.testosterone,
        activeMw: 288.42),
    TestosteroneEster.tu: CompoundInfo(
        name: 'Testosterone Undecanoate',
        mw: 456.70,
        hormone: SimulatedHormone.testosterone,
        activeMw: 288.42),
  };

  static double toTFactor(TestosteroneEster te) {
    if (te == TestosteroneEster.t) return 1.0;
    return values[TestosteroneEster.t]!.mw / values[te]!.mw;
  }
}

/// 核心 PK 参数
class CorePK {
  static const double vdPerKG = 2.0; // L/kg

  // E2 参数
  static const double kClearE2 = 0.41;
  static const double kClearInjectionE2 = 0.041;
  static const double depotK1CorrE2 = 1.0;

  // T 参数
  static const double kClearT = 0.6;
  static const double kClearInjectionT = 0.03;
  static const double depotK1CorrT = 1.0;
  static const double patchReleaseScaleT = 3.5078;

  static double kClear(SimulatedHormone hormone) =>
      hormone == SimulatedHormone.estradiol ? kClearE2 : kClearT;

  static double kClearInjection(SimulatedHormone hormone) =>
      hormone == SimulatedHormone.estradiol
          ? kClearInjectionE2
          : kClearInjectionT;

  static double depotK1Corr(SimulatedHormone hormone) =>
      hormone == SimulatedHormone.estradiol ? depotK1CorrE2 : depotK1CorrT;
}

/// 两库注射 PK 参数
class TwoPartDepotPK {
  static double? fracFast(SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return _e2FracFast[compoundKey];
    }
    return _tFracFast[compoundKey];
  }

  static double? k1Fast(SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return _e2K1Fast[compoundKey];
    }
    return _tK1Fast[compoundKey];
  }

  static double? k1Slow(SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return _e2K1Slow[compoundKey];
    }
    return _tK1Slow[compoundKey];
  }

  static const Map<String, double> _e2FracFast = {
    'eb': 0.90,
    'ev': 0.40,
    'ec': 0.229164549,
    'en': 0.05,
    'e2': 1.0,
  };
  static const Map<String, double> _e2K1Fast = {
    'eb': 0.144,
    'ev': 0.0216,
    'ec': 0.005035046,
    'en': 0.0010,
    'e2': 0,
  };
  static const Map<String, double> _e2K1Slow = {
    'eb': 0.114,
    'ev': 0.0138,
    'ec': 0.004510574,
    'en': 0.0050,
    'e2': 0,
  };

  static const Map<String, double> _tFracFast = {
    'tc': 0.35,
    'te': 0.35,
    'tu': 0.3,
    't': 1.0,
  };
  static const Map<String, double> _tK1Fast = {
    'tc': 0.016,
    'te': 0.022,
    'tu': 0.005,
    't': 0,
  };
  static const Map<String, double> _tK1Slow = {
    'tc': 0.0018,
    'te': 0.0035,
    'tu': 0.001127743154530867,
    't': 0,
  };
}

/// 注射形成分数
class InjectionPK {
  static double? formationFraction(
      SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return _e2FormationFraction[compoundKey];
    }
    return _tFormationFraction[compoundKey];
  }

  static const Map<String, double> _e2FormationFraction = {
    'eb': 0.1092237647,
    'ev': 0.0622582882,
    'ec': 0.117255838,
    'en': 0.12,
    'e2': 1.0,
  };
  static const Map<String, double> _tFormationFraction = {
    'tc': 0.06775603562678995,
    'te': 0.09963018136697789,
    'tu': 0.12940928580278235,
    't': 1.0,
  };
}

/// 酯水解速率
class HydrolysisPK {
  static double? k2(SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return _e2K2[compoundKey];
    }
    return _tK2[compoundKey];
  }

  static const Map<String, double> _e2K2 = {
    'eb': 0.090,
    'ev': 0.070,
    'ec': 0.045,
    'en': 0.015,
    'e2': 0,
  };
  static const Map<String, double> _tK2 = {
    'tc': 0.06,
    'te': 0.12,
    'tu': 0.015,
    't': 0,
  };
}

/// 口服 PK 参数
class OralPK {
  static double kAbs(SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return compoundKey == 'ev' ? 0.05 : 0.32;
    }
    return compoundKey == 'tu' ? 0.2162055136986597 : 0.32;
  }

  static double bioavailability(SimulatedHormone hormone, String compoundKey) {
    if (hormone == SimulatedHormone.estradiol) {
      return 0.03;
    }
    return compoundKey == 'tu' ? 0.02698781505574721 : 0.03;
  }

  static const double kAbsSL = 1.8; // 仅 E2 舌下
}

/// 凝胶 PK 参数
class GelPK {
  static double k1(SimulatedHormone hormone) =>
      hormone == SimulatedHormone.estradiol ? 0.022 : 0.05534590723252352;

  static double F(SimulatedHormone hormone) =>
      hormone == SimulatedHormone.estradiol ? 0.05 : 0.22613930825011333;
}

/// 舌下含服等级参数
class SublingualTierParams {
  final double theta;
  final double holdMinutes;

  const SublingualTierParams({required this.theta, required this.holdMinutes});

  static const Map<SublingualTier, SublingualTierParams> values = {
    SublingualTier.quick: SublingualTierParams(theta: 0.01, holdMinutes: 2),
    SublingualTier.casual: SublingualTierParams(theta: 0.04, holdMinutes: 5),
    SublingualTier.standard: SublingualTierParams(theta: 0.11, holdMinutes: 10),
    SublingualTier.strict: SublingualTierParams(theta: 0.18, holdMinutes: 15),
  };
}

/// 抗雄激素药物 PK 参数（单室口服模型）
///
/// 数据来源及模型说明见 docs/pk_antiandrogen_sources.md
class AntiandrogenPK {
  static double vdPerKG(Antiandrogen aa) {
    switch (aa) {
      case Antiandrogen.cpa:
        return 21.0;
      case Antiandrogen.spironolactone:
        return 10.0;
      case Antiandrogen.canrenone:
        return 10.0;
    }
  }

  static double ka(Antiandrogen aa) {
    switch (aa) {
      case Antiandrogen.cpa:
        return 0.23;
      case Antiandrogen.spironolactone:
        return 0.27;
      case Antiandrogen.canrenone:
        return 0.35;
    }
  }

  static double ke(Antiandrogen aa) {
    switch (aa) {
      case Antiandrogen.cpa:
        return 0.0182;
      case Antiandrogen.spironolactone:
        return 0.042;
      case Antiandrogen.canrenone:
        return 0.042;
    }
  }

  static double bioavailability(Antiandrogen aa) {
    switch (aa) {
      case Antiandrogen.cpa:
        return 1.0;
      case Antiandrogen.spironolactone:
        return 0.73;
      case Antiandrogen.canrenone:
        return 1.0;
    }
  }

  static String displayName(Antiandrogen aa) {
    switch (aa) {
      case Antiandrogen.cpa:
        return '环丙孕酮 (CPA)';
      case Antiandrogen.spironolactone:
        return '螺内酯 → 坎利酮';
      case Antiandrogen.canrenone:
        return '坎利酮 (Canrenone)';
    }
  }
}

/// 解析后的 PK 参数包
class PKParams {
  final double fracFast;
  final double k1Fast;
  final double k1Slow;
  final double k2;
  final double k3;
  final double F;
  final double rateMGh;
  final double fFast;
  final double fSlow;

  const PKParams({
    required this.fracFast,
    required this.k1Fast,
    required this.k1Slow,
    required this.k2,
    required this.k3,
    required this.F,
    this.rateMGh = 0,
    this.fFast = 1.0,
    this.fSlow = 1.0,
  });
}
