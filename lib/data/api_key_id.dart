/// A felhasználó által az appban megadható API-kulcsok.
///
/// A YouTube Data API kulcsa szándékosan nem szerepel: az csak környezeti
/// változóból érkezik, az appban nincs hozzá mező.
enum ApiKeyId {
  footballData(
    label: 'football-data.org',
    secretName: 'courtboard.api_key.football_data',
    legacyJsonField: 'footballDataKey',
    environmentVariables: ['FOOTBALL_DATA_KEY'],
  ),
  apiSports(
    label: 'API-Sports',
    secretName: 'courtboard.api_key.api_sports',
    legacyJsonField: 'apiSportsKey',
    environmentVariables: ['API_SPORTS_KEY'],
  ),
  balldontlie(
    label: 'BALLDONTLIE',
    secretName: 'courtboard.api_key.balldontlie',
    legacyJsonField: 'balldontlieKey',
    environmentVariables: ['BALLDONTLIE_KEY'],
  ),

  /// A Darts és a WNBA RapidAPI közös alkalmazáskulcsa. A régi
  /// `RAPIDAPI_DARTS_KEY` változó és `rapidApiDartsKey` JSON-mező továbbra
  /// is működik.
  rapidApi(
    label: 'RapidAPI',
    secretName: 'courtboard.api_key.rapidapi',
    legacyJsonField: 'rapidApiDartsKey',
    environmentVariables: ['RAPIDAPI_KEY', 'RAPIDAPI_DARTS_KEY'],
  ),
  liveTennis(
    label: 'Live Tennis API',
    secretName: 'courtboard.api_key.live_tennis',
    legacyJsonField: 'liveTennisKey',
    environmentVariables: ['LIVE_TENNIS_API_KEY'],
  );

  const ApiKeyId({
    required this.label,
    required this.secretName,
    required this.legacyJsonField,
    required this.environmentVariables,
  });

  /// Megjelenítendő szolgáltatónév.
  final String label;

  /// A kulcs neve a biztonságos tárolóban.
  final String secretName;

  /// A 0.9.0 előtti, titkosítatlan `courtboard_state.json` mezőneve.
  final String legacyJsonField;

  /// A környezeti változók elsőbbségi sorrendben (az első nem üres nyer).
  final List<String> environmentVariables;

  /// A kulcs értéke a [environment] változói közül, vagy üres szöveg.
  String fromEnvironment(Map<String, String> environment) {
    for (final name in environmentVariables) {
      final value = environment[name]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
