import 'package:flutter/material.dart';

import '../theme.dart';

void showError(BuildContext context, String message) => _show(
      context,
      message,
      Icons.error_outline,
      const Color(0xFF9F1220),
      const Duration(seconds: 5),
    );

void showOk(BuildContext context, String message) => _show(
      context,
      message,
      Icons.check_circle_outline,
      Brand.green,
      const Duration(seconds: 3),
    );

void _show(BuildContext context, String message, IconData icon, Color color, Duration duration) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: color,
      duration: duration,
    ));
}

Future<bool> confirm(BuildContext context, String text, {String? yes, String? no}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(text, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no ?? 'Йўқ')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes ?? 'Ҳа'),
        ),
      ],
    ),
  );
  return ok == true;
}
