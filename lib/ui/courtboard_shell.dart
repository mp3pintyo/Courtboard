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
    required this.onThemeChanged,
    this.onThemeModeChanged,
  });

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
    FocusManager.instance.addListener(_keepShellFocus);
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
    _overviewSort = state.overviewSort;
    _athleteSort = state.athleteSort;
    _selectedTheme = state.theme;
    _selectedThemeMode = state.themeMode;
    _railCollapsed = state.railCollapsed;
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
    1 => 'Vissza: Sportolók',
    4 => 'Vissza: Videók',
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
    if (wasProfile || index == 0) unawaited(_loadHighlights());
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
      _openAthlete?.name ?? _navItems[_activeNav.clamp(0, 6)].$2;

  /// Oldalak, amelyeken van keresőmező (Ctrl+F).
  bool get _pageHasSearch =>
      _openAthlete == null && const {0, 1, 3, 4}.contains(_activeNav);

  void _focusSearch() {
    if (_pageHasSearch && _commands.hasSearchHandler) {
      _commands.requestSearchFocus();
      return;
    }
    // Keresőmező nélküli oldalról az Áttekintés keresőjére ugrunk.
    _navigate(0);
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
    0 => _Dashboard(
      athletes: _athletes,
      highlights: _highlights,
      search: _search,
      sort: _overviewSort,
      filter: _dashboardFilter,
      onFilterChanged: (value) => setState(() => _dashboardFilter = value),
      onOpenSettings: () => _navigate(6),
      onOpen: _openProfile,
      onAddAthlete: _openAddAthlete,
      onOpenNews: () => _navigate(3),
      onOpenVideos: () => _navigate(4),
    ),
    1 => _AthleteDirectory(
      athletes: _athletes,
      sort: _athleteSort,
      onOpen: _openProfile,
      onAdd: _openAddAthlete,
      onReorder: _reorderAthletes,
    ),
    2 => const _CalendarPage(),
    3 => NewsPage(
      repository: _newsRepository,
      athletes: _athletes
          .map(
            (athlete) =>
                NewsAthleteRef(name: athlete.name, sport: athlete.sport),
          )
          .toList(),
    ),
    4 => VideoLibraryPage(
      athletes: _athletes,
      playlist: _playlist,
      onOpenAthlete: _openProfile,
      onRemoveVideo: _toggleVideo,
      onOpenAthletes: () => _navigate(1),
    ),
    5 => _DataStatusPage(
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
    ),
  };

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
