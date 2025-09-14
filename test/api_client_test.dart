import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vpn/api/api_client.dart';

void main() {
  group('ApiClient', () {
    test('get returns decoded json', () async {
      final mock = MockClient((req) async {
        return http.Response(jsonEncode({'foo': 'bar'}), 200, headers: {'content-type': 'application/json'});
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock);
      final res = await client.get<Map<String, dynamic>>('/path', (json) => json as Map<String, dynamic>);
      expect(res['foo'], 'bar');
    });

    test('post with body returns parsed json', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'POST');
        expect(jsonDecode(req.body)['a'], 'b');
        return http.Response(jsonEncode({'id': 1}), 201, headers: {'content-type': 'application/json'});
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock);
      final res = await client.post<Map<String, dynamic>>('/create', {'a': 'b'}, (json) => json as Map<String, dynamic>);
      expect(res['id'], 1);
    });

    test('empty body calls mapper with null', () async {
      final mock = MockClient((req) async {
        return http.Response('', 204);
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock);
      final res = await client.get<String>('/empty', (json) => json == null ? 'ok' : 'not');
      expect(res, 'ok');
    });

    test('retries on transient error', () async {
      int calls = 0;
      final mock = MockClient((req) async {
        calls++;
        if (calls == 1) throw SocketException('Network down');
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock, maxRetries: 3);
      final res = await client.get<Map<String, dynamic>>('/retry', (json) => json as Map<String, dynamic>);
      expect(res['ok'], true);
      expect(calls, 2);
    });

    test('refresh token on 401 and retries request', () async {
      int calls = 0;
      final mock = MockClient((req) async {
        calls++;
        if (calls == 1) return http.Response('Unauthorized', 401);
        // verify Authorization header updated
        expect(req.headers['authorization'], 'Bearer newtoken');
        return http.Response(jsonEncode({'user': 'john'}), 200, headers: {'content-type': 'application/json'});
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock, onRefreshToken: () async {
        return 'newtoken';
      });
      final res = await client.get<Map<String, dynamic>>('/me', (json) => json as Map<String, dynamic>);
      expect(res['user'], 'john');
      expect(calls, 2);
    });

    test('put sends json body and returns parsed response', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'PUT');
        expect(jsonDecode(req.body)['p'], 'v');
        return http.Response(jsonEncode({'res': 'ok'}), 200);
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock);
      final res = await client.put<Map<String, dynamic>>('/put', {'p': 'v'}, (json) => json as Map<String, dynamic>);
      expect(res['res'], 'ok');
    });

    test('delete returns parsed response', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'DELETE');
        return http.Response(jsonEncode({'deleted': true}), 200);
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock);
      final res = await client.delete<Map<String, dynamic>>('/del', (json) => json as Map<String, dynamic>);
      expect(res['deleted'], true);
    });

    test('isTokenValid returns false for empty and true for non-jwt', () async {
      final client = ApiClient(baseUrl: 'https://api.example.com', client: MockClient((req) async => http.Response('{}', 200)));
      expect(client.isTokenValid(), false);
      client.setToken('plain-token');
      expect(client.isTokenValid(), true);
    });

    test('authorization header present when token set', () async {
      final mock = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer abc123');
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final client = ApiClient(baseUrl: 'https://api.example.com', client: mock);
      client.setToken('abc123');
      final res = await client.get<Map<String, dynamic>>('/auth-test', (json) => json as Map<String, dynamic>);
      expect(res['ok'], true);
    });
  });
}
