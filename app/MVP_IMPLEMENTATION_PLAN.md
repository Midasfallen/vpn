# VPN Flutter App — MVP Implementation Plan

**Status:** Draft  
**Created:** December 3, 2025  
**Target Release:** Q1 2026  
**Estimated Duration:** 4-6 weeks (full-time development)

---

## 📋 Executive Summary

This is a comprehensive, phase-based roadmap to launch the VPN Flutter app to App Store and Google Play Store. The plan addresses **critical compliance requirements** that would otherwise result in app rejection, followed by feature completion, testing, and release preparation.

### Key Milestones
1. **Week 1:** Security & Compliance Foundation
2. **Week 2:** Network Robustness & Error Handling
3. **Week 3:** Code Cleanup & Localization
4. **Week 4:** API Architecture for In-App Purchases
5. **Week 5:** Purchase Integration & Privacy Documentation
6. **Week 6:** Testing, Monitoring, & Release Prep

---

## 🔴 PHASE 1: Security & Compliance Foundation (Week 1)

### Why This Phase is Critical
Without completing these tasks, the app will be **rejected during store review** for:
- VPN functionality without proper permissions
- Logging sensitive data (security breach)
- Missing privacy documentation
- Token management issues

---

### 1.1 Remove print() & Secure Logging

**Current Issue:**
```dart
// ❌ BAD: Leaks sensitive data in console logs
print('Token: $token');
print('Response: $res');
```

**Files to Update:**
- `lib/main.dart` (SplashScreen, HomeScreen, AuthScreen)
- `lib/api/api_client.dart` 
- `test/raw_auth_vpn_test.dart`
- `test/raw_vpn_peer_test.dart`
- `lib/tools/smoke_test.dart`

**Action Items:**
```dart
// ✅ GOOD: Use ApiLogger with sanitization
ApiLogger.debug('User info', {'userId': user.id}); // Never log sensitive fields

// Implement data sanitization in ApiLogger
class ApiLogger {
  static String _sanitize(dynamic data) {
    if (data is! String) return data.toString();
    return data
        .replaceAll(RegExp(r'Bearer\s+[^\s]+'), 'Bearer [REDACTED]')
        .replaceAll(RegExp(r'email["\s:]+[^\s,"]+'), 'email: [REDACTED]')
        .replaceAll(RegExp(r'password["\s:]+[^\s,"]+'), 'password: [REDACTED]');
  }
}
```

**Effort:** 3-4 hours  
**Priority:** 🔴 CRITICAL

---

### 1.2 Declare VPN Permissions

**Files to Update:**
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Runner.entitlements`

**Android Changes:**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.BIND_VPN_SERVICE" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" /> <!-- For app selection -->

<!-- Inside <application> tag -->
<service
    android:name="com.wireguard.android.backend.GoBackend$VpnService"
    android:exported="false"
    android:permission="android.permission.BIND_VPN_SERVICE" />
```

**iOS Changes:**
```xml
<!-- ios/Runner/Runner.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.vpn</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.yourcompany.vpn</string>
    </array>
</dict>
</plist>
```

**iOS Additional Setup:**
- [ ] Xcode: Target → Signing & Capabilities → "+ Capability" → Add "Network Extension"
- [ ] Ensure Team Provisioning Profile includes VPN entitlement
- [ ] Test only on real device (VPN doesn't work on simulator)

**Effort:** 2 hours  
**Priority:** 🔴 CRITICAL

---

### 1.3 Delete Refresh Token on Logout

**File:** `lib/main.dart`

**Current Code:**
```dart
Future<void> _logout() async {
  try {
    await TokenStorage.deleteToken();
  } catch (e) { /* ... */ }
  // ❌ MISSING: deleteRefreshToken()
  apiClient.clearToken();
  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
}
```

**Updated Code:**
```dart
Future<void> _logout() async {
  try {
    await TokenStorage.deleteToken();
    await TokenStorage.deleteRefreshToken(); // ✅ NEW
  } catch (e) {
    print('TokenStorage cleanup failed: $e');
  }
  
  try {
    apiClient.clearToken();
  } catch (e) { /* ignore */ }

  if (!mounted) return;
  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
}
```

**Effort:** 0.5 hours  
**Priority:** 🔴 CRITICAL

---

### 1.4 Handle 403 Forbidden

**File:** `lib/api/error_mapper.dart`

**Current State:** No special handling for 403

**Action:**
```dart
String mapErrorToMessage(Object e) {
  if (e is ApiException) {
    final status = e.statusCode;
    
    // ✅ NEW: 403 Forbidden
    if (status == 403) {
      return 'subscription_required'.tr(); // Or: 'Your subscription has expired'
    }
    
    if (status == 401) return 'invalid_credentials'.tr();
    // ... rest of the code
  }
  return 'server_error'.tr();
}
```

**Add to localization files:**
```json
// assets/langs/en.json
{
  "subscription_required": "Your subscription has expired or is inactive. Please renew your subscription."
}

// assets/langs/ru.json
{
  "subscription_required": "Ваша подписка истекла или неактивна. Пожалуйста, продлите подписку."
}
```

**UI Integration:**
```dart
// In HomeScreen._toggleVpn():
try {
  await vpnService.connectPeer(pid);
} catch (e) {
  if (e is ApiException && e.statusCode == 403) {
    // Navigate to subscription screen
    Navigator.pushNamed(context, '/subscription');
  } else {
    final msg = mapErrorToMessage(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
```

**Effort:** 1 hour  
**Priority:** 🔴 CRITICAL

---

## 🟡 PHASE 2: Network Robustness (Week 2)

### Why This Phase Matters
Users on unstable connections (mobile, traveling) will experience crashes/hangs without proper timeout and offline handling.

---

### 2.1 Add connectivity_plus Package

**File:** `pubspec.yaml`

```yaml
dependencies:
  connectivity_plus: ^5.0.0
```

**Create Service:** `lib/services/connectivity_service.dart`

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  /// Stream of connection status changes
  Stream<bool> get connectionStatusStream {
    return _connectivity.onConnectivityChanged
        .map((result) => result != ConnectivityResult.none);
  }

  /// Check current connection status
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

**Usage in main():**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Pre-initialize connectivity check
  final hasConnection = await ConnectivityService().hasConnection();
  if (!hasConnection) {
    // Show banner on startup
  }
  
  await initApi();
  // ...
}
```

**Effort:** 1 hour  
**Priority:** 🟡 HIGH

---

### 2.2 Configure API Timeouts

**File:** `lib/api/api_client.dart`

**Add timeout configuration:**
```dart
class ApiClient {
  final String baseUrl;
  final http.Client httpClient;
  final Duration requestTimeout;
  
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.onRefreshToken,
    this.maxRetries = 3,
    this.requestTimeout = const Duration(seconds: 30), // ✅ NEW
  }) : httpClient = client ?? http.Client();

  Future<T> get<T>(String path, T Function(dynamic json) mapper, {
    Map<String, String>? params,
    Duration? timeout, // ✅ Allow override per request
  }) async {
    _validatePath(path);
    _validateMapper(mapper);
    _validateParams(params);

    final uri = Uri.parse(baseUrl + path).replace(queryParameters: params);
    final effectiveTimeout = timeout ?? requestTimeout;

    return _requestWithRefreshAndRetry<T>(
      () => httpClient.get(uri, headers: _headers())
          .timeout(effectiveTimeout, onTimeout: () {
            throw TimeoutException('Request timeout after ${effectiveTimeout.inSeconds}s');
          }),
      mapper,
    );
  }

  // Similarly for post(), put(), delete()
}
```

**Error Handling for Timeout:**
```dart
Future<T> _withRetry(Future<http.Response> Function() fn) async {
  int attempt = 0;
  while (true) {
    attempt++;
    try {
      final res = await fn();
      return res;
    } catch (err) {
      final isTransient = err is SocketException || 
                         err is HttpException || 
                         err is TimeoutException || // ✅ Include timeout
                         err is http.ClientException;
      
      if (!isTransient || attempt >= maxRetries) {
        ApiLogger.error('Request failed', err, StackTrace.current);
        rethrow;
      }
      
      final delay = Duration(milliseconds: 300 * (1 << (attempt - 1)));
      ApiLogger.info('Transient error, retrying...', {'attempt': attempt});
      await Future.delayed(delay);
    }
  }
}
```

**Effort:** 1.5 hours  
**Priority:** 🟡 HIGH

---

### 2.3 Offline Banner Widget

**File:** `lib/main.dart` (or new `lib/widgets/offline_banner.dart`)

```dart
class OfflineBanner extends StatelessWidget {
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _connectivityService.connectionStatusStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true; // Default to true if unknown
        
        if (!isConnected) {
          return Container(
            width: double.infinity,
            color: Colors.red.shade700,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'offline_mode'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink(); // Hide when online
      },
    );
  }
}
```

**Integration in VpnApp:**
```dart
class VpnApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            OfflineBanner(), // ✅ Add at top
            Expanded(child: SplashScreen()),
          ],
        ),
      ),
    );
  }
}
```

**Add localization keys:**
```json
// assets/langs/en.json
{
  "offline_mode": "No internet connection. Some features are unavailable."
}

// assets/langs/ru.json
{
  "offline_mode": "Нет подключения к интернету. Некоторые функции недоступны."
}
```

**Effort:** 1.5 hours  
**Priority:** 🟡 HIGH

---

### 2.4 Graceful Network Error Handling

**File:** `lib/api/error_mapper.dart`

**Update mapErrorToMessage:**
```dart
String mapErrorToMessage(Object e) {
  try {
    if (e is ApiException) {
      final status = e.statusCode;
      // ... existing code ...
    }
    
    if (e is TimeoutException) {
      return 'request_timeout'.tr(); // "Request took too long. Please try again."
    }
    
    if (e is SocketException) {
      return 'network_error'.tr(); // "Network error. Check your connection."
    }
    
    if (e is HttpException) {
      return 'http_error'.tr();
    }
  } catch (_) {}
  
  return 'server_error'.tr();
}
```

**Add to localization:**
```json
// assets/langs/en.json
{
  "request_timeout": "Request timed out. Please check your connection and try again.",
  "network_error": "Network error. Please check your internet connection.",
  "http_error": "HTTP error. Please try again later.",
  "connection_lost": "Connection lost. Reconnecting..."
}

// assets/langs/ru.json
{
  "request_timeout": "Время запроса истекло. Проверьте подключение и попробуйте снова.",
  "network_error": "Ошибка сети. Проверьте подключение к интернету.",
  "http_error": "HTTP ошибка. Попробуйте позже.",
  "connection_lost": "Соединение потеряно. Переподключение..."
}
```

**Effort:** 1 hour  
**Priority:** 🟡 HIGH

---

## 📝 PHASE 3: Localization & Code Cleanup (Week 3)

### Why Important
- **Compliance:** Store guidelines require proper localization
- **Quality:** Magic strings are hard to maintain and test
- **UX:** Consistent terminology across the app

---

### 3.1 Create App Strings Constants

**File:** `lib/constants/app_strings.dart` (NEW)

```dart
/// Centralized string keys for localization.
/// Use with `.tr()` extension from easy_localization.
class AppStrings {
  // Common
  static const ok = 'ok';
  static const cancel = 'cancel';
  static const error = 'error';
  static const success = 'success';
  static const loading = 'loading';
  
  // Auth
  static const passwordLabel = 'password_label';
  static const emailLabel = 'email_label';
  static const emailHint = 'email_hint';
  static const passwordHint = 'password_hint';
  static const confirmPasswordHint = 'confirm_password_hint';
  static const loginButton = 'login';
  static const signupButton = 'signup';
  static const logoutButton = 'logout';
  static const forgotPasswordButton = 'forgot_password';
  
  // VPN
  static const vpnConnected = 'vpn_connected';
  static const vpnDisconnected = 'vpn_disconnected';
  static const vpnToggle = 'vpn_toggle';
  
  // Subscription
  static const buySubscription = 'buy_subscription';
  static const choosePlan = 'choose_plan';
  static const purchase = 'purchase';
  static const subscriptionRequired = 'subscription_required';
  
  // Errors
  static const invalidCredentials = 'invalid_credentials';
  static const networkError = 'network_error';
  static const serverError = 'server_error';
  static const passwordMinLength = 'password_min_length';
  static const emailAlreadyRegistered = 'email_already_registered';
}
```

**Effort:** 0.5 hours  
**Priority:** 🟡 MEDIUM

---

### 3.2 Localize PasswordField

**File:** `lib/main.dart`

**Current Code:**
```dart
class PasswordField extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Пароль', // ❌ Magic string
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
```

**Updated Code:**
```dart
class PasswordField extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: AppStrings.passwordLabel.tr(), // ✅ Localized
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
```

**Add to localization files:**
```json
// assets/langs/en.json
{
  "password_label": "Password",
  "password_hint": "Enter password"
}

// assets/langs/ru.json
{
  "password_label": "Пароль",
  "password_hint": "Введите пароль"
}
```

**Effort:** 0.5 hours  
**Priority:** 🟡 MEDIUM

---

### 3.3 Localize All UI Strings

**Files to Update:** `lib/main.dart` (all screens)

**Pattern for SnackBars:**
```dart
// ❌ Current
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('VPN отключен'))
);

// ✅ Updated
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(AppStrings.vpnDisconnected.tr()))
);
```

**Pattern for Dialogs:**
```dart
// ❌ Current
showDialog(
  builder: (ctx) => AlertDialog(
    title: const Text('Покупка'),
    content: Text('В будущем будет открыт телеграм-бот...'),
  ),
);

// ✅ Updated
showDialog(
  builder: (ctx) => AlertDialog(
    title: Text('purchase_title'.tr()),
    content: Text('purchase_confirm_message'.tr()),
  ),
);
```

**Update localization files with all strings:**
- Login/Signup messages
- VPN status messages
- Subscription messages
- Buttons, hints, labels

**Effort:** 2 hours  
**Priority:** 🟡 MEDIUM

---

### 3.4 Clean Up Logging (Remove print())

**Files:** `lib/main.dart`, `test/raw_auth_vpn_test.dart`, `lib/tools/smoke_test.dart`

**Replace all:**
```dart
// ❌ Remove
print('Login response: $res');

// ✅ Replace with
ApiLogger.debug('Login response', {'status': 'success'});
```

**Effort:** 1 hour  
**Priority:** 🟡 MEDIUM

---

### 3.5 Fix SplashScreen Navigation

**File:** `lib/main.dart`

**Current Code:**
```dart
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (!Navigator.canPop(context)) { // ❌ Non-standard check
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }
}
```

**Updated Code:**
```dart
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }
  
  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
```

**Effort:** 0.5 hours  
**Priority:** 🟡 MEDIUM

---

## 🛒 PHASE 4: API Architecture for In-App Purchase (Week 4)

### Why This Phase is Critical
- App Store / Google Play require IAP (In-App Purchase) for digital goods
- Must validate receipts server-side to prevent fraud
- Subscription status should be real-time from backend

---

### 4.1 Backend: POST /subscriptions/verify-receipt

**Endpoint:** `POST /subscriptions/verify-receipt`

**Request:**
```json
{
  "receipt_token": "string (from Play Billing / StoreKit)",
  "product_id": "string (e.g., 'premium_monthly')",
  "platform": "string ('ios' or 'android')"
}
```

**Response:**
```json
{
  "subscription_active": boolean,
  "plan_id": integer,
  "plan_name": "Premium Monthly",
  "expires_at": "2025-01-15T10:00:00Z",
  "renewable": boolean,
  "cancel_at_period_end": boolean
}
```

**Implementation Notes:**
- Call Google Play API or Apple StoreKit for receipt validation
- Cache result for 1 hour to avoid excessive API calls
- Mark fraudulent receipts and log for review

**Effort:** 4-6 hours (backend)

---

### 4.2 Backend: GET /subscriptions/me

**Endpoint:** `GET /subscriptions/me` (authenticated)

**Response:**
```json
{
  "id": 123,
  "user_id": 456,
  "plan_id": 1,
  "plan_name": "Premium Monthly",
  "active": boolean,
  "started_at": "2025-01-01T10:00:00Z",
  "expires_at": "2025-02-01T10:00:00Z",
  "cancelled_at": null,
  "cancel_at_period_end": false
}
```

**Usage in App:** HomeScreen will fetch this instead of hardcoding subscription status

**Effort:** 2-3 hours (backend)

---

### 4.3 Model: SubscriptionOut

**File:** `lib/api/models.dart`

```dart
class SubscriptionOut {
  final int id;
  final int userId;
  final int planId;
  final String planName;
  final bool active;
  final String startedAt;
  final String expiresAt;
  final String? cancelledAt;
  final bool cancelAtPeriodEnd;

  SubscriptionOut({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.active,
    required this.startedAt,
    required this.expiresAt,
    this.cancelledAt,
    required this.cancelAtPeriodEnd,
  });

  factory SubscriptionOut.fromJson(Map<String, dynamic> json) => SubscriptionOut(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    planId: json['plan_id'] as int,
    planName: json['plan_name'] as String,
    active: json['active'] as bool? ?? false,
    startedAt: json['started_at'] as String,
    expiresAt: json['expires_at'] as String,
    cancelledAt: json['cancelled_at'] as String?,
    cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
  );

  bool get isExpired => DateTime.parse(expiresAt).isBefore(DateTime.now());

  Duration get daysRemaining {
    final expiry = DateTime.parse(expiresAt);
    return expiry.difference(DateTime.now());
  }
}
```

**Effort:** 0.5 hours

---

### 4.4 VpnService.getSubscription()

**File:** `lib/api/vpn_service.dart`

```dart
class VpnService {
  // ... existing code ...

  Future<SubscriptionOut?> getSubscription() async {
    try {
      final res = await api.get<Map<String, dynamic>>(
        '/subscriptions/me',
        (json) => json as Map<String, dynamic>,
      );
      return SubscriptionOut.fromJson(res);
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        return null; // No active subscription
      }
      rethrow;
    }
  }

  Future<bool> verifyReceipt(String receiptToken, String productId) async {
    final res = await api.post<Map<String, dynamic>>(
      '/subscriptions/verify-receipt',
      {
        'receipt_token': receiptToken,
        'product_id': productId,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
      (json) => json as Map<String, dynamic>,
    );
    return res['subscription_active'] as bool? ?? false;
  }
}
```

**Effort:** 1 hour

---

### 4.5 VpnService.verifyReceipt()

Already implemented in 4.4. This method will be called by PurchaseService after successful purchase.

---

## 🛍️ PHASE 5: In-App Purchase Integration (Week 5)

### Why This Phase Matters
- Necessary for app store compliance
- Handles free tier + premium tiers
- Manages receipts and subscription state

---

### 5.1 Add in_app_purchase Package

**File:** `pubspec.yaml`

```yaml
dependencies:
  in_app_purchase: ^4.1.0
```

**Android Configuration:**
- Already handled by plugin
- No additional setup needed

**iOS Configuration:**
- [ ] App Store Connect: Create products (com.yourcompany.vpn.premium_monthly, etc.)
- [ ] Get App Store Shared Secret for receipt validation

**Effort:** 1 hour (setup)

---

### 5.2 Create PurchaseService

**File:** `lib/api/purchase_service.dart` (NEW)

```dart
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  factory PurchaseService() {
    return _instance;
  }

  PurchaseService._internal() {
    _initPurchaseStream();
  }

  void _initPurchaseStream() {
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        ApiLogger.error('Purchase stream error: $error', error);
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        ApiLogger.debug('Purchase pending', {'productId': purchase.productID});
      } else if (purchase.status == PurchaseStatus.error) {
        ApiLogger.error('Purchase error', {'productId': purchase.productID});
      } else if (purchase.status == PurchaseStatus.purchased) {
        // Verify receipt with backend
        await _verifyPurchaseWithBackend(purchase);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.restored) {
        ApiLogger.debug('Purchase restored', {'productId': purchase.productID});
      }
    }
  }

  Future<void> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    try {
      final isValid = await vpnService.verifyReceipt(
        purchase.verificationData.serverVerificationData,
        purchase.productID,
      );
      if (!isValid) {
        ApiLogger.error('Receipt verification failed', null);
      }
    } catch (e) {
      ApiLogger.error('Failed to verify receipt with backend', e);
      rethrow;
    }
  }

  Future<bool> isAvailable() async {
    return await _iap.isAvailable();
  }

  Future<ProductDetailsResponse> getProductDetails(List<String> productIds) async {
    try {
      return await _iap.queryProductDetails(productIds.toSet());
    } catch (e) {
      ApiLogger.error('Failed to query products', e);
      rethrow;
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    try {
      await _iap.buyNonConsumable(productDetails: product);
    } catch (e) {
      ApiLogger.error('Purchase failed', e);
      rethrow;
    }
  }

  Future<List<PurchaseDetails>> getPendingPurchases() async {
    try {
      return await _iap.queryPastPurchases();
    } catch (e) {
      ApiLogger.error('Failed to query past purchases', e);
      return [];
    }
  }

  void dispose() {
    _purchaseSubscription.cancel();
  }
}

final purchaseService = PurchaseService();
```

**Effort:** 3-4 hours

---

### 5.3 Integrate PurchaseService into SubscriptionScreen

**File:** `lib/main.dart` (SubscriptionScreen)

```dart
class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<List<TariffOut>> _futureTariffs;
  late Future<List<ProductDetails>> _futureProducts;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _futureTariffs = vpnService.listTariffs(skip: 0, limit: 50);
    _futureProducts = _loadProducts();
  }

  Future<List<ProductDetails>> _loadProducts() async {
    if (!await purchaseService.isAvailable()) {
      return [];
    }
    
    try {
      final response = await purchaseService.getProductDetails([
        'com.yourcompany.vpn.monthly',
        'com.yourcompany.vpn.annual',
      ]);
      return response.productDetails;
    } catch (e) {
      ApiLogger.error('Failed to load products', e);
      return [];
    }
  }

  Future<void> _onBuy(ProductDetails product) async {
    setState(() => _isProcessing = true);
    
    try {
      await purchaseService.buyProduct(product);
      // Purchase will be handled via PurchaseService stream
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorToMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('purchase_title'.tr())),
      body: FutureBuilder<List<ProductDetails>>(
        future: _futureProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final products = snapshot.data ?? [];
          
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.title),
                subtitle: Text(product.description),
                trailing: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _onBuy(product),
                  child: Text('purchase'.tr()),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

**Effort:** 2-3 hours

---

### 5.4 Handle Pending Purchases on App Start

**File:** `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initApi();
  
  // Restore pending purchases
  await _restorePendingPurchases();
  
  runApp(/* ... */);
}

Future<void> _restorePendingPurchases() async {
  try {
    final pendingPurchases = await purchaseService.getPendingPurchases();
    for (final purchase in pendingPurchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        // Verify and complete
        await vpnService.verifyReceipt(
          purchase.verificationData.serverVerificationData,
          purchase.productID,
        );
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  } catch (e) {
    ApiLogger.error('Failed to restore purchases', e);
  }
}
```

**Effort:** 1 hour

---

## 📋 PHASE 6: Privacy & Compliance Documentation (Week 5-6)

### Why This Phase is Critical
- **Legal:** Required by GDPR, CCPA
- **App Store:** Cannot publish without privacy policy
- **User Trust:** Transparency about data handling

---

### 6.1 Write Privacy Policy Document

**File:** `privacy_policy.md` (or publish as HTML)

```markdown
# Privacy Policy

**Last Updated:** December 2025

## 1. Introduction

[Your VPN App] ("App", "we", "us") is committed to protecting your privacy.
This Privacy Policy explains how we collect, use, and protect your information.

## 2. Information We Collect

### 2.1 Account Information
- Email address (for authentication)
- Password (hashed, never stored in plain text)
- Account creation timestamp

### 2.2 VPN Connection Data
- VPN connection logs (timestamp, duration, IP)
- **We DO NOT log:**
  - Your browsing history
  - Websites you visit
  - Traffic content

### 2.3 Device Information
- Device type (iOS/Android)
- App version
- Crash reports (via Firebase Crashlytics)

## 3. How We Use Your Information

- **Authentication:** To verify your identity
- **Service Delivery:** To provide VPN functionality
- **Analytics:** Aggregated, anonymized usage statistics
- **Support:** To troubleshoot issues

## 4. Data Retention

- Account data: Retained until account deletion
- VPN logs: Deleted within 7 days
- Crash reports: Retained for 30 days

## 5. Data Security

- All data in transit encrypted with TLS 1.3
- Tokens stored in device secure storage (flutter_secure_storage)
- No third-party data sharing

## 6. Your Rights (GDPR/CCPA)

- **Right to Access:** Request your personal data
- **Right to Deletion:** Request permanent deletion of your account
- **Right to Portability:** Export your data
- **Right to Opt-Out:** Disable analytics

### How to Exercise Your Rights

Email: privacy@yourcompany.com

## 7. Children's Privacy

This app is not intended for users under 13. We do not knowingly collect information from children.

## 8. Contact

If you have privacy concerns:
Email: privacy@yourcompany.com
Address: [Your Address]

---

## Changes to This Policy

We may update this policy. Changes are effective when posted.
```

**Publication:**
- Host on GitHub Pages or your website
- Use link in App Store / Play Store listing

**Effort:** 2-3 hours

---

### 6.2 Add Privacy Agreement Screen

**File:** `lib/main.dart` (AuthScreen)

```dart
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _agreedToPrivacy = false;

  Future<String?> _signupUser(SignupData data) async {
    if (!_agreedToPrivacy) {
      return 'must_agree_privacy'.tr();
    }

    final email = (data.name ?? '').trim();
    final password = data.password ?? '';
    try {
      await vpnService.register(email, password);
      // ... rest of signup
    } catch (e) {
      return mapErrorToMessage(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      onSignup: _signupUser,
      // ... rest of FlutterLogin config
      
      // Add custom widget for privacy agreement
      userValidator: (_) => null,
      onSubmitAnimationCompleted: () {
        if (_agreedToPrivacy) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showPrivacyDialog();
        }
      },
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('privacy_policy'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('privacy_policy_text'.tr()),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text('agree_privacy'.tr()),
                value: _agreedToPrivacy,
                onChanged: (val) {
                  setState(() => _agreedToPrivacy = val ?? false);
                  Navigator.pop(ctx);
                  if (_agreedToPrivacy) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }
}
```

**Effort:** 1 hour

---

### 6.3 Require Agreement During Registration

**Backend Change:**
```python
# In POST /auth/register
{
  "email": "user@example.com",
  "password": "...",
  "agreed_to_privacy_at": "2025-12-03T10:00:00Z"  # NEW FIELD
}
```

**Effort:** 1 hour (backend)

---

### 6.4 Add Terms of Service

**File:** `terms_of_service.md`

```markdown
# Terms of Service

## 1. Acceptable Use

You agree NOT to use this VPN for:
- Illegal activities
- Hacking or unauthorized access
- DDoS attacks
- Malware distribution

## 2. Liability

We provide the service "AS IS" without warranty. We are not liable for:
- Loss of data
- Interruption of service
- Third-party actions

## 3. Suspension

We reserve the right to suspend your account if you violate this policy.

## 4. Changes

We may modify these terms at any time. Continued use constitutes acceptance.
```

**Effort:** 1 hour

---

## 🧪 PHASE 7: Testing & Quality Assurance (Week 5-6)

### Target Coverage: >80%

---

### 7.1 Unit Tests for Auth Functions

**File:** `test/auth_test.dart` (NEW)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vpn/api/vpn_service.dart';
import 'package:vpn/api/error_mapper.dart';

class MockVpnService extends Mock implements VpnService {}

void main() {
  group('AuthScreen._authUser', () {
    late MockVpnService mockVpnService;

    setUp(() {
      mockVpnService = MockVpnService();
    });

    test('successful login returns null', () async {
      when(mockVpnService.login(any, any))
          .thenAnswer((_) async => 'token123');

      // TODO: Test _authUser with mockVpnService
    });

    test('invalid credentials returns error message', () async {
      when(mockVpnService.login(any, any))
          .thenThrow(ApiException(401, 'Unauthorized'));

      // TODO: Verify error message
    });
  });

  group('mapErrorToMessage', () {
    test('401 maps to invalid_credentials', () {
      final result = mapErrorToMessage(ApiException(401, 'Unauthorized'));
      expect(result, contains('invalid_credentials'));
    });

    test('403 maps to subscription_required', () {
      final result = mapErrorToMessage(ApiException(403, 'Forbidden'));
      expect(result, contains('subscription_required'));
    });
  });
}
```

**Effort:** 3-4 hours

---

### 7.2 Unit Tests for Error Mapping

**File:** `test/error_mapper_test.dart`

```dart
void main() {
  group('parseFieldErrors', () {
    test('extracts email field error', () {
      final exception = ApiException(
        422,
        jsonEncode({
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'already registered',
            }
          ]
        }),
      );

      final errors = parseFieldErrors(exception);
      expect(errors['email'], isNotNull);
      expect(errors['email']?.first, contains('already'));
    });
  });
}
```

**Effort:** 2 hours

---

### 7.3 Unit Tests for TokenStorage

**File:** `test/token_storage_test.dart`

```dart
void main() {
  group('TokenStorage', () {
    test('saves and retrieves token', () async {
      await TokenStorage.saveToken('test_token_123');
      final retrieved = await TokenStorage.readToken();
      expect(retrieved, equals('test_token_123'));
    });

    test('deletes token', () async {
      await TokenStorage.saveToken('test_token_123');
      await TokenStorage.deleteToken();
      final retrieved = await TokenStorage.readToken();
      expect(retrieved, isNull);
    });
  });
}
```

**Effort:** 2 hours

---

### 7.4 Widget Tests for Login Screen

**File:** `test/screens/login_screen_test.dart`

```dart
void main() {
  testWidgets('LoginScreen displays login form', (WidgetTester tester) async {
    await tester.pumpWidget(const VpnApp());
    
    expect(find.byType(FlutterLogin), findsOneWidget);
    expect(find.byType(PasswordField), findsOneWidget);
  });
}
```

**Effort:** 3-4 hours

---

### 7.5 Widget Tests for Home Screen

**File:** `test/screens/home_screen_test.dart`

**Effort:** 3-4 hours

---

### 7.6 Widget Tests for Subscription Screen

**File:** `test/screens/subscription_screen_test.dart`

**Effort:** 3-4 hours

---

### 7.7 Update API Client Tests

**File:** `test/api_client_test.dart`

Add tests for:
- 403 Forbidden
- Timeout handling
- Receipt verification endpoint

**Effort:** 2 hours

---

## 📊 PHASE 8: Firebase & Monitoring (Week 6)

### Why Important
- Production error tracking
- User behavior analytics
- Performance monitoring

---

### 8.1 Add Firebase Packages

**File:** `pubspec.yaml`

```yaml
dependencies:
  firebase_core: ^2.27.0
  firebase_crashlytics: ^3.5.0
  firebase_analytics: ^10.8.0
```

**Effort:** 0.5 hours

---

### 8.2 Setup Google Services

**Android:**
- [ ] Download `google-services.json` from Firebase Console
- [ ] Place in `android/app/`

**iOS:**
- [ ] Download `GoogleService-Info.plist`
- [ ] Add to Xcode project (ios/Runner/)

**Effort:** 1 hour

---

### 8.3 Integrate Crashlytics

**File:** `lib/firebase_init.dart` (NEW)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  // Pass all uncaught errors to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
  };

  // Also handle errors from isolates
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
```

**Integration in main():**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  // ... rest
}
```

**Effort:** 2 hours

---

### 8.4 Add Analytics Events

**File:** `lib/main.dart`

```dart
// Track login
Future<String?> _authUser(LoginData data) async {
  try {
    await vpnService.login(data.name, data.password);
    FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
    return null;
  } catch (e) {
    return mapErrorToMessage(e);
  }
}

// Track signup
Future<String?> _signupUser(SignupData data) async {
  try {
    await vpnService.register(data.name ?? '', data.password ?? '');
    FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');
    return null;
  } catch (e) {
    return mapErrorToMessage(e);
  }
}

// Track purchase
void _onBuy(ProductDetails product) async {
  try {
    await purchaseService.buyProduct(product);
    FirebaseAnalytics.instance.logPurchase(
      value: double.parse(product.price),
      currency: 'USD',
      items: [
        AnalyticsEventItem(itemName: product.id),
      ],
    );
  } catch (e) {
    // ...
  }
}
```

**Effort:** 1.5 hours

---

## ⚙️ PHASE 9: CI/CD Pipeline (Week 6)

### Why Important
- Automated quality gates
- Prevent broken commits
- Track coverage trends

---

### 9.1 Extend GitHub Actions Workflow

**File:** `.github/workflows/ci.yaml`

```yaml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
          cache: true
      - run: flutter pub get
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
          cache: true
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: true

  build-apk:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    needs: [analyze, test]
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

**Effort:** 2 hours

---

### 9.2 Add Artifact Upload

Already included in 9.1. Artifacts are available on GitHub Actions page.

---

### 9.3 Setup Codecov Integration

**File:** `.github/workflows/ci.yaml` (already included)

Codecov will track coverage trends over time. Visit codecov.io to enable.

**Effort:** 0.5 hours

---

## 📦 PHASE 10: Release Preparation (Week 6)

### Why Important
- Store guidelines compliance
- Professional presentation
- Legal requirements

---

### 10.1 Prepare Play Console Listing

**Required Fields:**
- **Title:** VPN App (short and descriptive)
- **Short Description:** (80 chars)
- **Full Description:** 4000 chars, highlighting features
- **Screenshots:** 5-8 high-quality images (1080x1920 for phones)
- **Privacy Policy URL:** Link to your privacy policy
- **Contact Email:** support@yourcompany.com

**Checklist:**
- [ ] Accurate app description
- [ ] Mention VPN encryption, privacy features
- [ ] Clear limitations (if any)
- [ ] No false claims about speed/anonymity
- [ ] Mention that it's a subscription service
- [ ] Privacy Policy URL
- [ ] Terms of Service URL

**Effort:** 3-4 hours

---

### 10.2 Prepare App Store Listing

**Required Fields:**
- **Name:** VPN App (max 30 chars)
- **Subtitle:** Fast & Secure VPN (max 30 chars)
- **Description:** 4000 chars
- **Keywords:** vpn, privacy, security, encrypted
- **Screenshots:** 2-5 images (1170x2532 for iPhone)
- **Preview Video:** Optional but recommended
- **Privacy Policy URL**
- **Support URL**
- **Category:** Productivity / Utilities

**Checklist:**
- [ ] App requires VPN capability (must declare in entitlements)
- [ ] Mention data practices (what you log, what you don't)
- [ ] Link to Privacy Policy and Terms
- [ ] No claims about bypassing restrictions
- [ ] Clear about subscription model

**Effort:** 3-4 hours

---

### 10.3 Create App Icons & Splash Screens

**Files to Create:**
- `App Icon`: 1024×1024 PNG (for both platforms)
- `Splash Screen`: 1080×1920 PNG (Android), 2208×1242 PNG (iOS)

**Recommendation:** Use flutter_native_splash package for consistent splash

```yaml
dependencies:
  flutter_native_splash: ^2.3.0
```

**Effort:** 4-5 hours (design)

---

### 10.4 Final Device Testing

**Test Matrix:**
- **Android:** 10, 12, 14 (phones & tablets)
- **iOS:** 15, 16, 17 (iPhone SE, iPhone 14 Pro)

**Test Scenarios:**
1. **Auth Flow:** Register → Login → Logout
2. **Subscription:** View tariffs → Purchase → Verify receipt
3. **VPN:** Toggle on/off (if natively integrated)
4. **Offline:** Disable internet → Check banner
5. **Error Handling:** Network timeout → Error message
6. **Localization:** Switch language → All text localized

**Effort:** 4-6 hours

---

### 10.5 Prepare Documentation

**README.md:**
```markdown
# VPN App

## Overview
Secure VPN client for Android and iOS.

## Features
- Fast & encrypted connection
- Multiple VPN locations
- Secure token management
- GDPR compliant

## Getting Started
```bash
flutter pub get
flutter run
```

## Requirements
- Flutter 3.x
- Dart 3.x
- Android 10+
- iOS 15+

## Contributing
See CONTRIBUTING.md for guidelines.

## License
MIT License
```

**CONTRIBUTING.md:**
```markdown
# Contributing

## Setup
```bash
git clone <repo>
flutter pub get
```

## Code Style
- Follow Dart style guide
- Run `dart format`
- Run `flutter analyze` before commit

## Testing
```bash
flutter test --coverage
```

## Submitting PRs
1. Create feature branch
2. Make changes
3. Run tests
4. Submit PR with description
```

**Effort:** 1 hour

---

## 📅 TIMELINE SUMMARY

```
WEEK 1: Security & Compliance
├── 1.1 Remove print() & secure logging       [4h]
├── 1.2 Declare VPN permissions               [2h]
├── 1.3 Delete refresh token on logout        [0.5h]
└── 1.4 Handle 403 Forbidden                  [1h]
    Total: ~7.5 hours

WEEK 2: Network Robustness
├── 2.1 Add connectivity_plus                 [1h]
├── 2.2 Configure timeouts                    [1.5h]
├── 2.3 Offline banner                        [1.5h]
└── 2.4 Graceful error handling               [1h]
    Total: ~5 hours

WEEK 3: Localization & Cleanup
├── 3.1 Create app strings constants          [0.5h]
├── 3.2 Localize PasswordField                [0.5h]
├── 3.3 Localize all UI strings               [2h]
├── 3.4 Clean up logging                      [1h]
└── 3.5 Fix SplashScreen navigation           [0.5h]
    Total: ~4.5 hours

WEEK 4: API Architecture
├── 4.1 Backend: verify-receipt endpoint      [5h backend]
├── 4.2 Backend: GET /subscriptions/me        [3h backend]
├── 4.3 Create SubscriptionOut model          [0.5h]
├── 4.4 VpnService.getSubscription()          [1h]
└── 4.5 VpnService.verifyReceipt()            [1h]
    Total: ~10.5 hours (5h backend, 5.5h frontend)

WEEK 5: In-App Purchase
├── 5.1 Add in_app_purchase package           [1h]
├── 5.2 Create PurchaseService                [4h]
├── 5.3 Integrate into SubscriptionScreen     [3h]
├── 5.4 Handle pending purchases              [1h]
├── 6.1 Write Privacy Policy                  [3h]
├── 6.2 Add privacy agreement screen          [1h]
├── 6.3 Require agreement on registration     [1h backend]
└── 6.4 Add Terms of Service                  [1h]
    Total: ~15 hours

WEEK 6: Testing, Monitoring, Release
├── 7.1-7.7 Testing suite (unit, widget)      [20h]
├── 8.1-8.4 Firebase integration              [5h]
├── 9.1-9.3 CI/CD pipeline                    [3h]
├── 10.1-10.5 Release preparation             [15h]
└── Final QA & bug fixes                      [10h]
    Total: ~53 hours

ESTIMATED TOTAL: ~95 hours (~2-3 weeks full-time)
```

---

## 🚀 LAUNCH CHECKLIST

### Before Submission
- [ ] All tests passing (coverage >80%)
- [ ] No lint warnings
- [ ] Privacy Policy published
- [ ] Terms of Service published
- [ ] Screenshots taken and formatted
- [ ] App icons created
- [ ] Release build tested on multiple devices
- [ ] Crashlytics configured
- [ ] Analytics events implemented

### Submission (Play Store)
- [ ] Create app listing
- [ ] Upload APK/AAB
- [ ] Fill in store metadata
- [ ] Submit for review (~24-48 hours)
- [ ] Monitor for rejection reasons

### Submission (App Store)
- [ ] Create app in App Store Connect
- [ ] Upload build via Xcode/TestFlight
- [ ] Fill in store metadata
- [ ] Request review (~24-48 hours)
- [ ] Monitor for rejection reasons

---

## 📞 Support & Communication

During the MVP launch:
- Set up support email: support@yourcompany.com
- Monitor app reviews daily
- Prepare quick-fix patches for critical issues
- Document common user issues

---

## 🎯 Success Criteria

- ✅ App passes store review on first submission
- ✅ >80% test coverage
- ✅ Zero critical security issues
- ✅ Proper privacy/compliance documentation
- ✅ <2% crash rate in production
- ✅ Sub-5 minute average VPN connect time
- ✅ Support team trained and ready

---

**Document Created:** December 3, 2025  
**Last Updated:** December 3, 2025  
**Status:** Ready for Implementation
