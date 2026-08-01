class FootballSeasonStat {
  const FootballSeasonStat({
    required this.season,
    required this.team,
    required this.competition,
    required this.source,
    this.rating,
    this.appearances,
    this.goals,
    this.assists,
    this.yellowCards,
    this.redCards,
  });

  final String season;
  final String team;
  final String competition;
  final String source;
  final double? rating;
  final int? appearances;
  final int? goals;
  final int? assists;
  final int? yellowCards;
  final int? redCards;

  int get seasonStart =>
      int.tryParse(RegExp(r'\d{4}').firstMatch(season)?.group(0) ?? '') ?? 0;

  bool hasUsefulData() =>
      rating != null ||
      appearances != null ||
      goals != null ||
      assists != null ||
      yellowCards != null ||
      redCards != null;

  FootballSeasonStat merge(FootballSeasonStat other) => FootballSeasonStat(
        season: seasonStart >= other.seasonStart ? season : other.season,
        team: team.isNotEmpty ? team : other.team,
        competition: competition.isNotEmpty ? competition : other.competition,
        source: source == other.source ? source : '$source + ${other.source}',
        rating: rating ?? other.rating,
        appearances: appearances ?? other.appearances,
        goals: goals ?? other.goals,
        assists: assists ?? other.assists,
        yellowCards: yellowCards ?? other.yellowCards,
        redCards: redCards ?? other.redCards,
      );
}

bool isCurrentOrPreviousFootballSeason(String season, DateTime now) {
  final start =
      int.tryParse(RegExp(r'\d{4}').firstMatch(season)?.group(0) ?? '');
  return start != null && (start == now.year || start == now.year - 1);
}
