import 'package:flutter/material.dart';

import '../i18n.dart';
import '../settings.dart';
import '../theme.dart';

/// Переключатель языка: латиница, кириллица, русский.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return PopupMenuButton<String>(
      onSelected: AppSettings.instance.setLang,
      itemBuilder: (_) => kLanguages.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 17, color: tone.muted),
            const SizedBox(width: 6),
            Text(kLanguages[AppSettings.instance.lang] ?? '',
                style: TextStyle(fontSize: 12.5, color: tone.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
