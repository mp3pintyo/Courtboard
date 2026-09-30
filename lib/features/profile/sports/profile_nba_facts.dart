import 'package:flutter/material.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/features/profile/form_data.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/sport_profile_spec.dart';
import 'package:courtboard/domain/player_contribution.dart';
import 'package:courtboard/domain/sport.dart';

class UnifiedAthleteFacts extends StatelessWidget {
  const UnifiedAthleteFacts({
    super.key,
    required this.data,
    required this.accent,
    this.season,
    this.athleteName = '',
  });

  final UnifiedAthleteData data;
  final Color accent;

  /// A sportoló neve (a pontszerzés képernyőolvasós mondatához).
  final String athleteName;

  /// A szezonösszesítő (a formagörbe szezonátlag-vonalához), ha van.
  final BasketballSeasonStat? season;

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
      SportFormChart(
        kind: SportProfileSpec.formChartOf(Sport.nba),
        data: BasketballFormData(
          [for (final game in data.games) BoxScoreLine.fromNba(game)],
          seasonAverage: season == null
              ? null
              : (stat) => basketballSeasonAverage(season, stat),
        ),
        accent: accent,
      ),
      const SizedBox(height: 22),
      BasketballReferenceGameList(
        games: data.games,
        accent: accent,
        league: Sport.nba,
        source: data.gamesSource,
        athleteName: athleteName,
      ),
    ],
  );
}

/// A kosárlabdameccs saját pontszerzése: a pont kiemelve („24 pont”), ha
/// több mint nulla — ekkor a statisztikasorból kimarad a PTS.
PlayerContribution basketballContribution(
  int points, {
  String athlete = '',
  String source = '',
}) => PlayerContribution.basketball(
  points: points,
  athlete: athlete,
  source: source,
);

class BasketballReferenceGameList extends StatelessWidget {
  const BasketballReferenceGameList({
    super.key,
    required this.games,
    required this.accent,
    required this.league,
    this.source = 'Basketball Reference',
    this.athleteName = '',
  });

  /// A sportoló neve (a pontszerzés képernyőolvasós mondatához).
  final String athleteName;

  final List<NbaGameLog> games;
  final Color accent;

  /// A kosárlabda-liga (NBA vagy WNBA).
  final Sport league;

  /// A meccsnapló forrása (`Basketball Reference` vagy tartalékként `ESPN`).
  final String source;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SubsectionLabel(
        'LEGUTÓBBI ${league.shortLabel} MECCSEK · ${source.toUpperCase()}',
        icon: Icons.sports_basketball,
        color: accent,
      ),
      if (games.isEmpty)
        EmptyState(
          compact: true,
          icon: Icons.event_busy_outlined,
          message: league == Sport.nba
              ? 'Sem a Basketball Reference, sem az ESPN nem adott friss NBA játékos-box score-t.'
              : 'A Basketball Reference nem adott friss ${league.shortLabel} játékos-box score-t.',
        )
      else
        for (final game in games) _row(game),
    ],
  );

  Widget _row(NbaGameLog game) {
    final contribution = basketballContribution(
      game.points,
      athlete: athleteName,
      source: source,
    );
    return MatchRow(
      date: game.date,
      venue: game.location == 'HOME' ? 'Hazai' : 'Idegen',
      opponent: game.opponent,
      subtitle: contribution.hasBadge
          ? game.performanceWithoutPoints
          : game.performance,
      score: game.score,
      outcome: MatchOutcome.parse(game.outcome),
      grade: game.grade,
      contribution: contribution,
    );
  }
}
