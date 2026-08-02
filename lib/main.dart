import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'data/api_sports.dart';
import 'data/basketball_reference.dart';
import 'data/basketball_season.dart';
import 'data/darts.dart';
import 'data/espn_liga_f.dart';
import 'data/football_data.dart';
import 'data/football_season.dart';
import 'data/football_season_repository.dart';
import 'data/local_state.dart';
import 'data/live_tennis.dart';
import 'data/multi_provider.dart';
import 'data/news.dart';
import 'data/provider_catalog.dart';
import 'data/rapidapi_wnba.dart';
import 'data/sports_api.dart';
import 'data/wehoop_wnba.dart';
import 'data/youtube_playlist.dart';
import 'data/youtube_video_id.dart';
import 'news_page.dart';

void main() => runApp(const CourtboardApp());

const _ink = Color(0xFF151815);
const _canvas = Color(0xFFECE9DF);
const _paper = Color(0xFFF9F8F3);
const _olive = Color(0xFFC5D48B);
const _moss = Color(0xFF596B35);
const _burgundy = Color(0xFF7A263A);
const _burgundySoft = Color(0xFFE4B4BD);
const _muted = Color(0xFF73766C);

class Athlete {
  const Athlete({
    required this.name,
    required this.sport,
    required this.team,
    required this.country,
    required this.photoUrl,
    required this.accent,
    required this.seasonLabel,
    required this.seasonValue,
    required this.primaryLabel,
    required this.primaryValue,
    required this.metrics,
    required this.matches,
    this.isCustom = false,
  });

  final String name;
  final String sport;
  final String team;
  final String country;
  final String photoUrl;
  final Color accent;
  final String seasonLabel;
  final String seasonValue;
  final String primaryLabel;
  final String primaryValue;
  final List<Metric> metrics;
  final List<MatchLine> matches;
  final bool isCustom;

  bool get showsTeam =>
      sport != 'Darts' &&
      sport != 'Tenisz' &&
      team.trim().isNotEmpty &&
      team.trim().toLowerCase() != 'nincs megadva';

  String get sportAndTeam => showsTeam ? '$sport · $team' : sport;
}

class Metric {
  const Metric(this.label, this.value, this.note);
  final String label;
  final String value;
  final String note;
}

class MatchLine {
  const MatchLine(this.date, this.opponent, this.result, this.score,
      this.performance, this.grade);
  final String date;
  final String opponent;
  final String result;
  final String score;
  final String performance;
  final String grade;
}

class ClipItem {
  const ClipItem(this.id, this.title, this.meta);
  final String id;
  final String title;
  final String meta;
  String get url => 'https://www.youtube.com/watch?v=$id';
}

class CourtboardApp extends StatefulWidget {
  const CourtboardApp({super.key});

  @override
  State<CourtboardApp> createState() => _CourtboardAppState();
}

class _CourtboardAppState extends State<CourtboardApp> {
  String _theme = 'green';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final state = await LocalStateStore().load();
    if (mounted && state.theme != _theme) {
      setState(() => _theme = state.theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final burgundy = _theme == 'burgundy';
    final seed = burgundy ? _burgundy : _moss;
    final secondary = burgundy ? _burgundySoft : _olive;
    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light)
            .copyWith(primary: seed, secondary: secondary);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Courtboard',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: _canvas,
        colorScheme: scheme,
      ),
      home: CourtboardShell(
          theme: _theme,
          onThemeChanged: (value) => setState(() => _theme = value)),
    );
  }
}

class CourtboardShell extends StatefulWidget {
  const CourtboardShell(
      {super.key, required this.theme, required this.onThemeChanged});
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
        Metric('MEZŐNY', '58.7%', 'Kiemelkedő')
      ],
      matches: [
        MatchLine('JAN 18', 'Phoenix Suns', 'GYŐZELEM', '124 – 111',
            '34 PTS · 14 REB · 8 AST', 'A+'),
        MatchLine('JAN 15', 'Dallas Mavericks', 'GYŐZELEM', '118 – 106',
            '29 PTS · 11 REB · 12 AST', 'A'),
        MatchLine('JAN 12', 'Boston Celtics', 'VERESÉG', '102 – 109',
            '24 PTS · 13 REB · 7 AST', 'B+')
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
        Metric('ÉRTÉKELÉS', '7.84', 'Átlag')
      ],
      matches: [
        MatchLine('JAN 19', 'Real Madrid', 'GYŐZELEM', '2 – 1',
            '1 gól · 2 kulcspassz · 8.7', 'A+'),
        MatchLine('JAN 15', 'Atlético', 'DÖNTETLEN', '1 – 1',
            '1 gólpassz · 92% passz · 7.9', 'A'),
        MatchLine('JAN 10', 'Sevilla', 'GYŐZELEM', '3 – 0',
            '4 szerelés · 5 kulcspassz · 8.3', 'A')
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
        Metric('LEGMAGASABB', '170', 'Checkout')
      ],
      matches: [
        MatchLine('JAN 18', 'M. van Gerwen', 'GYŐZELEM', '10 – 8',
            '101.6 átlag · 7×180 · 46% CO', 'A+'),
        MatchLine('JAN 15', 'G. Price', 'GYŐZELEM', '6 – 3',
            '99.2 átlag · 4×180 · 50% CO', 'A'),
        MatchLine('JAN 10', 'L. Littler', 'VERESÉG', '5 – 6',
            '96.8 átlag · 3×180 · 38% CO', 'B')
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
        Metric('LABDASZERZÉS', '1.3', 'Meccsenként')
      ],
      matches: [
        MatchLine('SZEPT 19', 'Connecticut Sun', 'GYŐZELEM', '91 – 84',
            '24 PTS · 9 AST · 4 REB', 'A+'),
        MatchLine('SZEPT 15', 'Las Vegas Aces', 'VERESÉG', '78 – 86',
            '18 PTS · 11 AST · 5 REB', 'A'),
        MatchLine('SZEPT 11', 'Chicago Sky', 'GYŐZELEM', '95 – 89',
            '27 PTS · 8 AST · 6 REB', 'A+')
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
        Metric('FUTOTT TD', '13', 'Szezon')
      ],
      matches: [
        MatchLine('JAN 19', 'L. A. Rams', 'GYŐZELEM', '28 – 22',
            '205 RUSH YDS · 2 TD · 26 carry', 'A+'),
        MatchLine('JAN 12', 'Green Bay Packers', 'GYŐZELEM', '22 – 10',
            '119 RUSH YDS · 1 TD · 25 carry', 'A'),
        MatchLine('JAN 05', 'New York Giants', 'GYŐZELEM', '20 – 13',
            '96 RUSH YDS · 4 REC · 1 TD', 'A')
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
              : _apiConfig.liveTennisKey);
      _removedAthleteNames = state.removedAthleteNames;
      _overviewSort = state.overviewSort;
      _athleteSort = state.athleteSort;
      _selectedTheme = state.theme;
      _athletes.removeWhere(
          (athlete) => _removedAthleteNames.contains(athlete.name));
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
          Metric('FRISSÍTVE', '—', 'Helyi profil')
        ],
        matches: const [],
        isCustom: true,
      );

  Future<void> _saveLocalState() => _stateStore.save(CourtboardLocalState(
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
            .map((a) => CustomAthlete(
                name: a.name,
                sport: a.sport,
                team: a.team,
                country: a.country,
                photoUrl: a.photoUrl))
            .toList(),
      ));

  void _setNote(Athlete athlete, String value) {
    setState(() => _notes = {..._notes, athlete.name: value});
    _saveLocalState();
  }

  void _toggleAlert(Athlete athlete) {
    setState(() => _alerts = {
          ..._alerts,
          athlete.name: !(_alerts[athlete.name] ?? false)
        });
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
                          hintText:
                              'https://youtu.be/… vagy 11 karakteres ID'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Mégse')),
                FilledButton(
                    onPressed: () async {
                      final id = YouTubeVideoId.parse(input.text);
                      if (id == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Érvénytelen YouTube-link vagy videóazonosító.')));
                        return;
                      }
                      try {
                        final video =
                            await YouTubeOEmbed.resolve(id, athlete.name);
                        if (!mounted) return;
                        setState(() => _playlist = _playlist.add(video));
                        await _savePlaylist();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'A YouTube videócíme most nem kérhető le. Próbáld újra később.')));
                        }
                      }
                    },
                    child: const Text('Hozzáadás')),
              ],
            ));
  }

  void _confirmDeleteAthlete(Athlete athlete) {
    showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Sportoló törlése'),
              content: Text(
                  'Biztosan törlöd őt a követettek közül?\n\n${athlete.name}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Mégse')),
                FilledButton(
                    onPressed: () {
                      setState(() {
                        _removedAthleteNames.add(athlete.name);
                        _athletes
                            .removeWhere((item) => item.name == athlete.name);
                        _openAthlete = null;
                      });
                      _saveLocalState();
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Törlés'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final showingProfile = _openAthlete != null;
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          _SideRail(
              active: showingProfile ? 0 : _activeNav,
              onSelect: (index) => setState(() {
                    _openAthlete = null;
                    _activeNav = index;
                  })),
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
                      onToggleAlert: _toggleAlert)
                  : _buildPage()),
        ]),
      ),
    );
  }

  Widget _buildPage() => switch (_activeNav) {
        0 => _Dashboard(
            athletes: _athletes,
            search: _search,
            sort: _overviewSort,
            onOpenSettings: () => setState(() => _activeNav = 6),
            onOpen: (athlete) => setState(() => _openAthlete = athlete)),
        1 => _AthleteDirectory(
            athletes: _athletes,
            sort: _athleteSort,
            onOpen: (athlete) => setState(() => _openAthlete = athlete),
            onAdd: _openAddAthlete),
        2 => const _CalendarPage(),
        3 => NewsPage(
            repository: _newsRepository,
            athletes: _athletes
                .map((athlete) =>
                    NewsAthleteRef(name: athlete.name, sport: athlete.sport))
                .toList()),
        4 => VideoLibraryPage(
            athletes: _athletes,
            playlist: _playlist,
            onOpenAthlete: (athlete) => setState(() => _openAthlete = athlete),
            onRemoveVideo: _toggleVideo,
            onOpenAthletes: () => setState(() => _activeNav = 1)),
        5 => _DataStatusPage(
            config: _apiConfig,
            onSaveFootballKey: _saveFootballKey,
            onSaveApiSportsKey: _saveApiSportsKey,
            onSaveBallDontLieKey: _saveBallDontLieKey,
            onSaveRapidApiDartsKey: _saveRapidApiDartsKey,
            onSaveLiveTennisKey: _saveLiveTennisKey),
        _ => _SettingsPage(
            theme: _selectedTheme,
            overviewSort: _overviewSort,
            athleteSort: _athleteSort,
            onThemeChanged: _setTheme,
            onOverviewSortChanged: _setOverviewSort,
            onAthleteSortChanged: _setAthleteSort),
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
    setState(() => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: key.trim(),
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: _apiConfig.liveTennisKey));
    _saveLocalState();
  }

  void _saveApiSportsKey(String key) {
    setState(() => _apiConfig = SportsApiConfig(
        apiSportsKey: key.trim(),
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: _apiConfig.liveTennisKey));
    _saveLocalState();
  }

  void _saveBallDontLieKey(String key) {
    setState(() => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: key.trim(),
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: _apiConfig.liveTennisKey));
    _saveLocalState();
  }

  void _saveRapidApiDartsKey(String key) {
    setState(() => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: key.trim(),
        liveTennisKey: _apiConfig.liveTennisKey));
    _saveLocalState();
  }

  void _saveLiveTennisKey(String key) {
    setState(() => _apiConfig = SportsApiConfig(
        apiSportsKey: _apiConfig.apiSportsKey,
        balldontlieKey: _apiConfig.balldontlieKey,
        footballDataKey: _apiConfig.footballDataKey,
        youtubeKey: _apiConfig.youtubeKey,
        rapidApiDartsKey: _apiConfig.rapidApiDartsKey,
        liveTennisKey: key.trim()));
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
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: name,
                            autofocus: true,
                            decoration:
                                const InputDecoration(labelText: 'Név')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: sport,
                            decoration:
                                const InputDecoration(labelText: 'Sportág'),
                            items: const [
                              'NBA',
                              'WNBA',
                              'Foci',
                              'Darts',
                              'Tenisz',
                              'NFL'
                            ]
                                .map((item) => DropdownMenuItem(
                                    value: item, child: Text(item)))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => sport = value ?? sport)),
                        if (sport != 'Darts' && sport != 'Tenisz') ...[
                          const SizedBox(height: 12),
                          TextField(
                              controller: team,
                              decoration: const InputDecoration(
                                  labelText: 'Csapat / klub')),
                        ] else ...[
                          const SizedBox(height: 10),
                          Text(
                              sport == 'Tenisz'
                                  ? 'A teniszezőkhöz nem kell csapatot megadni.'
                                  : 'A dartsjátékosokhoz nem kell csapatot megadni.',
                              style:
                                  const TextStyle(fontSize: 12, color: _muted)),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                            'A profilképet a rendszer háttérben próbálja feloldani; sikertelen esetben monogram jelenik meg.',
                            style: TextStyle(fontSize: 12, color: _muted)),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Mégse')),
                    FilledButton(
                        onPressed: () async {
                          if (name.text.trim().isEmpty) return;
                          final imageUrl =
                              await SportsApiClient(config: _apiConfig)
                                  .resolveProfileImage(name.text.trim());
                          if (!context.mounted) return;
                          final athlete = _customToAthlete(CustomAthlete(
                              name: name.text.trim(),
                              sport: sport,
                              team: team.text.trim(),
                              photoUrl: imageUrl ?? ''));
                          setState(() => _athletes.add(athlete));
                          _saveLocalState();
                          Navigator.pop(context);
                        },
                        child: const Text('Hozzáadás'))
                  ],
                )));
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

class _Dashboard extends StatefulWidget {
  const _Dashboard(
      {required this.athletes,
      required this.search,
      required this.sort,
      required this.onOpenSettings,
      required this.onOpen});
  final List<Athlete> athletes;
  final TextEditingController search;
  final String sort;
  final VoidCallback onOpenSettings;
  final ValueChanged<Athlete> onOpen;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String filter = 'Mind';
  @override
  Widget build(BuildContext context) {
    final list = sortAthletes(
      widget.athletes
          .where((a) =>
              (filter == 'Mind' || a.sport == filter) &&
              (widget.search.text.isEmpty ||
                  a.name
                      .toLowerCase()
                      .contains(widget.search.text.toLowerCase())))
          .toList(),
      widget.sort,
    );
    return Container(
      color: _canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 28, 34, 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(
              search: widget.search,
              onChanged: (_) => setState(() {}),
              onOpenSettings: widget.onOpenSettings),
          const SizedBox(height: 26),
          _WelcomeStrip(
              athlete: widget.athletes.first,
              onOpen: () => widget.onOpen(widget.athletes.first)),
          const SizedBox(height: 32),
          Wrap(
            spacing: 28,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Követett sportolók',
                        style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2)),
                    SizedBox(height: 4),
                    Text('Kattints egy profilra a részletes teljesítményhez.',
                        style: TextStyle(color: _muted))
                  ]),
              Wrap(
                  spacing: 8,
                  children: [
                    'Mind',
                    'NBA',
                    'WNBA',
                    'Foci',
                    'Darts',
                    'Tenisz',
                    'NFL'
                  ]
                      .map((item) => ChoiceChip(
                          label: Text(item),
                          selected: filter == item,
                          selectedColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          side: const BorderSide(color: Color(0xFFCAC7BC)),
                          onSelected: (_) => setState(() => filter = item)))
                      .toList()),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 1180
                ? 4
                : constraints.maxWidth > 820
                    ? 3
                    : 2;
            final gap = 16.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: list
                    .map((athlete) => SizedBox(
                        width: width,
                        child: _AthleteTile(
                            athlete: athlete,
                            onTap: () => widget.onOpen(athlete))))
                    .toList());
          }),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.search,
      required this.onChanged,
      required this.onOpenSettings});
  final TextEditingController search;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Jó reggelt.',
              style: TextStyle(
                  fontSize: 35,
                  height: .9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2)),
          SizedBox(height: 10),
          Text('A te személyes sportközpontod',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w600))
        ])),
        SizedBox(
            width: 310,
            child: TextField(
                controller: search,
                onChanged: onChanged,
                decoration: InputDecoration(
                    hintText: 'Sportoló keresése',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: _paper,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none)))),
        const SizedBox(width: 10),
        _roundIcon(Icons.notifications_none_rounded),
        const SizedBox(width: 8),
        _roundIcon(Icons.settings_outlined,
            onPressed: onOpenSettings,
            tooltip: 'Beállítások',
            key: const Key('overview-settings-button')),
      ]);
}

Widget _roundIcon(IconData icon,
        {VoidCallback? onPressed, String? tooltip, Key? key}) =>
    Container(
        key: key,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9C6BB))),
        child: IconButton(
            onPressed: onPressed,
            tooltip: tooltip,
            icon: Icon(icon, size: 21)));

class _WelcomeStrip extends StatelessWidget {
  const _WelcomeStrip({required this.athlete, required this.onOpen});
  final Athlete athlete;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
        height: 266,
        clipBehavior: Clip.antiAlias,
        decoration:
            BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(30)),
        child: Stack(children: [
          Positioned.fill(
              child: Opacity(
                  opacity: .38,
                  child: Image.network(athlete.photoUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => const SizedBox()))),
          Positioned.fill(
              child: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_ink, Color(0x00151815)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight)))),
          Padding(
              padding: const EdgeInsets.all(28),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text('MAI FÓKUSZ · ${athlete.sport.toUpperCase()}',
                          style: const TextStyle(
                              color: _olive,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4)),
                      const SizedBox(height: 8),
                      Text(athlete.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 39,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2)),
                      const SizedBox(height: 8),
                      Text(
                          athlete.showsTeam
                              ? '${athlete.team} · ${athlete.country}'
                              : athlete.country,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: onOpen,
                          style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 15)),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Profil megnyitása')),
                    ])),
                _HeroStat(
                    value: athlete.seasonValue, label: athlete.seasonLabel),
                const SizedBox(width: 14),
                _HeroStat(
                    value: athlete.primaryValue, label: athlete.primaryLabel),
              ])),
        ]),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      width: 146,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .18))),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7))
          ]));
}

class _AthleteTile extends StatelessWidget {
  const _AthleteTile({required this.athlete, required this.onTap});
  final Athlete athlete;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey('athlete-${athlete.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: _paper, borderRadius: BorderRadius.circular(24)),
            child: Stack(children: [
              Positioned.fill(
                  child: Image.network(athlete.photoUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) =>
                          Container(color: athlete.accent))),
              Positioned.fill(
                  child: const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0x00151815), Color(0xD9151815)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter)))),
              Positioned(
                  top: 15,
                  left: 15,
                  child: _Pill(text: athlete.sport, color: athlete.accent)),
              Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(athlete.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1)),
                        const SizedBox(height: 3),
                        if (athlete.showsTeam)
                          Text(athlete.team,
                              style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 13),
                        Row(children: [
                          if (athlete.seasonValue.isNotEmpty &&
                              athlete.seasonLabel.isNotEmpty) ...[
                            Text('${athlete.seasonValue}  ',
                                style: TextStyle(
                                    color: athlete.accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17)),
                            Expanded(
                                child: Text(athlete.seasonLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                          ] else
                            const Spacer(),
                          const Icon(Icons.arrow_outward,
                              color: Colors.white, size: 20)
                        ])
                      ]))
            ])),
      );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage(
      {required this.athlete,
      required this.apiConfig,
      required this.videos,
      required this.note,
      required this.alertEnabled,
      required this.onBack,
      required this.onToggleClip,
      required this.onAddVideo,
      required this.onDelete,
      required this.onSaveNote,
      required this.onToggleAlert});
  final Athlete athlete;
  final SportsApiConfig apiConfig;
  final List<SavedYouTubeVideo> videos;
  final String note;
  final bool alertEnabled;
  final VoidCallback onBack;
  final ValueChanged<SavedYouTubeVideo> onToggleClip;
  final VoidCallback onAddVideo;
  final VoidCallback onDelete;
  final void Function(Athlete, String) onSaveNote;
  final ValueChanged<Athlete> onToggleAlert;

  @override
  Widget build(BuildContext context) {
    final clips = videos;
    final ligaFProfile = athlete.sport == 'Foci' &&
        (athlete.name.toLowerCase().contains('aitana bonmat') ||
            athlete.team.toLowerCase().contains('femen'));
    return Container(
      color: _canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 24, 34, 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Vissza az áttekintéshez')),
            const Spacer(),
            IconButton(
                tooltip: 'Sportoló törlése',
                onPressed: onDelete,
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFB44646))),
            _Pill(text: 'JÁTÉKOSPROFIL', color: athlete.accent)
          ]),
          const SizedBox(height: 14),
          _ProfileHero(athlete: athlete),
          const SizedBox(height: 14),
          _PersonalTools(
              note: note,
              alertEnabled: alertEnabled,
              onSaveNote: (value) => onSaveNote(athlete, value),
              onToggleAlert: () => onToggleAlert(athlete)),
          if ((athlete.sport == 'Foci' && !ligaFProfile) ||
              athlete.sport == 'NBA' ||
              athlete.sport == 'NFL') ...[
            const SizedBox(height: 18),
            _ApiSportsCard(
                sport: athlete.sport,
                athleteName: athlete.name,
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig),
          ],
          if (athlete.sport == 'Foci' && !ligaFProfile) ...[
            const SizedBox(height: 18),
            _FootballDataCard(
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig),
          ],
          if (ligaFProfile) ...[
            const SizedBox(height: 18),
            _LigaFCard(accent: athlete.accent),
          ],
          if (athlete.sport == 'WNBA') ...[
            const SizedBox(height: 18),
            _WnbaWehoopCard(athleteName: athlete.name, accent: athlete.accent),
            const SizedBox(height: 18),
            _WnbaBasketballReferenceCard(
                athleteName: athlete.name, accent: athlete.accent),
            const SizedBox(height: 18),
            _WnbaRapidApiCard(
                athleteName: athlete.name,
                accent: athlete.accent,
                config: apiConfig),
          ],
          if (athlete.sport == 'NBA') ...[
            const SizedBox(height: 22),
            _NbaSeasonSummaryCard(
                athleteName: athlete.name, accent: athlete.accent),
          ],
          if (athlete.sport == 'Darts') ...[
            const SizedBox(height: 18),
            _DartsDataCard(
                athleteName: athlete.name,
                accent: athlete.accent,
                config: apiConfig),
          ],
          if (athlete.sport == 'Tenisz') ...[
            const SizedBox(height: 18),
            _TennisDataCard(
                athleteName: athlete.name,
                accent: athlete.accent,
                config: apiConfig),
          ],
          if (athlete.sport == 'Foci') ...[
            const SizedBox(height: 22),
            _FootballSeasonSummaryCard(
                athleteName: athlete.name,
                teamName: athlete.team,
                accent: athlete.accent,
                config: apiConfig),
            const SizedBox(height: 28),
          ] else if (athlete.sport != 'WNBA' &&
              athlete.sport != 'NBA' &&
              athlete.sport != 'Tenisz') ...[
            const SizedBox(height: 22),
            const Text('Szezon összesítő',
                style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final w = (constraints.maxWidth - 48) / 4;
              return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: athlete.metrics
                      .map((metric) => SizedBox(
                          width: w,
                          child: _MetricCard(
                              metric: metric, accent: athlete.accent)))
                      .toList());
            }),
            const SizedBox(height: 28),
            _SportTemplate(athlete: athlete),
            if (athlete.sport != 'NBA' && !ligaFProfile) ...[
              const SizedBox(height: 28),
              const Text('Utóbbi mérkőzések',
                  style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2)),
              const SizedBox(height: 6),
              const Text(
                  'Egységes mérkőzés-sablon: eredmény, sportág szerinti teljesítmény, értékelés.',
                  style: TextStyle(color: _muted)),
              const SizedBox(height: 12),
              ...athlete.matches.map(
                  (match) => _MatchRow(match: match, accent: athlete.accent)),
            ],
            const SizedBox(height: 28),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Videók és saját playlist',
                style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2)),
            Row(children: [
              Text('${videos.length} mentett videó',
                  style: const TextStyle(color: _muted)),
              const SizedBox(width: 10),
              FilledButton.icon(
                  onPressed: onAddVideo,
                  icon: const Icon(Icons.add),
                  label: const Text('Videó hozzáadása')),
            ]),
          ]),
          const SizedBox(height: 12),
          if (clips.isEmpty)
            const Text(
                'Még nincs mentett videó. A „Videó hozzáadása” gombbal illessz be egy YouTube-linket vagy videóazonosítót.',
                style: TextStyle(color: _muted))
          else
            Wrap(
                spacing: 16,
                runSpacing: 16,
                children: clips
                    .map((video) => _ClipCard(
                        video: video, onRemove: () => onToggleClip(video)))
                    .toList()),
        ]),
      ),
    );
  }
}

class _ApiSportsCard extends StatefulWidget {
  const _ApiSportsCard(
      {required this.sport,
      required this.athleteName,
      required this.teamName,
      required this.accent,
      required this.config});
  final String sport;
  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;
  @override
  State<_ApiSportsCard> createState() => _ApiSportsCardState();
}

class _ApiSportsCardState extends State<_ApiSportsCard> {
  late Future<Object> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ApiSportsRepository(widget.config.apiSportsKey);
    _data = switch (widget.sport) {
      'Foci' => repo.footballRecent(widget.teamName),
      'NBA' => MultiProviderAthleteRepository(widget.config)
          .fetchNbaPlayer(widget.athleteName),
      _ => repo.nflPlayer(widget.athleteName)
    };
  }

  @override
  void didUpdateWidget(covariant _ApiSportsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.teamName != widget.teamName ||
        oldWidget.config.apiSportsKey != widget.config.apiSportsKey ||
        oldWidget.config.balldontlieKey != widget.config.balldontlieKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Object>(
      future: _data,
      builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: .35))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                  widget.sport == 'NBA'
                      ? 'VALÓS NBA ADAT · EGYESÍTETT FORRÁSOK'
                      : 'VALÓS ${widget.sport.toUpperCase()} ADAT · API-SPORTS',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: widget.accent)),
              const Spacer(),
              IconButton(
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh))
            ]),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator())
            else if (snapshot.hasError)
              Text('${snapshot.error}',
                  style: const TextStyle(color: Colors.red))
            else if (snapshot.data is List<ApiSportsGame>)
              ...((snapshot.data as List<ApiSportsGame>).map((game) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                      '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')} · ${game.opponent} · ${game.score} · ${game.result}'))))
            else if (snapshot.data is UnifiedAthleteData)
              UnifiedAthleteFacts(
                  data: snapshot.data as UnifiedAthleteData,
                  accent: widget.accent)
            else
              Text(
                  '${widget.athleteName}: a szolgáltató nem adott megjeleníthető adatot.')
          ])));
}

class _NbaSeasonSummaryCard extends StatefulWidget {
  const _NbaSeasonSummaryCard({
    required this.athleteName,
    required this.accent,
  });

  final String athleteName;
  final Color accent;

  @override
  State<_NbaSeasonSummaryCard> createState() => _NbaSeasonSummaryCardState();
}

class _NbaSeasonSummaryCardState extends State<_NbaSeasonSummaryCard> {
  late Future<BasketballSeasonStat?> _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summary =
        BasketballReferenceRepository().seasonSummary(widget.athleteName);
  }

  @override
  void didUpdateWidget(covariant _NbaSeasonSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName) _load();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
                child: Text('Szezon összesítő',
                    style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2))),
            IconButton(
                tooltip: 'Szezonadatok frissítése',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          FutureBuilder<BasketballSeasonStat?>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _BasketballSeasonMessage(
                    message: 'NBA szezonadatok betöltése…',
                    accent: widget.accent,
                    loading: true);
              }
              if (snapshot.hasError) {
                return _BasketballSeasonMessage(
                    message:
                        'A friss NBA szezonösszesítő most nem érhető el: ${snapshot.error}',
                    accent: widget.accent);
              }
              final summary = snapshot.data;
              if (summary == null) {
                return _BasketballSeasonMessage(
                    message: 'Ehhez a játékoshoz nincs friss NBA szezonadat.',
                    accent: widget.accent);
              }
              return BasketballSeasonSummaryFacts(
                  summary: summary, accent: widget.accent);
            },
          ),
          const SizedBox(height: 28),
        ],
      );
}

class _BasketballSeasonMessage extends StatelessWidget {
  const _BasketballSeasonMessage({
    required this.message,
    required this.accent,
    this.loading = false,
  });

  final String message;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: .35))),
        child: Row(children: [
          if (loading) ...[
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(message, style: const TextStyle(color: _muted))),
        ]),
      );
}

class BasketballSeasonSummaryFacts extends StatelessWidget {
  const BasketballSeasonSummaryFacts({
    super.key,
    required this.summary,
    required this.accent,
  });

  final BasketballSeasonStat summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('MÉRKŐZÉS', '${summary.games}'),
      ('PERC / MECCS', _decimal(summary.minutesPerGame)),
      ('PONT / MECCS', _decimal(summary.pointsPerGame)),
      ('LEPATTANÓ / MECCS', _decimal(summary.reboundsPerGame)),
      ('ASSZISZT / MECCS', _decimal(summary.assistsPerGame)),
      ('LABDASZERZÉS / MECCS', _decimal(summary.stealsPerGame)),
      ('ELADOTT LABDA / MECCS', _decimal(summary.turnoversPerGame)),
      ('FG%', _percentage(summary.fieldGoalPercentage)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: .45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(summary.team.isEmpty ? summary.league : summary.team,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${summary.league} · ${summary.season}',
                    style: const TextStyle(color: _muted)),
              ])),
          _Pill(text: summary.source.toUpperCase(), color: accent),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000 ? 8 : 4;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metrics
                  .map((metric) => SizedBox(
                      width: width,
                      child: _BasketballSeasonMetric(
                          label: metric.$1, value: metric.$2, accent: accent)))
                  .toList());
        }),
      ]),
    );
  }

  static String _decimal(double? value) =>
      value == null ? '—' : value.toStringAsFixed(1);
  static String _percentage(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}%';
}

class _BasketballSeasonMetric extends StatelessWidget {
  const _BasketballSeasonMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: accent.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: _muted, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _FootballSeasonSummaryCard extends StatefulWidget {
  const _FootballSeasonSummaryCard({
    required this.athleteName,
    required this.teamName,
    required this.accent,
    required this.config,
  });

  final String athleteName;
  final String teamName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_FootballSeasonSummaryCard> createState() =>
      _FootballSeasonSummaryCardState();
}

class _FootballSeasonSummaryCardState
    extends State<_FootballSeasonSummaryCard> {
  late Future<List<FootballSeasonStat>> _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _stats = FootballSeasonRepository(widget.config)
        .fetch(widget.athleteName, widget.teamName);
  }

  @override
  void didUpdateWidget(covariant _FootballSeasonSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.teamName != widget.teamName ||
        oldWidget.config.apiSportsKey != widget.config.apiSportsKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Szezon összesítő',
                style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2)),
            const Spacer(),
            IconButton(
                tooltip: 'Szezonadatok frissítése',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          FutureBuilder<List<FootballSeasonStat>>(
              future: _stats,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _FootballSeasonMessage(
                      message:
                          'Nem érkezett friss szezonadat: ${snapshot.error}',
                      accent: widget.accent);
                }
                final stats = snapshot.data ?? const [];
                if (stats.isEmpty) {
                  return _FootballSeasonMessage(
                      message:
                          'Az aktuális vagy előző szezonhoz nincs elérhető adat.',
                      accent: widget.accent);
                }
                return Column(
                    children: stats
                        .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FootballSeasonStatCard(
                                stat: item, accent: widget.accent)))
                        .toList());
              }),
        ],
      );
}

class _FootballSeasonMessage extends StatelessWidget {
  const _FootballSeasonMessage({required this.message, required this.accent});
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: .35))),
      child: Text(message, style: const TextStyle(color: _muted)));
}

class _FootballSeasonStatCard extends StatelessWidget {
  const _FootballSeasonStatCard({required this.stat, required this.accent});
  final FootballSeasonStat stat;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('ÉRTÉKELÉS ÁTLAG', stat.rating?.toStringAsFixed(2) ?? '—'),
      ('MÉRKŐZÉS', _format(stat.appearances)),
      ('GÓL', _format(stat.goals)),
      ('GÓLPASSZ', _format(stat.assists)),
      ('SÁRGA LAP', _format(stat.yellowCards)),
      ('PIROS LAP', _format(stat.redCards)),
    ];
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: .42))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(stat.team,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${stat.competition} · ${stat.season}',
                      style: const TextStyle(color: _muted)),
                ])),
            _Pill(text: stat.source.toUpperCase(), color: accent),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 6 : 3;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map((metric) => Container(
                        width: width,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(metric.$1,
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 7),
                              Text(metric.$2,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                            ])))
                    .toList());
          }),
        ]));
  }

  static String _format(int? value) => value?.toString() ?? '—';
}

class UnifiedAthleteFacts extends StatelessWidget {
  const UnifiedAthleteFacts(
      {super.key, required this.data, required this.accent});

  final UnifiedAthleteData data;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.providers.map((provider) {
                final color = provider.hasData
                    ? _moss
                    : provider.configured
                        ? Colors.red.shade400
                        : Colors.orange.shade600;
                return Tooltip(
                    message: provider.message ?? 'Adat érkezett',
                    child: Chip(
                        avatar: Icon(
                            provider.hasData
                                ? Icons.check_circle
                                : provider.configured
                                    ? Icons.error_outline
                                    : Icons.key_off,
                            size: 17,
                            color: color),
                        label: Text(provider.name),
                        side: BorderSide(color: color.withValues(alpha: .45)),
                        backgroundColor: color.withValues(alpha: .08)));
              }).toList()),
          const SizedBox(height: 12),
          if (data.facts.isEmpty)
            const Text(
                'Egyik beállított szolgáltató sem talált ilyen nevű NBA-játékost.',
                style: TextStyle(color: Colors.red))
          else
            Wrap(
                spacing: 12,
                runSpacing: 12,
                children: data.facts
                    .map((fact) => Container(
                        width: 190,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fact.label.toUpperCase(),
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(fact.value,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(fact.source,
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ])))
                    .toList()),
          const SizedBox(height: 18),
          BasketballReferenceGameList(
              games: data.games, accent: accent, league: 'NBA'),
        ],
      );
}

class BasketballReferenceGameList extends StatelessWidget {
  const BasketballReferenceGameList(
      {super.key,
      required this.games,
      required this.accent,
      required this.league});

  final List<NbaGameLog> games;
  final Color accent;
  final String league;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.sports_basketball, color: accent, size: 20),
            const SizedBox(width: 8),
            Text('LEGUTÓBBI $league MECCSEK · BASKETBALL REFERENCE',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          if (games.isEmpty)
            Text(
                'A Basketball Reference nem adott friss $league játékos-box score-t.',
                style: const TextStyle(color: _muted))
          else
            ...games.map((game) => _MatchRow(
                accent: accent,
                match: MatchLine(
                  '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')}',
                  game.opponent,
                  game.resultLabel,
                  game.score ?? (game.location == 'HOME' ? 'HAZAI' : 'IDEGEN'),
                  game.performance,
                  game.grade,
                ))),
        ],
      );
}

class _FootballDataCard extends StatefulWidget {
  const _FootballDataCard(
      {required this.teamName, required this.accent, required this.config});
  final String teamName;
  final Color accent;
  final SportsApiConfig config;
  @override
  State<_FootballDataCard> createState() => _FootballDataCardState();
}

class _FootballDataCardState extends State<_FootballDataCard> {
  late Future<List<FootballGame>> _games;
  @override
  void initState() {
    super.initState();
    _games = FootballDataRepository(SportsApiClient(config: widget.config))
        .fetchRecentTeamGames(widget.teamName);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<FootballGame>>(
        future: _games,
        builder: (context, snapshot) => Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.accent.withValues(alpha: .7))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LEGUTÓBBI CSAPATMÉRKŐZÉSEK · FOOTBALL-DATA.ORG',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 5),
              Text('${widget.teamName} · valódi eredmények',
                  style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Text('Mérkőzések lekérése…')
              else if (snapshot.hasError)
                Text('Football-data.org hiba: ${snapshot.error}',
                    style: const TextStyle(color: _muted))
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                const Text(
                    'Nincs támogatott csapatazonosító vagy befejezett mérkőzés.',
                    style: TextStyle(color: _muted))
              else
                ...snapshot.data!.map((game) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')} · vs. ${game.opponent}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      Text(game.score,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Text(
                          game.result == FootballResult.win
                              ? 'GY'
                              : game.result == FootballResult.loss
                                  ? 'V'
                                  : 'D',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: game.result == FootballResult.win
                                  ? _olive
                                  : game.result == FootballResult.loss
                                      ? const Color(0xFFB44646)
                                      : _muted))
                    ]))),
            ])),
      );
}

class _LigaFCard extends StatefulWidget {
  const _LigaFCard({required this.accent});
  final Color accent;

  @override
  State<_LigaFCard> createState() => _LigaFCardState();
}

class _LigaFCardState extends State<_LigaFCard> {
  late Future<List<LigaFGame>> _games;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _games = LigaFRepository().recentBarcelonaGames();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<LigaFGame>>(
        future: _games,
        builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: .7))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.sports_soccer, color: widget.accent),
                const SizedBox(width: 9),
                const Expanded(
                    child: Text('FC BARCELONA FEMENÍ · LIGA F',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: .5))),
                const _Pill(text: 'ESPN · esp.w.1', color: _moss),
                IconButton(
                    tooltip: 'Újratöltés',
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh)),
              ]),
              const SizedBox(height: 5),
              const Text(
                  'Valós női Barcelona csapateredmények; nem a férfi FC Barcelona feedje.',
                  style: TextStyle(fontSize: 11, color: _muted)),
              const SizedBox(height: 14),
              if (snapshot.connectionState != ConnectionState.done)
                const CircularProgressIndicator()
              else if (snapshot.hasError)
                Text('ESPN Liga F hiba: ${snapshot.error}',
                    style: const TextStyle(color: _muted))
              else if (snapshot.data == null || snapshot.data!.isEmpty)
                const Text('Nincs befejezett Barcelona-meccs ebben az évben.',
                    style: TextStyle(color: _muted))
              else
                LigaFGameList(games: snapshot.data!, accent: widget.accent),
            ],
          ),
        ),
      );
}

class LigaFGameList extends StatelessWidget {
  const LigaFGameList({super.key, required this.games, required this.accent});
  final List<LigaFGame> games;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
      children: games
          .map((game) => _MatchRow(
              accent: accent,
              match: MatchLine(
                  '${game.date.year}.${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')}',
                  game.opponent,
                  game.result,
                  game.score,
                  game.home ? 'HAZAI · LIGA F' : 'IDEGEN · LIGA F',
                  '—')))
          .toList());
}

class _TennisDataCard extends StatefulWidget {
  const _TennisDataCard(
      {required this.athleteName, required this.accent, required this.config});

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_TennisDataCard> createState() => _TennisDataCardState();
}

class _TennisDataCardState extends State<_TennisDataCard> {
  Future<TennisProfileData>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool force = false}) {
    _data = widget.config.liveTennisKey.trim().isEmpty
        ? null
        : TennisRepository(widget.config)
            .fetch(widget.athleteName, forceRefresh: force);
  }

  @override
  void didUpdateWidget(covariant _TennisDataCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.config.liveTennisKey != widget.config.liveTennisKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accent.withValues(alpha: .7))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.sports_tennis_rounded, color: widget.accent),
            const SizedBox(width: 9),
            const Expanded(
                child: Text('ÉLŐ TENISZADAT · LIVE TENNIS API',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: .5))),
            _DartsProviderChip(
                name: 'Live Tennis API',
                ready: _data != null,
                configured: _data != null,
                message: _data == null
                    ? 'A kulcs az Adatforrások oldalon adható meg'
                    : 'Free: játékos, ranglista, élő és közelgő meccsek'),
            IconButton(
                tooltip: 'Frissítés az API-ból',
                onPressed: _data == null
                    ? null
                    : () => setState(() => _load(force: true)),
                icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 8),
          if (_data == null)
            const Text(
                'Add meg a Live Tennis API ingyenes kulcsát az Adatforrások oldalon. Ezután a profil automatikusan megkapja a ranglistát, az élő állást és a következő mérkőzéseket.',
                style: TextStyle(color: _muted))
          else
            FutureBuilder<TennisProfileData>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(children: [
                        SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Teniszprofil és aktuális meccsek betöltése…')
                      ]));
                }
                if (snapshot.hasError) {
                  return Text('Live Tennis API hiba: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red));
                }
                return TennisProfileFacts(
                    data: snapshot.data!, accent: widget.accent);
              },
            ),
        ]),
      );
}

class TennisProfileFacts extends StatelessWidget {
  const TennisProfileFacts(
      {super.key, required this.data, required this.accent});

  final TennisProfileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final facts = <(String, String)>[
      if (player.ranking != null) ('RANGLISTA', '#${player.ranking}'),
      if (player.rankingPoints != null)
        ('RANGLISTAPONT', '${player.rankingPoints}'),
      if (player.tour != null) ('SOROZAT', player.tour!.toUpperCase()),
      if (player.country != null) ('ORSZÁG', player.country!),
      if (player.hand != null)
        ('ÜTŐKÉZ', player.hand == 'L' ? 'Balkezes' : 'Jobbkezes'),
      if (player.backhand != null)
        ('FONÁK', player.backhand == 1 ? 'Egykezes' : 'Kétkezes'),
      if (player.birthday != null) ('SZÜLETETT', _tennisDate(player.birthday)),
    ];
    final usage = data.usage;
    final usageText = usage == null
        ? null
        : usage.today != null && usage.dailyLimit != null
            ? '${usage.tier} · ma ${usage.today}/${usage.dailyLimit} kérés'
            : '${usage.tier} csomag';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(player.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900))),
        if (usageText != null)
          _Pill(text: usageText.toUpperCase(), color: accent),
      ]),
      const SizedBox(height: 12),
      Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facts
              .map((fact) => Container(
                    width: 170,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fact.$1,
                              style: const TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(fact.$2,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900)),
                        ]),
                  ))
              .toList()),
      const SizedBox(height: 20),
      const Text('ÉLŐ MÉRKŐZÉS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4)),
      const SizedBox(height: 8),
      if (data.liveMatches.isEmpty)
        const Text('A játékosnak most nincs élő mérkőzése.',
            style: TextStyle(color: _muted))
      else
        ...data.liveMatches.map((match) => _TennisMatchTile(
            opponent: match.opponentOf(player),
            tournament: match.tournament,
            detail: match.score?.summary ?? 'Élő mérkőzés',
            date: match.scheduledTime,
            surface: match.surface,
            accent: accent,
            live: true)),
      const SizedBox(height: 18),
      const Text('KÖVETKEZŐ MÉRKŐZÉSEK',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4)),
      const SizedBox(height: 8),
      if (data.upcomingMatches.isEmpty && data.fixtures.isEmpty)
        const Text('Most nincs a játékoshoz kapcsolható közelgő mérkőzés.',
            style: TextStyle(color: _muted))
      else ...[
        ...data.upcomingMatches.take(5).map((match) => _TennisMatchTile(
            opponent: match.opponentOf(player),
            tournament: match.tournament,
            detail: match.round ?? 'Közelgő mérkőzés',
            date: match.scheduledTime,
            surface: match.surface,
            accent: accent)),
        if (data.upcomingMatches.length < 5)
          ...data.fixtures.take(5 - data.upcomingMatches.length).map(
              (fixture) => _TennisMatchTile(
                  opponent: fixture.opponentOf(player),
                  tournament: fixture.tournament,
                  detail: fixture.round ?? 'Közelgő mérkőzés',
                  date: fixture.eventDate,
                  surface: fixture.surface,
                  accent: accent)),
      ],
      const SizedBox(height: 14),
      const Text(
          'A Free csomag élő és közelgő adatokat biztosít. A befejezett meccselőzmények és a pontonkénti történet fizetős History hozzáférést igényelnek.',
          style: TextStyle(fontSize: 11, color: _muted)),
    ]);
  }
}

class _TennisMatchTile extends StatelessWidget {
  const _TennisMatchTile(
      {required this.opponent,
      required this.tournament,
      required this.detail,
      required this.accent,
      this.date,
      this.surface,
      this.live = false});

  final String opponent;
  final String tournament;
  final String detail;
  final Color accent;
  final DateTime? date;
  final String? surface;
  final bool live;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
            color:
                live ? accent.withValues(alpha: .13) : const Color(0xFFF1EFE8),
            borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: live ? Colors.red : accent, shape: BoxShape.circle)),
          const SizedBox(width: 11),
          SizedBox(
              width: 105,
              child: Text(live ? 'ÉLŐ' : _tennisDate(date),
                  style: TextStyle(
                      color: live ? Colors.red : _muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 11))),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('vs. $opponent',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                    [tournament, if (surface != null) surface!.toUpperCase()]
                        .join(' · '),
                    style: const TextStyle(fontSize: 11, color: _muted)),
              ])),
          const SizedBox(width: 12),
          Flexible(
              child: Text(detail,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );
}

String _tennisDate(DateTime? date) => date == null
    ? 'Időpont később'
    : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _DartsDataCard extends StatefulWidget {
  const _DartsDataCard(
      {required this.athleteName, required this.accent, required this.config});

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_DartsDataCard> createState() => _DartsDataCardState();
}

class _DartsDataCardState extends State<_DartsDataCard> {
  late Future<DartsProfileData> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = DartsRepository(widget.config).fetch(widget.athleteName);
  }

  @override
  void didUpdateWidget(covariant _DartsDataCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.config.rapidApiDartsKey != widget.config.rapidApiDartsKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DartsProfileData>(
        future: _data,
        builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: .7))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.adjust_rounded, color: widget.accent),
                const SizedBox(width: 9),
                const Expanded(
                    child: Text('VALÓS DARTS ADAT · EGYESÍTETT FORRÁSOK',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: .5))),
                IconButton(
                    tooltip: 'Újratöltés',
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh)),
              ]),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator())
              else if (snapshot.hasError)
                Text('Darts adatforrás hiba: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red))
              else
                DartsProfileFacts(data: snapshot.data!, accent: widget.accent),
            ],
          ),
        ),
      );
}

class DartsProfileFacts extends StatelessWidget {
  const DartsProfileFacts(
      {super.key, required this.data, required this.accent});

  final DartsProfileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final facts = <(String, String)>[
      if (player?['strPlayer'] != null) ('NÉV', '${player!['strPlayer']}'),
      if (player?['strTeam'] != null) ('SOROZAT', '${player!['strTeam']}'),
      if (player?['strNationality'] != null)
        ('NEMZETISÉG', '${player!['strNationality']}'),
      if (player?['dateBorn'] != null) ('SZÜLETETT', '${player!['dateBorn']}'),
      if (player?['strStatus'] != null) ('STÁTUSZ', '${player!['strStatus']}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _DartsProviderChip(
            name: 'TheSportsDB',
            ready: player != null,
            message: data.theSportsDbError ??
                (player == null ? 'Nincs találat' : 'Profil és eredmények')),
        _DartsProviderChip(
            name: 'RapidAPI · Darts API',
            ready: data.competitions.isNotEmpty,
            configured: data.rapidApiConfigured,
            message: data.rapidApiError ??
                (data.rapidApiConfigured
                    ? 'Verseny- és eseményfeed'
                    : 'RAPIDAPI_DARTS_KEY nincs beállítva')),
      ]),
      const SizedBox(height: 14),
      if (facts.isEmpty)
        const Text('A TheSportsDB nem talált ilyen dartsjátékost.',
            style: TextStyle(color: _muted))
      else
        Wrap(
            spacing: 10,
            runSpacing: 10,
            children: facts
                .map((fact) => Container(
                    width: 175,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fact.$1,
                              style: const TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(fact.$2,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900)),
                        ])))
                .toList()),
      const SizedBox(height: 20),
      const Text('LEGUTÓBBI DARTS EREDMÉNYEK · THESPORTSDB',
          style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (data.results.isEmpty)
        const Text('Nem érkezett játékoshoz kötött eredmény.',
            style: TextStyle(color: _muted))
      else
        ...data.results.map((result) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(
                    width: 92,
                    child: Text(
                        '${result.date.year}.${result.date.month.toString().padLeft(2, '0')}.${result.date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(
                    child: Text(result.event,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(result.detail == 'WIN' ? 'GYŐZELEM' : result.detail,
                    style: TextStyle(
                        color: result.detail == 'WIN' ? _moss : _muted,
                        fontWeight: FontWeight.w900)),
              ]),
            )),
      const SizedBox(height: 18),
      const Text('RAPIDAPI VERSENYFEED',
          style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text(
          'A Sportbex API ezen csomagja versenyeket, eseményeket, piacokat és oddsokat ad; játékosstatisztikát nem.',
          style: TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 8),
      if (!data.rapidApiConfigured)
        const Text('A RapidAPI darts kulcs az Adatforrások oldalon adható meg.',
            style: TextStyle(color: _muted))
      else if (data.competitions.isEmpty)
        Text(data.rapidApiError ?? 'Most nincs elérhető verseny.',
            style: const TextStyle(color: _muted))
      else
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.competitions
                .map((competition) => Chip(label: Text(competition.name)))
                .toList()),
    ]);
  }
}

class _DartsProviderChip extends StatelessWidget {
  const _DartsProviderChip(
      {required this.name,
      required this.ready,
      required this.message,
      this.configured = true});

  final String name;
  final bool ready;
  final bool configured;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? _moss
        : configured
            ? Colors.red.shade400
            : Colors.orange.shade600;
    return Tooltip(
        message: message,
        child: Chip(
            avatar: Icon(
                ready
                    ? Icons.check_circle
                    : configured
                        ? Icons.error_outline
                        : Icons.key_off,
                size: 17,
                color: color),
            label: Text(name),
            side: BorderSide(color: color.withValues(alpha: .45)),
            backgroundColor: color.withValues(alpha: .08)));
  }
}

class _WnbaWehoopCard extends StatefulWidget {
  const _WnbaWehoopCard({required this.athleteName, required this.accent});
  final String athleteName;
  final Color accent;

  @override
  State<_WnbaWehoopCard> createState() => _WnbaWehoopCardState();
}

class _WnbaWehoopCardState extends State<_WnbaWehoopCard> {
  late Future<List<WnbaGameLog>> _games;
  int _range = 5;

  @override
  void initState() {
    super.initState();
    _games = WnbaWehoopRepository().recentGames(widget.athleteName);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WnbaGameLog>>(
      future: _games,
      builder: (context, snapshot) {
        final child = switch (snapshot.connectionState) {
          ConnectionState.waiting => const Row(children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('WNBA box score-ok letöltése és helyi gyorsítótárazása…')
            ]),
          _ when snapshot.hasError => const Text(
              'A wehoop WNBA-adat most nem érhető el. A cache vagy a hálózat később újrapróbálható.',
              style: TextStyle(color: _muted)),
          _ when snapshot.data == null || snapshot.data!.isEmpty => const Text(
              'Ehhez a játékoshoz nem érkezett 2026-os wehoop box score rekord.',
              style: TextStyle(color: _muted)),
          _ => _WnbaLiveData(
              games: snapshot.data!,
              range: _range,
              accent: widget.accent,
              onRange: (value) => setState(() => _range = value),
            ),
        };
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: .7))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.data_usage_rounded, color: widget.accent),
              const SizedBox(width: 9),
              const Expanded(
                  child: Text('VALÓS WNBA MECCSNAPLÓ',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: .6))),
              const _Pill(text: 'WEHOOP · ESPN', color: _olive)
            ]),
            const SizedBox(height: 6),
            const Text(
                'SportsDataverse / wehoop WNBA player boxscores · CC BY 4.0',
                style: TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(height: 15),
            child,
          ]),
        );
      });
}

class _WnbaBasketballReferenceCard extends StatefulWidget {
  const _WnbaBasketballReferenceCard(
      {required this.athleteName, required this.accent});

  final String athleteName;
  final Color accent;

  @override
  State<_WnbaBasketballReferenceCard> createState() =>
      _WnbaBasketballReferenceCardState();
}

class _WnbaBasketballReferenceCardState
    extends State<_WnbaBasketballReferenceCard> {
  late Future<List<NbaGameLog>> _games;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _games = BasketballReferenceRepository()
        .recentGames(widget.athleteName, league: 'wnba');
  }

  @override
  void didUpdateWidget(covariant _WnbaBasketballReferenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NbaGameLog>>(
        future: _games,
        builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: .7))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('WNBA KIEGÉSZÍTŐ ADATFORRÁS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: .6))),
                IconButton(
                    tooltip: 'Újratöltés',
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh)),
              ]),
              const Text(
                  'A wehoop mellett közvetlen Basketball Reference játékos-meccsnapló.',
                  style: TextStyle(fontSize: 11, color: _muted)),
              const SizedBox(height: 15),
              if (snapshot.connectionState != ConnectionState.done)
                const Row(children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Basketball Reference WNBA-adatok letöltése…'),
                ])
              else if (snapshot.hasError)
                Text('Basketball Reference WNBA hiba: ${snapshot.error}',
                    style: const TextStyle(color: _muted))
              else
                BasketballReferenceGameList(
                    games: snapshot.data ?? const [],
                    accent: widget.accent,
                    league: 'WNBA'),
            ],
          ),
        ),
      );
}

class _WnbaRapidApiCard extends StatefulWidget {
  const _WnbaRapidApiCard(
      {required this.athleteName, required this.accent, required this.config});

  final String athleteName;
  final Color accent;
  final SportsApiConfig config;

  @override
  State<_WnbaRapidApiCard> createState() => _WnbaRapidApiCardState();
}

class _WnbaRapidApiCardState extends State<_WnbaRapidApiCard> {
  late Future<WnbaRapidProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile =
        WnbaRapidApiRepository(widget.config).playerProfile(widget.athleteName);
  }

  @override
  void didUpdateWidget(covariant _WnbaRapidApiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteName != widget.athleteName ||
        oldWidget.config.rapidApiDartsKey != widget.config.rapidApiDartsKey) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WnbaRapidProfile?>(
        future: _profile,
        builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withValues(alpha: .7))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.analytics_outlined, color: widget.accent),
                const SizedBox(width: 9),
                const Expanded(
                    child: Text('WNBA PLAYER BIO ÉS ADVANCED STATISTICS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: .4))),
                const _Pill(text: 'RAPIDAPI · 7 NAP CACHE', color: _moss),
                IconButton(
                    tooltip: 'Újratöltés',
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh)),
              ]),
              const SizedBox(height: 12),
              if (widget.config.rapidApiDartsKey.isEmpty)
                const Text('A RapidAPI-kulcs nincs beállítva.',
                    style: TextStyle(color: _muted))
              else if (snapshot.connectionState != ConnectionState.done)
                const Row(children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('WNBA játékosadatok betöltése…'),
                ])
              else if (snapshot.hasError)
                Text('RapidAPI WNBA hiba: ${snapshot.error}',
                    style: const TextStyle(color: _muted))
              else if (snapshot.data == null)
                const Text('A játékos ESPN-azonosítója nem található.',
                    style: TextStyle(color: _muted))
              else
                WnbaRapidProfileFacts(
                    profile: snapshot.data!, accent: widget.accent),
            ],
          ),
        ),
      );
}

class WnbaRapidProfileFacts extends StatelessWidget {
  const WnbaRapidProfileFacts(
      {super.key, required this.profile, required this.accent});

  final WnbaRapidProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${profile.team ?? 'WNBA'} · ${profile.season ?? 'aktuális szezon'} · ESPN ID ${profile.playerId}',
              style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 9,
              runSpacing: 9,
              children: profile.facts
                  .map((fact) => Container(
                      width: 92,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(11)),
                      child: Column(children: [
                        Text(fact.value,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(fact.label,
                            style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ])))
                  .toList()),
          if (profile.awards.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('ELISMERÉSEK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Wrap(
                spacing: 7,
                runSpacing: 7,
                children: profile.awards
                    .map((award) => Chip(label: Text(award)))
                    .toList()),
          ],
        ],
      );
}

class _WnbaLiveData extends StatelessWidget {
  const _WnbaLiveData(
      {required this.games,
      required this.range,
      required this.accent,
      required this.onRange});
  final List<WnbaGameLog> games;
  final int range;
  final Color accent;
  final ValueChanged<int> onRange;

  @override
  Widget build(BuildContext context) {
    final shown = range == 0 ? games : games.take(range).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WnbaSeasonSummaryFacts(games: games),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(
            child: Text('FORMA · PONTSZÁM',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
        for (final option in const [(5, '5'), (10, '10'), (0, 'SZEZON')])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
                label: Text(option.$2),
                selected: range == option.$1,
                onSelected: (_) => onRange(option.$1)),
          ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
          height: 116,
          child: _WnbaFormBars(games: shown.reversed.toList(), color: accent)),
      const SizedBox(height: 22),
      const Text('UTÓBBI MÉRKŐZÉSEK · VALÓS ADAT',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('A SportsDataverse / wehoop meccsszintű box score adataiból.',
          style: TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 8),
      _WnbaGameTable(games: games.take(5).toList(), accent: accent),
    ]);
  }
}

class WnbaSeasonSummaryFacts extends StatelessWidget {
  const WnbaSeasonSummaryFacts({super.key, required this.games});

  final List<WnbaGameLog> games;

  @override
  Widget build(BuildContext context) {
    final summary = WnbaSeasonSummary.fromGames(games);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SZEZON ÖSSZESÍTŐ · VALÓS ADAT',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _muted,
              letterSpacing: .8)),
      const SizedBox(height: 4),
      Text(
          '${games.first.team} · WNBA ${games.first.date.year} · SPORTSDATAVERSE / WEHOOP',
          style: const TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _WnbaMiniMetric(value: summary.games.toString(), label: 'MECCS'),
        _WnbaMiniMetric(
            value: summary.minutesPerGame.toStringAsFixed(1),
            label: 'PERC / MECCS'),
        _WnbaMiniMetric(
            value: summary.pointsPerGame.toStringAsFixed(1),
            label: 'PONT / MECCS'),
        _WnbaMiniMetric(
            value: summary.reboundsPerGame.toStringAsFixed(1),
            label: 'LEPATTANÓ / MECCS'),
        _WnbaMiniMetric(
            value: summary.assistsPerGame.toStringAsFixed(1),
            label: 'ASSZISZT / MECCS'),
        _WnbaMiniMetric(
            value: summary.stealsPerGame.toStringAsFixed(1),
            label: 'LABDASZERZÉS / MECCS'),
        _WnbaMiniMetric(
            value: summary.turnoversPerGame.toStringAsFixed(1),
            label: 'ELADOTT LABDA / MECCS'),
        _WnbaMiniMetric(
            value: summary.fieldGoalPercentage == null
                ? '—'
                : '${summary.fieldGoalPercentage!.toStringAsFixed(1)}%',
            label: 'FG%'),
      ]),
    ]);
  }
}

class _WnbaMiniMetric extends StatelessWidget {
  const _WnbaMiniMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      width: 138,
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: _canvas, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: _muted, fontWeight: FontWeight.w800))
      ]));
}

class _WnbaFormBars extends StatelessWidget {
  const _WnbaFormBars({required this.games, required this.color});
  final List<WnbaGameLog> games;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final max = games.fold<int>(
        1, (maxValue, game) => game.points > maxValue ? game.points : maxValue);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: games
          .map((game) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message:
                        '${game.date.month}.${game.date.day} · ${game.opponent}: ${game.points} PTS',
                    child: Container(
                      height: 18 + 88 * game.points / max,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _WnbaGameTable extends StatelessWidget {
  const _WnbaGameTable({required this.games, required this.accent});
  final List<WnbaGameLog> games;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
      children: games
          .map((game) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  SizedBox(
                      width: 76,
                      child: Text(
                          '${game.date.month.toString().padLeft(2, '0')}.${game.date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  Expanded(
                      child: Text('vs. ${game.opponent}',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 82,
                      child: Text(
                          '${game.score} ${game.result == WnbaResult.win ? 'GY' : game.result == WnbaResult.loss ? 'V' : ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: game.result == WnbaResult.win
                                  ? _olive
                                  : game.result == WnbaResult.loss
                                      ? const Color(0xFFB44646)
                                      : _muted))),
                  _WnbaStat(value: '${game.points}', label: 'PTS'),
                  _WnbaStat(value: '${game.rebounds}', label: 'REB'),
                  _WnbaStat(value: '${game.assists}', label: 'AST'),
                ]),
              ))
          .toList());
}

class _WnbaStat extends StatelessWidget {
  const _WnbaStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 52,
      child: Column(children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: _muted, fontWeight: FontWeight.w800))
      ]));
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.athlete});
  final Athlete athlete;
  @override
  Widget build(BuildContext context) => Container(
      height: 380,
      clipBehavior: Clip.antiAlias,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(32), color: _ink),
      child: Stack(children: [
        Positioned.fill(
            child: Image.network(athlete.photoUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) =>
                    Container(color: athlete.accent))),
        Positioned.fill(
            child: const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0x00151815), Color(0xED151815)],
                        stops: [.22, 1],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)))),
        Positioned(
            left: 28,
            bottom: 25,
            right: 28,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: athlete.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3)),
                  child: Text(athlete.name.substring(0, 1),
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(athlete.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2)),
                    const SizedBox(height: 5),
                    Text('${athlete.sportAndTeam} · ${athlete.country}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16))
                  ])),
              _Pill(text: 'KÖVETVE', color: _olive),
            ])),
      ]));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.accent});
  final Metric metric;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8D4C8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(metric.label,
            style: const TextStyle(
                fontSize: 10,
                color: _muted,
                fontWeight: FontWeight.w900,
                letterSpacing: .9)),
        const SizedBox(height: 15),
        Text(metric.value,
            style: const TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.3)),
        const SizedBox(height: 5),
        Text(metric.note,
            style: TextStyle(
                color: accent, fontWeight: FontWeight.w700, fontSize: 12))
      ]));
}

class _SportTemplate extends StatelessWidget {
  const _SportTemplate({required this.athlete});
  final Athlete athlete;
  @override
  Widget build(BuildContext context) {
    final content = switch (athlete.sport) {
      'NBA' || 'WNBA' => (
          'JÁTÉKINTELLIGENCIA',
          'A pontszerzés, játékirányítás és lepattanózás formagörbéje.',
          ['Dobóforma', 'Játékszervezés', 'Védekezés']
        ),
      'Foci' => (
          'TÁMADÓ HATÁS',
          'Gólveszély, kulcspasszok és labdabiztosság az utóbbi meccseken.',
          ['Gólveszély', 'Kreativitás', 'Passzjáték']
        ),
      'Darts' => (
          'DOBÓFORMA',
          '3-dart átlag, kiszállózás és maximumok alakulása.',
          ['Átlag', 'Checkout', '180-asok']
        ),
      'Tenisz' => (
          'TENISZPROFIL',
          'Ranglista, játékosprofil, élő állás és következő mérkőzések.',
          ['Ranglista', 'Borítás', 'Mérkőzésritmus']
        ),
      'NFL' => (
          'TELJESÍTMÉNYPROFIL',
          'A szerepkörhöz igazított, egységes heti teljesítmény.',
          ['Hatékonyság', 'Explozivitás', 'Kulcsjátékok']
        ),
      _ => (
          'TELJESÍTMÉNYPROFIL',
          'Sportág-specifikus formajelzők.',
          ['Forma', 'Hatékonyság', 'Hatás']
        ),
    };
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: athlete.accent.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(content.$1,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 7),
          Text(content.$2, style: const TextStyle(color: Color(0xFF3F4538))),
          const SizedBox(height: 22),
          Row(
              children: List.generate(
                  content.$3.length,
                  (index) => Expanded(
                      child: Padding(
                          padding: EdgeInsets.only(right: index == 2 ? 0 : 14),
                          child: _FormBar(
                              label: content.$3[index],
                              value: [84, 72, 91][index],
                              color: athlete.accent))))),
        ]));
  }
}

class _FormBar extends StatelessWidget {
  const _FormBar(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text('$value%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))
        ]),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 11,
                color: _ink,
                backgroundColor: Colors.white.withValues(alpha: .58)))
      ]);
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, required this.accent});
  final MatchLine match;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD8D4C8))),
      child: Row(children: [
        SizedBox(
            width: 62,
            child: Text(match.date,
                style: const TextStyle(
                    fontSize: 11, color: _muted, fontWeight: FontWeight.w900))),
        Expanded(
            flex: 2,
            child: Text(match.opponent,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(
            child: Text(match.result,
                style: TextStyle(
                    color: accent, fontSize: 11, fontWeight: FontWeight.w900))),
        SizedBox(
            width: 88,
            child: Text(match.score,
                style: const TextStyle(fontWeight: FontWeight.w900))),
        Expanded(
            flex: 2,
            child: Text(match.performance,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12))),
        Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Text(match.grade,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900))),
      ]));
}

class _ClipCard extends StatelessWidget {
  const _ClipCard({required this.video, required this.onRemove});
  final SavedYouTubeVideo video;
  final VoidCallback onRemove;
  void _play() => Process.start('cmd', ['/c', 'start', '', video.watchUrl]);
  @override
  Widget build(BuildContext context) => Container(
      width: 305,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(video.thumbnailUrl,
                height: 106,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 106,
                    child: Center(
                        child:
                            Icon(Icons.broken_image, color: Colors.white))))),
        const SizedBox(height: 14),
        Text(video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            'Mentve: ${video.savedAt.year}.${video.savedAt.month.toString().padLeft(2, '0')}.${video.savedAt.day.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          TextButton.icon(
              onPressed: _play,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lejátszás')),
          const Spacer(),
          IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.white))
        ])
      ]));
}

class _PersonalTools extends StatelessWidget {
  const _PersonalTools(
      {required this.note,
      required this.alertEnabled,
      required this.onSaveNote,
      required this.onToggleAlert});
  final String note;
  final bool alertEnabled;
  final ValueChanged<String> onSaveNote;
  final VoidCallback onToggleAlert;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8D4C8))),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('SAJÁT JEGYZET',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _muted)),
                const SizedBox(height: 5),
                Text(
                    note.isEmpty
                        ? 'Még nincs jegyzet ehhez a sportolóhoz.'
                        : note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)
              ])),
          TextButton.icon(
              onPressed: () {
                final controller = TextEditingController(text: note);
                showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                            title: const Text('Saját jegyzet'),
                            content: TextField(
                                controller: controller,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                    hintText: 'Mit szeretnél észben tartani?')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Mégse')),
                              FilledButton(
                                  onPressed: () {
                                    onSaveNote(controller.text.trim());
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Mentés'))
                            ]));
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Szerkesztés')),
          const SizedBox(width: 8),
          FilterChip(
              label: Text(alertEnabled ? 'Értesítés aktív' : 'Értesítés ki'),
              selected: alertEnabled,
              onSelected: (_) => onToggleAlert(),
              avatar: Icon(
                  alertEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off_outlined,
                  size: 16)),
        ]),
      );
}

class _AthleteDirectory extends StatefulWidget {
  const _AthleteDirectory(
      {required this.athletes,
      required this.sort,
      required this.onOpen,
      required this.onAdd});
  final List<Athlete> athletes;
  final String sort;
  final ValueChanged<Athlete> onOpen;
  final VoidCallback onAdd;

  @override
  State<_AthleteDirectory> createState() => _AthleteDirectoryState();
}

class _AthleteDirectoryState extends State<_AthleteDirectory> {
  final _search = TextEditingController();
  String _sport = 'Mind';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = normalizeAthleteName(_search.text.trim());
    final athletes = sortAthletes(
      widget.athletes
          .where((athlete) =>
              (_sport == 'Mind' || athlete.sport == _sport) &&
              (query.isEmpty ||
                  normalizeAthleteName(athlete.name).contains(query)))
          .toList(),
      widget.sort,
    );
    return Container(
      color: _canvas,
      padding: const EdgeInsets.all(34),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Sportolók',
                    style:
                        TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Névfeloldás, képkeresés és saját követési lista.',
                    style: TextStyle(color: _muted))
              ])),
          FilledButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Sportoló hozzáadása')),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
              child: TextField(
            key: const Key('athlete-directory-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                hintText: 'Keresés név alapján…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Keresés törlése',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close)),
                filled: true,
                fillColor: _paper,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none)),
          )),
          const SizedBox(width: 16),
          Text('${athletes.length} sportoló',
              style:
                  const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: [
            'Mind',
            'NBA',
            'WNBA',
            'Foci',
            'Darts',
            'Tenisz',
            'NFL'
          ]
                  .map((sport) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            key: ValueKey('athlete-sport-$sport'),
                            label: Text(sport),
                            selected: _sport == sport,
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            onSelected: (_) => setState(() => _sport = sport)),
                      ))
                  .toList()),
        ),
        const SizedBox(height: 18),
        Expanded(
            child: athletes.isEmpty
                ? const Center(
                    child: Text('Nincs a keresésnek megfelelő sportoló.',
                        style: TextStyle(color: _muted)))
                : ListView.separated(
                    itemCount: athletes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final athlete = athletes[index];
                      return Material(
                          color: _paper,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                              key:
                                  ValueKey('directory-athlete-${athlete.name}'),
                              onTap: () => widget.onOpen(athlete),
                              leading: CircleAvatar(
                                  backgroundColor: athlete.accent,
                                  child: Text(athlete.name.substring(0, 1))),
                              title: Text(athlete.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(athlete.sportAndTeam),
                              trailing: const Icon(Icons.arrow_forward)));
                    },
                  )),
      ]),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.theme,
    required this.overviewSort,
    required this.athleteSort,
    required this.onThemeChanged,
    required this.onOverviewSortChanged,
    required this.onAthleteSortChanged,
  });

  final String theme;
  final String overviewSort;
  final String athleteSort;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onOverviewSortChanged;
  final ValueChanged<String> onAthleteSortChanged;

  static const _sortOptions = {
    'custom': 'Saját sorrend',
    'name': 'Név (A–Z)',
    'sport': 'Sportág, majd név',
    'team': 'Csapat, majd név',
  };

  @override
  Widget build(BuildContext context) => Container(
        color: _canvas,
        padding: const EdgeInsets.all(34),
        child: ListView(children: [
          const Text('Beállítások',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4)),
          const SizedBox(height: 6),
          const Text('A módosításokat a Courtboard automatikusan elmenti.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 28),
          _SettingsCard(
              title: 'Megjelenés',
              description: 'Válaszd ki az alkalmazás kiemelőszínét.',
              child: SegmentedButton<String>(segments: const [
                ButtonSegment(
                    value: 'green',
                    icon: Icon(Icons.eco_outlined),
                    label: Text('Zöld téma')),
                ButtonSegment(
                    value: 'burgundy',
                    icon: Icon(Icons.wine_bar_outlined),
                    label: Text('Bordó téma')),
              ], selected: {
                theme
              }, onSelectionChanged: (values) => onThemeChanged(values.first))),
          const SizedBox(height: 16),
          _SettingsCard(
              title: 'Sportolók rendezése',
              description:
                  'Az Áttekintés és a Sportolók lista sorrendje külön állítható.',
              child: Column(children: [
                DropdownButtonFormField<String>(
                    key: const Key('overview-sort-setting'),
                    initialValue: overviewSort,
                    decoration: const InputDecoration(
                        labelText: 'Áttekintés – sportolók sorrendje',
                        border: OutlineInputBorder()),
                    items: _sortOptions.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onOverviewSortChanged(value);
                    }),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    key: const Key('athlete-sort-setting'),
                    initialValue: athleteSort,
                    decoration: const InputDecoration(
                        labelText: 'Sportolók oldal – lista sorrendje',
                        border: OutlineInputBorder()),
                    items: _sortOptions.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onAthleteSortChanged(value);
                    }),
              ])),
        ]),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard(
      {required this.title, required this.description, required this.child});
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD8D4C8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(description, style: const TextStyle(color: _muted)),
          const SizedBox(height: 20),
          child,
        ]),
      );
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage();
  @override
  Widget build(BuildContext context) {
    const events = [
      ('JAN 23', 'Denver Nuggets', 'vs. Lakers · NBA'),
      ('JAN 24', 'FC Barcelona', 'vs. Valencia · LaLiga'),
      ('JAN 25', 'Philadelphia Eagles', 'vs. Rams · NFL'),
      ('JAN 30', 'PDC Premier League', 'Luke Humphries · Darts')
    ];
    return Container(
        color: _canvas,
        child: Padding(
            padding: const EdgeInsets.all(34),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Naptár és mérkőzések',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5)),
              const SizedBox(height: 6),
              const Text(
                  'Követett sportolóid következő eseményei és utolsó eredményei.',
                  style: TextStyle(color: _muted)),
              const SizedBox(height: 28),
              ...events.map((event) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: _paper, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    SizedBox(
                        width: 80,
                        child: Text(event.$1,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: _moss))),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(event.$2,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(event.$3, style: const TextStyle(color: _muted))
                        ])),
                    const Icon(Icons.notifications_none)
                  ])))
            ])));
  }
}

class VideoLibraryEntry {
  const VideoLibraryEntry({required this.video, this.athlete});

  final SavedYouTubeVideo video;
  final Athlete? athlete;

  String get athleteName =>
      athlete?.name ??
      (video.athleteName.isEmpty
          ? 'Nincs sportolóhoz rendelve'
          : video.athleteName);
  String get sport => athlete?.sport ?? 'Egyéb';
}

List<VideoLibraryEntry> filterVideoLibrary({
  required List<VideoLibraryEntry> entries,
  String titleQuery = '',
  String athleteName = 'Mind',
  String sport = 'Mind',
}) {
  final query = normalizeAthleteName(titleQuery.trim());
  final filtered = entries
      .where((entry) =>
          (athleteName == 'Mind' || entry.athleteName == athleteName) &&
          (sport == 'Mind' || entry.sport == sport) &&
          (query.isEmpty ||
              normalizeAthleteName(entry.video.title).contains(query)))
      .toList();
  filtered.sort((a, b) => b.video.savedAt.compareTo(a.video.savedAt));
  return filtered;
}

class VideoLibraryPage extends StatefulWidget {
  const VideoLibraryPage({
    super.key,
    required this.athletes,
    required this.playlist,
    required this.onOpenAthlete,
    required this.onRemoveVideo,
    required this.onOpenAthletes,
  });

  final List<Athlete> athletes;
  final AthleteVideoPlaylist playlist;
  final ValueChanged<Athlete> onOpenAthlete;
  final ValueChanged<SavedYouTubeVideo> onRemoveVideo;
  final VoidCallback onOpenAthletes;

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  final _titleSearch = TextEditingController();
  String _athlete = 'Mind';
  String _sport = 'Mind';

  @override
  void dispose() {
    _titleSearch.dispose();
    super.dispose();
  }

  List<VideoLibraryEntry> get _entries {
    final athletesByName = {
      for (final athlete in widget.athletes)
        normalizeAthleteName(athlete.name): athlete
    };
    return [
      ...widget.playlist.videos,
      ...widget.playlist.unassigned,
    ]
        .map((video) => VideoLibraryEntry(
            video: video,
            athlete: athletesByName[normalizeAthleteName(video.athleteName)]))
        .toList();
  }

  void _clearFilters() {
    _titleSearch.clear();
    setState(() {
      _athlete = 'Mind';
      _sport = 'Mind';
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final athleteNames = entries
        .map((entry) => entry.athleteName)
        .toSet()
        .toList()
      ..sort(
          (a, b) => normalizeAthleteName(a).compareTo(normalizeAthleteName(b)));
    final sports = entries.map((entry) => entry.sport).toSet().toList()..sort();
    final activeAthlete = athleteNames.contains(_athlete) ? _athlete : 'Mind';
    final activeSport = sports.contains(_sport) ? _sport : 'Mind';
    final filtered = filterVideoLibrary(
        entries: entries,
        titleQuery: _titleSearch.text,
        athleteName: activeAthlete,
        sport: activeSport);
    final athletesWithVideos = entries
        .where((entry) => entry.athlete != null)
        .map((entry) => entry.athleteName)
        .toSet()
        .length;

    return Container(
      color: _canvas,
      padding: const EdgeInsets.fromLTRB(34, 28, 34, 34),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _VideoLibraryHeader(
            videoCount: entries.length,
            athleteCount: athletesWithVideos,
            sportCount: sports.where((sport) => sport != 'Egyéb').length),
        const SizedBox(height: 22),
        _VideoFilterBar(
          controller: _titleSearch,
          athlete: activeAthlete,
          sport: activeSport,
          athleteNames: athleteNames,
          sports: sports,
          onSearchChanged: (_) => setState(() {}),
          onAthleteChanged: (value) => setState(() => _athlete = value),
          onSportChanged: (value) => setState(() => _sport = value),
          onClear: _clearFilters,
        ),
        const SizedBox(height: 20),
        Row(children: [
          Text('${filtered.length} videó',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (entries.isNotEmpty)
            const Text('Legújabb mentések elöl',
                style: TextStyle(color: _muted, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
              ? _EmptyVideoLibrary(onOpenAthletes: widget.onOpenAthletes)
              : filtered.isEmpty
                  ? _EmptyVideoSearch(onClear: _clearFilters)
                  : LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1120
                          ? 3
                          : constraints.maxWidth >= 720
                              ? 2
                              : 1;
                      const gap = 16.0;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: filtered
                              .map((entry) => SizedBox(
                                  width: width,
                                  child: _VideoLibraryCard(
                                    entry: entry,
                                    onOpenAthlete: entry.athlete == null
                                        ? null
                                        : () => widget
                                            .onOpenAthlete(entry.athlete!),
                                    onRemove: () =>
                                        widget.onRemoveVideo(entry.video),
                                  )))
                              .toList(),
                        ),
                      );
                    }),
        ),
      ]),
    );
  }
}

class _VideoLibraryHeader extends StatelessWidget {
  const _VideoLibraryHeader(
      {required this.videoCount,
      required this.athleteCount,
      required this.sportCount});
  final int videoCount;
  final int athleteCount;
  final int sportCount;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.video_library_rounded, size: 29)),
        const SizedBox(width: 16),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Videók',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5)),
          SizedBox(height: 3),
          Text('A sportolóidhoz mentett videók egyetlen médiatárban.',
              style: TextStyle(color: _muted))
        ])),
        _VideoLibraryStat(value: '$videoCount', label: 'VIDEÓ'),
        const SizedBox(width: 8),
        _VideoLibraryStat(value: '$athleteCount', label: 'SPORTOLÓ'),
        const SizedBox(width: 8),
        _VideoLibraryStat(value: '$sportCount', label: 'SPORTÁG'),
      ]);
}

class _VideoLibraryStat extends StatelessWidget {
  const _VideoLibraryStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8D4C8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6)),
        ]),
      );
}

class _VideoFilterBar extends StatelessWidget {
  const _VideoFilterBar({
    required this.controller,
    required this.athlete,
    required this.sport,
    required this.athleteNames,
    required this.sports,
    required this.onSearchChanged,
    required this.onAthleteChanged,
    required this.onSportChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String athlete;
  final String sport;
  final List<String> athleteNames;
  final List<String> sports;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onAthleteChanged;
  final ValueChanged<String> onSportChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8D4C8))),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: TextField(
                key: const Key('video-title-search'),
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                    labelText: 'Keresés a videók címében',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder()),
              )),
          const SizedBox(width: 12),
          Expanded(
              key: const Key('video-athlete-filter'),
              flex: 2,
              child: DropdownButtonFormField<String>(
                  key: ValueKey('video-athlete-filter-$athlete'),
                  initialValue: athlete,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Sportoló',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder()),
                  items: ['Mind', ...athleteNames]
                      .map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(name,
                              maxLines: 1, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onAthleteChanged(value);
                  })),
          const SizedBox(width: 12),
          Expanded(
              key: const Key('video-sport-filter'),
              flex: 2,
              child: DropdownButtonFormField<String>(
                  key: ValueKey('video-sport-filter-$sport'),
                  initialValue: sport,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Sportág',
                      prefixIcon: Icon(Icons.sports_basketball_outlined),
                      border: OutlineInputBorder()),
                  items: ['Mind', ...sports]
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onSportChanged(value);
                  })),
          const SizedBox(width: 8),
          IconButton.filledTonal(
              key: const Key('video-clear-filters'),
              tooltip: 'Szűrők törlése',
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined)),
        ]),
      );
}

class _VideoLibraryCard extends StatelessWidget {
  const _VideoLibraryCard(
      {required this.entry,
      required this.onOpenAthlete,
      required this.onRemove});

  final VideoLibraryEntry entry;
  final VoidCallback? onOpenAthlete;
  final VoidCallback onRemove;

  void _play() =>
      Process.start('cmd', ['/c', 'start', '', entry.video.watchUrl]);

  @override
  Widget build(BuildContext context) {
    final athlete = entry.athlete;
    final accent = athlete?.accent ?? Theme.of(context).colorScheme.secondary;
    return Material(
      key: ValueKey('video-${entry.video.videoId}-${entry.athleteName}'),
      color: _paper,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _play,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Image.network(entry.video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: _ink,
                      child: const Icon(Icons.video_library_outlined,
                          color: Colors.white54, size: 44))),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0x99151815)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter))),
              Positioned(
                  top: 12,
                  left: 12,
                  child: _Pill(text: entry.sport.toUpperCase(), color: accent)),
              Center(
                  child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .92),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: _ink, size: 34))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 12, 13),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 13),
              Row(children: [
                CircleAvatar(
                    radius: 17,
                    backgroundColor: accent,
                    child: Text(entry.athleteName.substring(0, 1),
                        style: const TextStyle(
                            color: _ink, fontWeight: FontWeight.w900))),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(entry.athleteName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_savedDate(entry.video.savedAt),
                          style: const TextStyle(color: _muted, fontSize: 11)),
                    ])),
                if (onOpenAthlete != null)
                  IconButton(
                      tooltip: 'Sportoló profilja',
                      onPressed: onOpenAthlete,
                      icon: const Icon(Icons.person_outline)),
                IconButton(
                    tooltip: 'Videó eltávolítása',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _savedDate(DateTime date) =>
      'Mentve: ${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _EmptyVideoLibrary extends StatelessWidget {
  const _EmptyVideoLibrary({required this.onOpenAthletes});
  final VoidCallback onOpenAthletes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(34),
                  decoration: BoxDecoration(
                      color: _paper,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD8D4C8))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.video_library_outlined,
                        size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 14),
                    const Text('Még nincs mentett videód',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    const Text(
                        'Nyiss meg egy sportolói profilt, majd a videók résznél adj hozzá egy YouTube-linket.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, height: 1.4)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                        onPressed: onOpenAthletes,
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Sportolók megnyitása')),
                  ]),
                ),
              ),
            ),
          ));
}

class _EmptyVideoSearch extends StatelessWidget {
  const _EmptyVideoSearch({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded, size: 42, color: _muted),
          const SizedBox(height: 10),
          const Text('Nincs a szűrésnek megfelelő videó.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Szűrők törlése')),
        ]),
      );
}

class _DataStatusPage extends StatefulWidget {
  const _DataStatusPage(
      {required this.config,
      required this.onSaveFootballKey,
      required this.onSaveApiSportsKey,
      required this.onSaveBallDontLieKey,
      required this.onSaveRapidApiDartsKey,
      required this.onSaveLiveTennisKey});
  final SportsApiConfig config;
  final ValueChanged<String> onSaveFootballKey;
  final ValueChanged<String> onSaveApiSportsKey;
  final ValueChanged<String> onSaveBallDontLieKey;
  final ValueChanged<String> onSaveRapidApiDartsKey;
  final ValueChanged<String> onSaveLiveTennisKey;

  @override
  State<_DataStatusPage> createState() => _DataStatusPageState();
}

class _DataStatusPageState extends State<_DataStatusPage> {
  final _searchController = TextEditingController();
  String _sport = 'Mind';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editKey({
    required String title,
    required String value,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: value);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'API-kulcs'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('Mentés'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _openDocs(String url) async {
    try {
      await Process.start('cmd', ['/c', 'start', '', url]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A dokumentáció nem nyitható meg.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const sports = [
      'Mind',
      'NBA',
      'WNBA',
      'Foci',
      'Női foci',
      'Darts',
      'Tenisz',
      'NFL',
      'Hírek',
      'Videó'
    ];
    final rows = filterProviderCatalog(_searchController.text, _sport);
    final activeCount = providerCatalog
        .where((entry) =>
            entry.stage == ProviderStage.active &&
            entry.isConfigured(widget.config))
        .length;
    final noKeyCount = providerCatalog
        .where((entry) =>
            entry.stage == ProviderStage.active &&
            entry.key == ProviderKey.none)
        .length;
    return Container(
      color: _canvas,
      child: ListView(
        key: const Key('provider-documentation-list'),
        padding: const EdgeInsets.all(34),
        children: [
          const Text(
            'Adatforrás-kézikönyv',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keresd ki, melyik szolgáltató mit ad az apphoz, hol jelenik meg, '
            'milyen kulcs és kvóta tartozik hozzá, és mi történik hiba esetén.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryBadge(
                icon: Icons.hub_outlined,
                value: '${providerCatalog.length}',
                label: 'dokumentált forrás',
              ),
              _SummaryBadge(
                icon: Icons.check_circle_outline,
                value: '$activeCount',
                label: 'most használható',
              ),
              _SummaryBadge(
                icon: Icons.key_off_outlined,
                value: '$noKeyCount',
                label: 'saját kulcs nélkül',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _GettingStartedCard(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API-kulcsok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Mind opcionális. A mentett RapidAPI kulcsot a Darts és a WNBA API is használja, de mindkét API-ra külön fel kell iratkozni.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'football-data.org API-kulcs',
                        value: widget.config.footballDataKey,
                        onSave: widget.onSaveFootballKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('football-data.org'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'API-Sports API-kulcs',
                        value: widget.config.apiSportsKey,
                        onSave: widget.onSaveApiSportsKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('API-Sports'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'BALLDONTLIE API-kulcs',
                        value: widget.config.balldontlieKey,
                        onSave: widget.onSaveBallDontLieKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('BALLDONTLIE'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editKey(
                        title: 'RapidAPI közös alkalmazáskulcs',
                        value: widget.config.rapidApiDartsKey,
                        onSave: widget.onSaveRapidApiDartsKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('RapidAPI · Darts + WNBA'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('live-tennis-key-button'),
                      onPressed: () => _editKey(
                        title: 'Live Tennis API-kulcs',
                        value: widget.config.liveTennisKey,
                        onSave: widget.onSaveLiveTennisKey,
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Live Tennis API'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('provider-doc-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Keresés: pl. Aitana, 100/hó, profilkép, cache…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Keresés törlése',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: _paper,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sports
                  .map((sport) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(sport),
                          selected: _sport == sport,
                          onSelected: (_) => setState(() => _sport = sport),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${rows.length} találat',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const _EmptyProviderSearch()
          else
            ...rows.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProviderDocumentationCard(
                  entry: entry,
                  configured: entry.isConfigured(widget.config),
                  onOpenDocs: () => _openDocs(entry.docsUrl),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: _moss),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: _muted)),
        ]),
      );
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ELSŐ INDÍTÁS · 3 LÉPÉS',
                style: TextStyle(
                    color: _olive,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            SizedBox(height: 12),
            _SetupStep(
                number: '1', text: 'Indítsd a start-courtboard.ps1 fájlt.'),
            _SetupStep(
                number: '2',
                text:
                    'Az opcionális kulcsokat itt add meg; nélkülük is elindul.'),
            _SetupStep(
                number: '3',
                text:
                    'Vegyél fel vagy nyiss meg egy sportolót; az elérhető források együtt töltik ki a kártyáját.'),
          ],
        ),
      );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: _olive, shape: BoxShape.circle),
            child: Text(number,
                style:
                    const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white))),
        ]),
      );
}

class _ProviderDocumentationCard extends StatelessWidget {
  const _ProviderDocumentationCard({
    required this.entry,
    required this.configured,
    required this.onOpenDocs,
  });
  final ProviderCatalogEntry entry;
  final bool configured;
  final VoidCallback onOpenDocs;

  @override
  Widget build(BuildContext context) {
    final prepared = entry.stage == ProviderStage.prepared;
    final status = prepared
        ? 'ELŐKÉSZÍTVE'
        : entry.key == ProviderKey.none
            ? 'KULCS NÉLKÜL'
            : configured
                ? 'BEKÖTVE'
                : 'KULCS HIÁNYZIK';
    final statusColor = prepared
        ? _muted
        : configured
            ? _moss
            : Colors.orange.shade800;
    return Material(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('provider-${entry.name}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: Icon(
          prepared
              ? Icons.construction_rounded
              : configured
                  ? Icons.check_circle_rounded
                  : Icons.key_off_rounded,
          color: statusColor,
        ),
        title: Text(entry.name,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(entry.role),
        ),
        trailing: _StatusLabel(text: status, color: statusColor),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.sports
                  .map((sport) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(sport),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentationSection(
              title: 'MI JELENIK MEG?', items: entry.visibleOutput),
          _DocumentationSection(
              title: 'MIRE KÉPES?', items: entry.capabilities),
          _DocumentationFact(label: 'Hozzáférés', value: entry.authentication),
          _DocumentationFact(label: 'Limit', value: entry.limit),
          _DocumentationFact(label: 'Cache', value: entry.cache),
          _DocumentationFact(label: 'Beállítás', value: entry.setup),
          _DocumentationFact(label: 'Hiba esetén', value: entry.fallback),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenDocs,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Hivatalos dokumentáció'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}

class _DocumentationSection extends StatelessWidget {
  const _DocumentationSection({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8)),
          const SizedBox(height: 5),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(color: _moss)),
                      Expanded(child: Text(item)),
                    ]),
              )),
        ]),
      );
}

class _DocumentationFact extends StatelessWidget {
  const _DocumentationFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: _muted, fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text(value)),
        ]),
      );
}

class _EmptyProviderSearch extends StatelessWidget {
  const _EmptyProviderSearch();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(children: [
          Icon(Icons.search_off_rounded, color: _muted),
          SizedBox(height: 8),
          Text('Nincs ilyen adatforrás vagy funkció.',
              style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 3),
          Text('Próbálj sportágra, megjelenő adatra vagy kvótára keresni.',
              textAlign: TextAlign.center, style: TextStyle(color: _muted)),
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: const TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .8)));
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.active, required this.onSelect});
  final int active;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
        width: 236,
        color: _ink,
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: colors.secondary, shape: BoxShape.circle),
                child: Icon(Icons.bolt, color: colors.onSecondary)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('COURTBOARD',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
            )
          ]),
          const SizedBox(height: 48),
          _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'Áttekintés',
              selected: active == 0,
              onTap: () => onSelect(0)),
          _NavItem(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Sportolók',
              selected: active == 1,
              onTap: () => onSelect(1)),
          _NavItem(
              icon: Icons.calendar_month_outlined,
              label: 'Naptár',
              selected: active == 2,
              onTap: () => onSelect(2)),
          _NavItem(
              icon: Icons.newspaper_outlined,
              label: 'Hírek',
              selected: active == 3,
              onTap: () => onSelect(3)),
          _NavItem(
              icon: Icons.video_library_outlined,
              label: 'Videók',
              selected: active == 4,
              onTap: () => onSelect(4)),
          _NavItem(
              icon: Icons.cloud_sync_outlined,
              label: 'Adatforrások',
              selected: active == 5,
              onTap: () => onSelect(5)),
          _NavItem(
              icon: Icons.settings_outlined,
              label: 'Beállítások',
              selected: active == 6,
              onTap: () => onSelect(6)),
          const Spacer(),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF2A3027),
                  borderRadius: BorderRadius.circular(22)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: colors.secondary),
                    const SizedBox(height: 12),
                    Text('SZEMÉLYES KÖVETÉS',
                        style: TextStyle(
                            color: colors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Minden kedvenced egy helyen.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.3))
                  ])),
        ]));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: .55)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  Icon(icon,
                      color: selected ? colors.secondary : Colors.white54,
                      size: 19),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? Colors.white : Colors.white60,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600)),
                  )
                ]))));
  }
}
