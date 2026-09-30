/// A Courtboard belépési pontja: az indítás előtti betöltés (állapot,
/// API-kulcsok, asztali integráció), a szolgáltatások összeállítása és az
/// app futtatása `ProviderScope`-ban. Az alkalmazás felépítését lásd:
/// `lib/app/` (providerek: `providers.dart`, útvonalak: `router.dart`).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:courtboard/app/app_services.dart';
import 'package:courtboard/app/courtboard_app.dart';
import 'package:courtboard/app/providers.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/desktop/desktop_integration.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/desktop/toast_notifications.dart';
import 'package:courtboard/shared/format.dart';
import 'package:courtboard/shared/images.dart';

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
  final services = AppServices(
    stateStore: store,
    playlistFile: File(AppPaths.playlistFile),
    apiKeyStore: keyStore,
    appVersion: version,
    updateChecker: version == null
        ? null
        : UpdateChecker(currentVersion: version),
    desktop: desktop,
    notificationService: notifications,
    startupRegistration: desktop?.startup,
  );
  runApp(
    ProviderScope(
      overrides: courtboardOverrides(
        services: services,
        launch: AppLaunchState(
          initialState: keys.state,
          apiKeys: keys.keys,
          secureStorageAvailable: keys.secureStorageAvailable,
        ),
      ),
      retry: noAutomaticRetry,
      child: const CourtboardRoot(),
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
