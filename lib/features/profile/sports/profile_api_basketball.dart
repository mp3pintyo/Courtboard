import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/features/profile/profile_common.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/features/profile/sports/profile_nba_facts.dart';
import 'package:courtboard/domain/sport.dart';

/// Az NBA-profil élő adatai: az egyesített játékosadat (meccsnaplóval) és —
/// a formagörbe átlagvonalához — a szezonösszesítő, ha elérhető. A
/// szezonösszesítő ugyanabból a gyorsítótárból jön, mint a „Szezon
/// összesítő” kártyáé (az egyidejű kérést a gyorsítótár összevonja).
class _NbaProfileBundle {
  const _NbaProfileBundle(this.data, this.season);
  final UnifiedAthleteData data;
  final BasketballSeasonStat? season;
}

class ApiSportsCard extends ConsumerWidget {
  const ApiSportsCard({
    super.key,
    required this.sport,
    required this.athleteName,
    required this.teamName,
    required this.accent,
  });
  final Sport sport;
  final String athleteName;
  final String teamName;
  final Color accent;

  Future<Object> _load(WidgetRef ref) {
    final repo = ref.read(apiSportsRepositoryProvider);
    return switch (sport) {
      Sport.football => repo.footballRecent(teamName),
      Sport.nba => _loadNba(ref),
      _ => repo.nflPlayer(athleteName),
    };
  }

  Future<_NbaProfileBundle> _loadNba(WidgetRef ref) async {
    final season = ref
        .read(basketballReferenceRepositoryProvider)
        .seasonSummary(athleteName)
        .then<BasketballSeasonStat?>(
          (value) => value,
          onError: (Object _) => null,
        );
    final data = await ref
        .read(multiProviderAthleteRepositoryProvider)
        .fetchNbaPlayer(athleteName);
    // A Basketball Reference szezonátlaga, tartalékként az ESPN-é.
    return _NbaProfileBundle(data, await season ?? data.espnSeason);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nba = sport == Sport.nba;
    final config = ref.watch(apiConfigProvider);
    return DataSourceCard<Object>(
      title: nba
          ? 'Játékosadatok és meccsnapló'
          : '${sport.shortLabel} játékosadat',
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
      load: ({required force}) => withHighlights(
        athleteName,
        _load(ref),
        (data) => switch (data) {
          final List<ApiSportsGame> games => [
            for (final game in games)
              highlightEvent(
                game.date,
                game.opponent,
                MatchOutcome.parse(game.result),
                game.score,
              ),
          ],
          final _NbaProfileBundle bundle => [
            for (final game in bundle.data.games)
              highlightEvent(
                game.date,
                game.opponent,
                MatchOutcome.parse(game.outcome),
                game.score,
              ),
          ],
          _ => const <HighlightEvent>[],
        },
        store: ref.read(highlightStoreProvider),
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

/// NBA-szezonösszesítő: Basketball Reference; ha nem érhető el vagy nincs
/// sora, az ESPN meccsnaplójából számolt alapszakasz-összesítő (a
/// [nbaSeasonSummaryProvider]-ből).
class NbaSeasonSummaryCard extends ConsumerWidget {
  const NbaSeasonSummaryCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncDataSourceCard<BasketballSeasonStat?>(
        title: 'Szezon összesítő',
        icon: Icons.leaderboard_outlined,
        accent: accent,
        value: ref.watch(nbaSeasonSummaryProvider(athleteName)),
        onRefresh: () => unawaited(
          ref.read(nbaSeasonSummaryProvider(athleteName).notifier).refresh(),
        ),
        refreshTooltip: 'Szezonadatok frissítése',
        loadingLabel: 'NBA szezonadatok betöltése…',
        errorPrefix: 'A friss NBA szezonösszesítő most nem érhető el. ',
        emptyMessage: 'Ehhez a játékoshoz nincs friss NBA szezonadat.',
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
