/// Focicsapatok eredményei és menetrendje az ESPN nyilvános API-jából
/// (kulcs nélkül).
///
/// * Adatforrás-tippel (ESPN-ligakóddal) mentett sportolónál a bajnoki
///   scoreboard ([EspnSoccerTeamRepository.recentGames]). A 0.13.0 előtt ez
///   a `LigaFRepository` volt, a Barcelona női csapatára és az `esp.w.1`
///   ligára égetve; most a bajnokság és a csapat az [EspnSoccerTeam]
///   leíróból jön.
/// * Tipp nélküli klubnál (0.15.1) a csapatot a [espnSoccerClubLeagues]
///   bajnokságok csapatlistáiból oldja fel ([EspnSoccerTeamRepository
///   .resolveClub]), az eredmények és a menetrend pedig a csapat összes
///   sorozatát tartalmazó `soccer/all/teams/{id}/schedule` feedből jönnek.
library;

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/football_names.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/domain/athlete_source_hints.dart';

/// Egy csapat egy ESPN-bajnokságban: ligakód, keresett csapatnév és a
/// felületen megjelenő nevek.
class EspnSoccerTeam {
  const EspnSoccerTeam({
    required this.league,
    required this.team,
    this.competition = '',
    this.womensTeam = false,
    this.label,
    this.clubName = '',
  });

  /// A sportoló adatforrás-tippjeiből és csapatnevéből; `null`, ha nincs
  /// ESPN-ligakód, vagy nincs mi alapján csapatot keresni.
  static EspnSoccerTeam? fromHints(AthleteSourceHints hints, String team) {
    final league = hints.espnLeague;
    if (league == null) return null;
    final club = team.trim();
    final search = (hints.espnTeam ?? club).trim();
    if (search.isEmpty) return null;
    return EspnSoccerTeam(
      league: league,
      team: search,
      competition: hints.competition ?? '',
      womensTeam: hints.womensTeam,
      label: hints.teamLabel,
      clubName: club.isEmpty ? search : club,
    );
  }

  /// ESPN-ligakód (például `esp.w.1`).
  final String league;

  /// A keresett csapatnév az ESPN-ben (például `Barcelona`).
  final String team;

  /// A bajnokság megjelenített neve (például „Liga F”); üres esetén a
  /// ligakód.
  final String competition;

  /// A klub női csapata.
  final bool womensTeam;

  /// A megjelenített csapatnév, ha megadták (például „FC Barcelona
  /// Femení”).
  final String? label;

  /// A sportolónál megadott klubnév (például „FC Barcelona”).
  final String clubName;

  /// A bajnokság neve a felületen.
  String get competitionLabel => competition.isEmpty ? league : competition;

  /// A csapat neve a kártya címében.
  String get displayName {
    if (label != null) return label!;
    if (!womensTeam || hasWomenSuffix(clubName)) return clubName;
    return '$clubName (női)';
  }

  /// A kártya alcíme: női csapatnál kiemeli, hogy nem a férfi csapat
  /// eredményei látszanak.
  String get description => womensTeam
      ? 'Valós női $team csapateredmények; nem a férfi '
            '${withoutWomenSuffix(clubName)} feedje.'
      : 'Valós $clubName csapateredmények.';

  /// Az ESPN-csapatnév erre a csapatra utal-e (a női utótagok nélkül,
  /// tartalmazás vagy klubnév-egyezés alapján).
  bool matches(String espnName) {
    final expected = teamKey(team);
    final candidate = teamKey(espnName);
    if (expected.isEmpty || candidate.isEmpty) return false;
    return candidate.contains(expected) ||
        footballTeamNamesMatch(team, espnName);
  }

  /// Összehasonlító kulcs: kisbetűs, ékezet, női utótag és írásjel
  /// nélkül (`FC Barcelona Femení` → `fcbarcelona`).
  static String teamKey(String value) {
    var key = normalizeAthleteName(value);
    for (final suffix in _womenSuffixes) {
      key = key.replaceAll(suffix, '');
    }
    return key.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Női csapatnév-utótagok (ékezet nélkül; a [teamKey] már normalizált
  /// szövegből veszi ki őket).
  static const _womenSuffixes = [
    'femenino',
    'femeni',
    'feminines',
    'women',
    'frauen',
  ];

  /// A csapatnév női utótagú-e („Femení”, „Women”, „Frauen” …).
  static bool hasWomenSuffix(String value) {
    final normalized = normalizeAthleteName(value);
    return _womenSuffixes.any(normalized.contains);
  }

  /// A csapatnév a női utótag nélkül („FC Barcelona Femení” → „FC
  /// Barcelona”); ha semmi sem maradna, az eredeti név.
  static String withoutWomenSuffix(String value) {
    var result = value;
    for (final suffix in const [
      'Femenino',
      'Femení',
      'Femeni',
      'Féminines',
      'Feminines',
      'Women',
      'Frauen',
    ]) {
      result = result.replaceAll(RegExp(suffix, caseSensitive: false), '');
    }
    final trimmed = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed.isEmpty ? value.trim() : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is EspnSoccerTeam &&
      other.league == league &&
      other.team == team &&
      other.competition == competition &&
      other.womensTeam == womensTeam &&
      other.label == label &&
      other.clubName == clubName;

  @override
  int get hashCode =>
      Object.hash(league, team, competition, womensTeam, label, clubName);
}

/// Egy lejátszott mérkőzés a csapat szemszögéből.
class EspnSoccerGame {
  const EspnSoccerGame({
    required this.date,
    required this.opponent,
    required this.teamScore,
    required this.opponentScore,
    required this.home,
    this.eventId,
    this.competition = '',
    this.league,
    this.ownShootout,
    this.opponentShootout,
    this.afterExtraTime = false,
  });

  final DateTime date;

  /// ESPN-mérkőzésazonosító (az idővonalhoz), ha ismert.
  final String? eventId;
  final String opponent;
  final int teamScore;
  final int opponentScore;
  final bool home;

  /// A sorozat neve („MLS”, „Leagues Cup”), ha a forrás megadja.
  final String competition;

  /// A mérkőzés ESPN-ligakódja (`usa.1`, `concacaf.leagues.cup`), ha ismert.
  final String? league;

  /// Tizenegyespárbaj értékesített rúgásai (saját / ellenfél), ha volt.
  final int? ownShootout;
  final int? opponentShootout;

  /// Hosszabbítás után dőlt el (tizenegyesek nélkül).
  final bool afterExtraTime;

  bool get _hasShootout => ownShootout != null && opponentShootout != null;

  /// „1–2”, hosszabbításnál „2–1 (h.u.)”, tizenegyeseknél
  /// „1–1 (11-esek: 5–6)” (saját gólok elöl).
  String get score {
    final base = '$teamScore–$opponentScore';
    if (_hasShootout) return '$base (11-esek: $ownShootout–$opponentShootout)';
    if (afterExtraTime) return '$base (h.u.)';
    return base;
  }

  /// „GYŐZELEM” / „VERESÉG” / „DÖNTETLEN”; döntetlen rendes játékidőnél a
  /// tizenegyespárbaj dönt.
  String get result {
    var own = teamScore;
    var other = opponentScore;
    if (own == other && _hasShootout) {
      own = ownShootout!;
      other = opponentShootout!;
    }
    return own > other
        ? 'GYŐZELEM'
        : own < other
        ? 'VERESÉG'
        : 'DÖNTETLEN';
  }

  Map<String, Object?> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'eventId': eventId,
    'opponent': opponent,
    'teamScore': teamScore,
    'opponentScore': opponentScore,
    'home': home,
    'competition': competition,
    'league': league,
    'ownShootout': ownShootout,
    'opponentShootout': opponentShootout,
    'afterExtraTime': afterExtraTime,
  };

  static EspnSoccerGame? fromJson(Object? json) {
    final map = jsonMap(json);
    final date = DateTime.tryParse(jsonString(map['date']) ?? '');
    final teamScore = jsonIntOrNull(map['teamScore']);
    final opponentScore = jsonIntOrNull(map['opponentScore']);
    if (date == null || teamScore == null || opponentScore == null) {
      return null;
    }
    return EspnSoccerGame(
      date: date,
      eventId: jsonString(map['eventId']),
      opponent: jsonString(map['opponent']) ?? 'Ismeretlen',
      teamScore: teamScore,
      opponentScore: opponentScore,
      home: map['home'] == true,
      competition: jsonString(map['competition']) ?? '',
      league: jsonString(map['league']),
      ownShootout: jsonIntOrNull(map['ownShootout']),
      opponentShootout: jsonIntOrNull(map['opponentShootout']),
      afterExtraTime: map['afterExtraTime'] == true,
    );
  }
}

/// Egy ESPN-focibajnokság, amelynek csapatlistájában a tipp nélküli klubot
/// keressük.
class EspnSoccerLeague {
  const EspnSoccerLeague(
    this.slug,
    this.label, {
    this.womens = false,
    this.aliases = const [],
  });

  /// ESPN-ligakód (`usa.1`).
  final String slug;

  /// Megjelenített név („MLS”).
  final String label;

  /// Női bajnokság.
  final bool womens;

  /// A bajnokság további ismert nevei (a sorozat-tipphez).
  final List<String> aliases;

  /// A [competition] (például a sportolónál megadott „Premier League”) erre
  /// a bajnokságra utal-e: pontos (ékezet- és kisbetűfüggetlen) névegyezés
  /// vagy a ligakód.
  bool matchesCompetition(String competition) {
    final key = normalizeAthleteName(competition);
    if (key.isEmpty) return false;
    return competition.trim().toLowerCase() == slug ||
        [label, ...aliases].any((name) => normalizeAthleteName(name) == key);
  }
}

/// A tipp nélküli klubok feloldásához átnézett ESPN-bajnokságok, a
/// keresés sorrendjében: előbb a férfi, aztán a női bajnokságok. (Az ESPN a
/// szaúdi ligát `ksa.1`, nem `sau.1` kóddal adja.)
const espnSoccerClubLeagues = <EspnSoccerLeague>[
  EspnSoccerLeague('usa.1', 'MLS', aliases: ['Major League Soccer']),
  EspnSoccerLeague(
    'eng.1',
    'Premier League',
    aliases: ['English Premier League', 'EPL'],
  ),
  EspnSoccerLeague(
    'esp.1',
    'LaLiga',
    aliases: ['La Liga', 'Spanish LaLiga', 'Primera División'],
  ),
  EspnSoccerLeague('ger.1', 'Bundesliga', aliases: ['German Bundesliga']),
  EspnSoccerLeague('ita.1', 'Serie A', aliases: ['Italian Serie A']),
  EspnSoccerLeague('fra.1', 'Ligue 1', aliases: ['French Ligue 1']),
  EspnSoccerLeague(
    'por.1',
    'Primeira Liga',
    aliases: ['Liga Portugal', 'Portuguese Primeira Liga'],
  ),
  EspnSoccerLeague('ned.1', 'Eredivisie', aliases: ['Dutch Eredivisie']),
  EspnSoccerLeague('mex.1', 'Liga MX', aliases: ['Mexican Liga BBVA MX']),
  EspnSoccerLeague(
    'bra.1',
    'Brasileirão',
    aliases: ['Brazilian Serie A', 'Brasileirão Série A'],
  ),
  EspnSoccerLeague(
    'arg.1',
    'Liga Profesional',
    aliases: ['Argentine Liga Profesional de Fútbol'],
  ),
  EspnSoccerLeague(
    'ksa.1',
    'Saudi Pro League',
    aliases: ['Roshn Saudi League'],
  ),
  EspnSoccerLeague('tur.1', 'Süper Lig', aliases: ['Turkish Super Lig']),
  EspnSoccerLeague('sco.1', 'Premiership', aliases: ['Scottish Premiership']),
  EspnSoccerLeague(
    'bel.1',
    'Pro League',
    aliases: ['Belgian Pro League', 'Jupiler Pro League'],
  ),
  EspnSoccerLeague(
    'usa.nwsl',
    'NWSL',
    womens: true,
    aliases: [
      'National Women’s Soccer League',
      "National Women's Soccer League",
    ],
  ),
  EspnSoccerLeague(
    'eng.w.1',
    'Women’s Super League',
    womens: true,
    aliases: ['WSL', "Women's Super League", "English Women's Super League"],
  ),
  EspnSoccerLeague(
    AthleteSourceHints.ligaFLeague,
    'Liga F',
    womens: true,
    aliases: ['Spanish Liga F'],
  ),
];

/// Egy ESPN-bajnokságban feloldott klub.
class EspnSoccerClub {
  const EspnSoccerClub({
    required this.league,
    required this.leagueLabel,
    required this.id,
    required this.displayName,
    this.abbreviation = '',
  });

  /// A bajnokság ESPN-kódja (`usa.1`).
  final String league;

  /// A bajnokság megjelenített neve („MLS”).
  final String leagueLabel;

  /// ESPN-csapatazonosító (`20232`).
  final String id;

  /// A csapat ESPN-neve („Inter Miami CF”).
  final String displayName;
  final String abbreviation;

  /// A forrás megjelenített neve („ESPN · MLS”).
  String get sourceLabel => 'ESPN · $leagueLabel';

  Map<String, Object?> toJson() => {
    'league': league,
    'leagueLabel': leagueLabel,
    'id': id,
    'displayName': displayName,
    'abbreviation': abbreviation,
  };

  static EspnSoccerClub? fromJson(Object? json) {
    final map = jsonMap(json);
    final league = jsonString(map['league']);
    final id = jsonString(map['id']);
    if (league == null || id == null) return null;
    return EspnSoccerClub(
      league: league,
      leagueLabel: jsonString(map['leagueLabel']) ?? league,
      id: id,
      displayName: jsonString(map['displayName']) ?? '',
      abbreviation: jsonString(map['abbreviation']) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EspnSoccerClub && other.league == league && other.id == id;

  @override
  int get hashCode => Object.hash(league, id);

  @override
  String toString() => 'EspnSoccerClub($league/$id $displayName)';
}

class EspnSoccerTeamRepository {
  EspnSoccerTeamRepository([SportsApiClient? client])
    : _client = client ?? SportsApiClient();

  final SportsApiClient _client;

  /// Visszafelé kompatibilis: a közös HTTP-klienst nem zárja le.
  void close() => _client.close();

  /// A csapat legutóbbi lejátszott bajnoki mérkőzései.
  ///
  /// Az ESPN scoreboard `dates=ÉÉÉÉHHNN-ÉÉÉÉHHNN` tartományt kap az utolsó
  /// [window] napra; ha ebben nincs lejátszott meccs (nyári szünet), egy
  /// egyéves ablakkal próbálja újra.
  Future<List<EspnSoccerGame>> recentGames(
    EspnSoccerTeam team, {
    DateTime? now,
    Duration window = const Duration(days: 60),
  }) async {
    final today = now ?? DateTime.now();
    final recent = parseGames(
      await _client.espnSoccerScoreboard(
        team.league,
        from: today.subtract(window),
        to: today,
      ),
      team,
    );
    if (recent.isNotEmpty) return recent;
    return parseGames(
      await _client.espnSoccerScoreboard(
        team.league,
        from: today.subtract(const Duration(days: 365)),
        to: today,
        limit: 500,
      ),
      team,
    );
  }

  /// A scoreboard befejezett meccsei a [team] szemszögéből (legfrissebb
  /// elöl, legfeljebb 5).
  static List<EspnSoccerGame> parseGames(
    Map<String, dynamic> payload,
    EspnSoccerTeam team,
  ) {
    final games = <EspnSoccerGame>[];
    for (final rawEvent in jsonMapList(payload['events'])) {
      final competitions = jsonList(rawEvent['competitions']);
      if (competitions.isEmpty) continue;
      final competition = competitions.first;
      if (competition is! Map) continue;
      final status = competition['status'];
      final statusType = status is Map ? status['type'] : null;
      if (statusType is Map && statusType['completed'] != true) continue;
      final competitors = competition['competitors'];
      if (competitors is! List) continue;
      final entries = jsonMapList(competitors);
      Map<String, dynamic>? own;
      Map<String, dynamic>? opponent;
      for (final entry in entries) {
        final rawTeam = jsonMap(entry['team']);
        final displayName =
            '${rawTeam['displayName'] ?? rawTeam['name'] ?? ''}';
        if (team.matches(displayName)) own = entry;
      }
      if (own == null) continue;
      for (final entry in entries) {
        if (!identical(entry, own)) opponent = entry;
      }
      if (opponent == null) continue;
      final date = DateTime.tryParse('${rawEvent['date'] ?? ''}');
      if (date == null) continue;
      final opponentTeam = opponent['team'];
      games.add(
        EspnSoccerGame(
          date: date,
          opponent: opponentTeam is Map
              ? '${opponentTeam['displayName'] ?? opponentTeam['name'] ?? 'Ismeretlen'}'
              : 'Ismeretlen',
          teamScore: int.tryParse('${own['score'] ?? ''}') ?? 0,
          opponentScore: int.tryParse('${opponent['score'] ?? ''}') ?? 0,
          home: '${own['homeAway']}' == 'home',
          eventId: jsonString(rawEvent['id']),
        ),
      );
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }

  // -------------------------------------------------------------------------
  // Tipp nélküli klubok (0.15.1): csapatfeloldás és csapatmenetrend
  // -------------------------------------------------------------------------

  /// Gyorsítótár-névtér a foci-csapatlistáknak, a feloldott kluboknak és a
  /// klubmenetrendeknek.
  static const cacheNamespace = 'espn_soccer';

  /// Egy bajnokság csapatlistája ennyi ideig jön gyorsítótárból.
  static const leagueTeamsCacheLifetime = Duration(days: 7);

  /// A feloldott (csapat → liga, azonosító) párosítás élettartama.
  static const clubCacheLifetime = Duration(days: 7);

  /// A sikertelen feloldás ennyi ideig nem ismétlődik.
  static const clubMissCacheLifetime = Duration(hours: 24);

  /// Lejátszott meccsek (`schedule`) gyorsítótára.
  static const clubResultsCacheLifetime = Duration(hours: 1);

  /// Közelgő meccsek (`schedule?fixture=true`) gyorsítótára.
  static const clubFixturesCacheLifetime = Duration(hours: 6);

  /// Befejezett mérkőzést jelző ESPN-státuszok (a `completed` jelzés
  /// mellett).
  static const finishedStatuses = {
    'STATUS_FULL_TIME',
    'STATUS_FINAL',
    'STATUS_FINAL_AET',
    'STATUS_FINAL_PEN',
    'STATUS_FINAL_ET',
  };

  /// Nem lejátszott (törölt, elhalasztott, félbeszakadt) meccs jelzései a
  /// státusznévben.
  static const _voidStatusParts = ['CANCEL', 'POSTPON', 'ABANDON', 'SUSPEND'];

  /// A keresés sorrendje: a [competition] tipp szerinti bajnokság elöl; női
  /// csapatnál ([womensTeam]) csak a női bajnokságok.
  static List<EspnSoccerLeague> leagueSearchOrder({
    String? competition,
    bool womensTeam = false,
  }) {
    final candidates = [
      for (final league in espnSoccerClubLeagues)
        if (!womensTeam || league.womens) league,
    ];
    final hint = competition?.trim() ?? '';
    if (hint.isEmpty) return candidates;
    return [
      ...candidates.where((league) => league.matchesCompetition(hint)),
      ...candidates.where((league) => !league.matchesCompetition(hint)),
    ];
  }

  /// Egy bajnokság csapatlistája ([leagueTeamsCacheLifetime] ideig
  /// gyorsítótárból; csak a névfeloldáshoz szükséges mezők kerülnek
  /// lemezre).
  Future<Map<String, dynamic>> leagueTeams(String league) async =>
      (await _client
              .cache(cacheNamespace)
              .getOrFetch<Map<String, dynamic>>(
                'teams_$league',
                ttl: leagueTeamsCacheLifetime,
                fetch: () async =>
                    _trimTeams(await _client.espnSoccerSite('$league/teams')),
                encode: (value) => value,
                decode: jsonMap,
              ))
          .value;

  /// A tipp nélküli klub ESPN-bajnoksága és azonosítója.
  ///
  /// A [leagueSearchOrder] szerinti bajnokságok csapatlistáit lustán, egyenként
  /// nézi át, és az első találatnál megáll (a csapatlisták 7 napig
  /// gyorsítótárban vannak, így az ESPN percenkénti 30-as korlátja nem fogy
  /// feleslegesen). A találat [clubCacheLifetime], a „nincs ilyen csapat”
  /// [clubMissCacheLifetime] ideig jön gyorsítótárból. A 404-et adó bajnokság
  /// kimarad; más hálózati hibánál a keresés leáll, és a hiba továbbmegy (így
  /// hibás „nincs találat” nem kerül a gyorsítótárba).
  Future<EspnSoccerClub?> resolveClub(
    String teamName, {
    String? competition,
    bool? womensTeam,
  }) async {
    final name = teamName.trim();
    final key = normalizeFootballTeamName(name);
    if (key.isEmpty || name.toLowerCase() == 'nincs megadva') return null;
    final womens = womensTeam ?? EspnSoccerTeam.hasWomenSuffix(name);
    final leagues = leagueSearchOrder(
      competition: competition,
      womensTeam: womens,
    );
    return (await _client
            .cache(cacheNamespace)
            .getOrFetch<EspnSoccerClub?>(
              'club_${womens ? 'w_' : ''}$key',
              ttl: clubCacheLifetime,
              missTtl: clubMissCacheLifetime,
              fetch: () async {
                for (final league in leagues) {
                  final Map<String, dynamic> teams;
                  try {
                    teams = await leagueTeams(league.slug);
                  } on CourtboardHttpException catch (error) {
                    if (error.isNotFound) continue;
                    rethrow;
                  }
                  final club = findClubIn(teams, league, name);
                  if (club != null) return club;
                }
                return null;
              },
              encode: (value) => value?.toJson(),
              decode: (json) =>
                  json == null ? null : EspnSoccerClub.fromJson(json),
            ))
        .value;
  }

  /// A csapatlistából (`sports[].leagues[].teams[].team`) a [teamName]
  /// klub, szigorú, normalizált névegyezéssel ([normalizeFootballTeamName]:
  /// ékezet, kis-/nagybetű, FC/CF/… toldalék nélkül) a teljes névre, a rövid
  /// névre, a névre, a rövidítésre és a „hely + név” alakra. Részleges név
  /// („Inter”) nem egyezik. Női bajnokságban a női utótagokat („Femení”,
  /// „Women”) mindkét oldalon figyelmen kívül hagyja.
  static EspnSoccerClub? findClubIn(
    Map<String, dynamic> payload,
    EspnSoccerLeague league,
    String teamName,
  ) {
    String keyOf(String value) => normalizeFootballTeamName(
      league.womens ? EspnSoccerTeam.withoutWomenSuffix(value) : value,
    );
    final expected = keyOf(teamName);
    if (expected.isEmpty) return null;
    for (final team in _teamsOf(payload)) {
      final id = jsonString(team['id']);
      if (id == null) continue;
      final location = jsonString(team['location']);
      final nickname = jsonString(team['name']);
      final names = [
        for (final field in const [
          'displayName',
          'shortDisplayName',
          'name',
          'abbreviation',
        ])
          ?jsonString(team[field]),
        if (location != null && nickname != null && location != nickname)
          '$location $nickname',
      ];
      if (names.any((value) => keyOf(value) == expected)) {
        return EspnSoccerClub(
          league: league.slug,
          leagueLabel: league.label,
          id: id,
          displayName: jsonString(team['displayName']) ?? teamName.trim(),
          abbreviation: jsonString(team['abbreviation']) ?? '',
        );
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _teamsOf(Map<String, dynamic> payload) => [
    for (final sport in jsonMapList(payload['sports']))
      for (final league in jsonMapList(sport['leagues']))
        for (final entry in jsonMapList(league['teams']))
          jsonMap(entry['team']),
  ];

  /// A csapatlista csak a feloldáshoz szükséges mezőkkel (a logók és
  /// linkek nélkül), az eredeti szerkezetben.
  static Map<String, dynamic> _trimTeams(Map<String, dynamic> payload) => {
    'sports': [
      {
        'leagues': [
          {
            'teams': [
              for (final team in _teamsOf(payload))
                {
                  'team': {
                    for (final field in const [
                      'id',
                      'displayName',
                      'shortDisplayName',
                      'name',
                      'location',
                      'abbreviation',
                    ])
                      if (team[field] != null) field: team[field],
                  },
                },
            ],
          },
        ],
      },
    ],
  };

  /// A klub lejátszott mérkőzései minden sorozatból (bajnokság, kupák,
  /// felkészülési meccsek), a legújabb elöl; [clubResultsCacheLifetime]
  /// ideig gyorsítótárból, hibánál a régebbi lista is visszajön.
  Future<List<EspnSoccerGame>> clubResults(
    EspnSoccerClub club, {
    bool forceRefresh = false,
  }) async =>
      (await _client
              .cache(cacheNamespace)
              .getOrFetch<List<EspnSoccerGame>>(
                'results_${club.id}',
                ttl: clubResultsCacheLifetime,
                forceRefresh: forceRefresh,
                fetch: () async =>
                    parseClubResults(await _clubSchedule(club), club),
                encode: (value) => {
                  'games': [for (final game in value) game.toJson()],
                },
                decode: (json) => [
                  for (final raw in jsonList(jsonMap(json)['games']))
                    ?EspnSoccerGame.fromJson(raw),
                ],
              ))
          .value;

  /// A klub közelgő mérkőzései, a legközelebbi elöl;
  /// [clubFixturesCacheLifetime] ideig gyorsítótárból, hibánál a régebbi
  /// lista is visszajön.
  Future<List<EspnScheduledGame>> clubFixtures(
    EspnSoccerClub club, {
    bool forceRefresh = false,
  }) async =>
      (await _client
              .cache(cacheNamespace)
              .getOrFetch<List<EspnScheduledGame>>(
                'fixtures_${club.id}',
                ttl: clubFixturesCacheLifetime,
                forceRefresh: forceRefresh,
                fetch: () async => parseClubFixtures(
                  await _clubSchedule(club, fixtures: true),
                  club,
                ),
                encode: (value) => {
                  'games': [for (final game in value) game.toJson()],
                },
                decode: (json) => [
                  for (final raw in jsonList(jsonMap(json)['games']))
                    ?EspnScheduledGame.fromJson(raw),
                ],
              ))
          .value;

  /// A csapatmenetrend: elsőként az összes sorozatot tartalmazó
  /// `soccer/all/teams/{id}/schedule`, ha az 404-et vagy üres listát ad,
  /// akkor a bajnokságé (`soccer/{liga}/teams/{id}/schedule`).
  Future<Map<String, dynamic>> _clubSchedule(
    EspnSoccerClub club, {
    bool fixtures = false,
  }) async {
    final query = fixtures ? const {'fixture': 'true'} : null;
    Map<String, dynamic>? all;
    try {
      all = await _client.espnSoccerSite(
        'all/teams/${club.id}/schedule',
        query,
      );
      if (jsonList(all['events']).isNotEmpty) return all;
    } on CourtboardHttpException catch (error) {
      if (!error.isNotFound) rethrow;
    }
    try {
      return await _client.espnSoccerSite(
        '${club.league}/teams/${club.id}/schedule',
        query,
      );
    } on CourtboardHttpException {
      if (all != null) return all;
      rethrow;
    }
  }

  static bool _isOwn(Map<String, dynamic> competitor, EspnSoccerClub club) {
    final team = jsonMap(competitor['team']);
    final id = jsonString(competitor['id']) ?? jsonString(team['id']);
    if (id != null) return id == club.id;
    final name = jsonString(team['displayName']) ?? '';
    return name.isNotEmpty && footballTeamNamesMatch(club.displayName, name);
  }

  static String? _competitionOf(Map<String, dynamic> event) =>
      jsonString(jsonMap(event['league'])['name']);

  /// Egy csapatmenetrend (`events[]`) befejezett mérkőzései a [club]
  /// szemszögéből, a legújabb elöl (az ESPN nem rendezi őket). Csak a
  /// befejezett státuszok ([finishedStatuses], illetve `completed` +
  /// `post`) maradnak; a törölt / elhalasztott meccsek kimaradnak. A
  /// hosszabbítást és a tizenegyespárbajt a státusz és a `shootoutScore`
  /// jelzi.
  static List<EspnSoccerGame> parseClubResults(
    Map<String, dynamic> payload,
    EspnSoccerClub club,
  ) {
    int? intOf(Object? value) => switch (value) {
      num() => value.round(),
      _ => num.tryParse(jsonString(value) ?? '')?.round(),
    };
    int? scoreOf(Map<String, dynamic> competitor) {
      final raw = competitor['score'];
      if (raw is Map) {
        return intOf(raw['value']) ?? intOf(raw['displayValue']);
      }
      return intOf(raw);
    }

    int? shootoutOf(Map<String, dynamic> competitor) {
      final raw = competitor['score'];
      return (raw is Map ? intOf(raw['shootoutScore']) : null) ??
          intOf(competitor['shootoutScore']);
    }

    final games = <EspnSoccerGame>[];
    for (final event in jsonMapList(payload['events'])) {
      final competitions = jsonMapList(event['competitions']);
      if (competitions.isEmpty) continue;
      final competition = competitions.first;
      final statusType = jsonMap(jsonMap(competition['status'])['type']);
      final status = jsonString(statusType['name']) ?? '';
      if (_voidStatusParts.any(status.contains)) continue;
      final finished =
          finishedStatuses.contains(status) ||
          (statusType['completed'] == true &&
              (jsonString(statusType['state']) ?? 'post') == 'post');
      if (!finished) continue;
      final date = DateTime.tryParse(
        jsonString(competition['date']) ?? jsonString(event['date']) ?? '',
      );
      if (date == null) continue;
      final competitors = jsonMapList(competition['competitors']);
      final own = competitors.where((c) => _isOwn(c, club)).firstOrNull;
      if (own == null) continue;
      final other = competitors.where((c) => !identical(c, own)).firstOrNull;
      if (other == null) continue;
      final ownScore = scoreOf(own);
      final otherScore = scoreOf(other);
      if (ownScore == null || otherScore == null) continue;
      final ownShootout = shootoutOf(own);
      final otherShootout = shootoutOf(other);
      final penalties =
          ownShootout != null &&
          otherShootout != null &&
          (status.contains('PEN') || ownShootout + otherShootout > 0);
      final opponent = jsonMap(other['team']);
      games.add(
        EspnSoccerGame(
          date: date,
          eventId: jsonString(event['id']) ?? jsonString(competition['id']),
          opponent:
              jsonString(opponent['displayName']) ??
              jsonString(opponent['name']) ??
              'Ismeretlen',
          teamScore: ownScore,
          opponentScore: otherScore,
          home: jsonString(own['homeAway']) == 'home',
          competition: _competitionOf(event) ?? club.leagueLabel,
          league: jsonString(jsonMap(event['league'])['slug']) ?? club.league,
          ownShootout: penalties ? ownShootout : null,
          opponentShootout: penalties ? otherShootout : null,
          afterExtraTime:
              !penalties && (status.contains('AET') || status.endsWith('_ET')),
        ),
      );
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    return games;
  }

  /// Egy `schedule?fixture=true` válasz még le nem játszott mérkőzései a
  /// [club] szemszögéből, időrendben; a befejezett, törölt és elhalasztott
  /// meccsek kimaradnak. A sorozat a mérkőzés saját bajnoksága / kupája.
  static List<EspnScheduledGame> parseClubFixtures(
    Map<String, dynamic> payload,
    EspnSoccerClub club,
  ) => EspnScheduleRepository.parseEvents(
    payload,
    competitionLabel: (event) => _competitionOf(event) ?? club.leagueLabel,
    isOwnTeam: (competitor) => _isOwn(competitor, club),
  );
}
