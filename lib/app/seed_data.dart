/// Az alapból követett sportolók (első indításkor és a törölt alapsportolók
/// visszaállításakor).
library;

import 'dart:ui' show Color;

import 'package:courtboard/domain/athlete.dart';

/// Alap sportolók kitalált statisztikák nélkül: a számok kizárólag élő
/// adatforrásból érkezhetnek a profiloldalon.
const List<Athlete> seedAthletes = [
  Athlete(
    name: 'Nikola Jokić',
    sport: Sport.nba,
    team: 'Denver Nuggets',
    country: 'Szerbia',
    accent: Color(0xFFE9B86E),
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/7/79/Nikola_Jokic_2023.jpg',
  ),
  Athlete(
    name: 'Aitana Bonmatí',
    sport: Sport.football,
    team: 'FC Barcelona',
    country: 'Spanyolország',
    accent: Color(0xFF9CAAF7),
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/8/8f/Aitana_Bonmat%C3%AD_2023.jpg',
    // A Barcelona női csapata: menetrend, élő eredmény és egymás elleni
    // mérleg a Liga F-ből (ESPN esp.w.1).
    sourceHints: AthleteSourceHints.ligaFBarcelona,
  ),
  Athlete(
    name: 'Luke Humphries',
    sport: Sport.darts,
    team: 'PDC',
    country: 'Anglia',
    accent: Color(0xFFE894A7),
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/6/6e/Luke_Humphries_2023.jpg',
  ),
  Athlete(
    name: 'Caitlin Clark',
    sport: Sport.wnba,
    team: 'Indiana Fever',
    country: 'USA',
    accent: Color(0xFF70B7C5),
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/8/8d/Caitlin_Clark_2024.jpg',
  ),
  Athlete(
    name: 'Saquon Barkley',
    sport: Sport.nfl,
    team: 'Philadelphia Eagles',
    country: 'USA',
    accent: Color(0xFF8ED19C),
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/9/9c/Saquon_Barkley_2023.jpg',
  ),
];

/// A saját (felhasználó által felvett) sportolók azonosító színe; a téma
/// kiemelőszínétől független.
const customAthleteAccent = Color(0xFF9BAF65);
