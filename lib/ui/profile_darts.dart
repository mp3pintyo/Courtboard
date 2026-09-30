part of '../main.dart';

class _DartsDataCard extends StatelessWidget {
  const _DartsDataCard({
    required this.athleteName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  Widget build(BuildContext context) => DataSourceCard<DartsProfileData>(
    title: 'Darts profil és eredmények',
    provider: 'Egyesített források',
    icon: Icons.adjust_rounded,
    accent: accent,
    reloadKey: (athleteName, config.rapidApiKey),
    refreshTooltip: 'Újratöltés',
    loadingLabel: 'Darts adatok betöltése…',
    load: ({required force}) => _withHighlights(
      athleteName,
      DartsRepository(config).fetch(athleteName),
      (data) => [
        for (final result in data.results)
          _highlight(
            result.date,
            result.event,
            MatchOutcome.parse(result.detail),
          ),
      ],
    ),
    freshness: (data) =>
        data.fetchedAt == null ? null : DataFreshness(data.fetchedAt!),
    builder: (context, data) => DartsProfileFacts(data: data, accent: accent),
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
