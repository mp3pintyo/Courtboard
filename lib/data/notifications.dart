import 'dart:convert';

/// Az értesítés fajtája; a kattintáskori navigációt is ez dönti el.
enum CourtboardNotificationKind {
  /// Hamarosan kezdődik egy követett sportoló mérkőzése.
  matchStart,

  /// Új eredmény a sportoló legutóbbi mérkőzései között.
  result,

  /// Élő eredményváltozás egy zajló mérkőzésen (alapból kikapcsolva).
  liveScore,

  /// Új hír (egy vagy több sportolóról).
  news,

  /// A Beállítások „Teszt értesítés” gombja.
  test,

  /// Egyéb tájékoztatás (például az első tálcára rejtés tippje).
  info,
}

/// Egy asztali értesítés tartalma és „hasznos terhe” (payload).
class CourtboardNotification {
  const CourtboardNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.athleteName,
    this.imageUrl,
  });

  /// Stabil azonosító (ugyanarra az eseményre ugyanaz).
  final String id;
  final CourtboardNotificationKind kind;
  final String title;
  final String body;

  /// Kattintáskor ennek a sportolónak a profilja nyílik meg; `null` esetén
  /// hírnél a Hírek oldal, egyébként csak az ablak jelenik meg.
  final String? athleteName;

  /// A sportoló fotójának URL-je: ha a képgyorsítótárban megvan, a
  /// Windows-értesítés megmutatja (letöltés nincs).
  final String? imageUrl;

  /// Másolat a megadott fotó-URL-lel.
  CourtboardNotification withImageUrl(String? url) => CourtboardNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    athleteName: athleteName,
    imageUrl: url,
  );

  /// Sportolóhoz tartozó értesítés (meccskezdés, eredmény, élő állás).
  bool get isAthleteAlert =>
      athleteName != null &&
      (kind == CourtboardNotificationKind.matchStart ||
          kind == CourtboardNotificationKind.result ||
          kind == CourtboardNotificationKind.liveScore);

  /// Az értesítés gombjai a Windows-értesítésen.
  List<NotificationAction> get buttons => switch (kind) {
    CourtboardNotificationKind.news => const [NotificationAction.openNews],
    CourtboardNotificationKind.test => const [NotificationAction.open],
    CourtboardNotificationKind.info => const [],
    _ when isAthleteAlert => const [
      NotificationAction.openProfile,
      NotificationAction.pauseOneHour,
    ],
    _ => const [],
  };

  @override
  String toString() => 'CourtboardNotification($kind, $title | $body)';
}

/// Mit kért a felhasználó az értesítésen.
enum NotificationAction {
  /// Kattintás magára az értesítésre (vagy a teszt „Megnyitás” gombja):
  /// sportolónál a profil, hírösszesítőnél a Hírek oldal, egyébként csak az
  /// ablak.
  open('Megnyitás'),

  /// „Profil megnyitása” gomb.
  openProfile('Profil megnyitása'),

  /// „Hírek megnyitása” gomb.
  openNews('Hírek megnyitása'),

  /// „Némítás 1 órára” gomb: az értesítések szüneteltetése egy órára.
  pauseOneHour('Némítás 1 órára');

  const NotificationAction(this.label);

  /// A gomb felirata.
  final String label;

  /// Előjön-e az ablak (a némítás a háttérben marad).
  bool get showsWindow => this != pauseOneHour;
}

/// Egy értesítés aktiválása: kattintás vagy gomb. Az app értesítésből
/// indulásakor is ilyen érkezik (a payloadból visszafejtve).
class NotificationActivation {
  const NotificationActivation(
    this.notification, [
    this.action = NotificationAction.open,
  ]);

  final CourtboardNotification notification;
  final NotificationAction action;

  @override
  String toString() => 'NotificationActivation($action, $notification)';
}

/// Az értesítés payloadja: a Windows ezt a szöveget adja vissza kattintáskor
/// (az app újraindítása után is), ezért minden benne van, ami a
/// navigációhoz kell.
abstract final class NotificationPayload {
  static const _version = 1;

  /// JSON: `{"v":1,"id":…,"kind":…,"athlete":…,"action":…}`.
  static String encode(
    CourtboardNotification notification, [
    NotificationAction action = NotificationAction.open,
  ]) => jsonEncode({
    'v': _version,
    'id': notification.id,
    'kind': notification.kind.name,
    'athlete': ?notification.athleteName,
    'action': action.name,
  });

  /// A [payload] visszafejtése; ismeretlen vagy hibás payloadnál `null`
  /// (ilyenkor csak az ablak jön elő).
  static NotificationActivation? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final kindName = decoded['kind'];
    final kind = CourtboardNotificationKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    final actionName = decoded['action'];
    final action =
        NotificationAction.values
            .where((value) => value.name == actionName)
            .firstOrNull ??
        NotificationAction.open;
    final id = decoded['id'];
    final athlete = decoded['athlete'];
    return NotificationActivation(
      CourtboardNotification(
        id: id is String ? id : '',
        kind: kind,
        title: '',
        body: '',
        athleteName: athlete is String && athlete.isNotEmpty ? athlete : null,
      ),
      action,
    );
  }
}

/// Asztali értesítések küldése. A Windows-megvalósítások a
/// `lib/desktop/windows_notifications.dart` (`flutter_local_notifications`)
/// és a `lib/desktop/toast_notifications.dart` (tálcabuborék) fájlban
/// vannak; a tesztek hamis megvalósítást használnak (lásd
/// `test/support/fake_desktop.dart`).
abstract interface class NotificationService {
  /// Igaz, ha az értesítések megjeleníthetők.
  bool get available;

  /// Igaz, ha a szolgáltatás a kattintást is jelezni tudja
  /// ([onActivated]); a tálcabuborékos tartalék ezt nem tudja.
  bool get supportsClick;

  /// Igaz, ha az értesítéseken gombok is vannak ([NotificationAction]).
  bool get supportsActions;

  /// Rövid, felhasználónak szóló név a ténylegesen használt módról
  /// („Windows-értesítés”, „Tálcaértesítés (buborék)”).
  String get description;

  /// Kattintás vagy gomb egy értesítésen. A shell ilyenkor előhozza az
  /// ablakot és a sportoló profiljára / a Hírek oldalra navigál; a némítás
  /// gomb szünetelteti az értesítéseket. A kezelő beállítása előtt érkezett
  /// aktiválásokat (például az app értesítésből indult) a szolgáltatás
  /// megőrzi, és a beállításkor átadja.
  set onActivated(void Function(NotificationActivation activation)? handler);

  /// Megjeleníti az értesítést; hamis, ha nem sikerült. Soha nem dob.
  Future<bool> show(CourtboardNotification notification);

  /// A Courtboard még látható / Műveletközpontban lévő értesítéseinek
  /// törlése, ahol a platform támogatja. Soha nem dob.
  Future<void> clearAll();
}

/// Semmit nem jelenítő szolgáltatás (nem Windows platform, vagy ha minden
/// értesítési mód hibázott).
class DisabledNotificationService implements NotificationService {
  const DisabledNotificationService();

  @override
  bool get available => false;

  @override
  bool get supportsClick => false;

  @override
  bool get supportsActions => false;

  @override
  String get description => 'Nem elérhető';

  @override
  set onActivated(void Function(NotificationActivation activation)? handler) {}

  @override
  Future<bool> show(CourtboardNotification notification) async => false;

  @override
  Future<void> clearAll() async {}
}
