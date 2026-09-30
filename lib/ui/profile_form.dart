part of '../main.dart';

/// Kosárlabda-formagörbe (NBA / WNBA): PTS / REB / AST választó, a
/// meccsenkénti értékek GY/V színű pontokkal és a szezonátlag szaggatott
/// vonala. Két meccs alatt egyáltalán nem jelenik meg.
class BasketballFormSection extends StatefulWidget {
  const BasketballFormSection({
    super.key,
    required this.games,
    required this.accent,
    this.seasonAverage,
    this.ranges = const [],
  });

  /// A mérkőzések (bármilyen sorrendben; a legfrissebbek számítanak).
  final List<BoxScoreLine> games;
  final Color accent;

  /// A választott mérőszám szezonátlaga; `null` esetén a látható meccsek
  /// átlaga kerül a vonalra („Átlag”).
  final double? Function(BasketballStat stat)? seasonAverage;

  /// Választható meccsszámok (0 = teljes szezon); üres: nincs választó.
  final List<(int, String)> ranges;

  @override
  State<BasketballFormSection> createState() => _BasketballFormSectionState();
}

class _BasketballFormSectionState extends State<BasketballFormSection> {
  BasketballStat _stat = BasketballStat.points;
  late int _range = widget.ranges.isEmpty ? 0 : widget.ranges.first.$1;

  @override
  Widget build(BuildContext context) {
    final recent = [...widget.games]..sort((a, b) => b.date.compareTo(a.date));
    final shown = _range == 0 ? recent : recent.take(_range).toList();
    final points = basketballFormPoints(shown, _stat);
    if (!FormChart.canShow(points)) return const SizedBox.shrink();
    final season = widget.seasonAverage?.call(_stat);
    final average = season ?? averageOf(points);
    return Column(
      key: const Key('basketball-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'FORMA · ${_stat.unit.toUpperCase()} · '
                'UTOLSÓ ${points.length} MECCS',
                style: context.text.labelMedium?.copyWith(
                  color: context.cb.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final stat in BasketballStat.values)
              ChoiceChip(
                key: ValueKey('form-stat-${stat.code}'),
                label: Text(stat.code),
                tooltip: stat.unit,
                selected: _stat == stat,
                onSelected: (_) => setState(() => _stat = stat),
              ),
            if (widget.ranges.isNotEmpty) const SizedBox(width: 10),
            for (final (count, label) in widget.ranges)
              ChoiceChip(
                label: Text(label),
                selected: _range == count,
                onSelected: (_) => setState(() => _range = count),
              ),
          ],
        ),
        const SizedBox(height: 14),
        FormChart(
          points: points,
          unit: _stat.unit,
          average: average,
          averageLabel: season == null ? 'Átlag' : 'Szezonátlag',
          color: widget.accent,
        ),
      ],
    );
  }
}

/// Foci-formagörbe a FotMob legutóbbi meccseiből: értékelés, ha legalább
/// két meccsen van, különben gól + gólpassz. Két pont alatt rejtett.
class FootballFormPanel extends StatelessWidget {
  const FootballFormPanel({
    super.key,
    required this.matches,
    this.seasonRating,
    this.accent,
  });

  final List<FootballMatchForm> matches;

  /// A szezon átlagértékelése (szaggatott vonal az értékelés-görbén).
  final double? seasonRating;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final metric = pickFootballMetric(matches);
    final points = footballFormPoints(matches, metric);
    if (!FormChart.canShow(points)) return const SizedBox.shrink();
    final rating = metric == FootballFormMetric.rating;
    return Column(
      key: const Key('football-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionLabel(
          rating
              ? 'FORMA · FOTMOB-ÉRTÉKELÉS · UTOLSÓ ${points.length} MECCS'
              : 'FORMA · GÓL + GÓLPASSZ · UTOLSÓ ${points.length} MECCS',
          icon: Icons.show_chart_rounded,
          color: accent,
        ),
        FormChart(
          points: points,
          unit: metric.unit,
          digits: metric.digits,
          zeroBased: !rating,
          average: rating
              ? seasonRating ?? averageOf(points)
              : averageOf(points),
          averageLabel: rating && seasonRating != null
              ? 'Szezonátlag'
              : 'Átlag',
          color: accent,
        ),
      ],
    );
  }
}

/// Teniszezőnél a helyben gyűjtött ranglistapont-történet (naponta egy
/// mérés a profil betöltésekor). Két mérés alatt rejtett.
class TennisRankingForm extends StatelessWidget {
  const TennisRankingForm({super.key, required this.history, this.accent});

  final List<RankingSnapshot> history;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final points = tennisRankingPointsForm(history);
    if (!FormChart.canShow(points)) return const SizedBox.shrink();
    return Column(
      key: const Key('tennis-ranking-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionLabel(
          'RANGLISTAPONT-TÖRTÉNET · ${points.length} MÉRÉS',
          icon: Icons.timeline_rounded,
          color: accent,
        ),
        FormChart(
          points: points,
          unit: 'ranglistapont',
          zeroBased: false,
          color: accent,
          scope: (count) => 'Az utolsó $count mérésnél',
        ),
        const SizedBox(height: 6),
        Text(
          'A Courtboard a profil megnyitásakor naponta egyszer rögzíti a '
          'ranglistát; a görbe ezekből a helyi mérésekből áll.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

/// NFL: a csapat legutóbbi befejezett mérkőzései (ESPN, óránkénti
/// gyorsítótár) csapatpont-görbével és eredménysorral. Játékosszintű
/// meccsnapló nincs az ingyenes forrásokban, ezért a csapatforma látszik.
class _NflTeamFormCard extends StatelessWidget {
  const _NflTeamFormCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
  });

  final String athleteName;
  final String teamName;
  final Color accent;

  Future<List<EspnCompletedGame>> _load({required bool force}) async {
    final repository = EspnScheduleRepository();
    final team = await repository.findTeam(EspnLeague.nfl, teamName);
    if (team == null) {
      throw StateError('Az ESPN nem ismeri ezt az NFL-csapatot: $teamName');
    }
    return repository.recentResults(
      EspnLeague.nfl,
      team,
      limit: 8,
      forceRefresh: force,
    );
  }

  @override
  Widget build(BuildContext context) => DataSourceCard<List<EspnCompletedGame>>(
    title: 'Csapatforma',
    provider: 'ESPN',
    subtitle: '$teamName · a legutóbbi befejezett mérkőzések',
    icon: Icons.show_chart_rounded,
    accent: accent,
    reloadKey: (athleteName, teamName),
    refreshTooltip: 'Csapatforma frissítése',
    loadingLabel: 'NFL-eredmények betöltése…',
    errorPrefix: 'Az NFL-csapateredmények most nem érhetők el. ',
    emptyMessage:
        'Még nincs legalább két befejezett mérkőzés a csapatformához.',
    emptyIcon: Icons.event_busy_outlined,
    placeholder: teamName.trim().isEmpty
        ? const EmptyState(
            compact: true,
            icon: Icons.groups_outlined,
            message: 'A csapatformához add meg a sportoló csapatát.',
          )
        : null,
    isEmpty: (games) => !FormChart.canShow(teamScoreForm(games)),
    load: ({required force}) => _withHighlights(
      athleteName,
      _load(force: force),
      (games) => [
        for (final game in games)
          _highlight(
            game.start,
            game.opponent,
            MatchOutcome.parse(game.outcome),
            game.score.isEmpty ? null : game.score,
          ),
      ],
    ),
    builder: (context, games) {
      final points = teamScoreForm(games);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubsectionLabel(
            'CSAPATPONTOK · UTOLSÓ ${points.length} MECCS',
            icon: Icons.sports_football,
            color: accent,
          ),
          FormChart(
            points: points,
            unit: 'pont',
            average: averageOf(points),
            averageLabel: 'Átlag',
            color: accent,
          ),
          const SizedBox(height: 16),
          ResultStrip(
            results: [
              for (final point in points)
                ResultMark(
                  date: point.date,
                  title: point.opponent,
                  outcome: point.outcome,
                  score: point.score,
                ),
            ],
          ),
        ],
      );
    },
  );
}
