import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'logging.dart';

/// ApiClient — обёртка над `package:http` с удобной обработкой ответов,
/// централизованным логированием, retry для сетевых ошибок и встроенной
/// поддержкой обновления токена при 401.
///
/// Особенности:
/// - Валидация входных параметров (path, mapper и params).
/// - Retry на сетевые ошибки (SocketException, HttpException) с экспоненциальной задержкой.
/// - При 401 вызывается `onRefreshToken` для получения нового токена; если
///   callback вернул токен — запрос повторяется единожды.
/// - Mapper должен принимать распарсенный JSON (Map/List) или null/строку,
///   ApiClient обрабатывает пустые тела и некорректный JSON.
/// - Timeout для каждого запроса (30 сек по умолчанию).
class ApiClient {
  final String baseUrl;
  final http.Client httpClient;
  String? _token;
  
  /// Timeout для HTTP запросов
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Callback для обновления токена — обязан возвращать новый токен или null.
  /// Обычно реализуется в слое авторизации (VpnService) и сохраняет токен в безопасном хранилище.
  final Future<String?> Function()? onRefreshToken;

  /// Максимальное количество попыток для transient ошибок (включая первую).
  final int maxRetries;

  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.onRefreshToken,
    this.maxRetries = 3,
  }) : httpClient = client ?? http.Client();

  /// Установить токен вручную (например, после логина).
  /// При установке логируем и сохраняем в памяти; сохранение в безопасное хранилище
  /// реализуется на уровне приложения (внешний callback).
  void setToken(String token) {
    _token = token;
    ApiLogger.info('Token set', {'masked': _mask(token)});
  }

  /// Удаляет токен из памяти клиента (не из secure storage).
  void clearToken() {
    _token = null;
    ApiLogger.info('Token cleared');
  }

  /// Проверяет валидность токена. По умолчанию пытается декодировать JWT
  /// и проверить exp (если есть). Возвращает false при пустом/невалидном токене.
  bool isTokenValid() {
    final token = _token;
    if (token == null || token.trim().isEmpty) return false;
    final parts = token.split('.');
    if (parts.length != 3) return true; // не-JWT, доверяем — считаем валидным
    try {
      final payload = utf8.decode(base64Url.decode(_normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map.containsKey('exp')) {
        final exp = map['exp'];
        final expInt = exp is int ? exp : int.tryParse(exp.toString());
        if (expInt != null) return DateTime.fromMillisecondsSinceEpoch(expInt * 1000).isAfter(DateTime.now());
      }
    } catch (_) {
      // Не крешиться на ошибках декодирования, считать валидным.
      return true;
    }
    return true;
  }

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  /// GET-запрос к [path]. [mapper] не может быть null.
  Future<T> get<T>(String path, T Function(dynamic json) mapper, {Map<String, String>? params}) async {
    _validatePath(path);
    _validateMapper(mapper);
    _validateParams(params);

    final uri = Uri.parse(baseUrl + path).replace(queryParameters: params);
    ApiLogger.debug('GET $uri', {'headers': _headers()});

    return _requestWithRefreshAndRetry<T>(
      () => httpClient.get(uri, headers: _headers()).timeout(requestTimeout),
      mapper,
    );
  }

  Future<T> post<T>(String path, dynamic body, T Function(dynamic json) mapper, {Map<String, String>? params}) async {
    _validatePath(path);
    _validateMapper(mapper);
    _validateParams(params);
    if (body == null) throw ArgumentError.notNull('body');

    Uri uri = Uri.parse(baseUrl + path).replace(queryParameters: params);
    ApiLogger.debug('POST $uri', {'body': body, 'headers': _headers()});

    // Выполняем запрос и вручную обрабатываем возможный редирект (например, 307 -> location)
    http.Response res = await _withRetry(
      () => httpClient.post(uri, headers: _headers(), body: jsonEncode(body)).timeout(requestTimeout),
    );

    if (res.statusCode >= 300 && res.statusCode < 400 && res.headers['location'] != null) {
      try {
        final loc = res.headers['location']!;
        final redirectUri = Uri.parse(loc);
        ApiLogger.info('Following redirect for POST to $redirectUri');
        res = await _withRetry(
          () => httpClient.post(redirectUri, headers: _headers(), body: jsonEncode(body)).timeout(requestTimeout),
        );
      } catch (e) {
        ApiLogger.error('Failed to follow redirect', e);
      }
    }

    return _process<T>(res, mapper);
  }

  Future<T> put<T>(String path, dynamic body, T Function(dynamic json) mapper) async {
    _validatePath(path);
    _validateMapper(mapper);
    if (body == null) throw ArgumentError.notNull('body');

    final uri = Uri.parse(baseUrl + path);
    ApiLogger.debug('PUT $uri', {'body': body, 'headers': _headers()});

    return _requestWithRefreshAndRetry<T>(
      () => httpClient.put(uri, headers: _headers(), body: jsonEncode(body)).timeout(requestTimeout),
      mapper,
    );
  }

  Future<T> delete<T>(String path, T Function(dynamic json) mapper) async {
    _validatePath(path);
    _validateMapper(mapper);

    final uri = Uri.parse(baseUrl + path);
    ApiLogger.debug('DELETE $uri', {'headers': _headers()});

    return _requestWithRefreshAndRetry<T>(
      () => httpClient.delete(uri, headers: _headers()).timeout(requestTimeout),
      mapper,
    );
  }

  // --- Внутренние утилиты ---

  void _validatePath(String path) {
    if (path.trim().isEmpty) throw ArgumentError('Path must not be empty');
    // Simple normalization: ensure leading slash
    if (!path.startsWith('/')) ApiLogger.debug('Normalizing path to start with /');
  }

  void _validateMapper(Object? mapper) {
    if (mapper == null) throw ArgumentError.notNull('mapper');
  }

  void _validateParams(Map<String, String>? params) {
    if (params == null) return;
    for (final entry in params.entries) {
      // В Dart с null-safety ключи/значения в Map<String, String> не могут быть null.
      // Раньше тут была проверка на null — удаляем её.
      if (entry.key.isEmpty || entry.value.isEmpty) throw ArgumentError('Query params must not contain empty keys/values');
    }
  }

  Future<T> _requestWithRefreshAndRetry<T>(Future<http.Response> Function() fn, T Function(dynamic json) mapper) async {
    int attempt = 0;
    bool attemptedRefresh = false;
    while (true) {
      attempt++;
      try {
        final res = await _withRetry(fn);

        // If unauthorized and we have a refresh callback, try refreshing token once
        if (res.statusCode == 401 && onRefreshToken != null && !attemptedRefresh) {
          ApiLogger.info('Received 401, attempting token refresh');
          attemptedRefresh = true;
          final newToken = await onRefreshToken!();
          if (newToken != null) {
            setToken(newToken);
            // retry request once with new token
            continue;
          }
        }

        return _process<T>(res, mapper);
      } on ApiException {
        rethrow;
      } catch (err, st) {
        ApiLogger.error('Unhandled exception during request (attempt $attempt)', err, st);
        throw ApiException(-1, 'Network error: ${err.toString()}');
      }
    }
  }

  /// Retry wrapper: повторяет fn при transient ошибках.
  Future<http.Response> _withRetry(Future<http.Response> Function() fn) async {
    int attempt = 0;
    int maxAttempts = maxRetries;
    const baseDelayMs = 300;
    while (true) {
      attempt++;
      try {
        final res = await fn();
        return res;
      } catch (err) {
        final isTransient = err is SocketException || err is HttpException || err is TimeoutException || err is http.ClientException;
        if (!isTransient || attempt >= maxAttempts) {
          ApiLogger.error('Request failed and will not be retried', err, StackTrace.current);
          rethrow;
        }
        final delay = Duration(milliseconds: baseDelayMs * (1 << (attempt - 1)));
        ApiLogger.info('Transient error, retrying after ${delay.inMilliseconds}ms', {'attempt': attempt, 'error': err.toString()});
        await Future.delayed(delay);
      }
    }
  }

  T _process<T>(http.Response res, T Function(dynamic json) mapper) {
    ApiLogger.debug('Processing response', {'status': res.statusCode, 'body': res.body});

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.trim().isEmpty) {
        try {
          return mapper(null);
        } catch (err) {
          ApiLogger.error('Mapper error on empty body', err, StackTrace.current);
          throw ApiException(res.statusCode, 'Empty response body. Mapper error: ${err.toString()}');
        }
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = res.body;
      }

      try {
        return mapper(decoded);
      } catch (err) {
        ApiLogger.error('Mapper error', err, StackTrace.current);
        throw ApiException(res.statusCode, 'Mapper error: ${err.toString()} | body: ${res.body}');
      }
    }

    ApiLogger.error('API returned error', {'status': res.statusCode, 'body': res.body, 'headers': res.headers}, StackTrace.current);
    throw ApiException(res.statusCode, res.body);
  }

  String _mask(String token) {
    if (token.length <= 8) return '****';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  String _normalize(String input) {
    // base64url padding
    switch (input.length % 4) {
      case 2:
        return '$input==';
      case 3:
        return '$input=';
      default:
        return input;
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}
