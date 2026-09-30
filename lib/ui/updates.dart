part of '../main.dart';

/// Diszkrét sáv a tartalom tetején, ha a GitHubon újabb kiadás érhető el.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.result,
    required this.onDownload,
    required this.onDismiss,
  });

  final UpdateCheckResult result;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final version = result.latest?.version.toString() ?? '';
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Új verzió érhető el: $version',
      child: Material(
        key: const Key('update-banner'),
        color: cb.accentSoft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
          child: Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 18,
                color: cb.readable(cb.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Új verzió érhető el: $version',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: cb.textPrimary,
                  ),
                ),
              ),
              Text('–', style: context.text.bodyMedium),
              TextButton(
                key: const Key('update-banner-download'),
                onPressed: onDownload,
                child: const Text('Letöltés'),
              ),
              IconButton(
                key: const Key('update-banner-dismiss'),
                tooltip: 'Elrejtés',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Beállítások „Frissítések” kártyája: futó verzió, automatikus
/// ellenőrzés kapcsolója és kézi „Keresés most” gomb az eredménnyel.
class _UpdateSettingsCard extends StatefulWidget {
  const _UpdateSettingsCard({
    required this.currentVersion,
    required this.autoCheck,
    required this.onAutoCheckChanged,
    required this.result,
    required this.onCheckNow,
  });

  final String? currentVersion;
  final bool autoCheck;
  final ValueChanged<bool> onAutoCheckChanged;
  final UpdateCheckResult? result;

  /// `null`, ha a futó verzió nem ismert (ilyenkor nincs ellenőrzés).
  final Future<UpdateCheckResult?> Function()? onCheckNow;

  @override
  State<_UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends State<_UpdateSettingsCard> {
  bool _busy = false;

  Future<void> _check() async {
    final check = widget.onCheckNow;
    if (check == null || _busy) return;
    setState(() => _busy = true);
    try {
      await check();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final result = widget.result;
    final latest = result?.latest;
    final canCheck = widget.onCheckNow != null;
    return _SettingsCard(
      title: 'Frissítések',
      description:
          'A Courtboard a GitHubon közzétett kiadásokat figyeli. Letöltést és '
          'telepítést soha nem végez magától: új verziónál csak jelez.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jelenlegi verzió: ${widget.currentVersion ?? 'ismeretlen'}',
            key: const Key('update-current-version'),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: 8),
          // A kártya dekorált Container, ezért a csempe saját (átlátszó)
          // Material-t kap a tintához és a háttérhez.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('auto-update-check-setting'),
              contentPadding: EdgeInsets.zero,
              value: widget.autoCheck,
              onChanged: widget.onAutoCheckChanged,
              title: const Text('Automatikus frissítés-ellenőrzés'),
              subtitle: const Text(
                'Indításkor, legfeljebb 12 óránként egyszer kérdezi le a '
                'GitHub kiadáslistáját.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('update-check-now'),
                onPressed: canCheck && !_busy ? _check : null,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Keresés most'),
              ),
              if (result?.updateAvailable == true && latest != null)
                FilledButton.icon(
                  key: const Key('update-download'),
                  onPressed: () =>
                      unawaited(openExternalUrl(context, latest.htmlUrl)),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Letöltés: ${latest.version}'),
                ),
            ],
          ),
          if (!canCheck) ...[
            const SizedBox(height: 10),
            const CourtboardNote(
              'A futó verzió nem állapítható meg (fejlesztői futtatás), '
              'ezért az ellenőrzés nem érhető el.',
            ),
          ] else if (result != null) ...[
            const SizedBox(height: 12),
            Row(
              key: const Key('update-result'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (result.status) {
                    UpdateStatus.updateAvailable => Icons.new_releases_outlined,
                    UpdateStatus.upToDate => Icons.check_circle_outline,
                    UpdateStatus.failed => Icons.error_outline,
                  },
                  size: 18,
                  color: switch (result.status) {
                    UpdateStatus.updateAvailable => cb.readable(cb.accent),
                    UpdateStatus.upToDate => cb.win,
                    UpdateStatus.failed => cb.error,
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.summary, style: context.text.bodyMedium),
                      if (result.checkedAt != null)
                        Text(
                          freshnessLabel(
                            result.checkedAt!,
                            fromCache: result.fromCache,
                          ).replaceFirst('Frissítve', 'Ellenőrizve'),
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
