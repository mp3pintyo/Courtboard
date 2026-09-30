/// A profil formagörbéi: a sportág [FormChartKind]-ja dönti el, melyik
/// diagram készül ([SportFormChart]), a bemenet a kártyák már letöltött
/// adata ([FormChartData]). Kitalált adatot nem rajzolunk: két adatpont
/// alatt semmi nem jelenik meg.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/ranking_history.dart';
import 'package:courtboard/features/profile/form_data.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// Milyen formagörbét rajzolnak a sportág élő adatkártyái (a sportág
/// [SportProfileSpec]-je adja meg).
enum FormChartKind {
  /// Meccsnaplóból (pont, lepattanó, gólpassz) — NBA, WNBA.
  basketballGameLog,

  /// Mérkőzésenkénti értékelés vagy gól + gólpassz — foci.
  footballMatches,

  /// Ranglistapontok időben — tenisz.
  tennisRanking,

  /// Győzelem/vereség sáv a legutóbbi eredményekből — darts.
  dartsResults,

  /// A szerepkörhöz illő heti mutató (yard, szerelés) — NFL.
  nflGameLog,
}

/// A formagörbe bemenete: egy kártya már letöltött adata.
sealed class FormChartData {
  const FormChartData();
}

/// Kosárlabda-meccsnapló (NBA / WNBA).
class BasketballFormData extends FormChartData {
  const BasketballFormData(
    this.games, {
    this.seasonAverage,
    this.ranges = const [],
  });

  final List<BoxScoreLine> games;

  /// A választott mérőszám szezonátlaga (lásd [BasketballFormSection]).
  final double? Function(BasketballStat stat)? seasonAverage;

  /// Választható meccsszámok (0 = teljes szezon).
  final List<(int, String)> ranges;
}

/// Foci: a legutóbbi meccsek (FotMob) és a szezon átlagértékelése.
class FootballFormData extends FormChartData {
  const FootballFormData(this.matches, {this.seasonRating});

  final List<FootballMatchForm> matches;
  final double? seasonRating;
}

/// Tenisz: a helyben gyűjtött ranglista-történet.
class TennisFormData extends FormChartData {
  const TennisFormData(this.history);

  final List<RankingSnapshot> history;
}

/// Darts: a TheSportsDB eredménysorai.
class DartsFormData extends FormChartData {
  const DartsFormData(this.results);

  final List<DartsResult> results;
}

/// NFL: a játékos ESPN-meccsnaplója.
class NflFormData extends FormChartData {
  const NflFormData(this.log);

  final EspnGameLog log;
}

/// A sportág formagörbéje a [kind] szerint (a [SportProfileSpec]-ből): a
/// sportágankénti elágazás egyetlen helyen. Ha az adat nem illik a
/// típushoz, vagy nincs legalább két pont, semmit nem rajzol (a [leading] /
/// [trailing] térköz sem jelenik meg).
class SportFormChart extends StatelessWidget {
  const SportFormChart({
    super.key,
    required this.kind,
    required this.data,
    this.accent,
    this.leading = 22,
    this.trailing = 0,
  });

  final FormChartKind kind;
  final FormChartData data;

  /// A sportoló kiemelőszíne; `null` esetén a téma színe.
  final Color? accent;

  /// Térköz a diagram előtt és után (csak ha megjelenik).
  final double leading;
  final double trailing;

  /// Van-e rajzolható görbe a [kind] és a [data] alapján.
  static bool canShow(FormChartKind kind, FormChartData data) =>
      switch ((kind, data)) {
        (FormChartKind.basketballGameLog, final BasketballFormData data) =>
          data.games.length >= minChartPoints,
        (FormChartKind.footballMatches, final FootballFormData data) =>
          data.matches.length >= minChartPoints,
        (FormChartKind.tennisRanking, final TennisFormData data) =>
          tennisRankingPointsForm(data.history).length >= minChartPoints,
        (FormChartKind.dartsResults, final DartsFormData data) =>
          ResultStrip.canShow(dartsResultMarks(data.results)),
        (FormChartKind.nflGameLog, final NflFormData data) =>
          _NflPlayerForm.canShow(data.log),
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    if (!canShow(kind, data)) return const SizedBox.shrink();
    final chart = switch (data) {
      final BasketballFormData data => BasketballFormSection(
        games: data.games,
        accent: accent ?? context.cb.accent,
        seasonAverage: data.seasonAverage,
        ranges: data.ranges,
      ),
      final FootballFormData data => FootballFormPanel(
        matches: data.matches,
        seasonRating: data.seasonRating,
        accent: accent,
      ),
      final TennisFormData data => TennisRankingForm(
        history: data.history,
        accent: accent,
      ),
      final DartsFormData data => _DartsResultForm(
        results: data.results,
        accent: accent,
      ),
      final NflFormData data => _NflPlayerForm(log: data.log, accent: accent),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading > 0) SizedBox(height: leading),
        chart,
        if (trailing > 0) SizedBox(height: trailing),
      ],
    );
  }
}

/// Darts: győzelem/vereség eredménysor.
class _DartsResultForm extends StatelessWidget {
  const _DartsResultForm({required this.results, this.accent});

  final List<DartsResult> results;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SubsectionLabel(
        'FORMA · EREDMÉNYSOR',
        icon: Icons.show_chart_rounded,
        color: accent,
      ),
      ResultStrip(results: dartsResultMarks(results)),
    ],
  );
}

/// NFL: a szerepkörhöz illő mutató (yard, szerelés) meccsenként, a
/// szezonátlag (vagy a látható meccsek átlaga) vonalával.
class _NflPlayerForm extends StatelessWidget {
  const _NflPlayerForm({required this.log, this.accent});

  final EspnGameLog log;
  final Color? accent;

  static bool canShow(EspnGameLog log) {
    final stat = NflFormStat.pick(log);
    return stat != null && FormChart.canShow(nflFormPoints(log, stat));
  }

  @override
  Widget build(BuildContext context) {
    final stat = NflFormStat.pick(log)!;
    final points = nflFormPoints(log, stat);
    final season = log.perGame(stat.statName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionLabel(
          'FORMA · ${stat.code} · UTOLSÓ ${points.length} MECCS',
          icon: Icons.show_chart_rounded,
          color: accent,
        ),
        FormChart(
          points: points,
          unit: stat.unit,
          average: season ?? averageOf(points),
          averageLabel: season == null ? 'Átlag' : 'Szezonátlag',
          color: accent,
        ),
      ],
    );
  }
}

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
/// Az adat a [nflTeamFormProvider]-ből jön.
class NflTeamFormCard extends ConsumerWidget {
  const NflTeamFormCard({
    super.key,
    required this.athleteName,
    required this.teamName,
    required this.accent,
  });

  final String athleteName;
  final String teamName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = teamName.trim().isEmpty
        ? const EmptyState(
            compact: true,
            icon: Icons.groups_outlined,
            message: 'A csapatformához add meg a sportoló csapatát.',
          )
        : null;
    final request = (athlete: athleteName, team: teamName);
    return AsyncDataSourceCard<List<EspnCompletedGame>>(
      title: 'Csapatforma',
      provider: 'ESPN',
      subtitle: '$teamName · a legutóbbi befejezett mérkőzések',
      icon: Icons.show_chart_rounded,
      accent: accent,
      value: placeholder == null
          ? ref.watch(nflTeamFormProvider(request))
          : const AsyncLoading(),
      onRefresh: () =>
          unawaited(ref.read(nflTeamFormProvider(request).notifier).refresh()),
      refreshTooltip: 'Csapatforma frissítése',
      loadingLabel: 'NFL-eredmények betöltése…',
      errorPrefix: 'Az NFL-csapateredmények most nem érhetők el. ',
      emptyMessage:
          'Még nincs legalább két befejezett mérkőzés a csapatformához.',
      emptyIcon: Icons.event_busy_outlined,
      placeholder: placeholder,
      isEmpty: (games) => !FormChart.canShow(teamScoreForm(games)),
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
}
