import 'dart:convert';
import 'package:http/http.dart' as http;

const base = 'http://146.103.99.70:8000';

Future<void> main() async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final email = 'test+$ts@example.com';
  final password = 'Password1!';

  try {
    await postJson('$base/auth/register', {'email': email, 'password': password});
  } catch (e) {
    return;
  }

  // LOGIN
  try {
    final login = await postJson('$base/auth/login', {'email': email, 'password': password});

    if (login.statusCode < 200 || login.statusCode >= 300) return;
    final loginJson = _tryParseJson(login.body);
    final token = loginJson['access_token'] ?? loginJson['token'] ?? loginJson['access'];
    if (token == null) return;

    // CREATE PEER
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    await http.post(Uri.parse('$base/vpn_peers/self'), headers: headers, body: jsonEncode({'device_name': 'dart-check'}));

    // FETCH CONFIG (GET then POST fallback)
    final cfgGet = await http.get(Uri.parse('$base/vpn_peers/self/config'), headers: {'Authorization': 'Bearer $token'});

    if (cfgGet.statusCode == 404) {
      await http.post(Uri.parse('$base/vpn_peers/self/config'), headers: headers, body: jsonEncode({}));
    }
  } catch (e) {
    // Error handled silently
  }
}

Future<http.Response> postJson(String url, Map<String, dynamic> body) async {
  final res = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
  return res;
}

Map<String, dynamic> _tryParseJson(String s) {
  try {
    final v = jsonDecode(s);
    if (v is Map<String, dynamic>) return v;
  } catch (_) {}
  return {};
}

