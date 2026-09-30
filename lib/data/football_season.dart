import 'json_util.dart';

/// Egy játékos egy mérkőzésen (a FotMob `recentMatches` listájából): a
/// profil formagörbéjéhez. Csak a ténylegesen pályára lépett meccsek kerülnek
/// be; az értékelés hiányozhat.
class FootballMatchForm {
  const FootballMatchForm({
    required this.date,
    required this.opponent,
    this.competition = '',
    this.teamScore,
    this.opponentScore,
    this.rating,
    this.goals = 0,
    this.assists = 0,
    this.minutes,
  });

  final DateTime date;
  final String opponent;
  final String competition;
  final int? teamScore;
  final int? opponentScore;

  /// FotMob-értékelés (0–10), ha van.
  final double? rating;
  final int goals;
  final int assists;
  final int? minutes;

  /// „2–1” (saját csapat elöl), vagy `null`, ha nincs eredmény.
  String? get score => teamScore == null || opponentScore == null
      ? null
      : '$teamScore–$opponentScore';

  /// `win` / `loss` / `draw`, vagy üres, ha nincs eredmény.
  String get outcome {
    final own = teamScore;
    final other = opponentScore;
    if (own == null || other == null) return '';
    return own > other
        ? 'win'
        : own < other
            ? 'loss'
            : 'draw';
  }

  Map<String, dynamic> toJson() => {
        'date': date.toUtc().toIso8601String(),
        'opponent': opponent,
        'competition': competition,
        'teamScore': teamScore,
        'opponentScore': opponentScore,
        'rating': rating,
        'goals': goals,
        'assists': assists,
        'minutes': minutes,
      };

  static FootballMatchForm? fromJson(Object? raw) {
    final json = jsonMap(raw);
    final date = DateTime.tryParse('${json['date'] ?? ''}');
    if (date == null) return null;
    return FootballMatchForm(
      date: date.toLocal(),
      opponent: '${json['opponent'] ?? ''}',
      competition: '${json['competition'] ?? ''}',
      teamScore: jsonIntOrNull(json['teamScore']),
      opponentScore: jsonIntOrNull(json['opponentScore']),
      rating: jsonDoubleOrNull(json['rating']),
      goals: jsonIntOrNull(json['goals']) ?? 0,
      assists: jsonIntOrNull(json['assists']) ?? 0,
      minutes: jsonIntOrNull(json['minutes']),
    );
  }
}

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
    this.recentMatches = const [],
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

  /// A legutóbbi mérkőzések (legújabb elöl), ha a forrás ad ilyet (FotMob).
  final List<FootballMatchForm> recentMatches;

  Map<String, dynamic> toJson() => {
        'season': season,
        'team': team,
        'competition': competition,
        'source': source,
        'rating': rating,
        'appearances': appearances,
        'goals': goals,
        'assists': assists,
        'yellowCards': yellowCards,
        'redCards': redCards,
        if (recentMatches.isNotEmpty)
          'recentMatches': [for (final match in recentMatches) match.toJson()],
      };

  factory FootballSeasonStat.fromJson(Map<String, dynamic> json) =>
      FootballSeasonStat(
        season: '${json['season'] ?? ''}',
        team: '${json['team'] ?? ''}',
        competition: '${json['competition'] ?? ''}',
        source: '${json['source'] ?? ''}',
        rating: jsonDoubleOrNull(json['rating']),
        appearances: jsonIntOrNull(json['appearances']),
        goals: jsonIntOrNull(json['goals']),
        assists: jsonIntOrNull(json['assists']),
        yellowCards: jsonIntOrNull(json['yellowCards']),
        redCards: jsonIntOrNull(json['redCards']),
        recentMatches: [
          for (final raw in jsonList(json['recentMatches']))
            if (FootballMatchForm.fromJson(raw) case final match?) match,
        ],
      );

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
        recentMatches:
            recentMatches.isNotEmpty ? recentMatches : other.recentMatches,
      );
}

bool isCurrentOrPreviousFootballSeason(String season, DateTime now) {
  final start =
      int.tryParse(RegExp(r'\d{4}').firstMatch(season)?.group(0) ?? '');
  return start != null && (start == now.year || start == now.year - 1);
}
