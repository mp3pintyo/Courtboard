/// A már letöltött mérkőzésnaplók átalakítása formagörbe-pontokká és
/// eredménysorrá, sportáganként. Tiszta függvények (hálózat nélkül), így
/// tesztelhetők; kitalált adatot nem állítanak elő.
library;

import '../components.dart';
import '../data/basketball_reference.dart';
import '../data/basketball_season.dart';
import '../data/darts.dart';
import '../data/espn_athletes.dart';
import '../data/espn_schedule.dart';
import '../data/football_data.dart';
import '../data/football_season.dart';
import '../data/ranking_history.dart';
import '../data/wehoop_wnba.dart';

// ---------------------------------------------------------------------------
// Kosárlabda (NBA / WNBA)
// ---------------------------------------------------------------------------

/// A kosárlabda-formagörbe választható mérőszámai.
enum BasketballStat {
  points('PTS', 'pont'),
  rebounds('REB', 'lepattanó'),
  assists('AST', 'assziszt');

  const BasketballStat(this.code, this.unit);

  /// Rövid, nemzetközi jelölés a választóhoz („PTS”).
  final String code;

  /// Mértékegység a feliratokban és a képernyőolvasónak.
  final String unit;
}

/// Egy kosárlabda-meccs sora sportágtól (NBA / WNBA) és forrástól
/// függetlenül.
class BoxScoreLine {
  const BoxScoreLine({
    required this.date,
    required this.opponent,
    required this.outcome,
    required this.points,
    required this.rebounds,
    required this.assists,
    this.score,
  });

  /// Basketball Reference (NBA és a WNBA kiegészítő naplója).
  factory BoxScoreLine.fromNba(NbaGameLog game) => BoxScoreLine(
    date: game.date,
    opponent: game.opponent,
    outcome: MatchOutcome.parse(game.outcome),
    points: game.points,
    rebounds: game.rebounds,
    assists: game.assists,
    score: game.score,
  );

  /// wehoop / ESPN WNBA box score.
  factory BoxScoreLine.fromWnba(WnbaGameLog game) => BoxScoreLine(
    date: game.date,
    opponent: game.opponent,
    outcome: switch (game.result) {
      WnbaResult.win => MatchOutcome.win,
      WnbaResult.loss => MatchOutcome.loss,
      WnbaResult.unknown => MatchOutcome.unknown,
    },
    points: game.points,
    rebounds: game.rebounds,
    assists: game.assists,
    score: game.teamScore == 0 && game.opponentScore == 0 ? null : game.score,
  );

  final DateTime date;
  final String opponent;
  final MatchOutcome outcome;
  final int points;
  final int rebounds;
  final int assists;
  final String? score;

  int value(BasketballStat stat) => switch (stat) {
    BasketballStat.points => points,
    BasketballStat.rebounds => rebounds,
    BasketballStat.assists => assists,
  };
}

/// Meccsenkénti pontok a választott mérőszámból, időrendben.
List<FormPoint> basketballFormPoints(
  Iterable<BoxScoreLine> games,
  BasketballStat stat,
) => chronological([
  for (final game in games)
    FormPoint(
      date: game.date,
      value: game.value(stat).toDouble(),
      opponent: game.opponent,
      score: game.score,
      outcome: game.outcome,
    ),
]);

/// Szezonátlag a választott mérőszámhoz a szezonösszesítőből (NBA).
double? basketballSeasonAverage(
  BasketballSeasonStat? season,
  BasketballStat stat,
) => switch (stat) {
  BasketballStat.points => season?.pointsPerGame,
  BasketballStat.rebounds => season?.reboundsPerGame,
  BasketballStat.assists => season?.assistsPerGame,
};

/// Szezonátlag a teljes WNBA-meccsnaplóból (alapszakasz, ha van).
double? wnbaSeasonAverage(List<WnbaGameLog> games, BasketballStat stat) {
  if (games.isEmpty) return null;
  final summary = WnbaSeasonSummary.fromGames(games);
  return switch (stat) {
    BasketballStat.points => summary.pointsPerGame,
    BasketballStat.rebounds => summary.reboundsPerGame,
    BasketballStat.assists => summary.assistsPerGame,
  };
}

// ---------------------------------------------------------------------------
// Foci
// ---------------------------------------------------------------------------

/// A foci-formagörbe mérőszáma: FotMob-értékelés, ha legalább két meccsen
/// van, különben gól + gólpassz.
enum FootballFormMetric {
  rating('értékelés', 1),
  goalContributions('gól+gólpassz', 0);

  const FootballFormMetric(this.unit, this.digits);
  final String unit;
  final int digits;
}

FootballFormMetric pickFootballMetric(List<FootballMatchForm> matches) =>
    matches.where((match) => match.rating != null).length >= minChartPoints
    ? FootballFormMetric.rating
    : FootballFormMetric.goalContributions;

/// Meccsenkénti pontok (értékelésnél csak az értékelt meccsek), időrendben.
List<FormPoint> footballFormPoints(
  List<FootballMatchForm> matches,
  FootballFormMetric metric,
) => chronological([
  for (final match in matches)
    if (metric == FootballFormMetric.goalContributions || match.rating != null)
      FormPoint(
        date: match.date,
        value: metric == FootballFormMetric.rating
            ? match.rating!
            : (match.goals + match.assists).toDouble(),
        opponent: match.opponent,
        score: match.score,
        outcome: MatchOutcome.parse(match.outcome),
      ),
]);

/// Csapateredmények (football-data.org) eredménysorhoz.
List<ResultMark> footballTeamResultMarks(List<FootballGame> games) => [
  for (final game in games)
    if (game.result != FootballResult.unknown)
      ResultMark(
        date: game.date,
        title: 'vs. ${game.opponent}',
        score: game.score,
        outcome: switch (game.result) {
          FootballResult.win => MatchOutcome.win,
          FootballResult.loss => MatchOutcome.loss,
          FootballResult.draw => MatchOutcome.draw,
          FootballResult.unknown => MatchOutcome.unknown,
        },
      ),
];

// ---------------------------------------------------------------------------
// Tenisz, darts, NFL
// ---------------------------------------------------------------------------

/// Ranglistapontok a helyi mérésekből (pont nélküli mérés kimarad).
List<FormPoint> tennisRankingPointsForm(List<RankingSnapshot> history) =>
    chronological([
      for (final snapshot in history)
        if (snapshot.points != null)
          FormPoint(
            date: snapshot.date,
            value: snapshot.points!.toDouble(),
            opponent: snapshot.ranking == null ? '' : '#${snapshot.ranking}',
          ),
    ]);

/// Darts-eredmények (TheSportsDB) eredménysorhoz; az ismeretlen kimenetelű
/// sorok a [ResultStrip]-ből kimaradnak.
List<ResultMark> dartsResultMarks(List<DartsResult> results) => [
  for (final result in results)
    ResultMark(
      date: result.date,
      title: result.event,
      outcome: MatchOutcome.parse(result.detail),
    ),
];

/// NFL-csapat pontjai meccsenként (ESPN), időrendben.
List<FormPoint> teamScoreForm(List<EspnCompletedGame> games) => chronological([
  for (final game in games)
    if (num.tryParse(game.ownScore) case final own?)
      FormPoint(
        date: game.start,
        value: own.toDouble(),
        opponent: game.opponent,
        score: game.score.isEmpty ? null : game.score,
        outcome: MatchOutcome.parse(game.outcome),
      ),
]);

/// NFL-játékos meccsenkénti fő mutatója (ESPN-meccsnapló), időrendben; a
/// mutató nélküli meccs kimarad.
List<FormPoint> nflFormPoints(EspnGameLog log, NflFormStat stat) =>
    chronological([
      for (final game in log.games)
        if (game.stat(stat.statName) case final value?)
          FormPoint(
            date: game.date,
            value: value,
            opponent: game.opponent,
            score: game.score.isEmpty ? null : game.score,
            outcome: MatchOutcome.parse(game.outcome),
          ),
    ]);
