class BasketballSeasonStat {
  const BasketballSeasonStat({
    required this.league,
    required this.season,
    required this.team,
    required this.source,
    required this.games,
    this.minutesPerGame,
    this.pointsPerGame,
    this.reboundsPerGame,
    this.assistsPerGame,
    this.stealsPerGame,
    this.turnoversPerGame,
    this.fieldGoalPercentage,
  });

  final String league;
  final String season;
  final String team;
  final String source;
  final int games;
  final double? minutesPerGame;
  final double? pointsPerGame;
  final double? reboundsPerGame;
  final double? assistsPerGame;
  final double? stealsPerGame;
  final double? turnoversPerGame;
  final double? fieldGoalPercentage;

  bool get hasUsefulData =>
      games > 0 ||
      minutesPerGame != null ||
      pointsPerGame != null ||
      reboundsPerGame != null ||
      assistsPerGame != null ||
      stealsPerGame != null ||
      turnoversPerGame != null ||
      fieldGoalPercentage != null;

  Map<String, dynamic> toJson() => {
        'league': league,
        'season': season,
        'team': team,
        'source': source,
        'games': games,
        'minutes_per_game': minutesPerGame,
        'points_per_game': pointsPerGame,
        'rebounds_per_game': reboundsPerGame,
        'assists_per_game': assistsPerGame,
        'steals_per_game': stealsPerGame,
        'turnovers_per_game': turnoversPerGame,
        'field_goal_percentage': fieldGoalPercentage,
      };

  factory BasketballSeasonStat.fromJson(Map<String, dynamic> json) =>
      BasketballSeasonStat(
        league: '${json['league'] ?? ''}',
        season: '${json['season'] ?? ''}',
        team: '${json['team'] ?? ''}',
        source: '${json['source'] ?? ''}',
        games: _asInt(json['games']),
        minutesPerGame: _asDouble(json['minutes_per_game']),
        pointsPerGame: _asDouble(json['points_per_game']),
        reboundsPerGame: _asDouble(json['rebounds_per_game']),
        assistsPerGame: _asDouble(json['assists_per_game']),
        stealsPerGame: _asDouble(json['steals_per_game']),
        turnoversPerGame: _asDouble(json['turnovers_per_game']),
        fieldGoalPercentage: _asDouble(json['field_goal_percentage']),
      );
}

int _asInt(dynamic value) => int.tryParse('$value') ?? 0;

double? _asDouble(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  return double.tryParse('$value');
}
