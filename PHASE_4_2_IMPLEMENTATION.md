# Phase 4.2 - Flutter IAP Client Implementation ✅

**Status**: COMPLETED  
**Date**: 2025-12-03  
**Focus**: Flutter in-app purchase integration with backend webhook

## Summary

Successfully implemented Flutter IAP client for subscription management:
- ✅ Added `in_app_purchase: ^3.2.3` dependency
- ✅ Created `lib/api/iap_manager.dart` - Core IAP functionality
- ✅ Updated `lib/subscription_screen.dart` - Full subscription UI  
- ✅ Integrated with backend via `VpnService.verifyIapReceipt()`

## Files Created/Modified

### 1. ✅ `pubspec.yaml` (UPDATED)

**Added Dependency**:
```yaml
in_app_purchase: ^3.2.3
```

Also includes platform-specific packages:
- `in_app_purchase_android: ^0.4.0`
- `in_app_purchase_storekit: ^0.4.6`

---

### 2. ✅ `lib/api/iap_manager.dart` (NEW - 180 lines)

**Purpose**: Singleton manager for IAP lifecycle

**Key Responsibilities**:
- Initialize IAP plugin and product queries
- Listen to purchase stream and process updates
- Send receipts to backend for validation
- Restore previous purchases on app launch

**Public API**:

```dart
class IapManager {
  factory IapManager() => _instance;
  
  /// Initialize manager with VpnService
  Future<void> initialize(VpnService vpnService)
  
  /// Get list of available products
  Future<List<ProductDetails>> getProducts()
  
  /// Purchase a product (non-consumable)
  Future<bool> purchaseProduct(ProductDetails product)
  
  /// Cleanup resources
  Future<void> dispose()
}
```

**Product IDs**:
```dart
const String _kAppleProductIdMonthly = 'com.example.vpn.monthly';
const String _kAppleProductIdAnnual = 'com.example.vpn.annual';
const String _kAppleProductIdLifetime = 'com.example.vpn.lifetime';
```

**Purchase Flow**:

```
1. initialize() called from main.dart
   ↓
2. _queryProducts() fetches available products from App Store/Play Store
   ↓
3. User taps "Purchase" button → purchaseProduct(product)
   ↓
4. Platform shows IAP dialog (App Store or Play Store)
   ↓
5. User confirms payment
   ↓
6. Platform delivers PurchaseDetails via purchaseStream
   ↓
7. _handlePurchaseUpdate() processes the purchase
   ↓
8. _sendReceiptToBackend(purchase) sends receipt to backend webhook
   ↓
9. Backend validates receipt and creates Payment + UserTariff
   ↓
10. completePurchase() marks purchase as consumed
```

**Error Handling**:
- Products not found warnings logged
- Network errors caught and logged
- Failed receipts rejected by backend (HTTP 400)
- Duplicate receipts idempotent (returns existing payment)

---

### 3. ✅ `lib/subscription_screen.dart` (UPDATED - 320+ lines)

**Widgets**:

#### SubscriptionScreen
Main screen with two sections:
- Current subscription status (if active)
- Available plans for purchase

**State Management**:
```dart
List<ProductDetails>? _products;      // From IAP
Map<String, dynamic>? _currentSubscription;  // From backend /auth/me/subscription
bool _loading = true;
String? _error;
String? _purchasingProductId;  // Track in-progress purchase
```

**Methods**:

```dart
/// Load subscription data from backend and IAP
Future<void> _loadSubscriptionData()

/// Handle product purchase
Future<void> _handlePurchase(ProductDetails product)

/// Build UI card for current subscription
Widget _buildCurrentSubscriptionCard()

/// Build UI card when no subscription
Widget _buildNoSubscriptionCard()

/// Build UI card for each available plan
Widget _buildPlanCard(ProductDetails product)
```

**UI Flow**:

1. **Loading State**: Show CircularProgressIndicator
2. **Error State**: Show error message with retry button
3. **Loaded State**:
   - Display current active subscription (if any)
   - Show list of available plans
   - Each plan card shows: name, description, price, purchase button
   - Annual plan marked with "best_value" badge

**Subscription Card Features**:
- Shows tariff name, duration, days remaining
- Highlights if expiring within 7 days
- Shows "lifetime access" for unlimited subscriptions

---

## Integration with VpnService

### Backend Endpoint: `POST /payments/webhook`

**Called by**: `IapManager._sendReceiptToBackend()`  
**Executed via**: `VpnService.verifyIapReceipt()`

**Request**:
```dart
Future<IapReceiptVerificationResponse> verifyIapReceipt({
  required String receipt,
  required String provider,  // 'apple'
  String? packageName,       // 'com.example.vpn'
  String? productId,         // 'com.example.vpn.monthly'
})
```

**Backend Response** (from `IapReceiptVerificationResponse`):
```json
{
  "payment_id": 42,
  "user_tariff_id": 99,
  "tariff_id": 2,
  "msg": "Payment processed successfully"
}
```

---

## Localization Keys Added

Ensure these keys exist in `assets/langs/{en,ru}.json`:

| Key | Usage |
|-----|-------|
| `subscription` | Screen title |
| `available_plans` | Plans section header |
| `purchase` | Purchase button |
| `purchase_initiated` | Success snackbar |
| `purchase_error` | Error snackbar |
| `subscription_active` | Current subscription header |
| `no_active_subscription` | No subscription alert |
| `choose_plan_below` | Instruction text |
| `subscription_expiring_soon` | Expiry warning |
| `best_value` | Annual plan badge |
| `lifetime_access` | Lifetime subscription label |
| `days` | Days remaining label |
| `error` | Generic error |
| `retry` | Retry button |

---

## Platform Configuration

### iOS (App Store)

1. **Add Products in App Store Connect**:
   - Create In-App Purchase (Non-Consumable type)
   - Product IDs: `com.example.vpn.monthly`, `com.example.vpn.annual`, `com.example.vpn.lifetime`
   - Set prices for each tier

2. **Update `ios/Runner/Info.plist`**:
   ```xml
   <key>SKStoreProductParameterITunesItemIdentifier</key>
   <string>YOUR_APP_ID</string>
   ```

3. **Enable Capabilities** in Xcode:
   - Project → Signing & Capabilities
   - Add "In-App Purchase" capability

### Android (Google Play)

1. **Add Products in Google Play Console**:
   - Create In-App Product (Subscription type)
   - Product IDs: `com.example.vpn.monthly`, `com.example.vpn.annual`, `com.example.vpn.lifetime`

2. **Configure `android/app/build.gradle.kts`**:
   ```kotlin
   dependencies {
       implementation("com.android.billingclient:billing:7.0.0")
   }
   ```

3. **Update `AndroidManifest.xml`**:
   ```xml
   <uses-permission android:name="com.android.vending.BILLING" />
   ```

4. **Add Test Account**:
   - Settings → License Testing → Add Gmail address for testing

---

## Testing Phase 4.2

### Test with Sandbox Receipts (iOS)

1. **Setup Test Account in App Store Connect**:
   - Users → Sandbox Testers
   - Create test account with valid email

2. **Test on iOS Device/Simulator**:
   ```bash
   cd c:\vpn
   flutter run -d ios
   ```
   - Navigate to Subscription screen
   - Tap Purchase button
   - Choose test account
   - Complete "purchase" (no real charge)

3. **Verify Receipt Processing**:
   ```bash
   # Check backend logs
   ssh root@146.103.99.70 "tail -f /srv/vpn-api/logs/app.log | grep -i 'receipt'"
   ```

### Test with Google Play Sandbox (Android)

1. **Setup Test Account**:
   - Add Gmail to License Testers in Play Console
   - Wait 15 minutes for propagation

2. **Test on Android Device**:
   ```bash
   flutter run -d android
   ```
   - Navigate to Subscription screen
   - Tap Purchase button
   - Google Play billing prompt appears
   - Use test account to "purchase"

3. **Verify in Test Device**:
   - Settings → Apps → Google Play Services → Test Purchases

### Unit Tests

**File**: `test/iap_manager_test.dart`

```dart
import 'package:mockito/mockito.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:vpn/api/iap_manager.dart';
import 'package:vpn/api/vpn_service.dart';

void main() {
  group('IapManager', () {
    late MockVpnService mockVpnService;
    late IapManager iapManager;

    setUp(() {
      mockVpnService = MockVpnService();
      iapManager = IapManager();
    });

    test('initialize loads products', () async {
      when(mockVpnService.listTariffs())
          .thenAnswer((_) => Future.value([]));
      
      await iapManager.initialize(mockVpnService);
      
      final products = await iapManager.getProducts();
      expect(products, isNotEmpty);
    });

    test('purchaseProduct handles success', () async {
      final product = ProductDetails(
        id: 'com.example.vpn.monthly',
        title: 'Monthly',
        description: 'Monthly subscription',
        price: '\$9.99',
        rawPrice: 9.99,
        currencyCode: 'USD',
      );

      final success = await iapManager.purchaseProduct(product);
      
      expect(success, isTrue);
    });
  });
}
```

---

## Integration with main.dart

**Update `lib/main.dart`** to initialize IAP:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize localization
  await EasyLocalization.ensureInitialized();

  // Initialize VPN Service
  final vpnService = VpnService(api: getApiClient());

  // Initialize IAP Manager
  final iapManager = IapManager();
  try {
    await iapManager.initialize(vpnService);
  } catch (e) {
    print('Warning: IAP initialization failed: $e');
  }

  runApp(MyApp(vpnService: vpnService, iapManager: iapManager));
}
```

**Pass to SubscriptionScreen**:
```dart
SubscriptionScreen(
  vpnService: vpnService,
  iapManager: iapManager,
)
```

---

## Progress Tracking

| Phase | Task | Status |
|-------|------|--------|
| 4.1 | Backend IAP webhook | ✅ DONE |
| 4.2.1 | IapManager core | ✅ DONE |
| 4.2.2 | SubscriptionScreen UI | ✅ DONE |
| 4.2.3 | Product queries | ✅ DONE |
| 4.2.4 | Receipt transmission | ✅ DONE |
| 4.2.5 | Platform config | ⏳ TODO (manual setup) |
| 4.2.6 | Testing | ⏳ TODO |
| 4.3 | Subscription UI widget | ⏳ TODO |
| 4.4 | E2E testing & deploy | ⏳ TODO |

---

## Critical Notes

⚠️ **Before Production**:

1. **Update Product IDs**: Replace `com.example.vpn.*` with real product IDs from App Store/Play Store
2. **Update Bundle ID**: Replace `com.example.vpn` in IapManager with actual bundle ID
3. **Test Accounts**: Set up sandbox test accounts on both platforms
4. **Backend Compatibility**: Ensure backend version has Phase 4.1 changes deployed
5. **Receipt Validation**: Implement timeout in backend IapValidator to prevent hanging requests

✅ **Security Implemented**:
- Receipts validated on backend (not on client)
- Product IDs verified before creating subscriptions
- User ownership enforced on subscription endpoint
- Idempotent webhook (safe to retry)

⚠️ **Known Limitations**:
- No offline support (requires backend connectivity)
- No subscription management (cancel/change plan) - Phase 4.3
- No receipt renewal after expiry - TODO

---

## Next Steps (Phase 4.3)

### Subscription Management UI

**Tasks**:
1. Add "Manage Subscription" screen with options to:
   - View current plan details
   - Cancel subscription
   - Upgrade/downgrade plan
2. Implement subscription status polling
3. Show promotional offers/discounts
4. Add family sharing options (iOS only)

---

## Files Modified Summary

```
✅ c:\vpn\pubspec.yaml (+1 line - in_app_purchase)
✅ c:\vpn\lib\api\iap_manager.dart (NEW, 180 lines)
✅ c:\vpn\lib\subscription_screen.dart (updated, 320+ lines)
```

Total Flutter changes: 500+ lines

---

Generated: 2025-12-03  
Session: Phase 4.2 Flutter IAP Client Implementation
