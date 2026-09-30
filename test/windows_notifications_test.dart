// A flutter_local_notifications-alapú értesítési szolgáltatás hamis
// toast-platformmal: valódi Windows-értesítés, registry-írás vagy
// COM-regisztráció a tesztekben soha nem történik.
import 'dart:io';
import 'dart:typed_data';

import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/desktop/windows_notifications.dart';
import 'package:courtboard/shared/images.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_desktop.dart';

class _FakeToastPlatform implements ToastPlatform {
  _FakeToastPlatform({
    this.initResult = true,
    this.initThrows = false,
    this.launch,
  });

  bool initResult;
  bool initThrows;
  bool showThrows = false;
  String? launch;
  int initCalls = 0;
  int cancelAllCalls = 0;
  final List<int> cancelled = [];
  final List<ToastRequest> shown = [];
  void Function(String? payload)? respond;

  @override
  bool packaged = false;

  @override
  Future<bool> initialize(void Function(String? payload) onResponse) async {
    initCalls++;
    if (initThrows) throw StateError('COM-regisztráció sikertelen');
    respond = onResponse;
    return initResult;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> show(ToastRequest request) async {
    if (showThrows) throw Exception('A toast nem jeleníthető meg');
    shown.add(request);
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelAllCalls++;
}

const _result = CourtboardNotification(
  id: 'result:Nikola Jokić:2026-09-29',
  kind: CourtboardNotificationKind.result,
  title: 'Új eredmény: Nikola Jokić',
  body: 'Győzelem 112–104',
  athleteName: 'Nikola Jokić',
);

const _news = CourtboardNotification(
  id: 'news:batch',
  kind: CourtboardNotificationKind.news,
  title: '3 új hír',
  body: '…',
);

void main() {
  group('NotificationPayload', () {
    test('oda-vissza: fajta, sportoló és gomb', () {
      final payload = NotificationPayload.encode(
        _result,
        NotificationAction.pauseOneHour,
      );
      final activation = NotificationPayload.decode(payload)!;
      expect(activation.action, NotificationAction.pauseOneHour);
      expect(activation.notification.kind, CourtboardNotificationKind.result);
      expect(activation.notification.athleteName, 'Nikola Jokić');
      expect(activation.notification.id, _result.id);
    });

    test('hibás vagy ismeretlen payload: null', () {
      expect(NotificationPayload.decode(null), isNull);
      expect(NotificationPayload.decode(''), isNull);
      expect(NotificationPayload.decode('nem json'), isNull);
      expect(NotificationPayload.decode('{"kind":"ismeretlen"}'), isNull);
      expect(NotificationPayload.decode('[1,2]'), isNull);
      // Ismeretlen gomb: sima megnyitás.
      expect(
        NotificationPayload.decode('{"kind":"news","action":"x"}')!.action,
        NotificationAction.open,
      );
    });

    test('gombok fajtánként', () {
      expect(_result.buttons, [
        NotificationAction.openProfile,
        NotificationAction.pauseOneHour,
      ]);
      expect(_news.buttons, [NotificationAction.openNews]);
      expect(
        const CourtboardNotification(
          id: 'tray-hint',
          kind: CourtboardNotificationKind.info,
          title: '',
          body: '',
        ).buttons,
        isEmpty,
      );
      expect(NotificationAction.openProfile.label, 'Profil megnyitása');
      expect(NotificationAction.pauseOneHour.label, 'Némítás 1 órára');
      expect(NotificationAction.openNews.label, 'Hírek megnyitása');
    });
  });

  group('FlutterLocalNotificationService', () {
    test('megjelenítés: stabil azonosító, payload, gombok és kép', () async {
      final platform = _FakeToastPlatform();
      final requestedImages = <String>[];
      final service = FlutterLocalNotificationService(
        platform: platform,
        imagePathFor: (url) async {
          requestedImages.add(url);
          return r'C:\cache\toast_images\jokic.png';
        },
      );

      expect(
        await service.show(_result.withImageUrl('https://img/jokic.png')),
        isTrue,
      );
      final request = platform.shown.single;
      expect(request.id, toastIdFor(_result.id));
      expect(request.id, toastIdFor(_result.id), reason: 'stabil');
      expect(request.title, _result.title);
      expect(request.imagePath, r'C:\cache\toast_images\jokic.png');
      expect(requestedImages, ['https://img/jokic.png']);
      expect(request.buttons.map((b) => b.$1), [
        'Profil megnyitása',
        'Némítás 1 órára',
      ]);
      expect(
        NotificationPayload.decode(request.buttons.last.$2)!.action,
        NotificationAction.pauseOneHour,
      );
      expect(
        NotificationPayload.decode(request.payload)!.notification.athleteName,
        'Nikola Jokić',
      );
      expect(service.description, 'Windows-értesítés');
      expect(service.supportsActions, isTrue);

      // Kép nélkül nincs képkeresés; hírnél „Hírek megnyitása”.
      await service.show(_news);
      expect(requestedImages, hasLength(1));
      expect(platform.shown.last.imagePath, isNull);
      expect(platform.shown.last.buttons.single.$1, 'Hírek megnyitása');
      expect(platform.initCalls, 1);
    });

    test('kattintás és gomb → aktiválás a kezelőnek', () async {
      final platform = _FakeToastPlatform();
      final service = FlutterLocalNotificationService(platform: platform);
      final received = <NotificationActivation>[];
      service.onActivated = received.add;
      await service.initialize();

      platform.respond!(
        NotificationPayload.encode(_result, NotificationAction.openProfile),
      );
      platform.respond!(
        NotificationPayload.encode(_news, NotificationAction.openNews),
      );
      platform.respond!('sérült');

      expect(received.map((a) => a.action), [
        NotificationAction.openProfile,
        NotificationAction.openNews,
        NotificationAction.open,
      ]);
      expect(received.first.notification.athleteName, 'Nikola Jokić');
      expect(received.last.notification.athleteName, isNull);
    });

    test(
      'értesítésből indított app: az aktiválás a kezelőig megmarad, egyszer',
      () async {
        final platform = _FakeToastPlatform(
          launch: NotificationPayload.encode(_result),
        );
        final service = FlutterLocalNotificationService(platform: platform);
        await service.initialize();

        final received = <NotificationActivation>[];
        service.onActivated = received.add;
        expect(received, hasLength(1));
        expect(received.single.notification.athleteName, 'Nikola Jokić');

        service.onActivated = null;
        service.onActivated = received.add;
        expect(received, hasLength(1), reason: 'nincs ismételt kézbesítés');
      },
    );

    test(
      'a COM-hívással már megérkezett kattintás nem duplázódik az indítási adatokkal',
      () async {
        final payload = NotificationPayload.encode(_news);
        final service = FlutterLocalNotificationService(
          platform: _RespondingDuringInit(
            _FakeToastPlatform(launch: payload),
            payload,
          ),
        );
        final received = <NotificationActivation>[];
        service.onActivated = received.add;
        await service.initialize();
        expect(received, hasLength(1));
      },
    );

    test('sikertelen inicializálás → tálcabuborék-tartalék', () async {
      final platform = _FakeToastPlatform(initResult: false);
      final fallback = FakeNotificationService();
      final service = FlutterLocalNotificationService(
        platform: platform,
        fallback: fallback,
      );
      expect(await service.initialize(), isFalse);
      expect(await service.show(_result), isTrue);
      expect(fallback.shown.single.id, _result.id);
      expect(platform.shown, isEmpty);
      expect(service.description, 'Teszt-értesítés');
      expect(service.available, isTrue);
    });

    test(
      'kivételt dobó inicializálás → tartalék; tartalék nélkül nem elérhető',
      () async {
        final service = FlutterLocalNotificationService(
          platform: _FakeToastPlatform(initThrows: true),
        );
        expect(await service.initialize(), isFalse);
        expect(await service.show(_result), isFalse);
        expect(service.available, isFalse);
        expect(service.description, 'Nem elérhető');
      },
    );

    test(
      'megjelenítési hiba → a további értesítések a tartalékon mennek',
      () async {
        final platform = _FakeToastPlatform()..showThrows = true;
        final fallback = FakeNotificationService();
        final service = FlutterLocalNotificationService(
          platform: platform,
          fallback: fallback,
        );
        expect(await service.show(_result), isTrue);
        platform.showThrows = false;
        expect(await service.show(_news), isTrue);
        expect(platform.shown, isEmpty);
        expect(fallback.shown.map((n) => n.id), [_result.id, _news.id]);
      },
    );

    test('a kezelő a tartalékra is átkerül; törlés mindkettőn', () async {
      final platform = _FakeToastPlatform();
      final fallback = FakeNotificationService();
      final service = FlutterLocalNotificationService(
        platform: platform,
        fallback: fallback,
      );
      await service.initialize();
      service.onActivated = (_) {};
      expect(fallback.hasClickHandler, isTrue);

      await service.clearAll();
      expect(platform.cancelAllCalls, 1);
      expect(fallback.clearCount, 1);
      await service.cancel(_result.id);
      expect(platform.cancelled, [toastIdFor(_result.id)]);
    });

    test('MSIX-csomagból futtatva a leírás jelzi', () async {
      final platform = _FakeToastPlatform()..packaged = true;
      final service = FlutterLocalNotificationService(platform: platform);
      await service.initialize();
      expect(service.description, 'Windows-értesítés (MSIX)');
    });
  });

  group('toast-kép a képgyorsítótárból', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('courtboard-toast-');
    });
    tearDown(() => directory.delete(recursive: true));

    test('formátumfelismerés', () {
      expect(
        toastImageExtension(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1])),
        'png',
      );
      expect(
        toastImageExtension(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
        'jpg',
      );
      expect(
        toastImageExtension(Uint8List.fromList([0x47, 0x49, 0x46, 0x38])),
        'gif',
      );
      expect(
        toastImageExtension(Uint8List.fromList([0x52, 0x49, 0x46])),
        isNull,
      );
    });

    test(
      'csak a gyorsítótárban meglévő képet másolja, letöltés nélkül',
      () async {
        final cache = ImageDiskCache(directory: '${directory.path}/images');
        const url = 'https://img.example/jokic.png';
        final target = '${directory.path}/toast';

        expect(
          await cachedToastImage(url, cache: cache, directory: target),
          isNull,
        );

        final source = cache.fileFor(url);
        await source.parent.create(recursive: true);
        await source.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0, 1, 2, 3]);
        final path = await cachedToastImage(
          url,
          cache: cache,
          directory: target,
        );
        expect(path, isNotNull);
        expect(path, endsWith('.png'));
        expect(await File(path!).readAsBytes(), await source.readAsBytes());

        // Ismeretlen formátum (például WebP): nincs kép.
        await source.writeAsBytes([0x52, 0x49, 0x46, 0x46]);
        expect(
          await cachedToastImage(url, cache: cache, directory: target),
          isNull,
        );
      },
    );
  });
}

/// Az inicializálás közben (a COM-regisztráció után) már kattintást jelző
/// platform, amelynek indítási adatai ugyanazt a kattintást adják vissza.
class _RespondingDuringInit implements ToastPlatform {
  _RespondingDuringInit(this.inner, this.payload);

  final _FakeToastPlatform inner;
  final String payload;

  @override
  bool get packaged => inner.packaged;

  @override
  Future<bool> initialize(void Function(String? payload) onResponse) async {
    final ok = await inner.initialize(onResponse);
    onResponse(payload);
    return ok;
  }

  @override
  Future<String?> launchPayload() => inner.launchPayload();

  @override
  Future<void> show(ToastRequest request) => inner.show(request);

  @override
  Future<void> cancel(int id) => inner.cancel(id);

  @override
  Future<void> cancelAll() => inner.cancelAll();
}
