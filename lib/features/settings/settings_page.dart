/// A Beállítások oldal.
library;

import 'package:flutter/material.dart';

import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/features/settings/settings_card.dart';
import 'package:courtboard/features/settings/shortcut_help.dart';
import 'package:courtboard/features/settings/updates.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.theme,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.overviewSort,
    required this.athleteSort,
    required this.onThemeChanged,
    required this.onOverviewSortChanged,
    required this.onAthleteSortChanged,
    this.appVersion,
    this.autoUpdateCheck = true,
    this.onAutoUpdateCheckChanged,
    this.updateResult,
    this.onCheckUpdatesNow,
    this.notificationSettings,
    this.desktopSettings,
  });

  /// Az „Értesítések” kártya (a shell állítja össze).
  final Widget? notificationSettings;

  /// A „Tálca és indítás” kártya (a shell állítja össze).
  final Widget? desktopSettings;

  final String? appVersion;
  final bool autoUpdateCheck;
  final ValueChanged<bool>? onAutoUpdateCheckChanged;
  final UpdateCheckResult? updateResult;
  final Future<UpdateCheckResult?> Function()? onCheckUpdatesNow;

  final String theme;
  final String themeMode;
  final ValueChanged<String> onThemeModeChanged;
  final String overviewSort;
  final String athleteSort;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onOverviewSortChanged;
  final ValueChanged<String> onAthleteSortChanged;

  static const _sortOptions = {
    'custom': 'Saját sorrend',
    'name': 'Név (A–Z)',
    'sport': 'Sportág, majd név',
    'team': 'Csapat, majd név',
  };

  @override
  Widget build(BuildContext context) => Container(
    color: context.cb.canvas,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 800 ? 20 : 34),
    child: ListView(
      children: [
        const PageHeader(
          title: 'Beállítások',
          subtitle: 'A módosításokat a Courtboard automatikusan elmenti.',
        ),
        const SizedBox(height: 28),
        SettingsCard(
          title: 'Megjelenés',
          description:
              'Válaszd ki a világos vagy sötét módot és az alkalmazás kiemelőszínét.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MÓD', style: context.text.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('theme-mode-setting'),
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Rendszer'),
                  ),
                  ButtonSegment(
                    value: 'light',
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Világos'),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Sötét'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (values) =>
                    onThemeModeChanged(values.first),
              ),
              const SizedBox(height: 20),
              Text('KIEMELŐSZÍN', style: context.text.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('accent-setting'),
                segments: const [
                  ButtonSegment(
                    value: 'green',
                    icon: Icon(Icons.eco_outlined),
                    label: Text('Zöld téma'),
                  ),
                  ButtonSegment(
                    value: 'burgundy',
                    icon: Icon(Icons.wine_bar_outlined),
                    label: Text('Bordó téma'),
                  ),
                ],
                selected: {theme},
                onSelectionChanged: (values) => onThemeChanged(values.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: 'Sportolók rendezése',
          description:
              'Az Áttekintés és a Sportolók lista sorrendje külön állítható. A saját sorrendet a Sportolók oldalon, húzással módosíthatod.',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                style: context.text.bodyLarge,
                key: const Key('overview-sort-setting'),
                initialValue: overviewSort,
                decoration: const InputDecoration(
                  labelText: 'Áttekintés – sportolók sorrendje',
                ),
                items: _sortOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onOverviewSortChanged(value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                style: context.text.bodyLarge,
                key: const Key('athlete-sort-setting'),
                initialValue: athleteSort,
                decoration: const InputDecoration(
                  labelText: 'Sportolók oldal – lista sorrendje',
                ),
                items: _sortOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onAthleteSortChanged(value);
                },
              ),
            ],
          ),
        ),
        if (notificationSettings != null) ...[
          const SizedBox(height: 16),
          notificationSettings!,
        ],
        if (desktopSettings != null) ...[
          const SizedBox(height: 16),
          desktopSettings!,
        ],
        const SizedBox(height: 16),
        const SettingsCard(
          title: 'Billentyűparancsok',
          description:
              'A leggyakoribb műveletek egér nélkül is elérhetők. '
              'A gombok eszköztippje is jelzi a gyorsbillentyűt.',
          child: ShortcutList(),
        ),
        const SizedBox(height: 16),
        UpdateSettingsCard(
          currentVersion: appVersion,
          autoCheck: autoUpdateCheck,
          onAutoCheckChanged: onAutoUpdateCheckChanged ?? (_) {},
          result: updateResult,
          onCheckNow: onCheckUpdatesNow,
        ),
      ],
    ),
  );
}
