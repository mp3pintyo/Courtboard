// Az AppController egységtesztjei: sportolólista, kitűzés, jegyzet,
// értesítésjelölés, beállítások, videólista és a mentések.
import 'dart:async';
import 'dart:io';

import 'package:courtboard/app/app_controller.dart';
import 'package:courtboard/app/seed_data.dart';
import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/playlist_store.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingStateStore extends LocalStateStore {
  _RecordingStateStore({this.failing = false})
    : super(file: File('nem-irt-allapot.json'));

  final bool failing;
  final List<CourtboardLocalState> saved = [];
  CourtboardLocalState? get last => saved.isEmpty ? null : saved.last;

  @override
  Future<void> save(CourtboardLocalState state) async {
    saved.add(state);
    if (failing) throw const FileSystemException('írásvédett');
  }
}

class _MemoryPlaylistStore extends PlaylistStore {
  _MemoryPlaylistStore({this.initial = const AthleteVideoPlaylist()})
    : super(File('nem-irt-videolista.json'));

  final AthleteVideoPlaylist initial;
  final List<AthleteVideoPlaylist> saved = [];
  bool failing = false;

  @override
  Future<PlaylistLoadResult> load() async =>
      PlaylistLoadResult(playlist: initial);

  @override
  Future<void> save(AthleteVideoPlaylist playlist) async {
    if (failing) throw const FileSystemException('írásvédett');
    saved.add(playlist);
  }
}

AppController _controller({
  CourtboardLocalState initialState = const CourtboardLocalState(),
  LocalStateStore? store,
  PlaylistStore? playlist,
  ApiKeyStore? keys,
  Map<ApiKeyId, String> apiKeys = const {},
  DateTime Function()? clock,
}) => AppController(
  initialState: initialState,
  stateStore: store,
  playlistStore: playlist,
  apiKeyStore: keys ?? ApiKeyStore(secrets: MemorySecretStore()),
  apiKeys: apiKeys,
  baseConfig: const SportsApiConfig(),
  clock: clock,
);

SavedYouTubeVideo _video(String id, String athlete) => SavedYouTubeVideo(
  videoId: id,
  athleteName: athlete,
  title: 'Videó $id',
  thumbnailUrl: '',
  savedAt: DateTime(2026, 9, 1),
);

void main() {
  group('athlete ids (routes)', () {
    test('seed and custom athletes get stable slug ids', () {
      final app = _controller(
        initialState: const CourtboardLocalState(
          customAthletes: [
            CustomAthlete(name: 'Iga Świątek', sport: 'Tenisz', team: ''),
          ],
        ),
      );
      expect(app.athleteById('nikola-jokic')?.name, 'Nikola Jokić');
      expect(app.athleteById('iga-swiatek')?.name, 'Iga Świątek');
      expect(app.athleteById('nincs'), isNull);
      // Az azonosító a mentésbe is bekerül (migráció a régi bejegyzésekhez).
      expect(app.currentState.customAthletes.single.id, 'iga-swiatek');
      app.dispose();
    });

    test('colliding slugs get a numeric suffix', () {
      final app = _controller();
      final added = app.addCustomAthlete(
        const CustomAthlete(name: 'Nikola Jokic', sport: 'NBA', team: 'X'),
      );
      expect(added?.id, 'nikola-jokic-2');
      expect(app.athleteById('nikola-jokic')?.name, 'Nikola Jokić');
      expect(app.athleteById('nikola-jokic-2')?.name, 'Nikola Jokic');
      // A saved id survives a reload.
      final reloaded = _controller(initialState: app.currentState);
      expect(reloaded.athleteById('nikola-jokic-2')?.name, 'Nikola Jokic');
      app.dispose();
      reloaded.dispose();
    });

    test('a saved id is kept as data', () {
      final custom = CustomAthlete.fromJson(const {
        'id': 'sajat-azonosito',
        'name': 'Teszt Elek',
        'sport': 'NBA',
        'team': '',
      });
      expect(custom.id, 'sajat-azonosito');
      final legacy = CustomAthlete.fromJson(const {
        'name': 'Teszt Elek',
        'sport': 'NBA',
        'team': '',
      });
      expect(legacy.id, 'teszt-elek');
    });
  });

  group('athletes', () {
    test('starts from the seed list with Hungarian sport metadata', () {
      final app = _controller();
      expect(app.athleteNames, [for (final a in seedAthletes) a.name]);
      expect(app.athleteNamed('Nikola Jokić')!.sport, Sport.nba);
      expect(app.athleteNamed('Luke Humphries')!.showsTeam, isFalse);
      app.dispose();
    });

    test('adding a custom athlete appends, persists and notifies', () {
      final store = _RecordingStateStore();
      final app = _controller(store: store);
      var notified = 0;
      app.addListener(() => notified++);

      final added = app.addCustomAthlete(
        const CustomAthlete(
          name: 'Iga Świątek',
          sport: 'Tenisz',
          team: '',
          country: 'Lengyelország',
        ),
      );

      expect(added, isNotNull);
      expect(added!.sport, Sport.tennis);
      expect(added.isCustom, isTrue);
      expect(app.athleteNames.last, 'Iga Świątek');
      expect(notified, 1);
      expect(store.saved, hasLength(1));
      final saved = store.last!;
      expect(saved.customAthletes.single.name, 'Iga Świątek');
      expect(saved.customAthletes.single.sport, 'Tenisz');
      expect(saved.athleteOrder.last, 'Iga Świątek');
      // Ugyanaz a név még egyszer nem kerül fel.
      expect(
        app.addCustomAthlete(
          const CustomAthlete(name: 'Iga Świątek', sport: 'Tenisz', team: ''),
        ),
        isNull,
      );
      app.dispose();
    });

    test('removing an athlete records it and drops its pin', () {
      final store = _RecordingStateStore();
      final app = _controller(
        store: store,
        initialState: const CourtboardLocalState(
          pinnedAthletes: ['Caitlin Clark', 'Nikola Jokić'],
        ),
      );
      app.removeAthlete(app.athleteNamed('Nikola Jokić')!);

      expect(app.athleteNames, isNot(contains('Nikola Jokić')));
      expect(app.pinned, ['Caitlin Clark']);
      expect(store.last!.removedAthleteNames, contains('Nikola Jokić'));
      expect(store.last!.pinnedAthletes, ['Caitlin Clark']);

      // Újraindítás után a törölt alapsportoló nem tér vissza.
      final restarted = _controller(initialState: store.last!);
      expect(restarted.athleteNames, isNot(contains('Nikola Jokić')));
      app.dispose();
      restarted.dispose();
    });

    test('reorder persists the custom order and survives a restart', () {
      final store = _RecordingStateStore();
      final app = _controller(store: store);
      final names = app.athleteNames;
      app.reorderAthletes(0, names.length - 1);
      expect(app.athleteNames.last, names.first);
      expect(store.last!.athleteOrder, app.athleteNames);

      // Azonos indexnél nincs változás és mentés.
      app.reorderAthletes(1, 1);
      expect(store.saved, hasLength(1));

      final restarted = _controller(initialState: store.last!);
      expect(restarted.athleteNames, app.athleteNames);
      app.dispose();
      restarted.dispose();
    });

    test('pin toggling returns the new state and keeps pin order', () {
      final store = _RecordingStateStore();
      final app = _controller(store: store);
      final clark = app.athleteNamed('Caitlin Clark')!;
      final jokic = app.athleteNamed('Nikola Jokić')!;

      expect(app.togglePin(clark), isTrue);
      expect(app.togglePin(jokic), isTrue);
      expect(app.pinned, ['Caitlin Clark', 'Nikola Jokić']);
      expect(app.isPinned(clark), isTrue);
      expect(app.togglePin(clark), isFalse);
      expect(app.pinned, ['Nikola Jokić']);
      expect(store.last!.pinnedAthletes, ['Nikola Jokić']);
      app.dispose();
    });

    test('notes and alerts are stored per athlete', () {
      final store = _RecordingStateStore();
      final app = _controller(store: store);
      final clark = app.athleteNamed('Caitlin Clark')!;

      app.setNote(clark, 'Rekordszezon');
      app.toggleAlert(clark);
      expect(app.noteFor(clark), 'Rekordszezon');
      expect(app.alertEnabled(clark), isTrue);
      expect(app.alertAthletes.map((a) => a.name), ['Caitlin Clark']);
      expect(store.last!.notes, {'Caitlin Clark': 'Rekordszezon'});
      expect(store.last!.alerts, {'Caitlin Clark': true});

      app.toggleAlert(clark);
      expect(app.alertEnabled(clark), isFalse);
      expect(app.alertAthletes, isEmpty);
      app.dispose();
    });

    test('custom athletes with an unknown sport survive a save', () {
      final store = _RecordingStateStore();
      final app = _controller(
        store: store,
        initialState: const CourtboardLocalState(
          customAthletes: [
            CustomAthlete(
              name: 'Jövőbeli Sportoló',
              sport: 'Curling',
              team: '',
            ),
          ],
        ),
      );
      expect(app.athleteNames, isNot(contains('Jövőbeli Sportoló')));
      app.setTheme('burgundy');
      expect(
        store.last!.customAthletes.map((a) => '${a.name}/${a.sport}'),
        contains('Jövőbeli Sportoló/Curling'),
      );
      app.dispose();
    });
  });

  group('settings', () {
    test('every setter persists and notifies', () {
      final store = _RecordingStateStore();
      final app = _controller(store: store);
      var notified = 0;
      app.addListener(() => notified++);

      app
        ..setTheme('burgundy')
        ..setThemeMode('dark')
        ..setOverviewSort('name')
        ..setAthleteSort('team')
        ..toggleRail()
        ..setCloseToTray(true)
        ..setStartMinimized(true)
        ..setNotificationSettings(const NotificationSettings(enabled: false));

      expect(notified, 8);
      expect(store.saved, hasLength(8));
      final saved = store.last!;
      expect(saved.theme, 'burgundy');
      expect(saved.themeMode, 'dark');
      expect(saved.overviewSort, 'name');
      expect(saved.athleteSort, 'team');
      expect(saved.railCollapsed, isTrue);
      expect(saved.closeToTray, isTrue);
      expect(saved.startMinimized, isTrue);
      expect(saved.notifications.enabled, isFalse);
      app.dispose();
    });

    test('initial state is applied and round-trips unchanged', () {
      const initial = CourtboardLocalState(
        theme: 'burgundy',
        themeMode: 'light',
        overviewSort: 'sport',
        athleteSort: 'name',
        railCollapsed: true,
        autoUpdateCheck: false,
        closeToTray: true,
        closeToTrayHintShown: true,
        notes: {'Caitlin Clark': 'jegyzet'},
      );
      final app = _controller(initialState: initial);
      expect(app.theme, 'burgundy');
      expect(app.themeMode, 'light');
      expect(app.railCollapsed, isTrue);
      expect(app.autoUpdateCheck, isFalse);
      final state = app.currentState;
      expect(state.toJson()..remove('athleteOrder'), {
        ...initial.toJson()..remove('athleteOrder'),
      });
      app.dispose();
    });

    test('notification pause expires and is saved', () {
      fakeAsync((async) {
        var now = DateTime(2026, 9, 30, 12);
        final store = _RecordingStateStore();
        final app = _controller(store: store, clock: () => now);

        app.toggleNotificationPause();
        expect(app.notificationsPaused, isTrue);
        expect(store.last!.notificationsPausedUntil, DateTime(2026, 9, 30, 13));

        now = now.add(const Duration(hours: 1));
        async.elapse(const Duration(hours: 1));
        expect(app.notificationsPaused, isFalse);
        expect(app.notificationsPausedUntil, isNull);
        expect(store.last!.notificationsPausedUntil, isNull);
        app.dispose();
      });
    });

    test('save failures are reported on the message stream', () async {
      final app = _controller(store: _RecordingStateStore(failing: true));
      final messages = <String>[];
      final sub = app.messages.listen(messages.add);
      app.setTheme('burgundy');
      await pumpEventQueue();
      expect(messages, ['A módosítások mentése nem sikerült. Próbáld újra.']);
      await sub.cancel();
      app.dispose();
    });

    test('flush awaits the final save', () async {
      final store = _RecordingStateStore();
      final app = _controller(store: store);
      await app.flush();
      expect(store.saved, hasLength(1));
      app.dispose();
    });
  });

  group('api keys', () {
    test(
      'saved key applies immediately and lands in the secure store',
      () async {
        final secrets = MemorySecretStore();
        final app = _controller(keys: ApiKeyStore(secrets: secrets));
        await app.saveApiKey(ApiKeyId.footballData, 'abc123');
        expect(app.apiConfig.key(ApiKeyId.footballData), 'abc123');
        expect(secrets.values.values, contains('abc123'));
        expect(app.secureStorageAvailable, isTrue);
        app.dispose();
      },
    );

    test('secure store failure keeps the key for the session only', () async {
      final app = _controller(
        keys: ApiKeyStore(secrets: MemorySecretStore(failing: true)),
      );
      final messages = <String>[];
      final sub = app.messages.listen(messages.add);
      await app.saveApiKey(ApiKeyId.footballData, 'abc123');
      await pumpEventQueue();
      expect(app.apiConfig.key(ApiKeyId.footballData), 'abc123');
      expect(app.secureStorageAvailable, isFalse);
      expect(messages.single, contains('az app bezárásáig érvényes'));
      await sub.cancel();
      app.dispose();
    });

    test('loaded keys override legacy JSON keys', () {
      final app = _controller(
        initialState: const CourtboardLocalState(
          legacyApiKeys: {ApiKeyId.footballData: 'régi'},
        ),
        apiKeys: const {ApiKeyId.footballData: 'új'},
      );
      expect(app.apiConfig.key(ApiKeyId.footballData), 'új');
      app.dispose();
    });
  });

  group('playlist', () {
    test('loads, adds and removes videos through the store', () async {
      final store = _MemoryPlaylistStore(
        initial: const AthleteVideoPlaylist().add(
          _video('aaaaaaaaaaa', 'Caitlin Clark'),
        ),
      );
      final app = _controller(playlist: store);
      await app.loadPlaylist();
      expect(app.playlist.forAthlete('Caitlin Clark'), hasLength(1));

      await app.addVideo(_video('bbbbbbbbbbb', 'Caitlin Clark'));
      expect(app.playlist.forAthlete('Caitlin Clark'), hasLength(2));
      expect(store.saved.last.forAthlete('Caitlin Clark'), hasLength(2));

      app.removeVideo(app.playlist.forAthlete('Caitlin Clark').first);
      await pumpEventQueue();
      expect(app.playlist.forAthlete('Caitlin Clark'), hasLength(1));
      expect(store.saved.last.forAthlete('Caitlin Clark'), hasLength(1));
      app.dispose();
    });

    test('a failed add leaves the playlist unchanged', () async {
      final store = _MemoryPlaylistStore()..failing = true;
      final app = _controller(playlist: store);
      await expectLater(
        app.addVideo(_video('ccccccccccc', 'Caitlin Clark')),
        throwsA(isA<FileSystemException>()),
      );
      expect(app.playlist.videos, isEmpty);
      app.dispose();
    });
  });

  test('disposed controller ignores late async results', () async {
    final completer = Completer<PlaylistLoadResult>();
    final store = _DelayedPlaylistStore(completer.future);
    final app = _controller(playlist: store);
    final load = app.loadPlaylist();
    app.dispose();
    completer.complete(const PlaylistLoadResult());
    await load;
  });
}

class _DelayedPlaylistStore extends PlaylistStore {
  _DelayedPlaylistStore(this.result) : super(File('nem-irt.json'));
  final Future<PlaylistLoadResult> result;

  @override
  Future<PlaylistLoadResult> load() => result;
}
