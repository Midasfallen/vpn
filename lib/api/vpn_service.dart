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
    final refresh = res['refresh_token'] ?? res['refresh'];
    if (token == null) throw Exception('No token in login response: $res');
    final tokenStr = token.toString();
    api.setToken(tokenStr);
    await TokenStorage.saveToken(tokenStr);
    if (refresh != null) await TokenStorage.saveRefreshToken(refresh.toString());
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

  Future<VpnPeerOut> createPeer({String? deviceName, String? wgPublicKey, String? wgIp, String? allowedIps}) async {
    // Server expects POST /vpn_peers/self with optional body {device_name, wg_public_key, wg_ip, allowed_ips}
    final body = <String, dynamic>{};
    if (deviceName != null) body['device_name'] = deviceName;
    if (wgPublicKey != null) body['wg_public_key'] = wgPublicKey;
    if (wgIp != null) body['wg_ip'] = wgIp;
    if (allowedIps != null) body['allowed_ips'] = allowedIps;

    final res = await api.post<Map<String, dynamic>>('/vpn_peers/self', body, (json) => json as Map<String, dynamic>);
    return VpnPeerOut.fromJson(res);
  }

  Future<VpnPeerOut> getPeer(int peerId) async {
    final res = await api.get<Map<String, dynamic>>('/vpn_peers/$peerId/', (json) => json as Map<String, dynamic>);
    return VpnPeerOut.fromJson(res);
  }

  Future<int?> getUserPeerId() async {
    // Возвращает первый peer id у пользователя или null
    final peers = await listPeers(skip: 0, limit: 10);
    if (peers.isEmpty) return null;
    return peers.first.id;
  }

  Future<VpnPeerOut> connectPeer(int peerId) async {
    // GET /vpn_peers/{peer_id}/ — возвращает информацию о peer
    final peer = await getPeer(peerId);
    return peer;
  }

  // Получить wg-quick конфиг для текущего пользователя
  // Server exposes GET or POST /vpn_peers/self/config that returns config (wg_quick) or parts to build it.
  Future<String> fetchWgQuick() async {
    // Try GET first (server may implement GET returning 404 if not stored yet)
    try {
      final resGet = await api.get<dynamic>('/vpn_peers/self/config', (json) => json);
      // If returned string or map — process below
      if (resGet is String) return resGet;
      if (resGet is Map<String, dynamic>) {
        final cfg = resGet['wg_quick'] ?? resGet['wg_quick_config'] ?? resGet['config'];
        if (cfg != null) return cfg.toString();
        final privateKey = resGet['wg_private_key'] ?? resGet['wg_private'];
        final publicKey = resGet['wg_public_key'] ?? resGet['wg_public'];
        final endpoint = resGet['endpoint'];
        final allowedIps = resGet['allowed_ips'] ?? '0.0.0.0/0';
        final wgIp = resGet['wg_ip'];
        if (privateKey != null && publicKey != null) {
          final buffer = StringBuffer();
          buffer.writeln('[Interface]');
          if (wgIp != null) buffer.writeln('Address = ${wgIp.toString()}');
          buffer.writeln('PrivateKey = ${privateKey.toString()}');
          buffer.writeln('\n[Peer]');
          buffer.writeln('PublicKey = ${publicKey.toString()}');
          if (endpoint != null) buffer.writeln('Endpoint = ${endpoint.toString()}');
          buffer.writeln('AllowedIPs = ${allowedIps.toString()}');
          return buffer.toString();
        }
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // No stored config for peer — return informative exception
        throw Exception('No stored config for peer (server returned 404). Create peer and ensure server stores config first.');
      }
      // For other statuses fall through to POST fallback
    } catch (e) {
      // Non-ApiException error — fallthrough to POST fallback
    }

    // Fallback: try POST /vpn_peers/self/config (some servers implement POST)
    try {
      final resRaw = await api.post<dynamic>('/vpn_peers/self/config', {}, (json) => json);
      if (resRaw is String) return resRaw;
      if (resRaw is Map<String, dynamic>) {
        final cfg = resRaw['wg_quick'] ?? resRaw['wg_quick_config'] ?? resRaw['config'];
        if (cfg != null) return cfg.toString();
        final privateKey = resRaw['wg_private_key'] ?? resRaw['wg_private'];
        final publicKey = resRaw['wg_public_key'] ?? resRaw['wg_public'];
        final endpoint = resRaw['endpoint'];
        final allowedIps = resRaw['allowed_ips'] ?? '0.0.0.0/0';
        final wgIp = resRaw['wg_ip'];
        if (privateKey != null && publicKey != null) {
          final buffer = StringBuffer();
          buffer.writeln('[Interface]');
          if (wgIp != null) buffer.writeln('Address = ${wgIp.toString()}');
          buffer.writeln('PrivateKey = ${privateKey.toString()}');
          buffer.writeln('\n[Peer]');
          buffer.writeln('PublicKey = ${publicKey.toString()}');
          if (endpoint != null) buffer.writeln('Endpoint = ${endpoint.toString()}');
          buffer.writeln('AllowedIPs = ${allowedIps.toString()}');
          return buffer.toString();
        }
      }
    } on ApiException catch (e) {
      // rethrow with context
      throw Exception('Failed to fetch config: ${e.statusCode} ${e.body}');
    }

    throw Exception('No wg_quick or key fields in response from config endpoints');
  }

  // === Payment & IAP Methods ===

  /// Получить текущую активную подписку пользователя
  Future<UserSubscriptionOut?> getActiveSubscription() async {
    try {
      final res = await api.get<Map<String, dynamic>>('/auth/me/subscription', (json) => json as Map<String, dynamic>);
      return UserSubscriptionOut.fromJson(res);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Список платежей текущего пользователя
  Future<List<PaymentOut>> listPayments({int skip = 0, int limit = 50}) async {
    final params = <String, String>{'skip': skip.toString(), 'limit': limit.toString()};
    final res = await api.get<List<dynamic>>('/payments/', (json) => json as List<dynamic>, params: params);
    return res.map((e) => PaymentOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Проверить и активировать IAP платёж (Apple/Google)
  /// 
  /// Отправляет receipt на бэкенд для верификации.
  /// На успех: создаёт Payment, активирует подписку, возвращает объект с деталями.
  Future<IapReceiptVerificationResponse> verifyIapReceipt({
    required String receipt,
    required String provider, // 'apple' or 'google'
    String? packageName,
    String? productId,
  }) async {
    final req = IapReceiptVerificationRequest(
      receipt: receipt,
      provider: provider,
      packageName: packageName,
      productId: productId,
    );

    final res = await api.post<Map<String, dynamic>>(
      '/payments/iap_verify',
      req.toJson(),
      (json) => json as Map<String, dynamic>,
    );

    return IapReceiptVerificationResponse.fromJson(res);
  }

  /// Создать платёж вручную (для админа или других провайдеров)
  Future<PaymentOut> createPayment({
    required String amount,
    required String currency,
    required String status,
    String? provider,
    String? providerPaymentId,
    int? userId,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'status': status,
      if (provider != null) 'provider': provider,
      if (providerPaymentId != null) 'provider_payment_id': providerPaymentId,
      if (userId != null) 'user_id': userId,
    };

    final res = await api.post<Map<String, dynamic>>(
      '/payments/',
      body,
      (json) => json as Map<String, dynamic>,
    );

    return PaymentOut.fromJson(res);
  }

  /// Получить деталь платежа
  Future<PaymentOut> getPayment(int paymentId) async {
    final res = await api.get<Map<String, dynamic>>(
      '/payments/$paymentId/',
      (json) => json as Map<String, dynamic>,
    );
    return PaymentOut.fromJson(res);
  }

  /// Обновить статус платежа (например, на 'completed' после верификации)
  Future<PaymentOut> updatePaymentStatus(int paymentId, String newStatus) async {
    final body = {'status': newStatus};
    final res = await api.put<Map<String, dynamic>>(
      '/payments/$paymentId/',
      body,
      (json) => json as Map<String, dynamic>,
    );
    return PaymentOut.fromJson(res);
  }

  /// Активировать тариф для текущего пользователя (тестирование/демо)
  Future<Map<String, dynamic>> subscribeTariff(int tariffId) async {
    final body = {'tariff_id': tariffId};
    final res = await api.post<Map<String, dynamic>>(
      '/auth/subscribe',
      body,
      (json) => json as Map<String, dynamic>,
    );
    return res;
  }
}
