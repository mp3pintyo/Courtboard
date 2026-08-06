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
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: data.providers.map((provider) {
          final color = provider.hasData
              ? _moss
              : provider.configured
              ? Colors.red.shade400
              : Colors.orange.shade600;
          return Tooltip(
            message: provider.message ?? 'Adat érkezett',
            child: Chip(
              avatar: Icon(
                provider.hasData
                    ? Icons.check_circle
                    : provider.configured
                    ? Icons.error_outline
                    : Icons.key_off,
                size: 17,
                color: color,
              ),
              label: Text(provider.name),
              side: BorderSide(color: color.withValues(alpha: .45)),
              backgroundColor: color.withValues(alpha: .08),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      if (data.facts.isEmpty)
        const Text(
          'Egyik beállított szolgáltató sem talált ilyen nevű NBA-játékost.',
          style: TextStyle(color: Colors.red),
        )
      else
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: data.facts
              .map(
                (fact) => Container(
                  width: 190,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fact.label.toUpperCase(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fact.value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fact.source,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      const SizedBox(height: 18),
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
      Row(
        children: [
          Icon(Icons.sports_basketball, color: accent, size: 20),
          const SizedBox(width: 8),
          Text(
            'LEGUTÓBBI $league MECCSEK · BASKETBALL REFERENCE',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (games.isEmpty)
        Text(
          'A Basketball Reference nem adott friss $league játékos-box score-t.',
          style: const TextStyle(color: _muted),
        )
      else
        ...games.map(
          (game) => _MatchRow(
            accent: accent,
            match: MatchLine(
              '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')}',
              game.opponent,
              game.resultLabel,
              game.score ?? (game.location == 'HOME' ? 'HAZAI' : 'IDEGEN'),
              game.performance,
              game.grade,
            ),
          ),
        ),
    ],
  );
}
