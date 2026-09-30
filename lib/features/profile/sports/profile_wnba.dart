import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/features/profile/form_data.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';
import 'package:courtboard/features/profile/sports/profile_nba_facts.dart';
import 'package:courtboard/domain/sport.dart';

class WnbaWehoopCard extends ConsumerWidget {
  const WnbaWehoopCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });
  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncDataSourceCard<WnbaGamesResult>(
        title: 'WNBA meccsnapló',
        provider: 'wehoop · ESPN',
        subtitle:
            'SportsDataverse / wehoop WNBA player boxscores · CC BY 4.0; '
            'tartalék: ESPN játékos-meccsnapló',
        icon: Icons.data_usage_rounded,
        accent: accent,
        value: ref.watch(wnbaGamesProvider(athleteName)),
        onRefresh: () => unawaited(
          ref.read(wnbaGamesProvider(athleteName).notifier).refresh(),
        ),
        refreshTooltip: 'Újratöltés',
        loadingLabel: 'WNBA box score-ok letöltése és helyi gyorsítótárazása…',
        errorPrefix: 'A wehoop WNBA-adat most nem érhető el. ',
        emptyMessage:
            'Ehhez a játékoshoz nem érkezett 2026-os wehoop box score rekord.',
        isEmpty: (result) => result.games.isEmpty,
        builder: (context, result) => _WnbaLiveData(
          games: result.games,
          accent: accent,
          source: result.source,
          note: result.note,
        ),
      );
}

class WnbaBasketballReferenceCard extends ConsumerWidget {
  const WnbaBasketballReferenceCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => AsyncDataSourceCard<CachedValue<List<NbaGameLog>>>(
    title: 'Kiegészítő meccsnapló',
    provider: 'Basketball Reference',
    subtitle:
        'A wehoop mellett közvetlen Basketball Reference játékos-meccsnapló.',
    icon: Icons.fact_check_outlined,
    accent: accent,
    value: ref.watch(wnbaBasketballReferenceProvider(athleteName)),
    onRefresh: () =>
        ref.invalidate(wnbaBasketballReferenceProvider(athleteName)),
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'Basketball Reference WNBA-adatok letöltése…',
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
      league: Sport.wnba,
    ),
  );
}

class WnbaRapidApiCard extends ConsumerWidget {
  const WnbaRapidApiCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rapidApiKey = ref.watch(
      apiConfigProvider.select((config) => config.rapidApiKey),
    );
    return _rapidCard(ref, rapidApiKey);
  }

  Widget _rapidCard(
    WidgetRef ref,
    String rapidApiKey,
  ) => AsyncDataSourceCard<WnbaRapidProfile?>(
    title: 'Játékosbio és haladó statisztika',
    provider: 'RapidAPI · 7 napos cache',
    icon: Icons.analytics_outlined,
    accent: accent,
    // Kulcs nélkül nincs betöltés: a kártya a helyőrzőt mutatja.
    value: rapidApiKey.isEmpty
        ? const AsyncLoading()
        : ref.watch(wnbaRapidProfileProvider(athleteName)),
    onRefresh: () => ref.invalidate(wnbaRapidProfileProvider(athleteName)),
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'WNBA játékosadatok betöltése…',
    emptyMessage: 'A játékos ESPN-azonosítója nem található.',
    emptyIcon: Icons.person_search_outlined,
    placeholder: rapidApiKey.isEmpty
        ? const EmptyState(
            compact: true,
            icon: Icons.key_off_outlined,
            message:
                'A RapidAPI-kulcs nincs beállítva. Az Adatforrások oldalon adható meg.',
          )
        : null,
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
        SportFormChart(
          kind: SportProfileSpec.formChartOf(Sport.wnba),
          data: BasketballFormData(
            [for (final game in games) BoxScoreLine.fromWnba(game)],
            seasonAverage: (stat) => wnbaSeasonAverage(games, stat),
            ranges: const [(5, '5'), (10, '10'), (0, 'Szezon')],
          ),
          accent: accent,
          leading: 24,
        ),
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
