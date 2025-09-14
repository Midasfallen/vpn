import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const baseUrl = 'http://146.103.99.70:8000';

Future<void> main() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'test_user_$timestamp@example.com';
  final password = 'Password123!';

  stdout.writeln('Registering user: $email');
  try {
    final reg = await register(email, password);
    stdout.writeln('Registered user: id=${reg['id']} email=${reg['email']}');
  } catch (e) {
    stdout.writeln('Register failed: $e');
    exit(1);
  }

  stdout.writeln('Logging in...');
  String token;
  try {
    token = await login(email, password);
    stdout.writeln('Login success token length=${token.length}');
  } catch (e) {
    stdout.writeln('Login failed: $e');
    exit(1);
  }

  stdout.writeln('Calling /auth/me...');
  try {
    final me = await meInfo(token);
    stdout.writeln('Me: id=${me['id']} email=${me['email']} status=${me['status']}');
  } catch (e) {
    stdout.writeln('/auth/me failed: $e');
  }

  stdout.writeln('Listing peers...');
  try {
    final peers = await listPeers(token);
    stdout.writeln('Peers count=${peers.length}');
    for (final p in peers) {
      stdout.writeln('- peer id=${p['id']} user_id=${p['user_id']} ip=${p['wg_ip']}');
    }
  } catch (e) {
    stdout.writeln('listPeers failed: $e');
  }

  stdout.writeln('Smoke test finished');
}

Future<Map<String, dynamic>> register(String email, String password) async {
  final url = Uri.parse('$baseUrl/auth/register');
  final res = await http.post(url,
      headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password}));
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw 'Register failed: ${res.statusCode} ${res.body}';
}

Future<String> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/auth/login');
  final res = await http.post(url,
      headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password}));
  if (res.statusCode >= 200 && res.statusCode < 300) {
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) {
      // Try several common token keys
      final candidates = ['access_token', 'token', 'access', 'detail'];
      for (final k in candidates) {
        if (data.containsKey(k) && data[k] is String) return data[k] as String;
      }
      // Sometimes token is nested or returned as plain string
      if (data.values.any((v) => v is String && v.toString().length > 10)) {
        final t = data.values.firstWhere((v) => v is String && v.toString().length > 10) as String;
        return t;
      }
    } else if (data is String) {
      return data;
    }
    throw 'Login succeeded but token not found in response: ${res.body}';
  }
  throw 'Login failed: ${res.statusCode} ${res.body}';
}

Future<Map<String, dynamic>> meInfo(String token) async {
  final url = Uri.parse('$baseUrl/auth/me');
  final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw '/auth/me failed: ${res.statusCode} ${res.body}';
}

Future<List<dynamic>> listPeers(String token) async {
  final url = Uri.parse('$baseUrl/vpn_peers/');
  final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as List<dynamic>;
  }
  throw 'listPeers failed: ${res.statusCode} ${res.body}';
}
