import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/pk/pk_types.dart';
import '../models/pk/pk_params.dart';
import '../models/pk/pk_engine.dart';
import '../widgets/pk_license_notice.dart';

String _genId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_idCounter++}';
int _idCounter = 0;

/// 带标签的模拟结果条目
class _LabeledResult {
  final String label;
  final Color color;
  final SimulationResult result;
  const _LabeledResult(
      {required this.label, required this.color, required this.result});
}

class PKSimulationScreen extends StatefulWidget {
  final String genderIdentity;

  const PKSimulationScreen({super.key, required this.genderIdentity});

  @override
  State<PKSimulationScreen> createState() => _PKSimulationScreenState();
}

class _PKSimulationScreenState extends State<PKSimulationScreen> {
  List<DoseEvent> _events = [];
  double _bodyWeightKG = 60.0;
  late SimulatedHormone _currentHormone;
  List<_LabeledResult> _results = [];

  bool get _showEstradiol =>
      widget.genderIdentity == 'mtf' || widget.genderIdentity == 'nb';
  bool get _showTestosterone =>
      widget.genderIdentity == 'ftm' || widget.genderIdentity == 'nb';
  bool get _showAntiandrogen => widget.genderIdentity == 'mtf';

  @override
  void initState() {
    super.initState();
    _currentHormone = widget.genderIdentity == 'ftm'
        ? SimulatedHormone.testosterone
        : SimulatedHormone.estradiol;
    _addSampleEvents();
    _runSimulation();
  }

  void _addSampleEvents() {
    final now = DateTime.now().millisecondsSinceEpoch / 3600000.0;
    _events = [];

    if (_currentHormone == SimulatedHormone.estradiol) {
      _events.addAll([
        DoseEvent(
            id: _genId(),
            route: DoseRoute.injection,
            timeH: now - 24 * 7,
            doseMG: 5.0,
            hormone: SimulatedHormone.estradiol,
            ester: Ester.ev),
        DoseEvent(
            id: _genId(),
            route: DoseRoute.injection,
            timeH: now,
            doseMG: 5.0,
            hormone: SimulatedHormone.estradiol,
            ester: Ester.ev),
      ]);
    } else if (_currentHormone == SimulatedHormone.testosterone) {
      _events.addAll([
        DoseEvent(
            id: _genId(),
            route: DoseRoute.injection,
            timeH: now - 24 * 7,
            doseMG: 50.0,
            hormone: SimulatedHormone.testosterone,
            tEster: TestosteroneEster.tc),
        DoseEvent(
            id: _genId(),
            route: DoseRoute.injection,
            timeH: now,
            doseMG: 50.0,
            hormone: SimulatedHormone.testosterone,
            tEster: TestosteroneEster.tc),
      ]);
    } else {
      _events.addAll([
        DoseEvent(
            id: _genId(),
            route: DoseRoute.oral,
            timeH: now - 24,
            doseMG: 12.5,
            hormone: SimulatedHormone.antiandrogen,
            antiandrogen: Antiandrogen.cpa),
        DoseEvent(
            id: _genId(),
            route: DoseRoute.oral,
            timeH: now,
            doseMG: 12.5,
            hormone: SimulatedHormone.antiandrogen,
            antiandrogen: Antiandrogen.cpa),
      ]);
    }
  }

  void _runSimulation() {
    if (_currentHormone == SimulatedHormone.antiandrogen) {
      // 抗雄激素按药物类型分组，各自独立模拟
      final aaEvents = _events
          .where((e) => e.hormone == SimulatedHormone.antiandrogen)
          .toList();
      final colors = const [
        Color(0xFFE57373),
        Color(0xFF64B5F6),
        Color(0xFF81C784)
      ];
      final labeled = <_LabeledResult>[];
      final aaTypes = aaEvents.map((e) => e.antiandrogen).toSet();
      for (final aa in aaTypes) {
        if (aa == null) continue;
        final groupEvents =
            aaEvents.where((e) => e.antiandrogen == aa).toList();
        if (groupEvents.isEmpty) continue;
        final sim =
            runSimulation(events: groupEvents, bodyWeightKG: _bodyWeightKG);
        final idx = Antiandrogen.values.indexOf(aa);
        labeled.add(_LabeledResult(
          label: AntiandrogenPK.displayName(aa),
          color: colors[idx % colors.length],
          result: sim,
        ));
      }
      _results = labeled;
    } else {
      final hormoneEvents =
          _events.where((e) => e.hormone == _currentHormone).toList();
      final sim =
          runSimulation(events: hormoneEvents, bodyWeightKG: _bodyWeightKG);
      _results = [
        _LabeledResult(
          label: _hormoneLabel,
          color: _hormoneColor,
          result: sim,
        )
      ];
    }
    setState(() {});
  }

  void _addEvent(DoseEvent event) {
    setState(() => _events.add(event));
    _runSimulation();
  }

  void _removeEvent(String id) {
    setState(() => _events.removeWhere((e) => e.id == id));
    _runSimulation();
  }

  void _clearAll() {
    setState(() {
      _events.removeWhere((e) => e.hormone == _currentHormone);
      _results = [];
    });
  }

  void _switchHormone(SimulatedHormone h) {
    if (_currentHormone == h) return;
    setState(() => _currentHormone = h);
    _runSimulation();
  }

  List<DoseEvent> get _currentEvents =>
      _events.where((e) => e.hormone == _currentHormone).toList();

  Color get _hormoneColor {
    switch (_currentHormone) {
      case SimulatedHormone.estradiol:
        return const Color(0xFFF5A9B8);
      case SimulatedHormone.testosterone:
        return const Color(0xFF5BCEFA);
      case SimulatedHormone.antiandrogen:
        return const Color(0xFF7B68EE);
    }
  }

  String get _hormoneLabel {
    switch (_currentHormone) {
      case SimulatedHormone.estradiol:
        return '雌二醇 (E2)';
      case SimulatedHormone.testosterone:
        return '睾酮 (T)';
      case SimulatedHormone.antiandrogen:
        return '抗雄激素 (AA)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNB = _showEstradiol && _showTestosterone;
    final isMtF = _showAntiandrogen;
    final color = _hormoneColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('血药浓度模拟'),
        backgroundColor: color.withOpacity(0.15),
        actions: [
          if (isNB)
            PopupMenuButton<SimulatedHormone>(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color)),
                child: Text('药物类型选择',
                    style: TextStyle(fontSize: 12, color: color)),
              ),
              onSelected: _switchHormone,
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: SimulatedHormone.estradiol,
                    child: Text('雌二醇 (E2)',
                        style: TextStyle(
                            fontWeight:
                                _currentHormone == SimulatedHormone.estradiol
                                    ? FontWeight.bold
                                    : FontWeight.normal))),
                PopupMenuItem(
                    value: SimulatedHormone.testosterone,
                    child: Text('睾酮 (T)',
                        style: TextStyle(
                            fontWeight:
                                _currentHormone == SimulatedHormone.testosterone
                                    ? FontWeight.bold
                                    : FontWeight.normal))),
                PopupMenuItem(
                    value: SimulatedHormone.antiandrogen,
                    child: Text('抗雄激素 (AA)',
                        style: TextStyle(
                            fontWeight:
                                _currentHormone == SimulatedHormone.antiandrogen
                                    ? FontWeight.bold
                                    : FontWeight.normal))),
              ],
            )
          else if (isMtF)
            TextButton.icon(
              icon: Icon(
                  _currentHormone == SimulatedHormone.antiandrogen
                      ? Icons.female
                      : Icons.medication,
                  size: 16,
                  color: color),
              label: Text(
                  _currentHormone == SimulatedHormone.antiandrogen
                      ? '雌二醇'
                      : '抗雄激素',
                  style: TextStyle(fontSize: 12, color: color)),
              onPressed: () => _switchHormone(
                  _currentHormone == SimulatedHormone.antiandrogen
                      ? SimulatedHormone.estradiol
                      : SimulatedHormone.antiandrogen),
            ),
          if (_currentEvents.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空当前激素记录',
                onPressed: _clearAll),
          IconButton(
              icon: Icon(Icons.add_circle_outline, color: color),
              tooltip: '新增用药',
              onPressed: _showAddDoseDialog),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: color.withOpacity(0.08),
            child: Text('当前药物：$_hormoneLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ),
          _buildStatusBar(),
          Expanded(child: _buildChart()),
          _buildEventList(),
          const PKLicenseNotice(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final now = DateTime.now().millisecondsSinceEpoch / 3600000.0;
    double? currentConc;
    double? totalAuc;
    if (_results.isNotEmpty) {
      // 取第一条结果的浓度作为显示（多线时显示第一条的当前浓度）
      currentConc = interpolateConcentration(_results.first.result, now);
      totalAuc = _results.fold<double>(0, (sum, r) => sum + r.result.auc);
    }

    final unit = _currentHormone.concentrationUnit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('当前估算浓度',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                  currentConc != null
                      ? '${currentConc.toStringAsFixed(1)} $unit'
                      : '—',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (totalAuc != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('AUC (14天)',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('${(totalAuc / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          const SizedBox(width: 16),
          InkWell(
            onTap: _showWeightDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.monitor_weight_outlined, size: 16),
                const SizedBox(width: 4),
                Text('${_bodyWeightKG.round()} kg',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_results.isEmpty || _results.every((r) => r.result.timeH.isEmpty)) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.biotech, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text('暂无数据，请添加用药记录', style: TextStyle(color: Colors.grey)),
      ]));
    }

    final now = DateTime.now().millisecondsSinceEpoch / 3600000.0;
    final unit = _currentHormone.concentrationUnit;

    // 计算所有曲线的全局 X 范围和最大浓度
    double globalMinX = double.infinity,
        globalMaxX = double.negativeInfinity,
        globalMaxY = 0;
    for (final lr in _results) {
      if (lr.result.timeH.isEmpty) continue;
      final minX = (lr.result.timeH.first - now) / 24.0;
      final maxX = (lr.result.timeH.last - now) / 24.0;
      if (minX < globalMinX) globalMinX = minX;
      if (maxX > globalMaxX) globalMaxX = maxX;
      for (final c in lr.result.concentrations) {
        if (c > globalMaxY) globalMaxY = c;
      }
    }
    if (!globalMinX.isFinite) globalMinX = -14;
    if (!globalMaxX.isFinite) globalMaxX = 14;

    // 构建线数据
    final lineBars = <LineChartBarData>[];
    for (final lr in _results) {
      final spots = <FlSpot>[];
      for (int i = 0; i < lr.result.timeH.length; i++) {
        spots.add(FlSpot(
            (lr.result.timeH[i] - now) / 24.0, lr.result.concentrations[i]));
      }
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: lr.color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData:
            BarAreaData(show: true, color: lr.color.withOpacity(0.08)),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Column(
        children: [
          // 图例
          if (_results.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 16,
                children: _results
                    .map((lr) => Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 12, height: 3, color: lr.color),
                          const SizedBox(width: 4),
                          Text(lr.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: lr.color,
                                  fontWeight: FontWeight.w600)),
                        ]))
                    .toList(),
              ),
            ),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        max(1.0, (globalMaxY / 5).ceilToDouble())),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(unit,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) return const SizedBox.shrink();
                          return Text(value.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey));
                        }),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('天数',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) return const SizedBox.shrink();
                          return Text('${value.round()}d',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey));
                        }),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBars,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        // 找到对应这条线的标签
                        final idx = spot.barIndex;
                        final label =
                            idx < _results.length ? _results[idx].label : '';
                        return LineTooltipItem(
                          '$label\n${spot.y.toStringAsFixed(1)} $unit\n(${(spot.x * 24).round().toString()}h)',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                        x: 0,
                        color: Colors.red.withOpacity(0.4),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                        label: VerticalLineLabel(
                            show: true,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.red),
                            alignment: Alignment.topCenter,
                            padding: const EdgeInsets.only(top: 4))),
                  ],
                ),
                minX: globalMinX,
                maxX: globalMaxX,
                minY: 0,
                maxY: globalMaxY * 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final currentEvents = _currentEvents;
    if (currentEvents.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
              child: Text('暂无用药记录', style: TextStyle(color: Colors.grey))));
    }

    final sorted = List<DoseEvent>.from(currentEvents)
      ..sort((a, b) => b.timeH.compareTo(a.timeH));

    return Container(
      height: 180,
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              const Text('用药记录',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('共 ${currentEvents.length} 条',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
          itemCount: sorted.length,
          itemBuilder: (context, index) => _buildEventItem(sorted[index]),
        )),
      ]),
    );
  }

  Widget _buildEventItem(DoseEvent event) {
    final dt =
        DateTime.fromMillisecondsSinceEpoch((event.timeH * 3600000).round());
    final dateStr =
        '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final compoundLabel = _getCompoundLabel(event);
    final (icon, color, routeLabel) = _getRouteDisplay(event.route);

    return Card(
        margin: const EdgeInsets.only(bottom: 4),
        elevation: 0,
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 16, color: color)),
          title: Text(
              '$routeLabel · ${event.doseMG.toStringAsFixed(1)} mg $compoundLabel',
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(dateStr, style: const TextStyle(fontSize: 11)),
          trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _removeEvent(event.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.grey),
        ));
  }

  String _getCompoundLabel(DoseEvent event) {
    if (event.ester != null)
      return EsterInfo.values[event.ester!]?.name ??
          event.ester!.name.toUpperCase();
    if (event.tEster != null)
      return TestosteroneEsterInfo.values[event.tEster!]?.name ??
          event.tEster!.name.toUpperCase();
    if (event.antiandrogen != null)
      return AntiandrogenPK.displayName(event.antiandrogen!);
    return '?';
  }

  (IconData, Color, String) _getRouteDisplay(DoseRoute route) {
    switch (route) {
      case DoseRoute.injection:
        return (Icons.biotech, Colors.blue, '肌注');
      case DoseRoute.oral:
        return (Icons.medication_liquid, Colors.orange, '口服');
      case DoseRoute.sublingual:
        return (Icons.science, Colors.purple, '舌下');
      case DoseRoute.gel:
        return (Icons.opacity, Colors.teal, '凝胶');
      case DoseRoute.patchApply:
        return (Icons.sticky_note_2, Colors.indigo, '贴片');
      case DoseRoute.patchRemove:
        return (Icons.remove_circle_outline, Colors.red, '移除');
    }
  }

  void _showWeightDialog() {
    final controller =
        TextEditingController(text: _bodyWeightKG.round().toString());
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('设置体重'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('体重用于计算分布容积 (Vd ≈ 2.0 L/kg)，直接影响血药浓度峰值估算。'),
                const SizedBox(height: 16),
                TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '体重 (kg)', border: OutlineInputBorder())),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () {
                      final v = double.tryParse(controller.text);
                      if (v != null && v > 0) {
                        _bodyWeightKG = v;
                        _runSimulation();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('确认')),
              ],
            ));
  }

  void _showAddDoseDialog() {
    final isE2 = _currentHormone == SimulatedHormone.estradiol;
    final isT = _currentHormone == SimulatedHormone.testosterone;
    final isAA = _currentHormone == SimulatedHormone.antiandrogen;

    DoseRoute selectedRoute = isAA ? DoseRoute.oral : DoseRoute.injection;
    Ester? selectedEster = isE2 ? Ester.ev : null;
    TestosteroneEster? selectedTEster = isT ? TestosteroneEster.tc : null;
    Antiandrogen? selectedAA = isAA ? Antiandrogen.cpa : null;
    final doseController = TextEditingController(
        text: isE2
            ? '5.0'
            : isT
                ? '50.0'
                : '12.5');
    final now = DateTime.now();
    DateTime selectedDate = now;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(now);

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('新增用药'),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<DoseRoute>(
                      value: selectedRoute,
                      decoration: const InputDecoration(
                          labelText: '给药途径', border: OutlineInputBorder()),
                      items: _getRouteItems(),
                      onChanged: (v) {
                        if (v != null)
                          setDialogState(() {
                            selectedRoute = v;
                            if (isE2) {
                              final av = _getEsterItems(v, _currentHormone);
                              if (av.isNotEmpty &&
                                  !av.any((i) => i.value == selectedEster))
                                selectedEster = av.first.value;
                            } else if (isT) {
                              final av = _getTEsterItems(v, _currentHormone);
                              if (av.isNotEmpty &&
                                  !av.any((i) => i.value == selectedTEster))
                                selectedTEster = av.first.value;
                            }
                          });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isE2)
                      DropdownButtonHideUnderline(
                          child: DropdownButton<Ester>(
                        value: _getEsterItems(selectedRoute, _currentHormone)
                                .any((item) => item.value == selectedEster)
                            ? selectedEster
                            : (_getEsterItems(selectedRoute, _currentHormone)
                                    .isNotEmpty
                                ? _getEsterItems(selectedRoute, _currentHormone)
                                    .first
                                    .value
                                : null),
                        isExpanded: true,
                        items: _getEsterItems(selectedRoute, _currentHormone),
                        onChanged: (v) {
                          if (v != null)
                            setDialogState(() => selectedEster = v);
                        },
                      ))
                    else if (isT)
                      DropdownButtonHideUnderline(
                          child: DropdownButton<TestosteroneEster>(
                        value: _getTEsterItems(selectedRoute, _currentHormone)
                                .any((item) => item.value == selectedTEster)
                            ? selectedTEster
                            : (_getTEsterItems(selectedRoute, _currentHormone)
                                    .isNotEmpty
                                ? _getTEsterItems(
                                        selectedRoute, _currentHormone)
                                    .first
                                    .value
                                : null),
                        isExpanded: true,
                        items: _getTEsterItems(selectedRoute, _currentHormone),
                        onChanged: (v) {
                          if (v != null)
                            setDialogState(() => selectedTEster = v);
                        },
                      ))
                    else
                      DropdownButtonHideUnderline(
                          child: DropdownButton<Antiandrogen>(
                        value: _getAntiandrogenItems()
                                .any((item) => item.value == selectedAA)
                            ? selectedAA
                            : (_getAntiandrogenItems().isNotEmpty
                                ? _getAntiandrogenItems().first.value
                                : null),
                        isExpanded: true,
                        items: _getAntiandrogenItems(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedAA = v);
                        },
                      )),
                    const SizedBox(height: 12),
                    TextField(
                        controller: doseController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: '剂量 (mg)',
                            border: const OutlineInputBorder(),
                            helperText: isE2
                                ? 'E2 等效剂量'
                                : isT
                                    ? 'T 等效剂量'
                                    : '抗雄激素口服剂量')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                  '${selectedDate.month}/${selectedDate.day}'),
                              onPressed: () async {
                                final date = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: selectedDate
                                        .subtract(const Duration(days: 365)),
                                    lastDate: selectedDate
                                        .add(const Duration(days: 365)));
                                if (date != null)
                                  setDialogState(() => selectedDate = date);
                              })),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(selectedTime.format(context)),
                              onPressed: () async {
                                final time = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime);
                                if (time != null)
                                  setDialogState(() => selectedTime = time);
                              })),
                    ]),
                  ]),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        final dose = double.tryParse(doseController.text);
                        if (dose == null || dose <= 0) return;
                        final dt = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute);
                        _addEvent(DoseEvent(
                            id: _genId(),
                            route: selectedRoute,
                            timeH: dt.millisecondsSinceEpoch / 3600000.0,
                            doseMG: dose,
                            hormone: _currentHormone,
                            ester: selectedEster,
                            tEster: selectedTEster,
                            antiandrogen: selectedAA));
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('添加')),
                ],
              ),
            ));
  }

  List<DropdownMenuItem<DoseRoute>> _getRouteItems() {
    if (_currentHormone == SimulatedHormone.estradiol) {
      return const [
        DropdownMenuItem(
            value: DoseRoute.injection, child: Text('肌注 (Injection)')),
        DropdownMenuItem(value: DoseRoute.oral, child: Text('口服 (Oral)')),
        DropdownMenuItem(
            value: DoseRoute.sublingual, child: Text('舌下 (Sublingual)')),
        DropdownMenuItem(value: DoseRoute.gel, child: Text('凝胶 (Gel)')),
        DropdownMenuItem(
            value: DoseRoute.patchApply, child: Text('贴片 (Patch)')),
      ];
    }
    if (_currentHormone == SimulatedHormone.testosterone) {
      return const [
        DropdownMenuItem(
            value: DoseRoute.injection, child: Text('肌注 (Injection)')),
        DropdownMenuItem(value: DoseRoute.oral, child: Text('口服 (Oral)')),
        DropdownMenuItem(value: DoseRoute.gel, child: Text('凝胶 (Gel)')),
        DropdownMenuItem(
            value: DoseRoute.patchApply, child: Text('贴片 (Patch)')),
      ];
    }
    return const [
      DropdownMenuItem(value: DoseRoute.oral, child: Text('口服 (Oral)'))
    ];
  }

  List<DropdownMenuItem<Ester>> _getEsterItems(
      DoseRoute route, SimulatedHormone hormone) {
    if (hormone != SimulatedHormone.estradiol) return [];
    switch (route) {
      case DoseRoute.injection:
        return const [
          DropdownMenuItem(value: Ester.eb, child: Text('苯甲酸雌二醇 (EB)')),
          DropdownMenuItem(value: Ester.ev, child: Text('戊酸雌二醇 (EV)')),
          DropdownMenuItem(value: Ester.ec, child: Text('环戊丙酸雌二醇 (EC)')),
          DropdownMenuItem(value: Ester.en, child: Text('庚酸雌二醇 (EN)')),
        ];
      case DoseRoute.oral:
      case DoseRoute.sublingual:
        return const [
          DropdownMenuItem(value: Ester.e2, child: Text('雌二醇 (E2)')),
          DropdownMenuItem(value: Ester.ev, child: Text('戊酸雌二醇 (EV)')),
        ];
      case DoseRoute.gel:
      case DoseRoute.patchApply:
      case DoseRoute.patchRemove:
        return const [
          DropdownMenuItem(value: Ester.e2, child: Text('雌二醇 (E2)'))
        ];
    }
  }

  List<DropdownMenuItem<TestosteroneEster>> _getTEsterItems(
      DoseRoute route, SimulatedHormone hormone) {
    if (hormone != SimulatedHormone.testosterone) return [];
    switch (route) {
      case DoseRoute.injection:
        return const [
          DropdownMenuItem(
              value: TestosteroneEster.tc, child: Text('环戊丙酸睾酮 (TC)')),
          DropdownMenuItem(
              value: TestosteroneEster.te, child: Text('庚酸睾酮 (TE)')),
          DropdownMenuItem(
              value: TestosteroneEster.tu, child: Text('十一酸睾酮 (TU)')),
        ];
      case DoseRoute.oral:
        return const [
          DropdownMenuItem(
              value: TestosteroneEster.tu, child: Text('十一酸睾酮 (TU)'))
        ];
      case DoseRoute.gel:
      case DoseRoute.patchApply:
      case DoseRoute.patchRemove:
        return const [
          DropdownMenuItem(value: TestosteroneEster.t, child: Text('睾酮 (T)'))
        ];
      case DoseRoute.sublingual:
        return [];
    }
  }

  List<DropdownMenuItem<Antiandrogen>> _getAntiandrogenItems() {
    return const [
      DropdownMenuItem(value: Antiandrogen.cpa, child: Text('环丙孕酮 (CPA)')),
      DropdownMenuItem(
          value: Antiandrogen.spironolactone, child: Text('螺内酯 → 坎利酮')),
      DropdownMenuItem(
          value: Antiandrogen.canrenone, child: Text('坎利酮 (Canrenone)')),
    ];
  }
}
