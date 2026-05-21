import 'dart:math';
import 'pk_types.dart';
import 'pk_params.dart';

/// 参数解析器：将 DoseEvent 映射为 PKParams
PKParams resolveParams(DoseEvent event) {
  final hormone = event.hormone;
  final compoundKey = event.compoundKey;
  final route = event.route;

  final isInjection = route == DoseRoute.injection;
  final k3 =
      isInjection ? CorePK.kClearInjection(hormone) : CorePK.kClear(hormone);

  // 抗雄激素：单室口服模型
  if (hormone == SimulatedHormone.antiandrogen && event.antiandrogen != null) {
    final aa = event.antiandrogen!;
    return PKParams(
      fracFast: 1.0,
      k1Fast: AntiandrogenPK.ka(aa),
      k1Slow: 0,
      k2: 0,
      k3: AntiandrogenPK.ke(aa),
      F: AntiandrogenPK.bioavailability(aa),
      fFast: AntiandrogenPK.bioavailability(aa),
      fSlow: 0,
    );
  }

  switch (route) {
    case DoseRoute.injection:
      {
        final k1corr = CorePK.depotK1Corr(hormone);
        final k1Fast =
            (TwoPartDepotPK.k1Fast(hormone, compoundKey) ?? 0) * k1corr;
        final k1Slow =
            (TwoPartDepotPK.k1Slow(hormone, compoundKey) ?? 0) * k1corr;
        final fracFast = TwoPartDepotPK.fracFast(hormone, compoundKey) ?? 1.0;
        final form =
            InjectionPK.formationFraction(hormone, compoundKey) ?? 0.08;

        // 活性成分换算
        double toActive = 1.0;
        if (hormone == SimulatedHormone.estradiol && event.ester != null) {
          toActive = EsterInfo.toE2Factor(event.ester!);
        } else if (hormone == SimulatedHormone.testosterone &&
            event.tEster != null) {
          toActive = TestosteroneEsterInfo.toTFactor(event.tEster!);
        }
        final F = form * toActive;

        return PKParams(
          fracFast: fracFast,
          k1Fast: k1Fast,
          k1Slow: k1Slow,
          k2: HydrolysisPK.k2(hormone, compoundKey) ?? 0,
          k3: k3,
          F: F,
          fFast: F,
          fSlow: F,
        );
      }
    case DoseRoute.patchApply:
      {
        if (event.extras.containsKey(ExtraKey.releaseRateUGPerDay)) {
          final rateMGh =
              (event.extras[ExtraKey.releaseRateUGPerDay] ?? 0) / 24000.0;
          final scale = hormone == SimulatedHormone.testosterone
              ? CorePK.patchReleaseScaleT
              : 1.0;
          return PKParams(
            fracFast: 1.0,
            k1Fast: 0,
            k1Slow: 0,
            k2: 0,
            k3: k3,
            F: scale,
            rateMGh: rateMGh,
            fFast: scale,
            fSlow: scale,
          );
        } else {
          final k1Value =
              hormone == SimulatedHormone.testosterone ? 0.0051 : 0.0075;
          return PKParams(
            fracFast: 1.0,
            k1Fast: k1Value,
            k1Slow: 0,
            k2: 0,
            k3: k3,
            F: 1.0,
            fFast: 1.0,
            fSlow: 1.0,
          );
        }
      }
    case DoseRoute.gel:
      {
        return PKParams(
          fracFast: 1.0,
          k1Fast: GelPK.k1(hormone),
          k1Slow: 0,
          k2: 0,
          k3: k3,
          F: GelPK.F(hormone),
          fFast: GelPK.F(hormone),
          fSlow: GelPK.F(hormone),
        );
      }
    case DoseRoute.oral:
      {
        final k1Value = OralPK.kAbs(hormone, compoundKey);
        final k2Value = HydrolysisPK.k2(hormone, compoundKey) ?? 0.0;
        final bio = OralPK.bioavailability(hormone, compoundKey);
        return PKParams(
          fracFast: 1.0,
          k1Fast: k1Value,
          k1Slow: 0,
          k2: k2Value,
          k3: k3,
          F: bio,
          fFast: bio,
          fSlow: bio,
        );
      }
    case DoseRoute.sublingual:
      {
        // 仅 E2 支持舌下，T 不支持
        if (hormone != SimulatedHormone.estradiol) {
          return PKParams(
            fracFast: 0,
            k1Fast: 0,
            k1Slow: 0,
            k2: 0,
            k3: k3,
            F: 0,
            fFast: 0,
            fSlow: 0,
          );
        }

        double theta = 0.11;
        if (event.extras.containsKey(ExtraKey.sublingualTheta)) {
          theta = max(0.0, min(1.0, event.extras[ExtraKey.sublingualTheta]!));
        } else if (event.extras.containsKey(ExtraKey.sublingualTier)) {
          final tierIdx = event.extras[ExtraKey.sublingualTier]!.round();
          const tierOrder = [
            SublingualTier.quick,
            SublingualTier.casual,
            SublingualTier.standard,
            SublingualTier.strict,
          ];
          final tierKey = (tierIdx >= 0 && tierIdx < tierOrder.length)
              ? tierOrder[tierIdx]
              : SublingualTier.standard;
          theta = SublingualTierParams.values[tierKey]?.theta ?? 0.11;
        }

        final k1Fast = OralPK.kAbsSL;
        final k1Slow = OralPK.kAbs(hormone, compoundKey);
        final k2Value = HydrolysisPK.k2(hormone, compoundKey) ?? 0.0;

        return PKParams(
          fracFast: theta,
          k1Fast: k1Fast,
          k1Slow: k1Slow,
          k2: k2Value,
          k3: k3,
          F: 1.0,
          fFast: 1.0,
          fSlow: OralPK.bioavailability(hormone, compoundKey),
        );
      }
    case DoseRoute.patchRemove:
      return PKParams(
        fracFast: 0,
        k1Fast: 0,
        k1Slow: 0,
        k2: 0,
        k3: k3,
        F: 0,
        fFast: 0,
        fSlow: 0,
      );
  }
}

// ==================== 数学模型 ====================

double _analytic3C(
    double tau, double doseMG, double F, double k1, double k2, double k3) {
  if (k1 <= 0 || doseMG <= 0 || F <= 0) return 0;

  final k1k2 = k1 - k2;
  final k1k3 = k1 - k3;
  final k2k3 = k2 - k3;

  if (k1k2.abs() < 1e-9 || k1k3.abs() < 1e-9 || k2k3.abs() < 1e-9) return 0;

  final term1 = exp(-k1 * tau) / (k1k2 * k1k3);
  final term2 = exp(-k2 * tau) / (-k1k2 * k2k3);
  final term3 = exp(-k3 * tau) / (k1k3 * k2k3);

  return doseMG * F * k1 * k2 * (term1 + term2 + term3);
}

double _oneCompAmount(
    double tau, double doseMG, double F, double ka, double ke) {
  if (tau < 0 || doseMG <= 0 || ka <= 0) return 0;
  if ((ka - ke).abs() < 1e-9) {
    return doseMG * F * ka * tau * exp(-ke * tau);
  }
  return doseMG * F * ka / (ka - ke) * (exp(-ke * tau) - exp(-ka * tau));
}

double _injAmount(double tau, double doseMG, PKParams p) {
  final doseFast = doseMG * p.fracFast;
  final doseSlow = doseMG * (1.0 - p.fracFast);
  return _analytic3C(tau, doseFast, p.F, p.k1Fast, p.k2, p.k3) +
      _analytic3C(tau, doseSlow, p.F, p.k1Slow, p.k2, p.k3);
}

double _patchAmount(double tau, double doseMG, double wearH, PKParams p) {
  if (p.rateMGh > 0) {
    final effectiveRate = p.rateMGh * p.F;
    if (tau <= wearH) {
      return effectiveRate / p.k3 * (1 - exp(-p.k3 * tau));
    } else {
      final amtAtRemoval = effectiveRate / p.k3 * (1 - exp(-p.k3 * wearH));
      return amtAtRemoval * exp(-p.k3 * (tau - wearH));
    }
  }
  final amtUnderPatch = _oneCompAmount(tau, doseMG, p.F, p.k1Fast, p.k3);
  if (tau > wearH) {
    final amtAtRemoval = _oneCompAmount(wearH, doseMG, p.F, p.k1Fast, p.k3);
    return amtAtRemoval * exp(-p.k3 * (tau - wearH));
  }
  return amtUnderPatch;
}

double _sublingualAmount(double tau, double doseMG, PKParams p) {
  final doseF = doseMG * p.fracFast;
  final doseS = doseMG * (1.0 - p.fracFast);

  final fastAmount = p.k2 > 0
      ? _analytic3C(tau, doseF, p.fFast, p.k1Fast, p.k2, p.k3)
      : _oneCompAmount(tau, doseF, p.fFast, p.k1Fast, p.k3);

  final slowAmount = _oneCompAmount(tau, doseS, p.fSlow, p.k1Slow, p.k3);

  return fastAmount + slowAmount;
}

// ==================== 预计算事件模型 ====================

class _PrecomputedEventModel {
  final double startTime;
  final DoseRoute _route;
  final PKParams _params;
  final double _dose;
  final double _wearH;

  _PrecomputedEventModel(DoseEvent event, List<DoseEvent> allEvents)
      : startTime = event.timeH,
        _route = event.route,
        _dose = event.doseMG,
        _params = resolveParams(event),
        _wearH = _calcWearH(event, allEvents);

  static double _calcWearH(DoseEvent event, List<DoseEvent> allEvents) {
    if (event.route != DoseRoute.patchApply) return 0;
    final remove = allEvents.cast<DoseEvent?>().firstWhere(
          (e) => e!.route == DoseRoute.patchRemove && e.timeH > event.timeH,
          orElse: () => null,
        );
    return (remove?.timeH ?? double.maxFinite) - event.timeH;
  }

  double amount(double timeH) {
    final tau = timeH - startTime;
    if (tau < 0) return 0;

    switch (_route) {
      case DoseRoute.injection:
        return _injAmount(tau, _dose, _params);
      case DoseRoute.gel:
      case DoseRoute.oral:
        return _oneCompAmount(
            tau, _dose, _params.F, _params.k1Fast, _params.k3);
      case DoseRoute.sublingual:
        return _sublingualAmount(tau, _dose, _params);
      case DoseRoute.patchApply:
        return _patchAmount(tau, _dose, _wearH, _params);
      case DoseRoute.patchRemove:
        return 0;
    }
  }
}

// ==================== 仿真引擎 ====================

SimulationResult runSimulation({
  required List<DoseEvent> events,
  double bodyWeightKG = 60.0,
  double historyPaddingHours = 24.0,
  double forecastHours = 24.0 * 14,
  int numberOfSteps = 1000,
}) {
  if (events.isEmpty) {
    return SimulationResult(
      timeH: [],
      concentrations: [],
      auc: 0,
      hormone: SimulatedHormone.estradiol,
    );
  }

  final hormone = events.first.hormone;
  final sortedEvents = List<DoseEvent>.from(events)
    ..sort((a, b) => a.timeH.compareTo(b.timeH));

  final precomputed = sortedEvents
      .where((e) => e.route != DoseRoute.patchRemove)
      .map((e) => _PrecomputedEventModel(e, sortedEvents))
      .toList();

  final startTime = sortedEvents.first.timeH - historyPaddingHours;
  final endTime = sortedEvents.last.timeH + forecastHours;

  // 抗雄激素使用其专属 Vd
  double vdPerKG = CorePK.vdPerKG;
  if (hormone == SimulatedHormone.antiandrogen) {
    final firstAA = events.first.antiandrogen;
    if (firstAA != null) {
      vdPerKG = AntiandrogenPK.vdPerKG(firstAA);
    }
  }
  final plasmaVolumeML = vdPerKG * bodyWeightKG * 1000;

  final timeH = <double>[];
  final concentrations = <double>[];
  double auc = 0;
  final stepSize = (endTime - startTime) / (numberOfSteps - 1);
  final concScale = hormone.concentrationScale / plasmaVolumeML;

  for (int i = 0; i < numberOfSteps; i++) {
    final t = startTime + i * stepSize;
    double totalAmountMG = 0;
    for (final model in precomputed) {
      totalAmountMG += model.amount(t);
    }

    final currentConc = totalAmountMG * concScale;
    timeH.add(t);
    concentrations.add(currentConc);

    if (i > 0) {
      auc += 0.5 * (currentConc + concentrations[i - 1]) * stepSize;
    }
  }

  return SimulationResult(
    timeH: timeH,
    concentrations: concentrations,
    auc: auc,
    hormone: hormone,
  );
}

double? interpolateConcentration(SimulationResult sim, double hour) {
  if (sim.timeH.isEmpty) return null;
  if (hour <= sim.timeH.first) return sim.concentrations.first;
  if (hour >= sim.timeH.last) return sim.concentrations.last;

  int low = 0;
  int high = sim.timeH.length - 1;

  while (high - low > 1) {
    final mid = (low + high) ~/ 2;
    if (sim.timeH[mid] == hour) return sim.concentrations[mid];
    if (sim.timeH[mid] < hour) {
      low = mid;
    } else {
      high = mid;
    }
  }

  final t0 = sim.timeH[low];
  final t1 = sim.timeH[high];
  final c0 = sim.concentrations[low];
  final c1 = sim.concentrations[high];

  if (t1 == t0) return c0;
  final ratio = (hour - t0) / (t1 - t0);
  return c0 + (c1 - c0) * ratio;
}
