import 'dart:io';

import 'package:geolocator/geolocator.dart';

import 'api_client.dart';
import 'models.dart';

/// Запросы мобильного API OXO — по одному методу на endpoint `/api/mobile/*`.
class MobileApi {
  MobileApi._();
  static final MobileApi instance = MobileApi._();

  final _api = ApiClient.instance;

  Future<void> login(String username, String password) async {
    final data = await _api.post(
      '/mobile/auth/login',
      {'username': username, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    await _api.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
  }

  Future<void> logout() async {
    final refresh = _api.refreshToken;
    if (refresh != null) {
      try {
        await _api.post('/mobile/auth/logout', {'refreshToken': refresh}, auth: false);
      } catch (_) {
        // сервер недоступен — всё равно выходим локально
      }
    }
    await _api.clearTokens();
  }

  Future<Me> me() async => Me.fromJson(await _api.get('/mobile/me') as Map<String, dynamic>);

  Future<List<CalendarDay>> calendar(String from, String to) async {
    final data = await _api.get('/mobile/calendar', {'from': from, 'to': to}) as Map<String, dynamic>;
    return ((data['days'] as List?) ?? [])
        .map((d) => CalendarDay.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Пачка сэмплов трека; ответ — сколько точек принято.
  Future<int> sendTrack(List<Map<String, dynamic>> samples) async {
    final data = await _api.post('/mobile/track', {'samples': samples}) as Map<String, dynamic>;
    return (data['accepted'] as num?)?.toInt() ?? 0;
  }

  Future<List<WorkType>> workTypes() async {
    final data = await _api.get('/mobile/work-types') as List;
    return data.map((w) => WorkType.fromJson(w as Map<String, dynamic>)).toList();
  }

  Future<String?> geocode(double lat, double lon) async {
    final data = await _api.get('/mobile/geocode', {'lat': '$lat', 'lon': '$lon'}) as Map<String, dynamic>;
    return data['address'] as String?;
  }

  Future<Job> createJob(NewJob job, List<File> photos) async {
    final data = await _api.multipart('/mobile/jobs', job.toFields(), photos);
    return Job.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Job>> jobs(String date) async {
    final data = await _api.get('/mobile/jobs', {'date': date}) as List;
    return data.map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> deleteJob(int id) => _api.delete('/mobile/jobs/$id');

  Future<Stats> stats(String date) async =>
      Stats.fromJson(await _api.get('/mobile/jobs/stats', {'date': date}) as Map<String, dynamic>);

  /// Полный адрес фото для Image.network (нужен заголовок авторизации).
  String photoUrl(JobPhoto photo) => _api.uri(photo.url.replaceFirst(RegExp(r'^/api'), '')).toString();

  Map<String, String> get photoHeaders => _api.authHeaders;

  Future<AttendanceToday> attendanceToday() async {
    final data = await _api.get('/mobile/attendance/today') as Map<String, dynamic>;
    return AttendanceToday.fromJson(data);
  }

  Future<AttendanceToday> checkIn(File selfie, Position pos) async {
    final fields = {
      'lat': '${pos.latitude}',
      'lon': '${pos.longitude}',
      'accuracy': '${pos.accuracy.round()}',
      'mock': '${pos.isMocked}',
    };
    final data = await _api.multipart(
      '/mobile/attendance/check-in',
      fields,
      [selfie],
      fileField: 'selfie',
    ) as Map<String, dynamic>;
    return AttendanceToday.fromJson(data);
  }

  Future<AttendanceToday> checkOut([Position? pos]) async {
    final body = <String, dynamic>{
      if (pos != null) ...{
        'lat': pos.latitude,
        'lon': pos.longitude,
        'accuracy': pos.accuracy.round(),
      },
    };
    final data = await _api.post('/mobile/attendance/check-out', body) as Map<String, dynamic>;
    return AttendanceToday.fromJson(data);
  }

  Future<List<AttendanceHistoryDay>> attendanceHistory(String from, String to) async {
    final data = await _api.get(
      '/mobile/attendance/history',
      {'from': from, 'to': to},
    ) as Map<String, dynamic>;
    return ((data['days'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AttendanceHistoryDay.fromJson)
        .toList();
  }
}
