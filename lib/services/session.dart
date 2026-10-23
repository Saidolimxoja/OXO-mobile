import 'package:flutter/foundation.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import 'location_service.dart';
import 'track_service.dart';

/// Данные вошедшего сотрудника: кто он, его бўлим, рабочий ли сегодня день,
/// виды работ. После загрузки запускает трек.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  Me? me;
  List<WorkType> workTypes = [];

  Future<void> load() async {
    final api = MobileApi.instance;
    final results = await Future.wait([api.me(), api.workTypes()]);
    me = results[0] as Me;
    workTypes = results[1] as List<WorkType>;
    notifyListeners();

    await _startTracking();
  }

  Future<void> _startTracking() async {
    final today = me?.today;
    if (today == null) return;
    if (await LocationService.ensurePermission() != null) return;

    await TrackService.instance.start(workingDay: today.isWorkingDay);
  }

  Future<void> logout() async {
    await TrackService.instance.flush();
    await TrackService.instance.reset();
    await MobileApi.instance.logout();
    me = null;
    workTypes = [];
    notifyListeners();
  }
}
