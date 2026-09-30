import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/friendly_error.dart';
import 'data/url_safety.dart';

export 'data/friendly_error.dart' show friendlyError;

const _commonMuted = Color(0xFF73766C);

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
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 18, color: _commonMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(message, style: const TextStyle(color: _commonMuted)),
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
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline, size: 14, color: _commonMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: _commonMuted),
          ),
        ),
      ],
    ),
  );
}

/// Rövid frissességi felirat, például „Frissítve: 14:32 · gyorsítótárból”.
/// Nem mai adatnál a dátum is megjelenik (`09.28. 14:32`).
String freshnessLabel(
  DateTime fetchedAt, {
  bool fromCache = false,
  bool stale = false,
  DateTime? now,
}) {
  final local = fetchedAt.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final sameDay = local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  final when = sameDay ? time : '${two(local.month)}.${two(local.day)}. $time';
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
  Widget build(BuildContext context) => Text(
        freshnessLabel(fetchedAt, fromCache: fromCache, stale: stale),
        style: const TextStyle(fontSize: 11, color: _commonMuted),
      );
}
