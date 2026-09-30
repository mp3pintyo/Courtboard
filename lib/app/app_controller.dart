/// Az alkalmazás felhasználói állapota és annak mentése.
///
/// A 0.13.0 előtt mindez a shell `State`-jében élt; most egy UI-független
/// [ChangeNotifier], amelyet az `appControllerProvider` tesz elérhetővé
/// (lásd `lib/app/providers.dart`). A controller nem ismer widgeteket: a felhasználónak szóló
/// üzeneteket (például mentési hiba) a [messages] folyamon adja tovább.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/data/playlist_store.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/data/window_geometry.dart';
import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/domain/athlete_targets.dart';
import 'package:courtboard/app/seed_data.dart';

class AppController extends ChangeNotifier {
  AppController({
    CourtboardLocalState initialState = const CourtboardLocalState(),
    this.stateStore,
    this.playlistStore,
    ApiKeyStore? apiKeyStore,
    Map<ApiKeyId, String> apiKeys = const {},
    this._secureStorageAvailable = true,
    this.updateChecker,
    List<Athlete> seed = seedAthletes,
    SportsApiConfig? baseConfig,
    DateTime Function()? clock,
  }) : _apiKeyStore = apiKeyStore ?? ApiKeyStore(),
       _apiConfig = baseConfig ?? SportsApiConfig.fromEnvironment(),
       _clock = clock ?? DateTime.now,
       _athletes = [...seed] {
    _applyState(initialState, apiKeys);
    _schedulePauseExpiry();
  }

  /// `null` esetén az állapot nem kerül lemezre (például tesztben).
  final LocalStateStore? stateStore;

  /// `null` esetén a videólista nem töltődik be és nem mentődik.
  final PlaylistStore? playlistStore;

  /// `null` esetén nincs frissítés-ellenőrzés.
  final UpdateChecker? updateChecker;

  final ApiKeyStore _apiKeyStore;
  final DateTime Function() _clock;
  final StreamController<String> _messages = StreamController.broadcast();
  bool _disposed = false;

  /// A felhasználónak szóló rövid üzenetek (a shell SnackBarként mutatja).
  Stream<String> get messages => _messages.stream;

  // ---------------------------------------------------------------------------
  // Állapot
  // ---------------------------------------------------------------------------

  final List<Athlete> _athletes;

  /// Ismeretlen sportágú (például újabb verzióban felvett) saját sportolók:
  /// nem jelennek meg, de a mentés megőrzi őket.
  List<CustomAthlete> _unsupportedCustomAthletes = const [];
  Map<String, String> _notes = {};
  Map<String, bool> _alerts = {};
  Set<String> _removedAthleteNames = {};
  List<String> _pinned = [];
  SportsApiConfig _apiConfig;
  bool _secureStorageAvailable;
  Map<ApiKeyId, String> _legacyApiKeys = const {};
  String _overviewSort = 'custom';
  String _athleteSort = 'custom';
  String _theme = 'green';
  String _themeMode = 'system';
  bool _railCollapsed = false;
  bool _autoUpdateCheck = true;
  WindowGeometry? _windowGeometry;
  bool _closeToTray = false;
  bool _closeToTrayHintShown = false;
  bool _startMinimized = false;
  NotificationSettings _notificationSettings = const NotificationSettings();
  DateTime? _notificationsPausedUntil;
  Timer? _pauseTimer;
  AthleteVideoPlaylist _playlist = const AthleteVideoPlaylist();
  UpdateCheckResult? _updateResult;
  bool _updateBannerDismissed = false;

  /// A követett sportolók a „Saját sorrend” szerint.
  List<Athlete> get athletes => List.unmodifiable(_athletes);

  /// A követett sportolók nevei (sorrendben).
  List<String> get athleteNames => [for (final a in _athletes) a.name];

  Athlete? athleteNamed(String name) =>
      _athletes.where((athlete) => athlete.name == name).firstOrNull;

  /// A sportoló a stabil azonosítója ([Athlete.id]) alapján (útvonalak).
  Athlete? athleteById(String id) =>
      _athletes.where((athlete) => athlete.id == id).firstOrNull;

  /// A kitűzött sportolók neve a kitűzés sorrendjében.
  List<String> get pinned => List.unmodifiable(_pinned);
  bool isPinned(Athlete athlete) => _pinned.contains(athlete.name);

  Map<String, String> get notes => Map.unmodifiable(_notes);
  String noteFor(Athlete athlete) => _notes[athlete.name] ?? '';

  Map<String, bool> get alerts => Map.unmodifiable(_alerts);
  bool alertEnabled(Athlete athlete) => _alerts[athlete.name] ?? false;

  /// A profilon értesítésre jelölt sportolók.
  List<Athlete> get alertAthletes =>
      _athletes.where((athlete) => _alerts[athlete.name] == true).toList();

  /// A követett sportolók naptár-/élőeredmény-célpontjai.
  List<UpcomingEventsTarget> get eventTargets => calendarTargets(_athletes);

  /// Az aktuális API-kulcsokkal összeállított konfiguráció.
  SportsApiConfig get apiConfig => _apiConfig;

  /// Hamis, ha a biztonságos tároló indításkor vagy egy mentéskor hibázott.
  bool get secureStorageAvailable => _secureStorageAvailable;

  String get overviewSort => _overviewSort;
  String get athleteSort => _athleteSort;
  String get theme => _theme;
  String get themeMode => _themeMode;
  bool get railCollapsed => _railCollapsed;
  bool get autoUpdateCheck => _autoUpdateCheck;
  WindowGeometry? get windowGeometry => _windowGeometry;
  bool get closeToTray => _closeToTray;
  bool get closeToTrayHintShown => _closeToTrayHintShown;
  bool get startMinimized => _startMinimized;
  NotificationSettings get notificationSettings => _notificationSettings;
  DateTime? get notificationsPausedUntil => _notificationsPausedUntil;
  AthleteVideoPlaylist get playlist => _playlist;
  UpdateCheckResult? get updateResult => _updateResult;
  bool get updateBannerDismissed => _updateBannerDismissed;

  /// Látható-e a frissítés-sáv.
  bool get showUpdateBanner =>
      _updateResult?.updateAvailable == true && !_updateBannerDismissed;

  bool get notificationsPaused {
    final until = _notificationsPausedUntil;
    return until != null && _clock().isBefore(until);
  }

  // ---------------------------------------------------------------------------
  // Betöltés
  // ---------------------------------------------------------------------------

  void _applyState(CourtboardLocalState state, Map<ApiKeyId, String> keys) {
    _notes = {...state.notes};
    _alerts = {...state.alerts};
    // Elsőbbség: mentett kulcs > régi JSON-kulcs > környezeti változó.
    _legacyApiKeys = state.legacyApiKeys;
    _apiConfig = _apiConfig.withKeys({...state.legacyApiKeys, ...keys});
    _removedAthleteNames = {...state.removedAthleteNames};
    _pinned = [...state.pinnedAthletes];
    _overviewSort = state.overviewSort;
    _athleteSort = state.athleteSort;
    _theme = state.theme;
    _themeMode = state.themeMode;
    _railCollapsed = state.railCollapsed;
    _autoUpdateCheck = state.autoUpdateCheck;
    _windowGeometry = state.windowGeometry;
    _closeToTray = state.closeToTray;
    _closeToTrayHintShown = state.closeToTrayHintShown;
    _startMinimized = state.startMinimized;
    _notificationSettings = state.notifications;
    final pausedUntil = state.notificationsPausedUntil;
    _notificationsPausedUntil =
        pausedUntil != null && pausedUntil.isAfter(_clock())
        ? pausedUntil
        : null;
    _athletes.removeWhere(
      (athlete) => _removedAthleteNames.contains(athlete.name),
    );
    final known = _athletes.map((athlete) => athlete.name).toSet();
    final ids = _athletes.map((athlete) => athlete.id).toSet();
    final unsupported = <CustomAthlete>[];
    for (final saved in state.customAthletes) {
      if (!known.add(saved.name)) continue;
      // Az azonosító egyedi marad (két hasonló név ugyanazt a slugot adhatja).
      final id = uniqueAthleteId(saved.effectiveId, ids);
      ids.add(id);
      final custom = id == saved.effectiveId ? saved : saved.withId(id);
      final athlete = customToAthlete(custom);
      if (athlete == null) {
        unsupported.add(custom);
      } else {
        _athletes.add(athlete);
      }
    }
    _unsupportedCustomAthletes = List.unmodifiable(unsupported);
    _applyAthleteOrder(state.athleteOrder);
  }

  /// A mentett „Saját sorrend” alkalmazása; a listában nem szereplő
  /// sportolók eredeti sorrendjükben a végére kerülnek.
  void _applyAthleteOrder(List<String> order) {
    if (order.isEmpty) return;
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final indexed = _athletes.asMap().entries.toList()
      ..sort((a, b) {
        final aRank = rank[a.value.name] ?? order.length + a.key;
        final bRank = rank[b.value.name] ?? order.length + b.key;
        return aRank.compareTo(bRank);
      });
    _athletes
      ..clear()
      ..addAll(indexed.map((entry) => entry.value));
  }

  /// Egy mentett saját sportoló; ismeretlen sportágnál `null`.
  static Athlete? customToAthlete(CustomAthlete athlete) {
    final sport = Sport.fromLabel(athlete.sport);
    if (sport == null) return null;
    return Athlete(
      id: athlete.effectiveId,
      name: athlete.name,
      sport: sport,
      team: athlete.team,
      // Régebbi mentésekben „Ismeretlen” helyőrző szerepelhet: nem mutatjuk.
      country: athlete.country.trim() == 'Ismeretlen' ? '' : athlete.country,
      photoUrl: athlete.photoUrl,
      accent: customAthleteAccent,
      isCustom: true,
      sourceHints: athlete.sourceHints,
    );
  }

  static CustomAthlete athleteToCustom(Athlete athlete) => CustomAthlete(
    id: athlete.id,
    name: athlete.name,
    sport: athlete.sport.jsonValue,
    team: athlete.team,
    country: athlete.country,
    photoUrl: athlete.photoUrl,
    sourceHints: athlete.sourceHints,
  );

  /// A videólista betöltése (indításkor egyszer).
  Future<void> loadPlaylist() async {
    final store = playlistStore;
    if (store == null) return;
    final result = await store.load();
    if (_disposed) return;
    if (result.corrupt) {
      final backup = result.backup;
      _message(
        backup == null
            ? 'A mentett videólista nem olvasható be. A fájl védelmében a videólista módosításai most nem kerülnek mentésre.'
            : 'A mentett videólista nem olvasható be. Az eredeti fájlról biztonsági másolat készült: ${backup.path}',
      );
      return;
    }
    _playlist = result.playlist;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Mentés
  // ---------------------------------------------------------------------------

  /// A mentendő (teljes) állapot.
  CourtboardLocalState get currentState => CourtboardLocalState(
    notes: _notes,
    alerts: _alerts,
    removedAthleteNames: _removedAthleteNames,
    legacyApiKeys: _legacyApiKeys,
    theme: _theme,
    themeMode: _themeMode,
    overviewSort: _overviewSort,
    athleteSort: _athleteSort,
    athleteOrder: _athletes.map((athlete) => athlete.name).toList(),
    railCollapsed: _railCollapsed,
    autoUpdateCheck: _autoUpdateCheck,
    windowGeometry: _windowGeometry,
    closeToTray: _closeToTray,
    closeToTrayHintShown: _closeToTrayHintShown,
    startMinimized: _startMinimized,
    notifications: _notificationSettings,
    notificationsPausedUntil: _notificationsPausedUntil,
    pinnedAthletes: [
      for (final name in _pinned)
        if (_athletes.any((athlete) => athlete.name == name)) name,
    ],
    customAthletes: [
      ..._athletes.where((a) => a.isCustom).map(athleteToCustom),
      ..._unsupportedCustomAthletes,
    ],
  );

  /// Háttérben menti az állapotot (a [LocalStateStore] sorba rendezi az
  /// írásokat); hibánál a [messages] jelzi, hogy a módosítás nem került
  /// lemezre.
  void _save() {
    final store = stateStore;
    if (store == null) return;
    unawaited(
      store
          .save(currentState)
          .catchError(
            (Object _) =>
                _message('A módosítások mentése nem sikerült. Próbáld újra.'),
          ),
    );
  }

  /// Kilépés előtt: az állapot mentésének megvárása.
  Future<void> flush() async {
    final store = stateStore;
    if (store == null) return;
    try {
      await store.save(currentState);
    } catch (_) {
      // Kilépéskor már nem tudunk mit tenni.
    }
  }

  /// Változás: értesíti a figyelőket és ment.
  void _changed() {
    _notify();
    _save();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _message(String message) {
    if (!_disposed) _messages.add(message);
  }

  // ---------------------------------------------------------------------------
  // Sportolók
  // ---------------------------------------------------------------------------

  /// Egy új saját sportoló a lista végére; `null`, ha a sportág ismeretlen
  /// vagy a név már szerepel.
  Athlete? addCustomAthlete(CustomAthlete custom) {
    if (_athletes.any((athlete) => athlete.name == custom.name)) return null;
    final id = uniqueAthleteId(custom.effectiveId, {
      for (final athlete in _athletes) athlete.id,
    });
    final athlete = customToAthlete(custom.withId(id));
    if (athlete == null) return null;
    _athletes.add(athlete);
    _changed();
    return athlete;
  }

  /// A sportoló törlése a követettek közül (a jegyzet és a videók
  /// megmaradnak, a sportoló bármikor újra felvehető).
  void removeAthlete(Athlete athlete) {
    _removedAthleteNames.add(athlete.name);
    _athletes.removeWhere((item) => item.name == athlete.name);
    _pinned = [
      for (final name in _pinned)
        if (name != athlete.name) name,
    ];
    _changed();
  }

  /// „Saját sorrend” módosítása húzással (a teljes, szűretlen listán).
  /// A [newIndex] már az elem kivétele utáni listára vonatkozik.
  void reorderAthletes(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final athlete = _athletes.removeAt(oldIndex);
    _athletes.insert(newIndex, athlete);
    _changed();
  }

  /// „Kitűzés” / „Kitűzés megszüntetése”; az új állapottal tér vissza.
  bool togglePin(Athlete athlete) {
    final pinned = isPinned(athlete);
    _pinned = pinned
        ? [
            for (final name in _pinned)
              if (name != athlete.name) name,
          ]
        : [..._pinned, athlete.name];
    _changed();
    return !pinned;
  }

  void setNote(Athlete athlete, String value) {
    _notes = {..._notes, athlete.name: value};
    _changed();
  }

  void toggleAlert(Athlete athlete) {
    _alerts = {..._alerts, athlete.name: !(_alerts[athlete.name] ?? false)};
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Videólista
  // ---------------------------------------------------------------------------

  /// Egy videó hozzáadása; hibát dob, ha a mentés nem sikerült (a lista
  /// ilyenkor változatlan).
  Future<void> addVideo(SavedYouTubeVideo video) async {
    final updated = _playlist.add(video);
    await playlistStore?.save(updated);
    if (_disposed) return;
    _playlist = updated;
    _notify();
  }

  /// Egy videó eltávolítása; a mentés hibáját a [messages] jelzi.
  void removeVideo(SavedYouTubeVideo video) {
    final updated = _playlist.remove(video);
    _playlist = updated;
    _notify();
    final store = playlistStore;
    if (store == null) return;
    unawaited(
      store
          .save(updated)
          .catchError(
            (Object _) => _message('A videólista mentése nem sikerült.'),
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Beállítások
  // ---------------------------------------------------------------------------

  void setTheme(String value) {
    _theme = value;
    _changed();
  }

  void setThemeMode(String value) {
    _themeMode = value;
    _changed();
  }

  void setOverviewSort(String value) {
    _overviewSort = value;
    _changed();
  }

  void setAthleteSort(String value) {
    _athleteSort = value;
    _changed();
  }

  void toggleRail() {
    _railCollapsed = !_railCollapsed;
    _changed();
  }

  void setCloseToTray(bool value) {
    _closeToTray = value;
    _changed();
  }

  void setStartMinimized(bool value) {
    _startMinimized = value;
    _changed();
  }

  /// Az első tálcára rejtéskor megjelent tipp többé nem jelenik meg.
  void markCloseToTrayHintShown() {
    if (_closeToTrayHintShown) return;
    _closeToTrayHintShown = true;
    _save();
  }

  /// Az ablak új helyzete (az asztali integráció jelzi).
  void setWindowGeometry(WindowGeometry geometry) {
    _windowGeometry = geometry;
    _save();
  }

  void setNotificationSettings(NotificationSettings value) {
    _notificationSettings = value;
    _changed();
  }

  /// „Értesítések szüneteltetése 1 órára” / „Értesítések folytatása”.
  void toggleNotificationPause() {
    _notificationsPausedUntil = notificationsPaused
        ? null
        : _clock().add(const Duration(hours: 1));
    _schedulePauseExpiry();
    _changed();
  }

  /// A szünet lejártakor az állapot (és a tálcamenü felirata) visszaáll.
  void _schedulePauseExpiry() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    final until = _notificationsPausedUntil;
    if (until == null) return;
    final remaining = until.difference(_clock());
    if (remaining <= Duration.zero) {
      _notificationsPausedUntil = null;
      return;
    }
    _pauseTimer = Timer(remaining, () {
      _pauseTimer = null;
      if (_disposed) return;
      _notificationsPausedUntil = null;
      _changed();
    });
  }

  void setAutoUpdateCheck(bool value) {
    _autoUpdateCheck = value;
    _changed();
    if (value && _updateResult == null) unawaited(checkForUpdates());
  }

  /// Frissítés-ellenőrzés; [force] esetén a 12 órás gyorsítótár nélkül.
  Future<UpdateCheckResult?> checkForUpdates({bool force = false}) async {
    final checker = updateChecker;
    if (checker == null) return null;
    final result = await checker.check(force: force);
    if (_disposed) return result;
    _updateResult = result;
    if (force) _updateBannerDismissed = false;
    _notify();
    return result;
  }

  void dismissUpdateBanner() {
    _updateBannerDismissed = true;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // API-kulcsok
  // ---------------------------------------------------------------------------

  /// Egy API-kulcs mentése: azonnal érvényes, és a biztonságos tárolóba
  /// kerül (soha nem a JSON-állapotfájlba). Ha a tároló hibázik, a kulcs az
  /// app bezárásáig memóriában él, és az Adatforrások oldal figyelmeztet.
  Future<void> saveApiKey(ApiKeyId id, String value) async {
    _apiConfig = _apiConfig.withKey(id, value);
    _notify();
    try {
      await _apiKeyStore.save(id, value);
      // Egy korábban a JSON-ban rekedt régi érték a következő induláskor
      // felülírná az újat, ezért azt most kivesszük.
      if (_legacyApiKeys.containsKey(id)) {
        _legacyApiKeys = {..._legacyApiKeys}..remove(id);
        _save();
      }
    } on Object {
      if (_disposed) return;
      _secureStorageAvailable = false;
      _notify();
      _message(
        'A(z) ${id.label} kulcs nem menthető a biztonságos tárolóba; '
        'az app bezárásáig érvényes.',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pauseTimer?.cancel();
    unawaited(_messages.close());
    super.dispose();
  }
}
