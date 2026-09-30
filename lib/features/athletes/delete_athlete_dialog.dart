/// „Sportoló törlése” megerősítő párbeszédablak.
library;

import 'package:flutter/material.dart';

import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

class DeleteAthleteDialog extends StatelessWidget {
  const DeleteAthleteDialog({
    super.key,
    required this.athlete,
    required this.onConfirm,
  });

  final Athlete athlete;

  /// A törlés jóváhagyása; a párbeszédablak utána bezárul.
  final VoidCallback onConfirm;

  static Future<void> show(
    BuildContext context, {
    required Athlete athlete,
    required VoidCallback onConfirm,
  }) => showDialog<void>(
    context: context,
    builder: (_) => DeleteAthleteDialog(athlete: athlete, onConfirm: onConfirm),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('delete-athlete-dialog'),
    icon: Icon(Icons.delete_outline, color: context.cb.error),
    title: const Text('Sportoló törlése'),
    content: Text(
      'Biztosan törlöd őt a követettek közül?\n\n${athlete.name}\n\n'
      'A jegyzet és a mentett videók megmaradnak, a sportoló bármikor '
      'újra felvehető.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Mégse'),
      ),
      FilledButton(
        key: const Key('delete-athlete-confirm'),
        style: FilledButton.styleFrom(
          backgroundColor: context.cb.error,
          foregroundColor: context.cb.isDark
              ? const Color(0xFF3B0A08)
              : Colors.white,
        ),
        onPressed: () {
          onConfirm();
          Navigator.pop(context);
        },
        child: const Text('Törlés'),
      ),
    ],
  );
}
