/// Közös diagramok (fl_chart): formagörbe, eredménysor és
/// összehasonlító radar. A [components.dart] újraexportálja őket.
///
/// Minden diagram a [CourtboardColors] tokenekből színeződik (a győzelem /
/// vereség / döntetlen pontok a `win` / `loss` / `draw` tokenekkel), és
/// képernyőolvasónak egyetlen összefoglaló mondatot ad. Kitalált adatot
/// soha nem rajzolnak: két adatpont alatt a formagörbe és az eredménysor
/// egyáltalán nem jelenik meg.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

// ---------------------------------------------------------------------------
// Modellek
// ---------------------------------------------------------------------------

/// A formagörbe egy pontja: egy mérkőzés (vagy mérés) dátuma és értéke.
class FormPoint {
  const FormPoint({
    required this.date,
    required this.value,
    this.opponent = '',
    this.score,
    this.outcome = MatchOutcome.unknown,
  });

  final DateTime date;
  final double value;

  /// Ellenfél vagy esemény („Phoenix Suns”); üres, ha nincs (mérésnél).
  final String opponent;

  /// Eredmény („118–104”), ha ismert.
  final String? score;
  final MatchOutcome outcome;
}

/// Egy lejátszott mérkőzés eredménye az eredménysorhoz (darts, csapatok).
class ResultMark {
  const ResultMark({
    required this.date,
    required this.title,
    required this.outcome,
    this.score,
  });

  final DateTime date;
  final String title;
  final MatchOutcome outcome;
  final String? score;
}

/// A diagramok ennyi adatpont alatt nem jelennek meg.
const minChartPoints = 2;

/// A pontok időrendben (legrégebbi elöl).
List<FormPoint> chronological(Iterable<FormPoint> points) =>
    points.toList()..sort((a, b) => a.date.compareTo(b.date));

/// Átlag, vagy `null` üres listánál.
double? averageOf(Iterable<FormPoint> points) {
  if (points.isEmpty) return null;
  return points.fold<double>(0, (sum, point) => sum + point.value) /
      points.length;
}

/// Képernyőolvasó-összefoglaló, például „Az utolsó 5 meccsen átlag 21,4
/// pont. Legjobb: 31 pont (ápr. 12., Phoenix Suns).”
String formChartSummary(
  List<FormPoint> points, {
  required String unit,
  int digits = 0,
  String Function(int count)? scope,
}) {
  if (points.isEmpty) return 'Nincs formaadat.';
  final average = averageOf(points)!;
  final best = points.reduce((a, b) => b.value > a.value ? b : a);
  final where = (scope ?? (count) => 'Az utolsó $count meccsen')(points.length);
  final bestDetail = [
    formatShortDate(best.date),
    if (best.opponent.isNotEmpty) best.opponent,
  ].join(', ');
  return '$where átlag ${formatDecimal(average)} $unit. '
      'Legjobb: ${formatDecimal(best.value, digits: digits)} $unit '
      '($bestDetail).';
}

/// „Az utolsó 5 eredmény: 3 győzelem, 2 vereség.”
String resultStripSummary(List<ResultMark> marks) {
  final wins = marks.where((m) => m.outcome == MatchOutcome.win).length;
  final losses = marks.where((m) => m.outcome == MatchOutcome.loss).length;
  final draws = marks.where((m) => m.outcome == MatchOutcome.draw).length;
  final parts = [
    '$wins győzelem',
    '$losses vereség',
    if (draws > 0) '$draws döntetlen',
  ];
  return 'Az utolsó ${marks.length} eredmény: ${parts.join(', ')}.';
}

Color _outcomeColor(
  CourtboardColors cb,
  MatchOutcome outcome,
  Color fallback,
) => switch (outcome) {
  MatchOutcome.win => cb.win,
  MatchOutcome.loss => cb.loss,
  MatchOutcome.draw => cb.draw,
  _ => fallback,
};

// ---------------------------------------------------------------------------
// Formagörbe
// ---------------------------------------------------------------------------

/// Általános formagörbe: vonal a mérkőzésenkénti értékekkel, a pontok az
/// eredmény színével (GY / V / D), opcionális szaggatott átlagvonallal,
/// dátumos tengellyel és eszköztippel (ellenfél, eredmény).
///
/// [minChartPoints] adatpont alatt semmit nem rajzol (`SizedBox.shrink`).
class FormChart extends StatelessWidget {
  const FormChart({
    super.key,
    required this.points,
    required this.unit,
    this.average,
    this.averageLabel = 'Szezonátlag',
    this.color,
    this.height = 200,
    this.digits = 0,
    this.zeroBased = true,
    this.invert = false,
    this.scope,
  });

  final List<FormPoint> points;

  /// Az érték mértékegysége a feliratokban („pont”, „értékelés”).
  final String unit;

  /// A szaggatott vonal értéke (például szezonátlag); `null`: nincs vonal.
  final double? average;
  final String averageLabel;

  /// A vonal színe; alapból a téma kiemelőszíne (olvashatóra igazítva).
  final Color? color;
  final double height;

  /// Az értékek tizedesjegyei a feliratokban.
  final int digits;

  /// Igaz: az Y tengely nulláról indul (darabszámok); hamis: az adatokhoz
  /// igazodik (értékelés, ranglistapont).
  final bool zeroBased;

  /// Igaz: a kisebb érték van felül (például ranglista-helyezés).
  final bool invert;

  /// A képernyőolvasó-összefoglaló eleje („Az utolsó 5 meccsen”).
  final String Function(int count)? scope;

  static bool canShow(List<FormPoint> points) =>
      points.length >= minChartPoints;

  @override
  Widget build(BuildContext context) {
    if (!canShow(points)) return const SizedBox.shrink();
    final cb = context.cb;
    final sorted = chronological(points);
    final line = cb.readable(color ?? cb.accent, on: cb.surface);
    final summary = formChartSummary(
      sorted,
      unit: unit,
      digits: digits,
      scope: scope,
    );
    return Semantics(
      container: true,
      label: summary,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: const Key('form-chart'),
            height: height,
            child: LineChart(
              _data(context, cb, sorted, line),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 8),
          _Legend(
            lineColor: line,
            outcomes: {for (final point in sorted) point.outcome},
            averageLabel: average == null
                ? null
                : '$averageLabel: ${formatDecimal(average, digits: math.max(1, digits))}',
          ),
        ],
      ),
    );
  }

  LineChartData _data(
    BuildContext context,
    CourtboardColors cb,
    List<FormPoint> sorted,
    Color line,
  ) {
    // Fordított tengelynél (ranglista-helyezés) a negált értéket rajzoljuk,
    // a feliratok visszafordítva jelennek meg.
    double shown(double value) => invert ? -value : value;
    final values = [
      for (final point in sorted) shown(point.value),
      if (average != null) shown(average!),
    ];
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final span = math.max(maxY - minY, maxY.abs() * .1).clamp(1.0, 1e12);
    if (zeroBased && !invert && minY >= 0) {
      minY = 0;
      maxY = maxY + span * .15;
    } else {
      minY = minY - span * .15;
      maxY = maxY + span * .15;
      if (zeroBased && !invert) minY = math.max(0, minY);
    }
    final interval = _niceInterval((maxY - minY) / 4);
    final labelStyle = context.text.labelSmall?.copyWith(
      color: cb.textMuted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final step = (sorted.length / 7).ceil().clamp(1, sorted.length);
    return LineChartData(
      minX: 0,
      maxX: (sorted.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.none(),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: cb.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: invert || maxY >= 1000 ? 52 : 36,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value == meta.min || value == meta.max) {
                return const SizedBox.shrink();
              }
              final shown = invert ? -value : value;
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  formatDecimal(shown, digits: interval < 1 ? 1 : 0),
                  style: labelStyle,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if ((value - index).abs() > .01 ||
                  index < 0 ||
                  index >= sorted.length ||
                  (index % step != 0 && index != sorted.length - 1)) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  formatShortDate(sorted[index].date),
                  style: labelStyle,
                ),
              );
            },
          ),
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (average != null)
            HorizontalLine(
              y: shown(average!),
              color: cb.textMuted,
              strokeWidth: 1.5,
              dashArray: const [6, 4],
            ),
        ],
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => cb.ink,
          tooltipBorderRadius: BorderRadius.circular(10),
          maxContentWidth: 220,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) => [
            for (final spot in spots)
              _tooltip(context, cb, sorted[spot.spotIndex]),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < sorted.length; i++)
              FlSpot(i.toDouble(), shown(sorted[i].value)),
          ],
          color: line,
          barWidth: 2.5,
          isCurved: true,
          curveSmoothness: .2,
          preventCurveOverShooting: true,
          belowBarData: BarAreaData(
            show: !invert,
            color: line.withValues(alpha: .10),
          ),
          dotData: FlDotData(
            getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
              radius: 4.5,
              color: _outcomeColor(cb, sorted[index].outcome, line),
              strokeWidth: 2,
              strokeColor: cb.surface,
            ),
          ),
        ),
      ],
    );
  }

  LineTooltipItem _tooltip(
    BuildContext context,
    CourtboardColors cb,
    FormPoint point,
  ) {
    final header = [
      formatShortDate(point.date),
      if (point.opponent.isNotEmpty) point.opponent,
    ].join(' · ');
    final result = [
      if (point.outcome != MatchOutcome.unknown &&
          point.outcome != MatchOutcome.upcoming)
        point.outcome.letter,
      if (point.score != null && point.score!.isNotEmpty)
        normalizeScore(point.score!),
    ].join(' ');
    final value = '${formatDecimal(point.value, digits: digits)} $unit';
    return LineTooltipItem(
      '$header\n',
      TextStyle(
        color: cb.onInkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: result.isEmpty ? value : '$value · $result',
          style: TextStyle(
            color: cb.onInk,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  static double _niceInterval(double raw) {
    if (raw <= 0 || raw.isNaN) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final residual = raw / magnitude;
    final nice = residual <= 1
        ? 1
        : residual <= 2
        ? 2
        : residual <= 5
        ? 5
        : 10;
    return nice * magnitude;
  }
}

/// A formagörbe jelmagyarázata (vonal, GY/V/D pontok, átlag).
class _Legend extends StatelessWidget {
  const _Legend({
    required this.lineColor,
    required this.outcomes,
    required this.averageLabel,
  });

  final Color lineColor;

  /// A görbén előforduló kimenetelek (csak ezek kerülnek a jelmagyarázatba).
  final Set<MatchOutcome> outcomes;
  final String? averageLabel;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final style = context.text.labelSmall?.copyWith(
      color: cb.textMuted,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
    );
    Widget dot(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (outcomes.contains(MatchOutcome.win)) dot(cb.win, 'Győzelem'),
        if (outcomes.contains(MatchOutcome.loss)) dot(cb.loss, 'Vereség'),
        if (outcomes.contains(MatchOutcome.draw)) dot(cb.draw, 'Döntetlen'),
        if (averageLabel != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 2,
                child: CustomPaint(painter: _DashPainter(cb.textMuted)),
              ),
              const SizedBox(width: 5),
              Text(averageLabel!, style: style),
            ],
          ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 4, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Eredménysor
// ---------------------------------------------------------------------------

/// Tömör GY / V / D sor (legrégebbi balra), eszköztippel és mérleggel.
/// Ismert kimenetelű eredményből [minChartPoints] alatt nem jelenik meg.
class ResultStrip extends StatelessWidget {
  const ResultStrip({super.key, required this.results});

  final List<ResultMark> results;

  /// Csak az ismert kimenetelű (GY / V / D) eredmények, időrendben.
  static List<ResultMark> known(Iterable<ResultMark> results) =>
      results
          .where(
            (mark) =>
                mark.outcome == MatchOutcome.win ||
                mark.outcome == MatchOutcome.loss ||
                mark.outcome == MatchOutcome.draw,
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  static bool canShow(Iterable<ResultMark> results) =>
      known(results).length >= minChartPoints;

  @override
  Widget build(BuildContext context) {
    final marks = known(results);
    if (marks.length < minChartPoints) return const SizedBox.shrink();
    final cb = context.cb;
    final wins = marks.where((m) => m.outcome == MatchOutcome.win).length;
    final losses = marks.where((m) => m.outcome == MatchOutcome.loss).length;
    final draws = marks.where((m) => m.outcome == MatchOutcome.draw).length;
    return Semantics(
      container: true,
      label: resultStripSummary(marks),
      excludeSemantics: true,
      child: Wrap(
        key: const Key('result-strip'),
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final mark in marks)
            Tooltip(
              message: [
                formatShortDate(mark.date),
                mark.title,
                mark.outcome.label,
                if (mark.score != null && mark.score!.isNotEmpty)
                  normalizeScore(mark.score!),
              ].join(' · '),
              child: Container(
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _outcomeColor(cb, mark.outcome, cb.textMuted),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mark.outcome.letter,
                  style: context.text.labelSmall?.copyWith(
                    color: foregroundOn(
                      _outcomeColor(cb, mark.outcome, cb.textMuted),
                    ),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            ['$wins GY', '$losses V', if (draws > 0) '$draws D'].join(' · '),
            style: context.text.labelLarge?.copyWith(color: cb.textMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Összehasonlító radar
// ---------------------------------------------------------------------------

/// Két sportoló 0–1 közé normalizált mérőszámai radardiagramon. Legalább
/// három tengely kell; kevesebbnél semmit nem rajzol.
class ComparisonRadar extends StatelessWidget {
  const ComparisonRadar({
    super.key,
    required this.labels,
    required this.left,
    required this.right,
    required this.leftColor,
    required this.rightColor,
    required this.semanticLabel,
    this.size = 300,
  });

  final List<String> labels;

  /// 0–1 közötti értékek, a [labels] sorrendjében.
  final List<double> left;
  final List<double> right;
  final Color leftColor;
  final Color rightColor;
  final String semanticLabel;
  final double size;

  static bool canShow(int axes) => axes >= 3;

  @override
  Widget build(BuildContext context) {
    if (!canShow(labels.length) ||
        left.length != labels.length ||
        right.length != labels.length) {
      return const SizedBox.shrink();
    }
    final cb = context.cb;
    RadarDataSet anchor(double value) => RadarDataSet(
      dataEntries: [for (final _ in labels) RadarEntry(value: value)],
      fillColor: Colors.transparent,
      borderColor: Colors.transparent,
      borderWidth: 0,
      entryRadius: 0,
    );
    RadarDataSet series(List<double> values, Color color) => RadarDataSet(
      dataEntries: [
        for (final value in values) RadarEntry(value: value.clamp(0.0, 1.0)),
      ],
      fillColor: color.withValues(alpha: .18),
      borderColor: color,
      borderWidth: 2.5,
      entryRadius: 3,
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        key: const Key('compare-radar'),
        height: size,
        child: RadarChart(
          RadarChartData(
            // A két átlátszó „horgony” rögzíti a skálát 0 és 1 közé.
            dataSets: [
              anchor(0),
              anchor(1),
              series(left, leftColor),
              series(right, rightColor),
            ],
            radarShape: RadarShape.polygon,
            radarBackgroundColor: Colors.transparent,
            radarBorderData: BorderSide(color: cb.borderStrong),
            gridBorderData: BorderSide(color: cb.border),
            tickBorderData: BorderSide(color: cb.border),
            tickCount: 4,
            isMinValueAtCenter: true,
            ticksTextStyle: const TextStyle(
              color: Colors.transparent,
              fontSize: 1,
            ),
            titleTextStyle: context.text.labelSmall?.copyWith(
              color: cb.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            titlePositionPercentageOffset: .12,
            getTitle: (index, angle) => RadarChartTitle(text: labels[index]),
            radarTouchData: RadarTouchData(enabled: false),
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}
