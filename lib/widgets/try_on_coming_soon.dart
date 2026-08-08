import 'package:flutter/material.dart';

const tryOnComingSoonAction = '__try_on_coming_soon__';

bool isTryOnComingSoonAction(Object? value) {
  return (value ?? '').toString().trim() == tryOnComingSoonAction;
}

Future<void> showTryOnComingSoon(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const TryOnComingSoonDialog(),
  );
}

class TryOnComingSoonDialog extends StatelessWidget {
  const TryOnComingSoonDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Try-On'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('See how your looks come together on you.'),
          SizedBox(height: 16),
          Text('Coming soon', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
