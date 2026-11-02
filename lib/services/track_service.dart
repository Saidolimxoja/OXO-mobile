import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/mobile_api.dart';
import '../config.dart';

/// Трек и сигналы «на связи» в рабочее время.
///
/// Точки пишутся строго 09:00–18:00 рабочего дня, остальное время не нужно ни
/// Давомату, ни Ишлар ҳисоботи. GPS работает как foreground-сервис Android
/// (постоянное уведомление) и продолжает писать, когда приложение свёрнуто.
///
/// Запустить сервис геолокации Android разрешает только из открытого приложения,
/// поэтому GPS включается при входе и при возврате в приложение (обычно это
/// «Келдим» утром) и сам выключается в 18:00 и в нерабочий день. Без интернета
/// сэмплы копятся на телефоне и уходят позже.
class TrackService extends ChangeNotifier {
  TrackService._();
  static final TrackService instance = TrackService._();

  static const _keyBuffer = 'track_buffer';

  /// Рабочий ли день [_day] — по календарю сервера (праздники).
  bool workingDay = false;
  String? _day;

  /// Есть разрешение на геолокацию и трек ведётся (может ждать рабочего времени).
  bool enabled = false;

  bool get running => _positions != null;
  DateTime? lastSentAt;
  DateTime? lastFixAt;
  int pending = 0;

  StreamSubscription<Position>? _positions;
  Timer? _clock;
  Timer? _sendTimer;
  bool _sending = false;
  final List<Map<String, dynamic>> _buffer = [];

  static bool inWorkTime(DateTime tashkent) {
    final minutes = tashkent.hour * 60 + tashkent.minute;
    return minutes >= AppConfig.workStartMinutes && minutes < AppConfig.workEndMinutes;
  }

  bool get _today => _day == ymd(tashkentNow());

  bool get collecting => running && workingDay && _today && inWorkTime(tashkentNow());

  /// GPS нужен до конца рабочего дня: с утра он включается заранее (точки до 09:00
  /// не пишутся), чтобы в 09:00 трек пошёл, даже если приложение уже свёрнуто.
  bool get _streamNeeded {
    final now = tashkentNow();

    return workingDay && _today && now.hour * 60 + now.minute < AppConfig.workEndMinutes;
  }

  /// Привести трек к дню [date]; вызывается при входе и при каждом возврате в приложение.
  Future<void> sync({required String date, required bool workingDay}) async {
    _day = date;
    this.workingDay = workingDay;
    enabled = true;
    await _restoreBuffer();

    _clock ??= Timer.periodic(AppConfig.pingEvery, (_) => _tick());
    _sendTimer ??= Timer.periodic(AppConfig.trackSendEvery, (_) => flush());

    if (_streamNeeded) {
      _startStream();
    } else {
      await _stopStream();
    }

    notifyListeners();
  }

  void _startStream() {
    if (running) return;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
      intervalDuration: const Duration(minutes: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Ҳудуд назорати',
        notificationText: 'Иш вақтида (09:00–18:00) жойлашув ёзилади',
        notificationChannelName: 'Ҳудуд назорати — трек',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    _positions = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (_) {},
    );
  }

  Future<void> _stopStream() async {
    await _positions?.cancel();
    _positions = null;
  }

  /// Раз в минуту: сигнал «на связи» и выключение GPS после 18:00 или со сменой дня.
  Future<void> _tick() async {
    if (collecting) _add({'t': DateTime.now().toUtc().toIso8601String()});

    if (running && !_streamNeeded) {
      await _stopStream();
      await flush();
      notifyListeners();
    }
  }

  /// Выход из учётной записи: всё выключить.
  Future<void> stop() async {
    await _stopStream();
    _clock?.cancel();
    _sendTimer?.cancel();
    _clock = null;
    _sendTimer = null;
    enabled = false;
    notifyListeners();
  }

  void _onPosition(Position pos) {
    lastFixAt = DateTime.now();
    if (!collecting) return;

    _add({
      't': pos.timestamp.toUtc().toIso8601String(),
      'lat': pos.latitude,
      'lon': pos.longitude,
      'acc': pos.accuracy.round(),
      'mock': pos.isMocked,
    });
  }

  void _add(Map<String, dynamic> sample) {
    _buffer.add(sample);
    if (_buffer.length > AppConfig.maxTrackBuffer) {
      _buffer.removeRange(0, _buffer.length - AppConfig.maxTrackBuffer);
    }
    pending = _buffer.length;
    // Сразу на диск: если система закроет приложение до отправки, точки не пропадут
    _saveBuffer();
    notifyListeners();
  }

  /// Отправляет накопленное пачками; при ошибке сети сохраняет на телефоне.
  Future<void> flush() async {
    if (_sending || _buffer.isEmpty) return;
    _sending = true;
    try {
      while (_buffer.isNotEmpty) {
        final batch = _buffer.take(AppConfig.maxTrackBatch).toList();
        await MobileApi.instance.sendTrack(batch);
        _buffer.removeRange(0, batch.length);
        lastSentAt = DateTime.now();
      }
    } catch (_) {
      // нет сети — попробуем в следующий раз
    } finally {
      _sending = false;
      pending = _buffer.length;
      await _saveBuffer();
      notifyListeners();
    }
  }

  Future<void> _saveBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBuffer, jsonEncode(_buffer));
  }

  Future<void> _restoreBuffer() async {
    if (_buffer.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBuffer);
    if (raw == null) return;
    try {
      _buffer.addAll((jsonDecode(raw) as List).cast<Map<String, dynamic>>());
      pending = _buffer.length;
    } catch (_) {
      await prefs.remove(_keyBuffer);
    }
  }

  /// При выходе из учётной записи накопленное чужому пользователю не уходит.
  Future<void> reset() async {
    await stop();
    _buffer.clear();
    pending = 0;
    lastSentAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBuffer);
  }
}
