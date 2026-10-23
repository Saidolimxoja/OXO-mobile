import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Til: 'uz' (lotin), 'uzc' (kirill), 'ru' (rus)
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _keyLang = 'lang';
  static const _keyTheme = 'theme';

  String lang = 'uzc';
  ThemeMode themeMode = ThemeMode.light;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    lang = prefs.getString(_keyLang) ?? 'uzc';
    themeMode = prefs.getString(_keyTheme) == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setLang(String value) async {
    lang = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLang, value);
  }

  Future<void> setDark(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, dark ? 'dark' : 'light');
  }
}
