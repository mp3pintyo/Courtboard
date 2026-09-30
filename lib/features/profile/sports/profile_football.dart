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
import 'package:courtboard/data/player_contributions.dart';
import 'package:courtboard/domain/player_contribution.dart';
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

  /// Lejátszott meccsnél a sor a játékos saját góljával/gólpasszával.
  Widget _playedRow(FootballGame game) => FootballContributionBuilder(
    athleteName: athleteName,
    teamName: teamName,
    date: game.date,
    opponent: game.opponent,
    score: game.score,
    teamHome: switch (game.homeAway) {
      'home' => true,
      'away' => false,
      _ => null,
    },
    espnMatch: game.espnMatch,
    timeline: game.timeline,
    builder: (context, contribution) =>
        _gameRow(game, contribution: contribution),
  );

  Widget _gameRow(FootballGame game, {PlayerContribution? contribution}) =>
      MatchRow(
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
            ? MatchTimelineExpander(
                match: game.espnMatch,
                timeline: game.timeline,
              )
            : null,
        contribution: contribution,
      );

  /// A fejléc forráscímkéje: a ténylegesen használt adatforrás (például
  /// „ESPN · MLS”), betöltés közben az általános felirat.
  static String providerLabel(FootballTeamGames? data) {
    final source = data?.source ?? '';
    return source.isEmpty ? 'Élő adatforrás' : source;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(_gamesProvider);
    final data = value.hasValue && !value.hasError ? value.value : null;
    return AsyncDataSourceCard<FootballTeamGames>(
      title: 'Csapatmérkőzések',
      provider: providerLabel(data),
      subtitle: '$teamName · valódi eredmények',
      icon: Icons.sports_soccer,
      accent: accent,
      value: value,
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
            ...data.recent.map(_playedRow),
          ],
          if (data.upcoming.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SubsectionLabel('KÖVETKEZŐ MÉRKŐZÉSEK'),
            ...data.upcoming.map((game) => _gameRow(game)),
          ],
          for (final warning in data.warnings) CourtboardNote(warning),
        ],
      ),
    );
  }
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
      builder: (context, games) => EspnSoccerGameList(
        games: games,
        team: team,
        accent: accent,
        athleteName: athleteName,
      ),
    );
  }
}

class EspnSoccerGameList extends StatelessWidget {
  const EspnSoccerGameList({
    super.key,
    required this.games,
    required this.team,
    required this.accent,
    this.athleteName,
  });

  final List<EspnSoccerGame> games;
  final EspnSoccerTeam team;
  final Color accent;

  /// A követett sportoló: megadva a sorok a saját góljait/gólpasszait is
  /// mutatják (FotMob, tartalékként az ESPN-összefoglaló).
  final String? athleteName;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final game in games)
        if (athleteName case final athlete? when athlete.isNotEmpty)
          FootballContributionBuilder(
            athleteName: athlete,
            // Ugyanaz a kulcs, mint a „Szezon összesítő” kártyáé.
            teamName: team.clubName,
            date: game.date,
            opponent: game.opponent,
            score: game.score,
            teamHome: game.home,
            espnMatch: _matchOf(game),
            builder: (context, contribution) =>
                _row(game, contribution: contribution),
          )
        else
          _row(game),
    ],
  );

  EspnMatchRef? _matchOf(EspnSoccerGame game) => game.eventId == null
      ? null
      : EspnMatchRef(eventId: game.eventId!, league: team.league);

  Widget _row(EspnSoccerGame game, {PlayerContribution? contribution}) {
    final match = _matchOf(game);
    return MatchRow(
      date: game.date,
      venue: game.home ? 'Hazai' : 'Idegen',
      opponent: game.opponent,
      subtitle: team.competitionLabel,
      score: game.score,
      outcome: MatchOutcome.parse(game.result),
      footer: match == null ? null : MatchTimelineExpander(match: match),
      contribution: contribution,
    );
  }
}

/// Egy lejátszott focimeccs sorához a sportoló saját gólja és gólpassza.
///
/// Forrássorrend: a FotMob játékos-meccslistája (ugyanaz a
/// [footballSeasonProvider], amelyből a „Szezon összesítő” kártya és a
/// formagörbe dolgozik — külön kérés nélkül), ha ismeri a meccset
/// (dátum ±1 nap és ellenfél, lásd [findFootballMatchForm]); különben a
/// beépített OpenLigaDB-idővonal góllövői; végül az ESPN-összefoglaló
/// (csak a FotMob betöltődése után, meccsenként egyszer, végleges
/// gyorsítótárral). Ha egyik sem ismeri, nincs jelölés.
class FootballContributionBuilder extends ConsumerWidget {
  const FootballContributionBuilder({
    super.key,
    required this.athleteName,
    required this.teamName,
    required this.date,
    required this.opponent,
    required this.score,
    required this.builder,
    this.teamHome,
    this.espnMatch,
    this.timeline,
  });

  final String athleteName;

  /// A csapat (a szezonösszesítő providerének kulcsa).
  final String teamName;
  final DateTime date;
  final String opponent;

  /// „2–1” (saját gólok elöl) vagy „–”.
  final String score;

  /// A sportoló csapata hazai-e (ha ismert).
  final bool? teamHome;
  final EspnMatchRef? espnMatch;
  final MatchTimeline? timeline;
  final Widget Function(BuildContext context, PlayerContribution? contribution)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(
      footballSeasonProvider((athlete: athleteName, team: teamName)),
    );
    final scores = parseScorePair(score);
    final form = findFootballMatchForm(
      [
        for (final stat in season.value?.stats ?? const <FootballSeasonStat>[])
          ...stat.recentMatches,
      ],
      date: date,
      opponent: opponent,
      teamScore: scores?.$1,
      opponentScore: scores?.$2,
    );
    PlayerContribution? contribution;
    if (form != null) {
      contribution = footballContributionFromForm(form);
    } else if (timeline != null) {
      contribution = footballContributionFromTimeline(
        timeline!,
        athleteName,
        teamHome: teamHome,
      );
    } else if (espnMatch != null && (season.hasValue || season.hasError)) {
      contribution = ref
          .watch(
            espnMatchContributionProvider((
              match: espnMatch!,
              athlete: athleteName,
              teamHome: teamHome,
            )),
          )
          .value;
    }
    return builder(context, contribution?.withAthlete(athleteName));
  }
}
