// Formagörbék: a meccsnaplók átalakítása diagrampontokká sportáganként, a
// rejtési szabály (2 pont alatt semmi) és a widgetek megjelenése.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/components.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/fotmob_football.dart';
import 'package:courtboard/data/ranking_history.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/insights/form_data.dart';
import 'package:courtboard/main.dart';
import 'package:courtboard/theme/courtboard_theme.dart';

NbaGameLog _nba(int day, int points, {String outcome = 'WIN'}) => NbaGameLog(
  date: DateTime(2026, 4, day),
  opponent: 'Ellenfél $day',
  outcome: outcome,
  location: 'HOME',
  minutes: 34,
  points: points,
  rebounds: 10 + day,
  assists: 5,
  steals: 1,
  blocks: 0,
  score: '110-100',
);

WnbaGameLog _wnba(int day, int points, WnbaResult result) => WnbaGameLog(
  gameId: '$day',
  date: DateTime(2026, 7, day),
  team: 'Minnesota Lynx',
  opponent: 'Seattle Storm',
  teamScore: 84,
  opponentScore: 78,
  result: result,
  points: points,
  rebounds: 4,
  assists: 2,
  steals: 1,
  blocks: 0,
  minutes: 20,
  headshotUrl: '',
  seasonType: '2',
);

Widget _host(Widget child) => MaterialApp(
  theme: buildCourtboardTheme(CourtboardAccent.green, Brightness.light),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 900, child: child)),
  ),
);

void main() {
  group('basketball mapping', () {
    test('NBA game logs become chronological points per stat', () {
      final games = [
        _nba(12, 31),
        _nba(10, 24, outcome: 'LOSS'),
        _nba(8, 22),
      ].map(BoxScoreLine.fromNba).toList();
      final points = basketballFormPoints(games, BasketballStat.points);
      expect(points.map((p) => p.value), [22, 24, 31]);
      expect(points.first.date, DateTime(2026, 4, 8));
      expect(points[1].outcome, MatchOutcome.loss);
      expect(points[1].opponent, 'Ellenfél 10');
      expect(points[1].score, '110-100');

      final rebounds = basketballFormPoints(games, BasketballStat.rebounds);
      expect(rebounds.map((p) => p.value), [18, 20, 22]);
    });

    test('season average comes from the NBA summary', () {
      const season = BasketballSeasonStat(
        league: 'NBA',
        season: '2025/2026',
        team: 'Denver Nuggets',
        source: 'Basketball Reference',
        games: 60,
        pointsPerGame: 26.8,
        reboundsPerGame: 12.9,
        assistsPerGame: 10.7,
      );
      expect(basketballSeasonAverage(season, BasketballStat.points), 26.8);
      expect(basketballSeasonAverage(season, BasketballStat.assists), 10.7);
      expect(basketballSeasonAverage(null, BasketballStat.points), isNull);
    });

    test('WNBA box scores map results and a season average', () {
      final games = [
        _wnba(20, 18, WnbaResult.win),
        _wnba(17, 6, WnbaResult.loss),
        _wnba(14, 12, WnbaResult.unknown),
      ];
      final points = basketballFormPoints(
        games.map(BoxScoreLine.fromWnba),
        BasketballStat.points,
      );
      expect(points.map((p) => p.outcome), [
        MatchOutcome.unknown,
        MatchOutcome.loss,
        MatchOutcome.win,
      ]);
      expect(wnbaSeasonAverage(games, BasketballStat.points), 12);
      expect(wnbaSeasonAverage(const [], BasketballStat.points), isNull);
    });
  });

  group('football mapping', () {
    FootballMatchForm match(int day, {double? rating, int goals = 0}) =>
        FootballMatchForm(
          date: DateTime(2026, 4, day),
          opponent: 'Rivális $day',
          teamScore: 2,
          opponentScore: day.isEven ? 1 : 3,
          rating: rating,
          goals: goals,
          assists: 1,
        );

    test('rating is used when at least two matches are rated', () {
      final matches = [match(3, rating: 7.4), match(8, rating: 8.1), match(6)];
      expect(pickFootballMetric(matches), FootballFormMetric.rating);
      final points = footballFormPoints(matches, FootballFormMetric.rating);
      expect(points.map((p) => p.value), [7.4, 8.1]);
      expect(points.last.outcome, MatchOutcome.win);
      expect(points.first.outcome, MatchOutcome.loss);
    });

    test('falls back to goals + assists without ratings', () {
      final matches = [match(3, goals: 2), match(8), match(6, rating: 7)];
      expect(pickFootballMetric(matches), FootballFormMetric.goalContributions);
      final points = footballFormPoints(
        matches,
        FootballFormMetric.goalContributions,
      );
      expect(points.map((p) => p.value), [3, 1, 1]);
    });

    test('FotMob recentMatches are parsed, bench games skipped', () {
      final matches = FotMobFootballRepository.parseRecentMatches({
        'recentMatches': [
          {
            'id': 1,
            'opponentTeamName': 'Real Madrid',
            'isHomeTeam': false,
            'matchDate': {'utcTime': '2026-04-20T19:00:00Z'},
            'homeScore': 1,
            'awayScore': 3,
            'goals': 1,
            'assists': 1,
            'minutesPlayed': 90,
            'ratingProps': {'num': '8.7'},
            'leagueName': 'Liga F',
          },
          {
            'id': 2,
            'opponentTeamName': 'Sevilla',
            'isHomeTeam': true,
            'matchDate': {'utcTime': '2026-04-13T17:00:00Z'},
            'homeScore': 0,
            'awayScore': 0,
            'onBench': true,
          },
          {
            'id': 3,
            'opponentTeamName': 'Levante',
            'isHomeTeam': true,
            'matchDate': '2026-04-06T17:00:00Z',
            'homeScore': 2,
            'awayScore': 2,
            'goals': 0,
            'assists': 0,
          },
        ],
      });
      expect(matches, hasLength(2));
      expect(matches.first.opponent, 'Real Madrid');
      expect(matches.first.score, '3–1');
      expect(matches.first.outcome, 'win');
      expect(matches.first.rating, 8.7);
      expect(matches.last.outcome, 'draw');
      expect(matches.last.rating, isNull);
    });

    test('recent matches survive the season stat JSON round trip', () {
      final stat = FootballSeasonStat(
        season: '2025/2026',
        team: 'Barcelona',
        competition: 'Liga F',
        source: 'FotMob',
        rating: 7.6,
        recentMatches: [match(3, rating: 7.4)],
      );
      final restored = FootballSeasonStat.fromJson(stat.toJson());
      expect(restored.recentMatches, hasLength(1));
      expect(restored.recentMatches.first.rating, 7.4);
      expect(restored.recentMatches.first.opponent, 'Rivális 3');
    });

    test('football-data team results become result marks', () {
      final marks = footballTeamResultMarks([
        FootballGame(
          date: DateTime(2026, 4, 1),
          opponent: 'Chelsea',
          score: '2–0',
          result: FootballResult.win,
        ),
        FootballGame(
          date: DateTime(2026, 4, 8),
          opponent: 'Arsenal',
          score: '—',
          result: FootballResult.unknown,
        ),
      ]);
      expect(marks, hasLength(1));
      expect(marks.single.outcome, MatchOutcome.win);
      expect(marks.single.title, 'vs. Chelsea');
    });
  });

  group('tennis, darts and NFL mapping', () {
    test('ranking history keeps only snapshots with points', () {
      final points = tennisRankingPointsForm([
        RankingSnapshot(date: DateTime(2026, 7, 7), ranking: 3, points: 7000),
        RankingSnapshot(date: DateTime(2026, 7, 1), ranking: 4, points: 6500),
        RankingSnapshot(date: DateTime(2026, 7, 9), ranking: 3),
      ]);
      expect(points.map((p) => p.value), [6500, 7000]);
      expect(points.last.opponent, '#3');
    });

    test('darts results map to marks; unknown outcomes are dropped', () {
      final marks = dartsResultMarks([
        DartsResult(date: DateTime(2026, 7, 26), event: 'A', detail: 'WIN'),
        DartsResult(date: DateTime(2026, 7, 20), event: 'B', detail: 'LOSS'),
        DartsResult(date: DateTime(2026, 7, 10), event: 'C', detail: '—'),
      ]);
      expect(marks, hasLength(3));
      final known = ResultStrip.known(marks);
      expect(known.map((m) => m.title), ['B', 'A']);
      expect(ResultStrip.canShow(marks), isTrue);
      expect(ResultStrip.canShow(marks.take(1)), isFalse);
      expect(
        resultStripSummary(known),
        'Az utolsó 2 eredmény: 1 győzelem, 1 vereség.',
      );
    });

    test('NFL team scores become points; unscored games are skipped', () {
      final points = teamScoreForm([
        EspnCompletedGame(
          id: '2',
          start: DateTime(2026, 9, 21),
          opponent: 'Los Angeles Rams',
          ownScore: '27',
          opponentScore: '20',
          outcome: 'win',
        ),
        EspnCompletedGame(
          id: '1',
          start: DateTime(2026, 9, 14),
          opponent: 'Dallas Cowboys',
          ownScore: '17',
          opponentScore: '24',
          outcome: 'loss',
        ),
        EspnCompletedGame(
          id: '0',
          start: DateTime(2026, 9, 7),
          opponent: 'Unknown',
          ownScore: '',
          opponentScore: '',
        ),
      ]);
      expect(points.map((p) => p.value), [17, 27]);
      expect(points.first.outcome, MatchOutcome.loss);
      expect(points.last.score, '27–20');
    });
  });

  group('summary and hiding rules', () {
    final points = [
      for (final (day, value) in const [
        (1, 20),
        (2, 22),
        (3, 21),
        (4, 23),
        (5, 21),
      ])
        FormPoint(
          date: DateTime(2026, 4, day),
          value: value.toDouble(),
          opponent: 'Ellenfél $day',
        ),
    ];

    test('the accessible summary reads the average in Hungarian', () {
      final summary = formChartSummary(points, unit: 'pont');
      expect(summary, startsWith('Az utolsó 5 meccsen átlag 21,4 pont.'));
      expect(summary, contains('Legjobb: 23 pont (ápr. 4., Ellenfél 4)'));
    });

    test('charts need at least two points', () {
      expect(FormChart.canShow(const []), isFalse);
      expect(FormChart.canShow(points.take(1).toList()), isFalse);
      expect(FormChart.canShow(points.take(2).toList()), isTrue);
    });

    testWidgets('FormChart renders a chart with semantics and a legend', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(FormChart(points: points, unit: 'pont', average: 21.4)),
      );
      expect(find.byKey(const Key('form-chart')), findsOneWidget);
      expect(find.text('Szezonátlag: 21,4'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Az utolsó 5 meccsen átlag 21,4 pont')),
        findsOneWidget,
      );
    });

    testWidgets('FormChart and ResultStrip hide below two points', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              FormChart(points: points.take(1).toList(), unit: 'pont'),
              ResultStrip(
                results: [
                  ResultMark(
                    date: DateTime(2026, 7, 1),
                    title: 'A',
                    outcome: MatchOutcome.win,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('form-chart')), findsNothing);
      expect(find.byKey(const Key('result-strip')), findsNothing);
    });

    testWidgets('BasketballFormSection switches between PTS, REB and AST', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BasketballFormSection(
            games: [
              for (final game in [_nba(3, 20), _nba(5, 30), _nba(7, 25)])
                BoxScoreLine.fromNba(game),
            ],
            accent: Colors.orange,
            seasonAverage: (stat) =>
                stat == BasketballStat.points ? 24.5 : null,
          ),
        ),
      );
      expect(find.byKey(const Key('form-chart')), findsOneWidget);
      expect(find.text('Szezonátlag: 24,5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('form-stat-REB')));
      await tester.pump();
      expect(find.text('FORMA · LEPATTANÓ · UTOLSÓ 3 MECCS'), findsOneWidget);
      // Szezonátlag híján a látható meccsek átlaga: (13+15+17)/3 = 15.
      expect(find.text('Átlag: 15,0'), findsOneWidget);
    });

    testWidgets('BasketballFormSection is hidden with a single game', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BasketballFormSection(
            games: [BoxScoreLine.fromNba(_nba(3, 20))],
            accent: Colors.orange,
          ),
        ),
      );
      expect(find.byKey(const Key('basketball-form')), findsNothing);
    });

    testWidgets('football and tennis panels render with enough data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              FootballFormPanel(
                matches: [
                  for (var day = 1; day <= 4; day++)
                    FootballMatchForm(
                      date: DateTime(2026, 4, day),
                      opponent: 'R$day',
                      rating: 6.5 + day / 2,
                    ),
                ],
                seasonRating: 7.2,
              ),
              TennisRankingForm(
                history: [
                  RankingSnapshot(date: DateTime(2026, 7, 1), points: 6000),
                  RankingSnapshot(date: DateTime(2026, 7, 2), points: 6200),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('football-form')), findsOneWidget);
      expect(find.byKey(const Key('tennis-ranking-form')), findsOneWidget);
      expect(find.byKey(const Key('form-chart')), findsNWidgets(2));
    });
  });
}
