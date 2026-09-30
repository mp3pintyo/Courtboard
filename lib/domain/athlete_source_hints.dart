/// Sportolónkénti adatforrás-tippek: melyik bajnokság / csapatváltozat
/// adatait kell keresni az általános (klubnév szerinti) keresés helyett.
///
/// A 0.13.0 előtt ezt a nevekbe égetett különleges eset döntötte el
/// („Aitana Bonmatí” → Liga F); most a sportolóval együtt mentett adat.
/// Az ESPN-bajnokságkód bármely ott szereplő (női vagy férfi) focicsapatnál
/// működik: a csapatot a sportoló csapatneve (vagy az [espnTeam]) adja.
library;

import 'package:courtboard/domain/sport.dart';

class AthleteSourceHints {
  const AthleteSourceHints({
    this.womensTeam = false,
    this.espnLeague,
    this.competition,
    this.espnTeam,
    this.teamLabel,
  });

  /// Nincs tipp: az általános, klubnév szerinti források élnek.
  static const none = AthleteSourceHints();

  /// A spanyol női bajnokság (Liga F, ESPN `esp.w.1`); a csapatot a
  /// sportoló csapatneve adja.
  static const ligaF = AthleteSourceHints(
    womensTeam: true,
    espnLeague: ligaFLeague,
    competition: 'Liga F',
  );

  /// Az alapból követett Aitana Bonmatí tippje: Liga F, a Barcelona női
  /// csapatával (az ESPN-ben „Barcelona”), „FC Barcelona Femení” néven.
  static const ligaFBarcelona = AthleteSourceHints(
    womensTeam: true,
    espnLeague: ligaFLeague,
    competition: 'Liga F',
    espnTeam: 'Barcelona',
    teamLabel: 'FC Barcelona Femení',
  );

  /// Az ESPN Liga F-kódja.
  static const ligaFLeague = 'esp.w.1';

  /// A sportoló a klub női csapatában játszik.
  final bool womensTeam;

  /// ESPN ligakód (például `esp.w.1`) a menetrendhez és az élő
  /// eredményekhez; `null` esetén az általános forrás.
  final String? espnLeague;

  /// A bajnokság megjelenített neve (például „Liga F”).
  final String? competition;

  /// A csapat neve az ESPN-ben (például `Barcelona`), ha eltér a
  /// sportolónál megadott csapatnévtől; `null` esetén a sportoló csapata.
  final String? espnTeam;

  /// A csapat megjelenített neve a profilon (például „FC Barcelona
  /// Femení”); `null` esetén a sportoló csapatából képzett név.
  final String? teamLabel;

  bool get isEmpty =>
      !womensTeam &&
      espnLeague == null &&
      competition == null &&
      espnTeam == null &&
      teamLabel == null;

  /// A Liga F-forrásokat (ESPN `esp.w.1`) kell használni.
  bool get isLigaF => espnLeague == ligaFLeague;

  /// Van-e ESPN-bajnokságkód: a csapat eredményei és menetrendje az ESPN
  /// bajnoki scoreboardjából jönnek.
  bool get hasEspnLeague => espnLeague != null;

  Map<String, dynamic> toJson() => {
    if (womensTeam) 'womensTeam': true,
    if (espnLeague != null) 'espnLeague': espnLeague,
    if (competition != null) 'competition': competition,
    if (espnTeam != null) 'espnTeam': espnTeam,
    if (teamLabel != null) 'teamLabel': teamLabel,
  };

  factory AthleteSourceHints.fromJson(Object? json) {
    if (json is! Map) return none;
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    final hints = AthleteSourceHints(
      womensTeam: json['womensTeam'] == true,
      espnLeague: text(json['espnLeague']),
      competition: text(json['competition']),
      espnTeam: text(json['espnTeam']),
      teamLabel: text(json['teamLabel']),
    );
    return hints.isEmpty ? none : hints;
  }

  /// Új sportoló felvételekor a csapatnévből kikövetkeztethető tipp: a
  /// „Femení” / „Femenino” utótagú (spanyol női) focicsapat a Liga F-ben
  /// játszik. Egyébként nincs tipp.
  static AthleteSourceHints inferFromTeam(Sport sport, String team) =>
      sport == Sport.football && team.toLowerCase().contains('femen')
      ? ligaF
      : none;

  /// **Csak migrációhoz**: a 0.13.0 előtti mentésekben még nem volt tipp,
  /// és a Liga F-profilt a név („Aitana Bonmatí”) vagy a csapat („Femení”)
  /// döntötte el. A régi szabály itt, egyetlen helyen él tovább, és csak a
  /// tipp nélküli, régi bejegyzésekre fut le egyszer. Aitana a korábbi
  /// (barcelonai) adatokat kapja, a többi „Femení” csapat a saját nevével
  /// keresett Liga F-tippet.
  static AthleteSourceHints migrateLegacy({
    required Sport? sport,
    required String name,
    required String team,
  }) {
    if (sport != Sport.football) return none;
    if (name.toLowerCase().contains('aitana bonmat')) return ligaFBarcelona;
    return team.toLowerCase().contains('femen') ? ligaF : none;
  }

  @override
  bool operator ==(Object other) =>
      other is AthleteSourceHints &&
      other.womensTeam == womensTeam &&
      other.espnLeague == espnLeague &&
      other.competition == competition &&
      other.espnTeam == espnTeam &&
      other.teamLabel == teamLabel;

  @override
  int get hashCode =>
      Object.hash(womensTeam, espnLeague, competition, espnTeam, teamLabel);

  @override
  String toString() => 'AthleteSourceHints(${toJson()})';
}
