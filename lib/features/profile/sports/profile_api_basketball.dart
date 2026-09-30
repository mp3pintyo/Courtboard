import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/features/profile/sports/profile_nba_facts.dart';
import 'package:courtboard/domain/sport.dart';

/// „Játékosadatok” kártya: NBA-nál az egyesített játékosadat (meccsnapló,
/// szezonátlag), fociban és NFL-ben az API-Sports; az adat az
/// [apiSportsCardProvider]-ből jön.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nba = sport == Sport.nba;
    final provider = apiSportsCardProvider((
      sport: sport,
      athlete: athleteName,
      team: teamName,
    ));
    return AsyncDataSourceCard<Object>(
      title: nba
          ? 'Játékosadatok és meccsnapló'
          : '${sport.shortLabel} játékosadat',
      provider: nba ? 'Egyesített források' : 'API-Sports',
      icon: nba ? Icons.sports_basketball : Icons.sports_football,
      accent: accent,
      value: ref.watch(provider),
      onRefresh: () => ref.invalidate(provider),
      loadingLabel: 'Játékosadatok betöltése…',
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
        final NbaProfileBundle bundle => UnifiedAthleteFacts(
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
