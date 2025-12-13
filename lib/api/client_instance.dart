import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'api_client.dart';
import 'vpn_service.dart';
import 'vpn_manager.dart';
import 'token_storage.dart';
import 'certificate_pinning.dart';

// Create HTTP client with optional certificate pinning based on environment
final http.Client _httpClient = Environment.current.enableCertificatePinning
    ? CertificatePinningClient(
        innerClient: http.Client(),
        pinnedHashes: _getPinsForEnvironment(),
        enabled: true,
      )
    : http.Client();

// Create ApiClient with onRefreshToken handler.
final ApiClient apiClient = ApiClient(
  baseUrl: Environment.current.apiBaseUrl,
  client: _httpClient,
  onRefreshToken: () async {
    final refresh = await TokenStorage.readRefreshToken();
    if (refresh == null) return null;
    try {
      final uri = Uri.parse('${Environment.current.apiBaseUrl}/auth/refresh');
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

final VpnManager vpnManager = VpnManager(vpnService: vpnService);

/// Get certificate pins based on current environment
Map<String, List<String>> _getPinsForEnvironment() {
  return switch (Environment.current.name) {
    'dev' => CertificatePinningClient.getDevelopmentPins(),
    'staging' => CertificatePinningClient.getStagingPins(),
    'prod' => CertificatePinningClient.getProductionPins(),
    _ => {},
  };
}

/// Initialize API client by reading persisted token (if any).
Future<void> initApi() async {
  final t = await TokenStorage.readToken();
  if (t != null) {
    apiClient.setToken(t);
  }
}
