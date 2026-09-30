import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/rate_limit.dart';
import 'package:courtboard/format.dart';
import 'package:courtboard/images.dart';
import 'package:courtboard/main.dart';

Athlete _athlete(String name) => Athlete(
  name: name,
  sport: 'NBA',
  team: 'Teszt',
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

void main() {
  group('formatMatchDate', () {
    test('omits the year in the current year and shows it otherwise', () {
      final now = DateTime(2026, 9, 30);
      expect(formatMatchDate(DateTime(2026, 4, 12), now: now), 'ápr. 12.');
      expect(
        formatMatchDate(DateTime(2025, 4, 12), now: now),
        '2025. ápr. 12.',
      );
    });
  });

  group('AthleteHighlightStore', () {
    test('keeps the latest result and the soonest upcoming event', () async {
      final now = DateTime(2026, 9, 30, 12);
      final store = AthleteHighlightStore(
        storage: MemoryCacheStorage(),
        clock: () => now,
      );
      await store.record('Nikola Jokić', [
        HighlightEvent(
          date: DateTime(2026, 9, 20),
          title: 'Phoenix Suns',
          outcome: 'loss',
          score: '109–112',
        ),
        HighlightEvent(
          date: DateTime(2026, 9, 28),
          title: 'San Antonio Spurs',
          outcome: 'win',
          score: '118–104',
        ),
        HighlightEvent(
          date: DateTime(2026, 10, 9),
          title: 'vs. Lakers',
          outcome: 'upcoming',
        ),
        HighlightEvent(
          date: DateTime(2026, 10, 3),
          title: 'vs. Clippers',
          outcome: 'upcoming',
        ),
      ]);
      final highlight = await store.read('Nikola Jokić');
      expect(highlight?.last?.title, 'San Antonio Spurs');
      expect(highlight?.last?.outcome, 'win');
      expect(highlight?.last?.score, '118–104');
      expect(highlight?.upcoming(now)?.title, 'vs. Clippers');

      // Új adat nélküli frissítés nem törli a korábbi eredményt.
      await store.record('Nikola Jokić', [
        HighlightEvent(
          date: DateTime(2026, 10, 5),
          title: 'vs. Jazz',
          outcome: 'upcoming',
        ),
      ]);
      final merged = await store.read('Nikola Jokić');
      expect(merged?.last?.title, 'San Antonio Spurs');
      expect(merged?.upcoming(now)?.title, 'vs. Jazz');

      expect(await store.read('Ismeretlen'), isNull);
      expect((await store.readAll(['Nikola Jokić', 'Ismeretlen'])).keys, [
        'Nikola Jokić',
      ]);
    });

    test('dashboard focus prefers the soonest upcoming event', () {
      final now = DateTime(2026, 9, 30);
      final a = _athlete('A');
      final b = _athlete('B');
      final highlights = {
        'A': AthleteHighlight(
          last: HighlightEvent(date: DateTime(2026, 9, 29), title: 'X'),
          updatedAt: now,
        ),
        'B': AthleteHighlight(
          next: HighlightEvent(date: DateTime(2026, 10, 2), title: 'Y'),
          updatedAt: now,
        ),
      };
      final focus = pickDashboardFocus([a, b], highlights, now);
      expect(focus?.athlete.name, 'B');
      expect(focus?.upcoming, isTrue);

      final recent = pickDashboardFocus([a], highlights, now);
      expect(recent?.athlete.name, 'A');
      expect(recent?.upcoming, isFalse);

      expect(pickDashboardFocus([a, b], const {}, now), isNull);
    });
  });

  group('ImageDiskCache', () {
    late Directory dir;
    final offline = HttpService(
      networkEnabled: false,
      quota: QuotaTracker(storage: MemoryCacheStorage()),
    );

    setUp(() => dir = Directory.systemTemp.createTempSync('courtboard-img-'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('serves a fresh file from disk without network', () async {
      final cache = ImageDiskCache(directory: dir.path, http: offline);
      const url = 'https://example.com/a.jpg';
      final file = cache.fileFor(url);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      expect(await cache.load(url), Uint8List.fromList([1, 2, 3]));
    });

    test('falls back to an expired copy when the download fails', () async {
      final cache = ImageDiskCache(
        directory: dir.path,
        http: offline,
        clock: () => DateTime.now().add(const Duration(days: 60)),
      );
      const url = 'https://example.com/b.jpg';
      final file = cache.fileFor(url);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([4, 5]);
      expect(await cache.load(url), Uint8List.fromList([4, 5]));
    });

    test('throws when there is neither a copy nor network', () async {
      final cache = ImageDiskCache(directory: dir.path, http: offline);
      Object? error;
      try {
        await cache.load('https://example.com/c.jpg');
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
    });

    test('initials come from the first and last name', () {
      expect(initialsOf('Nikola Jokić'), 'NJ');
      expect(initialsOf('Juhász Dorka'), 'JD');
      expect(initialsOf('aitana'), 'A');
      expect(initialsOf('  '), '?');
    });
  });

  test('rail collapse preference survives a save/load round trip', () {
    const state = CourtboardLocalState(railCollapsed: true);
    final restored = CourtboardLocalState.fromJson(state.toJson());
    expect(restored.railCollapsed, isTrue);
    expect(CourtboardLocalState.fromJson(const {}).railCollapsed, isFalse);
  });
}
