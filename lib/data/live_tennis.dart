import 'athlete_names.dart';
import 'file_util.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'json_util.dart';
import 'ranking_history.dart';
import 'sports_api.dart';

typedef TennisApiCall = Future<Map<String, dynamic>> Function(
    String path, Map<String, String> query);

class TennisPlayer {
  const TennisPlayer({
    required this.id,
    required this.name,
    this.tour,
    this.country,
    this.ranking,
    this.rankingPoints,
    this.rankingMovement,
    this.hand,
    this.backhand,
    this.birthday,
    this.stats = const {},
  });

  final int id;
  final String name;
  final String? tour;
  final String? country;
  final int? ranking;
  final int? rankingPoints;
  final String? rankingMovement;
  final String? hand;
  final int? backhand;
  final DateTime? birthday;
  final Map<String, dynamic> stats;

  factory TennisPlayer.fromJson(Map<String, dynamic> json) => TennisPlayer(
        id: jsonIntOrNull(json['id']) ?? 0,
        name: jsonString(json['name']) ?? 'Ismeretlen játékos',
        tour: jsonString(json['tour']),
        country: jsonString(json['country']),
        ranking: jsonIntOrNull(json['ranking']),
        rankingPoints: jsonIntOrNull(json['ranking_points']),
        rankingMovement: jsonString(json['ranking_movement']),
        hand: jsonString(json['hand']),
        backhand: jsonIntOrNull(json['backhand']),
        birthday: DateTime.tryParse(jsonString(json['birthday']) ?? ''),
        stats: jsonMap(json['stats']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tour': tour,
        'country': country,
        'ranking': ranking,
        'ranking_points': rankingPoints,
        'ranking_movement': rankingMovement,
        'hand': hand,
        'backhand': backhand,
        'birthday': birthday?.toIso8601String(),
        'stats': stats,
      };
}

class TennisScore {
  const TennisScore({
    this.sets = const [],
    this.games = const [],
    this.points = const [],
    this.server,
    this.isTiebreak = false,
  });

  final List<int> sets;
  final List<List<int>> games;
  final List<String?> points;
  final int? server;
  final bool isTiebreak;

  factory TennisScore.fromJson(Map<String, dynamic> json) => TennisScore(
        sets: _intList(json['sets']),
        games: json['games'] is List
            ? (json['games'] as List)
                .whereType<List<Object?>>()
                .map((row) => row.map((value) => jsonIntOrNull(value) ?? 0).toList())
                .toList()
            : const [],
        points: json['points'] is List
            ? (json['points'] as List)
                .map((value) => value == null ? null : '$value')
                .toList()
            : const [],
        server: jsonIntOrNull(json['server']),
        isTiebreak: json['is_tiebreak'] == true,
      );

  String get summary {
    final parts = <String>[];
    if (sets.length >= 2) parts.add('${sets[0]}–${sets[1]} szett');
    if (games.length >= 2) {
      final count =
          games[0].length < games[1].length ? games[0].length : games[1].length;
      if (count > 0) {
        parts.add(List.generate(count, (i) => '${games[0][i]}–${games[1][i]}')
            .join(', '));
      }
    }
    if (points.length >= 2 && points.any((point) => point != null)) {
      parts.add('${points[0] ?? '—'}–${points[1] ?? '—'} pont');
    }
    return parts.isEmpty
        ? 'A mérkőzés még nem kezdődött el'
        : parts.join(' · ');
  }
}

class TennisMatch {
  const TennisMatch({
    required this.id,
    required this.tournament,
    required this.status,
    required this.player1,
    required this.player2,
    this.player1Id,
    this.player2Id,
    this.surface,
    this.round,
    this.scheduledTime,
    this.score,
    this.indoor = false,
  });

  final int id;
  final String tournament;
  final String status;
  final String player1;
  final String player2;
  final int? player1Id;
  final int? player2Id;
  final String? surface;
  final String? round;
  final DateTime? scheduledTime;
  final TennisScore? score;
  final bool indoor;

  factory TennisMatch.fromJson(Map<String, dynamic> json) {
    final players = jsonMap(json['players']);
    final p1 = jsonMap(players['p1']);
    final p2 = jsonMap(players['p2']);
    final rawScore = json['score'];
    return TennisMatch(
      id: jsonIntOrNull(json['id']) ?? 0,
      tournament: jsonString(json['tournament']) ?? 'Ismeretlen verseny',
      status: jsonString(json['status']) ?? 'upcoming',
      player1: jsonString(p1['name']) ?? 'Ismeretlen játékos',
      player2: jsonString(p2['name']) ?? 'Ismeretlen játékos',
      player1Id: jsonIntOrNull(p1['id']),
      player2Id: jsonIntOrNull(p2['id']),
      surface: jsonString(json['surface']),
      round: jsonString(json['round']),
      scheduledTime:
          DateTime.tryParse(jsonString(json['scheduled_time']) ?? '')?.toLocal(),
      score: rawScore is Map
          ? TennisScore.fromJson(Map<String, dynamic>.from(rawScore))
          : null,
      indoor: json['indoor'] == true,
    );
  }

  bool belongsTo(TennisPlayer player) =>
      player1Id == player.id ||
      player2Id == player.id ||
      athleteNamesMatch(player.name, player1) ||
      athleteNamesMatch(player.name, player2);

  String opponentOf(TennisPlayer player) =>
      player1Id == player.id || athleteNamesMatch(player.name, player1)
          ? player2
          : player1;
}

class TennisFixture {
  const TennisFixture({
    required this.id,
    required this.tournament,
    required this.player1,
    required this.player2,
    this.eventDate,
    this.tour,
    this.surface,
    this.round,
  });

  final int id;
  final String tournament;
  final String player1;
  final String player2;
  final DateTime? eventDate;
  final String? tour;
  final String? surface;
  final String? round;

  factory TennisFixture.fromJson(Map<String, dynamic> json) => TennisFixture(
        id: jsonIntOrNull(json['id']) ?? 0,
        tournament: jsonString(json['tournament']) ?? 'Ismeretlen verseny',
        player1: jsonString(json['player1_name']) ?? 'Ismeretlen játékos',
        player2: jsonString(json['player2_name']) ?? 'Ismeretlen játékos',
        eventDate:
            DateTime.tryParse(jsonString(json['event_date']) ?? '')?.toLocal(),
        tour: jsonString(json['tour']),
        surface: jsonString(json['surface']),
        round: jsonString(json['round']),
      );

  bool belongsTo(TennisPlayer player) =>
      athleteNamesMatch(player.name, player1) ||
      athleteNamesMatch(player.name, player2);

  String opponentOf(TennisPlayer player) =>
      athleteNamesMatch(player.name, player1) ? player2 : player1;
}

class TennisUsage {
  const TennisUsage({required this.tier, this.today, this.dailyLimit});
  final String tier;
  final int? today;
  final int? dailyLimit;

  factory TennisUsage.fromJson(Map<String, dynamic> json) {
    final limits = jsonMap(json['limits']);
    final today = jsonMap(json['today']);
    return TennisUsage(
      tier: (jsonString(json['tier']) ?? 'free').toUpperCase(),
      today: _firstInt(today, const ['calls', 'requests', 'count', 'used']),
      dailyLimit: _firstInt(limits, const [
        'per_day',
        'daily',
        'daily_requests',
        'requests_per_day',
        'day'
      ]),
    );
  }
}

class TennisProfileData {
  const TennisProfileData({
    required this.player,
    this.liveMatches = const [],
    this.upcomingMatches = const [],
    this.fixtures = const [],
    this.usage,
    this.fetchedAt,
    this.fromCache = false,
    this.rankingHistory = const [],
  });

  final TennisPlayer player;
  final List<TennisMatch> liveMatches;
  final List<TennisMatch> upcomingMatches;
  final List<TennisFixture> fixtures;
  final TennisUsage? usage;

  /// Az adatcsomag letöltési ideje (gyorsítótárból az eredetié).
  final DateTime? fetchedAt;
  final bool fromCache;

  /// A helyben gyűjtött ranglista-mérések (lásd [RankingHistoryStore]).
  final List<RankingSnapshot> rankingHistory;
}

class TennisRepository {
  TennisRepository(
    this.config, {
    TennisApiCall? call,
    this.cacheLifetime = const Duration(minutes: 10),
    this._http,
    this._cacheStorage,
  }) : _callOverride = call;

  final SportsApiConfig config;
  final TennisApiCall? _callOverride;
  final Duration cacheLifetime;
  final HttpService? _http;
  final CacheStorage? _cacheStorage;

  /// Játékosonként [cacheLifetime] ideig lemezről; a [forceRefresh] kikerüli
  /// a gyorsítótárat. Hálózati hibánál a lejárt csomag is visszajön.
  Future<TennisProfileData> fetch(String athleteName,
      {bool forceRefresh = false}) async {
    if (config.liveTennisKey.trim().isEmpty && _callOverride == null) {
      throw StateError('Live Tennis API-kulcs nincs beállítva.');
    }
    final client = SportsApiClient(
        config: config, http: _http, cacheStorage: _cacheStorage);
    Future<Map<String, dynamic>> call(String path, Map<String, String> query) =>
        _callOverride?.call(path, query) ?? client.liveTennis(path, query);

    final bundle = await client.cache('live_tennis').getOrFetch<
        Map<String, dynamic>>(
      cacheSlug(athleteName),
      ttl: cacheLifetime,
      forceRefresh: forceRefresh,
      fetch: () => _download(athleteName, call),
      encode: (value) => value,
      decode: jsonMap,
    );
    final data = parseProfileBundle(bundle.value);
    return TennisProfileData(
      player: data.player,
      liveMatches: data.liveMatches,
      upcomingMatches: data.upcomingMatches,
      fixtures: data.fixtures,
      usage: data.usage,
      fetchedAt: bundle.fetchedAt,
      fromCache: bundle.fromCache,
    );
  }

  static Future<Map<String, dynamic>> _download(
    String athleteName,
    TennisApiCall call,
  ) async {
    final search = await call('/players', {
      'search': athleteName,
      'limit': '20',
    });
    final playerSummary = findPlayer(search, athleteName);
    if (playerSummary == null || playerSummary.id == 0) {
      throw StateError('A Live Tennis API nem talált ilyen játékost.');
    }
    final playerJson = await call('/players/${playerSummary.id}', const {});
    final player = TennisPlayer.fromJson(playerJson);
    final tourQuery = _safeTourFilter(player.tour);
    final common = <String, String>{'limit': '200'};
    if (tourQuery != null) common['tour'] = tourQuery;

    final responses = await Future.wait([
      call('/matches', {...common, 'status': 'live'}),
      call('/matches', {...common, 'status': 'upcoming'}),
      call('/fixtures', common),
      call('/usage', const {}),
    ]);
    return <String, dynamic>{
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'player': playerJson,
      'live': responses[0],
      'upcoming': responses[1],
      'fixtures': responses[2],
      'usage': responses[3],
    };
  }

  static TennisPlayer? findPlayer(
      Map<String, dynamic> payload, String athleteName) {
    final raw = payload['data'];
    if (raw is! List) return null;
    final players = jsonMapList(raw)
        .map(TennisPlayer.fromJson)
        .where((player) => player.id != 0)
        .toList();
    // Nincs névegyezés: `null`, hogy ne egy másik játékos profilja jelenjen meg.
    return findAthleteByName(players, athleteName, (player) => player.name);
  }

  static TennisProfileData parseProfileBundle(Map<String, dynamic> bundle) {
    final player = TennisPlayer.fromJson(jsonMap(bundle['player']));
    final live = _parseMatches(jsonMap(bundle['live']))
        .where((match) => match.belongsTo(player))
        .toList();
    final upcoming = _parseMatches(jsonMap(bundle['upcoming']))
        .where((match) => match.belongsTo(player))
        .toList()
      ..sort(_matchDateCompare);
    final fixtures = _parseFixtures(jsonMap(bundle['fixtures']))
        .where((fixture) => fixture.belongsTo(player))
        .toList()
      ..sort((a, b) => _dateCompare(a.eventDate, b.eventDate));
    final rawUsage = bundle['usage'];
    return TennisProfileData(
      player: player,
      liveMatches: live,
      upcomingMatches: upcoming,
      fixtures: fixtures,
      usage: rawUsage is Map
          ? TennisUsage.fromJson(Map<String, dynamic>.from(rawUsage))
          : null,
    );
  }

  static List<TennisMatch> _parseMatches(Map<String, dynamic> payload) {
    final raw = payload['data'];
    if (raw is! List) return const [];
    return jsonMapList(raw)
        .map(TennisMatch.fromJson)
        .toList();
  }

  static List<TennisFixture> _parseFixtures(Map<String, dynamic> payload) {
    final raw = payload['data'];
    if (raw is! List) return const [];
    return jsonMapList(raw)
        .map(TennisFixture.fromJson)
        .toList();
  }
}

String? _safeTourFilter(String? tour) {
  final normalized = tour?.toLowerCase();
  return normalized == 'atp' || normalized == 'wta' ? normalized : null;
}

List<int> _intList(dynamic value) => value is List
    ? value.map((item) => jsonIntOrNull(item) ?? 0).toList()
    : const [];

int? _firstInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = jsonIntOrNull(map[key]);
    if (value != null) return value;
  }
  return null;
}

int _matchDateCompare(TennisMatch a, TennisMatch b) =>
    _dateCompare(a.scheduledTime, b.scheduledTime);

int _dateCompare(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
