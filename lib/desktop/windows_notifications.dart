/// Windows-értesítések (toast) a `flutter_local_notifications` csomaggal:
/// gombok, a sportoló képe, kattintás és indítás értesítésből.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:win32/win32.dart';

import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/file_util.dart' show fnv1a32Hex;
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/shared/images.dart';

/// A Courtboard Windows-értesítési azonosítói. Rögzítettek: a Windows ezek
/// alapján rendeli az értesítéseket (és a Beállítások → Értesítések
/// bejegyzést) az apphoz, a GUID pedig a kattintást fogadó COM-osztályé.
abstract final class CourtboardToastIdentity {
  static const appName = 'Courtboard';

  /// Alkalmazásazonosító (AUMID) a nem csomagolt futtatáshoz. MSIX-ből a
  /// csomag saját azonosítója él (a manifestből).
  static const appUserModelId = 'Mp3Pintyo.Courtboard';

  /// A kattintást fogadó COM-osztály azonosítója. Az MSIX-manifestben
  /// (`pubspec.yaml` → `msix_config.toast_activator.clsid`) ugyanez áll.
  static const activatorGuid = '2d8668a6-7c36-481c-99dd-25e4a414dc60';

  /// Ezzel a kapcsolóval indítja a Windows az appot, ha egy értesítésre
  /// akkor kattintanak, amikor az nem fut (a COM ehhez `-Embedding`-et is
  /// fűzhet); a Courtboard a többi kapcsolóhoz hasonlóan figyelmen kívül
  /// hagyja, a kattintás adatai a COM-hívással érkeznek.
  static const activationArgument = '-ToastActivated';
}

/// Egy megjelenítendő toast (a platformfüggetlen adatok).
class ToastRequest {
  const ToastRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    this.buttons = const [],
    this.imagePath,
  });

  /// A Windows-toast címkéje (`Tag`): ugyanazzal az azonosítóval küldött
  /// új értesítés felváltja a régit a Műveletközpontban.
  final int id;
  final String title;
  final String body;

  /// A kattintáskor visszaérkező szöveg ([NotificationPayload]).
  final String payload;

  /// Gombok: (felirat, a gomb payloadja).
  final List<(String label, String payload)> buttons;

  /// Helyi képfájl (PNG/JPEG/GIF) a toast bal oldalán (kör alakú).
  final String? imagePath;
}

/// A toast-platform vékony rétege (a tesztekben hamis megvalósítás).
abstract interface class ToastPlatform {
  /// Igaz, ha az app MSIX-csomagból fut (csomagazonosítója van).
  bool get packaged;

  /// Az értesítések beállítása; az [onResponse] minden kattintásnál (gombnál
  /// is) a payloadot kapja. Hamis vagy kivétel: a toast nem érhető el.
  Future<bool> initialize(void Function(String? payload) onResponse);

  /// Ha az appot egy értesítés indította, annak payloadja; egyébként `null`.
  Future<String?> launchPayload();

  Future<void> show(ToastRequest request);

  /// Egy értesítés visszavonása (nem csomagolt appnál a Windows ezt nem
  /// támogatja, ilyenkor hatástalan).
  Future<void> cancel(int id);

  /// Az app összes értesítésének törlése a Műveletközpontból.
  Future<void> cancelAll();
}

/// A valódi platform: `flutter_local_notifications` (Windows: C++/WinRT,
/// FFI).
///
/// **Nem csomagolt futtatás** (zip / `flutter run`): az inicializálás a
/// `HKCU\Software\Classes\AppUserModelId\Mp3Pintyo.Courtboard` kulcsba
/// írja az app nevét, ikonját és a COM-osztály GUID-ját, és a futó
/// folyamatban regisztrálja a COM-osztályt; így a kattintás a futó apphoz
/// érkezik. Hogy a Műveletközpontból a már bezárt app is elinduljon, a
/// [registerLocalServer] a `HKCU\Software\Classes\CLSID\{GUID}\
/// LocalServer32` alá beírja az exe útvonalát. A `cancel` itt nem működik
/// (csomagazonosító kell hozzá), a `cancelAll` igen.
///
/// **MSIX:** az azonosítót és a COM-kiszolgálót a csomag manifestje adja
/// (`msix_config.toast_activator`), a registry nem kell; a `cancel` is
/// működik.
class FlutterLocalNotificationsToastPlatform implements ToastPlatform {
  FlutterLocalNotificationsToastPlatform({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get packaged => RegistryStartupRegistration.isPackaged;

  /// Az értesítések ikonja (a registry `IconUri` értéke nem csomagolt
  /// futtatásnál); `null`, ha a fájl nincs meg.
  static String? _iconPath() {
    final exeDirectory = File(Platform.resolvedExecutable).parent.path;
    final icon = File(
      '$exeDirectory\\data\\flutter_assets\\assets\\tray\\app_icon.ico',
    );
    return icon.existsSync() ? icon.path : null;
  }

  @override
  Future<bool> initialize(void Function(String? payload) onResponse) async {
    final ready = await _plugin.initialize(
      settings: InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: CourtboardToastIdentity.appName,
          appUserModelId: CourtboardToastIdentity.appUserModelId,
          guid: CourtboardToastIdentity.activatorGuid,
          iconPath: packaged ? null : _iconPath(),
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onResponse(response.payload),
    );
    if (ready != true) return false;
    if (!packaged) {
      try {
        registerLocalServer();
      } catch (_) {
        // A futó appban a kattintás enélkül is működik; csak a bezárt app
        // nem indul el a Műveletközpontból.
      }
    }
    return true;
  }

  /// A kattintást fogadó COM-kiszolgáló bejegyzése a nem csomagolt
  /// futtatáshoz: `HKCU\Software\Classes\CLSID\{GUID}\LocalServer32` =
  /// `"<exe>" -ToastActivated`. Csak az aktuális felhasználót érinti.
  static void registerLocalServer({String? executablePath}) {
    final exe = executablePath ?? Platform.resolvedExecutable;
    final command = '"$exe" ${CourtboardToastIdentity.activationArgument}';
    final subKey =
        'Software\\Classes\\CLSID\\{${CourtboardToastIdentity.activatorGuid}}'
        '\\LocalServer32';
    using((arena) {
      final data = command.toPcwstr(allocator: arena);
      final result = RegSetKeyValue(
        HKEY_CURRENT_USER,
        subKey.toPcwstr(allocator: arena),
        null,
        REG_SZ,
        data.cast(),
        (command.length + 1) * 2,
      );
      if (result != ERROR_SUCCESS) {
        throw StateError('LocalServer32 bejegyzése sikertelen ($result)');
      }
    });
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<void> show(ToastRequest request) {
    final image = request.imagePath;
    return _plugin.show(
      id: request.id,
      title: request.title,
      body: request.body,
      payload: request.payload,
      notificationDetails: NotificationDetails(
        windows: WindowsNotificationDetails(
          actions: [
            for (final (label, payload) in request.buttons)
              WindowsAction(content: label, arguments: payload),
          ],
          images: [
            if (image != null)
              WindowsImage(
                Uri.file(image, windows: true),
                altText: request.title,
                placement: WindowsImagePlacement.appLogoOverride,
                crop: WindowsImageCrop.circle,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Az értesítés stabil, 31 bites azonosítója (a Windows-toast címkéje).
int toastIdFor(String notificationId) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(notificationId)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Windows-értesítés a `flutter_local_notifications` csomaggal (0.15.0-tól
/// az elsődleges megvalósítás).
///
/// - A payload ([NotificationPayload]) az értesítés fajtáját és a sportoló
///   nevét viszi; kattintáskor ebből lesz [NotificationActivation]
///   (profil: `/sportolok/<id>`, hírösszesítő: `/hirek`).
/// - Gombok: sportolós értesítésen „Profil megnyitása” és „Némítás 1 órára”,
///   hírnél „Hírek megnyitása” (lásd [CourtboardNotification.buttons]).
/// - Ha az appot egy értesítés indította (vagy a kattintás a kezelő
///   beállítása előtt érkezik), az aktiválás megmarad, és a kezelő
///   beállításakor kézbesül.
/// - A sportoló képe akkor jelenik meg, ha a képgyorsítótárban megvan
///   (letöltés nincs).
/// - Hibánál (inicializálás vagy megjelenítés) az app bezárásáig a
///   [fallback] (tálcabuborék) veszi át az értesítéseket.
class FlutterLocalNotificationService implements NotificationService {
  FlutterLocalNotificationService({
    ToastPlatform? platform,
    this.fallback,
    Future<String?> Function(String imageUrl)? imagePathFor,
  }) : _platform = platform ?? FlutterLocalNotificationsToastPlatform(),
       _imagePathFor = imagePathFor ?? cachedToastImage;

  final ToastPlatform _platform;
  final Future<String?> Function(String imageUrl) _imagePathFor;

  /// Tartalék megjelenítés, ha a toast nem érhető el.
  final NotificationService? fallback;

  /// `null`: még nincs inicializálva; hamis: a toast nem érhető el.
  bool? _ready;
  Future<bool>? _initializing;
  bool _packaged = false;

  void Function(NotificationActivation activation)? _handler;

  /// A kezelő beállítása előtt érkezett aktiválások.
  final List<NotificationActivation> _pending = [];

  /// Érkezett-e már aktiválás a kattintás-kezelőn át (az indítási adatok
  /// ne kézbesüljenek kétszer).
  bool _responded = false;

  /// Igaz, ha a toast működik (vagy még nem próbáltuk).
  bool get toastActive => _ready != false;

  /// Az értesítések beállítása és az indítási értesítés átvétele. Többszöri
  /// hívásnál ugyanaz a [Future]. Soha nem dob; hamis esetén a tartalék él.
  Future<bool> initialize() => _initializing ??= _initialize();

  Future<bool> _initialize() async {
    try {
      final ready = await _platform.initialize(_onResponse);
      _ready = ready;
      if (!ready) return false;
      _packaged = _platform.packaged;
      final payload = await _platform.launchPayload();
      if (payload != null && !_responded) _onResponse(payload);
      return true;
    } catch (_) {
      return _ready = false;
    }
  }

  void _onResponse(String? payload) {
    _responded = true;
    final activation =
        NotificationPayload.decode(payload) ??
        // Ismeretlen payload: csak az ablak jön elő.
        const NotificationActivation(
          CourtboardNotification(
            id: '',
            kind: CourtboardNotificationKind.info,
            title: '',
            body: '',
          ),
        );
    final handler = _handler;
    if (handler == null) {
      _pending.add(activation);
    } else {
      handler(activation);
    }
  }

  @override
  bool get available => toastActive || (fallback?.available ?? false);

  @override
  bool get supportsClick => toastActive || (fallback?.supportsClick ?? false);

  @override
  bool get supportsActions =>
      toastActive || (fallback?.supportsActions ?? false);

  @override
  String get description => toastActive
      ? (_packaged ? 'Windows-értesítés (MSIX)' : 'Windows-értesítés')
      : fallback?.description ?? 'Nem elérhető';

  @override
  set onActivated(void Function(NotificationActivation activation)? handler) {
    _handler = handler;
    fallback?.onActivated = handler;
    if (handler == null || _pending.isEmpty) return;
    final pending = [..._pending];
    _pending.clear();
    pending.forEach(handler);
  }

  @override
  Future<bool> show(CourtboardNotification notification) async {
    if (await initialize() && _ready == true) {
      try {
        await _platform.show(await _request(notification));
        return true;
      } catch (_) {
        // A toast nem jeleníthető meg (például letiltott COM-regisztráció):
        // a további értesítések a tartalékon mennek.
        _ready = false;
      }
    }
    return await fallback?.show(notification) ?? false;
  }

  Future<ToastRequest> _request(CourtboardNotification notification) async {
    String? imagePath;
    final url = notification.imageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        imagePath = await _imagePathFor(url);
      } catch (_) {
        imagePath = null;
      }
    }
    return ToastRequest(
      id: toastIdFor(notification.id),
      title: notification.title,
      body: notification.body,
      payload: NotificationPayload.encode(notification),
      buttons: [
        for (final action in notification.buttons)
          (action.label, NotificationPayload.encode(notification, action)),
      ],
      imagePath: imagePath,
    );
  }

  /// Egy értesítés visszavonása (csak MSIX-ből futtatva hat).
  Future<void> cancel(String notificationId) async {
    if (_ready != true) return;
    try {
      await _platform.cancel(toastIdFor(notificationId));
    } catch (_) {
      // Nem támogatott vagy már eltűnt.
    }
  }

  @override
  Future<void> clearAll() async {
    if (_ready == true) {
      try {
        await _platform.cancelAll();
      } catch (_) {
        // Nem kritikus.
      }
    }
    await fallback?.clearAll();
  }
}

/// A képgyorsítótárban ([ImageDiskCache]) meglévő fotó toastba tehető
/// másolata (`…\cache\toast_images\<hash>.png|jpg|gif`), vagy `null`, ha a
/// kép nincs a gyorsítótárban, túl nagy, vagy a Windows-toast nem ismeri a
/// formátumát. Hálózati letöltés nincs.
Future<String?> cachedToastImage(
  String url, {
  ImageDiskCache? cache,
  String? directory,
}) async {
  final source = (cache ?? ImageDiskCache.shared).fileFor(url);
  if (!await source.exists()) return null;
  final bytes = await source.readAsBytes();
  // A Windows-toast legfeljebb 3 MB-os képet fogad el.
  if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) return null;
  final extension = toastImageExtension(bytes);
  if (extension == null) return null;
  final target = File(
    '${directory ?? AppPaths.cacheDirectory('toast_images')}/'
    '${fnv1a32Hex(url)}.$extension',
  );
  if (!await target.exists() || await target.length() != bytes.length) {
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
  }
  return target.absolute.path;
}

/// A toastban megjeleníthető képformátum kiterjesztése a fájl első bájtjai
/// alapján (PNG, JPEG, GIF), egyébként `null`.
String? toastImageExtension(Uint8List bytes) {
  bool starts(List<int> magic) =>
      bytes.length >= magic.length &&
      Iterable<int>.generate(magic.length).every((i) => bytes[i] == magic[i]);
  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (starts(const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (starts(const [0x47, 0x49, 0x46, 0x38])) return 'gif';
  return null;
}
