/// A követett sportolók átalakítása az adatréteg eseménycélpontjaivá.
library;

import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/domain/athlete.dart';

extension AthleteEventsTarget on Athlete {
  /// A sportoló naptár-, élőeredmény- és figyelőcélpontja (név, sportág,
  /// csapat és adatforrás-tippek).
  UpcomingEventsTarget get eventsTarget => UpcomingEventsTarget(
    name: name,
    sport: sport,
    team: showsTeam ? team : '',
    sourceHints: sourceHints,
  );
}

/// A követett sportolók naptárcélpontjai.
List<UpcomingEventsTarget> calendarTargets(Iterable<Athlete> athletes) => [
  for (final athlete in athletes) athlete.eventsTarget,
];
