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
  });

  /// Stabil azonosító (ugyanarra az eseményre ugyanaz).
  final String id;
  final CourtboardNotificationKind kind;
  final String title;
  final String body;

  /// Kattintáskor ennek a sportolónak a profilja nyílik meg; `null` esetén
  /// hírnél a Hírek oldal, egyébként csak az ablak jelenik meg.
  final String? athleteName;

  @override
  String toString() => 'CourtboardNotification($kind, $title | $body)';
}

/// Asztali értesítések küldése. A Windows-megvalósítás a
/// `lib/desktop/toast_notifications.dart`-ban van; a tesztek hamis
/// megvalósítást használnak (lásd `test/support/fake_desktop.dart`).
abstract interface class NotificationService {
  /// Igaz, ha az értesítések megjeleníthetők.
  bool get available;

  /// Igaz, ha a szolgáltatás a kattintást is jelezni tudja
  /// ([onClick]); a tálcabuborékos tartalék ezt nem tudja.
  bool get supportsClick;

  /// Rövid, felhasználónak szóló név („Windows-értesítés”, „Tálcabuborék”).
  String get description;

  /// A kattintott értesítés; a shell ilyenkor előhozza az ablakot és a
  /// sportoló profiljára navigál.
  set onClick(void Function(CourtboardNotification notification)? handler);

  /// Megjeleníti az értesítést; hamis, ha nem sikerült. Soha nem dob.
  Future<bool> show(CourtboardNotification notification);
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
  String get description => 'Nem elérhető';

  @override
  set onClick(void Function(CourtboardNotification notification)? handler) {}

  @override
  Future<bool> show(CourtboardNotification notification) async => false;
}
