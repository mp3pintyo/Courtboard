import 'dart:convert';
import 'dart:io';

import 'api_sports.dart' show athleteNamesMatch, normalizeAthleteName;
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
        id: _integer(json['id']) ?? 0,
        name: _text(json['name']) ?? 'Ismeretlen játékos',
        tour: _text(json['tour']),
        country: _text(json['country']),
        ranking: _integer(json['ranking']),
        rankingPoints: _integer(json['ranking_points']),
        rankingMovement: _text(json['ranking_movement']),
        hand: _text(json['hand']),
        backhand: _integer(json['backhand']),
        birthday: DateTime.tryParse(_text(json['birthday']) ?? ''),
        stats: json['stats'] is Map
            ? Map<String, dynamic>.from(json['stats'] as Map)
            : const {},
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
                .whereType<List>()
                .map((row) => row.map((value) => _integer(value) ?? 0).toList())
                .toList()
            : const [],
        points: json['points'] is List
            ? (json['points'] as List)
                .map((value) => value == null ? null : '$value')
                .toList()
            : const [],
        server: _integer(json['server']),
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
    final players = json['players'] is Map
        ? Map<String, dynamic>.from(json['players'] as Map)
        : const <String, dynamic>{};
    final p1 = _playerMap(players['p1']);
    final p2 = _playerMap(players['p2']);
    final rawScore = json['score'];
    return TennisMatch(
      id: _integer(json['id']) ?? 0,
      tournament: _text(json['tournament']) ?? 'Ismeretlen verseny',
      status: _text(json['status']) ?? 'upcoming',
      player1: _text(p1['name']) ?? 'Ismeretlen játékos',
      player2: _text(p2['name']) ?? 'Ismeretlen játékos',
      player1Id: _integer(p1['id']),
      player2Id: _integer(p2['id']),
      surface: _text(json['surface']),
      round: _text(json['round']),
      scheduledTime:
          DateTime.tryParse(_text(json['scheduled_time']) ?? '')?.toLocal(),
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
        id: _integer(json['id']) ?? 0,
        tournament: _text(json['tournament']) ?? 'Ismeretlen verseny',
        player1: _text(json['player1_name']) ?? 'Ismeretlen játékos',
        player2: _text(json['player2_name']) ?? 'Ismeretlen játékos',
        eventDate:
            DateTime.tryParse(_text(json['event_date']) ?? '')?.toLocal(),
        tour: _text(json['tour']),
        surface: _text(json['surface']),
        round: _text(json['round']),
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
    final limits = _map(json['limits']);
    final today = _map(json['today']);
    return TennisUsage(
      tier: (_text(json['tier']) ?? 'free').toUpperCase(),
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
  });

  final TennisPlayer player;
  final List<TennisMatch> liveMatches;
  final List<TennisMatch> upcomingMatches;
  final List<TennisFixture> fixtures;
  final TennisUsage? usage;
}

class TennisRepository {
  TennisRepository(this.config,
      {TennisApiCall? call, this.cacheLifetime = const Duration(minutes: 10)})
      : _callOverride = call;

  final SportsApiConfig config;
  final TennisApiCall? _callOverride;
  final Duration cacheLifetime;

  Future<TennisProfileData> fetch(String athleteName,
      {bool forceRefresh = false}) async {
    if (config.liveTennisKey.trim().isEmpty && _callOverride == null) {
      throw StateError('Live Tennis API-kulcs nincs beállítva.');
    }
    final cache = _cacheFile(athleteName);
    if (!forceRefresh) {
      final cached = await _readCache(cache);
      if (cached != null) return parseProfileBundle(cached);
    }

    final client =
        _callOverride == null ? SportsApiClient(config: config) : null;
    Future<Map<String, dynamic>> call(String path, Map<String, String> query) =>
        _callOverride?.call(path, query) ?? client!.liveTennis(path, query);

    try {
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
      final bundle = <String, dynamic>{
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'player': playerJson,
        'live': responses[0],
        'upcoming': responses[1],
        'fixtures': responses[2],
        'usage': responses[3],
      };
      await cache.parent.create(recursive: true);
      await cache.writeAsString(jsonEncode(bundle));
      return parseProfileBundle(bundle);
    } finally {
      client?.close();
    }
  }

  static TennisPlayer? findPlayer(
      Map<String, dynamic> payload, String athleteName) {
    final raw = payload['data'];
    if (raw is! List) return null;
    final players = raw
        .whereType<Map>()
        .map((item) => TennisPlayer.fromJson(Map<String, dynamic>.from(item)))
        .where((player) => player.id != 0)
        .toList();
    for (final player in players) {
      if (athleteNamesMatch(player.name, athleteName)) return player;
    }
    final wanted = normalizeAthleteName(athleteName);
    final wantedTokens =
        wanted.split(' ').where((token) => token.isNotEmpty).toSet();
    for (final player in players) {
      final candidate = normalizeAthleteName(player.name);
      final candidateTokens =
          candidate.split(' ').where((token) => token.isNotEmpty).toSet();
      if (candidate.contains(wanted) ||
          wanted.contains(candidate) ||
          candidateTokens.containsAll(wantedTokens) ||
          wantedTokens.containsAll(candidateTokens)) {
        return player;
      }
    }
    return players.isEmpty ? null : players.first;
  }

  static TennisProfileData parseProfileBundle(Map<String, dynamic> bundle) {
    final player = TennisPlayer.fromJson(_map(bundle['player']));
    final live = _parseMatches(_map(bundle['live']))
        .where((match) => match.belongsTo(player))
        .toList();
    final upcoming = _parseMatches(_map(bundle['upcoming']))
        .where((match) => match.belongsTo(player))
        .toList()
      ..sort(_matchDateCompare);
    final fixtures = _parseFixtures(_map(bundle['fixtures']))
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
    return raw
        .whereType<Map>()
        .map((item) => TennisMatch.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<TennisFixture> _parseFixtures(Map<String, dynamic> payload) {
    final raw = payload['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => TennisFixture.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> _readCache(File cache) async {
    try {
      if (!await cache.exists() ||
          DateTime.now().difference(await cache.lastModified()) >=
              cacheLifetime) {
        return null;
      }
      final decoded = jsonDecode(await cache.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static File _cacheFile(String athleteName) {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    final slug = normalizeAthleteName(athleteName).replaceAll(' ', '_');
    return File('$appData/courtboard_cache/live_tennis/$slug.json');
  }
}

String? _safeTourFilter(String? tour) {
  final normalized = tour?.toLowerCase();
  return normalized == 'atp' || normalized == 'wta' ? normalized : null;
}

Map<String, dynamic> _playerMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String? _text(dynamic value) {
  final result = '${value ?? ''}'.trim();
  return result.isEmpty || result == 'null' ? null : result;
}

int? _integer(dynamic value) =>
    value is int ? value : int.tryParse('${value ?? ''}');

List<int> _intList(dynamic value) => value is List
    ? value.map((item) => _integer(item) ?? 0).toList()
    : const [];

int? _firstInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _integer(map[key]);
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
