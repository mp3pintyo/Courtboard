/// „YouTube-videó hozzáadása” párbeszédablak (a profil videólistájához).
library;

import 'package:flutter/material.dart';

import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/data/youtube_video_id.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

class AddVideoDialog extends StatefulWidget {
  const AddVideoDialog({
    super.key,
    required this.athleteName,
    required this.onSave,
  });

  final String athleteName;

  /// A feloldott videó mentése; hibánál a párbeszédablak nyitva marad.
  final Future<void> Function(SavedYouTubeVideo video) onSave;

  static Future<void> show(
    BuildContext context, {
    required String athleteName,
    required Future<void> Function(SavedYouTubeVideo video) onSave,
  }) => showDialog<void>(
    context: context,
    builder: (_) => AddVideoDialog(athleteName: athleteName, onSave: onSave),
  );

  @override
  State<AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<AddVideoDialog> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final id = YouTubeVideoId.parse(_input.text);
    if (id == null) {
      setState(() => _error = 'Érvénytelen YouTube-link vagy videóazonosító.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final SavedYouTubeVideo video;
    try {
      video = await YouTubeOEmbed.resolve(id, widget.athleteName);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'A YouTube videócíme most nem kérhető le. Próbáld újra később.';
        });
      }
      return;
    }
    try {
      await widget.onSave(video);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'A videó mentése nem sikerült.';
        });
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('YouTube-videó hozzáadása'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _input,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'YouTube link vagy videóazonosító',
              hintText: 'https://youtu.be/… vagy 11 karakteres ID',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
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
