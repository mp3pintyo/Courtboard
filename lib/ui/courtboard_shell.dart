part of '../main.dart';

class CourtboardShell extends StatefulWidget {
  const CourtboardShell({
    super.key,
    required this.theme,
    required this.onThemeChanged,
  });
  final String theme;
  final ValueChanged<String> onThemeChanged;

  @override
  State<CourtboardShell> createState() => _CourtboardShellState();
}

class _CourtboardShellState extends State<CourtboardShell> {
  final _search = TextEditingController();
  late final File _playlistFile;
  AthleteVideoPlaylist _playlist = const AthleteVideoPlaylist();
  Athlete? _openAthlete;
  int _activeNav = 0;
  final LocalStateStore _stateStore = LocalStateStore();
  final NewsRepository _newsRepository = NewsRepository();
  Map<String, String> _notes = {};
  Map<String, bool> _alerts = {};
  Set<String> _removedAthleteNames = {};
  SportsApiConfig _apiConfig = SportsApiConfig.fromEnvironment();
  String _overviewSort = 'custom';
  String _athleteSort = 'custom';
  late String _selectedTheme;

  final List<Athlete> _athletes = [
    Athlete(
      name: 'Nikola Jokić',
      sport: 'NBA',
      team: 'Denver Nuggets',
      country: 'Szerbia',
      accent: Color(0xFFE9B86E),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/7/79/Nikola_Jokic_2023.jpg',
      seasonLabel: 'SZEZON PONT / MECCS',
      seasonValue: '26.8',
      primaryLabel: 'TRIPLA-DUPLA',
      primaryValue: '31',
      metrics: [
        Metric('PONT', '26.8', '+2.1 az előző szezonhoz'),
        Metric('LEPATTANÓ', '12.4', 'Liga #2'),
        Metric('GÓLPASSZ', '9.1', 'Poszt #1'),
        Metric('MEZŐNY', '58.7%', 'Kiemelkedő'),
      ],
      matches: [
        MatchLine(
          'JAN 18',
          'Phoenix Suns',
          'GYŐZELEM',
          '124 – 111',
          '34 PTS · 14 REB · 8 AST',
          'A+',
        ),
        MatchLine(
          'JAN 15',
          'Dallas Mavericks',
          'GYŐZELEM',
          '118 – 106',
          '29 PTS · 11 REB · 12 AST',
          'A',
        ),
        MatchLine(
          'JAN 12',
          'Boston Celtics',
          'VERESÉG',
          '102 – 109',
          '24 PTS · 13 REB · 7 AST',
          'B+',
        ),
      ],
    ),
    Athlete(
      name: 'Aitana Bonmatí',
      sport: 'Foci',
      team: 'FC Barcelona',
      country: 'Spanyolország',
      accent: Color(0xFF9CAAF7),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/8/8f/Aitana_Bonmat%C3%AD_2023.jpg',
      seasonLabel: 'GÓLHOZZÁJÁRULÁS',
      seasonValue: '19',
      primaryLabel: 'KULCSPASSZ',
      primaryValue: '62',
      metrics: [
        Metric('GÓL', '9', 'Minden sorozat'),
        Metric('GÓLPASSZ', '10', 'Minden sorozat'),
        Metric('PASSZPONT.', '91.8%', 'Szezon'),
        Metric('ÉRTÉKELÉS', '7.84', 'Átlag'),
      ],
      matches: [
        MatchLine(
          'JAN 19',
          'Real Madrid',
          'GYŐZELEM',
          '2 – 1',
          '1 gól · 2 kulcspassz · 8.7',
          'A+',
        ),
        MatchLine(
          'JAN 15',
          'Atlético',
          'DÖNTETLEN',
          '1 – 1',
          '1 gólpassz · 92% passz · 7.9',
          'A',
        ),
        MatchLine(
          'JAN 10',
          'Sevilla',
          'GYŐZELEM',
          '3 – 0',
          '4 szerelés · 5 kulcspassz · 8.3',
          'A',
        ),
      ],
    ),
    Athlete(
      name: 'Luke Humphries',
      sport: 'Darts',
      team: 'PDC',
      country: 'Anglia',
      accent: Color(0xFFE894A7),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/6/6e/Luke_Humphries_2023.jpg',
      seasonLabel: '3 DART ÁTLAG',
      seasonValue: '98.42',
      primaryLabel: '180-ASOK',
      primaryValue: '214',
      metrics: [
        Metric('3 DART ÁTLAG', '98.42', 'Szezon'),
        Metric('KISZÁLLÓ', '44.9%', 'Checkout'),
        Metric('180-ASOK', '214', 'Szezon'),
        Metric('LEGMAGASABB', '170', 'Checkout'),
      ],
      matches: [
        MatchLine(
          'JAN 18',
          'M. van Gerwen',
          'GYŐZELEM',
          '10 – 8',
          '101.6 átlag · 7×180 · 46% CO',
          'A+',
        ),
        MatchLine(
          'JAN 15',
          'G. Price',
          'GYŐZELEM',
          '6 – 3',
          '99.2 átlag · 4×180 · 50% CO',
          'A',
        ),
        MatchLine(
          'JAN 10',
          'L. Littler',
          'VERESÉG',
          '5 – 6',
          '96.8 átlag · 3×180 · 38% CO',
          'B',
        ),
      ],
    ),
    Athlete(
      name: 'Caitlin Clark',
      sport: 'WNBA',
      team: 'Indiana Fever',
      country: 'USA',
      accent: Color(0xFF70B7C5),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/8/8d/Caitlin_Clark_2024.jpg',
      seasonLabel: 'GÓLPASSZ / MECCS',
      seasonValue: '8.4',
      primaryLabel: 'HÁRMASOK',
      primaryValue: '122',
      metrics: [
        Metric('PONT', '19.2', 'Újonc szezon'),
        Metric('GÓLPASSZ', '8.4', 'Liga #1'),
        Metric('HÁRMAS', '122', 'Szezon'),
        Metric('LABDASZERZÉS', '1.3', 'Meccsenként'),
      ],
      matches: [
        MatchLine(
          'SZEPT 19',
          'Connecticut Sun',
          'GYŐZELEM',
          '91 – 84',
          '24 PTS · 9 AST · 4 REB',
          'A+',
        ),
        MatchLine(
          'SZEPT 15',
          'Las Vegas Aces',
          'VERESÉG',
          '78 – 86',
          '18 PTS · 11 AST · 5 REB',
          'A',
        ),
        MatchLine(
          'SZEPT 11',
          'Chicago Sky',
          'GYŐZELEM',
          '95 – 89',
          '27 PTS · 8 AST · 6 REB',
          'A+',
        ),
      ],
    ),
    Athlete(
      name: 'Saquon Barkley',
      sport: 'NFL',
      team: 'Philadelphia Eagles',
      country: 'USA',
      accent: Color(0xFF8ED19C),
      photoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/9/9c/Saquon_Barkley_2023.jpg',
      seasonLabel: 'FUTOTT YARD / MECCS',
      seasonValue: '124.5',
      primaryLabel: 'FUTOTT TD',
      primaryValue: '13',
      metrics: [
        Metric('FUTOTT YARD', '2,005', 'Alapszakasz'),
        Metric('CARRY', '345', 'Szezon'),
        Metric('YARD / CARRY', '5.8', 'Elit hatékonyság'),
        Metric('FUTOTT TD', '13', 'Szezon'),
      ],
      matches: [
        MatchLine(
          'JAN 19',
          'L. A. Rams',
          'GYŐZELEM',
          '28 – 22',
          '205 RUSH YDS · 2 TD · 26 carry',
          'A+',
        ),
        MatchLine(
          'JAN 12',
          'Green Bay Packers',
          'GYŐZELEM',
          '22 – 10',
          '119 RUSH YDS · 1 TD · 25 carry',
          'A',
        ),
        MatchLine(
          'JAN 05',
          'New York Giants',
          'GYŐZELEM',
          '20 – 13',
          '96 RUSH YDS · 4 REC · 1 TD',
          'A',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.theme;
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    _playlistFile = File('$appData/courtboard_playlist.json');
    _loadPlaylist();
    _loadLocalState();
  }

  @override
  void dispose() {
    _search.dispose();
    unawaited(_newsRepository.close());
    super.dispose();
  }

  Future<void> _loadLocalState() async {
    final state = await _stateStore.load();
    if (!mounted) return;
    widget.onThemeChanged(state.theme);
    setState(() {
      _notes = state.notes;
      _alerts = state.alerts;
      _apiConfig = SportsApiConfig(
        apiSportsKey: state.apiSportsKey.isNotEmpty
            ? state.apiSportsKey
            : _apiConfig.apiSportsKey,
        balldontlieKey: state.balldontlieKey.isNotEmpty
            ? state.balldontlieKey
            : _apiConfig.balldontlieKey,
        footballDataKey: state.footballDataKey.isNotEmpty
            ? state.footballDataKey
            : _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: state.rapidApiDartsKey.isNotEmpty
            ? state.rapidApiDartsKey
            : _apiConfig.rapidApiDartsKey,
        liveTennisKey: state.liveTennisKey.isNotEmpty
            ? state.liveTennisKey
            : _apiConfig.liveTennisKey,
      );
      _removedAthleteNames = state.removedAthleteNames;
      _overviewSort = state.overviewSort;
      _athleteSort = state.athleteSort;
      _selectedTheme = state.theme;
      _athletes.removeWhere(
        (athlete) => _removedAthleteNames.contains(athlete.name),
      );
      _athletes.addAll(state.customAthletes.map(_customToAthlete));
    });
  }

  Athlete _customToAthlete(CustomAthlete athlete) => Athlete(
    name: athlete.name,
    sport: athlete.sport,
    team: athlete.team,
    country: athlete.country.isEmpty ? 'Ismeretlen' : athlete.country,
    photoUrl: athlete.photoUrl,
    accent: const Color(0xFF9BAF65),
    seasonLabel: '',
    seasonValue: '',
    primaryLabel: 'ADATFORRÁS',
    primaryValue: 'Vár',
    metrics: const [
      Metric('ADAT', '—', 'Provider csatlakoztatása után'),
      Metric('FORMA', '—', 'Még nincs mérkőzés'),
      Metric('RATING', '—', 'Nincs adat'),
      Metric('FRISSÍTVE', '—', 'Helyi profil'),
    ],
    matches: const [],
    isCustom: true,
  );

  Future<void> _saveLocalState() => _stateStore.save(
    CourtboardLocalState(
      notes: _notes,
      alerts: _alerts,
      removedAthleteNames: _removedAthleteNames,
      footballDataKey: _apiConfig.footballDataKey,
      apiSportsKey: _apiConfig.apiSportsKey,
      balldontlieKey: _apiConfig.balldontlieKey,
      rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
      liveTennisKey: _apiConfig.liveTennisKey,
      theme: _selectedTheme,
      overviewSort: _overviewSort,
      athleteSort: _athleteSort,
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
    ),
  );

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
    try {
      if (!await _playlistFile.exists()) return;
      final content = jsonDecode(await _playlistFile.readAsString());
      if (mounted) {
        setState(() => _playlist = AthleteVideoPlaylist.fromJson(content));
      }
    } catch (_) {}
  }

  Future<void> _savePlaylist() =>
      _playlistFile.writeAsString(jsonEncode(_playlist.toJson()));

  void _toggleVideo(SavedYouTubeVideo video) {
    setState(() => _playlist = _playlist.remove(video));
    _savePlaylist();
  }

  void _openAddVideo(Athlete athlete) {
    final input = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('YouTube-videó hozzáadása'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'YouTube link vagy videóazonosító',
              hintText: 'https://youtu.be/… vagy 11 karakteres ID',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () async {
              final id = YouTubeVideoId.parse(input.text);
              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Érvénytelen YouTube-link vagy videóazonosító.',
                    ),
                  ),
                );
                return;
              }
              try {
                final video = await YouTubeOEmbed.resolve(id, athlete.name);
                if (!mounted) return;
                setState(() => _playlist = _playlist.add(video));
                await _savePlaylist();
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A YouTube videócíme most nem kérhető le. Próbáld újra később.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Hozzáadás'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAthlete(Athlete athlete) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sportoló törlése'),
        content: Text(
          'Biztosan törlöd őt a követettek közül?\n\n${athlete.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
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
  }

  @override
  Widget build(BuildContext context) {
    final showingProfile = _openAthlete != null;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _SideRail(
              active: showingProfile ? 0 : _activeNav,
              onSelect: (index) => setState(() {
                _openAthlete = null;
                _activeNav = index;
              }),
            ),
            Expanded(
              child: showingProfile
                  ? _ProfilePage(
                      athlete: _openAthlete!,
                      apiConfig: _apiConfig,
                      videos: _playlist.forAthlete(_openAthlete!.name),
                      note: _notes[_openAthlete!.name] ?? '',
                      alertEnabled: _alerts[_openAthlete!.name] ?? false,
                      onBack: () => setState(() => _openAthlete = null),
                      onToggleClip: _toggleVideo,
                      onAddVideo: () => _openAddVideo(_openAthlete!),
                      onDelete: () => _confirmDeleteAthlete(_openAthlete!),
                      onSaveNote: _setNote,
                      onToggleAlert: _toggleAlert,
                    )
                  : _buildPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() => switch (_activeNav) {
    0 => _Dashboard(
      athletes: _athletes,
      search: _search,
      sort: _overviewSort,
      onOpenSettings: () => setState(() => _activeNav = 6),
      onOpen: (athlete) => setState(() => _openAthlete = athlete),
    ),
    1 => _AthleteDirectory(
      athletes: _athletes,
      sort: _athleteSort,
      onOpen: (athlete) => setState(() => _openAthlete = athlete),
      onAdd: _openAddAthlete,
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
      onOpenAthlete: (athlete) => setState(() => _openAthlete = athlete),
      onRemoveVideo: _toggleVideo,
      onOpenAthletes: () => setState(() => _activeNav = 1),
    ),
    5 => _DataStatusPage(
      config: _apiConfig,
      onSaveFootballKey: _saveFootballKey,
      onSaveApiSportsKey: _saveApiSportsKey,
      onSaveBallDontLieKey: _saveBallDontLieKey,
      onSaveRapidApiDartsKey: _saveRapidApiDartsKey,
      onSaveLiveTennisKey: _saveLiveTennisKey,
    ),
    _ => _SettingsPage(
      theme: _selectedTheme,
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

  void _setOverviewSort(String value) {
    setState(() => _overviewSort = value);
    _saveLocalState();
  }

  void _setAthleteSort(String value) {
    setState(() => _athleteSort = value);
    _saveLocalState();
  }

  void _saveFootballKey(String key) {
    setState(
      () => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: key.trim(),
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: _apiConfig.liveTennisKey,
      ),
    );
    _saveLocalState();
  }

  void _saveApiSportsKey(String key) {
    setState(
      () => _apiConfig = SportsApiConfig(
        apiSportsKey: key.trim(),
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: _apiConfig.liveTennisKey,
      ),
    );
    _saveLocalState();
  }

  void _saveBallDontLieKey(String key) {
    setState(
      () => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: key.trim(),
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: _apiConfig.liveTennisKey,
      ),
    );
    _saveLocalState();
  }

  void _saveRapidApiDartsKey(String key) {
    setState(
      () => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: key.trim(),
        liveTennisKey: _apiConfig.liveTennisKey,
      ),
    );
    _saveLocalState();
  }

  void _saveLiveTennisKey(String key) {
    setState(
      () => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: key.trim(),
      ),
    );
    _saveLocalState();
  }

  void _openAddAthlete() {
    final name = TextEditingController();
    final team = TextEditingController();
    String sport = 'NBA';
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sportoló hozzáadása'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Név'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: sport,
                  decoration: const InputDecoration(labelText: 'Sportág'),
                  items: const ['NBA', 'WNBA', 'Foci', 'Darts', 'Tenisz', 'NFL']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => sport = value ?? sport),
                ),
                if (sport != 'Darts' && sport != 'Tenisz') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: team,
                    decoration: const InputDecoration(
                      labelText: 'Csapat / klub',
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    sport == 'Tenisz'
                        ? 'A teniszezőkhöz nem kell csapatot megadni.'
                        : 'A dartsjátékosokhoz nem kell csapatot megadni.',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'A profilképet a rendszer háttérben próbálja feloldani; sikertelen esetben monogram jelenik meg.',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final imageUrl = await SportsApiClient(
                  config: _apiConfig,
                ).resolveProfileImage(name.text.trim());
                if (!context.mounted) return;
                final athlete = _customToAthlete(
                  CustomAthlete(
                    name: name.text.trim(),
                    sport: sport,
                    team: team.text.trim(),
                    photoUrl: imageUrl ?? '',
                  ),
                );
                setState(() => _athletes.add(athlete));
                _saveLocalState();
                Navigator.pop(context);
              },
              child: const Text('Hozzáadás'),
            ),
          ],
        ),
      ),
    );
  }
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
