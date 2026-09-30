// Az 0.12.0 mérkőzésrészletei: idővonal, egymás elleni mérleg, élő
// eredményjelző és NFL-meccsnapló — a widgetek megjelenése hálózat nélkül.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/shared/components.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/head_to_head.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/features/live_scores/live_scores_ui.dart';
import 'package:courtboard/features/profile/match_details.dart';
import 'package:courtboard/features/profile/sports/profile_nfl.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

import 'support/fake_http.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: buildCourtboardTheme(CourtboardAccent.green, brightness),
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 900, child: child)),
      ),
    );

void main() {
  final timeline = MatchTimelineRepository.parseEspnSummary(
    fixture('espn_soccer_summary_final.json'),
  );

  testWidgets('idővonal: Material ikonok, perc, játékos és állás', (
    tester,
  ) async {
    await tester.pumpWidget(_host(MatchTimelineView(timeline: timeline)));
    expect(find.byKey(const Key('match-timeline')), findsOneWidget);
    expect(find.text("1'"), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsNWidgets(5));
    expect(find.byIcon(Icons.rectangle_rounded), findsNWidgets(7));
    expect(find.byIcon(Icons.swap_vert_rounded), findsWidgets);
    expect(find.textContaining('le: Vilariño'), findsOneWidget);
    expect(find.text('Forrás: ESPN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lenyitható idővonal csak lenyitáskor tölt be', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      _host(
        LazyDetailExpander<MatchTimeline>(
          title: 'Idővonal',
          icon: Icons.timeline_rounded,
          load: () async {
            loads++;
            return timeline;
          },
          builder: (context, data) => MatchTimelineView(timeline: data),
        ),
      ),
    );
    expect(loads, 0);
    expect(find.byKey(const Key('match-timeline')), findsNothing);
    await tester.tap(find.text('Idővonal'));
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.byKey(const Key('match-timeline')), findsOneWidget);
    // Becsukás és újranyitás: nem tölt újra.
    await tester.tap(find.text('Idővonal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idővonal'));
    await tester.pumpAndSettle();
    expect(loads, 1);
  });

  testWidgets('egymás elleni mérleg: GY / V számláló és meccsek', (
    tester,
  ) async {
    final record = HeadToHeadRepository.teamHeadToHead(
      [
        EspnCompletedGame(
          id: '1',
          start: DateTime(2026, 4, 11),
          opponent: 'Oklahoma City Thunder',
          ownScore: '127',
          opponentScore: '107',
          outcome: 'win',
          homeAway: 'home',
        ),
        EspnCompletedGame(
          id: '2',
          start: DateTime(2026, 3, 9),
          opponent: 'Oklahoma City Thunder',
          ownScore: '126',
          opponentScore: '129',
          outcome: 'loss',
          homeAway: 'away',
        ),
      ],
      opponent: 'Oklahoma City Thunder',
      source: 'ESPN',
      note: 'Az aktuális és az előző alapszakasz befejezett meccseiből.',
    );
    await tester.pumpWidget(_host(HeadToHeadView(record: record)));
    expect(find.byKey(const Key('head-to-head')), findsOneWidget);
    expect(find.text('GY 1'), findsOneWidget);
    expect(find.text('V 1'), findsOneWidget);
    expect(find.text('127–107'), findsOneWidget);
    expect(find.textContaining('@ Oklahoma City Thunder'), findsOneWidget);
    expect(find.byType(ResultBadge), findsNWidgets(2));
  });

  testWidgets('egymás elleni mérleg: „nem elérhető” jelzés hibaként', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LazyDetailExpander<HeadToHeadRecord>(
          title: 'Egymás elleni mérleg',
          load: () async => throw const HeadToHeadUnavailable(
            'Nem elérhető a Free csomagban.',
          ),
          errorBuilder: (context, error) =>
              error is HeadToHeadUnavailable ? Text(error.message) : null,
          builder: (context, record) => HeadToHeadView(record: record),
        ),
      ),
    );
    await tester.tap(find.text('Egymás elleni mérleg'));
    await tester.pumpAndSettle();
    expect(find.text('Nem elérhető a Free csomagban.'), findsOneWidget);
  });

  testWidgets('élő eredményjelző: pontszám, állapot, élő jelzés', (
    tester,
  ) async {
    final game = LiveScoresRepository.parseNbaCdnScoreboard(
      fixture('nba_cdn_scoreboard.json'),
    ).firstWhere((game) => game.isLive);
    await tester.pumpWidget(
      _host(
        LiveGameScoreboard(
          game: AthleteLiveGame(
            athleteName: 'Nikola Jokić',
            game: game,
            ownIsHome: true,
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(find.text('84 – 79'), findsOneWidget);
    expect(find.text('3. negyed · 5:32'), findsOneWidget);
    expect(find.text('Denver Nuggets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NFL-meccsnapló: összesítő, formagörbe és meccssorok', (
    tester,
  ) async {
    final log = EspnAthleteRepository.parseGameLog(
      fixture('espn_nfl_gamelog_hurts.json'),
      const EspnAthleteRef(
        id: '4040715',
        displayName: 'Jalen Hurts',
        league: EspnLeague.nfl,
        team: 'Philadelphia Eagles',
        position: 'QB',
        jersey: '1',
      ),
    );
    await tester.pumpWidget(
      _host(NflGameLogView(log: log, accent: const Color(0xFF004C54))),
    );
    expect(find.byKey(const Key('nfl-player-log')), findsOneWidget);
    expect(find.text('PASSZOLT YARD'), findsOneWidget);
    expect(find.text('620'), findsOneWidget);
    expect(find.textContaining('FORMA · PASSZ YD'), findsOneWidget);
    expect(find.byType(FormChart), findsOneWidget);
    expect(find.byType(MatchRow), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
