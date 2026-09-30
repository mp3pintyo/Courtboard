/// A játékos saját pontszerzése egy-egy lejátszott meccsen, a meglévő
/// forrásokból számolva:
///
/// * foci: a FotMob játékos-meccslistája (`recentMatches`: gól, gólpassz),
///   az ESPN-összefoglaló (`rosters` statisztika, tartalékként a
///   `keyEvents` góllövői és gólpasszadói) és az OpenLigaDB góllövői;
/// * NFL: az ESPN játékos-meccsnaplójának touchdown- és rúgóoszlopai.
///
/// Soha nem talál ki értéket: ha a forrás nem ismeri a játékos adott
/// meccsét, az eredmény `null`.
library;

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_names.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/domain/player_contribution.dart';

// ---------------------------------------------------------------------------
// Foci
// ---------------------------------------------------------------------------

/// „2–1” / „2-1 (h.u.)” → (2, 1); eredmény nélkül (`–`) `null`.
(int, int)? parseScorePair(String score) {
  final match = RegExp(r'^\s*(\d+)\s*[–-]\s*(\d+)').firstMatch(score);
  if (match == null) return null;
  return (int.parse(match[1]!), int.parse(match[2]!));
}

/// A FotMob-meccslistából a csapatmeccs-sorhoz illő meccs, vagy `null`.
///
/// Párosítás: a kezdés legfeljebb egy (UTC-)naptári nap eltérésű (a csak
/// dátumot adó forrás helyi éjfele és az időzónák miatt), és az ellenfél
/// neve egyezik (a „(W)”, „Femenino”… utótagok nélkül). Ha az ellenfél
/// neve eltér (például „Dux Logroño” / „Logroño United”), csak akkor
/// párosít, ha pontosan egy meccs kezdődött legfeljebb 3 órán belül
/// ugyanazzal az eredménnyel.
FootballMatchForm? findFootballMatchForm(
  Iterable<FootballMatchForm> forms, {
  required DateTime date,
  required String opponent,
  int? teamScore,
  int? opponentScore,
}) {
  final near = [
    for (final form in forms)
      if (_utcDayDistance(form.date, date) <= 1) form,
  ];
  Duration gap(FootballMatchForm form) => form.date.difference(date).abs();
  final named = [
    for (final form in near)
      if (footballOpponentsMatch(opponent, form.opponent)) form,
  ]..sort((a, b) => gap(a).compareTo(gap(b)));
  if (named.isNotEmpty) return named.first;
  if (teamScore == null || opponentScore == null) return null;
  final sameGame = [
    for (final form in near)
      if (gap(form) <= const Duration(hours: 3) &&
          form.teamScore == teamScore &&
          form.opponentScore == opponentScore)
        form,
  ];
  return sameGame.length == 1 ? sameGame.single : null;
}

/// Két forrás ellenfélneve ugyanarra a csapatra utal-e (a zárójeles és a
/// női csapatot jelölő utótagok nélkül, mindkét irányban).
bool footballOpponentsMatch(String first, String second) {
  final a = _plainTeamName(first);
  final b = _plainTeamName(second);
  if (a.isEmpty || b.isEmpty) return false;
  return footballTeamNamesMatch(a, b) || footballTeamNamesMatch(b, a);
}

String _plainTeamName(String value) => EspnSoccerTeam.withoutWomenSuffix(
  value.replaceAll(RegExp(r'\([^)]*\)'), ' '),
).trim();

int _utcDayDistance(DateTime a, DateTime b) {
  final x = a.toUtc();
  final y = b.toUtc();
  return DateTime.utc(
    x.year,
    x.month,
    x.day,
  ).difference(DateTime.utc(y.year, y.month, y.day)).inDays.abs();
}

/// A FotMob-meccs gólja és gólpassza.
PlayerContribution footballContributionFromForm(
  FootballMatchForm form, {
  String athlete = '',
}) => PlayerContribution.football(
  goals: form.goals,
  assists: form.assists,
  athlete: athlete,
  source: 'FotMob',
);

/// A játékos gólja és gólpassza egy mérkőzés-idővonalból, vagy `null`, ha
/// nem szerzett egyiket sem (vagy a forrás nem ismeri).
///
/// Ha az idővonal teljes játékosstatisztikával jött (ESPN `rosters`), az
/// dönt; különben a gólesemények: a játékos neve a gólszerzőnél (öngól
/// soha nem számít a szerzőjének) vagy a gólpasszadónál. A [teamHome]
/// (a játékos csapata hazai-e) megadásakor csak a saját csapat oldala
/// számít, így az ellenfél névrokona nem téveszt meg.
PlayerContribution? footballContributionFromTimeline(
  MatchTimeline timeline,
  String athlete, {
  bool? teamHome,
}) {
  bool ownSide(bool? home) =>
      teamHome == null || home == null || home == teamHome;
  final PlayerContribution contribution;
  if (timeline.hasPlayerStats) {
    final player = findAthleteByName(
      [
        for (final player in timeline.players)
          if (ownSide(player.home)) player,
      ],
      athlete,
      (player) => player.name,
    );
    if (player == null) return null;
    contribution = PlayerContribution.football(
      goals: player.goals,
      assists: player.assists,
      source: timeline.source,
    );
  } else {
    bool isAthlete(String name) =>
        name.isNotEmpty &&
        (athleteNamesMatch(name, athlete) || athleteNameMatches(athlete, name));
    var goals = 0;
    var assists = 0;
    for (final event in timeline.events) {
      if (!event.type.isGoal || event.type == TimelineEventType.ownGoal) {
        continue;
      }
      if (!ownSide(event.home)) continue;
      if (isAthlete(event.player)) goals++;
      if (isAthlete(event.assist)) assists++;
    }
    contribution = PlayerContribution.football(
      goals: goals,
      assists: assists,
      source: timeline.source,
    );
  }
  return contribution.hasBadge ? contribution : null;
}

// ---------------------------------------------------------------------------
// NFL
// ---------------------------------------------------------------------------

/// A játékos saját touchdownjainak oszlopai az ESPN-meccsnaplóban. Élőben
/// ellenőrizve (2026-09-30): `rushingTouchdowns`, `receivingTouchdowns`
/// (RB/WR/QB), `interceptionTouchdowns` (védő). A visszahordási
/// touchdownok oszlopai a meccsnaplóban nem szerepelnek; ha egyszer
/// megjelennek, ezek a nevek számítanak.
const _scoringTouchdownStats = [
  'rushingTouchdowns',
  'receivingTouchdowns',
  'interceptionTouchdowns',
  'kickReturnTouchdowns',
  'puntReturnTouchdowns',
  'fumblesTouchdowns',
];

/// Egy NFL-meccs saját pontszerzése: touchdownok (6 pont), rúgónál a
/// `fieldGoalsMade-fieldGoalAttempts` és `extraPointsMade-extraPointAttempts`
/// oszlopból 3 × FG + XP (az ESPN `totalKickingPoints` oszlopa néha hibás,
/// csak tartalék). A passzolt TD (`passingTouchdowns`) külön érték. A
/// kétpontos kísérletet a meccsnapló nem adja. `null`, ha a napló egyik
/// oszlopot sem tartalmazza.
PlayerContribution? nflContribution(EspnGameLogEntry game) {
  int? count(String name) => game.stat(name)?.round();
  var known = false;
  var touchdowns = 0;
  for (final name in _scoringTouchdownStats) {
    final value = count(name);
    if (value == null) continue;
    known = true;
    touchdowns += value;
  }
  final fieldGoals = game.madeAttempted('fieldGoalsMade-fieldGoalAttempts');
  final extraPoints = game.madeAttempted('extraPointsMade-extraPointAttempts');
  final kicking = fieldGoals != null || extraPoints != null
      ? 3 * (fieldGoals?.$1 ?? 0) + (extraPoints?.$1 ?? 0)
      : count('totalKickingPoints');
  final passing = count('passingTouchdowns');
  if (!known && kicking == null && passing == null) return null;
  return PlayerContribution.nfl(
    touchdowns: touchdowns,
    points: touchdowns * 6 + (kicking ?? 0),
    passingTouchdowns: passing ?? 0,
    source: 'ESPN',
  );
}
