import 'package:courtboard/data/json_util.dart';

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
        games: jsonInt(json['games']),
        minutesPerGame: jsonDoubleOrNull(json['minutes_per_game']),
        pointsPerGame: jsonDoubleOrNull(json['points_per_game']),
        reboundsPerGame: jsonDoubleOrNull(json['rebounds_per_game']),
        assistsPerGame: jsonDoubleOrNull(json['assists_per_game']),
        stealsPerGame: jsonDoubleOrNull(json['steals_per_game']),
        turnoversPerGame: jsonDoubleOrNull(json['turnovers_per_game']),
        fieldGoalPercentage: jsonDoubleOrNull(json['field_goal_percentage']),
      );
}
