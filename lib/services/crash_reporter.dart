import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/mobile_api.dart';
import '../config.dart';
import 'client_info.dart';

/// Отчёты о падениях на сервер OXO (`mobile_crash_reports`).
///
/// Ошибка сначала ложится в очередь на телефоне: она может случиться до входа или
/// без интернета. Очередь уходит, когда пользователь вошёл и сеть есть. Стек в
/// release обфусцирован — расшифровка картами символов сборки (README, «Падения»).
class CrashReporter {
  CrashReporter._();

  static const _keyQueue = 'crash_queue';
  static const _keyReported = 'crash_reported_today';

  /// Длины — как принимает сервер (MobileCrashReportDto).
  static const _maxError = 4000;
  static const _maxStack = 30000;
  static const _maxDedupeKey = 200;

  static bool _flushing = false;

  /// Перехват ошибок Flutter (сломанный экран) и необработанных асинхронных ошибок.
  static void install() {
    final presentError = FlutterError.onError;

    FlutterError.onError = (details) {
      presentError?.call(details);
      record(details.exception, details.stack, fatal: true);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, fatal: true);
      return true;
    };
  }

  /// Записать ошибку; fatal=false — ошибка перехвачена кодом, но знать о ней нужно.
  static Future<void> record(Object error, StackTrace? stack, {bool fatal = false}) async {
    try {
      // Одинаковая некритичная ошибка — не чаще раза в сутки: ошибка камеры
      // на каждом «Келдим» давала сотни одинаковых отчётов
      if (!fatal && await _reportedToday(error)) return;

      final client = await ClientInfo.get();
      final report = {
        'appVersion': client.appVersion,
        'buildNumber': client.buildNumber,
        if (client.deviceModel != null) 'deviceModel': client.deviceModel,
        if (client.osVersion != null) 'osVersion': client.osVersion,
        'fatal': fatal,
        'error': _cut(error.toString(), _maxError),
        if (stack != null) 'stack': _cut(stack.toString(), _maxStack),
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      };
      final queue = await _read();

      queue.add(report);
      if (queue.length > AppConfig.maxCrashQueue) {
        queue.removeRange(0, queue.length - AppConfig.maxCrashQueue);
      }

      await _write(queue);
      await flush();
    } catch (e) {
      // Сообщать об ошибке отчёта некуда, а новая запись отсюда зациклила бы обработчик
      debugPrint('CrashReporter: $e');
    }
  }

  /// Отправить очередь. Без входа ждём: отчёт привяжется к пользователю.
  static Future<void> flush() async {
    if (_flushing || !ApiClient.instance.signedIn) return;
    _flushing = true;

    try {
      final queue = await _read();

      while (queue.isNotEmpty) {
        try {
          await MobileApi.instance.sendCrash(queue.first);
        } on ApiException catch (e) {
          // Нет сети или сервер недоступен — отправим в следующий раз;
          // отказ по содержимому (4xx) не исправится повтором — отчёт выбрасываем
          final status = e.status;
          if (status == null || status >= 500 || status == 401) break;
        }

        queue.removeAt(0);
        await _write(queue);
      }
    } catch (e) {
      debugPrint('CrashReporter: $e');
    } finally {
      _flushing = false;
    }
  }

  /// Был ли сегодня отчёт с такой же ошибкой; если нет — запоминает её.
  /// Сбой хранилища считается «не был»: лишний отчёт лучше потерянного.
  static Future<bool> _reportedToday(Object error) async {
    try {
      final key = '${error.runtimeType}:${_cut(error.toString(), _maxDedupeKey)}';
      final prefs = await SharedPreferences.getInstance();
      final today = ymd(tashkentNow());
      final saved = jsonDecode(prefs.getString(_keyReported) ?? '{}');
      final keys = saved is Map && saved['date'] == today && saved['keys'] is List
          ? (saved['keys'] as List).map((k) => k.toString()).toList()
          : <String>[];

      if (keys.contains(key)) return true;

      await prefs.setString(_keyReported, jsonEncode({'date': today, 'keys': [...keys, key]}));

      return false;
    } catch (e) {
      debugPrint('CrashReporter: $e');

      return false;
    }
  }

  static String _cut(String text, int max) => text.length <= max ? text : text.substring(0, max);

  static Future<List<Map<String, dynamic>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyQueue);
    if (raw == null) return [];

    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      await prefs.remove(_keyQueue);
      return [];
    }
  }

  static Future<void> _write(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQueue, jsonEncode(queue));
  }
}
