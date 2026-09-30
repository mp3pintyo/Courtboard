// „Követés” hírfolyam: források → elemek, összefésülés és rendezés, magyar
// relatív időpontok, az előnézet és az oldal (szűrők, lapozás).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/components.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/insights/follow_feed.dart';
import 'package:courtboard/main.dart';

final _now = DateTime(2026, 9, 30, 14);

FeedItem _item(
  String id,
  FeedItemType type,
  DateTime time, [
  String who = 'A',
]) => FeedItem(id: id, type: type, time: time, title: id, athletes: [who]);

NewsArticle _article(String key, String title, DateTime at) => NewsArticle(
  dedupeKey: key,
  sourceId: 'fox_nba',
  sourceName: 'FOX Sports',
  sport: 'NBA',
  title: title,
  url: 'https://example.com/$key',
  publishedAt: at,
  fetchedAt: at,
);

void main() {
  group('relative time (hu)', () {
    String rel(DateTime time) => formatRelativeTime(time, now: _now);

    test('past', () {
      expect(rel(_now), 'most');
      expect(rel(_now.subtract(const Duration(seconds: 30))), 'most');
      expect(rel(_now.subtract(const Duration(minutes: 5))), '5 perce');
      expect(rel(_now.subtract(const Duration(hours: 2))), '2 órája');
      expect(rel(DateTime(2026, 9, 29, 10)), 'tegnap');
      expect(rel(DateTime(2026, 9, 27, 10)), '3 napja');
      expect(rel(DateTime(2026, 9, 10, 10)), 'szept. 10.');
      expect(rel(DateTime(2025, 12, 1)), '2025. dec. 1.');
    });

    test('just after midnight the last hours are still hours', () {
      final now = DateTime(2026, 9, 30, 0, 30);
      expect(
        formatRelativeTime(DateTime(2026, 9, 29, 23), now: now),
        '1 órája',
      );
      expect(formatRelativeTime(DateTime(2026, 9, 29, 12), now: now), 'tegnap');
    });

    test('future', () {
      expect(rel(DateTime(2026, 9, 30, 19, 30)), 'ma 19:30');
      expect(rel(DateTime(2026, 10, 1, 19, 30)), 'holnap 19:30');
      expect(rel(DateTime(2026, 10, 3, 12)), '3 nap múlva');
      expect(rel(DateTime(2026, 10, 20)), 'okt. 20.');
    });
  });

  group('merge and sort', () {
    test('upcoming first (soonest first), then newest past first', () {
      final merged = mergeFeed([
        _item(
          'old-news',
          FeedItemType.news,
          _now.subtract(const Duration(days: 2)),
        ),
        _item(
          'later',
          FeedItemType.upcoming,
          _now.add(const Duration(days: 3)),
        ),
        _item(
          'video',
          FeedItemType.video,
          _now.subtract(const Duration(hours: 1)),
        ),
        _item(
          'soon',
          FeedItemType.upcoming,
          _now.add(const Duration(hours: 5)),
        ),
        _item(
          'result',
          FeedItemType.result,
          _now.subtract(const Duration(hours: 20)),
        ),
      ]);
      expect(merged.map((i) => i.id), [
        'soon',
        'later',
        'video',
        'result',
        'old-news',
      ]);
    });

    test('duplicates are dropped; type and athlete filters apply', () {
      final items = [
        _item('x', FeedItemType.news, _now, 'Jokić'),
        _item('x', FeedItemType.news, _now, 'Jokić'),
        _item('y', FeedItemType.video, _now, 'Clark'),
        _item('z', FeedItemType.result, _now, 'Clark'),
      ];
      expect(mergeFeed(items), hasLength(3));
      expect(mergeFeed(items, types: {FeedItemType.video}).map((i) => i.id), [
        'y',
      ]);
      expect(mergeFeed(items, athlete: 'Clark').map((i) => i.id), ['z', 'y']);
      expect(mergeFeed(items, types: {}, athlete: 'Jokić').map((i) => i.id), [
        'x',
      ]);
    });

    test('the dashboard preview mixes past items with a few upcoming', () {
      final feed = mergeFeed([
        for (var i = 0; i < 5; i++)
          _item('u$i', FeedItemType.upcoming, _now.add(Duration(hours: i + 1))),
        for (var i = 0; i < 5; i++)
          _item(
            'p$i',
            FeedItemType.news,
            _now.subtract(Duration(hours: i + 1)),
          ),
      ]);
      expect(feedPreview(feed, count: 6).map((i) => i.id), [
        'u0',
        'u1',
        'p0',
        'p1',
        'p2',
        'p3',
      ]);
      // Kevés múltbeli elemnél a közelgők töltik ki a helyet.
      final few = mergeFeed([
        for (var i = 0; i < 5; i++)
          _item('u$i', FeedItemType.upcoming, _now.add(Duration(hours: i + 1))),
        _item('p0', FeedItemType.news, _now),
      ]);
      expect(feedPreview(few, count: 4).map((i) => i.id), [
        'u0',
        'u1',
        'u2',
        'p0',
      ]);
    });
  });

  group('sources', () {
    test('news: only articles that mention followed athletes', () {
      final items = feedFromNews(
        [
          _article('1', 'Nikola Jokić leads Denver past Phoenix', _now),
          _article('2', 'Power rankings: the West is crowded', _now),
          _article('3', 'Lynx rookie Dorka Juhász sparks comeback', _now),
        ],
        ['Nikola Jokić', 'Juhász Dorka'],
      );
      expect(items.map((i) => i.id), ['news:1', 'news:3']);
      expect(items.last.athletes, ['Juhász Dorka']);
      expect(items.first.url, 'https://example.com/1');
      expect(items.first.detail, 'FOX Sports');
    });

    test('videos: saved date, only followed athletes', () {
      final saved = _now.subtract(const Duration(minutes: 5));
      final items = feedFromVideos(
        [
          SavedYouTubeVideo(
            videoId: 'dQw4w9WgXcQ',
            athleteName: 'Nikola Jokić',
            title: 'Highlights',
            thumbnailUrl: '',
            savedAt: saved,
          ),
          SavedYouTubeVideo(
            videoId: 'aqz-KE-bpKQ',
            athleteName: 'Removed Athlete',
            title: 'Other',
            thumbnailUrl: '',
            savedAt: saved,
          ),
        ],
        ['Nikola Jokić'],
      );
      expect(items, hasLength(1));
      expect(items.single.time, saved);
      expect(items.single.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('results from highlights keep outcome and score', () {
      final items = feedFromHighlights({
        'Nikola Jokić': AthleteHighlight(
          updatedAt: _now,
          recent: [
            HighlightEvent(
              date: _now.subtract(const Duration(days: 1)),
              title: 'San Antonio Spurs',
              outcome: 'win',
              score: '118–104',
            ),
            HighlightEvent(
              date: _now.add(const Duration(days: 1)),
              title: 'Future',
              outcome: 'upcoming',
            ),
          ],
        ),
      }, _now);
      expect(items, hasLength(1));
      expect(items.single.outcome, MatchOutcome.win);
      expect(items.single.score, '118–104');
      expect(items.single.type, FeedItemType.result);
    });

    test('upcoming: only the next 7 days', () {
      UpcomingEvent event(DateTime start) => UpcomingEvent(
        athleteName: 'Nikola Jokić',
        sport: 'NBA',
        title: 'Denver – Utah',
        opponent: 'Utah Jazz',
        homeAway: 'home',
        competition: 'NBA',
        start: start,
        source: 'ESPN',
      );
      final items = feedFromUpcoming([
        event(_now.add(const Duration(hours: 3))),
        event(_now.add(const Duration(days: 8))),
        event(_now.subtract(const Duration(hours: 1))),
      ], _now);
      expect(items, hasLength(1));
      expect(items.single.title, 'vs. Utah Jazz');
      expect(items.single.outcome, MatchOutcome.upcoming);
    });
  });

  group('highlight store keeps recent results', () {
    test('merges, dedupes and caps the recent list', () async {
      final store = AthleteHighlightStore(
        storage: MemoryCacheStorage(),
        clock: () => _now,
      );
      HighlightEvent played(int days, String title) => HighlightEvent(
        date: _now.subtract(Duration(days: days)),
        title: title,
        outcome: 'win',
      );
      await store.record('A', [played(1, 'X'), played(3, 'Y')]);
      await store.record('A', [played(1, 'X'), played(2, 'Z')]);
      final read = await store.read('A');
      expect(read!.recent.map((e) => e.title), ['X', 'Z', 'Y']);
      expect(read.last!.title, 'X');

      await store.record('A', [for (var i = 4; i < 12; i++) played(i, 'G$i')]);
      final capped = await store.read('A');
      expect(capped!.recent, hasLength(AthleteHighlightStore.maxRecent));
      expect(capped.recent.first.title, 'X');
    });
  });

  group('feed page', () {
    setUp(() => CacheStorage.shared = MemoryCacheStorage());

    Future<void> seed() async {
      final store = AthleteHighlightStore.shared;
      final now = DateTime.now();
      for (final name in const [
        'Nikola Jokić',
        'Caitlin Clark',
        'Luke Humphries',
        'Aitana Bonmatí',
        'Saquon Barkley',
      ]) {
        await store.record(name, [
          for (var i = 1; i <= 6; i++)
            HighlightEvent(
              date: now.subtract(Duration(hours: i * 7 + name.length)),
              title: '$name ellenfél $i',
              outcome: i.isEven ? 'win' : 'loss',
              score: '10–$i',
            ),
        ]);
      }
    }

    testWidgets('filters by type and athlete, paginates lazily', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await seed();
      await tester.pumpWidget(const CourtboardApp());
      await tester.pumpAndSettle();

      // A nyitóoldal előnézete és az „összes” gomb.
      await tester.scrollUntilVisible(
        find.byKey(const Key('dashboard-feed-all')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('dashboard-feed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dashboard-feed-all')));
      await tester.pumpAndSettle();

      expect(find.text('30 elem · 20 látható'), findsOneWidget);

      // Görgetéskor a következő oldal magától betöltődik.
      final list = find.byType(Scrollable).last;
      for (var i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, -900));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, 900));
        await tester.pumpAndSettle();
      }
      expect(find.text('30 elem · 30 látható'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('feed-athlete-Caitlin Clark')),
      );
      await tester.pumpAndSettle();
      expect(find.text('6 elem · 6 látható'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('feed-type-news')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-empty')), findsOneWidget);
      expect(find.text('Nincs a szűrésnek megfelelő elem.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feed-type-all')));
      await tester.pumpAndSettle();
      expect(find.text('6 elem · 6 látható'), findsOneWidget);

      // Eredményre kattintva a sportoló profilja nyílik meg.
      await tester.tap(find.text('Caitlin Clark ellenfél 1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-hero')), findsOneWidget);
      expect(find.text('Vissza: Követés'), findsOneWidget);
    });

    testWidgets('empty feed explains where items come from', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const CourtboardApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-Követés')));
      await tester.pumpAndSettle();
      expect(
        find.text('Még nincs friss tartalom a követettektől.'),
        findsOneWidget,
      );
    });
  });
}
