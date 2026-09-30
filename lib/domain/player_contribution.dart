/// A sportoló saját pontszerzése / hozzájárulása egy lejátszott
/// mérkőzésen: fociban gól és gólpassz, kosárlabdában pont, NFL-ben
/// touchdown és pont (a passzolt touchdown külön, mert az nem a
/// játékos saját pontja).
///
/// Csak valós, meccsenkénti adatból készül: ha a forrás nem ismeri a
/// játékos adott meccsét, nincs hozzájárulás (`null`), és a felület sem
/// mutat semmit — soha nem „0”-t.
library;

/// A hozzájárulás sportága (a megjelenítés és az ikon ebből adódik).
enum ContributionKind { football, basketball, nfl }

class PlayerContribution {
  /// Foci: saját gólok (öngól nélkül) és gólpasszok.
  const PlayerContribution.football({
    this.goals = 0,
    this.assists = 0,
    this.athlete = '',
    this.source = '',
  }) : kind = ContributionKind.football,
       points = 0,
       touchdowns = 0,
       passingTouchdowns = 0;

  /// Kosárlabda: a játékos pontjai.
  const PlayerContribution.basketball({
    required this.points,
    this.athlete = '',
    this.source = '',
  }) : kind = ContributionKind.basketball,
       goals = 0,
       assists = 0,
       touchdowns = 0,
       passingTouchdowns = 0;

  /// NFL: a játékos saját touchdownjai (futás, elkapás, visszahordás) és
  /// összes pontja (6 × TD + rúgóként 3 × mezőnygól + extra pont). A
  /// [passingTouchdowns] (irányítónál a passzolt TD) nem számít bele.
  const PlayerContribution.nfl({
    this.touchdowns = 0,
    this.points = 0,
    this.passingTouchdowns = 0,
    this.athlete = '',
    this.source = '',
  }) : kind = ContributionKind.nfl,
       goals = 0,
       assists = 0;

  final ContributionKind kind;
  final int goals;
  final int assists;
  final int points;
  final int touchdowns;
  final int passingTouchdowns;

  /// A sportoló neve a képernyőolvasó mondatához (üresen „A játékos”).
  final String athlete;

  /// Az adatforrás (például „FotMob”, „ESPN”), ha ismert.
  final String source;

  /// Van-e kiemelendő saját pontszerzés (gól/gólpassz, pont).
  bool get hasBadge => switch (kind) {
    ContributionKind.football => goals > 0 || assists > 0,
    ContributionKind.basketball => points > 0,
    ContributionKind.nfl => points > 0,
  };

  /// Van-e bármi megjeleníthető (kiemelés vagy mellékes megjegyzés).
  bool get isVisible => hasBadge || note != null;

  /// A kiemelés szövege („2 gól · 1 gólpassz”, „24 pont”, „2 TD · 12
  /// pont”), vagy `null`, ha nincs mit kiemelni.
  String? get badgeText {
    if (!hasBadge) return null;
    return switch (kind) {
      ContributionKind.football => [
        if (goals > 0) '$goals gól',
        if (assists > 0) '$assists gólpassz',
      ].join(' · '),
      ContributionKind.basketball => '$points pont',
      ContributionKind.nfl =>
        touchdowns > 0 ? '$touchdowns TD · $points pont' : '$points pont',
    };
  }

  /// Mellékes, halvány megjegyzés: irányítónál a passzolt touchdownok
  /// („3 passzolt TD”) — ezek nem a játékos saját pontjai.
  String? get note => kind == ContributionKind.nfl && passingTouchdowns > 0
      ? '$passingTouchdowns passzolt TD'
      : null;

  /// Egyetlen mondat a képernyőolvasónak, például „Juhász Dorka 24
  /// pontot szerzett”.
  String get semanticsLabel {
    final who = athlete.trim().isEmpty ? 'A játékos' : athlete.trim();
    final parts = <String>[];
    switch (kind) {
      case ContributionKind.football:
        if (goals > 0 && assists > 0) {
          parts.add('$goals gólt szerzett és $assists gólpasszt adott');
        } else if (goals > 0) {
          parts.add('$goals gólt szerzett');
        } else if (assists > 0) {
          parts.add('$assists gólpasszt adott');
        }
      case ContributionKind.basketball:
        if (points > 0) parts.add('$points pontot szerzett');
      case ContributionKind.nfl:
        if (touchdowns > 0) {
          parts.add('$touchdowns touchdownt szerzett, összesen $points pontot');
        } else if (points > 0) {
          parts.add('$points pontot szerzett');
        }
        if (passingTouchdowns > 0) {
          parts.add('$passingTouchdowns touchdownpasszt adott');
        }
    }
    return parts.isEmpty ? '' : '$who ${parts.join(', ')}';
  }

  /// Ugyanez a hozzájárulás a sportoló nevével (a képernyőolvasóhoz).
  PlayerContribution withAthlete(String name) => switch (kind) {
    ContributionKind.football => PlayerContribution.football(
      goals: goals,
      assists: assists,
      athlete: name,
      source: source,
    ),
    ContributionKind.basketball => PlayerContribution.basketball(
      points: points,
      athlete: name,
      source: source,
    ),
    ContributionKind.nfl => PlayerContribution.nfl(
      touchdowns: touchdowns,
      points: points,
      passingTouchdowns: passingTouchdowns,
      athlete: name,
      source: source,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is PlayerContribution &&
      other.kind == kind &&
      other.goals == goals &&
      other.assists == assists &&
      other.points == points &&
      other.touchdowns == touchdowns &&
      other.passingTouchdowns == passingTouchdowns &&
      other.athlete == athlete &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
    kind,
    goals,
    assists,
    points,
    touchdowns,
    passingTouchdowns,
    athlete,
    source,
  );

  @override
  String toString() =>
      'PlayerContribution(${kind.name}, ${badgeText ?? '-'}'
      '${note == null ? '' : ', $note'})';
}
