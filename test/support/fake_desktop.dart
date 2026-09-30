import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/window_geometry.dart';
import 'package:courtboard/desktop/desktop_integration.dart';
import 'package:courtboard/desktop/startup_registration.dart';

/// Valódi értesítést soha nem mutató szolgáltatás: a „megjelenített”
/// értesítéseket csak naplózza, és a kattintás szimulálható.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.available = true, this.succeeds = true});

  @override
  bool available;

  /// Hamis esetén a [show] sikertelen (például letiltott értesítések).
  bool succeeds;

  final List<CourtboardNotification> shown = [];
  void Function(CourtboardNotification notification)? _onClick;

  @override
  bool get supportsClick => true;

  @override
  String get description => 'Teszt-értesítés';

  @override
  set onClick(void Function(CourtboardNotification notification)? handler) =>
      _onClick = handler;

  bool get hasClickHandler => _onClick != null;

  /// Kattintás a [notification]-re (ahogy a Windows jelezné).
  void click(CourtboardNotification notification) =>
      _onClick?.call(notification);

  @override
  Future<bool> show(CourtboardNotification notification) async {
    if (!succeeds) return false;
    shown.add(notification);
    return true;
  }
}

/// Hálózat nélküli figyelő-adatforrás; a hívásokat naplózza.
class FakeWatcherSource implements WatcherDataSource {
  final Map<String, List<UpcomingEvent>> events = {};

  /// Sportoló → eredmények; hiányzó kulcs: nincs eredményforrás (`null`).
  final Map<String, List<WatchedResult>> results = {};
  final Map<String, List<NewsArticle>> news = {};

  /// A sportolónkénti hívások („upcoming:Név”, „results:Név”, „news:Név”).
  final List<String> calls = [];
  int newsRefreshes = 0;

  /// Igaz esetén minden hívás kivételt dob (hálózati hiba).
  bool failing = false;

  void _check() {
    if (failing) throw Exception('hálózati hiba');
  }

  @override
  Future<List<UpcomingEvent>> upcomingEvents(
    UpcomingEventsTarget athlete,
  ) async {
    calls.add('upcoming:${athlete.name}');
    _check();
    return events[athlete.name] ?? const [];
  }

  @override
  Future<List<WatchedResult>?> recentResults(
    UpcomingEventsTarget athlete,
  ) async {
    calls.add('results:${athlete.name}');
    _check();
    return results[athlete.name];
  }

  @override
  Future<void> refreshNews() async {
    newsRefreshes++;
    _check();
  }

  @override
  Future<List<NewsArticle>> recentNews(String athleteName) async {
    calls.add('news:$athleteName');
    _check();
    return news[athleteName] ?? const [];
  }
}

/// Valódi ablakot és tálcaikont nem érintő asztali integráció.
class FakeDesktopIntegration extends DesktopIntegration {
  FakeDesktopIntegration({
    this.trayAvailable = true,
    this.startedHidden = false,
    StartupRegistration? startup,
  }) : startup = startup ?? MemoryStartupRegistration();

  @override
  final bool trayAvailable;

  @override
  final bool startedHidden;

  @override
  final StartupRegistration startup;

  @override
  int? get windowHandle => null;

  @override
  bool closeToTray = false;

  DesktopHandlers handlers = const DesktopHandlers();

  /// A meghívott műveletek sorrendben („show”, „hide”, „quit”, …).
  final List<String> log = [];

  /// A tálcamenü legutóbbi „szüneteltetve” állapota.
  bool? trayPaused;

  @override
  void attach(DesktopHandlers handlers) => this.handlers = handlers;

  @override
  Future<void> revealInitialWindow() async => log.add('reveal');

  @override
  Future<void> showWindow() async {
    log.add('show');
    handlers.onWindowShown?.call();
  }

  @override
  Future<void> hideToTray() async => log.add('hide');

  @override
  Future<void> updateTrayMenu({required bool notificationsPaused}) async {
    trayPaused = notificationsPaused;
    log.add('tray:${notificationsPaused ? 'paused' : 'active'}');
  }

  @override
  Future<void> quit() async {
    log.add('quit');
    await handlers.onBeforeQuit?.call();
  }

  /// Az ablak bezárása (X gomb), ahogy a Windows-megvalósítás kezeli.
  Future<void> simulateClose() async {
    if (closeToTray && trayAvailable) {
      await hideToTray();
      handlers.onHiddenToTray?.call();
    } else {
      await quit();
    }
  }

  /// Az ablak áthelyezése / átméretezése.
  void simulateGeometry(WindowGeometry geometry) =>
      handlers.onGeometryChanged?.call(geometry);

  @override
  void dispose() {}
}
