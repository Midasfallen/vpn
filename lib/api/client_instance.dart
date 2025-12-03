import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'vpn_service.dart';
import 'token_storage.dart';

// Create ApiClient with onRefreshToken handler.
final ApiClient apiClient = ApiClient(
  baseUrl: 'http://146.103.99.70:8000',
  client: http.Client(),
  onRefreshToken: () async {
    final refresh = await TokenStorage.readRefreshToken();
    if (refresh == null) return null;
    try {
      final uri = Uri.parse('http://146.103.99.70:8000/auth/refresh');
      final r = await http.Client().post(uri,
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': refresh}));
      if (r.statusCode == 200) {
        final Map b = jsonDecode(r.body) as Map<String, dynamic>;
        final newAccess = b['access_token'] ?? b['access'];
        final newRefresh = b['refresh_token'] ?? b['refresh'];
        if (newAccess != null) {
          final tokenStr = newAccess.toString();
          await TokenStorage.saveToken(tokenStr);
          apiClient.setToken(tokenStr);
          if (newRefresh != null) await TokenStorage.saveRefreshToken(newRefresh.toString());
          return tokenStr;
        }
      }
    } catch (e) {
      // ignore and return null to signal refresh failed
    }
    return null;
  },
);

final VpnService vpnService = VpnService(api: apiClient);

/// Initialize API client by reading persisted token (if any).
Future<void> initApi() async {
  final t = await TokenStorage.readToken();
  if (t != null) {
    apiClient.setToken(t);
  }
}
