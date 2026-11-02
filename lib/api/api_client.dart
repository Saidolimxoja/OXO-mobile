import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;
  final int? distanceM;
  ApiException(this.message, [this.status, this.code, this.distanceM]);

  bool get unauthorized => status == 401;
  bool get forbidden => status == 403;

  @override
  String toString() => message;
}

/// HTTP-клиент мобильного API OXO (`/api/mobile/*`): Bearer access-токен,
/// при 401 — один обмен refresh-токена и повтор запроса.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  /// Токены — в Android Keystore: не читаются другими приложениями и не
  /// попадают в резервную копию телефона.
  static const _secure = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 25);
  static const _uploadTimeout = Duration(minutes: 3);

  String? _access;
  String? _refresh;
  Future<bool>? _refreshing;

  /// Вызывается, когда сессию восстановить нельзя — приложение уходит на вход.
  void Function()? onSessionExpired;

  bool get signedIn => _refresh != null;

  String? get refreshToken => _refresh;

  Future<void> load() async {
    _access = await _secure.read(key: _keyAccess);
    _refresh = await _secure.read(key: _keyRefresh);
    await _dropPlainTokens();
  }

  Future<void> saveTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _secure.write(key: _keyAccess, value: access);
    await _secure.write(key: _keyRefresh, value: refresh);
  }

  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    await _secure.delete(key: _keyAccess);
    await _secure.delete(key: _keyRefresh);
  }

  /// Прежние версии хранили токены открытым текстом в SharedPreferences. Их не
  /// переносим: сервер больше не принимает токены без сессии, вход нужен заново.
  Future<void> _dropPlainTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/api$path').replace(queryParameters: query);
  }

  Map<String, String> get authHeaders =>
      {if (_access != null) 'Authorization': 'Bearer $_access'};

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send(() => http.get(uri(path, query), headers: authHeaders));

  Future<dynamic> post(String path, Object? body, {bool auth = true}) => _send(
        () => http.post(
          uri(path),
          headers: {'Content-Type': 'application/json', if (auth) ...authHeaders},
          body: jsonEncode(body),
        ),
        retryOnUnauthorized: auth,
      );

  Future<dynamic> delete(String path) =>
      _send(() => http.delete(uri(path), headers: authHeaders));

  /// multipart/form-data: поля и фото (тип файла задаётся явно — сервер принимает только изображения).
  Future<dynamic> multipart(
    String path,
    Map<String, String> fields,
    List<File> files, {
    String fileField = 'photos',
  }) {
    Future<http.Response> build() async {
      final req = http.MultipartRequest('POST', uri(path))
        ..headers.addAll(authHeaders)
        ..fields.addAll(fields);
      for (final f in files) {
        req.files.add(await http.MultipartFile.fromPath(
          fileField,
          f.path,
          contentType: _imageType(f.path),
        ));
      }
      final streamed = await req.send().timeout(_uploadTimeout);
      return http.Response.fromStream(streamed);
    }

    return _send(build);
  }

  static MediaType _imageType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return MediaType('image', 'png');
    if (p.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    bool retryOnUnauthorized = true,
  }) async {
    if (!AppConfig.configured) {
      throw ApiException('API_BASE_URL is not set in this build');
    }

    var res = await _guard(request);
    if (res.statusCode == 401 && retryOnUnauthorized && _refresh != null) {
      if (await _refreshTokens()) {
        res = await _guard(request);
      }
    }
    if (res.statusCode == 401 && retryOnUnauthorized) {
      await clearTokens();
      onSessionExpired?.call();
    }

    return _decode(res);
  }

  Future<http.Response> _guard(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('network');
    }
  }

  /// Одновременные 401 обмениваются одним refresh-запросом.
  Future<bool> _refreshTokens() {
    return _refreshing ??= () async {
      try {
        final res = await http
            .post(
              uri('/mobile/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': _refresh}),
            )
            .timeout(_timeout);
        if (res.statusCode != 200) return false;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  static dynamic _decode(http.Response res) {
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        body = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final message = body is Map ? body['message'] : null;
    final code = body is Map ? body['code']?.toString() : null;
    final distanceM = body is Map && body['distanceM'] is num
        ? (body['distanceM'] as num).toInt()
        : null;
    final text = message is List
        ? message.join('\n')
        : (message?.toString() ?? 'HTTP ${res.statusCode}');

    throw ApiException(text, res.statusCode, code, distanceM);
  }
}
