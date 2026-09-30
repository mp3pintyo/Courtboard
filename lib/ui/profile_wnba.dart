part of '../main.dart';

class _WnbaWehoopCard extends StatelessWidget {
  const _WnbaWehoopCard({required this.athleteName, required this.accent});
  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context) => DataSourceCard<WnbaGamesResult>(
    title: 'WNBA meccsnapló',
    provider: 'wehoop · ESPN',
    subtitle:
        'SportsDataverse / wehoop WNBA player boxscores · CC BY 4.0; '
        'tartalék: ESPN játékos-meccsnapló',
    icon: Icons.data_usage_rounded,
    accent: accent,
    reloadKey: athleteName,
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'WNBA box score-ok letöltése és helyi gyorsítótárazása…',
    errorPrefix: 'A wehoop WNBA-adat most nem érhető el. ',
    emptyMessage:
        'Ehhez a játékoshoz nem érkezett 2026-os wehoop box score rekord.',
    isEmpty: (result) => result.games.isEmpty,
    load: ({required force}) => _withHighlights(
      athleteName,
      wnbaGamesWithFallback(athleteName, forceRefresh: force),
      (result) => [
        for (final game in result.games)
          _highlight(
            game.date,
            game.opponent,
            switch (game.result) {
              WnbaResult.win => MatchOutcome.win,
              WnbaResult.loss => MatchOutcome.loss,
              WnbaResult.unknown => MatchOutcome.unknown,
            },
            game.teamScore == 0 && game.opponentScore == 0 ? null : game.score,
          ),
      ],
    ),
    builder: (context, result) => _WnbaLiveData(
      games: result.games,
      accent: accent,
      source: result.source,
      note: result.note,
    ),
  );
}

class _WnbaBasketballReferenceCard extends StatelessWidget {
  const _WnbaBasketballReferenceCard({
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(
    BuildContext context,
  ) => DataSourceCard<CachedValue<List<NbaGameLog>>>(
    title: 'Kiegészítő meccsnapló',
    provider: 'Basketball Reference',
    subtitle:
        'A wehoop mellett közvetlen Basketball Reference játékos-meccsnapló.',
    icon: Icons.fact_check_outlined,
    accent: accent,
    reloadKey: athleteName,
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'Basketball Reference WNBA-adatok letöltése…',
    load: ({required force}) => _withHighlights(
      athleteName,
      BasketballReferenceRepository().recentGamesCached(
        athleteName,
        league: 'wnba',
      ),
      (cached) => [
        for (final game in cached.value)
          _highlight(
            game.date,
            game.opponent,
            MatchOutcome.parse(game.outcome),
            game.score,
          ),
      ],
    ),
    freshness: (cached) => cached.value.isEmpty
        ? null
        : DataFreshness(
            cached.fetchedAt,
            fromCache: cached.fromCache,
            stale: cached.stale,
          ),
    builder: (context, cached) => BasketballReferenceGameList(
      games: cached.value,
      accent: accent,
      league: 'WNBA',
    ),
  );
}

class _WnbaRapidApiCard extends StatelessWidget {
  const _WnbaRapidApiCard({
    required this.athleteName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  Widget build(BuildContext context) => DataSourceCard<WnbaRapidProfile?>(
    title: 'Játékosbio és haladó statisztika',
    provider: 'RapidAPI · 7 napos cache',
    icon: Icons.analytics_outlined,
    accent: accent,
    reloadKey: (athleteName, config.rapidApiKey),
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'WNBA játékosadatok betöltése…',
    emptyMessage: 'A játékos ESPN-azonosítója nem található.',
    emptyIcon: Icons.person_search_outlined,
    placeholder: config.rapidApiKey.isEmpty
        ? const EmptyState(
            compact: true,
            icon: Icons.key_off_outlined,
            message:
                'A RapidAPI-kulcs nincs beállítva. Az Adatforrások oldalon adható meg.',
          )
        : null,
    load: ({required force}) =>
        WnbaRapidApiRepository(config).playerProfile(athleteName),
    freshness: (profile) => profile?.fetchedAt == null
        ? null
        : DataFreshness(profile!.fetchedAt!, fromCache: profile.fromCache),
    builder: (context, profile) =>
        WnbaRapidProfileFacts(profile: profile!, accent: accent),
  );
}

class WnbaRapidProfileFacts extends StatelessWidget {
  const WnbaRapidProfileFacts({
    super.key,
    required this.profile,
    required this.accent,
  });

  final WnbaRapidProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${profile.team ?? 'WNBA'} · ${profile.season ?? 'aktuális szezon'} · ESPN ID ${profile.playerId}',
        style: context.text.bodySmall,
      ),
      const SizedBox(height: 12),
      MetricGrid(
        minTileWidth: 120,
        children: [
          for (final fact in profile.facts)
            MetricTile(
              label: fact.label,
              value: localizeNumberText(fact.value),
            ),
        ],
      ),
      if (profile.awards.isNotEmpty) ...[
        const SizedBox(height: 18),
        const SubsectionLabel('ELISMERÉSEK', icon: Icons.emoji_events_outlined),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final award in profile.awards)
              StatusPill(award, tone: StatusTone.accent),
          ],
        ),
      ],
    ],
  );
}

class _WnbaLiveData extends StatelessWidget {
  const _WnbaLiveData({
    required this.games,
    required this.accent,
    this.source = 'SportsDataverse / wehoop',
    this.note,
  });
  final List<WnbaGameLog> games;
  final Color accent;
  final String source;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note != null) ...[
          CourtboardNote(note!),
          const SizedBox(height: 12),
        ],
        WnbaSeasonSummaryFacts(games: games, source: source),
        if (games.length >= minChartPoints) ...[
          const SizedBox(height: 24),
          BasketballFormSection(
            games: [for (final game in games) BoxScoreLine.fromWnba(game)],
            accent: accent,
            seasonAverage: (stat) => wnbaSeasonAverage(games, stat),
            ranges: const [(5, '5'), (10, '10'), (0, 'Szezon')],
          ),
        ],
        const SizedBox(height: 24),
        const SubsectionLabel('UTÓBBI MÉRKŐZÉSEK · VALÓS ADAT'),
        for (final game in games.take(5))
          MatchRow(
            date: game.date,
            opponent: game.opponent,
            subtitle:
                '${game.points} PTS · ${game.rebounds} REB · ${game.assists} AST',
            score: game.teamScore == 0 && game.opponentScore == 0
                ? null
                : game.score,
            outcome: switch (game.result) {
              WnbaResult.win => MatchOutcome.win,
              WnbaResult.loss => MatchOutcome.loss,
              WnbaResult.unknown => MatchOutcome.unknown,
            },
          ),
      ],
    );
  }
}

/// WNBA-szezonösszesítő a wehoop meccsnaplóból, a közös
/// [SeasonSummaryPanel]-lel — ugyanaz a nézet, mint az NBA-é.
class WnbaSeasonSummaryFacts extends StatelessWidget {
  const WnbaSeasonSummaryFacts({
    super.key,
    required this.games,
    this.source = 'SportsDataverse / wehoop',
  });

  final List<WnbaGameLog> games;
  final String source;

  @override
  Widget build(BuildContext context) {
    final summary = WnbaSeasonSummary.fromGames(games);
    return SeasonSummaryPanel(
      title: games.first.team,
      subtitle: 'WNBA ${games.first.date.year} · szezon összesítő',
      source: source,
      metrics: [
        ('MECCS', formatInt(summary.games)),
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
}
