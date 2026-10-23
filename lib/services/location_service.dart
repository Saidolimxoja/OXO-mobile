import 'package:geolocator/geolocator.dart';

enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  final Position? position;
  final LocationProblem? problem;

  const LocationResult.ok(Position this.position) : problem = null;
  const LocationResult.fail(LocationProblem this.problem) : position = null;

  bool get isOk => position != null;
}

/// Разовое определение места (для отчёта о работе) и проверка прав на геолокацию.
class LocationService {
  static const _fixTimeout = Duration(seconds: 25);

  /// Права на геолокацию; при необходимости спрашивает пользователя.
  static Future<LocationProblem?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationProblem.serviceOff;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) return LocationProblem.denied;
    if (permission == LocationPermission.deniedForever) return LocationProblem.deniedForever;

    return null;
  }

  static Future<LocationResult> current() async {
    final problem = await ensurePermission();
    if (problem != null) return LocationResult.fail(problem);

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      return LocationResult.ok(pos);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationResult.ok(last);
      return const LocationResult.fail(LocationProblem.unavailable);
    }
  }
}
