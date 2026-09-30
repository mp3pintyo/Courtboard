part of '../main.dart';

/// Az NBA-profil élő adatai: az egyesített játékosadat (meccsnaplóval) és —
/// a formagörbe átlagvonalához — a szezonösszesítő, ha elérhető. A
/// szezonösszesítő ugyanabból a gyorsítótárból jön, mint a „Szezon
/// összesítő” kártyáé (az egyidejű kérést a gyorsítótár összevonja).
class _NbaProfileBundle {
  const _NbaProfileBundle(this.data, this.season);
  final UnifiedAthleteData data;
  final BasketballSeasonStat? season;
}

class _ApiSportsCard extends StatelessWidget {
  const _ApiSportsCard({
    required this.sport,
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });
  final String sport;
  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  Future<Object> _load() {
    final repo = ApiSportsRepository(config.apiSportsKey);
    return switch (sport) {
      'Foci' => repo.footballRecent(teamName),
      'NBA' => _loadNba(),
      _ => repo.nflPlayer(athleteName),
    };
  }

  Future<_NbaProfileBundle> _loadNba() async {
    final season = BasketballReferenceRepository()
        .seasonSummary(athleteName)
        .then<BasketballSeasonStat?>(
          (value) => value,
          onError: (Object _) => null,
        );
    final data = await MultiProviderAthleteRepository(
      config,
    ).fetchNbaPlayer(athleteName);
    // A Basketball Reference szezonátlaga, tartalékként az ESPN-é.
    return _NbaProfileBundle(data, await season ?? data.espnSeason);
  }

  @override
  Widget build(BuildContext context) {
    final nba = sport == 'NBA';
    return DataSourceCard<Object>(
      title: nba ? 'Játékosadatok és meccsnapló' : '$sport játékosadat',
      provider: nba ? 'Egyesített források' : 'API-Sports',
      icon: nba ? Icons.sports_basketball : Icons.sports_football,
      accent: accent,
      reloadKey: (
        sport,
        athleteName,
        teamName,
        config.apiSportsKey,
        config.balldontlieKey,
      ),
      loadingLabel: 'Játékosadatok betöltése…',
      load: ({required force}) => _withHighlights(
        athleteName,
        _load(),
        (data) => switch (data) {
          final List<ApiSportsGame> games => [
            for (final game in games)
              _highlight(
                game.date,
                game.opponent,
                MatchOutcome.parse(game.result),
                game.score,
              ),
          ],
          final _NbaProfileBundle bundle => [
            for (final game in bundle.data.games)
              _highlight(
                game.date,
                game.opponent,
                MatchOutcome.parse(game.outcome),
                game.score,
              ),
          ],
          _ => const <HighlightEvent>[],
        },
      ),
      builder: (context, data) => switch (data) {
        final List<ApiSportsGame> games => Column(
          children: [
            for (final game in games)
              MatchRow(
                date: game.date,
                opponent: game.opponent,
                score: game.score,
                outcome: MatchOutcome.parse(game.result),
              ),
          ],
        ),
        final _NbaProfileBundle bundle => UnifiedAthleteFacts(
          data: bundle.data,
          accent: accent,
          season: bundle.season,
        ),
        _ => EmptyState(
          compact: true,
          message:
              '$athleteName: a szolgáltató nem adott megjeleníthető adatot.',
        ),
      },
    );
  }
}

class _NbaSeasonSummaryCard extends StatelessWidget {
  const _NbaSeasonSummaryCard({
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context) => DataSourceCard<BasketballSeasonStat?>(
    title: 'Szezon összesítő',
    icon: Icons.leaderboard_outlined,
    accent: accent,
    reloadKey: athleteName,
    refreshTooltip: 'Szezonadatok frissítése',
    loadingLabel: 'NBA szezonadatok betöltése…',
    errorPrefix: 'A friss NBA szezonösszesítő most nem érhető el. ',
    emptyMessage: 'Ehhez a játékoshoz nincs friss NBA szezonadat.',
    // Basketball Reference; ha nem érhető el vagy nincs sora, az ESPN
    // meccsnaplójából számolt alapszakasz-összesítő.
    load: ({required force}) => nbaSeasonSummaryWithFallback(
      athleteName,
      forceRefresh: force,
    ).then((cached) => cached?.value),
    builder: (context, summary) =>
        BasketballSeasonSummaryFacts(summary: summary!, accent: accent),
  );
}

/// NBA-szezonösszesítő (Basketball Reference) a közös
/// [SeasonSummaryPanel]-lel — ugyanaz a nézet, mint a WNBA-é.
class BasketballSeasonSummaryFacts extends StatelessWidget {
  const BasketballSeasonSummaryFacts({
    super.key,
    required this.summary,
    required this.accent,
  });

  final BasketballSeasonStat summary;
  final Color accent;

  @override
  Widget build(BuildContext context) => SeasonSummaryPanel(
    title: summary.team.isEmpty ? summary.league : summary.team,
    subtitle: '${summary.league} · ${summary.season}',
    source: summary.source,
    accent: accent,
    metrics: [
      ('MÉRKŐZÉS', formatInt(summary.games)),
      ('PERC / MECCS', formatDecimal(summary.minutesPerGame)),
      ('PONT / MECCS', formatDecimal(summary.pointsPerGame)),
      ('LEPATTANÓ / MECCS', formatDecimal(summary.reboundsPerGame)),
      ('ASSZISZT / MECCS', formatDecimal(summary.assistsPerGame)),
      ('LABDASZERZÉS / MECCS', formatDecimal(summary.stealsPerGame)),
      ('ELADOTT LABDA / MECCS', formatDecimal(summary.turnoversPerGame)),
      ('FG%', formatPercent(summary.fieldGoalPercentage)),
    ],
  );
}
