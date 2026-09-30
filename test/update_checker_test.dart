import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

const _path = '/repos/mp3pintyo/Courtboard/releases/latest';

Map<String, dynamic> _release({
  String tag = 'v0.12.0',
  bool prerelease = false,
  bool draft = false,
}) => fixture('github_release_latest.json')
  ..['tag_name'] = tag
  ..['prerelease'] = prerelease
  ..['draft'] = draft;

void main() {
  group('SemanticVersion', () {
    test('értelmezés: v-előtag, build-metaadat, előzetes kiadás', () {
      expect(SemanticVersion.tryParse('v0.12.0').toString(), '0.12.0');
      expect(SemanticVersion.tryParse('0.11.0+12').toString(), '0.11.0');
      expect(SemanticVersion.tryParse('1.2').toString(), '1.2.0');
      expect(SemanticVersion.tryParse('0.12.0-beta.2')?.preRelease, [
        'beta',
        '2',
      ]);
      for (final bad in ['', 'legfrissebb', '1', 'v1.x.0', '1.2.3.4', null]) {
        expect(SemanticVersion.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('elsőbbség a SemVer 2.0 szerint', () {
      final ordered = [
        '0.9.9',
        '0.10.0',
        '0.11.0-alpha',
        '0.11.0-alpha.1',
        '0.11.0-alpha.beta',
        '0.11.0-beta',
        '0.11.0-beta.2',
        '0.11.0-beta.11',
        '0.11.0-rc.1',
        '0.11.0',
        '0.11.1',
        '1.0.0',
      ].map((v) => SemanticVersion.tryParse(v)!).toList();
      for (var i = 0; i + 1 < ordered.length; i++) {
        expect(
          ordered[i + 1] > ordered[i],
          isTrue,
          reason: '${ordered[i + 1]} > ${ordered[i]}',
        );
      }
      expect(
        SemanticVersion.tryParse('0.11.0+12'),
        SemanticVersion.tryParse('v0.11.0'),
      );
    });
  });

  group('kiadás-értékelés fixture-ökkel', () {
    ReleaseInfo release(Map<String, dynamic> json) =>
        ReleaseInfo.fromJson(json)!;

    test('újabb kiadás → frissítés érhető el', () {
      final result = UpdateChecker.evaluate(
        current: '0.11.0+12',
        latest: release(_release()),
      );
      expect(result.status, UpdateStatus.updateAvailable);
      expect(result.latest?.version.toString(), '0.12.0');
      expect(
        result.latest?.htmlUrl,
        'https://github.com/mp3pintyo/Courtboard/releases/tag/v0.12.0',
      );
      expect(result.summary, contains('Új verzió érhető el: 0.12.0'));
    });

    test('azonos és régebbi kiadás → naprakész', () {
      for (final tag in ['v0.11.0', '0.10.0', 'v0.11.0+99']) {
        final result = UpdateChecker.evaluate(
          current: '0.11.0',
          latest: release(_release(tag: tag)),
        );
        expect(result.status, UpdateStatus.upToDate, reason: tag);
        expect(result.summary, contains('naprakész'));
      }
    });

    test('előzetes vagy vázlat kiadás soha nem frissítés', () {
      for (final json in [
        _release(tag: 'v0.12.0', prerelease: true),
        _release(tag: 'v0.12.0-beta.1'),
        _release(tag: 'v0.12.0', draft: true),
      ]) {
        final result = UpdateChecker.evaluate(
          current: '0.11.0',
          latest: release(json),
        );
        expect(result.updateAvailable, isFalse, reason: '${json['tag_name']}');
      }
    });

    test('hibás válasz: nincs értelmezhető kiadás', () {
      expect(
        ReleaseInfo.fromJson(fixture('github_release_malformed.json')),
        isNull,
      );
      expect(ReleaseInfo.fromJson(const {}), isNull);
      expect(ReleaseInfo.fromJson('szöveg'), isNull);
      // Nem GitHub-os oldal linkje nem kerülhet a felületre.
      expect(
        ReleaseInfo.fromJson(
          _release()..['html_url'] = 'https://example.com/letoltes',
        ),
        isNull,
      );
    });
  });

  group('UpdateChecker.check', () {
    late DateTime clock;
    setUp(() => clock = DateTime.utc(2026, 10, 21, 8));

    UpdateChecker checker(
      FakeHttpService http, {
      String version = '0.11.0',
      CacheStorage? storage,
    }) => UpdateChecker(
      currentVersion: version,
      http: http,
      cacheStorage: storage ?? MemoryCacheStorage(clock: () => clock),
      clock: () => clock,
    );

    test(
      'User-Agent fejléc, 12 órás gyorsítótár, kényszerített frissítés',
      () async {
        final http = FakeHttpService({_path: _release()});
        final updates = checker(http);

        final first = await updates.check();
        expect(first.updateAvailable, isTrue);
        expect(first.fromCache, isFalse);
        expect(http.requests.single.host, 'api.github.com');
        expect(
          http.headers.single['User-Agent'],
          startsWith('Courtboard/0.11.0'),
        );
        expect(http.headers.single['Accept'], 'application/vnd.github+json');

        clock = clock.add(const Duration(hours: 11));
        final cached = await updates.check();
        expect(cached.fromCache, isTrue);
        expect(cached.updateAvailable, isTrue);
        expect(http.requests, hasLength(1));

        await updates.check(force: true);
        expect(http.requests, hasLength(2));

        clock = clock.add(const Duration(hours: 13));
        await updates.check();
        expect(http.requests, hasLength(3));
      },
    );

    test('kéréskorlát (403/429): barátságos üzenet, nem dob', () async {
      for (final status in [403, 429]) {
        final result = await checker(
          FakeHttpService({
            _path: CourtboardHttpException(
              provider: 'GitHub',
              statusCode: status,
            ),
          }),
        ).check();
        expect(result.status, UpdateStatus.failed);
        expect(result.message, contains('kéréskorlát'));
      }
    });

    test('nincs kiadás (404), hálózati hiba, hibás válasz', () async {
      final missing = await checker(FakeHttpService({})).check();
      expect(missing.message, 'Még nincs közzétett kiadás.');

      final offline = await checker(
        FakeHttpService({_path: CourtboardHttpException(provider: 'GitHub')}),
      ).check();
      expect(offline.message, 'Nincs internetkapcsolat.');

      final storage = MemoryCacheStorage();
      final malformed = await checker(
        FakeHttpService({_path: fixture('github_release_malformed.json')}),
        storage: storage,
      ).check();
      expect(malformed.status, UpdateStatus.failed);
      expect(malformed.message, 'A kiadási adatok nem értelmezhetők.');
      // A hibás választ nem mentjük el.
      expect(storage.length, 0);
    });

    test('hálózati hibánál a régebbi, mentett eredmény használható', () async {
      final storage = MemoryCacheStorage(clock: () => clock);
      await checker(
        FakeHttpService({_path: _release()}),
        storage: storage,
      ).check();
      clock = clock.add(const Duration(days: 2));
      final result = await checker(
        FakeHttpService({_path: CourtboardHttpException(provider: 'GitHub')}),
        storage: storage,
      ).check();
      expect(result.updateAvailable, isTrue);
      expect(result.fromCache, isTrue);
    });

    test('ismeretlen futó verzióval nem kérdez', () async {
      final http = FakeHttpService({_path: _release()});
      final result = await checker(http, version: 'fejlesztői').check();
      expect(result.status, UpdateStatus.failed);
      expect(http.requests, isEmpty);
    });
  });
}
