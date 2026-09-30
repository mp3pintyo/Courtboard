/// A Beállítások oldal kártyakerete.
library;

import 'package:flutter/material.dart';

import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleLarge),
            const SizedBox(height: 5),
            Text(
              description,
              style: context.text.bodyMedium?.copyWith(
                color: context.cb.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    ),
  );
}
