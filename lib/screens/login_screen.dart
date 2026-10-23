import 'package:flutter/material.dart';

import '../api/mobile_api.dart';
import '../config.dart';
import '../i18n.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import '../widgets/language_button.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _login.text.trim();
    final password = _password.text;
    if (!AppConfig.configured) {
      showError(context, t('notConfigured'));
      return;
    }
    if (login.isEmpty || password.isEmpty) {
      showError(context, t('loginEmpty'));
      return;
    }

    setState(() => _busy = true);
    try {
      await MobileApi.instance.login(login, password);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final tone = Tone.of(context);
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
              child: Column(
                children: [
                  const Align(alignment: Alignment.centerRight, child: LanguageButton()),
                  const SizedBox(height: 18),
                  const BrandMark(size: 76),
                  const SizedBox(height: 18),
                  Text(t('appName'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  const SizedBox(height: 4),
                  Text(t('appSub'), style: TextStyle(fontSize: 14, color: tone.muted)),
                  const SizedBox(height: 30),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label(t('login'), tone),
                        TextField(
                          controller: _login,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: t('loginHint'),
                            prefixIcon: Icon(Icons.person_outline_rounded, color: tone.muted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label(t('password'), tone),
                        TextField(
                          controller: _password,
                          obscureText: _hidden,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: t('passwordHint'),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: tone.muted),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: tone.muted,
                              ),
                              onPressed: () => setState(() => _hidden = !_hidden),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _busy
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : GradientButton(
                                label: t('enter'),
                                icon: Icons.arrow_forward_rounded,
                                onPressed: _submit,
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('loginSameAccount'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tone.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, Tone tone) => Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 2),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone.muted)),
      );
}
