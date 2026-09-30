import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/features/profile/profile_providers.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';

class DartsDataCard extends ConsumerWidget {
  const DartsDataCard({
    super.key,
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncDataSourceCard<DartsProfileData>(
        title: 'Darts profil és eredmények',
        provider: 'Egyesített források',
        icon: Icons.adjust_rounded,
        accent: accent,
        value: ref.watch(dartsProfileProvider(athleteName)),
        onRefresh: () => ref.invalidate(dartsProfileProvider(athleteName)),
        refreshTooltip: 'Újratöltés',
        loadingLabel: 'Darts adatok betöltése…',
        freshness: (data) =>
            data.fetchedAt == null ? null : DataFreshness(data.fetchedAt!),
        builder: (context, data) =>
            DartsProfileFacts(data: data, accent: accent),
      );
}

class DartsProfileFacts extends StatelessWidget {
  const DartsProfileFacts({
    super.key,
    required this.data,
    required this.accent,
  });

  final DartsProfileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final facts = <(String, String)>[
      if (player?['strPlayer'] != null) ('NÉV', '${player!['strPlayer']}'),
      if (player?['strTeam'] != null) ('SOROZAT', '${player!['strTeam']}'),
      if (player?['strNationality'] != null)
        ('NEMZETISÉG', '${player!['strNationality']}'),
      if (player?['dateBorn'] != null)
        ('SZÜLETETT', formatDateText('${player!['dateBorn']}')),
      if (player?['strStatus'] != null) ('STÁTUSZ', '${player!['strStatus']}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ProviderChip.fromFlags(
              name: 'TheSportsDB',
              ready: player != null,
              message:
                  data.theSportsDbError ??
                  (player == null ? 'Nincs találat' : 'Profil és eredmények'),
            ),
            ProviderChip.fromFlags(
              name: 'RapidAPI · Darts API',
              ready: data.competitions.isNotEmpty,
              configured: data.rapidApiConfigured,
              message:
                  data.rapidApiError ??
                  (data.rapidApiConfigured
                      ? 'Verseny- és eseményfeed'
                      : 'RapidAPI kulcs nincs beállítva'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (facts.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.person_search_outlined,
            message: 'A TheSportsDB nem talált ilyen dartsjátékost.',
          )
        else
          MetricGrid(
            minTileWidth: 170,
            maxColumns: 5,
            children: [
              for (final (label, value) in facts)
                MetricTile(label: label, value: value),
            ],
          ),
        const SizedBox(height: 22),
        SportFormChart(
          kind: SportProfileSpec.formChartOf(Sport.darts),
          data: DartsFormData(data.results),
          accent: accent,
          leading: 0,
          trailing: 22,
        ),
        const SubsectionLabel('LEGUTÓBBI DARTS EREDMÉNYEK · THESPORTSDB'),
        if (data.results.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.event_busy_outlined,
            message: 'Nem érkezett játékoshoz kötött eredmény.',
          )
        else
          for (final result in data.results)
            MatchRow(
              date: result.date,
              opponent: result.event,
              subtitle:
                  MatchOutcome.parse(result.detail) == MatchOutcome.unknown
                  ? result.detail
                  : null,
              outcome: MatchOutcome.parse(result.detail),
            ),
        const SizedBox(height: 18),
        const SubsectionLabel('RAPIDAPI VERSENYFEED'),
        Text(
          'A Sportbex API ezen csomagja versenyeket, eseményeket, piacokat és oddsokat ad; játékosstatisztikát nem.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 10),
        if (!data.rapidApiConfigured)
          const EmptyState(
            compact: true,
            icon: Icons.key_off_outlined,
            message:
                'A közös RapidAPI kulcs az Adatforrások oldalon adható meg.',
          )
        else if (data.competitions.isEmpty)
          EmptyState(
            compact: true,
            message: data.rapidApiError ?? 'Most nincs elérhető verseny.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final competition in data.competitions)
                StatusPill(competition.name),
            ],
          ),
      ],
    );
  }
}
