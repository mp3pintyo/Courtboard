import 'dart:async';
import 'package:flutter/material.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/features/compare/compare_data.dart';
import 'package:courtboard/domain/athlete.dart';

/// Az összehasonlítás egyik oldalának eredménye: szezonadat vagy hiba.
class _CompareSide {
  const _CompareSide(this.snapshot, [this.error]);
  final AthleteSeasonSnapshot? snapshot;
  final Object? error;
}

class _ComparePair {
  const _ComparePair(this.left, this.right);
  final _CompareSide left;
  final _CompareSide right;
}

/// „Összehasonlítás”: két azonos sportágú követett sportoló szezon-
/// összesítője egymás mellett (a jobb érték kiemelve) és radardiagramon.
class ComparePage extends StatefulWidget {
  const ComparePage({
    super.key,
    required this.athletes,
    required this.config,
    required this.source,
    required this.onOpenAthlete,
    this.initialAthlete,
    this.initialOpponent,
    this.onSelectionChanged,
  });

  final List<Athlete> athletes;
  final SportsApiConfig config;
  final CompareDataSource source;
  final ValueChanged<Athlete> onOpenAthlete;

  /// Előre kiválasztott (bal oldali) sportoló neve.
  final String? initialAthlete;

  /// Előre kiválasztott jobb oldali sportoló neve (ha azonos sportágú).
  final String? initialOpponent;

  /// A felhasználó új párt választott (bal, jobb név) — például az
  /// útvonal (`/osszehasonlitas?a=…&b=…`) frissítéséhez.
  final void Function(String? left, String? right)? onSelectionChanged;

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  String? _left;
  String? _right;

  /// Kívülről (útvonalból) kért új kiválasztáskor nő: a választómezők
  /// újraépülnek az új értékkel.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _pickInitial();
  }

  @override
  void didUpdateWidget(covariant ComparePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requestChanged =
        oldWidget.initialAthlete != widget.initialAthlete ||
        oldWidget.initialOpponent != widget.initialOpponent;
    final alreadyShown =
        widget.initialAthlete == _left &&
        (widget.initialOpponent == null || widget.initialOpponent == _right);
    if ((requestChanged && !alreadyShown) ||
        _find(_left) == null ||
        (_right != null && _find(_right) == null)) {
      _pickInitial();
      _generation++;
    }
  }

  void _notifySelection() => widget.onSelectionChanged?.call(_left, _right);

  Athlete? _find(String? name) => name == null
      ? null
      : widget.athletes.where((athlete) => athlete.name == name).firstOrNull;

  /// A bal oldal: a kért sportoló, különben az első olyan, akinek a
  /// sportágában van másik követett sportoló és összehasonlítható.
  void _pickInitial() {
    final requested = _find(widget.initialAthlete);
    final left =
        requested ??
        widget.athletes
            .where(
              (athlete) =>
                  sportSupportsComparison(athlete.sport) &&
                  _partnersOf(athlete).isNotEmpty,
            )
            .firstOrNull ??
        widget.athletes.firstOrNull;
    _left = left?.name;
    final partners = left == null ? const <Athlete>[] : _partnersOf(left);
    final opponent = requested == null
        ? null
        : partners
              .where((athlete) => athlete.name == widget.initialOpponent)
              .firstOrNull;
    _right = (opponent ?? partners.firstOrNull)?.name;
  }

  List<Athlete> _partnersOf(Athlete athlete) => [
    for (final other in widget.athletes)
      if (other.name != athlete.name && other.sport == athlete.sport) other,
  ];

  void _selectLeft(String? name) {
    final left = _find(name);
    if (left == null) return;
    setState(() {
      _left = left.name;
      final right = _find(_right);
      if (right == null ||
          right.name == left.name ||
          right.sport != left.sport) {
        _right = _partnersOf(left).firstOrNull?.name;
      }
    });
    _notifySelection();
  }

  void _swap() {
    setState(() {
      final left = _left;
      _left = _right;
      _right = left;
    });
    _notifySelection();
  }

  Future<_CompareSide> _loadSide(Athlete athlete, {required bool force}) async {
    try {
      return _CompareSide(
        await widget.source.load(
          name: athlete.name,
          sport: athlete.sport,
          team: athlete.team,
          config: widget.config,
          force: force,
        ),
      );
    } catch (error) {
      return _CompareSide(null, error);
    }
  }

  Future<_ComparePair> _load(
    Athlete left,
    Athlete right, {
    required bool force,
  }) async {
    final sides = await Future.wait([
      _loadSide(left, force: force),
      _loadSide(right, force: force),
    ]);
    // Csak akkor hiba, ha egyik oldal sem adott adatot és volt hiba.
    if (sides.every((side) => side.snapshot == null)) {
      final error = sides.map((side) => side.error).nonNulls.firstOrNull;
      if (error != null) throw error;
    }
    return _ComparePair(sides[0], sides[1]);
  }

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final left = _find(_left);
    final right = _find(_right);
    final horizontal = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    return ColoredBox(
      color: cb.canvas,
      child: SingleChildScrollView(
        key: const PageStorageKey('compare-scroll'),
        padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Összehasonlítás',
              subtitle:
                  'Két azonos sportágú követett sportoló szezonösszesítője '
                  'egymás mellett; a jobb érték kiemelve.',
            ),
            const SizedBox(height: 22),
            if (widget.athletes.length < 2)
              const SurfaceCard(
                child: EmptyState(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Legalább két követett sportoló kell.',
                  message:
                      'Adj hozzá még egy sportolót (Ctrl+N), és itt '
                      'összevetheted a szezonjukat.',
                ),
              )
            else ...[
              _selectors(context, left, right),
              const SizedBox(height: 20),
              _content(context, left, right),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectors(BuildContext context, Athlete? left, Athlete? right) {
    DropdownMenuItem<String> item(Athlete athlete, {bool enabled = true}) =>
        DropdownMenuItem(
          value: athlete.name,
          enabled: enabled,
          child: Text(
            enabled
                ? '${athlete.name} · ${athlete.sport.shortLabel}'
                : '${athlete.name} · ${athlete.sport.shortLabel} (más sportág)',
            overflow: TextOverflow.ellipsis,
          ),
        );
    final leftField = DropdownButtonFormField<String>(
      key: const Key('compare-left'),
      initialValue: left?.name,
      isExpanded: true,
      style: context.text.bodyLarge,
      decoration: const InputDecoration(labelText: 'Első sportoló'),
      items: [for (final athlete in widget.athletes) item(athlete)],
      onChanged: _selectLeft,
    );
    final rightField = DropdownButtonFormField<String>(
      key: ValueKey('compare-right-${left?.name}-$_right'),
      initialValue: right?.name,
      isExpanded: true,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Második sportoló',
        helperText: left == null
            ? null
            : 'Csak azonos sportágú (${left.sport.shortLabel}) sportoló választható.',
      ),
      items: [
        for (final athlete in widget.athletes)
          if (athlete.name != left?.name)
            item(athlete, enabled: athlete.sport == left?.sport),
      ],
      onChanged: (name) {
        setState(() => _right = name);
        _notifySelection();
      },
    );
    final swap = IconButton.outlined(
      key: const Key('compare-swap'),
      tooltip: 'Oldalak cseréje',
      onPressed: left != null && right != null ? _swap : null,
      icon: const Icon(Icons.swap_horiz_rounded),
    );
    return SurfaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyedSubtree(key: ValueKey(_generation), child: leftField),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.center, child: swap),
                  const SizedBox(height: 8),
                  rightField,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(_generation),
                      child: leftField,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: swap,
                  ),
                  Expanded(child: rightField),
                ],
              ),
      ),
    );
  }

  Widget _content(BuildContext context, Athlete? left, Athlete? right) {
    if (left == null) return const SizedBox.shrink();
    if (!sportSupportsComparison(left.sport)) {
      return SurfaceCard(
        key: const Key('compare-unsupported'),
        child: EmptyState(
          compact: true,
          icon: Icons.info_outline,
          message:
              'A(z) ${left.sport.shortLabel} sportághoz egyik bekötött forrás sem ad '
              'szezonösszesítőt, ezért nem hasonlítható össze. Összehasonlítható: '
              'NBA, WNBA, foci és tenisz.',
        ),
      );
    }
    if (right == null) {
      return SurfaceCard(
        key: const Key('compare-no-partner'),
        child: EmptyState(
          compact: true,
          icon: Icons.person_search_outlined,
          message:
              'Nincs másik követett ${left.sport.shortLabel}-sportoló. Különböző '
              'sportágú sportolók nem hasonlíthatók össze; adj hozzá egy '
              '${left.sport.shortLabel}-sportolót (Ctrl+N).',
        ),
      );
    }
    if (right.sport != left.sport) {
      return SurfaceCard(
        key: const Key('compare-cross-sport'),
        child: EmptyState(
          compact: true,
          icon: Icons.block_outlined,
          message:
              'Csak azonos sportágú sportolók hasonlíthatók össze '
              '(${left.sport.shortLabel} és ${right.sport.shortLabel} mérőszámai nem vethetők össze).',
        ),
      );
    }
    final metrics = CompareMetrics.forSport(left.sport);
    return DataSourceCard<_ComparePair>(
      key: const Key('compare-card'),
      title: 'Szezon összesítő · ${left.sport.shortLabel}',
      icon: Icons.leaderboard_outlined,
      reloadKey: (left.name, right.name, widget.config),
      refreshTooltip: 'Szezonadatok frissítése',
      loadingLabel: 'Szezonadatok betöltése a két sportolóhoz…',
      errorPrefix: 'A szezonadatok most nem érhetők el. ',
      emptyMessage: 'Egyik sportolóhoz sem érkezett szezonadat.',
      emptyIcon: Icons.person_search_outlined,
      isEmpty: (pair) =>
          pair.left.snapshot?.hasData != true &&
          pair.right.snapshot?.hasData != true,
      load: ({required force}) => _load(left, right, force: force),
      builder: (context, pair) => _CompareView(
        left: left,
        right: right,
        pair: pair,
        metrics: metrics,
        onOpenAthlete: widget.onOpenAthlete,
      ),
    );
  }
}

class _CompareView extends StatelessWidget {
  const _CompareView({
    required this.left,
    required this.right,
    required this.pair,
    required this.metrics,
    required this.onOpenAthlete,
  });

  final Athlete left;
  final Athlete right;
  final _ComparePair pair;
  final List<CompareMetric> metrics;
  final ValueChanged<Athlete> onOpenAthlete;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final leftColor = cb.readable(cb.accent);
    final rightColor = cb.readable(cb.warning);
    final a =
        pair.left.snapshot ??
        AthleteSeasonSnapshot(
          athleteName: left.name,
          sport: left.sport,
          values: const {},
        );
    final b =
        pair.right.snapshot ??
        AthleteSeasonSnapshot(
          athleteName: right.name,
          sport: right.sport,
          values: const {},
        );
    final axes = radarMetrics(metrics, a, b);
    final radar = ComparisonRadar(
      labels: [for (final metric in axes) metric.axisLabel],
      left: [for (final metric in axes) normalizeMetric(metric, a[metric.id])],
      right: [for (final metric in axes) normalizeMetric(metric, b[metric.id])],
      leftColor: leftColor,
      rightColor: rightColor,
      semanticLabel:
          'Radardiagram, ligához viszonyított értékek. '
          '${compareSummary(metrics, a, b)}',
    );
    final tiles = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final metric in metrics)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MetricPair(
              metric: metric,
              left: a[metric.id],
              right: b[metric.id],
            ),
          ),
      ],
    );
    final errors = [
      if (pair.left.snapshot?.hasData != true)
        '${left.name}: ${pair.left.error == null ? 'nem érkezett szezonadat.' : friendlyError(pair.left.error!)}',
      if (pair.right.snapshot?.hasData != true)
        '${right.name}: ${pair.right.error == null ? 'nem érkezett szezonadat.' : friendlyError(pair.right.error!)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heads = [
              _SideHeader(
                athlete: left,
                snapshot: pair.left.snapshot,
                color: leftColor,
                onOpen: () => onOpenAthlete(left),
              ),
              _SideHeader(
                athlete: right,
                snapshot: pair.right.snapshot,
                color: rightColor,
                onOpen: () => onOpenAthlete(right),
              ),
            ];
            return constraints.maxWidth < 560
                ? Column(
                    children: [heads[0], const SizedBox(height: 10), heads[1]],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heads[0]),
                      const SizedBox(width: 10),
                      Expanded(child: heads[1]),
                    ],
                  );
          },
        ),
        const SizedBox(height: 12),
        Text(
          compareSummary(metrics, a, b),
          key: const Key('compare-summary'),
          style: context.text.titleSmall,
        ),
        for (final error in errors) CourtboardNote(error),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final showRadar = ComparisonRadar.canShow(axes.length);
            final radarBlock = Column(
              children: [
                radar,
                const SizedBox(height: 10),
                _RadarLegend(
                  left: left.name,
                  right: right.name,
                  leftColor: leftColor,
                  rightColor: rightColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'A radar a liga referencia-értékeihez viszonyít (külső él = '
                  'kiemelkedő szezon); a „kevesebb a jobb” mutatók fordítva.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ],
            );
            if (!showRadar) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tiles,
                  if (axes.length < 3)
                    Text(
                      'A radardiagramhoz legalább három, mindkét sportolónál '
                      'ismert mutató kell.',
                      style: context.text.bodySmall,
                    ),
                ],
              );
            }
            if (constraints.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tiles, const SizedBox(height: 12), radarBlock],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: tiles),
                const SizedBox(width: 28),
                Expanded(flex: 2, child: radarBlock),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SideHeader extends StatelessWidget {
  const _SideHeader({
    required this.athlete,
    required this.snapshot,
    required this.color,
    required this.onOpen,
  });

  final Athlete athlete;
  final AthleteSeasonSnapshot? snapshot;
  final Color color;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final details = [
      if (snapshot?.team.isNotEmpty == true) snapshot!.team,
      if (snapshot?.season.isNotEmpty == true) snapshot!.season,
      if (snapshot?.source.isNotEmpty == true) snapshot!.source,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cb.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  athlete.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge,
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '${athlete.name} profilja',
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_outward),
          ),
        ],
      ),
    );
  }
}

/// Egy mérőszám két oldala egymás mellett; a jobb érték kiemelve.
class _MetricPair extends StatelessWidget {
  const _MetricPair({
    required this.metric,
    required this.left,
    required this.right,
  });

  final CompareMetric metric;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final winner = compareMetric(metric, left, right);
    final hint = metric.higherIsBetter ? null : 'kevesebb a jobb';
    final tie = winner == CompareWinner.tie ? 'egyenlő' : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MetricTile(
            key: ValueKey('compare-${metric.id}-left'),
            label: metric.label,
            value: metric.format(left),
            caption: tie ?? hint,
            highlighted: winner == CompareWinner.left,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            key: ValueKey('compare-${metric.id}-right'),
            label: metric.label,
            value: metric.format(right),
            caption: tie ?? hint,
            highlighted: winner == CompareWinner.right,
          ),
        ),
      ],
    );
  }
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend({
    required this.left,
    required this.right,
    required this.leftColor,
    required this.rightColor,
  });

  final String left;
  final String right;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    Widget entry(String name, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .25),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(name, style: context.text.labelLarge),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [entry(left, leftColor), entry(right, rightColor)],
    );
  }
}
