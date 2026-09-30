import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'common_ui.dart';
import 'components.dart';
import 'format.dart';
import 'images.dart';
import 'theme/courtboard_theme.dart';

import 'data/api_key_id.dart';
import 'data/api_key_store.dart';
import 'data/api_sports.dart';
import 'data/app_paths.dart';
import 'data/athlete_highlights.dart';
import 'data/basketball_reference.dart';
import 'data/basketball_season.dart';
import 'data/darts.dart';
import 'data/espn_liga_f.dart';
import 'data/football_data.dart';
import 'data/football_data_players.dart';
import 'data/football_season.dart';
import 'data/football_season_repository.dart';
import 'data/file_util.dart';
import 'data/http_service.dart';
import 'data/json_file_cache.dart';
import 'data/local_state.dart';
import 'data/live_tennis.dart';
import 'data/multi_provider.dart';
import 'data/news.dart';
import 'data/provider_catalog.dart';
import 'data/rate_limit.dart';
import 'data/rapidapi_wnba.dart';
import 'data/secret_store.dart';
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
part 'ui/shortcuts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Magyar dátumformátumok (hónapnevek) az első képkocka előtt.
  ensureHungarianDateFormatting();
  // Az állapotot egyszer, a futtatás előtt töltjük be, hogy a mentett téma
  // már az első képkockán érvényes legyen (nincs zöld villanás).
  // A 0.9.0 előtti, szétszórt gyorsítótár-könyvtárak egyszeri rendbetétele.
  unawaited(AppPaths.migrateLegacyCaches());
  // A nagyon régi, lemezen tárolt képek takarítása (háttérben).
  unawaited(ImageDiskCache.shared.pruneExpired());
  final store = LocalStateStore();
  // Az API-kulcsok a Windows biztonságos tárolójából jönnek; a régi,
  // titkosítatlan JSON-kulcsok itt költöznek át (lásd [ApiKeyStore.load]).
  final keyStore = ApiKeyStore();
  final keys = await keyStore.load(await store.load(), stateStore: store);
  runApp(
    CourtboardApp(
      initialState: keys.state,
      stateStore: store,
      playlistFile: File(AppPaths.playlistFile),
      apiKeys: keys.keys,
      apiKeyStore: keyStore,
      secureStorageAvailable: keys.secureStorageAvailable,
    ),
  );
}
