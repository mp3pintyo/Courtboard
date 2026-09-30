part of '../main.dart';

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
    this.apiKeys = const {},
    this.apiKeyStore,
    this.secureStorageAvailable = true,
  });

  /// A futtatás előtt egyszer betöltött helyi állapot.
  final CourtboardLocalState initialState;

  /// A biztonságos tárolóból (vagy annak hibájakor a régi állapotfájlból)
  /// betöltött API-kulcsok; a környezeti változókat felülírják.
  final Map<ApiKeyId, String> apiKeys;

  /// Az appban módosított kulcsok mentési helye; `null` esetén a közös
  /// [SecretStore.shared]-re épülő tároló.
  final ApiKeyStore? apiKeyStore;

  /// Hamis, ha indításkor a biztonságos tároló nem volt elérhető.
  final bool secureStorageAvailable;

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
  late String _themeMode = widget.initialState.themeMode;

  @override
  Widget build(BuildContext context) {
    final accent = CourtboardAccent.fromStorage(_theme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Courtboard',
      theme: buildCourtboardTheme(accent, Brightness.light),
      darkTheme: buildCourtboardTheme(accent, Brightness.dark),
      themeMode: themeModeFromStorage(_themeMode),
      locale: const Locale('hu'),
      supportedLocales: const [Locale('hu')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: CourtboardShell(
        initialState: widget.initialState,
        stateStore: widget.stateStore,
        playlistFile: widget.playlistFile,
        apiKeys: widget.apiKeys,
        apiKeyStore: widget.apiKeyStore,
        secureStorageAvailable: widget.secureStorageAvailable,
        onThemeChanged: (value) => setState(() => _theme = value),
        onThemeModeChanged: (value) => setState(() => _themeMode = value),
      ),
    );
  }
}
