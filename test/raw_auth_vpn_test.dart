// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, unused_import, unused_local_variable

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vpn/api/client_instance.dart';

void main() {
  test('raw auth POST to /vpn_peers/ with token', () async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'test+${ts}@example.com';
    final password = 'Password1!';

    // Use apiClient directly to avoid TokenStorage/platform channels in tests
    final reg = await apiClient.post<Map<String, dynamic>>(
        '/auth/register', {'email': email, 'password': password},
        (json) => json as Map<String, dynamic>);

    final loginRes = await apiClient.post<Map<String, dynamic>>(
        '/auth/login', {'email': email, 'password': password},
        (json) => json as Map<String, dynamic>);

    final token = loginRes['access_token'] ?? loginRes['token'] ?? loginRes['detail'] ?? loginRes['access'];

    final uri = Uri.parse('http://146.103.99.70:8000/vpn_peers/');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token.toString()}');
      req.add(utf8.encode('{}'));
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();
      expect(resp.statusCode, anyOf([200,201,202]));
    } finally {
      client.close(force: true);
    }
  }, timeout: Timeout(Duration(seconds: 60)));
}
