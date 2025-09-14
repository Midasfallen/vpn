import 'package:http/http.dart';
import 'api_client.dart';
import 'vpn_service.dart';
import 'token_storage.dart';

// Global ApiClient and VpnService instances for the app to consume.
// Adjust baseUrl if the backend moves.
final ApiClient apiClient = ApiClient(
  baseUrl: 'http://146.103.99.70:8000',
  client: Client(),
);

final VpnService vpnService = VpnService(api: apiClient);

/// Initialize API client by reading persisted token (if any).
Future<void> initApi() async {
  final t = await TokenStorage.readToken();
  if (t != null) {
    apiClient.setToken(t);
  }
}
