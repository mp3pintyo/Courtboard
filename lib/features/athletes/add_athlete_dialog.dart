/// „Sportoló hozzáadása” párbeszédablak (Ctrl+N).
library;

import 'package:flutter/material.dart';

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// Új saját sportoló felvétele; a kitöltött [CustomAthlete]-tel tér vissza
/// (`Navigator.pop`), megszakításkor `null`-lal.
class AddAthleteDialog extends StatefulWidget {
  const AddAthleteDialog({
    super.key,
    required this.existingNames,
    required this.resolveImage,
  });

  final List<String> existingNames;
  final Future<String?> Function(String name) resolveImage;

  /// A párbeszédablak megnyitása.
  static Future<CustomAthlete?> show(
    BuildContext context, {
    required List<String> existingNames,
    required Future<String?> Function(String name) resolveImage,
  }) => showDialog<CustomAthlete>(
    context: context,
    builder: (_) => AddAthleteDialog(
      existingNames: existingNames,
      resolveImage: resolveImage,
    ),
  );

  @override
  State<AddAthleteDialog> createState() => _AddAthleteDialogState();
}

class _AddAthleteDialogState extends State<AddAthleteDialog> {
  final _name = TextEditingController();
  final _team = TextEditingController();
  Sport _sport = Sport.nba;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _team.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add meg a sportoló nevét.');
      return;
    }
    final normalized = normalizeAthleteName(name);
    if (widget.existingNames.any(
      (existing) => normalizeAthleteName(existing) == normalized,
    )) {
      setState(
        () => _error = 'Ez a sportoló már szerepel a követettek között.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? imageUrl;
    try {
      imageUrl = await widget.resolveImage(name);
    } catch (_) {
      // A képkeresés hibája nem akadályozza a hozzáadást: monogram jelenik meg.
      imageUrl = null;
    }
    if (!mounted) return;
    final team = _sport.hasTeam ? _team.text.trim() : '';
    Navigator.pop(
      context,
      CustomAthlete(
        name: name,
        sport: _sport.jsonValue,
        team: team,
        photoUrl: imageUrl ?? '',
        sourceHints: AthleteSourceHints.inferFromTeam(_sport, team),
      ),
    );
  }

  /// Egyéni sportágnál a csapatmező helyén megjelenő magyarázat.
  static String _noTeamHint(Sport sport) => switch (sport) {
    Sport.tennis => 'A teniszezőkhöz nem kell csapatot megadni.',
    _ => 'A dartsjátékosokhoz nem kell csapatot megadni.',
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sportoló hozzáadása'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('add-athlete-name'),
            controller: _name,
            autofocus: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Név'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Sport>(
            style: context.text.bodyLarge,
            initialValue: _sport,
            decoration: const InputDecoration(labelText: 'Sportág'),
            items: Sport.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.shortLabel),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _sport = value ?? _sport),
          ),
          if (_sport.hasTeam) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _team,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Csapat / klub'),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(_noTeamHint(_sport), style: context.text.bodySmall),
          ],
          const SizedBox(height: 10),
          Text(
            _busy
                ? 'Profilkép keresése…'
                : 'A profilképet a rendszer háttérben próbálja feloldani; sikertelen esetben monogram jelenik meg.',
            style: context.text.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('add-athlete-error'),
              style: context.text.bodySmall?.copyWith(
                color: context.cb.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Mégse'),
      ),
      FilledButton.icon(
        key: const Key('add-athlete-submit'),
        onPressed: _busy ? null : _submit,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Hozzáadás'),
      ),
    ],
  );
}
