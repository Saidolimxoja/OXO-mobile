import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/mobile_api.dart';
import '../config.dart';

/// Трек и сигналы «на связи» в рабочее время.
///
/// Работает как foreground-сервис Android (постоянное уведомление), поэтому
/// продолжает писать точки, когда приложение свёрнуто. В нерабочее время,
/// в выходные и праздники ничего не собирает и не отправляет — сервер такие
/// точки всё равно отбросит. Без интернета сэмплы копятся и уходят позже.
class TrackService extends ChangeNotifier {
  TrackService._();
  static final TrackService instance = TrackService._();

  static const _keyBuffer = 'track_buffer';

  /// Рабочий ли сегодня день — по календарю сервера (праздники).
  bool workingDay = false;

  bool get running => _positions != null;
  DateTime? lastSentAt;
  DateTime? lastFixAt;
  int pending = 0;

  StreamSubscription<Position>? _positions;
  Timer? _pingTimer;
  Timer? _sendTimer;
  bool _sending = false;
  final List<Map<String, dynamic>> _buffer = [];

  static bool inWorkTime(DateTime tashkent) {
    final minutes = tashkent.hour * 60 + tashkent.minute;
    return minutes >= AppConfig.workStartMinutes && minutes < AppConfig.workEndMinutes;
  }

  bool get collecting => workingDay && inWorkTime(tashkentNow());

  Future<void> start({required bool workingDay}) async {
    this.workingDay = workingDay;
    await _restoreBuffer();
    if (running) return;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
      intervalDuration: const Duration(minutes: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'OXO',
        notificationText: 'Иш вақтида (09:00–18:00) жойлашув иш ҳисоботига ёзилади',
        notificationChannelName: 'OXO трек',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    _positions = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (_) {},
    );
    _pingTimer = Timer.periodic(AppConfig.pingEvery, (_) => _ping());
    _sendTimer = Timer.periodic(AppConfig.trackSendEvery, (_) => flush());
    notifyListeners();
  }

  Future<void> stop() async {
    await _positions?.cancel();
    _positions = null;
    _pingTimer?.cancel();
    _sendTimer?.cancel();
    _pingTimer = null;
    _sendTimer = null;
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

  /// Сигнал без координат — телефон на связи, даже если GPS не ловит.
  void _ping() {
    if (!collecting) return;
    _add({'t': DateTime.now().toUtc().toIso8601String()});
  }

  void _add(Map<String, dynamic> sample) {
    _buffer.add(sample);
    if (_buffer.length > AppConfig.maxTrackBuffer) {
      _buffer.removeRange(0, _buffer.length - AppConfig.maxTrackBuffer);
    }
    pending = _buffer.length;
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
