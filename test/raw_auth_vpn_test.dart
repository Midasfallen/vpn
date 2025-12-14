// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, unused_import, unused_local_variable

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vpn/api/client_instance.dart';
import 'package:vpn/config/environment.dart';

void main() {
  setUpAll(() {
    Environment.initialize(flavor: 'dev');
  });

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
    expect(token, isNotNull, reason: 'Login should return access_token');

    final client = HttpClient();
    try {
      // Create tariff
      final tariffName = 'test-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final tariffReq = await client.postUrl(Uri.parse('http://146.103.99.70:8000/tariffs/'));
      tariffReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      tariffReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      tariffReq.add(utf8.encode('{"name": "$tariffName", "price": 100}'));
      final tariffResp = await tariffReq.close();
      final tariffBody = await tariffResp.transform(utf8.decoder).join();
      final tariffData = jsonDecode(tariffBody) as Map<String, dynamic>;

      // Subscribe to tariff
      if (tariffResp.statusCode == 200 || tariffResp.statusCode == 201) {
        final tariffId = tariffData['id'];
        final subscribeReq = await client.postUrl(Uri.parse('http://146.103.99.70:8000/auth/subscribe'));
        subscribeReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        subscribeReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        subscribeReq.add(utf8.encode('{"tariff_id": $tariffId}'));
        final subscribeResp = await subscribeReq.close();
        await subscribeResp.transform(utf8.decoder).join();
      }

      // Create peer
      final peerUri = Uri.parse('http://146.103.99.70:8000/vpn_peers/self');
      final peerReq = await client.postUrl(peerUri);
      peerReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      peerReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      peerReq.add(utf8.encode('{"device_name": "test_device"}'));
      final peerResp = await peerReq.close();
      await peerResp.transform(utf8.decoder).join();
      expect(peerResp.statusCode, anyOf([200,201,202]));
    } finally {
      client.close(force: true);
    }
  }, timeout: Timeout(Duration(seconds: 60)));
}
