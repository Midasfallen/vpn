# Phase 4 — In-App Purchase Backend Integration

**Статус:** Ready to implement  
**Дата:** 3 декабря 2025 г.  
**Время реализации:** ~11 часов  
**Разбор:** 4 подфазы по 2-4 часа

---

## 📊 Обзор Phase 4

### Цель
Интегрировать In-App Purchase (IAP) от Apple и Google Play с backend API и Flutter клиентом. Обеспечить:
- ✅ Receipt verification от Apple/Google
- ✅ Автоматическое активирование subscription в БД
- ✅ UI для отображения статуса subscription
- ✅ Обработка webhook'ов от платёжных провайдеров

### Архитектура

```
┌─────────────────────────────────────────┐
│         Flutter App (iOS/Android)       │
├─────────────────────────────────────────┤
│  in_app_purchase package                │
│  ↓ (После успешной покупки)             │
│  Отправляет receipt на backend          │
└────────────────┬────────────────────────┘
                 │ POST /payments/ + receipt
                 ↓
┌─────────────────────────────────────────┐
│    Backend API (FastAPI)                │
├─────────────────────────────────────────┤
│ POST /payments/webhook (НОВОЕ)          │
│  ├─ Валидирует receipt от Apple/Google  │
│  ├─ Обновляет Payment.status            │
│  └─ Создаёт UserTariff                  │
│                                         │
│ GET /auth/me/subscription (НОВОЕ)       │
│  └─ Возвращает текущую subscription     │
└─────────────────────────────────────────┘
```

---

## 🔧 Phase 4.1: Backend IAP Webhook Endpoint

### 4.1.1 Создать receipt validator

**Файл:** `vpn_api/iap_validator.py` (NEW)

```python
"""
Receipt validation для Apple IAP и Google Play.
"""
import json
import os
from typing import Dict, Optional
from datetime import datetime, timedelta
import requests

class IapValidator:
    """Валидирует receipt от Apple IAP и Google Play."""
    
    # Apple constants
    APPLE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt"
    APPLE_PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt"
    
    @staticmethod
    def validate_apple_receipt(receipt: str, bundle_id: str) -> Optional[Dict]:
        """
        Валидирует Apple IAP receipt.
        
        Возвращает:
        {
            "transaction_id": "...",
            "product_id": "com.example.vpn.monthly",
            "purchase_date": datetime,
            "expiry_date": datetime,  # Для subscriptions
            "is_valid": True
        }
        """
        url = os.getenv("APPLE_RECEIPT_URL", IapValidator.APPLE_SANDBOX_URL)
        
        payload = {
            "receipt-data": receipt,
            "password": os.getenv("APPLE_APP_SECRET"),  # Shared Secret
            "exclude-old-transactions": False
        }
        
        try:
            resp = requests.post(url, json=payload, timeout=10)
            resp.raise_for_status()
            data = resp.json()
            
            if data.get("status") != 0:
                return None  # Receipt invalid
            
            # Extract latest transaction
            receipt_info = data.get("latest_receipt_info") or data.get("receipt", {}).get("in_app", [])
            
            if not receipt_info:
                return None
            
            latest = receipt_info[-1] if isinstance(receipt_info, list) else receipt_info
            
            return {
                "transaction_id": latest.get("transaction_id"),
                "product_id": latest.get("product_id"),
                "purchase_date": datetime.fromtimestamp(int(latest.get("purchase_date_ms", 0)) / 1000),
                "expiry_date": datetime.fromtimestamp(int(latest.get("expires_date_ms", 0)) / 1000) if latest.get("expires_date_ms") else None,
                "is_valid": True
            }
        except Exception as e:
            print(f"Apple receipt validation error: {e}")
            return None
    
    @staticmethod
    def validate_google_receipt(package_name: str, product_id: str, token: str) -> Optional[Dict]:
        """
        Валидирует Google Play receipt.
        
        Требует: Google Play service account JSON и refresh token
        """
        # Implement Google Play API validation
        # https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get
        # Requires: oauth2 service account credentials
        
        # Placeholder
        return None

class ProductIdToTariffMapper:
    """Маппинг product_id → tariff_id."""
    
    MAPPING = {
        "com.example.vpn.monthly": 1,      # 30 дней
        "com.example.vpn.annual": 2,       # 365 дней
        "com.example.vpn.lifetime": 3,     # Lifetime
    }
    
    @staticmethod
    def get_tariff_id(product_id: str) -> Optional[int]:
        return ProductIdToTariffMapper.MAPPING.get(product_id)
    
    @staticmethod
    def get_duration_days(tariff_id: int) -> int:
        """Получить длительность тарифа в днях."""
        # Fetch from DB
        # Simplified: return hardcoded values
        if tariff_id == 1:
            return 30
        elif tariff_id == 2:
            return 365
        elif tariff_id == 3:
            return 36500  # ~100 years
        return 0
```

### 4.1.2 Создать webhook endpoint

**Файл:** `vpn_api/payments.py` (UPDATE)

```python
from datetime import datetime, UTC, timedelta
from fastapi import Request, BackgroundTasks
from vpn_api.iap_validator import IapValidator, ProductIdToTariffMapper

@router.post("/webhook")
async def payment_webhook(
    payload: dict,
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Получает webhook от Apple IAP, Google Play или других провайдеров.
    
    Структура payload:
    {
        "provider": "apple" | "google" | "stripe",
        "provider_payment_id": "transaction_id",
        "receipt": "base64-receipt-data",  # Для Apple
        "package_name": "com.example.vpn",  # Для Google
        "bundle_id": "com.example.vpn"      # Для Apple
    }
    """
    try:
        provider = payload.get("provider")
        provider_payment_id = payload.get("provider_payment_id")
        
        if not provider or not provider_payment_id:
            raise HTTPException(status_code=400, detail="Invalid payload")
        
        # Find existing payment
        payment = (
            db.query(models.Payment)
            .filter(models.Payment.provider_payment_id == provider_payment_id)
            .first()
        )
        
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        # Validate receipt based on provider
        iap_data = None
        if provider == "apple":
            receipt = payload.get("receipt")
            bundle_id = payload.get("bundle_id")
            iap_data = IapValidator.validate_apple_receipt(receipt, bundle_id)
        elif provider == "google":
            # Implement Google validation
            pass
        
        if not iap_data:
            payment.status = models.PaymentStatus.failed
            db.commit()
            return {"status": "failed", "msg": "Receipt validation failed"}
        
        # Mark payment as completed
        payment.status = models.PaymentStatus.completed
        payment.provider_payment_id = iap_data.get("transaction_id")
        
        # Get tariff from product_id
        tariff_id = ProductIdToTariffMapper.get_tariff_id(iap_data.get("product_id"))
        
        if not tariff_id:
            db.commit()
            return {"status": "warning", "msg": "Unknown product_id"}
        
        # Create UserTariff
        user_tariff = models.UserTariff(
            user_id=payment.user_id,
            tariff_id=tariff_id,
            started_at=datetime.now(UTC),
            ended_at=datetime.now(UTC) + timedelta(
                days=ProductIdToTariffMapper.get_duration_days(tariff_id)
            ),
            status="active"
        )
        
        db.add(user_tariff)
        db.commit()
        
        # Schedule cleanup (optional): mark old subscriptions as expired
        background_tasks.add_task(mark_expired_subscriptions, payment.user_id, db)
        
        return {"status": "success", "msg": "Subscription activated"}
        
    except Exception as e:
        return {"status": "error", "msg": str(e)}


def mark_expired_subscriptions(user_id: int, db: Session):
    """Mark old subscriptions as expired (background task)."""
    now = datetime.now(UTC)
    old_subs = (
        db.query(models.UserTariff)
        .filter(
            models.UserTariff.user_id == user_id,
            models.UserTariff.status == "active",
            models.UserTariff.ended_at <= now
        )
        .all()
    )
    for sub in old_subs:
        sub.status = "expired"
    db.commit()
```

### 4.1.3 Обновить Payment schema

**Файл:** `vpn_api/schemas.py` (UPDATE)

```python
class PaymentCreate(BaseModel):
    user_id: Optional[int] = None
    amount: Decimal
    currency: str = "USD"
    provider: str  # "apple", "google", "stripe"
    provider_payment_id: Optional[str] = None
    receipt: Optional[str] = None  # Base64-encoded receipt for validation

class PaymentOut(BaseModel):
    id: int
    user_id: Optional[int]
    amount: Decimal
    currency: str
    status: str  # "pending", "completed", "failed", "refunded"
    provider: Optional[str]
    provider_payment_id: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True
```

### 4.1.4 Создать endpoint для проверки subscription

**Файл:** `vpn_api/auth.py` (ADD)

```python
@router.get("/me/subscription")
def get_user_subscription(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Получить активную subscription текущего пользователя.
    
    Возвращает:
    {
        "has_active": True/False,
        "tariff": {
            "id": 1,
            "name": "Pro Plan",
            "price": "9.99"
        },
        "started_at": "2025-12-01T00:00:00Z",
        "ends_at": "2026-01-01T00:00:00Z",
        "days_remaining": 29
    }
    """
    now = datetime.now(UTC)
    
    # Find latest active subscription
    user_tariff = (
        db.query(models.UserTariff)
        .filter(
            models.UserTariff.user_id == current_user.id,
            models.UserTariff.status == "active",
            models.UserTariff.ended_at > now
        )
        .order_by(models.UserTariff.ended_at.desc())
        .first()
    )
    
    if not user_tariff:
        return {
            "has_active": False,
            "tariff": None,
            "started_at": None,
            "ends_at": None,
            "days_remaining": 0
        }
    
    days_remaining = (user_tariff.ended_at - now).days
    
    return {
        "has_active": True,
        "tariff": {
            "id": user_tariff.tariff.id,
            "name": user_tariff.tariff.name,
            "price": str(user_tariff.tariff.price),
            "duration_days": user_tariff.tariff.duration_days
        },
        "started_at": user_tariff.started_at.isoformat(),
        "ends_at": user_tariff.ended_at.isoformat(),
        "days_remaining": days_remaining
    }
```

### 4.1.5 Требуемые переменные окружения

```bash
# Apple IAP
APPLE_APP_SECRET=your_shared_secret_from_appstoreconnect
APPLE_RECEIPT_URL=https://sandbox.itunes.apple.com/verifyReceipt  # или production URL

# Google Play
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=/path/to/service-account.json
GOOGLE_PLAY_PACKAGE_NAME=com.example.vpn

# Product ID mapping (в коде или env)
# Или в БД таблица product_id → tariff_id
```

---

## 📱 Phase 4.2: Flutter IAP Client Implementation

### 4.2.1 Добавить dependency

**Файл:** `pubspec.yaml` (UPDATE)

```yaml
dependencies:
  in_app_purchase: ^0.8.0
  in_app_purchase_android: ^0.3.0  # Android specific
  in_app_purchase_ios: ^0.1.0       # iOS specific
```

### 4.2.2 Создать IapService

**Файл:** `lib/api/iap_service.dart` (NEW)

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_ios/in_app_purchase_ios.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  
  factory IapService() {
    return _instance;
  }
  
  IapService._internal();
  
  final InAppPurchase _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  
  // Product IDs matching backend mapping
  static const Set<String> _productIds = {
    'com.example.vpn.monthly',
    'com.example.vpn.annual',
    'com.example.vpn.lifetime',
  };
  
  Future<void> initializePlatform() async {
    final iapAvailable = await _iap.isAvailable();
    if (!iapAvailable) {
      throw Exception('In-app purchases not available');
    }
    
    await _loadProducts();
  }
  
  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = 
        await _iap.queryProductDetails(_productIds);
    
    if (response.error != null) {
      throw Exception('Failed to load products: ${response.error}');
    }
    
    _products = response.productDetails;
  }
  
  List<ProductDetails> getProducts() => _products;
  
  /// Purchase a product and return the receipt
  Future<String?> purchaseProduct(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );
      
      // Trigger purchase UI
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      
      // Listen for purchase updates
      // (Simplified; see full implementation below)
      
      return null; // Will be set when purchase completes
    } catch (e) {
      print('Purchase error: $e');
      return null;
    }
  }
  
  /// Setup listeners for purchase updates
  void setupPurchaseListener(
    Function(PurchaseDetails) onPurchaseCompleted,
    Function(PurchaseDetails) onPurchaseFailed,
  ) {
    _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
          if (purchaseDetails.status == PurchaseStatus.pending) {
            // Show loading UI
          } else if (purchaseDetails.status == PurchaseStatus.error) {
            onPurchaseFailed(purchaseDetails);
          } else if (purchaseDetails.status == PurchaseStatus.purchased ||
              purchaseDetails.status == PurchaseStatus.restored) {
            onPurchaseCompleted(purchaseDetails);
          }
        }
      },
      onError: (error) {
        print('Purchase stream error: $error');
      },
    );
  }
  
  /// Get receipt for latest purchase
  Future<String?> getReceipt(PurchaseDetails purchase) async {
    if (purchase.verificationData.localVerificationData.isEmpty) {
      return null;
    }
    
    return purchase.verificationData.localVerificationData;
  }
  
  /// Complete purchase (required after handling)
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    await _iap.completePurchase(purchaseDetails);
  }
  
  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      print('Restore purchases error: $e');
    }
  }
}
```

### 4.2.3 Обновить VpnService

**Файл:** `lib/api/vpn_service.dart` (UPDATE)

```dart
class VpnService {
  // ... existing code ...
  
  /// Send receipt to backend and activate subscription
  Future<PaymentOut> processIapReceipt({
    required String receipt,
    required String productId,
    required String provider, // "apple" or "google"
  }) async {
    try {
      final response = await apiClient.post(
        '/payments/',
        body: {
          'amount': '9.99', // Should get from ProductDetails
          'currency': 'USD',
          'provider': provider,
          'provider_payment_id': productId,
          'receipt': receipt,
        },
      );
      
      return PaymentOut.fromJson(response);
    } catch (e) {
      throw ApiException(message: 'Failed to process IAP receipt: $e');
    }
  }
  
  /// Get current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final response = await apiClient.get('/auth/me/subscription');
      
      return SubscriptionStatus.fromJson(response);
    } catch (e) {
      throw ApiException(message: 'Failed to get subscription status: $e');
    }
  }
  
  /// Get available tariffs for purchase
  Future<List<TariffOut>> getAvailableTariffs() async {
    try {
      final List<dynamic> response = await apiClient.get(
        '/tariffs/',
        (json) => json as List,
      );
      
      return response.map((t) => TariffOut.fromJson(t)).toList();
    } catch (e) {
      throw ApiException(message: 'Failed to get tariffs: $e');
    }
  }
}
```

### 4.2.4 Создать модели

**Файл:** `lib/api/models.dart` (UPDATE)

```dart
class SubscriptionStatus {
  final bool hasActive;
  final TariffOut? tariff;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final int daysRemaining;
  
  SubscriptionStatus({
    required this.hasActive,
    this.tariff,
    this.startedAt,
    this.endsAt,
    this.daysRemaining = 0,
  });
  
  factory SubscriptionStatus.fromJson(Map json) {
    return SubscriptionStatus(
      hasActive: json['has_active'] ?? false,
      tariff: json['tariff'] != null 
          ? TariffOut.fromJson(json['tariff'])
          : null,
      startedAt: json['started_at'] != null 
          ? DateTime.parse(json['started_at'])
          : null,
      endsAt: json['ends_at'] != null 
          ? DateTime.parse(json['ends_at'])
          : null,
      daysRemaining: json['days_remaining'] ?? 0,
    );
  }
}

class PaymentOut {
  final int id;
  final int? userId;
  final Decimal amount;
  final String currency;
  final String status;
  final String? provider;
  final String? providerPaymentId;
  final DateTime createdAt;
  
  PaymentOut({
    required this.id,
    this.userId,
    required this.amount,
    required this.currency,
    required this.status,
    this.provider,
    this.providerPaymentId,
    required this.createdAt,
  });
  
  factory PaymentOut.fromJson(Map json) {
    return PaymentOut(
      id: json['id'],
      userId: json['user_id'],
      amount: Decimal.parse(json['amount'].toString()),
      currency: json['currency'] ?? 'USD',
      status: json['status'],
      provider: json['provider'],
      providerPaymentId: json['provider_payment_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
```

### 4.2.5 Интеграция в HomeScreen

**Файл:** `lib/main.dart` (UPDATE)

```dart
class HomeScreenState extends State<HomeScreen> {
  // ... existing code ...
  
  late IapService _iapService;
  SubscriptionStatus? _subscription;
  
  @override
  void initState() {
    super.initState();
    _initializeIap();
  }
  
  Future<void> _initializeIap() async {
    _iapService = IapService();
    
    try {
      await _iapService.initializePlatform();
      
      // Setup purchase listener
      _iapService.setupPurchaseListener(
        _onPurchaseCompleted,
        _onPurchaseFailed,
      );
      
      // Fetch subscription status
      await _refreshSubscription();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize IAP: $e'.tr())),
      );
    }
  }
  
  Future<void> _refreshSubscription() async {
    try {
      final status = await vpnService.getSubscriptionStatus();
      setState(() {
        _subscription = status;
      });
    } catch (e) {
      print('Error fetching subscription: $e');
    }
  }
  
  Future<void> _onPurchaseCompleted(PurchaseDetails purchase) async {
    try {
      // Get receipt
      final receipt = await _iapService.getReceipt(purchase);
      
      if (receipt != null) {
        // Send to backend
        await vpnService.processIapReceipt(
          receipt: receipt,
          productId: purchase.productID,
          provider: Platform.isIOS ? 'apple' : 'google',
        );
        
        // Refresh subscription
        await _refreshSubscription();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('subscription_activated'.tr())),
        );
      }
      
      // Complete purchase
      await _iapService.completePurchase(purchase);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase processing failed: $e'.tr())),
      );
    }
  }
  
  void _onPurchaseFailed(PurchaseDetails purchase) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase failed'.tr())),
    );
  }
  
  Future<void> _showBuySubscriptionDialog() async {
    try {
      final tariffs = await vpnService.getAvailableTariffs();
      final products = _iapService.getProducts();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('buy_subscription'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...products.map((product) {
                  return ListTile(
                    title: Text(product.title),
                    subtitle: Text(product.description),
                    trailing: Text(product.price),
                    onTap: () {
                      Navigator.pop(ctx);
                      _iapService.purchaseProduct(product);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tariffs: $e'.tr())),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_screen_title'.tr())),
      body: Column(
        children: [
          // ... existing offline banner ...
          
          // Subscription status widget
          if (_subscription != null)
            _buildSubscriptionCard(),
          
          // Buy subscription button
          if (_subscription?.hasActive != true)
            ElevatedButton(
              onPressed: _showBuySubscriptionDialog,
              child: Text('buy_subscription'.tr()),
            ),
          
          // ... existing VPN toggle and peers ...
        ],
      ),
    );
  }
  
  Widget _buildSubscriptionCard() {
    if (!_subscription!.hasActive) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('no_active_subscription'.tr()),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('subscription_active_until'.tr(args: [
              _subscription!.endsAt?.toString().split(' ')[0] ?? '',
            ])),
            if (_subscription!.tariff != null)
              Text('${_subscription!.tariff!.name} (${_subscription!.daysRemaining} дней осталось)'),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎨 Phase 4.3: Subscription Status Display

### 4.3.1 Обновить localization

**Файлы:** `assets/langs/ru.json`, `assets/langs/en.json`

```json
{
  "subscription_active": "Подписка активна",
  "subscription_expires": "Подписка истекает {0}",
  "days_remaining": "осталось {0} дней",
  "no_active_subscription": "Нет активной подписки",
  "buy_subscription": "Купить подписку",
  "subscription_activated": "Подписка активирована!",
  "select_plan": "Выберите план",
  "plan_monthly": "Ежемесячно - {0}/мес",
  "plan_annual": "Ежегодно - {0}/год",
  "plan_lifetime": "Пожизненно - {0}"
}
```

### 4.3.2 Создать SubscriptionWidget

**Файл:** `lib/widgets/subscription_widget.dart` (NEW)

```dart
class SubscriptionWidget extends StatelessWidget {
  final SubscriptionStatus subscription;
  final VoidCallback onBuyPressed;
  
  const SubscriptionWidget({
    required this.subscription,
    required this.onBuyPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!subscription.hasActive) {
      return _buildInactiveCard(context);
    }
    
    return _buildActiveCard(context);
  }
  
  Widget _buildInactiveCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.lock, size: 48, color: Colors.orange),
            SizedBox(height: 8),
            Text('no_active_subscription'.tr(), 
              style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: onBuyPressed,
              child: Text('buy_subscription'.tr()),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveCard(BuildContext context) {
    final daysRemaining = subscription.daysRemaining;
    final color = daysRemaining > 7 ? Colors.green : Colors.orange;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: color, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('subscription_active'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge),
                      Text('${subscription.tariff?.name}',
                        style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: (subscription.tariff?.durationDays ?? 30 - daysRemaining) / (subscription.tariff?.durationDays ?? 30),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Text('days_remaining'.tr(args: ['$daysRemaining']),
              style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
```

---

## ✅ Phase 4.4: Integration Testing и Deployment

### 4.4.1 Backend smoke tests

**Файл:** `test/iap_integration_test.dart` (NEW)

```dart
void main() {
  group('IAP Integration Tests', () {
    test('Payment webhook accepts valid Apple receipt', () async {
      // Test with sandbox receipt
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/payments/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': 'apple',
          'provider_payment_id': 'test_transaction_123',
          'receipt': 'base64_encoded_sandbox_receipt',
          'bundle_id': 'com.example.vpn',
        }),
      );
      
      expect(response.statusCode, 200);
      expect(response.body, contains('success'));
    });
    
    test('Subscription status endpoint returns active subscription', () async {
      // Login first
      final loginResp = await http.post(
        Uri.parse('http://127.0.0.1:8000/auth/login'),
        body: jsonEncode({'email': 'test@example.com', 'password': 'password123'}),
      );
      final token = jsonDecode(loginResp.body)['access_token'];
      
      // Get subscription
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/auth/me/subscription'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['has_active'], true);
      expect(data['tariff'], isNotNull);
      expect(data['days_remaining'], greaterThan(0));
    });
  });
}
```

### 4.4.2 Deployment на production

```bash
# 1. Синхронизировать код backend
cd /srv/vpn-api
git pull origin main

# 2. Установить новые зависимости (если есть)
pip install -r vpn_api/requirements.txt

# 3. Запустить миграции (если есть новые модели)
DATABASE_URL=postgresql://... alembic upgrade head

# 4. Перезагрузить сервис
sudo systemctl restart vpn-api

# 5. Проверить здоровье
curl http://146.103.99.70:8000/docs
curl -X POST http://146.103.99.70:8000/auth/login ...

# 6. Протестировать webhook
curl -X POST http://146.103.99.70:8000/payments/webhook \
  -H "Content-Type: application/json" \
  -d '{"provider":"apple","provider_payment_id":"test","receipt":"..."}'
```

### 4.4.3 Тестирование на реальном устройстве

1. **iOS:**
   - Настроить App Store Connect для testing
   - Использовать TestFlight для receipt generation
   - Тестировать на физическом устройстве

2. **Android:**
   - Настроить Google Play Console для testing
   - Использовать test product IDs
   - Тестировать на физическом устройстве

---

## 📋 ИТОГОВЫЙ ЧЕКЛИСТ PHASE 4

### Backend
- [ ] Создан `iap_validator.py` с поддержкой Apple и Google
- [ ] Реализован endpoint `POST /payments/webhook`
- [ ] Добавлен endpoint `GET /auth/me/subscription`
- [ ] Обновлены schemas и models
- [ ] Миграции Alembic (если требуются)
- [ ] Обновлены переменные окружения
- [ ] Backend развёрнут на production

### Flutter
- [ ] Добавлена dependency `in_app_purchase`
- [ ] Создан `IapService`
- [ ] Обновлён `VpnService` с методами для IAP
- [ ] Созданы модели (`SubscriptionStatus`, `PaymentOut`)
- [ ] Интегрирована IAP логика в `HomeScreen`
- [ ] Обновлена localization (ru.json, en.json)
- [ ] Создан `SubscriptionWidget`
- [ ] UI тесты пройдены

### Тестирование
- [ ] Smoke tests для webhook пройдены
- [ ] Integration tests на staging
- [ ] Тестирование на реальных устройствах (iOS + Android)
- [ ] Все тесты Flutter проходят (`flutter test`)
- [ ] `flutter analyze` чист

### Deployment
- [ ] Backend обновления deployed
- [ ] Все dependencies установлены
- [ ] Переменные окружения настроены
- [ ] Webhook доступен и работает
- [ ] Flutter app ready for App Store / Google Play submission

---

## ⏱️ ВРЕМЕННАЯ ОЦЕНКА

| Фаза | Задача | Время |
|------|--------|-------|
| 4.1 | Backend IAP webhook + receipt validation | 4 часа |
| 4.2 | Flutter IAP client + integration | 3 часа |
| 4.3 | Subscription UI display | 2 часа |
| 4.4 | Integration testing + deployment | 2 часа |
| **Итого** | **Phase 4** | **~11 часов** |

---

**Готово к началу Phase 4!** 🚀
