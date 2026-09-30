part of '../main.dart';

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

  /// Ismeretlen vagy üres országot nem jelenítünk meg.
  bool get showsCountry {
    final value = country.trim();
    return value.isNotEmpty && value.toLowerCase() != 'ismeretlen';
  }
}

class Metric {
  const Metric(this.label, this.value, this.note);
  final String label;
  final String value;
  final String note;
}

class MatchLine {
  const MatchLine(
    this.date,
    this.opponent,
    this.result,
    this.score,
    this.performance,
    this.grade,
  );
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
  const CourtboardApp({
    super.key,
    this.initialState = const CourtboardLocalState(),
    this.stateStore,
    this.playlistFile,
  });

  /// A futtatás előtt egyszer betöltött helyi állapot.
  final CourtboardLocalState initialState;

  /// Az állapot mentésének helye; `null` esetén (például widget-tesztben)
  /// az alkalmazás semmit nem ír a lemezre.
  final LocalStateStore? stateStore;

  /// A saját videólista fájlja; `null` esetén nincs betöltés és mentés.
  final File? playlistFile;

  @override
  State<CourtboardApp> createState() => _CourtboardAppState();
}

class _CourtboardAppState extends State<CourtboardApp> {
  late String _theme = widget.initialState.theme;

  @override
  Widget build(BuildContext context) {
    final burgundy = _theme == 'burgundy';
    final seed = burgundy ? _burgundy : _moss;
    final secondary = burgundy ? _burgundySoft : _olive;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(primary: seed, secondary: secondary);
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
        initialState: widget.initialState,
        stateStore: widget.stateStore,
        playlistFile: widget.playlistFile,
        onThemeChanged: (value) => setState(() => _theme = value),
      ),
    );
  }
}
