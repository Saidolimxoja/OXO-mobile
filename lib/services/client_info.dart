import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Версия приложения и телефон — уходят с «Келдим» и с отчётом о падении,
/// чтобы было видно, на каких телефонах и версиях что не работает.
class ClientInfo {
  final String appVersion;
  final String buildNumber;
  final String? deviceModel;
  final String? osVersion;

  const ClientInfo._(this.appVersion, this.buildNumber, this.deviceModel, this.osVersion);

  static Future<ClientInfo>? _loading;

  /// Читается один раз за запуск: за время работы приложения ничего из этого не меняется.
  static Future<ClientInfo> get() => _loading ??= _load();

  static Future<ClientInfo> _load() async {
    final package = await PackageInfo.fromPlatform();
    String? model;
    String? os;

    try {
      final android = await DeviceInfoPlugin().androidInfo;

      model = '${android.manufacturer} ${android.model}'.trim();
      os = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
    } catch (_) {
      // Без модели телефона отчёт всё равно полезен — версия приложения есть
    }

    return ClientInfo._(package.version, package.buildNumber, model, os);
  }
}
