import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'data/api_sports.dart';
import 'data/basketball_reference.dart';
import 'data/basketball_season.dart';
import 'data/darts.dart';
import 'data/espn_liga_f.dart';
import 'data/football_data.dart';
import 'data/football_data_players.dart';
import 'data/football_season.dart';
import 'data/football_season_repository.dart';
import 'data/local_state.dart';
import 'data/live_tennis.dart';
import 'data/multi_provider.dart';
import 'data/news.dart';
import 'data/provider_catalog.dart';
import 'data/rapidapi_wnba.dart';
import 'data/sports_api.dart';
import 'data/wehoop_wnba.dart';
import 'data/youtube_playlist.dart';
import 'data/youtube_video_id.dart';
import 'news_page.dart';

part 'ui/app_core.dart';
part 'ui/courtboard_shell.dart';
part 'ui/dashboard.dart';
part 'ui/athlete_profile.dart';
part 'ui/profile_api_basketball.dart';
part 'ui/profile_football.dart';
part 'ui/profile_nba_facts.dart';
part 'ui/profile_tennis.dart';
part 'ui/profile_darts.dart';
part 'ui/profile_wnba.dart';
part 'ui/profile_common.dart';
part 'ui/athlete_directory_settings.dart';
part 'ui/video_library.dart';
part 'ui/data_sources.dart';
part 'ui/navigation.dart';

void main() => runApp(const CourtboardApp());
