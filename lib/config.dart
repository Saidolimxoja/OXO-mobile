/// Настройки сборки. Адрес сервера задаётся при сборке:
/// `flutter build apk --dart-define=API_BASE_URL=https://oxo-api.example.uz`
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Рабочее время одно для всех — как на сервере (work-calendar.ts).
  static const workStartMinutes = 9 * 60;
  static const workEndMinutes = 18 * 60;

  /// Ташкент: UTC+5 круглый год.
  static const tashkentOffset = Duration(hours: 5);

  /// Точки трека уходят на сервер не реже этого.
  static const trackSendEvery = Duration(minutes: 2);

  /// Сигнал «на связи» — раз в минуту, даже без GPS.
  static const pingEvery = Duration(minutes: 1);

  /// Сервер принимает не больше стольких сэмплов за запрос (track.rules.ts).
  static const maxTrackBatch = 600;

  /// Столько сэмплов храним, пока нет интернета.
  static const maxTrackBuffer = 3000;

  /// Фото к работе: 1–4 (work-job.rules.ts).
  static const minJobPhotos = 1;
  static const maxJobPhotos = 4;

  static bool get configured => apiBaseUrl.isNotEmpty;
}

/// Текущее время по Ташкенту независимо от пояса телефона.
DateTime tashkentNow() => DateTime.now().toUtc().add(AppConfig.tashkentOffset);

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
