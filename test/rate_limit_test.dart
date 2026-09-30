import 'package:courtboard/data/friendly_error.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/rate_limit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateLimiter', () {
    test('queues requests beyond the per-minute limit', () async {
      var now = DateTime.utc(2026, 9, 30, 12);
      final waits = <Duration>[];
      final limiter = RateLimiter(
        clock: () => now,
        delay: (duration) async {
          waits.add(duration);
          now = now.add(duration);
        },
      );

      await limiter.acquire('football-data.org', 2);
      now = now.add(const Duration(seconds: 10));
      await limiter.acquire('football-data.org', 2);
      await limiter.acquire('football-data.org', 2);

      // A harmadik kérés az első utáni 60. másodpercig vár.
      expect(waits, [const Duration(seconds: 50)]);
      expect(now, DateTime.utc(2026, 9, 30, 12, 1));
      expect(limiter.pending('football-data.org'), 2);
      // Más szolgáltató kerete független.
      await limiter.acquire('TheSportsDB', 1);
      expect(waits, hasLength(1));
    });

    test('waiting callers are served in FIFO order', () async {
      var now = DateTime.utc(2026, 9, 30);
      final limiter = RateLimiter(
        clock: () => now,
        delay: (duration) async => now = now.add(duration),
      );
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 5; i++)
          limiter.acquire('BALLDONTLIE', 2).then((_) => order.add(i)),
      ]);

      expect(order, [0, 1, 2, 3, 4]);
      expect(now, DateTime.utc(2026, 9, 30, 0, 2));
    });
  });

  group('QuotaTracker', () {
    const limits = {
      'Napi': ProviderLimits(perDay: 2),
      'Havi': ProviderLimits(perMonth: 1),
      'Percenkénti': ProviderLimits(perMinute: 5),
    };

    test(
      'refuses requests after the daily limit until the next UTC day',
      () async {
        var now = DateTime.utc(2026, 9, 30, 23, 50);
        final storage = MemoryCacheStorage();
        final tracker = QuotaTracker(
          storage: storage,
          clock: () => now,
          limits: limits,
        );

        await tracker.reserve('Napi');
        await tracker.reserve('Napi');
        await expectLater(
          tracker.reserve('Napi'),
          throwsA(
            isA<QuotaExhaustedException>()
                .having((error) => error.used, 'used', 2)
                .having((error) => error.limit, 'limit', 2)
                .having((error) => error.period, 'period', QuotaPeriod.day),
          ),
        );

        // Az állás tartós: egy új példány ugyanazt látja.
        final reopened = QuotaTracker(
          storage: storage,
          clock: () => now,
          limits: limits,
        );
        expect(
          (await reopened.snapshot())
              .singleWhere((usage) => usage.provider == 'Napi')
              .label,
          'Ma: 2 / 2 kérés',
        );

        now = DateTime.utc(2026, 10, 1, 0, 1);
        await reopened.reserve('Napi');
        final usage = (await reopened.snapshot()).singleWhere(
          (usage) => usage.provider == 'Napi',
        );
        expect(usage.used, 1);
        expect(usage.remaining, 1);
      },
    );

    test('monthly quota resets in the next month', () async {
      var now = DateTime.utc(2026, 9, 15);
      final tracker = QuotaTracker(
        storage: MemoryCacheStorage(),
        clock: () => now,
        limits: limits,
      );

      await tracker.reserve('Havi');
      await expectLater(
        tracker.reserve('Havi'),
        throwsA(
          isA<QuotaExhaustedException>().having(
            (error) => error.period,
            'period',
            QuotaPeriod.month,
          ),
        ),
      );
      now = DateTime.utc(2026, 10, 1);
      await tracker.reserve('Havi');
      expect(
        (await tracker.snapshot())
            .singleWhere((usage) => usage.provider == 'Havi')
            .label,
        'E hónapban: 1 / 1 kérés',
      );
    });

    test(
      'providers without a daily or monthly limit are not tracked',
      () async {
        final storage = MemoryCacheStorage();
        final tracker = QuotaTracker(storage: storage, limits: limits);
        for (var i = 0; i < 10; i++) {
          await tracker.reserve('Percenkénti');
          await tracker.reserve('Ismeretlen');
        }
        expect(storage.length, 0);
        expect((await tracker.snapshot()).map((usage) => usage.provider), [
          'Napi',
          'Havi',
        ]);
      },
    );

    test('the default configuration documents the free quotas', () {
      expect(providerLimits['API-Sports']?.perMinute, 10);
      expect(providerLimits['API-Sports']?.perDay, 100);
      expect(providerLimits['BALLDONTLIE']?.perMinute, 5);
      expect(providerLimits['football-data.org']?.perMinute, 10);
      expect(providerLimits['TheSportsDB']?.perMinute, 30);
      expect(providerLimits['Live Tennis API']?.perDay, 100);
      expect(providerLimits['RapidAPI Darts']?.perMonth, 1000);
      expect(providerLimits['RapidAPI WNBA']?.perMonth, 100);
    });

    test('friendlyError explains the local quota in Hungarian', () {
      expect(
        friendlyError(
          QuotaExhaustedException(
            provider: 'API-Sports',
            used: 100,
            limit: 100,
            period: QuotaPeriod.day,
          ),
        ),
        'Elérted a napi keretet (100/100) – holnap újra elérhető.',
      );
      expect(
        friendlyError(
          QuotaExhaustedException(
            provider: 'RapidAPI WNBA',
            used: 100,
            limit: 100,
            period: QuotaPeriod.month,
          ),
        ),
        'Elérted a havi keretet (100/100) – jövő hónapban újra elérhető.',
      );
    });
  });
}
