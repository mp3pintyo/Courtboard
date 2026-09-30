import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/friendly_error.dart';
import 'data/url_safety.dart';
import 'format.dart';
import 'theme/courtboard_theme.dart';

export 'data/friendly_error.dart' show friendlyError;

/// Külső webcím megnyitása a rendszer alapértelmezett böngészőjében.
///
/// Csak `http`/`https` címet nyit meg ([isSafeWebUrl]); minden más esetben,
/// illetve sikertelen indításkor magyar nyelvű SnackBar jelenik meg.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void fail(String message) =>
      messenger?.showSnackBar(SnackBar(content: Text(message)));

  if (!isSafeWebUrl(url)) {
    fail('Ez a hivatkozás nem nyitható meg biztonságosan.');
    return;
  }
  try {
    final opened = await launchUrl(
      Uri.parse(url.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) fail('A hivatkozás nem nyitható meg.');
  } catch (_) {
    fail('A hivatkozás nem nyitható meg.');
  }
}

/// Helyi fájl (például egy `.ics` naptárfájl) megnyitása a hozzá rendelt
/// alapértelmezett alkalmazással (Outlook, Naptár…). Sikertelen indításkor
/// magyar SnackBar jelenik meg; a visszatérési érték a siker.
Future<bool> openLocalFile(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final opened = await launchUrl(Uri.file(path));
    if (opened) return true;
  } catch (_) {
    // Lent jelezzük.
  }
  messenger?.showSnackBar(
    const SnackBar(
      content: Text(
        'A fájl nem nyitható meg. Van a gépen naptáralkalmazás az .ics fájlokhoz?',
      ),
    ),
  );
  return false;
}

/// Egységes hibaállapot: rövid, felhasználóbarát üzenet és opcionális
/// „Újrapróbálás” gomb. Nyers kivételszöveget soha nem jelenít meg.
class CourtboardErrorState extends StatelessWidget {
  const CourtboardErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  /// Hibaüzenet közvetlenül egy kivételből, [friendlyError] szerint.
  CourtboardErrorState.fromError(
    Object error, {
    Key? key,
    VoidCallback? onRetry,
    bool compact = false,
  }) : this(
         key: key,
         message: friendlyError(error),
         onRetry: onRetry,
         compact: compact,
       );

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 18, color: cb.error),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: cb.textPrimary),
          ),
        ),
      ],
    );
    final retry = onRetry == null
        ? null
        : TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Újrapróbálás'),
          );
    if (compact || retry == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [text, ?retry],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 6), retry],
      ),
    );
  }
}

/// Apró, halvány megjegyzés (például egy adatforrás figyelmeztetése).
class CourtboardNote extends StatelessWidget {
  const CourtboardNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.info_outline,
            size: 15,
            color: context.cb.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: context.text.bodySmall)),
      ],
    ),
  );
}

/// Rövid frissességi felirat, például „Frissítve: 14:32 · gyorsítótárból”.
/// Nem mai adatnál a dátum is megjelenik (`szept. 28. 14:32`).
String freshnessLabel(
  DateTime fetchedAt, {
  bool fromCache = false,
  bool stale = false,
  DateTime? now,
}) {
  final local = fetchedAt.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final time = formatTime(local);
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  final when = sameDay ? time : '${formatShortDate(local)} $time';
  final origin = stale
      ? ' · régebbi mentett adat'
      : fromCache
      ? ' · gyorsítótárból'
      : '';
  return 'Frissítve: $when$origin';
}

/// Apró, halvány frissességi sor kártyafejlécek alá.
class FreshnessNote extends StatelessWidget {
  const FreshnessNote({
    super.key,
    required this.fetchedAt,
    this.fromCache = false,
    this.stale = false,
  });

  final DateTime fetchedAt;
  final bool fromCache;
  final bool stale;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        stale ? Icons.history_rounded : Icons.schedule_rounded,
        size: 14,
        color: stale ? context.cb.warning : context.cb.textMuted,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          freshnessLabel(fetchedAt, fromCache: fromCache, stale: stale),
          style: context.text.bodySmall,
        ),
      ),
    ],
  );
}
