import 'api_client.dart';
import 'models.dart';
import 'token_storage.dart';

class VpnService {
  final ApiClient api;
  VpnService({required this.api});

  // Auth
  Future<String> login(String email, String password) async {
    final res = await api.post<Map<String, dynamic>>('/auth/login', {'email': email, 'password': password}, (json) => json as Map<String, dynamic>);
    // The API uses OAuth2 password flow and likely returns a token in body; try common fields
  final token = res['access_token'] ?? res['token'] ?? res['detail'] ?? res['access'];
    if (token == null) throw Exception('No token in login response: $res');
    final tokenStr = token.toString();
    api.setToken(tokenStr);
    await TokenStorage.saveToken(tokenStr);
    return tokenStr;
  }

  Future<UserOut> register(String email, String password) async {
    final body = {'email': email, 'password': password};
    final res = await api.post<Map<String, dynamic>>('/auth/register', body, (json) => json as Map<String, dynamic>);
    return UserOut.fromJson(res);
  }

  Future<UserOut> me() async {
    final u = await api.get<Map<String, dynamic>>('/auth/me', (json) => json as Map<String, dynamic>);
    return UserOut.fromJson(u);
  }

  Future<List<TariffOut>> listTariffs({int skip = 0, int limit = 10}) async {
    final res = await api.get<List<dynamic>>('/tariffs/', (json) => json as List<dynamic>, params: {'skip': skip.toString(), 'limit': limit.toString()});
    return res.map((e) => TariffOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VpnPeerOut>> listPeers({int? userId, int skip = 0, int limit = 100}) async {
    final params = <String, String>{'skip': skip.toString(), 'limit': limit.toString()};
    if (userId != null) params['user_id'] = userId.toString();
    final res = await api.get<List<dynamic>>('/vpn_peers/', (json) => json as List<dynamic>, params: params);
    return res.map((e) => VpnPeerOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VpnPeerOut> createPeer() async {
    // Создаёт новый peer для текущего пользователя
    final res = await api.post<Map<String, dynamic>>('/vpn_peers', {}, (json) => json as Map<String, dynamic>);
    return VpnPeerOut.fromJson(res);
  }

  Future<VpnPeerOut> getPeer(int peerId) async {
    final res = await api.get<Map<String, dynamic>>('/vpn_peers/$peerId', (json) => json as Map<String, dynamic>);
    return VpnPeerOut.fromJson(res);
  }
}
