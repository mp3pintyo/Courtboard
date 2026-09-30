import 'dart:io';

import 'package:courtboard/data/http_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late HttpClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = createHttpClient();
    server.listen((request) async {
      switch (request.uri.path) {
        case '/ok':
          request.response.write('{"value": 42}');
        case '/quota':
          request.response
            ..statusCode = 429
            ..headers.set(HttpHeaders.retryAfterHeader, '120')
            ..write('Too many requests');
        case '/forbidden':
          request.response
            ..statusCode = 403
            ..write('Invalid key');
        case '/slow':
          await Future<void>.delayed(const Duration(seconds: 2));
          request.response.write('late');
        default:
          request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.http('127.0.0.1:${server.port}', path, query);

  test('createHttpClient sets the shared connection timeout', () {
    expect(client.connectionTimeout, httpConnectionTimeout);
  });

  test('successful GET returns decoded JSON', () async {
    final json = await httpGetJson(client, uri('/ok'), provider: 'Teszt');
    expect(json['value'], 42);
  });

  test('429 exposes status and Retry-After without leaking the query key',
      () async {
    final future = httpGetText(
      client,
      uri('/quota', {'key': 'SECRET-KEY-123', 'q': 'Jokic'}),
      provider: 'YouTube Data API',
    );
    await expectLater(
      future,
      throwsA(isA<CourtboardHttpException>()
          .having((error) => error.statusCode, 'statusCode', 429)
          .having((error) => error.isRateLimited, 'isRateLimited', isTrue)
          .having((error) => error.retryAfter, 'retryAfter',
              const Duration(seconds: 120))
          .having((error) => '$error', 'message',
              allOf(contains('YouTube Data API'), contains('kvóta'),
                  isNot(contains('SECRET-KEY-123'))))
          .having((error) => '${error.uri}', 'uri',
              isNot(contains('SECRET-KEY-123')))),
    );
  });

  test('403 is reported as an authentication problem', () async {
    await expectLater(
      httpGetText(client, uri('/forbidden'), provider: 'football-data.org'),
      throwsA(isA<CourtboardHttpException>()
          .having((error) => error.isAuthError, 'isAuthError', isTrue)
          .having((error) => '$error', 'message',
              startsWith('football-data.org: a kulcs hibás'))),
    );
  });

  test('overall timeout covers the whole request', () async {
    await expectLater(
      httpGetText(client, uri('/slow'),
          provider: 'Teszt', timeout: const Duration(milliseconds: 200)),
      throwsA(isA<CourtboardHttpException>()
          .having((error) => error.timedOut, 'timedOut', isTrue)),
    );
  });

  test('Retry-After accepts seconds and HTTP dates', () {
    final now = DateTime.utc(2026, 9, 30, 12);
    expect(parseRetryAfter('30'), const Duration(seconds: 30));
    expect(
      parseRetryAfter(HttpDate.format(now.add(const Duration(minutes: 5))),
          now: now),
      const Duration(minutes: 5),
    );
    expect(parseRetryAfter('garbage'), isNull);
    expect(parseRetryAfter(null), isNull);
  });

  test('sanitizeUri drops the query string', () {
    expect(
      '${sanitizeUri(Uri.parse('https://www.googleapis.com/youtube/v3/search?key=abc&q=x'))}',
      'https://www.googleapis.com/youtube/v3/search',
    );
  });
}
