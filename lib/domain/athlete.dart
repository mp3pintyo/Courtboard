/// A követett sportoló modellje és a hozzá tartozó tiszta segédfüggvények.
library;

import 'dart:ui' show Color;

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/domain/athlete_id.dart';
import 'package:courtboard/domain/athlete_source_hints.dart';
import 'package:courtboard/domain/sport.dart';

export 'package:courtboard/domain/athlete_id.dart';
export 'package:courtboard/domain/athlete_source_hints.dart';
export 'package:courtboard/domain/sport.dart';

class Athlete {
  const Athlete({
    required this.name,
    required this.sport,
    required this.team,
    required this.country,
    required this.photoUrl,
    required this.accent,
    this.seasonLabel = '',
    this.seasonValue = '',
    this.primaryLabel = '',
    this.primaryValue = '',
    this.metrics = const [],
    this.matches = const [],
    this.isCustom = false,
    this.sourceHints = AthleteSourceHints.none,
    this._id,
  });

  final String? _id;

  /// Stabil azonosító (az útvonalakban: `/sportolok/<id>`). A saját
  /// sportolóknál a mentett érték, egyébként a névből képzett slug
  /// ([athleteIdFor]).
  String get id => _id ?? athleteIdFor(name);

  final String name;
  final Sport sport;
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

  /// Adatforrás-tippek (például Liga F a női csapatnál); lásd
  /// [AthleteSourceHints].
  final AthleteSourceHints sourceHints;

  bool get showsTeam =>
      sport.hasTeam &&
      team.trim().isNotEmpty &&
      team.trim().toLowerCase() != 'nincs megadva';

  String get sportAndTeam =>
      showsTeam ? '${sport.shortLabel} · $team' : sport.shortLabel;

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

/// A sportolólista rendezése a Beállításokban választott mód szerint
/// (`custom`: a lista saját sorrendje marad).
List<Athlete> sortAthletes(List<Athlete> athletes, String mode) {
  final result = List<Athlete>.from(athletes);
  int byName(Athlete a, Athlete b) =>
      normalizeAthleteName(a.name).compareTo(normalizeAthleteName(b.name));
  switch (mode) {
    case 'name':
      result.sort(byName);
    case 'sport':
      result.sort((a, b) {
        // A felirat ábécérendje (a 0.13.0 előtti szöveges rendezéssel azonos).
        final sport = a.sport.shortLabel.compareTo(b.sport.shortLabel);
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
