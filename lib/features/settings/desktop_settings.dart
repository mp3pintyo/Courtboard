import 'dart:async';
import 'package:flutter/material.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/notification_settings.dart';
import 'package:courtboard/features/settings/settings_card.dart';

/// Kapcsolósor a Beállítások kártyáin (a kártya dekorált Container, ezért
/// a csempe saját, átlátszó Material-t kap a tintához).
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.settingKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Key settingKey;
  final String title;
  final String? subtitle;
  final bool value;

  /// `null`: letiltott kapcsoló.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SwitchListTile(
      key: settingKey,
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    ),
  );
}

/// Beállítások → Értesítések: fő kapcsoló, típusok, gyakoriság, csendes
/// órák, szüneteltetés állapota és „Teszt értesítés”.
class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.alertAthleteCount,
    required this.serviceDescription,
    this.pausedUntil,
    this.onResume,
    this.onTest,
  });

  final NotificationSettings settings;
  final ValueChanged<NotificationSettings> onChanged;

  /// Hány követett sportolónál van bekapcsolva az értesítés a profilon.
  final int alertAthleteCount;

  /// A megjelenítés módja („Windows-értesítés”); `null`, ha nem elérhető.
  final String? serviceDescription;

  /// A szüneteltetés vége, ha éppen szünetel.
  final DateTime? pausedUntil;
  final VoidCallback? onResume;

  /// `null`, ha az értesítések nem érhetők el (például tesztben).
  final Future<bool> Function()? onTest;

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  bool _testing = false;

  Future<void> _test() async {
    final test = widget.onTest;
    if (test == null || _testing) return;
    setState(() => _testing = true);
    try {
      final ok = await test();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Teszt értesítés elküldve.'
                : 'Az értesítés nem jeleníthető meg. Ellenőrizd a Windows '
                      'értesítési beállításait.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _pickQuietTime({required bool start}) async {
    final settings = widget.settings;
    final minutes = start
        ? settings.quietStartMinutes
        : settings.quietEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: start ? 'Csendes órák kezdete' : 'Csendes órák vége',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final value = picked.hour * 60 + picked.minute;
    widget.onChanged(
      start
          ? settings.copyWith(quietStartMinutes: value)
          : settings.copyWith(quietEndMinutes: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final enabled = settings.enabled;
    final paused = widget.pausedUntil;
    final count = widget.alertAthleteCount;
    ValueChanged<bool>? typeToggle(
      NotificationSettings Function(bool value) update,
    ) => enabled ? (value) => widget.onChanged(update(value)) : null;

    return SettingsCard(
      title: 'Értesítések',
      description:
          'A Courtboard a háttérben (a tálcán is) figyeli azokat a '
          'sportolókat, akiknél a profilon bekapcsoltad az „Értesítés” '
          'gombot, és Windows-értesítést küld.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingSwitch(
            settingKey: const Key('notifications-enabled-setting'),
            title: 'Értesítések bekapcsolva',
            subtitle: count == 0
                ? 'Még egy sportolónál sincs bekapcsolva az értesítés.'
                : '$count sportolónál bekapcsolva.',
            value: enabled,
            onChanged: (value) =>
                widget.onChanged(settings.copyWith(enabled: value)),
          ),
          const SizedBox(height: 12),
          Text('TÍPUSOK', style: context.text.labelMedium),
          _SettingSwitch(
            settingKey: const Key('notify-match-start-setting'),
            title: 'Meccskezdés',
            subtitle: '15 perccel a kezdés előtt, eseményenként egyszer.',
            value: settings.matchStart,
            onChanged: typeToggle(
              (value) => settings.copyWith(matchStart: value),
            ),
          ),
          _SettingSwitch(
            settingKey: const Key('notify-results-setting'),
            title: 'Új eredmény',
            subtitle:
                'NBA-, WNBA- és NFL-játékosoknál az ESPN menetrendjéből; a mai '
                'végeredmény az élő scoreboardról gyorsabban jelez (focinál is).',
            value: settings.results,
            onChanged: typeToggle((value) => settings.copyWith(results: value)),
          ),
          _SettingSwitch(
            settingKey: const Key('notify-live-scores-setting'),
            title: 'Élő eredményváltozás',
            subtitle:
                'Zajló meccsen az állás változásakor, ellenőrzésenként '
                'legfeljebb egyszer. Alapból kikapcsolva.',
            value: settings.liveScores,
            onChanged: typeToggle(
              (value) => settings.copyWith(liveScores: value),
            ),
          ),
          _SettingSwitch(
            settingKey: const Key('notify-news-setting'),
            title: 'Új hír',
            subtitle: 'Több hír esetén egy összesítő értesítés.',
            value: settings.news,
            onChanged: typeToggle((value) => settings.copyWith(news: value)),
          ),
          const SizedBox(height: 16),
          Text('ELLENŐRZÉS GYAKORISÁGA', style: context.text.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            key: const Key('notify-interval-setting'),
            segments: [
              for (final minutes in NotificationSettings.intervalOptions)
                ButtonSegment(value: minutes, label: Text('$minutes perc')),
            ],
            selected: {settings.intervalMinutes},
            onSelectionChanged: enabled
                ? (values) => widget.onChanged(
                    settings.copyWith(intervalMinutes: values.first),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          const CourtboardNote(
            'Az adatforrások gyorsítótára és kvótája érvényes: a hírek '
            'legfeljebb 20 percenként, az eredmények óránként (az élő '
            'scoreboard 45 mp-es gyorsítótárral), a menetrend 6 óránként '
            'frissül a háttérben.',
          ),
          const SizedBox(height: 12),
          _SettingSwitch(
            settingKey: const Key('quiet-hours-setting'),
            title: 'Csendes órák',
            subtitle: 'Ebben az időszakban nem jelenik meg értesítés.',
            value: settings.quietHours,
            onChanged: enabled
                ? (value) =>
                      widget.onChanged(settings.copyWith(quietHours: value))
                : null,
          ),
          if (settings.quietHours)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('quiet-start-setting'),
                  onPressed: enabled
                      ? () => unawaited(_pickQuietTime(start: true))
                      : null,
                  icon: const Icon(Icons.bedtime_outlined, size: 18),
                  label: Text(
                    'Kezdete: ${formatMinuteOfDay(settings.quietStartMinutes)}',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('quiet-end-setting'),
                  onPressed: enabled
                      ? () => unawaited(_pickQuietTime(start: false))
                      : null,
                  icon: const Icon(Icons.wb_twilight_outlined, size: 18),
                  label: Text(
                    'Vége: ${formatMinuteOfDay(settings.quietEndMinutes)}',
                  ),
                ),
              ],
            ),
          if (paused != null) ...[
            const SizedBox(height: 12),
            Row(
              key: const Key('notifications-paused'),
              children: [
                Icon(
                  Icons.notifications_paused_outlined,
                  size: 18,
                  color: context.cb.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Szüneteltetve eddig: '
                    '${formatMinuteOfDay(paused.hour * 60 + paused.minute)}',
                    style: context.text.bodyMedium,
                  ),
                ),
                TextButton(
                  key: const Key('notifications-resume'),
                  onPressed: widget.onResume,
                  child: const Text('Folytatás'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('notification-test'),
                onPressed: widget.onTest != null && !_testing
                    ? () => unawaited(_test())
                    : null,
                icon: _testing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: const Text('Teszt értesítés'),
              ),
              if (widget.serviceDescription != null)
                Text(
                  'Megjelenítés: ${widget.serviceDescription}',
                  style: context.text.bodySmall,
                ),
            ],
          ),
          if (widget.onTest == null) ...[
            const SizedBox(height: 8),
            const CourtboardNote(
              'Az értesítések csak a telepített Windows-alkalmazásban '
              'jelennek meg.',
            ),
          ],
        ],
      ),
    );
  }
}

/// Beállítások → Tálca és indítás.
class DesktopSettingsCard extends StatelessWidget {
  const DesktopSettingsCard({
    super.key,
    required this.closeToTray,
    required this.onCloseToTrayChanged,
    required this.launchAtStartup,
    required this.onLaunchAtStartupChanged,
    required this.startMinimized,
    required this.onStartMinimizedChanged,
    this.startupUnavailableReason,
    this.desktopAvailable = true,
  });

  final bool closeToTray;

  /// `null`: nincs tálcaikon (a kapcsoló letiltva).
  final ValueChanged<bool>? onCloseToTrayChanged;
  final bool launchAtStartup;
  final ValueChanged<bool>? onLaunchAtStartupChanged;
  final bool startMinimized;
  final ValueChanged<bool>? onStartMinimizedChanged;

  /// Ha a Windows-zal indítás itt nem állítható, ennek oka.
  final String? startupUnavailableReason;

  /// Hamis, ha az app nem asztali Windows-folyamatként fut (tesztben).
  final bool desktopAvailable;

  @override
  Widget build(BuildContext context) => SettingsCard(
    title: 'Tálca és indítás',
    description:
        'A Courtboard megjegyzi az ablak méretét, helyét és teljes méretű '
        'állapotát. A tálcán futva is küld értesítést.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingSwitch(
          settingKey: const Key('close-to-tray-setting'),
          title: 'Bezáráskor a tálcára kicsinyítés',
          subtitle:
              'Az ablak bezárása után az app a tálcán fut tovább; kilépés a '
              'tálcaikon menüjéből.',
          value: closeToTray,
          onChanged: onCloseToTrayChanged,
        ),
        _SettingSwitch(
          settingKey: const Key('launch-at-startup-setting'),
          title: 'Indítás a Windows-zal',
          subtitle: 'Bejelentkezéskor automatikusan elindul.',
          value: launchAtStartup,
          onChanged: onLaunchAtStartupChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: _SettingSwitch(
            settingKey: const Key('start-minimized-setting'),
            title: 'Tálcára minimalizálva indul',
            subtitle: 'Windows-indításkor ablak nélkül, a tálcán indul.',
            value: startMinimized,
            onChanged: launchAtStartup ? onStartMinimizedChanged : null,
          ),
        ),
        if (!desktopAvailable) ...[
          const SizedBox(height: 8),
          const CourtboardNote(
            'Ezek a beállítások csak a telepített Windows-alkalmazásban '
            'érhetők el.',
          ),
        ] else if (startupUnavailableReason != null) ...[
          const SizedBox(height: 8),
          CourtboardNote(startupUnavailableReason!),
        ],
      ],
    ),
  );
}
