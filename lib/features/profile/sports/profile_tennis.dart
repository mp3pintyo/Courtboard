import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';

class TennisDataCard extends ConsumerWidget {
  const TennisDataCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTennisKey = ref.watch(
      apiConfigProvider.select((config) => config.liveTennisKey),
    );
    final hasKey = liveTennisKey.trim().isNotEmpty;
    final provider = tennisProfileProvider(athleteName);
    return AsyncDataSourceCard<TennisProfileData>(
      title: 'Teniszprofil',
      icon: Icons.sports_tennis_rounded,
      accent: accent,
      // Kulcs nélkül nincs betöltés: a kártya a helyőrzőt mutatja.
      value: hasKey ? ref.watch(provider) : const AsyncLoading(),
      onRefresh: () => unawaited(ref.read(provider.notifier).refresh()),
      refreshTooltip: 'Frissítés az API-ból',
      loadingLabel: 'Teniszprofil és aktuális meccsek betöltése…',
      headerTrailing: ProviderChip(
        name: 'Live Tennis API',
        status: hasKey ? ProviderStatus.ready : ProviderStatus.missingKey,
        message: hasKey
            ? 'Free: játékos, ranglista, élő és közelgő meccsek'
            : 'A kulcs az Adatforrások oldalon adható meg',
      ),
      placeholder: hasKey
          ? null
          : const EmptyState(
              compact: true,
              icon: Icons.key_off_outlined,
              message:
                  'Add meg a Live Tennis API ingyenes kulcsát az Adatforrások oldalon. Ezután a profil automatikusan megkapja a ranglistát, az élő állást és a következő mérkőzéseket.',
            ),
      freshness: (data) => data.fetchedAt == null
          ? null
          : DataFreshness(data.fetchedAt!, fromCache: data.fromCache),
      builder: (context, data) =>
          TennisProfileFacts(data: data, accent: accent),
    );
  }
}

class TennisProfileFacts extends StatelessWidget {
  const TennisProfileFacts({
    super.key,
    required this.data,
    required this.accent,
  });

  final TennisProfileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final facts = <(String, String)>[
      if (player.ranking != null) ('RANGLISTA', '#${player.ranking}'),
      if (player.rankingPoints != null)
        ('RANGLISTAPONT', formatInt(player.rankingPoints)),
      if (player.tour != null) ('SOROZAT', player.tour!.toUpperCase()),
      if (player.country != null) ('ORSZÁG', player.country!),
      if (player.hand != null)
        ('ÜTŐKÉZ', player.hand == 'L' ? 'Balkezes' : 'Jobbkezes'),
      if (player.backhand != null)
        ('FONÁK', player.backhand == 1 ? 'Egykezes' : 'Kétkezes'),
      if (player.birthday != null) ('SZÜLETETT', formatDate(player.birthday!)),
    ];
    final usage = data.usage;
    final usageText = usage == null
        ? null
        : usage.today != null && usage.dailyLimit != null
        ? '${usage.tier} · ma ${usage.today}/${usage.dailyLimit} kérés'
        : '${usage.tier} csomag';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(player.name, style: context.text.titleLarge)),
            if (usageText != null)
              StatusPill(usageText.toUpperCase(), tone: StatusTone.accent),
          ],
        ),
        const SizedBox(height: 12),
        MetricGrid(
          minTileWidth: 150,
          maxColumns: 7,
          children: [
            for (final (label, value) in facts)
              MetricTile(label: label, value: value),
          ],
        ),
        SportFormChart(
          kind: SportProfileSpec.formChartOf(Sport.tennis),
          data: TennisFormData(data.rankingHistory),
          accent: accent,
        ),
        const SizedBox(height: 22),
        const SubsectionLabel('ÉLŐ MÉRKŐZÉS'),
        if (data.liveMatches.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.sensors_off_outlined,
            message: 'A játékosnak most nincs élő mérkőzése.',
          )
        else
          ...data.liveMatches.map(
            (match) => MatchRow(
              live: true,
              opponent: 'vs. ${match.opponentOf(player)}',
              subtitle: _tennisSubtitle(match.tournament, match.surface),
              score: match.score?.summary ?? 'Élő mérkőzés',
            ),
          ),
        const SizedBox(height: 18),
        const SubsectionLabel('KÖVETKEZŐ MÉRKŐZÉSEK'),
        if (data.upcomingMatches.isEmpty && data.fixtures.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.event_busy_outlined,
            message: 'Most nincs a játékoshoz kapcsolható közelgő mérkőzés.',
          )
        else ...[
          ...data.upcomingMatches
              .take(5)
              .map(
                (match) => _upcoming(
                  opponent: match.opponentOf(player),
                  tournament: match.tournament,
                  detail: match.round ?? 'Közelgő mérkőzés',
                  date: match.scheduledTime,
                  surface: match.surface,
                ),
              ),
          if (data.upcomingMatches.length < 5)
            ...data.fixtures
                .take(5 - data.upcomingMatches.length)
                .map(
                  (fixture) => _upcoming(
                    opponent: fixture.opponentOf(player),
                    tournament: fixture.tournament,
                    detail: fixture.round ?? 'Közelgő mérkőzés',
                    date: fixture.eventDate,
                    surface: fixture.surface,
                  ),
                ),
        ],
        const SizedBox(height: 10),
        const CourtboardNote(
          'A Free csomag élő és közelgő adatokat biztosít. A befejezett meccselőzmények és a pontonkénti történet fizetős History hozzáférést igényelnek.',
        ),
      ],
    );
  }

  static String _tennisSubtitle(String tournament, String? surface) =>
      [tournament, if (surface != null) surface.toUpperCase()].join(' · ');

  static Widget _upcoming({
    required String opponent,
    required String tournament,
    required String detail,
    required DateTime? date,
    required String? surface,
  }) => MatchRow(
    date: date,
    dateLabel: date == null ? 'Időpont később' : null,
    venue: date == null ? null : formatTime(date),
    opponent: 'vs. $opponent',
    subtitle: '${_tennisSubtitle(tournament, surface)} · $detail',
  );
}
