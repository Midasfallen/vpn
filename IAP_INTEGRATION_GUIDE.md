# IAP Integration Guide for VPN Flutter App

## Overview

This guide demonstrates how to integrate In-App Purchase (IAP) functionality with the VPN backend API.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Flutter Mobile App (iOS/Android)                                │
├─────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────┐         ┌──────────────────────┐       │
│ │ SubscriptionScreen   │         │ IapService           │       │
│ │ (UI)                 │         │ (Business Logic)     │       │
│ └──────────────────────┘         └──────────────────────┘       │
│           │                               │                      │
│           └───────────────────────────────┘                      │
│                       │                                          │
│               ┌───────▼────────┐                                │
│               │ VpnService     │                                │
│               │ (API Client)   │                                │
│               └───────┬────────┘                                │
│                       │                                          │
└───────────────────────┼──────────────────────────────────────────┘
                        │ HTTP(S)
         ┌──────────────▼───────────────────┐
         │ VPN Backend API                  │
         ├──────────────────────────────────┤
         │ POST /auth/login                 │
         │ POST /auth/register              │
         │ GET /tariffs/                    │
         │ POST /payments/iap_verify ◄─────┼─ Receipt Verification
         │ POST /payments/webhook           │
         └──────────────────────────────────┘
```

## Step 1: Add IAP Dependencies

### pubspec.yaml

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

dependencies:
  # iOS In-App Purchase
  app_store_kit: ^1.0.0
  
  # Android In-App Purchase (Google Play Billing)
  in_app_purchase: ^5.0.0
  
  # Or use cross-platform solution:
  iap: ^2.0.0  # recommended for both platforms
```

### Run

```bash
flutter pub get
flutter pub add app_store_kit
flutter pub add in_app_purchase
```

## Step 2: Configure Platform-Specific Setup

### iOS (Runner.xcodeproj)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select target `Runner`
3. Go to **Signing & Capabilities**
4. Click **+ Capability** and add:
   - **In-App Purchase**
   - **StoreKit Configuration**

5. In **Build Phases** → **Link Binary With Libraries**, ensure:
   - StoreKit.framework is linked

### Android (app/build.gradle.kts)

```kotlin
dependencies {
    // Google Play Billing Library
    implementation("com.android.billingclient:billing:7.0.0")
}
```

Create `android/app/src/main/AndroidManifest.xml` permission:

```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

## Step 3: Initialize IAP Service

### main.dart

```dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'api/client_instance.dart';
import 'api/iap_service.dart';
import 'subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize easy_localization
  await EasyLocalization.ensureInitialized();
  
  // Initialize API client (refresh token callback)
  final vpnService = createVpnService();
  
  // Initialize IAP Service
  final iapService = IapService(vpnService: vpnService);
  
  // Load and cache product list from App Store / Google Play
  await iapService.loadProductsList();
  
  runApp(MyApp(
    vpnService: vpnService,
    iapService: iapService,
  ));
}

class MyApp extends StatelessWidget {
  final VpnService vpnService;
  final IapService iapService;

  const MyApp({
    required this.vpnService,
    required this.iapService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: SubscriptionScreen(
        vpnService: vpnService,
        iapService: iapService,
      ),
    );
  }
}
```

## Step 4: Implement Product Configuration

### backend/products_config.dart

Create configuration for products matching App Store / Google Play:

```dart
class IapProduct {
  final String id;           // e.g., "com.example.vpn.monthly_pro"
  final String platformId;   // Platform-specific ID
  final String name;
  final String description;
  final String price;
  final int durationDays;

  IapProduct({
    required this.id,
    required this.platformId,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
  });
}

class IapProductsConfig {
  static final Map<String, IapProduct> products = {
    'monthly': IapProduct(
      id: 'monthly_subscription',
      platformId: 'com.example.vpn.monthly',
      name: 'Monthly Plan',
      description: 'Unlimited VPN for 30 days',
      price: '9.99',
      durationDays: 30,
    ),
    'yearly': IapProduct(
      id: 'yearly_subscription',
      platformId: 'com.example.vpn.yearly',
      name: 'Yearly Plan',
      description: 'Unlimited VPN for 365 days',
      price: '49.99',
      durationDays: 365,
    ),
  };
  
  static List<String> get iosProductIds =>
      products.values.map((p) => p.platformId).toList();
  
  static List<String> get androidProductIds =>
      products.values.map((p) => p.platformId).toList();
}
```

## Step 5: Handle Purchase Flow

### Complete Purchase Example

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

class PurchaseHandler {
  final IapService iapService;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  PurchaseHandler({required this.iapService});

  void initPurchaseListener() {
    // Listen for purchase updates from the platform
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdate(purchaseDetailsList);
      },
      onError: (error) {
        print('Purchase stream error: $error');
      },
    );
  }

  Future<void> _handlePurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // User hasn't completed payment, just wait
        print('Purchase pending');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Error occurred
        print('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        // Verify receipt with backend
        await _verifyWithBackend(purchaseDetails);
        
        // Mark as consumed (important for recurring purchases)
        if (purchaseDetails.productID.isNotEmpty) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchaseDetails) async {
    try {
      // Get the receipt
      final receipt = purchaseDetails.verificationData.serverVerificationData;
      
      // Determine platform
      final isIos = purchaseDetails.verificationData.source == 'app_store';
      final isAndroid = purchaseDetails.verificationData.source == 'google_play';
      
      if (isIos) {
        // Verify Apple receipt
        final response = await iapService.verifyAppStoreReceipt(
          receipt: receipt,
          productId: purchaseDetails.productID,
        );
        
        if (response.valid) {
          print('Apple receipt verified and subscription activated');
        }
      } else if (isAndroid) {
        // Verify Google Play receipt
        final response = await iapService.verifyGooglePlayReceipt(
          receipt: receipt,
          packageName: 'com.example.vpn',
          productId: purchaseDetails.productID,
        );
        
        if (response.valid) {
          print('Google Play receipt verified and subscription activated');
        }
      }
    } catch (e) {
      print('Backend verification failed: $e');
    }
  }

  Future<void> purchaseProduct(String productId) async {
    try {
      final product = InAppPurchase.instance.queryProductDetails({productId});
      if (product.productDetails.isEmpty) {
        throw Exception('Product not found: $productId');
      }
      
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product.productDetails.first,
        ),
      );
    } catch (e) {
      print('Purchase initiation failed: $e');
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
```

### Integrate into SubscriptionScreen

```dart
class SubscriptionScreen extends StatefulWidget {
  // ... existing code ...
  
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late PurchaseHandler _purchaseHandler;

  @override
  void initState() {
    super.initState();
    _purchaseHandler = PurchaseHandler(iapService: widget.iapService);
    _purchaseHandler.initPurchaseListener();
  }

  Future<void> _onPurchaseTapped(TariffOut tariff) async {
    final productId = 'com.example.vpn.tariff_${tariff.id}';
    await _purchaseHandler.purchaseProduct(productId);
  }

  @override
  void dispose() {
    _purchaseHandler.dispose();
    super.dispose();
  }

  // ... rest of the code ...
}
```

## Step 6: Backend Receipt Verification

### Backend Endpoint Implementation (FastAPI)

```python
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import aiohttp
import base64
import json

router = APIRouter(prefix="/payments", tags=["payments"])

class IapReceiptVerificationRequest(BaseModel):
    receipt: str  # Base64-encoded receipt
    provider: str  # 'apple' or 'google'
    package_name: str = None
    product_id: str = None

@router.post("/iap_verify")
async def verify_iap_receipt(
    req: IapReceiptVerificationRequest,
    current_user: User = Depends(get_current_user),
):
    """Verify IAP receipt with App Store or Google Play and activate subscription."""
    
    if req.provider == "apple":
        return await _verify_apple_receipt(req.receipt, current_user, req.product_id)
    elif req.provider == "google":
        return await _verify_google_receipt(
            req.receipt, req.package_name, current_user, req.product_id
        )
    else:
        raise HTTPException(status_code=400, detail="Unknown provider")

async def _verify_apple_receipt(receipt: str, user: User, product_id: str):
    """Verify receipt with Apple App Store."""
    async with aiohttp.ClientSession() as session:
        # Production endpoint
        url = "https://buy.itunes.apple.com/verifyReceipt"
        # Sandbox endpoint (for testing)
        # url = "https://sandbox.itunes.apple.com/verifyReceipt"
        
        payload = {
            "receipt-data": receipt,
            "password": os.getenv("APPLE_SHARED_SECRET"),
        }
        
        async with session.post(url, json=payload) as resp:
            result = await resp.json()
            
            if result.get("status") == 0:  # Valid receipt
                # Extract subscription info
                latest_receipt_info = result.get("latest_receipt_info", [{}])[0]
                
                # Create payment and activate subscription
                payment = Payment(
                    user_id=user.id,
                    amount=Decimal(latest_receipt_info.get("price_locale")),
                    currency="USD",
                    status="completed",
                    provider="apple",
                    provider_payment_id=latest_receipt_info.get("transaction_id"),
                )
                db.add(payment)
                db.commit()
                
                # Activate subscription
                tariff = db.query(Tariff).filter(Tariff.id == 1).first()  # Get tariff by ID
                if tariff:
                    user_tariff = UserTariff(
                        user_id=user.id,
                        tariff_id=tariff.id,
                        started_at=datetime.now(),
                        ended_at=datetime.now() + timedelta(days=tariff.duration_days),
                        status="active",
                    )
                    db.add(user_tariff)
                    db.commit()
                
                return {
                    "valid": True,
                    "user_id": user.id,
                    "payment_id": payment.id,
                    "message": "Subscription activated",
                    "subscription": {
                        "started_at": user_tariff.started_at.isoformat(),
                        "ended_at": user_tariff.ended_at.isoformat(),
                    },
                }
            else:
                return {"valid": False, "message": f"Invalid receipt: {result.get('status')}"}

async def _verify_google_receipt(
    receipt: str, package_name: str, user: User, product_id: str
):
    """Verify receipt with Google Play."""
    # This is a simplified example; real implementation requires:
    # 1. Get Google Play credentials (OAuth2 service account JSON)
    # 2. Use androidpublisher API to validate purchase tokens
    
    async with aiohttp.ClientSession() as session:
        url = f"https://www.googleapis.com/androidpublisher/v3/applications/{package_name}/purchases/subscriptions/{product_id}/tokens/{receipt}"
        
        headers = {
            "Authorization": f"Bearer {google_access_token}",
        }
        
        async with session.get(url, headers=headers) as resp:
            result = await resp.json()
            
            if result.get("paymentState") == 1:  # Paid
                # Similar to Apple: create payment and activate subscription
                return {
                    "valid": True,
                    "user_id": user.id,
                    "message": "Google Play receipt verified",
                }
            else:
                return {"valid": False, "message": "Invalid receipt"}
```

## Step 7: Testing

### Local Testing (Sandbox)

**iOS:**
```bash
# Use Sandbox environment for testing
# In Xcode: Product → Scheme → Edit Scheme → Run → Environment Variables
# Set: APPLE_TESTFLIGHT_ENABLED=1
```

**Android:**
```bash
# Use Google Play Console → Internal Testing track
# Testing users receive actual purchases for free but use real credit card for validation
```

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('IapService', () {
    late IapService iapService;
    late MockVpnService mockVpnService;

    setUp(() {
      mockVpnService = MockVpnService();
      iapService = IapService(vpnService: mockVpnService);
    });

    test('verifyAppStoreReceipt calls correct endpoint', () async {
      // Arrange
      const receipt = 'mock_receipt_data';
      const productId = 'com.example.vpn.monthly';
      
      when(mockVpnService.verifyIapReceipt(
        receipt: receipt,
        provider: 'apple',
        productId: productId,
      )).thenAnswer((_) async => IapReceiptVerificationResponse(
        valid: true,
        userId: 1,
        message: 'Receipt verified',
      ));

      // Act
      final response = await iapService.verifyAppStoreReceipt(receipt, productId);

      // Assert
      expect(response.valid, true);
      expect(response.userId, 1);
      verify(mockVpnService.verifyIapReceipt(
        receipt: receipt,
        provider: 'apple',
        productId: productId,
      )).called(1);
    });
  });
}
```

## Checklist

- [ ] Add IAP dependencies to pubspec.yaml
- [ ] Configure iOS In-App Purchase capability in Xcode
- [ ] Add Google Play Billing to Android build.gradle
- [ ] Create product IDs in App Store Connect and Google Play Console
- [ ] Implement PurchaseHandler class
- [ ] Integrate PurchaseHandler into SubscriptionScreen
- [ ] Implement `/payments/iap_verify` endpoint on backend
- [ ] Test with sandbox/internal testing environment
- [ ] Handle edge cases (network errors, purchase cancellation, duplicate receipts)
- [ ] Add error tracking (Sentry) for failed verifications
- [ ] Deploy to production App Store and Google Play

## Common Issues & Solutions

### Issue: "Receipt validation failed"
- **Cause**: Using wrong certificate or wrong endpoint (sandbox vs production)
- **Solution**: Use sandbox for testing, production for live users

### Issue: "Subscription not activated"
- **Cause**: Receipt verified but user_tariff creation failed
- **Solution**: Add retry logic and proper error logging on backend

### Issue: "Duplicate receipts"
- **Cause**: User completes purchase, app crashes, retries verification
- **Solution**: Use provider_payment_id as unique key; check for existing payment before creating new one

### Issue: "Purchase not reflected immediately"
- **Cause**: Network latency between device, app store, and backend
- **Solution**: Show loading indicator, refresh subscription status after 2-3 seconds

## References

- [Apple StoreKit Documentation](https://developer.apple.com/storekit/)
- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [Flutter in_app_purchase Package](https://pub.dev/packages/in_app_purchase)
- [Backend Receipt Verification (VPN_BACKEND_ARCHITECTURE.md)](../VPN_BACKEND_ARCHITECTURE.md)
