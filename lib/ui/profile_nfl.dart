part of '../main.dart';

/// NFL-játékos meccsnaplója (ESPN, kulcs nélkül, 6 órás gyorsítótár):
/// szezonösszesítő, szerepkör szerinti formagörbe és legutóbbi meccsek.
class _NflPlayerCard extends StatelessWidget {
  const _NflPlayerCard({required this.athleteName, required this.accent});

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context) => DataSourceCard<EspnGameLog?>(
    title: 'Játékos-meccsnapló',
    provider: 'ESPN',
    subtitle: 'Szezonösszesítő, formagörbe és a legutóbbi meccsek.',
    icon: Icons.sports_football,
    accent: accent,
    reloadKey: athleteName,
    refreshTooltip: 'Meccsnapló frissítése',
    loadingLabel: 'NFL-meccsnapló betöltése…',
    errorPrefix: 'Az ESPN NFL-meccsnaplója most nem érhető el. ',
    emptyMessage:
        'Az ESPN nem talált ilyen nevű NFL-játékost, vagy még nincs '
        'lejátszott meccse ebben a szezonban.',
    emptyIcon: Icons.person_search_outlined,
    isEmpty: (log) => log == null || log.games.isEmpty,
    load: ({required force}) => _withHighlights(
      athleteName,
      EspnAthleteRepository().gameLog(
        athleteName,
        EspnLeague.nfl,
        forceRefresh: force,
      ),
      (log) => [
        for (final game in log?.games.take(8) ?? const <EspnGameLogEntry>[])
          _highlight(
            game.date,
            game.opponent,
            MatchOutcome.parse(game.outcome),
            game.score.isEmpty ? null : game.score,
          ),
      ],
    ),
    freshness: (log) => log?.fetchedAt == null
        ? null
        : DataFreshness(
            log!.fetchedAt!,
            fromCache: log.fromCache,
            stale: log.stale,
          ),
    builder: (context, log) => NflGameLogView(log: log!, accent: accent),
  );
}

/// Az NFL-meccsnapló nézete (külön osztály, hogy tesztelhető legyen).
class NflGameLogView extends StatelessWidget {
  const NflGameLogView({super.key, required this.log, required this.accent});

  final EspnGameLog log;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final athlete = log.athlete;
    final stat = NflFormStat.pick(log);
    final points = stat == null
        ? const <FormPoint>[]
        : nflFormPoints(log, stat);
    final identity = [
      if (athlete.team.isNotEmpty) athlete.team,
      if (athlete.position.isNotEmpty) athlete.position,
      if (athlete.jersey.isNotEmpty) '#${athlete.jersey}',
    ].join(' · ');
    return Column(
      key: const Key('nfl-player-log'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeasonSummaryPanel(
          title: identity.isEmpty ? athlete.displayName : identity,
          subtitle:
              'NFL ${log.season} · alapszakasz'
              '${log.regularSeason.isEmpty ? '' : ' · ${log.regularSeason.length} meccs'}',
          source: 'ESPN',
          metrics: [
            for (final (label, value, digits) in nflSeasonLines(log))
              (
                label,
                digits == 0
                    ? formatInt(value)
                    : formatDecimal(value, digits: digits),
              ),
          ],
        ),
        if (stat != null && FormChart.canShow(points)) ...[
          const SizedBox(height: 22),
          SubsectionLabel(
            'FORMA · ${stat.code} · UTOLSÓ ${points.length} MECCS',
            icon: Icons.show_chart_rounded,
            color: accent,
          ),
          FormChart(
            points: points,
            unit: stat.unit,
            average: log.perGame(stat.statName) ?? averageOf(points),
            averageLabel: log.perGame(stat.statName) == null
                ? 'Átlag'
                : 'Szezonátlag',
            color: accent,
          ),
        ],
        const SizedBox(height: 22),
        SubsectionLabel(
          'LEGUTÓBBI MECCSEK · ESPN',
          icon: Icons.sports_football,
          color: accent,
        ),
        for (final game in log.games.take(5))
          MatchRow(
            date: game.date,
            venue: game.homeAway == 'away' ? 'Idegen' : 'Hazai',
            opponent: game.opponent,
            subtitle: [
              nflGameSummary(game),
              if (game.phase == EspnSeasonPhase.postseason)
                game.note.isEmpty ? 'Rájátszás' : game.note,
            ].where((part) => part.isNotEmpty).join(' · '),
            score: game.score.isEmpty ? null : game.score,
            outcome: MatchOutcome.parse(game.outcome),
          ),
      ],
    );
  }
}
