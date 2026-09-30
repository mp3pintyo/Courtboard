import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
import 'data/athlete_watcher.dart';
import 'data/basketball_reference.dart';
import 'data/basketball_season.dart';
import 'data/darts.dart';
import 'data/espn_athletes.dart';
import 'data/espn_schedule.dart';
import 'data/espn_liga_f.dart';
import 'data/football_data.dart';
import 'data/football_data_players.dart';
import 'data/football_season.dart';
import 'data/football_season_repository.dart';
import 'data/head_to_head.dart';
import 'data/file_util.dart';
import 'data/http_service.dart';
import 'data/ics_export.dart';
import 'data/json_file_cache.dart';
import 'data/local_state.dart';
import 'data/live_scores.dart';
import 'data/live_tennis.dart';
import 'data/match_timeline.dart';
import 'data/multi_provider.dart';
import 'data/news.dart';
import 'data/notification_settings.dart';
import 'data/notifications.dart';
import 'data/provider_catalog.dart';
import 'data/ranking_history.dart';
import 'data/rate_limit.dart';
import 'data/rapidapi_wnba.dart';
import 'data/secret_store.dart';
import 'data/sports_api.dart';
import 'data/upcoming_events.dart';
import 'data/update_checker.dart';
import 'data/wehoop_wnba.dart';
import 'data/window_geometry.dart';
import 'data/youtube_playlist.dart';
import 'data/youtube_video_id.dart';
import 'desktop/desktop_integration.dart';
import 'desktop/startup_registration.dart';
import 'desktop/toast_notifications.dart';
import 'insights/compare.dart';
import 'insights/follow_feed.dart';
import 'insights/form_data.dart';
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
part 'ui/profile_form.dart';
part 'ui/profile_nfl.dart';
part 'ui/match_details.dart';
part 'ui/live_scores_ui.dart';
part 'ui/athlete_directory_settings.dart';
part 'ui/calendar.dart';
part 'ui/updates.dart';
part 'ui/desktop_settings.dart';
part 'ui/video_library.dart';
part 'ui/follow_feed_page.dart';
part 'ui/compare_page.dart';
part 'ui/data_sources.dart';
part 'ui/navigation.dart';
part 'ui/shortcuts.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // `--minimized`: Windows-indításkor a tálcára, ablak nélkül.
  final launch = LaunchOptions.parse(arguments);
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
  final version = await _runningVersion();
  // Ablakhelyzet, tálcaikon, bezárás kezelése és értesítések (Windows).
  final desktop = Platform.isWindows
      ? await WindowsDesktopIntegration.initialize(
          savedGeometry: keys.state.windowGeometry,
          startHidden: launch.minimized,
          closeToTray: keys.state.closeToTray,
        )
      : null;
  final NotificationService notifications = Platform.isWindows
      ? ToastNotificationService.lazy(
          fallback: desktop != null && desktop.trayAvailable
              ? TrayBalloonNotificationService(desktop.windowHandle)
              : null,
        )
      : const DisabledNotificationService();
  runApp(
    CourtboardApp(
      initialState: keys.state,
      stateStore: store,
      playlistFile: File(AppPaths.playlistFile),
      apiKeys: keys.keys,
      apiKeyStore: keyStore,
      secureStorageAvailable: keys.secureStorageAvailable,
      appVersion: version,
      updateChecker: version == null
          ? null
          : UpdateChecker(currentVersion: version),
      desktop: desktop,
      notificationService: notifications,
      startupRegistration: desktop?.startup,
    ),
  );
  // Az első képkocka után jelenik meg az ablak a mentett helyen (a futtató
  // már nem mutatja magától, így nincs ugrás / villanás).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Timer(const Duration(milliseconds: 30), () {
      if (desktop != null) {
        unawaited(desktop.revealInitialWindow());
      } else if (Platform.isWindows) {
        unawaited(showWindowFallback());
      }
    });
  });
}

/// A futó alkalmazás verziója a Windows-exe verzióadataiból (fordításkor a
/// pubspec.yaml `version` mezőjéből kerül bele); hibánál `null`, ilyenkor
/// a frissítés-ellenőrzés kimarad.
Future<String?> _runningVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    return SemanticVersion.tryParse(version) == null ? null : version;
  } catch (_) {
    return null;
  }
}
