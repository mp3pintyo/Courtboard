import 'dart:async';

import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_desktop.dart';

const _jokic = UpcomingEventsTarget(
  name: 'Nikola Jokić',
  sport: 'NBA',
  team: 'Denver Nuggets',
);
const _clark = UpcomingEventsTarget(
  name: 'Caitlin Clark',
  sport: 'WNBA',
  team: 'Indiana Fever',
);

UpcomingEvent _event(
  DateTime start, {
  String athlete = 'Nikola Jokić',
  String opponent = 'Utah Jazz',
  bool timeKnown = true,
}) => UpcomingEvent(
  athleteName: athlete,
  sport: 'NBA',
  title: 'Denver Nuggets – $opponent',
  opponent: opponent,
  competition: 'NBA · Alapszakasz',
  start: start,
  homeAway: 'home',
  source: 'ESPN',
  timeKnown: timeKnown,
);

WatchedResult _result(
  String key,
  DateTime date, {
  String opponent = 'San Antonio Spurs',
  String outcome = 'win',
  String score = '118–104',
}) => WatchedResult(
  key: key,
  date: date,
  opponent: opponent,
  outcome: outcome,
  score: score,
  homeAway: 'home',
);

NewsArticle _article(String key, DateTime published, String title) =>
    NewsArticle(
      dedupeKey: key,
      sourceId: 'fox_nba',
      sourceName: 'FOX Sports',
      sport: 'NBA',
      title: title,
      url: 'https://example.com/$key',
      publishedAt: published,
      fetchedAt: published,
    );

void main() {
  late FakeWatcherSource source;
  late FakeNotificationService notifications;
  late MemoryWatcherMemoryStore memory;
  late DateTime now;

  AthleteWatcher watcher({
    NotificationSettings settings = const NotificationSettings(),
    List<UpcomingEventsTarget> athletes = const [_jokic],
    DateTime Function()? clock,
  }) {
    final result = AthleteWatcher(
      source: source,
      notifications: notifications,
      memoryStore: memory,
      clock: clock ?? () => now,
    )..update(athletes: athletes, settings: settings);
    addTearDown(result.dispose);
    return result;
  }

  setUp(() {
    source = FakeWatcherSource();
    notifications = FakeNotificationService();
    memory = MemoryWatcherMemoryStore();
    now = DateTime(2026, 10, 1, 18);
  });

  group('első futás', () {
    test(
      'csak megjegyzi a meglévő eredményeket és híreket (nincs özön)',
      () async {
        source.results['Nikola Jokić'] = [
          _result('nba:1', now.subtract(const Duration(hours: 5))),
          _result('nba:2', now.subtract(const Duration(days: 2))),
        ];
        source.news['Nikola Jokić'] = [
          _article(
            'a1',
            now.subtract(const Duration(hours: 1)),
            'Jokić triple-double',
          ),
        ];
        final report = await watcher().run();
        expect(notifications.shown, isEmpty);
        expect(report.seeded, 2);
        expect(memory.saved!.seenResults['Nikola Jokić'], ['nba:1', 'nba:2']);
        expect(memory.saved!.seenNews['Nikola Jokić'], ['a1']);
      },
    );
  });

  group('Új eredmény', () {
    test('egy új eredmény egyszer jelez, utána nem ismétlődik', () async {
      final w = watcher();
      source.results['Nikola Jokić'] = [
        _result('nba:1', now.subtract(const Duration(days: 1))),
      ];
      await w.run();
      source.results['Nikola Jokić'] = [
        _result('nba:2', now.subtract(const Duration(hours: 2))),
        _result('nba:1', now.subtract(const Duration(days: 1))),
      ];
      await w.run();
      expect(notifications.shown, hasLength(1));
      final shown = notifications.shown.single;
      expect(shown.kind, CourtboardNotificationKind.result);
      expect(shown.title, 'Új eredmény: Nikola Jokić');
      expect(shown.body, 'Győzelem 118–104 · vs. San Antonio Spurs');
      expect(shown.athleteName, 'Nikola Jokić');

      await w.run();
      expect(notifications.shown, hasLength(1));
    });

    test('több új eredménynél a legújabb szerepel, a régiek nem', () async {
      final w = watcher();
      source.results['Nikola Jokić'] = const [];
      await w.run();
      source.results['Nikola Jokić'] = [
        _result(
          'nba:3',
          now.subtract(const Duration(hours: 3)),
          outcome: 'loss',
          score: '109–112',
        ),
        _result('nba:2', now.subtract(const Duration(days: 1))),
        // Régi, de még nem látott (például szezonváltás): nem jelez.
        _result('nba:old', now.subtract(const Duration(days: 20))),
      ];
      await w.run();
      expect(
        notifications.shown.single.body,
        'Vereség 109–112 · vs. San Antonio Spurs (+1 további)',
      );
    });

    test('eredményforrás nélküli sportolónál nincs értesítés', () async {
      await watcher(athletes: const [_clark]).run();
      expect(source.calls, contains('results:Caitlin Clark'));
      expect(memory.saved!.seenResults, isEmpty);
      expect(notifications.shown, isEmpty);
    });
  });

  group('Meccs kezdődik', () {
    test(
      '15 percen belüli kezdés egyszer jelez, újraindítás után sem ismétlődik',
      () async {
        source.events['Nikola Jokić'] = [
          _event(now.add(const Duration(minutes: 10))),
        ];
        final first = watcher();
        await first.run();
        await first.run();
        expect(notifications.shown, hasLength(1));
        final shown = notifications.shown.single;
        expect(shown.kind, CourtboardNotificationKind.matchStart);
        expect(shown.title, 'Hamarosan kezdődik: Nikola Jokić');
        expect(
          shown.body,
          'Denver Nuggets – Utah Jazz · kezdés 18:10 · NBA · Alapszakasz',
        );

        // Új példány ugyanazzal az emlékezettel (az app újraindítása).
        now = now.add(const Duration(minutes: 3));
        await watcher().run();
        expect(notifications.shown, hasLength(1));
      },
    );

    test(
      'elkezdett, távoli vagy időpont nélküli eseménynél nincs jelzés',
      () async {
        source.events['Nikola Jokić'] = [
          _event(
            now.subtract(const Duration(minutes: 20)),
            opponent: 'Phoenix Suns',
          ),
          _event(now.add(const Duration(hours: 3)), opponent: 'Chicago Bulls'),
          _event(
            now.add(const Duration(minutes: 5)),
            opponent: 'Utah Jazz',
            timeKnown: false,
          ),
        ];
        final w = watcher();
        await w.run();
        expect(notifications.shown, isEmpty);
        expect(w.scheduledReminders, isEmpty);
      },
    );

    test(
      'a következő futás előtt esedékes kezdésre pontos emlékeztető fut',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 10, 1, 18);
          DateTime clock() => start.add(async.elapsed);
          source.events['Nikola Jokić'] = [
            _event(start.add(const Duration(minutes: 25))),
          ];
          final w = AthleteWatcher(
            source: source,
            notifications: notifications,
            memoryStore: memory,
            clock: clock,
          )..update(athletes: const [_jokic]);
          unawaited(w.run());
          async.flushMicrotasks();
          expect(notifications.shown, isEmpty);
          expect(w.scheduledReminders, hasLength(1));

          async.elapse(const Duration(minutes: 9, seconds: 59));
          expect(notifications.shown, isEmpty);
          async.elapse(const Duration(seconds: 1));
          expect(
            notifications.shown.single.kind,
            CourtboardNotificationKind.matchStart,
          );

          // A következő futás már nem jelez újra.
          unawaited(w.run());
          async.flushMicrotasks();
          expect(notifications.shown, hasLength(1));
          w.dispose();
        });
      },
    );

    test('a régi esemény-UID-ok törlődnek', () {
      final stored = WatcherMemory(
        notifiedEvents: {
          'old': now.subtract(const Duration(days: 3)),
          'recent': now.subtract(const Duration(hours: 3)),
        },
        seenResults: {
          'Nikola Jokić': ['x'],
          'Törölt Sportoló': ['y'],
        },
      );
      stored.prune(now, {'Nikola Jokić'});
      expect(stored.notifiedEvents.keys, ['recent']);
      expect(stored.seenResults.keys, ['Nikola Jokić']);
      final restored = WatcherMemory.fromJson(stored.toJson());
      expect(
        restored.notifiedEvents['recent'],
        stored.notifiedEvents['recent'],
      );
      expect(restored.seenResults, stored.seenResults);
    });
  });

  group('Új hír', () {
    test('több sportoló új hírei egy értesítésbe kerülnek', () async {
      final w = watcher(athletes: const [_jokic, _clark]);
      await w.run();
      source.news['Nikola Jokić'] = [
        _article(
          'j1',
          now.subtract(const Duration(hours: 2)),
          'Jokić MVP-esélyes',
        ),
        _article(
          'j2',
          now.subtract(const Duration(minutes: 30)),
          'Nuggets győzelem',
        ),
      ];
      source.news['Caitlin Clark'] = [
        _article('c1', now.subtract(const Duration(hours: 1)), 'Clark rekord'),
        // Régi, eddig nem látott cikk: nem jelez.
        _article('c0', now.subtract(const Duration(days: 5)), 'Régi hír'),
      ];
      await w.run();
      expect(notifications.shown, hasLength(1));
      final shown = notifications.shown.single;
      expect(shown.kind, CourtboardNotificationKind.news);
      expect(shown.title, '3 új hír a követett sportolókról');
      expect(
        shown.body,
        'Nikola Jokić (2), Caitlin Clark (1) · Nuggets győzelem',
      );
      expect(shown.athleteName, isNull);
      expect(source.newsRefreshes, 2);
    });

    test('egy sportoló egy hírénél a profilra mutat', () async {
      final w = watcher();
      await w.run();
      source.news['Nikola Jokić'] = [
        _article(
          'j1',
          now.subtract(const Duration(hours: 2)),
          'Jokić MVP-esélyes',
        ),
      ];
      await w.run();
      expect(notifications.shown.single.title, 'Új hír: Nikola Jokić');
      expect(notifications.shown.single.body, 'Jokić MVP-esélyes');
      expect(notifications.shown.single.athleteName, 'Nikola Jokić');
    });
  });

  group('beállítások', () {
    test('kikapcsolt értesítéseknél nincs lekérdezés', () async {
      final report = await watcher(
        settings: const NotificationSettings(enabled: false),
      ).run();
      expect(report.skipReason, 'disabled');
      expect(source.calls, isEmpty);
      expect(source.newsRefreshes, 0);
    });

    test('figyelt sportoló nélkül nincs lekérdezés', () async {
      final report = await watcher(athletes: const []).run();
      expect(report.skipReason, 'no-athletes');
      expect(source.calls, isEmpty);
    });

    test('típusonkénti kapcsolók', () async {
      source.events['Nikola Jokić'] = [
        _event(now.add(const Duration(minutes: 10))),
      ];
      final w = watcher(
        settings: const NotificationSettings(matchStart: false, news: false),
      );
      await w.run();
      expect(notifications.shown, isEmpty);
      expect(source.calls, ['results:Nikola Jokić']);
      expect(source.newsRefreshes, 0);

      w.update(
        settings: const NotificationSettings(results: false, news: false),
      );
      source.calls.clear();
      await w.run();
      expect(source.calls, ['upcoming:Nikola Jokić']);
      expect(
        notifications.shown.single.kind,
        CourtboardNotificationKind.matchStart,
      );
    });

    test('csendes órában nem jelenik meg értesítés, és utólag sem', () async {
      const quiet = NotificationSettings(
        quietHours: true,
        quietStartMinutes: 23 * 60,
        quietEndMinutes: 7 * 60,
      );
      now = DateTime(2026, 10, 1, 22, 30);
      source.results['Nikola Jokić'] = const [];
      final w = watcher(settings: quiet);
      await w.run();
      now = DateTime(2026, 10, 1, 23, 30);
      source.results['Nikola Jokić'] = [
        _result('nba:9', now.subtract(const Duration(minutes: 30))),
      ];
      final report = await w.run();
      expect(report.suppressed, 1);
      expect(notifications.shown, isEmpty);

      now = DateTime(2026, 10, 2, 7, 30);
      await w.run();
      expect(notifications.shown, isEmpty);
    });

    test('szüneteltetés egy órára, utána újra jelez', () async {
      final w = watcher();
      source.results['Nikola Jokić'] = const [];
      await w.run();
      w.update(pausedUntil: now.add(const Duration(hours: 1)));
      expect(w.isPaused, isTrue);
      source.results['Nikola Jokić'] = [
        _result('nba:1', now.subtract(const Duration(minutes: 10))),
      ];
      final paused = await w.run();
      expect(paused.suppressed, 1);
      expect(notifications.shown, isEmpty);

      now = now.add(const Duration(minutes: 61));
      expect(w.isPaused, isFalse);
      source.results['Nikola Jokić'] = [
        _result('nba:2', now.subtract(const Duration(minutes: 5))),
        _result('nba:1', now.subtract(const Duration(minutes: 71))),
      ];
      await w.run();
      expect(notifications.shown.single.id, 'result:Nikola Jokić:nba:2');

      w.update(pausedUntil: now.add(const Duration(hours: 1)));
      w.update(clearPause: true);
      expect(w.isPaused, isFalse);
    });

    test('egy sportoló forráshibája nem állítja meg a többit', () async {
      final w = watcher(athletes: const [_jokic, _clark]);
      source.failing = true;
      final report = await w.run();
      expect(report.shown, isEmpty);
      source.failing = false;
      await w.run();
      expect(
        memory.saved!.seenNews.keys,
        containsAll(['Nikola Jokić', 'Caitlin Clark']),
      );
    });
  });

  group('ütemezés', () {
    test('első futás késleltetve, utána a beállított időközönként', () {
      fakeAsync((async) {
        final start = DateTime(2026, 10, 1, 12);
        final w = AthleteWatcher(
          source: source,
          notifications: notifications,
          memoryStore: memory,
          clock: () => start.add(async.elapsed),
          startDelay: const Duration(seconds: 45),
        )..update(athletes: const [_jokic]);
        w.start();
        async.elapse(const Duration(seconds: 44));
        expect(source.newsRefreshes, 0);
        async.elapse(const Duration(seconds: 1));
        expect(source.newsRefreshes, 1);
        async.elapse(const Duration(minutes: 15));
        expect(source.newsRefreshes, 2);

        // Gyakoriságváltás: az ütemezés újraindul az új időközzel.
        w.update(settings: const NotificationSettings(intervalMinutes: 5));
        async.elapse(const Duration(minutes: 5));
        expect(source.newsRefreshes, 3);
        async.elapse(const Duration(minutes: 10));
        expect(source.newsRefreshes, 5);

        w.stop();
        async.elapse(const Duration(hours: 1));
        expect(source.newsRefreshes, 5);
        w.dispose();
      });
    });

    test('egyidejű futások összevonódnak', () async {
      final w = watcher();
      final a = w.run();
      final b = w.run();
      expect(identical(await a, await b), isTrue);
      expect(source.newsRefreshes, 1);
    });
  });
}
