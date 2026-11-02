import 'package:geolocator/geolocator.dart';

import '../i18n.dart';
import 'location_service.dart';

class CheckInException implements Exception {
  final String message;

  CheckInException(this.message);

  @override
  String toString() => message;
}

/// Сервис отметки прихода: свежая точка GPS (селфи снимает FaceCaptureScreen).
class CheckInService {
  CheckInService._();

  static const _fixTimeout = Duration(seconds: 25);

  static String problemText(LocationProblem p) => switch (p) {
        LocationProblem.serviceOff => t('gpsOff'),
        LocationProblem.denied => t('gpsDenied'),
        LocationProblem.deniedForever => t('gpsDeniedForever'),
        LocationProblem.unavailable => t('gpsUnavailable'),
      };

  /// Свежая текущая позиция с LocationAccuracy.best и таймаутом 25 с,
  /// без использования getLastKnownPosition.
  static Future<Position> getFreshPosition() async {
    final problem = await LocationService.ensurePermission();
    if (problem != null) {
      throw CheckInException(problemText(problem));
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _fixTimeout,
        ),
      );

      return pos;
    } catch (_) {
      throw CheckInException(t('gpsUnavailable'));
    }
  }
}
