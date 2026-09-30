part of '../main.dart';

class UnifiedAthleteFacts extends StatelessWidget {
  const UnifiedAthleteFacts({
    super.key,
    required this.data,
    required this.accent,
  });

  final UnifiedAthleteData data;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final provider in data.providers)
            ProviderChip.fromFlags(
              name: provider.name,
              ready: provider.hasData,
              configured: provider.configured,
              message: provider.message ?? 'Adat érkezett',
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (data.facts.isEmpty)
        const EmptyState(
          compact: true,
          icon: Icons.person_search_outlined,
          message:
              'Egyik beállított szolgáltató sem talált ilyen nevű NBA-játékost.',
        )
      else
        MetricGrid(
          minTileWidth: 170,
          maxColumns: 6,
          children: [
            for (final fact in data.facts)
              MetricTile(
                label: fact.label,
                value: fact.value,
                caption: fact.source,
                captionColor: accent,
              ),
          ],
        ),
      const SizedBox(height: 22),
      BasketballReferenceGameList(
        games: data.games,
        accent: accent,
        league: 'NBA',
      ),
    ],
  );
}

class BasketballReferenceGameList extends StatelessWidget {
  const BasketballReferenceGameList({
    super.key,
    required this.games,
    required this.accent,
    required this.league,
  });

  final List<NbaGameLog> games;
  final Color accent;
  final String league;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SubsectionLabel(
        'LEGUTÓBBI $league MECCSEK · BASKETBALL REFERENCE',
        icon: Icons.sports_basketball,
        color: accent,
      ),
      if (games.isEmpty)
        EmptyState(
          compact: true,
          icon: Icons.event_busy_outlined,
          message:
              'A Basketball Reference nem adott friss $league játékos-box score-t.',
        )
      else
        for (final game in games)
          MatchRow(
            date: game.date,
            venue: game.location == 'HOME' ? 'Hazai' : 'Idegen',
            opponent: game.opponent,
            subtitle: game.performance,
            score: game.score,
            outcome: MatchOutcome.parse(game.outcome),
            grade: game.grade,
          ),
    ],
  );
}
