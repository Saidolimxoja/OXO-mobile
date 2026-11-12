import 'package:flutter/foundation.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import 'location_service.dart';
import 'track_service.dart';

/// Данные вошедшего сотрудника: кто он, его бўлим, рабочий ли сегодня день,
/// виды работ. После загрузки включает трек.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  Me? me;
  List<WorkType> workTypes = [];
  DateTime? _lastMeAt;

  /// Ишлар ҳисоботи — только у сотрудников туманов.
  bool get reportsWork => me?.canReportWork ?? false;

  Future<void> load() async {
    final api = MobileApi.instance;

    me = await api.me();
    _lastMeAt = DateTime.now();
    workTypes = reportsWork ? await api.workTypes() : [];
    notifyListeners();

    await _syncTrack();
  }

  /// Возврат в приложение: мог смениться день (праздник, выходной), а с ним и трек.
  Future<void> refresh() async {
    final today = ymd(tashkentNow());
    final shouldFetchMe = _lastMeAt == null ||
        DateTime.now().difference(_lastMeAt!) >= AppConfig.meRefreshEvery ||
        me?.today.date != today;

    if (!shouldFetchMe) {
      await _syncTrack();
      return;
    }

    try {
      me = await MobileApi.instance.me();
      _lastMeAt = DateTime.now();
      notifyListeners();
      await _syncTrack();
    } catch (_) {
      // Без сети день берём по телефону: Пн–Пт рабочие; праздники сервер учтёт сам
      final now = tashkentNow();
      final currentToday = ymd(now);

      if (me?.today.date != currentToday) {
        await _syncTrack(date: currentToday, workingDay: now.weekday <= DateTime.friday);
      }
    }
  }

  Future<void> _syncTrack({String? date, bool? workingDay}) async {
    final today = me?.today;
    if (today == null) return;
    if (await LocationService.ensurePermission() != null) return;

    await TrackService.instance.sync(
      date: date ?? today.date,
      workingDay: workingDay ?? today.isWorkingDay,
    );
  }

  /// Локальная очистка данных сотрудника: накопленный трек и профиль не должны
  /// достаться следующему вошедшему пользователю.
  Future<void> clearLocal() async {
    await TrackService.instance.reset();

    me = null;
    _lastMeAt = null;
    workTypes = [];
    notifyListeners();
  }

  Future<void> logout() async {
    await TrackService.instance.flush();
    await clearLocal();
    await MobileApi.instance.logout();
  }
}
