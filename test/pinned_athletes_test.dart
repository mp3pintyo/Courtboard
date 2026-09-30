// Kitűzött sportolók: mentés, sorrend a nyitóoldalon, jelvény, a kártya
// helyi menüje és a profil „Továbbiak” menüje; valamint a helyi
// ranglista-történet.
import 'dart:convert';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/ranking_history.dart';
import 'package:courtboard/main.dart';

void _desktopView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 1400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Athlete _athlete(String name) => Athlete(
  name: name,
  sport: 'NBA',
  team: '',
  country: '',
  photoUrl: '',
  accent: Colors.blue,
  seasonLabel: '',
  seasonValue: '',
  primaryLabel: '',
  primaryValue: '',
  metrics: const [],
  matches: const [],
);

/// A sportolókártyák sorrendje a nyitóoldalon (olvasási sorrend).
List<String> _tileOrder(WidgetTester tester, List<String> names) {
  final positions = {
    for (final name in names)
      name: tester.getTopLeft(find.byKey(ValueKey('athlete-$name'))),
  };
  return names.toList()..sort((a, b) {
    final dy = positions[a]!.dy.compareTo(positions[b]!.dy);
    return dy != 0 ? dy : positions[a]!.dx.compareTo(positions[b]!.dx);
  });
}

void main() {
  test('pinned athletes survive the state JSON round trip', () {
    const state = CourtboardLocalState(pinnedAthletes: ['B', 'A']);
    final restored = CourtboardLocalState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
    expect(restored.pinnedAthletes, ['B', 'A']);
    // Régebbi állapotfájl: nincs mező; hibás / duplikált értékek kiszűrve.
    expect(CourtboardLocalState.fromJson(const {}).pinnedAthletes, isEmpty);
    expect(
      CourtboardLocalState.fromJson(const {
        'pinnedAthletes': ['A', 3, '', 'A', 'C'],
      }).pinnedAthletes,
      ['A', 'C'],
    );
    // A többi másolat is megtartja.
    expect(state.withWindowGeometry(null).pinnedAthletes, ['B', 'A']);
  });

  test('pinnedFirst keeps relative order on both sides', () {
    final list = [for (final name in 'ABCDE'.split('')) _athlete(name)];
    expect(pinnedFirst(list, {'D', 'B'}).map((a) => a.name).join(), 'BDACE');
    expect(pinnedFirst(list, const {}).map((a) => a.name).join(), 'ABCDE');
  });

  testWidgets('pinned athletes come first with a badge', (tester) async {
    _desktopView(tester);
    await tester.pumpWidget(
      const CourtboardApp(
        initialState: CourtboardLocalState(pinnedAthletes: ['Saquon Barkley']),
      ),
    );
    await tester.pumpAndSettle();
    const names = [
      'Nikola Jokić',
      'Aitana Bonmatí',
      'Luke Humphries',
      'Caitlin Clark',
      'Saquon Barkley',
    ];
    expect(_tileOrder(tester, names).first, 'Saquon Barkley');
    expect(
      find.byKey(const ValueKey('pin-badge-Saquon Barkley')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pin-badge-Nikola Jokić')), findsNothing);
  });

  testWidgets('the card context menu pins and unpins', (tester) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('athlete-Caitlin Clark')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kitűzés'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tile-menu-pin')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pin-badge-Caitlin Clark')),
      findsOneWidget,
    );
    expect(
      _tileOrder(tester, const ['Nikola Jokić', 'Caitlin Clark']).first,
      'Caitlin Clark',
    );

    await tester.tap(
      find.byKey(const ValueKey('athlete-Caitlin Clark')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kitűzés megszüntetése'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tile-menu-pin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pin-badge-Caitlin Clark')), findsNothing);
  });

  testWidgets('the profile menu toggles pinning and opens comparison', (
    tester,
  ) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('athlete-Nikola Jokić')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-pinned-badge')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-pin-athlete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-pinned-badge')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Kitűzés megszüntetése'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-compare-athlete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compare-left')), findsOneWidget);
    expect(find.text('Nikola Jokić · NBA'), findsWidgets);

    // Vissza a nyitóoldalra: a kitűzés megmaradt.
    await tester.tap(find.byKey(const ValueKey('nav-Áttekintés')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pin-badge-Nikola Jokić')),
      findsOneWidget,
    );
  });

  group('ranking history', () {
    test('one snapshot per day, chronological, capped', () {
      var history = <RankingSnapshot>[];
      history = mergeRankingSnapshot(
        history,
        RankingSnapshot(
          date: DateTime(2026, 7, 2, 9),
          ranking: 3,
          points: 7000,
        ),
      );
      history = mergeRankingSnapshot(
        history,
        RankingSnapshot(
          date: DateTime(2026, 7, 1, 9),
          ranking: 4,
          points: 6500,
        ),
      );
      history = mergeRankingSnapshot(
        history,
        RankingSnapshot(
          date: DateTime(2026, 7, 2, 18),
          ranking: 2,
          points: 7100,
        ),
      );
      expect(history.map((s) => s.points), [6500, 7100]);
      final capped = mergeRankingSnapshot(
        history,
        RankingSnapshot(date: DateTime(2026, 7, 5), points: 1),
        max: 2,
      );
      expect(capped.map((s) => s.points), [7100, 1]);
    });

    test('the store records and reads back without network', () async {
      var now = DateTime(2026, 7, 1, 10);
      final store = RankingHistoryStore(
        storage: MemoryCacheStorage(),
        clock: () => now,
      );
      expect(await store.read('Iga Swiatek'), isEmpty);
      await store.record('Iga Swiatek', ranking: 2, points: 8000);
      now = DateTime(2026, 7, 3, 10);
      final history = await store.record(
        'Iga Swiatek',
        ranking: 1,
        points: 8400,
      );
      expect(history.map((s) => s.ranking), [2, 1]);
      expect((await store.read('Iga Swiatek')).map((s) => s.points), [
        8000,
        8400,
      ]);
      // Adat nélkül csak olvas.
      expect(await store.record('Iga Swiatek'), hasLength(2));
    });
  });
}
