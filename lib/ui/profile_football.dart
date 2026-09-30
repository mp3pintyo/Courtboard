part of '../main.dart';

class _FootballSeasonSummaryCard extends StatelessWidget {
  const _FootballSeasonSummaryCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  @override
  Widget build(BuildContext context) => DataSourceCard<FootballSeasonResult>(
    title: 'Szezon összesítő',
    icon: Icons.leaderboard_outlined,
    accent: accent,
    reloadKey: (athleteName, teamName, config.apiSportsKey),
    refreshTooltip: 'Szezonadatok frissítése',
    loadingLabel: 'Szezonadatok betöltése…',
    errorPrefix: 'Nem érkezett friss szezonadat. ',
    emptyMessage: 'Az aktuális vagy előző szezonhoz nincs elérhető adat.',
    isEmpty: (result) => result.stats.isEmpty,
    emptyFooter: (context, result) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final error in result.errors) CourtboardNote(error)],
    ),
    load: ({required force}) =>
        FootballSeasonRepository(config).fetchWithStatus(athleteName, teamName),
    freshness: (result) => result.fetchedAt == null
        ? null
        : DataFreshness(result.fetchedAt!, fromCache: result.fromCache),
    builder: (context, result) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < result.stats.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 18),
          ],
          _FootballSeasonStatPanel(stat: result.stats[i]),
        ],
        for (final error in result.errors) CourtboardNote(error),
      ],
    ),
  );
}

class _FootballSeasonStatPanel extends StatelessWidget {
  const _FootballSeasonStatPanel({required this.stat});
  final FootballSeasonStat stat;

  @override
  Widget build(BuildContext context) => SeasonSummaryPanel(
    title: stat.team,
    subtitle: '${stat.competition} · ${stat.season}',
    source: stat.source,
    metrics: [
      ('ÉRTÉKELÉS ÁTLAG', formatDecimal(stat.rating, digits: 2)),
      ('MÉRKŐZÉS', formatInt(stat.appearances)),
      ('GÓL', formatInt(stat.goals)),
      ('GÓLPASSZ', formatInt(stat.assists)),
      ('SÁRGA LAP', formatInt(stat.yellowCards)),
      ('PIROS LAP', formatInt(stat.redCards)),
    ],
  );
}

class _FootballDataCard extends StatelessWidget {
  const _FootballDataCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });
  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  static MatchOutcome _outcome(FootballResult result) => switch (result) {
    FootballResult.win => MatchOutcome.win,
    FootballResult.loss => MatchOutcome.loss,
    FootballResult.draw => MatchOutcome.draw,
    FootballResult.unknown => MatchOutcome.upcoming,
  };

  Widget _gameRow(FootballGame game) => MatchRow(
    date: game.date,
    opponent: 'vs. ${game.opponent}',
    score: game.score,
    outcome: _outcome(game.result),
  );

  @override
  Widget build(BuildContext context) => DataSourceCard<FootballTeamGames>(
    title: 'Csapatmérkőzések',
    provider: 'Élő adatforrás',
    subtitle: '$teamName · valódi eredmények',
    icon: Icons.sports_soccer,
    accent: accent,
    reloadKey: (teamName, config.footballDataKey),
    refreshTooltip: 'Mérkőzések frissítése',
    loadingLabel: 'Mérkőzések lekérése…',
    emptyMessage: 'Nem található friss vagy közelgő csapatmérkőzés.',
    emptyIcon: Icons.event_busy_outlined,
    isEmpty: (data) => data.recent.isEmpty && data.upcoming.isEmpty,
    emptyFooter: (context, data) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final warning in data.warnings) CourtboardNote(warning)],
    ),
    load: ({required force}) => _withHighlights(
      athleteName,
      FootballDataRepository(
        SportsApiClient(config: config),
      ).fetchTeamGames(teamName),
      (data) => [
        for (final game in [...data.recent, ...data.upcoming])
          _highlight(
            game.date,
            'vs. ${game.opponent}',
            _outcome(game.result),
            game.result == FootballResult.unknown ? null : game.score,
          ),
      ],
    ),
    builder: (context, data) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.recent.isNotEmpty) ...[
          const SubsectionLabel('LEJÁTSZOTT MÉRKŐZÉSEK'),
          ...data.recent.map(_gameRow),
        ],
        if (data.upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SubsectionLabel('KÖVETKEZŐ MÉRKŐZÉSEK'),
          ...data.upcoming.map(_gameRow),
        ],
        for (final warning in data.warnings) CourtboardNote(warning),
      ],
    ),
  );
}

class _FootballDataPlayerCard extends StatelessWidget {
  const _FootballDataPlayerCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  @override
  Widget build(
    BuildContext context,
  ) => DataSourceCard<FootballDataPlayerProfile?>(
    title: 'Játékosprofil',
    provider: 'football-data.org',
    icon: Icons.badge_outlined,
    accent: accent,
    reloadKey: (athleteName, teamName, config.footballDataKey),
    refreshTooltip: 'Játékosadat frissítése',
    loadingLabel: 'Játékosadat lekérése…',
    emptyMessage:
        'A játékos nem található az ingyenes versenysorozatok aktuális kereteiben.',
    emptyIcon: Icons.person_search_outlined,
    load: ({required force}) => FootballDataPlayerRepository(
      SportsApiClient(config: config),
    ).findPlayer(athleteName, teamName),
    builder: (context, profile) => _FootballDataPlayerFacts(profile: profile!),
  );
}

class _FootballDataPlayerFacts extends StatelessWidget {
  const _FootballDataPlayerFacts({required this.profile});

  final FootballDataPlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final birth = profile.dateOfBirth;
    final facts = [
      ('CSAPAT', profile.team),
      ('POSZT', profile.position ?? '—'),
      ('NEMZETISÉG', profile.nationality ?? '—'),
      ('SZÜLETÉSI DÁTUM', birth == null ? '—' : formatDateText(birth)),
      ('MEZSZÁM', profile.shirtNumber?.toString() ?? '—'),
      ('PLAYER ID', profile.id.toString()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(profile.name, style: context.text.titleLarge),
        const SizedBox(height: 12),
        MetricGrid(
          minTileWidth: 170,
          maxColumns: 6,
          children: [
            for (final (label, value) in facts)
              MetricTile(label: label, value: value),
          ],
        ),
      ],
    );
  }
}

class _LigaFCard extends StatelessWidget {
  const _LigaFCard({required this.athleteName, required this.accent});
  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context) => DataSourceCard<List<LigaFGame>>(
    title: 'FC Barcelona Femení · Liga F',
    provider: 'ESPN · esp.w.1',
    subtitle:
        'Valós női Barcelona csapateredmények; nem a férfi FC Barcelona feedje.',
    icon: Icons.sports_soccer,
    accent: accent,
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'Liga F eredmények betöltése…',
    emptyMessage: 'Nincs befejezett Barcelona-meccs ebben az évben.',
    emptyIcon: Icons.event_busy_outlined,
    isEmpty: (games) => games.isEmpty,
    load: ({required force}) => _withHighlights(
      athleteName,
      LigaFRepository().recentBarcelonaGames(),
      (games) => [
        for (final game in games)
          _highlight(
            game.date,
            game.opponent,
            MatchOutcome.parse(game.result),
            game.score,
          ),
      ],
    ),
    builder: (context, games) => LigaFGameList(games: games, accent: accent),
  );
}

class LigaFGameList extends StatelessWidget {
  const LigaFGameList({super.key, required this.games, required this.accent});
  final List<LigaFGame> games;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final game in games)
        MatchRow(
          date: game.date,
          venue: game.home ? 'Hazai' : 'Idegen',
          opponent: game.opponent,
          subtitle: 'Liga F',
          score: game.score,
          outcome: MatchOutcome.parse(game.result),
        ),
    ],
  );
}
