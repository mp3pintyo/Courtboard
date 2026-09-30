/// Sportágankénti profil-leírók egy helyen.
///
/// A 0.13.0 előtt a profiloldal `if (athlete.sport == 'NBA') …` láncokból
/// rakta össze az élő adatkártyákat, a sablonszöveget és a kivételeket
/// (például a Liga F-et). Most minden sportág egy [SportProfileSpec]-et kap
/// a [SportProfileSpec.registry]-ben; új sportág felvételekor itt (és a
/// [Sport] enumban) kell bővíteni.
library;

import 'package:flutter/widgets.dart';

import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/domain/athlete_targets.dart';
import 'package:courtboard/features/compare/compare_data.dart';
import 'package:courtboard/features/profile/profile_form.dart';
import 'package:courtboard/features/profile/sports/profile_api_basketball.dart';
import 'package:courtboard/features/profile/sports/profile_darts.dart';
import 'package:courtboard/features/profile/sports/profile_football.dart';
import 'package:courtboard/features/profile/sports/profile_nfl.dart';
import 'package:courtboard/features/profile/sports/profile_tennis.dart';
import 'package:courtboard/features/profile/sports/profile_wnba.dart';

export 'package:courtboard/features/profile/profile_form.dart'
    show FormChartKind;

/// A sportoló „Élő adatok” kártyái a profilon (az adatforrásokat és az
/// API-kulcsokat a kártyák maguk olvassák a providerekből).
typedef ProfileCardsBuilder = List<Widget> Function(Athlete athlete);

/// Az egymás elleni mérleg jellege.
enum HeadToHeadKind {
  /// Csapatsport: „Legutóbbi egymás elleni meccsek”.
  team,

  /// Egyéni sport: „Egymás elleni mérleg”.
  individual,
}

/// A generikus „Szezon összesítő” blokk sablonja (csak azoknál a
/// sportágaknál, amelyeknek nincs saját összesítő kártyájuk).
class SportTemplateContent {
  const SportTemplateContent({
    required this.title,
    required this.description,
    required this.indicators,
  });

  final String title;
  final String description;

  /// A formajelzők neve (valós adat nélkül csak címkeként jelenik meg).
  final List<String> indicators;
}

class SportProfileSpec {
  const SportProfileSpec({
    required this.sport,
    required this.liveCards,
    required this.template,
    required this.formChart,
    required this.headToHead,
    this.showsGenericSummary = false,
  });

  final Sport sport;

  /// Az „Élő adatok” szakasz kártyái (sorrendben).
  final ProfileCardsBuilder liveCards;

  /// A generikus szezonsablon szövegei.
  final SportTemplateContent template;

  /// Milyen formagörbét rajzolnak az élő adatkártyák (a [SportFormChart]
  /// ez alapján választ).
  final FormChartKind formChart;

  /// Az egymás elleni mérleg jellege a naptárban és a profilon.
  final HeadToHeadKind headToHead;

  /// Igaz, ha a sportágnak nincs saját szezonösszesítő kártyája, ezért a
  /// profil a generikus „Szezon összesítő” és „Utóbbi mérkőzések”
  /// blokkot mutatja.
  final bool showsGenericSummary;

  /// Van-e szezonadat-összehasonlítás (Összehasonlítás oldal).
  bool get supportsCompare => sportSupportsComparison(sport);

  /// A sportoló közelgő eseményeinek forrása (az adatforrás-tippekkel).
  UpcomingSource upcomingSourceFor(Athlete athlete) =>
      UpcomingSource.forTarget(athlete.eventsTarget);

  /// Az élő eredmények scoreboardja; `null`, ha a sportághoz nincs.
  LiveFeed? liveFeedFor(Athlete athlete) =>
      LiveFeed.forTarget(athlete.eventsTarget);

  static SportProfileSpec of(Sport sport) => registry[sport]!;

  /// A sportág formagörbéjének fajtája.
  static FormChartKind formChartOf(Sport sport) => of(sport).formChart;

  static const Map<Sport, SportProfileSpec> registry = {
    Sport.nba: SportProfileSpec(
      sport: Sport.nba,
      liveCards: _nbaCards,
      template: _basketballTemplate,
      formChart: FormChartKind.basketballGameLog,
      headToHead: HeadToHeadKind.team,
    ),
    Sport.wnba: SportProfileSpec(
      sport: Sport.wnba,
      liveCards: _wnbaCards,
      template: _basketballTemplate,
      formChart: FormChartKind.basketballGameLog,
      headToHead: HeadToHeadKind.team,
    ),
    Sport.football: SportProfileSpec(
      sport: Sport.football,
      liveCards: _footballCards,
      template: SportTemplateContent(
        title: 'TÁMADÓ HATÁS',
        description:
            'Gólveszély, kulcspasszok és labdabiztosság az utóbbi meccseken.',
        indicators: ['Gólveszély', 'Kreativitás', 'Passzjáték'],
      ),
      formChart: FormChartKind.footballMatches,
      headToHead: HeadToHeadKind.team,
    ),
    Sport.darts: SportProfileSpec(
      sport: Sport.darts,
      liveCards: _dartsCards,
      template: SportTemplateContent(
        title: 'DOBÓFORMA',
        description: '3-dart átlag, kiszállózás és maximumok alakulása.',
        indicators: ['Átlag', 'Checkout', '180-asok'],
      ),
      formChart: FormChartKind.dartsResults,
      headToHead: HeadToHeadKind.individual,
      showsGenericSummary: true,
    ),
    Sport.tennis: SportProfileSpec(
      sport: Sport.tennis,
      liveCards: _tennisCards,
      template: SportTemplateContent(
        title: 'TENISZPROFIL',
        description:
            'Ranglista, játékosprofil, élő állás és következő mérkőzések.',
        indicators: ['Ranglista', 'Borítás', 'Mérkőzésritmus'],
      ),
      formChart: FormChartKind.tennisRanking,
      headToHead: HeadToHeadKind.individual,
    ),
    Sport.nfl: SportProfileSpec(
      sport: Sport.nfl,
      liveCards: _nflCards,
      template: SportTemplateContent(
        title: 'TELJESÍTMÉNYPROFIL',
        description: 'A szerepkörhöz igazított, egységes heti teljesítmény.',
        indicators: ['Hatékonyság', 'Explozivitás', 'Kulcsjátékok'],
      ),
      formChart: FormChartKind.nflGameLog,
      headToHead: HeadToHeadKind.team,
    ),
  };

  static const _basketballTemplate = SportTemplateContent(
    title: 'JÁTÉKINTELLIGENCIA',
    description: 'A pontszerzés, játékirányítás és lepattanózás formagörbéje.',
    indicators: ['Dobóforma', 'Játékszervezés', 'Védekezés'],
  );

  static List<Widget> _nbaCards(Athlete athlete) => [
    ApiSportsCard(
      sport: athlete.sport,
      athleteName: athlete.name,
      teamName: athlete.team,
      accent: athlete.accent,
    ),
    NbaSeasonSummaryCard(athleteName: athlete.name, accent: athlete.accent),
  ];

  static List<Widget> _nflCards(Athlete athlete) => [
    ApiSportsCard(
      sport: athlete.sport,
      athleteName: athlete.name,
      teamName: athlete.team,
      accent: athlete.accent,
    ),
    NflPlayerCard(athleteName: athlete.name, accent: athlete.accent),
    NflTeamFormCard(
      athleteName: athlete.name,
      teamName: athlete.team,
      accent: athlete.accent,
    ),
  ];

  /// Foci: az ESPN-bajnokságkóddal rendelkező profil (például Liga F, női
  /// csapat) a csapat bajnoki eredményeit kapja a klubcsapat-kártyák
  /// helyett; a szezonösszesítő mindkettőnél.
  static List<Widget> _footballCards(Athlete athlete) {
    final espnTeam = athlete.sport == Sport.football
        ? EspnSoccerTeam.fromHints(athlete.sourceHints, athlete.team)
        : null;
    return [
      if (espnTeam != null)
        EspnSoccerTeamCard(
          athleteName: athlete.name,
          team: espnTeam,
          accent: athlete.accent,
        )
      else ...[
        FootballDataCard(
          athleteName: athlete.name,
          teamName: athlete.team,
          accent: athlete.accent,
        ),
        FootballDataPlayerCard(
          athleteName: athlete.name,
          teamName: athlete.team,
          accent: athlete.accent,
        ),
      ],
      FootballSeasonSummaryCard(
        athleteName: athlete.name,
        teamName: athlete.team,
        accent: athlete.accent,
      ),
    ];
  }

  static List<Widget> _wnbaCards(Athlete athlete) => [
    WnbaWehoopCard(athleteName: athlete.name, accent: athlete.accent),
    WnbaBasketballReferenceCard(
      athleteName: athlete.name,
      accent: athlete.accent,
    ),
    WnbaRapidApiCard(athleteName: athlete.name, accent: athlete.accent),
  ];

  static List<Widget> _dartsCards(Athlete athlete) => [
    DartsDataCard(athleteName: athlete.name, accent: athlete.accent),
  ];

  static List<Widget> _tennisCards(Athlete athlete) => [
    TennisDataCard(athleteName: athlete.name, accent: athlete.accent),
  ];
}
