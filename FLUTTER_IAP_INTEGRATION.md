# Flutter VPN Client — Интеграция с Backend API и IAP

**Документ содержит**:
1. Примеры API запросов для Flutter клиента
2. Обработка ошибок и токенов
3. IAP интеграция (App Store / Google Play)
4. Примеры реализации на Dart

---

## 1. API Client на Flutter

### 1.1 Структура ApiClient (актуальная для проекта)

```dart
class ApiClient {
  final String baseUrl;
  final TokenStorage _tokenStorage;
  String? _accessToken;
  
  ApiClient({
    required this.baseUrl,
    required TokenStorage tokenStorage,
  }) : _tokenStorage = tokenStorage {
    _accessToken = null;
  }
  
  Future<void> initialize() async {
    _accessToken = await _tokenStorage.getToken();
  }
  
  Future<T> get<T>(
    String path, {
    required T Function(dynamic) mapper,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 401) {
      // Token истёк, нужен refresh (см. ниже)
      throw ApiException(response.statusCode, 'Unauthorized');
    }
    
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    
    try {
      final json = jsonDecode(response.body);
      return mapper(json);
    } catch (e) {
      throw ApiException(500, 'Failed to parse response');
    }
  }
  
  Future<T> post<T>(
    String path, {
    dynamic body,
    required T Function(dynamic) mapper,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
    
    // Аналогично get()
    ...
  }
  
  Map<String, String> _getHeaders() => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };
  
  void setToken(String token) {
    _accessToken = token;
  }
  
  void clearToken() {
    _accessToken = null;
  }
}
```

### 1.2 Примеры использования в Flutter

#### Регистрация

```dart
Future<void> register(String email, String password) async {
  try {
    final response = await apiClient.post<UserOut>(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
      },
      mapper: (json) => UserOut.fromJson(json),
    );
    
    // Пользователь создан, но нужна регистрация
    print('User registered: ${response.email}');
  } on ApiException catch (e) {
    if (e.statusCode == 400) {
      print('Email already registered');
    } else {
      print('Error: ${e.message}');
    }
  }
}
```

#### Логин

```dart
Future<void> login(String email, String password) async {
  try {
    final response = await apiClient.post<TokenOut>(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      mapper: (json) => TokenOut.fromJson(json),
    );
    
    // Сохранить токен
    await tokenStorage.saveToken(response.accessToken);
    apiClient.setToken(response.accessToken);
    
    print('Login successful');
  } on ApiException catch (e) {
    if (e.statusCode == 401) {
      print('Invalid credentials');
    }
  }
}
```

#### Создание VPN пира

```dart
Future<VpnPeerOut> createVpnPeer() async {
  try {
    final response = await apiClient.post<VpnPeerOut>(
      '/vpn_peers/self',
      body: {
        'device_name': 'iPhone 15 Pro',
      },
      mapper: (json) => VpnPeerOut.fromJson(json),
    );
    
    // Сохранить приватный ключ безопасно (только один раз!)
    if (response.wgPrivateKey != null) {
      await wireguardStorage.savePrivateKey(response.wgPrivateKey!);
    }
    
    return response;
  } on ApiException catch (e) {
    if (e.statusCode == 403) {
      print('User not active');
    }
  }
}
```

#### Получить конфиг WireGuard

```dart
Future<String> getWireGuardConfig() async {
  try {
    final response = await apiClient.get(
      '/vpn_peers/self/config',
      mapper: (json) {
        if (json is Map && json.containsKey('wg_quick')) {
          return json['wg_quick'] as String;
        }
        throw Exception('Invalid config response');
      },
    );
    
    return response;
  } on ApiException catch (e) {
    if (e.statusCode == 404) {
      print('No peer config found');
    }
  }
}
```

#### Получить тарифы

```dart
Future<List<TariffOut>> getTariffs() async {
  try {
    final response = await apiClient.get<List<TariffOut>>(
      '/tariffs/?skip=0&limit=10',
      mapper: (json) {
        if (json is List) {
          return json.map((item) => TariffOut.fromJson(item)).toList();
        }
        return [];
      },
    );
    
    return response;
  } on ApiException catch (e) {
    print('Error fetching tariffs: ${e.message}');
    return [];
  }
}
```

---

## 2. Обработка ошибок

### 2.1 Глобальный error mapper

```dart
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, List<String>>? fieldErrors; // Для валидации
  
  ApiException(this.statusCode, this.message, {this.fieldErrors});
  
  @override
  String toString() => 'ApiException($statusCode): $message';
  
  // Локализованное сообщение
  String getLocalizedMessage(BuildContext context) {
    switch (statusCode) {
      case 400:
        return 'Invalid request'.tr();
      case 401:
        return 'Unauthorized, please login again'.tr();
      case 403:
        return 'Access forbidden'.tr();
      case 404:
        return 'Resource not found'.tr();
      case 422:
        return 'Validation error'.tr();
      case 429:
        return 'Too many requests, please wait'.tr();
      case 500:
      case 502:
      case 503:
        return 'Server error, please try again later'.tr();
      default:
        return 'An error occurred'.tr();
    }
  }
}
```

### 2.2 Перехват 401 и refresh token (рекомендуется добавить)

```dart
Future<T> _makeRequestWithRetry<T>(
  Future<T> Function() request,
) async {
  try {
    return await request();
  } on ApiException catch (e) {
    if (e.statusCode == 401) {
      // Попытаться обновить токен
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Повторить запрос
        return await request();
      } else {
        // Logout пользователя
        await logout();
        rethrow;
      }
    }
    rethrow;
  }
}

Future<bool> _tryRefreshToken() async {
  try {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final newAccessToken = json['access_token'];
      final newRefreshToken = json['refresh_token'];
      
      await _tokenStorage.saveToken(newAccessToken);
      await _tokenStorage.saveRefreshToken(newRefreshToken);
      setToken(newAccessToken);
      
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
```

---

## 3. IAP (In-App Purchases)

### 3.1 Структура для IAP на клиенте

```dart
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPManager {
  final ApiClient apiClient;
  final InAppPurchase _iap = InAppPurchase.instance;
  
  static const Set<String> productIds = {
    'vpn_premium_monthly',
    'vpn_premium_yearly',
    'vpn_premium_lifetime',
  };
  
  List<ProductDetails> _availableProducts = [];
  
  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      print('IAP not available');
      return;
    }
    
    // Получить доступные продукты
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(productIds);
    
    _availableProducts = response.productDetails;
  }
  
  // Загрузить доступные IAP продукты
  List<ProductDetails> getAvailableProducts() => _availableProducts;
  
  // Начать платёж
  Future<void> purchaseProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );
    
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }
  
  // Восстановить покупки (для existing users)
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
  
  // Слушать обновления
  void listenToPurchaseUpdates() {
    _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) {
        for (final purchase in purchases) {
          _handlePurchase(purchase);
        }
      },
      onError: (Object error) {
        print('IAP error: $error');
      },
    );
  }
  
  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompleteMark) {
      print('Purchase pending');
      return;
    }
    
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      
      // Отправить receipt на backend для верификации
      await _verifyReceiptWithBackend(purchase);
      
      // Mark as complete
      if (purchase.pendingCompleteMark) {
        await _iap.completePurchase(purchase);
      }
    } else if (purchase.status == PurchaseStatus.canceled) {
      print('Purchase cancelled');
    } else if (purchase.status == PurchaseStatus.error) {
      print('Purchase error: ${purchase.error?.message}');
    }
  }
  
  Future<void> _verifyReceiptWithBackend(PurchaseDetails purchase) async {
    try {
      // Отправить receipt на backend
      final response = await apiClient.post(
        '/payments/iap_verify',
        body: {
          'receipt': purchase.verificationData.serverVerificationData,
          'provider': _getPlatform(),
          'product_id': purchase.productID,
        },
        mapper: (json) => json,
      );
      
      print('IAP verified: $response');
      
      // Backend обновит subscription в БД
      // Можно обновить UI
    } on ApiException catch (e) {
      print('IAP verification failed: ${e.message}');
    }
  }
  
  String _getPlatform() {
    if (Platform.isIOS) return 'app_store';
    if (Platform.isAndroid) return 'google_play';
    return 'unknown';
  }
}
```

### 3.2 Backend endpoint для IAP верификации

```python
# На backend-е (vpn_api/payments.py или отдельный модуль)

from enum import Enum

class IAPProvider(str, Enum):
    APP_STORE = "app_store"
    GOOGLE_PLAY = "google_play"

class IAPVerifyIn(BaseModel):
    receipt: str
    provider: IAPProvider
    product_id: str

@router.post("/payments/iap_verify")
async def verify_iap_receipt(
    payload: IAPVerifyIn,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Верифицировать IAP receipt и активировать subscription."""
    
    # 1. Валидировать receipt на App Store / Google Play
    try:
        if payload.provider == IAPProvider.APP_STORE:
            verified_data = await verify_apple_receipt(payload.receipt)
        elif payload.provider == IAPProvider.GOOGLE_PLAY:
            verified_data = await verify_google_receipt(payload.receipt)
        else:
            raise HTTPException(status_code=400, detail="Unknown provider")
    except Exception as e:
        logger.error(f"IAP verification failed: {e}")
        raise HTTPException(status_code=400, detail="Receipt validation failed")
    
    # 2. Извлечь данные
    transaction_id = verified_data.get("transaction_id")
    product_id = verified_data.get("product_id")
    bundle_id = verified_data.get("bundle_id")
    expires_at = verified_data.get("expires_at")
    
    # 3. Проверить двойные покупки (идемпотентность)
    existing_payment = (
        db.query(models.Payment)
        .filter(models.Payment.provider_payment_id == transaction_id)
        .first()
    )
    
    if existing_payment:
        # Уже обработали этот платёж
        return {
            "status": "already_verified",
            "expires_at": existing_payment.subscription_expires_at,
        }
    
    # 4. Найти соответствующий тариф
    # Маппинг product_id на Tariff в БД
    tariff_map = {
        "vpn_premium_monthly": 1,
        "vpn_premium_yearly": 2,
        "vpn_premium_lifetime": 3,
    }
    
    tariff_id = tariff_map.get(product_id)
    if not tariff_id:
        raise HTTPException(status_code=400, detail="Unknown product ID")
    
    tariff = db.query(models.Tariff).filter(models.Tariff.id == tariff_id).first()
    if not tariff:
        raise HTTPException(status_code=404, detail="Tariff not found")
    
    # 5. Создать Payment
    payment = models.Payment(
        user_id=current_user.id,
        amount=tariff.price,
        currency="USD",
        status="completed",
        provider=payload.provider.value,
        provider_payment_id=transaction_id,
    )
    db.add(payment)
    db.commit()
    
    # 6. Создать/обновить UserTariff
    # Удалить старые активные subscriptions этого типа
    old_subscriptions = (
        db.query(models.UserTariff)
        .filter(
            models.UserTariff.user_id == current_user.id,
            models.UserTariff.status == "active",
        )
        .all()
    )
    
    for sub in old_subscriptions:
        sub.status = "cancelled"
        sub.ended_at = datetime.now(UTC)
    
    # Создать новую subscription
    user_tariff = models.UserTariff(
        user_id=current_user.id,
        tariff_id=tariff.id,
        started_at=datetime.now(UTC),
        ended_at=expires_at,
        status="active",
    )
    db.add(user_tariff)
    db.commit()
    
    # 7. Убедиться, что пользователь активен
    current_user.status = "active"
    db.commit()
    
    return {
        "status": "verified",
        "subscription_id": user_tariff.id,
        "expires_at": expires_at,
    }


async def verify_apple_receipt(receipt_data: str) -> dict:
    """Верифицировать App Store receipt."""
    import httpx
    
    # Apple Sandbox / Production endpoints
    SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt"
    PRODUCTION = "https://buy.itunes.apple.com/verifyReceipt"
    
    async with httpx.AsyncClient() as client:
        for url in [SANDBOX, PRODUCTION]:
            response = await client.post(
                url,
                json={
                    "receipt-data": receipt_data,
                    "password": os.getenv("APPLE_IAP_SECRET"),
                },
            )
            
            result = response.json()
            
            if result.get("status") == 0:
                # Success
                receipt = result["receipt"]
                
                # Извлечь данные последней покупки
                latest = receipt.get("in_app", [{}])[-1]
                
                return {
                    "transaction_id": latest.get("transaction_id"),
                    "product_id": latest.get("product_id"),
                    "bundle_id": receipt.get("bundle_id"),
                    "expires_at": datetime.fromisoformat(
                        latest.get("expires_date_ms", "0")[:10]
                    ),
                }
    
    raise Exception("Apple receipt verification failed")


async def verify_google_receipt(receipt_data: str) -> dict:
    """Верифицировать Google Play receipt."""
    import httpx
    
    # Google Play API
    package_name = os.getenv("GOOGLE_PLAY_PACKAGE_NAME")
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://www.googleapis.com/androidpublisher/v3/"
                f"applications/{package_name}/purchases/subscriptions/verify",
                json={
                    "packageName": package_name,
                    "subscriptionId": ...,  # product_id
                    "token": receipt_data,
                },
                headers={
                    "Authorization": f"Bearer {await _get_google_access_token()}",
                },
            )
            
            result = response.json()
            
            return {
                "transaction_id": result.get("purchaseToken"),
                "product_id": result.get("subscriptionId"),
                "bundle_id": package_name,
                "expires_at": datetime.fromtimestamp(
                    int(result.get("expiryTimeMillis", 0)) / 1000
                ),
            }
    except Exception as e:
        raise Exception(f"Google receipt verification failed: {e}")
```

### 3.3 IAP Webhook от App Store (Server-to-Server)

```python
# На backend-е для обработки App Store webhook-ов

@router.post("/payments/webhook/app_store")
async def app_store_webhook(
    request: Request,
    db: Session = Depends(get_db),
):
    """Обработать App Store Server-to-Server notification."""
    
    payload = await request.json()
    signed_payload = payload.get("signedPayload")
    
    try:
        # Верифицировать JWT подпись
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.backends import default_backend
        import jwt
        
        # Загрузить Apple public key из кеша или API
        cert = await _get_apple_certificate()
        
        decoded = jwt.decode(
            signed_payload,
            cert,
            algorithms=["ES256"],
        )
        
        # Обработать notification
        notification_type = decoded.get("notificationType")
        
        if notification_type == "SUBSCRIBED":
            # Новая подписка
            transaction_id = decoded.get("transactionId")
            product_id = decoded.get("productId")
            
            # Найти пользователя и активировать тариф
            payment = (
                db.query(models.Payment)
                .filter(models.Payment.provider_payment_id == transaction_id)
                .first()
            )
            
            if not payment:
                # Создать новый Payment (если не был создан на клиенте)
                ...
        
        elif notification_type == "DID_RENEW":
            # Авто-продление подписки
            transaction_id = decoded.get("transactionId")
            
            # Обновить UserTariff.ended_at
            ...
        
        elif notification_type in ["EXPIRED", "DID_FAIL_TO_RENEW"]:
            # Подписка истекла или платёж не удался
            transaction_id = decoded.get("transactionId")
            
            # Деактивировать UserTariff
            ...
        
        return {"status": "processed"}
    
    except Exception as e:
        logger.error(f"App Store webhook error: {e}")
        return {"status": "error", "message": str(e)}
```

---

## 4. Интеграция подписок в UI

### 4.1 Home Screen с отображением статуса подписки

```dart
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late VpnService _vpnService;
  UserOut? _user;
  UserTariff? _activeTariff;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      _user = await _vpnService.getMe();
      _activeTariff = await _vpnService.getActiveTariff();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e'.tr())),
      );
    }
    
    setState(() => _isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('VPN Status'.tr()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Статус подписки
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subscription Status'.tr()),
                    SizedBox(height: 8),
                    if (_activeTariff != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plan: ${_activeTariff!.tariff.name}'),
                          Text(
                            'Expires: ${_activeTariff!.endedAt?.toString() ?? 'Unlimited'.tr()}',
                          ),
                        ],
                      )
                    else
                      Text('No active subscription'.tr()),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showSubscriptionOptions,
                      child: Text('Upgrade'.tr()),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // VPN статус и toggle
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('VPN Status'.tr()),
                    Switch(
                      value: _vpnEnabled,
                      onChanged: (value) => _toggleVpn(value),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSubscriptionOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SubscriptionBottomSheet(
        onPurchase: (product) => _handlePurchase(product),
      ),
    );
  }
  
  Future<void> _handlePurchase(ProductDetails product) async {
    try {
      await _iapManager.purchaseProduct(product);
      // IAP обновит UI через purchaseStream listener
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e'.tr())),
      );
    }
  }
}
```

---

## 5. Локализованные сообщения об ошибках

**assets/langs/en.json**:
```json
{
  "unauthorized": "Please log in to continue",
  "user_not_active": "Your account is not activated. Please contact support",
  "email_already_registered": "This email is already registered",
  "password_min_length": "Password must be at least 8 characters",
  "invalid_credentials": "Invalid email or password",
  "tariff_not_found": "The selected plan is not available",
  "peer_creation_failed": "Failed to create VPN peer. Please try again",
  "no_active_subscription": "You need an active subscription to use VPN",
  "iap_verification_failed": "Failed to verify purchase. Please try again",
  "server_error": "Server error. Please try again later"
}
```

**assets/langs/ru.json**:
```json
{
  "unauthorized": "Пожалуйста, войдите в аккаунт",
  "user_not_active": "Ваш аккаунт не активирован. Свяжитесь с поддержкой",
  "email_already_registered": "Этот email уже зарегистрирован",
  "password_min_length": "Пароль должен содержать минимум 8 символов",
  "invalid_credentials": "Неправильный email или пароль",
  "tariff_not_found": "Выбранный тариф недоступен",
  "peer_creation_failed": "Ошибка при создании VPN пира. Попробуйте снова",
  "no_active_subscription": "Для использования VPN нужна активная подписка",
  "iap_verification_failed": "Ошибка при верификации покупки. Попробуйте снова",
  "server_error": "Ошибка сервера. Попробуйте позже"
}
```

---

## 6. Тестирование IAP (Sandbox)

### iOS

1. Создать sandbox тестовый аккаунт в App Store Connect
2. В Xcode: Scheme → Edit Scheme → Run → Pre-actions
3. Добавить environment variable: `APP_SANDBOX=true`
4. При запуске приложение будет использовать Sandbox
5. Логиниться под sandbox аккаунтом для тестирования

### Android

1. Создать тестовый Google Play аккаунт
2. Добавить в Google Play Console → Тестирование → Лицензированные тестеры
3. Установить APK на тестовый девайс
4. Google Play автоматически переключит на Sandbox

---

## 7. Контрольный список интеграции IAP

- [ ] Configured App Store Connect (iOS)
- [ ] Configured Google Play Console (Android)
- [ ] Created sandbox test accounts
- [ ] Implemented IAP product IDs in app
- [ ] Backend endpoint `/payments/iap_verify` работает
- [ ] App Store webhook настроен
- [ ] Google Play webhook настроен
- [ ] Receipt verification работает в Sandbox
- [ ] Subscription автоматически активируется после покупки
- [ ] Subscription автоматически деактивируется при истечении
- [ ] Тестирование на реальных девайсах (iOS + Android)
- [ ] Локализованные сообщения об ошибках

---

**Конец документации**

Версия 1.0 — Интеграция Flutter клиента с backend API и IAP платежами.
