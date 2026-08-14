import 'package:flutter/material.dart';
import 'package:myapp/theme/theme_tokens.dart';

Future<bool> confirmClearChat(BuildContext context) async {
  final tokens = context.themeTokens;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: tokens.panel,
          title: Text(
            'Clear this conversation?',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: Text(
            'This will remove the chat history on this device and start a '
            'fresh conversation.',
            style: TextStyle(color: tokens.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: TextStyle(color: tokens.mutedText)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear chat'),
            ),
          ],
        ),
      ) ??
      false;
}
