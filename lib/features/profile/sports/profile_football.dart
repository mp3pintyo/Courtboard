import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_data_players.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/features/profile/form_data.dart';
import 'package:courtboard/features/profile/match_details.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';

class FootballSeasonSummaryCard extends ConsumerWidget {
  const FootballSeasonSummaryCard({
    super.key,
    required this.athleteName,
    required this.teamName,
    required this.accent,
  });

  final String athleteName;
  final String teamName;
  final Color accent;

  FutureProvider<FootballSeasonResult> get _seasonProvider =>
      footballSeasonProvider((athlete: athleteName, team: teamName));

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncDataSourceCard<FootballSeasonResult>(
        title: 'Szezon összesítő',
        icon: Icons.leaderboard_outlined,
        accent: accent,
        value: ref.watch(_seasonProvider),
        onRefresh: () => ref.invalidate(_seasonProvider),
        refreshTooltip: 'Szezonadatok frissítése',
        loadingLabel: 'Szezonadatok betöltése…',
        errorPrefix: 'Nem érkezett friss szezonadat. ',
        emptyMessage: 'Az aktuális vagy előző szezonhoz nincs elérhető adat.',
        isEmpty: (result) => result.stats.isEmpty,
        emptyFooter: (context, result) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final error in result.errors) CourtboardNote(error)],
        ),
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
              _FootballSeasonStatPanel(stat: result.stats[i], accent: accent),
            ],
            for (final error in result.errors) CourtboardNote(error),
          ],
        ),
      );
}

class _FootballSeasonStatPanel extends StatelessWidget {
  const _FootballSeasonStatPanel({required this.stat, this.accent});
  final FootballSeasonStat stat;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SeasonSummaryPanel(
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
      ),
      SportFormChart(
        kind: SportProfileSpec.formChartOf(Sport.football),
        data: FootballFormData(stat.recentMatches, seasonRating: stat.rating),
        accent: accent,
      ),
    ],
  );
}

class FootballDataCard extends ConsumerWidget {
  const FootballDataCard({
    super.key,
    required this.athleteName,
    required this.teamName,
    required this.accent,
  });
  final String athleteName;
  final String teamName;
  final Color accent;

  FutureProvider<FootballTeamGames> get _gamesProvider =>
      footballTeamGamesProvider((athlete: athleteName, team: teamName));

  Widget _gameRow(FootballGame game) => MatchRow(
    date: game.date,
    venue: switch (game.homeAway) {
      'home' => 'Hazai',
      'away' => 'Idegen',
      _ => null,
    },
    opponent: '${game.homeAway == 'away' ? '@' : 'vs.'} ${game.opponent}',
    subtitle: [
      if (game.competition.isNotEmpty) game.competition,
      if (game.source.isNotEmpty) game.source,
    ].join(' · '),
    score: game.score,
    outcome: footballMatchOutcome(game.result),
    footer:
        MatchTimelineExpander.available(
          match: game.espnMatch,
          timeline: game.timeline,
        )
        ? MatchTimelineExpander(match: game.espnMatch, timeline: game.timeline)
        : null,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncDataSourceCard<FootballTeamGames>(
        title: 'Csapatmérkőzések',
        provider: 'Élő adatforrás',
        subtitle: '$teamName · valódi eredmények',
        icon: Icons.sports_soccer,
        accent: accent,
        value: ref.watch(_gamesProvider),
        onRefresh: () => ref.invalidate(_gamesProvider),
        refreshTooltip: 'Mérkőzések frissítése',
        loadingLabel: 'Mérkőzések lekérése…',
        emptyMessage: 'Nem található friss vagy közelgő csapatmérkőzés.',
        emptyIcon: Icons.event_busy_outlined,
        isEmpty: (data) => data.recent.isEmpty && data.upcoming.isEmpty,
        emptyFooter: (context, data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final warning in data.warnings) CourtboardNote(warning),
          ],
        ),
        builder: (context, data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ResultStrip.canShow(footballTeamResultMarks(data.recent))) ...[
              const SubsectionLabel('CSAPATFORMA'),
              ResultStrip(results: footballTeamResultMarks(data.recent)),
              const SizedBox(height: 18),
            ],
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

class FootballDataPlayerCard extends ConsumerWidget {
  const FootballDataPlayerCard({
    super.key,
    required this.athleteName,
    required this.teamName,
    required this.accent,
  });

  final String athleteName;
  final String teamName;
  final Color accent;

  FutureProvider<FootballDataPlayerProfile?> get _playerProvider =>
      footballDataPlayerProvider((athlete: athleteName, team: teamName));

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => AsyncDataSourceCard<FootballDataPlayerProfile?>(
    title: 'Játékosprofil',
    provider: 'football-data.org',
    icon: Icons.badge_outlined,
    accent: accent,
    value: ref.watch(_playerProvider),
    onRefresh: () => ref.invalidate(_playerProvider),
    refreshTooltip: 'Játékosadat frissítése',
    loadingLabel: 'Játékosadat lekérése…',
    emptyMessage:
        'A játékos nem található az ingyenes versenysorozatok aktuális kereteiben.',
    emptyIcon: Icons.person_search_outlined,
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

/// Egy ESPN-bajnokságban (például Liga F) szereplő csapat legutóbbi
/// bajnoki eredményei; a sportoló adatforrás-tippjei adják a ligát és a
/// csapatot. Az adat az [espnSoccerTeamGamesProvider]-ből jön.
class EspnSoccerTeamCard extends ConsumerWidget {
  const EspnSoccerTeamCard({
    super.key,
    required this.athleteName,
    required this.team,
    required this.accent,
  });

  final String athleteName;
  final EspnSoccerTeam team;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (athlete: athleteName, team: team);
    final competition = team.competitionLabel;
    return AsyncDataSourceCard<List<EspnSoccerGame>>(
      title: '${team.displayName} · $competition',
      provider: 'ESPN · ${team.league}',
      subtitle: team.description,
      icon: Icons.sports_soccer,
      accent: accent,
      value: ref.watch(espnSoccerTeamGamesProvider(request)),
      onRefresh: () => unawaited(
        ref.read(espnSoccerTeamGamesProvider(request).notifier).refresh(),
      ),
      refreshTooltip: 'Újratöltés',
      loadingLabel: '$competition eredmények betöltése…',
      emptyMessage: 'Nincs befejezett ${team.team}-meccs ebben az évben.',
      emptyIcon: Icons.event_busy_outlined,
      isEmpty: (games) => games.isEmpty,
      builder: (context, games) =>
          EspnSoccerGameList(games: games, team: team, accent: accent),
    );
  }
}

class EspnSoccerGameList extends StatelessWidget {
  const EspnSoccerGameList({
    super.key,
    required this.games,
    required this.team,
    required this.accent,
  });

  final List<EspnSoccerGame> games;
  final EspnSoccerTeam team;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final game in games)
        MatchRow(
          date: game.date,
          venue: game.home ? 'Hazai' : 'Idegen',
          opponent: game.opponent,
          subtitle: team.competitionLabel,
          score: game.score,
          outcome: MatchOutcome.parse(game.result),
          footer: game.eventId == null
              ? null
              : MatchTimelineExpander(
                  match: EspnMatchRef(
                    eventId: game.eventId!,
                    league: team.league,
                  ),
                ),
        ),
    ],
  );
}
