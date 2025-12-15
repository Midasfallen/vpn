// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, unused_import, unused_local_variable

import 'dart:math';

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vpn/api/client_instance.dart';
import 'package:vpn/api/vpn_service.dart';
import 'package:vpn/config/environment.dart';

void main() {
  setUpAll(() {
    Environment.initialize(flavor: 'dev');
  });

  test('create peer via API (POST /vpn_peers)', () async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'test+${ts}@example.com';
      final password = 'Password1!';

      await apiClient.post<Map<String, dynamic>>(
          '/auth/register', {'email': email, 'password': password},
          (json) => json as Map<String, dynamic>);

      final loginRes = await apiClient.post<Map<String, dynamic>>(
          '/auth/login', {'email': email, 'password': password},
          (json) => json as Map<String, dynamic>);

      final token = loginRes['access_token'] ??
          loginRes['token'] ??
          loginRes['detail'] ??
          loginRes['access'];
      if (token != null) apiClient.setToken(token.toString());

      // Create tariff and subscribe (required for peer creation)
      final tariffName = 'test-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final tariffRes = await apiClient.post<Map<String, dynamic>>(
          '/tariffs/', {'name': tariffName, 'price': 100},
          (json) => json as Map<String, dynamic>);

      if (tariffRes['id'] != null) {
        await apiClient.post<Map<String, dynamic>>(
            '/auth/subscribe', {'tariff_id': tariffRes['id']},
            (json) => json as Map<String, dynamic>);
      }

      final peer = await vpnService.createPeer();

      expect(peer.id, isNonZero);
    } catch (e) {
      rethrow;
    }
  }, timeout: Timeout(Duration(seconds: 60)));
}
