import 'dart:io';

import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/rate_limit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Map<String, int> hits;
  late List<Duration> waits;
  late HttpService http;

  const limits = {
    'Teszt': ProviderLimits(perDay: 3),
    'Perces': ProviderLimits(perMinute: 1),
  };

  HttpService service({RateLimiter? limiter}) => HttpService(
    client: createHttpClient(),
    limits: limits,
    quota: QuotaTracker(storage: MemoryCacheStorage(), limits: limits),
    limiter: limiter,
    delay: (duration) async => waits.add(duration),
    random: () => 0,
  );

  setUp(() async {
    hits = {};
    waits = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      final count = hits[path] = (hits[path] ?? 0) + 1;
      final response = request.response;
      switch (path) {
        case '/ok':
          response.write('{"value": 1}');
        case '/flaky-429':
          if (count == 1) {
            response
              ..statusCode = 429
              ..headers.set(HttpHeaders.retryAfterHeader, '2');
          } else {
            response.write('{"value": 2}');
          }
        case '/long-429':
          response
            ..statusCode = 429
            ..headers.set(HttpHeaders.retryAfterHeader, '120');
        case '/flaky-503':
          if (count <= 2) {
            response.statusCode = 503;
          } else {
            response.write('recovered');
          }
        case '/always-500':
          response.statusCode = 500;
        case '/not-found':
          response.statusCode = 404;
        case '/etag':
          if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == '"v1"') {
            response.statusCode = HttpStatus.notModified;
          } else {
            response
              ..headers.set(HttpHeaders.etagHeader, '"v1"')
              ..write('<rss/>');
          }
        default:
          response.statusCode = 404;
      }
      await response.close();
    });
    http = service();
  });

  tearDown(() async {
    http.close();
    await server.close(force: true);
  });

  Uri uri(String path) => Uri.http('127.0.0.1:${server.port}', path);

  test('429 honours Retry-After once and then succeeds', () async {
    final json = await http.getJson(uri('/flaky-429'), provider: 'Egyéb');
    expect(json['value'], 2);
    expect(hits['/flaky-429'], 2);
    expect(waits, [const Duration(seconds: 2)]);
  });

  test('429 with a Retry-After above the cap is not retried', () async {
    await expectLater(
      http.getText(uri('/long-429'), provider: 'Egyéb'),
      throwsA(
        isA<CourtboardHttpException>().having(
          (error) => error.isRateLimited,
          'isRateLimited',
          isTrue,
        ),
      ),
    );
    expect(hits['/long-429'], 1);
    expect(waits, isEmpty);
  });

  test('5xx is retried twice with exponential backoff', () async {
    expect(
      await http.getText(uri('/flaky-503'), provider: 'Egyéb'),
      'recovered',
    );
    expect(hits['/flaky-503'], 3);
    expect(waits, [
      const Duration(milliseconds: 500),
      const Duration(milliseconds: 1000),
    ]);
  });

  test('persistent 5xx gives up after two retries', () async {
    await expectLater(
      http.getText(uri('/always-500'), provider: 'Egyéb'),
      throwsA(
        isA<CourtboardHttpException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
    expect(hits['/always-500'], 3);
  });

  test('other 4xx responses are never retried', () async {
    await expectLater(
      http.getText(uri('/not-found'), provider: 'Egyéb'),
      throwsA(
        isA<CourtboardHttpException>().having(
          (error) => error.isNotFound,
          'isNotFound',
          isTrue,
        ),
      ),
    );
    expect(hits['/not-found'], 1);
    expect(waits, isEmpty);
  });

  test('jitter stays within the configured fraction', () {
    const policy = RetryPolicy();
    final error = CourtboardHttpException(provider: 'X', statusCode: 502);
    final low = policy.retryDelay(
      error,
      transientRetries: 1,
      rateLimitRetries: 0,
      random: () => 0,
    );
    final high = policy.retryDelay(
      error,
      transientRetries: 1,
      rateLimitRetries: 0,
      random: () => 1,
    );
    expect(low, const Duration(seconds: 1));
    expect(high, const Duration(milliseconds: 1250));
    expect(
      policy.retryDelay(
        CourtboardHttpException(provider: 'X', timedOut: true),
        transientRetries: 2,
        rateLimitRetries: 0,
        random: () => 0,
      ),
      isNull,
    );
  });

  test('the local daily quota refuses requests before they are sent', () async {
    for (var i = 0; i < 3; i++) {
      await http.getText(uri('/ok'), provider: 'Teszt');
    }
    await expectLater(
      http.getText(uri('/ok'), provider: 'Teszt'),
      throwsA(isA<QuotaExhaustedException>()),
    );
    expect(hits['/ok'], 3);
    final usage = (await http.quota.snapshot()).single;
    expect(usage.label, 'Ma: 3 / 3 kérés');
  });

  test('per-minute limits queue requests through the limiter', () async {
    var now = DateTime.utc(2026, 9, 30);
    http.close();
    http = service(
      limiter: RateLimiter(
        clock: () => now,
        delay: (duration) async {
          waits.add(duration);
          now = now.add(duration);
        },
      ),
    );

    await http.getText(uri('/ok'), provider: 'Perces');
    await http.getText(uri('/ok'), provider: 'Perces');

    expect(hits['/ok'], 2);
    expect(waits, [const Duration(minutes: 1)]);
  });

  test('disabled network fails fast without sending anything', () async {
    final offline = HttpService(
      networkEnabled: false,
      quota: QuotaTracker(storage: MemoryCacheStorage()),
    );
    await expectLater(
      offline.getText(uri('/ok'), provider: 'Egyéb'),
      throwsA(
        isA<CourtboardHttpException>().having(
          (error) => error.statusCode,
          'statusCode',
          isNull,
        ),
      ),
    );
    expect(hits, isEmpty);
  });

  test('conditional requests expose ETag and accept 304', () async {
    final first = await http.getResponse(uri('/etag'), provider: 'RSS');
    expect(first.body, '<rss/>');
    expect(first.etag, '"v1"');
    final second = await http.getResponse(
      uri('/etag'),
      provider: 'RSS',
      headers: {HttpHeaders.ifNoneMatchHeader: '"v1"'},
    );
    expect(second.notModified, isTrue);
    expect(second.body, isEmpty);
  });
}
