import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/window_geometry.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_http.dart';

void main() {
  group('NotificationSettings', () {
    test('alapértékek és JSON-oda-vissza', () {
      const defaults = NotificationSettings();
      expect(defaults.enabled, isTrue);
      expect(defaults.intervalMinutes, 15);
      expect(defaults.quietHours, isFalse);
      expect(NotificationSettings.fromJson(null), defaults);
      expect(NotificationSettings.fromJson(const {}), defaults);

      final custom = defaults.copyWith(
        news: false,
        intervalMinutes: 60,
        quietHours: true,
        quietStartMinutes: 22 * 60 + 30,
        quietEndMinutes: 6 * 60,
      );
      expect(NotificationSettings.fromJson(custom.toJson()), custom);
    });

    test('hibás gyakoriság és időpont helyett alapérték', () {
      final parsed = NotificationSettings.fromJson(const {
        'intervalMinutes': 7,
        'quietStart': 5000,
        'quietEnd': -1,
      });
      expect(parsed.intervalMinutes, 15);
      expect(parsed.quietStartMinutes, 23 * 60);
      expect(parsed.quietEndMinutes, 7 * 60);
      expect(
        const NotificationSettings()
            .copyWith(intervalMinutes: 3)
            .intervalMinutes,
        15,
      );
    });

    test('csendes órák éjfélen átnyúlva és napon belül', () {
      const overnight = NotificationSettings(
        quietHours: true,
        quietStartMinutes: 23 * 60,
        quietEndMinutes: 7 * 60,
      );
      expect(overnight.isQuietAt(DateTime(2026, 10, 1, 23)), isTrue);
      expect(overnight.isQuietAt(DateTime(2026, 10, 2, 3, 15)), isTrue);
      expect(overnight.isQuietAt(DateTime(2026, 10, 2, 6, 59)), isTrue);
      expect(overnight.isQuietAt(DateTime(2026, 10, 2, 7)), isFalse);
      expect(overnight.isQuietAt(DateTime(2026, 10, 1, 22, 59)), isFalse);

      const daytime = NotificationSettings(
        quietHours: true,
        quietStartMinutes: 13 * 60,
        quietEndMinutes: 14 * 60,
      );
      expect(daytime.isQuietAt(DateTime(2026, 10, 1, 13, 30)), isTrue);
      expect(daytime.isQuietAt(DateTime(2026, 10, 1, 14)), isFalse);

      // Kikapcsolva soha nincs csend.
      expect(
        overnight
            .copyWith(quietHours: false)
            .isQuietAt(DateTime(2026, 10, 1, 23, 30)),
        isFalse,
      );
      expect(formatMinuteOfDay(7 * 60 + 5), '07:05');
    });
  });

  group('WindowGeometry', () {
    const saved = WindowGeometry(left: 100, top: 80, width: 1440, height: 900);

    test('JSON-oda-vissza, hibás vagy túl kicsi mentés elvetése', () {
      expect(WindowGeometry.fromJson(saved.toJson()), saved);
      final maximized = saved.copyWith(maximized: true);
      expect(WindowGeometry.fromJson(maximized.toJson())!.maximized, isTrue);
      expect(WindowGeometry.fromJson(null), isNull);
      expect(WindowGeometry.fromJson(const {'left': 0}), isNull);
      expect(
        WindowGeometry.fromJson(const {
          'left': 0,
          'top': 0,
          'width': 200,
          'height': 900,
        }),
        isNull,
      );
      expect(
        WindowGeometry.fromJson(const {
          'left': 0,
          'top': 0,
          'width': 1000,
          'height': 99999,
        }),
        isNull,
      );
    });

    // Két monitor: fő 1920×1040 munkaterülettel, jobbra egy 1280×984-es.
    PixelRect? monitors(PixelRect rect) {
      const areas = [
        PixelRect(0, 0, 1920, 1040),
        PixelRect(1920, 0, 3200, 984),
      ];
      for (final area in areas) {
        if (rect.left < area.right &&
            rect.right > area.left &&
            rect.top < area.bottom &&
            rect.bottom > area.top) {
          return area;
        }
      }
      return null;
    }

    test('látható helyzet változatlan marad', () {
      expect(fitWindowGeometry(saved, monitors), saved);
    });

    test('leválasztott monitoron mentett ablak helyett alapablak', () {
      const offscreen = WindowGeometry(
        left: 4000,
        top: 100,
        width: 1200,
        height: 800,
      );
      expect(fitWindowGeometry(offscreen, monitors), isNull);
      // A címsor a képernyő fölött: nem elérhető.
      const aboveTop = WindowGeometry(
        left: 100,
        top: -600,
        width: 1200,
        height: 800,
      );
      expect(fitWindowGeometry(aboveTop, monitors), isNull);
      expect(fitWindowGeometry(null, monitors), isNull);
    });

    test('kilógó vagy túl nagy ablak a monitor munkaterületére igazodik', () {
      const partly = WindowGeometry(
        left: 2800,
        top: 500,
        width: 1000,
        height: 800,
      );
      final fitted = fitWindowGeometry(partly, monitors)!;
      expect(fitted.left, 2200);
      expect(fitted.top, 184);
      expect(fitted.width, 1000);

      const huge = WindowGeometry(
        left: 10,
        top: 10,
        width: 2600,
        height: 1600,
        maximized: true,
      );
      final clamped = fitWindowGeometry(huge, monitors)!;
      expect(
        clamped,
        const WindowGeometry(
          left: 0,
          top: 0,
          width: 1920,
          height: 1040,
          maximized: true,
        ),
      );
    });
  });

  group('Indítás a Windows-zal', () {
    const exe = r'C:\Program Files\Courtboard\courtboard.exe';

    test('a Run-bejegyzés parancsa és felismerése', () {
      expect(startupCommand(exe, minimized: false), '"$exe"');
      expect(startupCommand(exe, minimized: true), '"$exe" --minimized');
      expect(startupCommandTargets('"$exe" --minimized', exe), isTrue);
      expect(
        startupCommandTargets(
          r'"C:\PROGRAM FILES\courtboard\Courtboard.exe"',
          exe,
        ),
        isTrue,
      );
      expect(startupCommandTargets('$exe --minimized', exe), isTrue);
      expect(startupCommandTargets(r'"D:\Régi\courtboard.exe"', exe), isFalse);
      expect(startupCommandIsMinimized('"$exe" --minimized'), isTrue);
      expect(startupCommandIsMinimized('"$exe"'), isFalse);
    });

    test('indítási kapcsoló értelmezése', () {
      expect(LaunchOptions.parse(const []).minimized, isFalse);
      expect(LaunchOptions.parse(const ['--minimized']).minimized, isTrue);
      expect(LaunchOptions.parse(const ['--MINIMIZED ']).minimized, isTrue);
      expect(LaunchOptions.parse(const ['--other']).minimized, isFalse);
    });

    test('memóriabeli megvalósítás', () async {
      final startup = MemoryStartupRegistration();
      expect(await startup.isEnabled(), isFalse);
      await startup.setEnabled(true, minimized: true);
      expect(await startup.isEnabled(), isTrue);
      expect(startupCommandIsMinimized(startup.command!), isTrue);
      await startup.setEnabled(false, minimized: true);
      expect(await startup.isEnabled(), isFalse);
    });
  });

  group('helyi állapot', () {
    test('az asztali beállítások alapértéke és mentése', () {
      const empty = CourtboardLocalState();
      expect(empty.closeToTray, isFalse);
      expect(empty.startMinimized, isFalse);
      expect(empty.windowGeometry, isNull);
      expect(empty.notificationsPausedUntil, isNull);
      // A 0.11.0 előtti állapotfájlokban nincsenek ilyen mezők.
      final legacy = CourtboardLocalState.fromJson(const {'theme': 'green'});
      expect(legacy.closeToTray, isFalse);
      expect(legacy.notifications, const NotificationSettings());

      final paused = DateTime(2026, 10, 1, 19, 30);
      final state = CourtboardLocalState(
        closeToTray: true,
        closeToTrayHintShown: true,
        startMinimized: true,
        windowGeometry: const WindowGeometry(
          left: -1200,
          top: 40,
          width: 1100,
          height: 700,
          maximized: true,
        ),
        notifications: const NotificationSettings(
          results: false,
          intervalMinutes: 30,
        ),
        notificationsPausedUntil: paused,
      );
      final restored = CourtboardLocalState.fromJson(state.toJson());
      expect(restored.closeToTray, isTrue);
      expect(restored.closeToTrayHintShown, isTrue);
      expect(restored.startMinimized, isTrue);
      expect(restored.windowGeometry, state.windowGeometry);
      expect(restored.notifications, state.notifications);
      expect(restored.notificationsPausedUntil, paused);
      // A régi kulcsok átköltöztetése nem veszíti el az új mezőket.
      final migrated = restored.withLegacyApiKeys(const {});
      expect(migrated.windowGeometry, state.windowGeometry);
      expect(migrated.notifications, state.notifications);
      expect(restored.withWindowGeometry(null).windowGeometry, isNull);
    });
  });

  group('ESPN befejezett mérkőzések', () {
    test('a menetrendből csak a lejátszott meccsek, a legújabb elöl', () {
      final games = EspnScheduleRepository.parseCompletedGames(
        fixture('espn_nba_schedule_den.json'),
        league: EspnLeague.nba,
        team: const EspnTeam(id: '7', displayName: 'Denver Nuggets'),
      );
      expect(games, isNotEmpty);
      final game = games.first;
      expect(game.opponent, 'Oklahoma City Thunder');
      expect(game.ownScore, '105');
      expect(game.opponentScore, '110');
      expect(game.score, '105–110');
      expect(game.outcome, 'loss');
      expect(game.homeAway, 'away');
      expect(EspnCompletedGame.fromJson(game.toJson())!.score, game.score);
    });

    test('scoreboard-formátum (szöveges pontszám, winner jelző)', () {
      final games = EspnScheduleRepository.parseCompletedGames(
        {
          'events': [
            {
              'id': '1',
              'date': '2026-10-20T00:00Z',
              'competitions': [
                {
                  'status': {
                    'type': {
                      'state': 'post',
                      'completed': true,
                      'name': 'STATUS_FINAL',
                    },
                  },
                  'competitors': [
                    {
                      'homeAway': 'home',
                      'winner': true,
                      'score': '98',
                      'team': {'id': '7', 'displayName': 'Denver Nuggets'},
                    },
                    {
                      'homeAway': 'away',
                      'winner': false,
                      'score': '91',
                      'team': {'id': '26', 'displayName': 'Utah Jazz'},
                    },
                  ],
                },
              ],
            },
            {
              'id': '2',
              'date': '2026-10-24T00:00Z',
              'competitions': [
                {
                  'status': {
                    'type': {'state': 'pre', 'completed': false},
                  },
                  'competitors': const <Object>[],
                },
              ],
            },
          ],
        },
        league: EspnLeague.nba,
        team: const EspnTeam(id: '7', displayName: 'Denver Nuggets'),
      );
      expect(games, hasLength(1));
      expect(games.single.outcome, 'win');
      expect(games.single.score, '98–91');
      expect(games.single.opponent, 'Utah Jazz');
    });

    test('recentResults gyorsítótárból jön a második hívásnál', () async {
      final http = FakeHttpService({
        '/apis/site/v2/sports/basketball/nba/teams/7/schedule': fixture(
          'espn_nba_schedule_den.json',
        ),
      });
      final repository = EspnScheduleRepository(http: http);
      const team = EspnTeam(id: '7', displayName: 'Denver Nuggets');
      final first = await repository.recentResults(EspnLeague.nba, team);
      final second = await repository.recentResults(EspnLeague.nba, team);
      expect(first.map((game) => game.id), second.map((game) => game.id));
      expect(http.requests, hasLength(1));
    });
  });
}
