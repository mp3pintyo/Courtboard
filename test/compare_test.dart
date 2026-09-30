// Összehasonlítás: normalizálás, „jobb érték” döntés, pillanatképek és az
// oldal állapotai (betöltés, adat, hiba, nem támogatott sportág).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/features/compare/compare_data.dart';
import 'package:courtboard/app/courtboard_app.dart';

const _jokic = BasketballSeasonStat(
  league: 'NBA',
  season: '2025/2026',
  team: 'Denver Nuggets',
  source: 'Basketball Reference',
  games: 65,
  minutesPerGame: 34.8,
  pointsPerGame: 26.8,
  reboundsPerGame: 12.9,
  assistsPerGame: 10.7,
  stealsPerGame: 1.4,
  turnoversPerGame: 3.7,
  fieldGoalPercentage: 56.9,
);

const _luka = BasketballSeasonStat(
  league: 'NBA',
  season: '2025/2026',
  team: 'Los Angeles Lakers',
  source: 'Basketball Reference',
  games: 70,
  minutesPerGame: 36.2,
  pointsPerGame: 28.4,
  reboundsPerGame: 8.1,
  assistsPerGame: 7.9,
  stealsPerGame: 1.6,
  turnoversPerGame: 3.9,
  fieldGoalPercentage: 47.1,
);

class _FakeSource implements CompareDataSource {
  _FakeSource(this.handler);
  final Future<AthleteSeasonSnapshot?> Function(String name) handler;
  final calls = <String>[];

  @override
  Future<AthleteSeasonSnapshot?> load({
    required String name,
    required Sport sport,
    required String team,
    required SportsApiConfig config,
    bool force = false,
  }) {
    calls.add(name);
    return handler(name);
  }
}

const _state = CourtboardLocalState(
  customAthletes: [
    CustomAthlete(
      name: 'Luka Dončić',
      sport: 'NBA',
      team: 'Los Angeles Lakers',
    ),
  ],
);

void _desktopView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 1400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openCompare(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-Összehasonlítás')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  const points = CompareMetric(id: 'points', label: 'Pont', max: 35);
  const turnovers = CompareMetric(
    id: 'turnovers',
    label: 'Eladott labda',
    max: 5,
    higherIsBetter: false,
  );
  const fieldGoal = CompareMetric(
    id: 'fieldGoal',
    label: 'FG%',
    min: 30,
    max: 70,
    percent: true,
  );

  group('better value', () {
    test('higher is better by default', () {
      expect(compareMetric(points, 28.4, 26.8), CompareWinner.left);
      expect(compareMetric(points, 20, 26.8), CompareWinner.right);
    });

    test('turnovers: fewer is better', () {
      expect(compareMetric(turnovers, 3.7, 3.9), CompareWinner.left);
      expect(compareMetric(turnovers, 4.2, 3.9), CompareWinner.right);
    });

    test('ties within the shown precision, missing values give none', () {
      expect(compareMetric(points, 26.81, 26.84), CompareWinner.tie);
      expect(compareMetric(points, null, 26.8), CompareWinner.none);
      expect(compareMetric(points, 26.8, null), CompareWinner.none);
    });

    test('tennis ranking: the smaller number wins', () {
      final ranking = CompareMetrics.tennis.first;
      expect(ranking.id, 'ranking');
      expect(compareMetric(ranking, 2, 7), CompareWinner.left);
    });
  });

  group('normalisation', () {
    test('scales into 0..1 against the reference range', () {
      expect(normalizeMetric(points, 35), 1);
      expect(normalizeMetric(points, 17.5), closeTo(.5, 1e-9));
      expect(normalizeMetric(points, 50), 1, reason: 'clamped');
      expect(normalizeMetric(points, -3), 0);
      expect(normalizeMetric(fieldGoal, 50), closeTo(.5, 1e-9));
      expect(normalizeMetric(fieldGoal, 20), 0);
    });

    test('lower-is-better metrics are inverted, missing is 0', () {
      expect(normalizeMetric(turnovers, 0), 1);
      expect(normalizeMetric(turnovers, 5), 0);
      expect(normalizeMetric(turnovers, 1), closeTo(.8, 1e-9));
      expect(normalizeMetric(turnovers, null), 0);
    });

    test('every sport documents sensible reference ranges', () {
      for (final sport in const [
        Sport.nba,
        Sport.wnba,
        Sport.football,
        Sport.tennis,
        Sport.nfl,
      ]) {
        final metrics = CompareMetrics.forSport(sport);
        expect(metrics, isNotEmpty, reason: sport.shortLabel);
        for (final metric in metrics) {
          expect(metric.max, greaterThan(metric.min), reason: metric.id);
        }
      }
      expect(sportSupportsComparison(Sport.darts), isFalse);
      // 0.12.0: az NFL az ESPN-meccsnaplóból összehasonlítható.
      expect(sportSupportsComparison(Sport.nfl), isTrue);
    });
  });

  group('snapshots', () {
    test('basketball summary maps every NBA metric', () {
      final a = snapshotFromBasketball('Nikola Jokić', _jokic);
      final b = snapshotFromBasketball('Luka Dončić', _luka);
      expect(a['points'], 26.8);
      expect(a['fieldGoal'], 56.9);
      expect(a.sport, Sport.nba);
      final axes = radarMetrics(CompareMetrics.nba, a, b);
      expect(axes.map((m) => m.id), isNot(contains('games')));
      expect(axes, hasLength(7));
      expect(
        compareSummary(CompareMetrics.nba, a, b),
        'Nikola Jokić 4 mutatóban, Luka Dončić 4 mutatóban jobb.',
      );
    });

    test('football and tennis snapshots', () {
      final football = snapshotFromFootball(
        'Aitana Bonmatí',
        const FootballSeasonStat(
          season: '2025/2026',
          team: 'Barcelona',
          competition: 'Liga F',
          source: 'FotMob',
          rating: 7.8,
          goals: 9,
        ),
      );
      expect(football['rating'], 7.8);
      expect(football['assists'], isNull);
      expect(football.hasData, isTrue);

      final tennis = snapshotFromTennis(
        'Iga Swiatek',
        const TennisPlayer(
          id: 1,
          name: 'Iga Swiatek',
          ranking: 2,
          rankingPoints: 8000,
        ),
      );
      expect(tennis['ranking'], 2);
      expect(tennis['rankingPoints'], 8000);
      // Két mutatóval a radar nem rajzolható.
      expect(radarMetrics(CompareMetrics.tennis, tennis, tennis), hasLength(2));
      expect(ComparisonRadar.canShow(2), isFalse);
    });
  });

  group('compare page', () {
    testWidgets('loads both athletes and highlights the better values', (
      tester,
    ) async {
      _desktopView(tester);
      final source = _FakeSource(
        (name) async => snapshotFromBasketball(
          name,
          name == 'Nikola Jokić' ? _jokic : _luka,
        ),
      );
      await tester.pumpWidget(
        CourtboardApp(initialState: _state, compareSource: source),
      );
      await tester.pumpAndSettle();
      await _openCompare(tester);
      await tester.pumpAndSettle();

      expect(source.calls, containsAll(['Nikola Jokić', 'Luka Dončić']));
      expect(find.byKey(const Key('compare-summary')), findsOneWidget);
      expect(find.byKey(const Key('compare-radar')), findsOneWidget);
      MetricTile tile(String key) =>
          tester.widget<MetricTile>(find.byKey(ValueKey(key)));
      expect(tile('compare-points-left').highlighted, isFalse);
      expect(tile('compare-points-right').highlighted, isTrue);
      expect(tile('compare-rebounds-left').highlighted, isTrue);
      expect(tile('compare-turnovers-left').highlighted, isTrue);
      expect(tile('compare-turnovers-right').highlighted, isFalse);
      expect(tile('compare-points-right').value, '28,4');
    });

    testWidgets('shows a loading state, then an error with retry', (
      tester,
    ) async {
      _desktopView(tester);
      final pending = Completer<AthleteSeasonSnapshot?>();
      var fail = true;
      final source = _FakeSource((name) {
        if (!pending.isCompleted) return pending.future;
        if (fail) throw StateError('offline');
        return Future.value(snapshotFromBasketball(name, _jokic));
      });
      await tester.pumpWidget(
        CourtboardApp(initialState: _state, compareSource: source),
      );
      await tester.pumpAndSettle();
      await _openCompare(tester);
      expect(
        find.text('Szezonadatok betöltése a két sportolóhoz…'),
        findsWidgets,
      );

      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A szezonadatok most nem érhetők el.'),
        findsOneWidget,
      );

      fail = false;
      await tester.tap(find.text('Újrapróbálás'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-summary')), findsOneWidget);
    });

    testWidgets('one missing side is shown as a note, not an error', (
      tester,
    ) async {
      _desktopView(tester);
      final source = _FakeSource(
        (name) async => name == 'Nikola Jokić'
            ? snapshotFromBasketball(name, _jokic)
            : null,
      );
      await tester.pumpWidget(
        CourtboardApp(initialState: _state, compareSource: source),
      );
      await tester.pumpAndSettle();
      await _openCompare(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Luka Dončić: nem érkezett szezonadat.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('compare-radar')), findsNothing);
    });

    testWidgets('unsupported sport and missing partner are explained', (
      tester,
    ) async {
      _desktopView(tester);
      final source = _FakeSource((_) async => null);
      await tester.pumpWidget(CourtboardApp(compareSource: source));
      await tester.pumpAndSettle();

      // Profilból: Luke Humphries (darts) → nem hasonlítható.
      await tester.tap(find.byKey(const ValueKey('athlete-Luke Humphries')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-compare-athlete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-unsupported')), findsOneWidget);

      // Jokić mellé nincs másik NBA-sportoló (a más sportágúak tiltottak).
      await tester.tap(find.byKey(const Key('compare-left')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nikola Jokić · NBA').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-no-partner')), findsOneWidget);
      expect(source.calls, isEmpty);

      await tester.tap(find.byKey(ValueKey('compare-right-Nikola Jokić-null')));
      await tester.pumpAndSettle();
      final item = tester.widget<DropdownMenuItem<String>>(
        find
            .ancestor(
              of: find.text('Caitlin Clark · WNBA (más sportág)').last,
              matching: find.byType(DropdownMenuItem<String>),
            )
            .first,
      );
      expect(item.enabled, isFalse);
    });
  });
}
