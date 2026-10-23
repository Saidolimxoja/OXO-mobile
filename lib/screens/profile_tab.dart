import 'package:flutter/material.dart';

import '../i18n.dart';
import '../services/session.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import '../widgets/language_button.dart';
import 'login_screen.dart';

/// Профил: сотрудник и его бўлим, язык, тема, выход.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context) async {
    if (!await confirm(context, t('logoutAsk'), yes: t('yes'), no: t('no'))) return;
    await Session.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final me = Session.instance.me;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (me != null)
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Brand.indigo.withValues(alpha: 0.12),
                  child: Text(
                    me.employee.fullName
                        .split(RegExp(r'\s+'))
                        .where((w) => w.isNotEmpty)
                        .take(2)
                        .map((w) => w[0])
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.indigo),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.employee.fullName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      if (me.employee.post.isNotEmpty)
                        Text(me.employee.post, style: TextStyle(color: tone.muted, fontSize: 13)),
                      if (me.employee.phone.isNotEmpty)
                        Text(me.employee.phone, style: TextStyle(color: tone.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (me?.office != null) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                const IconChip(Icons.apartment_rounded, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('office'), style: TextStyle(color: tone.muted, fontSize: 12.5)),
                      Text(me!.office!.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('language')),
                trailing: const LanguageButton(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('darkTheme')),
                value: AppSettings.instance.themeMode == ThemeMode.dark,
                onChanged: AppSettings.instance.setDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded, color: Brand.red),
          label: Text(t('logout'), style: const TextStyle(color: Brand.red)),
        ),
      ],
    );
  }
}
