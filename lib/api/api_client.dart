import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client httpClient;
  String? _token;

  ApiClient({required this.baseUrl, http.Client? client}) : httpClient = client ?? http.Client();

  void setToken(String token) => _token = token;

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<T> get<T>(String path, T Function(dynamic json) mapper, {Map<String, String>? params}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: params);
    final res = await httpClient.get(uri, headers: _headers());
    return _process<T>(res, mapper);
  }

  Future<T> post<T>(String path, dynamic body, T Function(dynamic json) mapper, {Map<String, String>? params}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: params);
    final res = await httpClient.post(uri, headers: _headers(), body: jsonEncode(body));
    return _process<T>(res, mapper);
  }

  Future<T> put<T>(String path, dynamic body, T Function(dynamic json) mapper) async {
    final uri = Uri.parse(baseUrl + path);
    final res = await httpClient.put(uri, headers: _headers(), body: jsonEncode(body));
    return _process<T>(res, mapper);
  }

  Future<T> delete<T>(String path, T Function(dynamic json) mapper) async {
    final uri = Uri.parse(baseUrl + path);
    final res = await httpClient.delete(uri, headers: _headers());
    return _process<T>(res, mapper);
  }

  T _process<T>(http.Response res, T Function(dynamic json) mapper) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) {
        // Return empty response as null mapped value if T is nullable
        return mapper(null);
      }
      final decoded = jsonDecode(res.body);
      return mapper(decoded);
    }
    throw ApiException(res.statusCode, res.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}
