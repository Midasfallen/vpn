import 'api_client.dart';
import 'models.dart';
import 'token_storage.dart';
import 'vpn_manager.dart';
import 'logging.dart';
import 'wireguard_helper.dart';

class VpnService {
  final ApiClient api;
  late final VpnManager vpnManager;

  VpnService({required this.api}) {
    // Инициализируем VpnManager с этим сервисом
    vpnManager = VpnManager(vpnService: this);
  }

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

  /// Вход через Google OAuth
  ///
  /// Backend должен реализовать endpoint POST /auth/google
  /// Принимает: { "id_token": "..." }
  /// Возвращает: { "access_token": "...", "refresh_token": "..." }
  Future<String> loginWithGoogle(String idToken) async {
    final res = await api.post<Map<String, dynamic>>(
      '/auth/google',
      {'id_token': idToken},
      (json) => json as Map<String, dynamic>,
    );
    final token = res['access_token'] ?? res['token'];
    final refresh = res['refresh_token'] ?? res['refresh'];
    if (token == null) throw Exception('No token in Google login response: $res');
    final tokenStr = token.toString();
    api.setToken(tokenStr);
    await TokenStorage.saveToken(tokenStr);
    if (refresh != null) await TokenStorage.saveRefreshToken(refresh.toString());
    ApiLogger.info('VpnService.loginWithGoogle: Успешный вход через Google');
    return tokenStr;
  }

  /// Вход через Apple OAuth
  ///
  /// Backend должен реализовать endpoint POST /auth/apple
  /// Принимает: { "identity_token": "...", "authorization_code": "...", "user_identifier": "..." }
  /// Возвращает: { "access_token": "...", "refresh_token": "..." }
  Future<String> loginWithApple({
    required String? identityToken,
    required String? authorizationCode,
    required String userIdentifier,
  }) async {
    final body = <String, dynamic>{
      'user_identifier': userIdentifier,
    };
    if (identityToken != null) body['identity_token'] = identityToken;
    if (authorizationCode != null) body['authorization_code'] = authorizationCode;

    final res = await api.post<Map<String, dynamic>>(
      '/auth/apple',
      body,
      (json) => json as Map<String, dynamic>,
    );
    final token = res['access_token'] ?? res['token'];
    final refresh = res['refresh_token'] ?? res['refresh'];
    if (token == null) throw Exception('No token in Apple login response: $res');
    final tokenStr = token.toString();
    api.setToken(tokenStr);
    await TokenStorage.saveToken(tokenStr);
    if (refresh != null) await TokenStorage.saveRefreshToken(refresh.toString());
    ApiLogger.info('VpnService.loginWithApple: Успешный вход через Apple');
    return tokenStr;
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
    // Server expects POST /vpn_peers/self with body {device_name, wg_public_key, wg_ip, allowed_ips}
    // If wg_public_key is not provided, generate a WireGuard key pair
    String? publicKey = wgPublicKey;
    
    if (publicKey == null) {
      // Generate WireGuard key pair locally
      ApiLogger.info('VpnService.createPeer: No public key provided, generating WireGuard key pair');
      final keyPair = WireGuardHelper.generateKeyPair();
      publicKey = keyPair['public']!;
      ApiLogger.info('VpnService.createPeer: Generated WireGuard key pair, public key length=${publicKey.length}');
    }
    
    final body = <String, dynamic>{};
    if (deviceName != null) body['device_name'] = deviceName;
    body['wg_public_key'] = publicKey;  // Always send the public key
    if (wgIp != null) body['wg_ip'] = wgIp;
    if (allowedIps != null) body['allowed_ips'] = allowedIps;

    ApiLogger.info('VpnService.createPeer: Sending POST /vpn_peers/self with body: $body');
    final res = await api.post<Map<String, dynamic>>('/vpn_peers/self', body, (json) => json as Map<String, dynamic>);
    ApiLogger.info('VpnService.createPeer: Server returned peer: id=${res['id']}, wg_ip=${res['wg_ip']}, has_wg_private_key=${res['wg_private_key'] != null}');
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
      ApiLogger.info('VpnService.fetchWgQuick: Trying GET /vpn_peers/self/config');
      final resGet = await api.get<dynamic>('/vpn_peers/self/config', (json) => json);
      ApiLogger.info('VpnService.fetchWgQuick: GET returned: $resGet');
      // If returned string or map — process below
      if (resGet is String) {
        ApiLogger.info('VpnService.fetchWgQuick: Got string response, size=${resGet.length} bytes');
        return resGet;
      }
      if (resGet is Map<String, dynamic>) {
        ApiLogger.info('VpnService.fetchWgQuick: Got map response with keys: ${resGet.keys.toList()}');
        final cfg = resGet['wg_quick'] ?? resGet['wg_quick_config'] ?? resGet['config'];
        if (cfg != null) {
          ApiLogger.info('VpnService.fetchWgQuick: Found wg_quick in response');
          return cfg.toString();
        }
        final privateKey = resGet['wg_private_key'] ?? resGet['wg_private'];
        final publicKey = resGet['wg_public_key'] ?? resGet['wg_public'];
        final endpoint = resGet['endpoint'];
        final allowedIps = resGet['allowed_ips'] ?? '0.0.0.0/0';
        final wgIp = resGet['wg_ip'];
        if (privateKey != null && publicKey != null) {
          ApiLogger.info('VpnService.fetchWgQuick: Building config from map parts');
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
      ApiLogger.error('VpnService.fetchWgQuick: ApiException status=${e.statusCode}: ${e.body}', e, null);
      if (e.statusCode == 404) {
        // No stored config for peer — return informative exception
        throw Exception('No stored config for peer (server returned 404). Create peer and ensure server stores config first.');
      }
      // For other statuses fall through to POST fallback
    } catch (e) {
      ApiLogger.error('VpnService.fetchWgQuick: Non-ApiException: $e', null, null);
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
      final res = await api.get<Map<String, dynamic>?>('/auth/me/subscription', (json) {
        if (json == null) return null;
        return json as Map<String, dynamic>;
      });
      if (res == null) return null;
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
