part of '../main.dart';

class CourtboardShell extends StatefulWidget {
  const CourtboardShell({
    super.key,
    this.initialState = const CourtboardLocalState(),
    this.stateStore,
    this.playlistFile,
    this.apiKeys = const {},
    this.apiKeyStore,
    this.secureStorageAvailable = true,
    this.appVersion,
    this.updateChecker,
    this.upcomingEvents,
    this.desktop,
    this.notificationService,
    this.startupRegistration,
    this.watcherSource,
    this.watcherMemoryStore,
    this.compareSource,
    required this.onThemeChanged,
    this.onThemeModeChanged,
  });

  /// Lásd [CourtboardApp.desktop].
  final DesktopIntegration? desktop;

  /// Lásd [CourtboardApp.notificationService].
  final NotificationService? notificationService;

  /// Lásd [CourtboardApp.startupRegistration].
  final StartupRegistration? startupRegistration;

  /// Lásd [CourtboardApp.watcherSource].
  final WatcherDataSource? watcherSource;

  /// Lásd [CourtboardApp.watcherMemoryStore].
  final WatcherMemoryStore? watcherMemoryStore;

  /// Lásd [CourtboardApp.compareSource].
  final CompareDataSource? compareSource;

  /// Lásd [CourtboardApp.appVersion].
  final String? appVersion;

  /// Lásd [CourtboardApp.updateChecker].
  final UpdateChecker? updateChecker;

  /// Lásd [CourtboardApp.upcomingEvents].
  final UpcomingEventsController? upcomingEvents;

  /// A futtatás előtt betöltött helyi állapot.
  final CourtboardLocalState initialState;

  /// `null` esetén az állapot nem kerül lemezre (például tesztben).
  final LocalStateStore? stateStore;

  /// `null` esetén a videólista nem töltődik be és nem mentődik.
  final File? playlistFile;

  /// Indításkor betöltött API-kulcsok (lásd [CourtboardApp.apiKeys]).
  final Map<ApiKeyId, String> apiKeys;

  /// `null` esetén a közös [SecretStore.shared]-re épülő tároló.
  final ApiKeyStore? apiKeyStore;
  final bool secureStorageAvailable;
  final ValueChanged<String> onThemeChanged;

  /// A megjelenési mód (`system` / `light` / `dark`) változása.
  final ValueChanged<String>? onThemeModeChanged;

  @override
  State<CourtboardShell> createState() => _CourtboardShellState();
}

class _CourtboardShellState extends State<CourtboardShell> {
  final _search = TextEditingController();
  AthleteVideoPlaylist _playlist = const AthleteVideoPlaylist();

  /// Igaz, ha a videólista-fájl nem volt beolvasható, és biztonsági másolat
  /// sem készülhetett róla: ilyenkor a mentés felülírná a felhasználó adatát.
  bool _playlistSaveBlocked = false;
  Athlete? _openAthlete;
  int _activeNav = 0;
  String _dashboardFilter = 'Mind';
  final NewsRepository _newsRepository = NewsRepository();
  Map<String, String> _notes = {};
  Map<String, bool> _alerts = {};
  Set<String> _removedAthleteNames = {};

  /// A kitűzött sportolók neve a kitűzés sorrendjében (a nyitóoldalon elöl).
  List<String> _pinned = [];

  /// A „Követés” hírfolyam hírei: a hírarchívumból (helyi SQLite) a
  /// követett sportolókat említő cikkek; hálózati kérés nélkül töltődik.
  List<NewsArticle> _feedArticles = const [];
  bool _feedLoading = false;

  /// Az Összehasonlítás oldal előre kiválasztott sportolója (a profil
  /// „Összehasonlítás…” menüpontjából).
  String? _compareFocus;
  SportsApiConfig _apiConfig = SportsApiConfig.fromEnvironment();
  late final ApiKeyStore _apiKeyStore = widget.apiKeyStore ?? ApiKeyStore();

  /// Hamis, ha a biztonságos tároló indításkor vagy egy mentéskor hibázott:
  /// ilyenkor az Adatforrások oldal figyelmeztetést mutat.
  late bool _secureStorageAvailable = widget.secureStorageAvailable;

  /// A régi állapotfájlban maradt kulcsok (csak tárolóhiba esetén nem
  /// üres); a mentések változatlanul visszaírják őket, hogy ne vesszenek el.
  Map<ApiKeyId, String> _legacyApiKeys = const {};
  String _overviewSort = 'custom';
  String _athleteSort = 'custom';
  String _selectedTheme = 'green';
  String _selectedThemeMode = 'system';

  /// Széles ablakban is összecsukott (kompakt) oldalsáv, a felhasználó
  /// választása szerint.
  bool _railCollapsed = false;

  /// A profil adatkártyái által legutóbb mentett eredmények és események
  /// sportolónként (csak már betöltött adatból, hálózati kérés nélkül).
  Map<String, AthleteHighlight> _highlights = const {};

  /// A naptár eseményei (a shellben élnek, így oldalváltáskor megmaradnak,
  /// és a nyitóoldal „Mai fókusz” blokkja is profitál belőlük).
  late final UpcomingEventsController _upcoming =
      widget.upcomingEvents ?? UpcomingEventsController();
  bool _upcomingWasLoading = false;

  /// Automatikus frissítés-ellenőrzés (Beállítások → Frissítések).
  bool _autoUpdateCheck = true;
  UpdateCheckResult? _updateResult;
  bool _updateBannerDismissed = false;

  /// Az ablak legutóbb mentett helyzete (az asztali integráció jelzi).
  WindowGeometry? _windowGeometry;

  /// Beállítások → Tálca és indítás.
  bool _closeToTray = false;
  bool _closeToTrayHintShown = false;
  bool _startMinimized = false;

  /// A Windows „Run” bejegyzésének állapota (induláskor kiolvasva).
  bool _launchAtStartup = false;

  /// Az első tálcára rejtés után a következő megjelenéskor SnackBar-tipp.
  bool _trayHintPending = false;

  /// Beállítások → Értesítések, és a tálcamenüből indított szünet.
  NotificationSettings _notificationSettings = const NotificationSettings();
  DateTime? _notificationsPausedUntil;
  Timer? _pauseTimer;

  /// A háttérfigyelő (csak ha van értesítési szolgáltatás).
  AthleteWatcher? _watcher;

  /// Billentyűparancsok jelzései a látható oldal felé.
  final CourtboardCommands _commands = CourtboardCommands();

  /// A shell fókuszcsomópontja: a billentyűparancsok innen indulnak akkor
  /// is, ha az oldalon semmi nincs fókuszban.
  final FocusNode _shellFocus = FocusNode(debugLabel: 'courtboard-shell');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ModalRoute<Object?>? _route;

  final List<Athlete> _athletes = [
    _seedAthlete(
      name: 'Nikola Jokić',
      sport: 'NBA',
      team: 'Denver Nuggets',
      country: 'Szerbia',
      accent: const Color(0xFFE9B86E),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/7/79/Nikola_Jokic_2023.jpg',
    ),
    _seedAthlete(
      name: 'Aitana Bonmatí',
      sport: 'Foci',
      team: 'FC Barcelona',
      country: 'Spanyolország',
      accent: const Color(0xFF9CAAF7),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/8/8f/Aitana_Bonmat%C3%AD_2023.jpg',
    ),
    _seedAthlete(
      name: 'Luke Humphries',
      sport: 'Darts',
      team: 'PDC',
      country: 'Anglia',
      accent: const Color(0xFFE894A7),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/6/6e/Luke_Humphries_2023.jpg',
    ),
    _seedAthlete(
      name: 'Caitlin Clark',
      sport: 'WNBA',
      team: 'Indiana Fever',
      country: 'USA',
      accent: const Color(0xFF70B7C5),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/8/8d/Caitlin_Clark_2024.jpg',
    ),
    _seedAthlete(
      name: 'Saquon Barkley',
      sport: 'NFL',
      team: 'Philadelphia Eagles',
      country: 'USA',
      accent: const Color(0xFF8ED19C),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/9/9c/Saquon_Barkley_2023.jpg',
    ),
  ];

  /// Alap sportoló kitalált statisztikák nélkül: a számok kizárólag élő
  /// adatforrásból érkezhetnek a profiloldalon.
  static Athlete _seedAthlete({
    required String name,
    required String sport,
    required String team,
    required String country,
    required Color accent,
    required String photoUrl,
  }) => Athlete(
    name: name,
    sport: sport,
    team: team,
    country: country,
    photoUrl: photoUrl,
    accent: accent,
    seasonLabel: '',
    seasonValue: '',
    primaryLabel: '',
    primaryValue: '',
    metrics: const [],
    matches: const [],
  );

  @override
  void initState() {
    super.initState();
    _applyState(widget.initialState);
    unawaited(_loadPlaylist());
    unawaited(_loadHighlights());
    unawaited(_loadFeedNews());
    FocusManager.instance.addListener(_keepShellFocus);
    _upcoming.addListener(_upcomingChanged);
    // Háttérben (6 órás gyorsítótárral) betöltjük a közelgő eseményeket, hogy
    // a „Mai fókusz” a naptár megnyitása nélkül is lássa a következőt.
    unawaited(_loadUpcoming());
    if (_autoUpdateCheck && widget.updateChecker != null) {
      unawaited(_checkForUpdates());
    }
    _initDesktop();
  }

  // ---------------------------------------------------------------------------
  // Asztali integráció: tálca, értesítések, háttérfigyelő
  // ---------------------------------------------------------------------------

  void _initDesktop() {
    final notifications = widget.notificationService;
    if (notifications != null) {
      notifications.onClick = _onNotificationClick;
      final watcher = AthleteWatcher(
        source:
            widget.watcherSource ??
            RepositoryWatcherSource(
              config: () => _apiConfig,
              news: _newsRepository,
            ),
        notifications: notifications,
        memoryStore: widget.watcherMemoryStore,
      );
      _watcher = watcher;
      _syncWatcher();
      watcher.start();
    }
    final desktop = widget.desktop;
    if (desktop != null) {
      desktop
        ..closeToTray = _closeToTray
        ..attach(
          DesktopHandlers(
            onRefreshNow: _refreshNow,
            onTogglePause: _togglePause,
            onHiddenToTray: _hiddenToTray,
            onWindowShown: _windowShown,
            onGeometryChanged: _geometryChanged,
            onBeforeQuit: _beforeQuit,
          ),
        );
      unawaited(
        desktop.updateTrayMenu(notificationsPaused: _notificationsPaused),
      );
    }
    _schedulePauseExpiry();
    unawaited(_loadStartupState());
  }

  /// A profilon értesítésre jelölt sportolók.
  List<Athlete> get _alertAthletes =>
      _athletes.where((athlete) => _alerts[athlete.name] == true).toList();

  bool get _notificationsPaused {
    final until = _notificationsPausedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _syncWatcher() => _watcher?.update(
    athletes: _calendarTargets(_alertAthletes),
    settings: _notificationSettings,
    pausedUntil: _notificationsPausedUntil,
    clearPause: _notificationsPausedUntil == null,
  );

  /// Tálcamenü „Frissítés most”: azonnali figyelőfutás (a források
  /// gyorsítótára érvényes), utána a kiemelések újraolvasása.
  void _refreshNow() => unawaited(_runWatcherNow());

  Future<void> _runWatcherNow() async {
    await _watcher?.run();
    if (mounted) await _loadHighlights();
  }

  /// „Értesítések szüneteltetése 1 órára” / „Értesítések folytatása”.
  void _togglePause() {
    setState(
      () => _notificationsPausedUntil = _notificationsPaused
          ? null
          : DateTime.now().add(const Duration(hours: 1)),
    );
    _schedulePauseExpiry();
    _saveLocalState();
    unawaited(
      widget.desktop?.updateTrayMenu(notificationsPaused: _notificationsPaused),
    );
  }

  /// A szünet lejártakor a tálcamenü felirata is visszaáll.
  void _schedulePauseExpiry() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    final until = _notificationsPausedUntil;
    if (until == null) return;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _notificationsPausedUntil = null;
      return;
    }
    _pauseTimer = Timer(remaining, () {
      _pauseTimer = null;
      if (!mounted) return;
      setState(() => _notificationsPausedUntil = null);
      _saveLocalState();
      unawaited(widget.desktop?.updateTrayMenu(notificationsPaused: false));
    });
  }

  /// Az első tálcára rejtéskor egyszeri tipp (értesítés, és a következő
  /// megjelenéskor SnackBar).
  void _hiddenToTray() {
    if (_closeToTrayHintShown) return;
    _closeToTrayHintShown = true;
    _trayHintPending = true;
    _saveLocalState();
    unawaited(
      widget.notificationService?.show(
        const CourtboardNotification(
          id: 'tray-hint',
          kind: CourtboardNotificationKind.info,
          title: 'A Courtboard a tálcán fut tovább',
          body:
              'Kattints a tálcaikonra a megnyitáshoz; kilépés a tálcaikon '
              'menüjéből.',
        ),
      ),
    );
  }

  void _windowShown() {
    if (!_trayHintPending) return;
    _trayHintPending = false;
    _showSnack(
      'A Courtboard a tálcán futott tovább. Kilépés: tálcaikon → Kilépés '
      '(Beállítások → Tálca és indítás).',
    );
  }

  void _geometryChanged(WindowGeometry geometry) {
    _windowGeometry = geometry;
    _saveLocalState();
  }

  Future<void> _beforeQuit() async {
    _watcher?.stop();
    await _flushLocalState();
  }

  /// Értesítésre kattintva: ablak előhozása, majd a sportoló profilja
  /// (hírösszesítőnél a Hírek oldal).
  void _onNotificationClick(CourtboardNotification notification) {
    unawaited(widget.desktop?.showWindow());
    if (!mounted) return;
    final name = notification.athleteName;
    final athlete = name == null
        ? null
        : _athletes.where((item) => item.name == name).firstOrNull;
    if (athlete != null) {
      _openProfile(athlete);
    } else if (notification.kind == CourtboardNotificationKind.news) {
      _navigate(_Nav.news);
    }
  }

  Future<void> _loadStartupState() async {
    final startup = widget.startupRegistration;
    if (startup == null || !startup.supported) return;
    final enabled = await startup.isEnabled();
    if (mounted) setState(() => _launchAtStartup = enabled);
  }

  Future<void> _setLaunchAtStartup(bool value) async {
    final startup = widget.startupRegistration;
    if (startup == null) return;
    try {
      await startup.setEnabled(value, minimized: _startMinimized);
    } catch (_) {
      _showSnack('Az automatikus indítás beállítása nem sikerült.');
    }
    final enabled = await startup.isEnabled();
    if (mounted) setState(() => _launchAtStartup = enabled);
  }

  Future<void> _setStartMinimized(bool value) async {
    setState(() => _startMinimized = value);
    _saveLocalState();
    final startup = widget.startupRegistration;
    if (startup == null || !_launchAtStartup) return;
    try {
      await startup.setEnabled(true, minimized: value);
    } catch (_) {
      _showSnack('Az automatikus indítás beállítása nem sikerült.');
    }
  }

  void _setCloseToTray(bool value) {
    setState(() => _closeToTray = value);
    widget.desktop?.closeToTray = value;
    _saveLocalState();
  }

  void _setNotificationSettings(NotificationSettings value) {
    setState(() => _notificationSettings = value);
    _saveLocalState();
  }

  Future<bool> _sendTestNotification() async {
    final service = widget.notificationService;
    if (service == null) return false;
    return service.show(
      const CourtboardNotification(
        id: 'test',
        kind: CourtboardNotificationKind.test,
        title: 'Courtboard – teszt értesítés',
        body:
            'Az értesítések működnek. Így jelez a Courtboard meccskezdéskor, '
            'új eredménynél és új hírnél.',
      ),
    );
  }

  /// Kilépés előtt: az állapot mentésének megvárása.
  Future<void> _flushLocalState() async {
    final store = widget.stateStore;
    if (store == null) return;
    try {
      await store.save(_currentState());
    } catch (_) {
      // Kilépéskor már nem tudunk mit tenni.
    }
  }

  Future<void> _loadUpcoming() =>
      _upcoming.load(_calendarTargets(_athletes), config: _apiConfig);

  /// Egy betöltési kör végén a kiemelések újraolvasása.
  void _upcomingChanged() {
    final loading = _upcoming.isLoading;
    if (_upcomingWasLoading && !loading) unawaited(_loadHighlights());
    _upcomingWasLoading = loading;
  }

  /// Frissítés-ellenőrzés; [force] esetén a 12 órás gyorsítótár nélkül.
  Future<UpdateCheckResult?> _checkForUpdates({bool force = false}) async {
    final checker = widget.updateChecker;
    if (checker == null) return null;
    final result = await checker.check(force: force);
    if (!mounted) return result;
    setState(() {
      _updateResult = result;
      if (force) _updateBannerDismissed = false;
    });
    return result;
  }

  void _setAutoUpdateCheck(bool value) {
    setState(() => _autoUpdateCheck = value);
    _saveLocalState();
    if (value && _updateResult == null) unawaited(_checkForUpdates());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepShellFocus);
    _shellFocus.dispose();
    _commands.dispose();
    _upcoming.removeListener(_upcomingChanged);
    if (widget.upcomingEvents == null) _upcoming.dispose();
    _watcher?.dispose();
    _pauseTimer?.cancel();
    widget.notificationService?.onClick = null;
    widget.desktop?.attach(const DesktopHandlers());
    _search.dispose();
    unawaited(_newsRepository.close());
    super.dispose();
  }

  void _applyState(CourtboardLocalState state) {
    _notes = {...state.notes};
    _alerts = {...state.alerts};
    // Elsőbbség: mentett kulcs > régi JSON-kulcs > környezeti változó.
    _legacyApiKeys = state.legacyApiKeys;
    _apiConfig = _apiConfig.withKeys({
      ...state.legacyApiKeys,
      ...widget.apiKeys,
    });
    _removedAthleteNames = {...state.removedAthleteNames};
    _pinned = [...state.pinnedAthletes];
    _overviewSort = state.overviewSort;
    _athleteSort = state.athleteSort;
    _selectedTheme = state.theme;
    _selectedThemeMode = state.themeMode;
    _railCollapsed = state.railCollapsed;
    _autoUpdateCheck = state.autoUpdateCheck;
    _windowGeometry = state.windowGeometry;
    _closeToTray = state.closeToTray;
    _closeToTrayHintShown = state.closeToTrayHintShown;
    _startMinimized = state.startMinimized;
    _notificationSettings = state.notifications;
    final pausedUntil = state.notificationsPausedUntil;
    _notificationsPausedUntil =
        pausedUntil != null && pausedUntil.isAfter(DateTime.now())
        ? pausedUntil
        : null;
    _athletes.removeWhere(
      (athlete) => _removedAthleteNames.contains(athlete.name),
    );
    final known = _athletes.map((athlete) => athlete.name).toSet();
    _athletes.addAll(
      state.customAthletes
          .where((athlete) => known.add(athlete.name))
          .map(_customToAthlete),
    );
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

  Athlete _customToAthlete(CustomAthlete athlete) => Athlete(
    name: athlete.name,
    sport: athlete.sport,
    team: athlete.team,
    // Régebbi mentésekben „Ismeretlen” helyőrző szerepelhet: nem mutatjuk.
    country: athlete.country.trim() == 'Ismeretlen' ? '' : athlete.country,
    photoUrl: athlete.photoUrl,
    // Saját sportoló azonosító színe (a téma kiemelőszínétől független).
    accent: const Color(0xFF9BAF65),
    seasonLabel: '',
    seasonValue: '',
    primaryLabel: '',
    primaryValue: '',
    metrics: const [],
    matches: const [],
    isCustom: true,
  );

  CourtboardLocalState _currentState() => CourtboardLocalState(
    notes: _notes,
    alerts: _alerts,
    removedAthleteNames: _removedAthleteNames,
    legacyApiKeys: _legacyApiKeys,
    theme: _selectedTheme,
    themeMode: _selectedThemeMode,
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
    customAthletes: _athletes
        .where((a) => a.isCustom)
        .map(
          (a) => CustomAthlete(
            name: a.name,
            sport: a.sport,
            team: a.team,
            country: a.country,
            photoUrl: a.photoUrl,
          ),
        )
        .toList(),
  );

  /// Háttérben menti az állapotot (a tároló sorba rendezi az írásokat);
  /// hiba esetén SnackBar jelzi, hogy a módosítás nem került lemezre.
  void _saveLocalState() {
    // Minden mentett változás (értesítésjelölés, sportolólista, beállítások)
    // a háttérfigyelőhöz is eljut.
    _syncWatcher();
    final store = widget.stateStore;
    if (store == null) return;
    unawaited(
      store
          .save(_currentState())
          .catchError(
            (Object _) =>
                _showSnack('A módosítások mentése nem sikerült. Próbáld újra.'),
          ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setNote(Athlete athlete, String value) {
    setState(() => _notes = {..._notes, athlete.name: value});
    _saveLocalState();
  }

  bool _isPinned(Athlete athlete) => _pinned.contains(athlete.name);

  /// „Kitűzés” / „Kitűzés megszüntetése”: a kitűzött sportolók a
  /// nyitóoldalon a saját sorrend előtt, jelvénnyel jelennek meg.
  void _togglePin(Athlete athlete) {
    final pinned = _isPinned(athlete);
    setState(
      () => _pinned = pinned
          ? [
              for (final name in _pinned)
                if (name != athlete.name) name,
            ]
          : [..._pinned, athlete.name],
    );
    _saveLocalState();
    _showSnack(
      pinned
          ? '${athlete.name} kitűzése megszűnt.'
          : '${athlete.name} kitűzve: a nyitóoldalon elöl jelenik meg.',
    );
  }

  /// Az Összehasonlítás oldal megnyitása a sportolóval előre kiválasztva.
  void _openCompare(Athlete athlete) {
    setState(() => _compareFocus = athlete.name);
    _navigate(_Nav.compare);
  }

  /// A hírfolyam hírei a helyi hírarchívumból (hálózat nélkül).
  Future<void> _loadFeedNews() async {
    if (_feedLoading) return;
    _feedLoading = true;
    try {
      final articles = await _newsRepository.store.query(limit: 400);
      final names = _athletes.map((athlete) => athlete.name).toList();
      final related = [
        for (final article in articles)
          if (names.any((name) => newsMatchesAthlete(article, name))) article,
      ];
      if (mounted) setState(() => _feedArticles = related);
    } catch (_) {
      // A hírarchívum hibája nem akaszthatja meg a hírfolyam többi részét.
    } finally {
      _feedLoading = false;
    }
  }

  /// A hírfolyam frissítése a meglévő szabályok szerint: a hírforrások csak
  /// a frissítési időközük lejárta után, a naptár a gyorsítótárból (6 óra),
  /// a kiemelések helyből töltődnek.
  Future<void> _refreshFeed() async {
    await Future.wait<void>([
      _newsRepository.refresh().then<void>((_) {}, onError: (Object _) {}),
      _loadUpcoming(),
    ]);
    await _loadHighlights();
    await _loadFeedNews();
  }

  /// A hírfolyam elemei a shell már betöltött állapotából.
  List<FeedItem> _feedItems() {
    final now = DateTime.now();
    final names = _athletes.map((athlete) => athlete.name).toList();
    final followed = names.toSet();
    return mergeFeed([
      ...feedFromUpcoming(
        _upcoming.events().where(
          (event) => followed.contains(event.athleteName),
        ),
        now,
      ),
      ...feedFromHighlights(_highlights, now),
      ...feedFromNews(_feedArticles, names),
      ...feedFromVideos(_playlist.videos, names),
    ]);
  }

  void _toggleAlert(Athlete athlete) {
    setState(
      () => _alerts = {
        ..._alerts,
        athlete.name: !(_alerts[athlete.name] ?? false),
      },
    );
    _saveLocalState();
  }

  Future<void> _loadPlaylist() async {
    final file = widget.playlistFile;
    if (file == null) return;
    try {
      if (!await file.exists()) return;
      final content = jsonDecode(await file.readAsString());
      if (mounted) {
        setState(() => _playlist = AthleteVideoPlaylist.fromJson(content));
      }
    } catch (_) {
      // A hibás fájlt nem írhatjuk felül: előbb biztonsági másolat készül,
      // és csak ennek sikere után engedjük a mentést.
      final backup = await _backupPlaylistFile(file);
      if (!mounted) return;
      setState(() => _playlistSaveBlocked = backup == null);
      _showSnack(
        backup == null
            ? 'A mentett videólista nem olvasható be. A fájl védelmében a videólista módosításai most nem kerülnek mentésre.'
            : 'A mentett videólista nem olvasható be. Az eredeti fájlról biztonsági másolat készült: ${backup.path}',
      );
    }
  }

  Future<File?> _backupPlaylistFile(File file) async {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 17);
    final path = file.path.endsWith('.json')
        ? file.path.substring(0, file.path.length - 5)
        : file.path;
    try {
      return await file.copy('$path.corrupt-$stamp.json');
    } catch (_) {
      return null;
    }
  }

  /// A videólista mentése. Hibát dob, ha a fájl nem írható, vagy ha a
  /// korábbi, olvashatatlan fájl védelme miatt a mentés tiltott.
  Future<void> _savePlaylist(AthleteVideoPlaylist playlist) async {
    final file = widget.playlistFile;
    if (file == null) return;
    if (_playlistSaveBlocked) {
      throw const FileSystemException('A videólista mentése le van tiltva.');
    }
    await writeFileAtomic(file, jsonEncode(playlist.toJson()));
  }

  void _toggleVideo(SavedYouTubeVideo video) {
    final updated = _playlist.remove(video);
    setState(() => _playlist = updated);
    unawaited(
      _savePlaylist(updated).catchError(
        (Object _) => _showSnack('A videólista mentése nem sikerült.'),
      ),
    );
  }

  Future<void> _addVideo(SavedYouTubeVideo video) async {
    final updated = _playlist.add(video);
    await _savePlaylist(updated);
    if (mounted) setState(() => _playlist = updated);
  }

  Future<void> _openAddVideo(Athlete athlete) => showDialog<void>(
    context: context,
    builder: (_) =>
        _AddVideoDialog(athleteName: athlete.name, onSave: _addVideo),
  );

  Future<void> _confirmDeleteAthlete(Athlete athlete) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('delete-athlete-dialog'),
      icon: Icon(Icons.delete_outline, color: dialogContext.cb.error),
      title: const Text('Sportoló törlése'),
      content: Text(
        'Biztosan törlöd őt a követettek közül?\n\n${athlete.name}\n\n'
        'A jegyzet és a mentett videók megmaradnak, a sportoló bármikor '
        'újra felvehető.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Mégse'),
        ),
        FilledButton(
          key: const Key('delete-athlete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: dialogContext.cb.error,
            foregroundColor: dialogContext.cb.isDark
                ? const Color(0xFF3B0A08)
                : Colors.white,
          ),
          onPressed: () {
            setState(() {
              _removedAthleteNames.add(athlete.name);
              _athletes.removeWhere((item) => item.name == athlete.name);
              _pinned = [
                for (final name in _pinned)
                  if (name != athlete.name) name,
              ];
              _openAthlete = null;
            });
            _saveLocalState();
            Navigator.pop(dialogContext);
          },
          child: const Text('Törlés'),
        ),
      ],
    ),
  );

  /// A profil „Vissza” gombjának felirata a megnyitás helye szerint.
  String get _backLabel => switch (_activeNav) {
    _Nav.athletes => 'Vissza: Sportolók',
    _Nav.videos => 'Vissza: Videók',
    _Nav.feed => 'Vissza: Követés',
    _Nav.compare => 'Vissza: Összehasonlítás',
    _ => 'Vissza: Áttekintés',
  };

  void _openProfile(Athlete athlete) => setState(() => _openAthlete = athlete);

  /// Vissza a profilból; a kiemelések újraolvasása, hogy a profilon most
  /// betöltött eredmény az Áttekintésen is megjelenjen.
  void _closeProfile() {
    setState(() => _openAthlete = null);
    unawaited(_loadHighlights());
  }

  void _navigate(int index) {
    final wasProfile = _openAthlete != null;
    setState(() {
      _openAthlete = null;
      _activeNav = index;
    });
    if (wasProfile || index == _Nav.overview) unawaited(_loadHighlights());
    // A Hírek oldalon közben érkezett cikkek a hírfolyamba is bekerülnek.
    if (index == _Nav.overview || index == _Nav.feed) {
      unawaited(_loadFeedNews());
    }
  }

  Future<void> _loadHighlights() async {
    final names = _athletes.map((athlete) => athlete.name).toList();
    final highlights = await AthleteHighlightStore.shared.readAll(names);
    if (mounted) setState(() => _highlights = highlights);
  }

  void _toggleRail() {
    setState(() => _railCollapsed = !_railCollapsed);
    _saveLocalState();
  }

  /// Ha a fókusz „elveszik” (például egy fókuszban lévő mező eltűnik egy
  /// oldalváltáskor), visszakerül a shellre, így a billentyűparancsok mindig
  /// működnek. Nyitott párbeszédablaknál (nem aktuális útvonal) nem nyúl hozzá.
  void _keepShellFocus() {
    if (!mounted || !(_route?.isCurrent ?? true)) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        (primary == _shellFocus || primary.ancestors.contains(_shellFocus))) {
      return;
    }
    // Csak akkor vesszük vissza, ha a fókusz egy őscsomóponton (gyökér vagy
    // útvonal-hatókör) ragadt, nem egy másik widget saját mezőjén.
    if (primary != null && !_shellFocus.ancestors.contains(primary)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_route?.isCurrent ?? true)) return;
      final current = FocusManager.instance.primaryFocus;
      if (current == null || _shellFocus.ancestors.contains(current)) {
        _shellFocus.requestFocus();
      }
    });
  }

  /// A látható oldal címe (keskeny ablak felső sávjához).
  String get _pageTitle =>
      _openAthlete?.name ??
      _navItems[_activeNav.clamp(0, _navItems.length - 1)].$2;

  /// Oldalak, amelyeken van keresőmező (Ctrl+F).
  bool get _pageHasSearch =>
      _openAthlete == null &&
      const {
        _Nav.overview,
        _Nav.athletes,
        _Nav.news,
        _Nav.videos,
      }.contains(_activeNav);

  void _focusSearch() {
    if (_pageHasSearch && _commands.hasSearchHandler) {
      _commands.requestSearchFocus();
      return;
    }
    // Keresőmező nélküli oldalról az Áttekintés keresőjére ugrunk.
    _navigate(_Nav.overview);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _commands.requestSearchFocus(),
    );
  }

  void _refreshPage() {
    if (_commands.hasRefreshHandler) {
      _commands.requestRefresh();
    } else {
      unawaited(_loadHighlights());
    }
  }

  Map<Type, Action<Intent>> get _actions => {
    _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
      onInvoke: (_) {
        _focusSearch();
        return null;
      },
    ),
    _BackIntent: _ShellAction<_BackIntent>(
      enabled: () => _openAthlete != null,
      onInvoke: _closeProfile,
    ),
    _RefreshIntent: CallbackAction<_RefreshIntent>(
      onInvoke: (_) {
        _refreshPage();
        return null;
      },
    ),
    _NavigateIntent: CallbackAction<_NavigateIntent>(
      onInvoke: (intent) {
        _navigate(intent.index);
        return null;
      },
    ),
    _AddAthleteIntent: CallbackAction<_AddAthleteIntent>(
      onInvoke: (_) {
        unawaited(_openAddAthlete());
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final showingProfile = _openAthlete != null;
    final width = MediaQuery.sizeOf(context).width;
    final mode = _Layout.modeFor(width, collapsed: _railCollapsed);
    final canToggle = width >= _Layout.fullRailBreakpoint;
    void selectFromDrawer(int index) {
      _scaffoldKey.currentState?.closeDrawer();
      _navigate(index);
    }

    final page = showingProfile
        ? _ProfilePage(
            key: ValueKey(_openAthlete!.name),
            athlete: _openAthlete!,
            backLabel: _backLabel,
            apiConfig: _apiConfig,
            videos: _playlist.forAthlete(_openAthlete!.name),
            note: _notes[_openAthlete!.name] ?? '',
            alertEnabled: _alerts[_openAthlete!.name] ?? false,
            onBack: _closeProfile,
            onToggleClip: _toggleVideo,
            onAddVideo: () => unawaited(_openAddVideo(_openAthlete!)),
            onDelete: () => unawaited(_confirmDeleteAthlete(_openAthlete!)),
            onSaveNote: _setNote,
            onToggleAlert: _toggleAlert,
            pinned: _isPinned(_openAthlete!),
            onTogglePin: () => _togglePin(_openAthlete!),
            onCompare: () => _openCompare(_openAthlete!),
          )
        : _buildPage();

    return CourtboardCommandScope(
      commands: _commands,
      child: Shortcuts(
        shortcuts: _shellShortcuts,
        child: Actions(
          actions: _actions,
          child: Focus(
            focusNode: _shellFocus,
            autofocus: true,
            child: Scaffold(
              key: _scaffoldKey,
              drawer: mode == _RailMode.drawer
                  ? Drawer(
                      width: 264,
                      backgroundColor: context.cb.ink,
                      child: _SideRail(
                        active: _activeNav,
                        width: double.infinity,
                        onSelect: selectFromDrawer,
                      ),
                    )
                  : null,
              body: SafeArea(
                child: Row(
                  // A tartalom mindig kitölti a teljes magasságot (rövid
                  // oldalnál sem kerül függőlegesen középre).
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (mode != _RailMode.drawer)
                      _SideRail(
                        // A profil megnyitásakor a kiinduló menüpont marad
                        // kiemelve.
                        active: _activeNav,
                        compact: mode == _RailMode.compact,
                        onToggle: canToggle ? _toggleRail : null,
                        onSelect: _navigate,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mode == _RailMode.drawer)
                            _CompactTopBar(
                              title: _pageTitle,
                              onMenu: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                          if (_updateResult?.updateAvailable == true &&
                              !_updateBannerDismissed)
                            _UpdateBanner(
                              result: _updateResult!,
                              onDownload: () => unawaited(
                                openExternalUrl(
                                  context,
                                  _updateResult!.latest?.htmlUrl ??
                                      widget.updateChecker!.releasesPage,
                                ),
                              ),
                              onDismiss: () =>
                                  setState(() => _updateBannerDismissed = true),
                            ),
                          Expanded(child: _ContentFrame(child: page)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage() => switch (_activeNav) {
    _Nav.overview => _Dashboard(
      athletes: _athletes,
      highlights: _highlights,
      search: _search,
      sort: _overviewSort,
      filter: _dashboardFilter,
      onFilterChanged: (value) => setState(() => _dashboardFilter = value),
      onOpenSettings: () => _navigate(_Nav.settings),
      onOpen: _openProfile,
      onAddAthlete: _openAddAthlete,
      onOpenNews: () => _navigate(_Nav.news),
      onOpenVideos: () => _navigate(_Nav.videos),
      pinned: _pinned.toSet(),
      onTogglePin: _togglePin,
      onCompare: _openCompare,
      feed: _feedItems(),
      onOpenFeed: () => _navigate(_Nav.feed),
      liveTargets: _calendarTargets(_athletes),
    ),
    _Nav.athletes => _AthleteDirectory(
      athletes: _athletes,
      sort: _athleteSort,
      onOpen: _openProfile,
      onAdd: _openAddAthlete,
      onReorder: _reorderAthletes,
    ),
    _Nav.calendar => _CalendarPage(
      athletes: _athletes,
      controller: _upcoming,
      config: _apiConfig,
    ),
    _Nav.news => NewsPage(
      repository: _newsRepository,
      athletes: _athletes
          .map(
            (athlete) =>
                NewsAthleteRef(name: athlete.name, sport: athlete.sport),
          )
          .toList(),
    ),
    _Nav.videos => VideoLibraryPage(
      athletes: _athletes,
      playlist: _playlist,
      onOpenAthlete: _openProfile,
      onRemoveVideo: _toggleVideo,
      onOpenAthletes: () => _navigate(_Nav.athletes),
    ),
    _Nav.feed => _FollowFeedPage(
      items: _feedItems(),
      athletes: _athletes,
      onOpenAthlete: _openProfile,
      onRefresh: _refreshFeed,
    ),
    _Nav.compare => _ComparePage(
      athletes: _athletes,
      config: _apiConfig,
      source: widget.compareSource ?? const RepositoryCompareSource(),
      initialAthlete: _compareFocus,
      onOpenAthlete: _openProfile,
    ),
    _Nav.dataSources => _DataStatusPage(
      config: _apiConfig,
      secureStorageAvailable: _secureStorageAvailable,
      onSaveKey: (id, value) => unawaited(_saveApiKey(id, value)),
    ),
    _ => _SettingsPage(
      theme: _selectedTheme,
      themeMode: _selectedThemeMode,
      onThemeModeChanged: _setThemeMode,
      overviewSort: _overviewSort,
      athleteSort: _athleteSort,
      onThemeChanged: _setTheme,
      onOverviewSortChanged: _setOverviewSort,
      onAthleteSortChanged: _setAthleteSort,
      appVersion: widget.appVersion,
      autoUpdateCheck: _autoUpdateCheck,
      onAutoUpdateCheckChanged: _setAutoUpdateCheck,
      updateResult: _updateResult,
      onCheckUpdatesNow: widget.updateChecker == null
          ? null
          : () => _checkForUpdates(force: true),
      notificationSettings: _NotificationSettingsCard(
        settings: _notificationSettings,
        onChanged: _setNotificationSettings,
        alertAthleteCount: _alertAthletes.length,
        serviceDescription: widget.notificationService?.available == true
            ? widget.notificationService!.description
            : null,
        pausedUntil: _notificationsPaused ? _notificationsPausedUntil : null,
        onResume: _notificationsPaused ? _togglePause : null,
        onTest: widget.notificationService == null
            ? null
            : _sendTestNotification,
      ),
      desktopSettings: _buildDesktopSettings(),
    ),
  };

  Widget _buildDesktopSettings() {
    final startup = widget.startupRegistration;
    final startupSupported = startup != null && startup.supported;
    return _DesktopSettingsCard(
      closeToTray: _closeToTray,
      onCloseToTrayChanged: widget.desktop?.trayAvailable == true
          ? _setCloseToTray
          : null,
      launchAtStartup: _launchAtStartup,
      onLaunchAtStartupChanged: startupSupported
          ? (value) => unawaited(_setLaunchAtStartup(value))
          : null,
      startMinimized: _startMinimized,
      onStartMinimizedChanged: startupSupported
          ? (value) => unawaited(_setStartMinimized(value))
          : null,
      startupUnavailableReason: startup != null && !startup.supported
          ? startup.unsupportedReason
          : null,
      desktopAvailable: widget.desktop != null,
    );
  }

  void _setTheme(String value) {
    setState(() => _selectedTheme = value);
    widget.onThemeChanged(value);
    _saveLocalState();
  }

  void _setThemeMode(String value) {
    setState(() => _selectedThemeMode = value);
    widget.onThemeModeChanged?.call(value);
    _saveLocalState();
  }

  void _setOverviewSort(String value) {
    setState(() => _overviewSort = value);
    _saveLocalState();
  }

  void _setAthleteSort(String value) {
    setState(() => _athleteSort = value);
    _saveLocalState();
  }

  /// Egy API-kulcs mentése: azonnal érvényes, és a biztonságos tárolóba
  /// kerül (soha nem a JSON-állapotfájlba). Ha a tároló hibázik, a kulcs az
  /// app bezárásáig memóriában él, és az Adatforrások oldal figyelmeztet.
  Future<void> _saveApiKey(ApiKeyId id, String value) async {
    setState(() => _apiConfig = _apiConfig.withKey(id, value));
    try {
      await _apiKeyStore.save(id, value);
      // Egy korábban a JSON-ban rekedt régi érték a következő induláskor
      // felülírná az újat, ezért azt most kivesszük.
      if (_legacyApiKeys.containsKey(id)) {
        _legacyApiKeys = {..._legacyApiKeys}..remove(id);
        _saveLocalState();
      }
    } on Object {
      if (!mounted) return;
      setState(() => _secureStorageAvailable = false);
      _showSnack(
        'A(z) ${id.label} kulcs nem menthető a biztonságos tárolóba; '
        'az app bezárásáig érvényes.',
      );
    }
  }

  /// „Saját sorrend” módosítása húzással (a teljes, szűretlen listán).
  /// A [newIndex] már az elem kivétele utáni listára vonatkozik.
  void _reorderAthletes(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      final athlete = _athletes.removeAt(oldIndex);
      _athletes.insert(newIndex, athlete);
    });
    _saveLocalState();
  }

  /// Profilkép keresése; hiba vagy időtúllépés esetén `null` (monogram).
  Future<String?> _resolveProfileImage(String name) async {
    final client = SportsApiClient(config: _apiConfig);
    try {
      return await client
          .resolveProfileImage(name)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> _openAddAthlete() async {
    final athlete = await showDialog<CustomAthlete>(
      context: context,
      builder: (_) => _AddAthleteDialog(
        existingNames: _athletes.map((athlete) => athlete.name).toList(),
        resolveImage: _resolveProfileImage,
      ),
    );
    if (athlete == null || !mounted) return;
    setState(() => _athletes.add(_customToAthlete(athlete)));
    _saveLocalState();
  }
}

class _AddAthleteDialog extends StatefulWidget {
  const _AddAthleteDialog({
    required this.existingNames,
    required this.resolveImage,
  });

  final List<String> existingNames;
  final Future<String?> Function(String name) resolveImage;

  @override
  State<_AddAthleteDialog> createState() => _AddAthleteDialogState();
}

class _AddAthleteDialogState extends State<_AddAthleteDialog> {
  final _name = TextEditingController();
  final _team = TextEditingController();
  String _sport = 'NBA';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _team.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add meg a sportoló nevét.');
      return;
    }
    final normalized = normalizeAthleteName(name);
    if (widget.existingNames.any(
      (existing) => normalizeAthleteName(existing) == normalized,
    )) {
      setState(
        () => _error = 'Ez a sportoló már szerepel a követettek között.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? imageUrl;
    try {
      imageUrl = await widget.resolveImage(name);
    } catch (_) {
      // A képkeresés hibája nem akadályozza a hozzáadást: monogram jelenik meg.
      imageUrl = null;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      CustomAthlete(
        name: name,
        sport: _sport,
        team: _sport == 'Darts' || _sport == 'Tenisz' ? '' : _team.text.trim(),
        photoUrl: imageUrl ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sportoló hozzáadása'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('add-athlete-name'),
            controller: _name,
            autofocus: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Név'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            style: context.text.bodyLarge,
            initialValue: _sport,
            decoration: const InputDecoration(labelText: 'Sportág'),
            items: const ['NBA', 'WNBA', 'Foci', 'Darts', 'Tenisz', 'NFL']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _sport = value ?? _sport),
          ),
          if (_sport != 'Darts' && _sport != 'Tenisz') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _team,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Csapat / klub'),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              _sport == 'Tenisz'
                  ? 'A teniszezőkhöz nem kell csapatot megadni.'
                  : 'A dartsjátékosokhoz nem kell csapatot megadni.',
              style: context.text.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _busy
                ? 'Profilkép keresése…'
                : 'A profilképet a rendszer háttérben próbálja feloldani; sikertelen esetben monogram jelenik meg.',
            style: context.text.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('add-athlete-error'),
              style: context.text.bodySmall?.copyWith(
                color: context.cb.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Mégse'),
      ),
      FilledButton.icon(
        key: const Key('add-athlete-submit'),
        onPressed: _busy ? null : _submit,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Hozzáadás'),
      ),
    ],
  );
}

class _AddVideoDialog extends StatefulWidget {
  const _AddVideoDialog({required this.athleteName, required this.onSave});

  final String athleteName;
  final Future<void> Function(SavedYouTubeVideo video) onSave;

  @override
  State<_AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<_AddVideoDialog> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final id = YouTubeVideoId.parse(_input.text);
    if (id == null) {
      setState(() => _error = 'Érvénytelen YouTube-link vagy videóazonosító.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final SavedYouTubeVideo video;
    try {
      video = await YouTubeOEmbed.resolve(id, widget.athleteName);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'A YouTube videócíme most nem kérhető le. Próbáld újra később.';
        });
      }
      return;
    }
    try {
      await widget.onSave(video);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'A videó mentése nem sikerült.';
        });
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('YouTube-videó hozzáadása'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _input,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'YouTube link vagy videóazonosító',
              hintText: 'https://youtu.be/… vagy 11 karakteres ID',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: context.text.bodySmall?.copyWith(
                color: context.cb.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Mégse'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _submit,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Hozzáadás'),
      ),
    ],
  );
}

/// A Back intent csak akkor „fogyasztja el” a billentyűt, ha van hova
/// visszalépni; különben az Esc továbbjut (például a párbeszédablakokhoz).
class _ShellAction<T extends Intent> extends Action<T> {
  _ShellAction({required this.enabled, required this.onInvoke});
  final bool Function() enabled;
  final VoidCallback onInvoke;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
}

/// A lap tartalma: ultraszéles ablakban legfeljebb
/// [_Layout.contentMaxWidth] széles, vízszintesen középre zárva.
class _ContentFrame extends StatelessWidget {
  const _ContentFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.cb.canvas,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > _Layout.contentMaxWidth
            ? _Layout.contentMaxWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    ),
  );
}

List<Athlete> sortAthletes(List<Athlete> athletes, String mode) {
  final result = List<Athlete>.from(athletes);
  int byName(Athlete a, Athlete b) =>
      normalizeAthleteName(a.name).compareTo(normalizeAthleteName(b.name));
  switch (mode) {
    case 'name':
      result.sort(byName);
    case 'sport':
      result.sort((a, b) {
        final sport = a.sport.compareTo(b.sport);
        return sport != 0 ? sport : byName(a, b);
      });
    case 'team':
      result.sort((a, b) {
        final aTeam = a.showsTeam ? normalizeAthleteName(a.team) : 'zzzz';
        final bTeam = b.showsTeam ? normalizeAthleteName(b.team) : 'zzzz';
        final team = aTeam.compareTo(bTeam);
        return team != 0 ? team : byName(a, b);
      });
  }
  return result;
}
