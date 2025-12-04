# Phase 4.1 - Backend IAP Webhook Implementation ✅

**Status**: COMPLETED  
**Date**: 2025-12-03  
**Focus**: Backend receipt validation, payment webhook, subscription endpoints

## Summary

Successfully implemented core backend infrastructure for In-App Purchase (IAP) integration:
- ✅ Created `iap_validator.py` - Apple receipt validation + product mapping
- ✅ Updated `payments.py` - Added `/payments/webhook` endpoint
- ✅ Updated `auth.py` - Added `/auth/me/subscription` endpoint  
- ✅ Updated `schemas.py` - Added PaymentWebhookIn schema for webhook payloads

## Files Created/Modified

### 1. ✅ `vpn_api/iap_validator.py` (NEW - 170 lines)

**Location**: `C:\Users\ravin\OneDrive\Рабочий стол\vpn api\vpn_api\iap_validator.py`

**Classes**:

#### IapValidator
Static methods for receipt validation:

```python
@staticmethod
def validate_apple_receipt(receipt: str, bundle_id: str) -> Optional[Dict]:
    """
    Validate Apple IAP receipt via iTunes receipt validation API.
    Returns: {
        'transaction_id': str,
        'product_id': str,
        'purchase_date': datetime,
        'expiry_date': Optional[datetime],
        'is_valid': bool
    }
    """
```

#### ProductIdToTariffMapper
Maps product IDs to internal tariff IDs and durations:

```python
MAPPING = {
    "com.example.vpn.monthly": 1,    # 30 days
    "com.example.vpn.annual": 2,     # 365 days
    "com.example.vpn.lifetime": 3,   # Lifetime
}
```

**Key Methods**:
- `validate_apple_receipt()` - Apple receipt validation
- `validate_google_receipt()` - Google Play placeholder (ready for implementation)
- `get_tariff_id(product_id)` - Product → Tariff mapping
- `get_duration_days(tariff_id)` - Returns subscription duration

---

### 2. ✅ `vpn_api/payments.py` (UPDATED)

**New Endpoint**: `POST /payments/webhook`

**Purpose**: Handle IAP webhook from Apple or Google Play

**Flow**:
1. Accept receipt from mobile client
2. Validate receipt via `IapValidator.validate_apple_receipt()` or `.validate_google_receipt()`
3. Extract transaction_id, product_id, purchase_date, expiry_date
4. Check for duplicate payment (by provider_payment_id)
5. Map product_id → tariff_id via `ProductIdToTariffMapper`
6. Create `Payment` record with status="completed"
7. Create `UserTariff` with calculated end_date
8. Schedule background task to mark expired subscriptions

**Request Body** (via `PaymentWebhookIn`):
```json
{
  "user_id": 1,
  "provider": "apple",
  "receipt": "base64_encoded_receipt_data",
  "bundle_id": "com.example.vpn",
  "currency": "USD"
}
```

**Response**:
```json
{
  "msg": "Payment processed successfully",
  "payment_id": 42,
  "user_tariff_id": 99,
  "tariff_id": 2
}
```

**Error Cases**:
- 400: Missing receipt or user_id
- 404: User not found or unknown tariff
- 400: Invalid receipt (fails validation)
- 200: Payment already processed (idempotent)

**Added Import**:
```python
from vpn_api.iap_validator import IapValidator, ProductIdToTariffMapper
from datetime import UTC, datetime, timedelta
from fastapi import BackgroundTasks
```

**Added Function**: `mark_expired_subscriptions(db)`
- Background task to mark expired UserTariff records as "expired"
- Queries for records where ended_at <= now and status == "active"
- Updates status to "expired"

---

### 3. ✅ `vpn_api/auth.py` (UPDATED)

**New Endpoint**: `GET /auth/me/subscription`

**Purpose**: Retrieve current active subscription for authenticated user

**Response**:
```json
{
  "user_id": 1,
  "tariff_id": 2,
  "tariff_name": "Annual",
  "tariff_duration_days": 365,
  "tariff_price": "99.99",
  "started_at": "2025-12-03T12:00:00Z",
  "ended_at": "2026-12-03T12:00:00Z",
  "days_remaining": 365,
  "is_lifetime": false
}
```

**Returns null** if no active subscription

**Logic**:
1. Query for active UserTariff (where status="active")
2. Join with Tariff to get subscription details
3. Calculate days_remaining from (ended_at - now)
4. Return tariff info + subscription status

---

### 4. ✅ `vpn_api/schemas.py` (UPDATED)

**New Schema**: `PaymentWebhookIn`

```python
class PaymentWebhookIn(BaseModel):
    """IAP webhook payload from Apple IAP or Google Play"""
    user_id: int
    provider: str  # "apple" or "google"
    receipt: str  # Base64-encoded receipt or token
    product_id: Optional[str] = None  # Google Play product ID
    bundle_id: Optional[str] = None  # App bundle ID for validation
    currency: Optional[str] = "USD"
```

---

## Testing Phase 4.1

### Manual Testing

#### 1. Test Webhook with Mock Apple Receipt
```bash
curl -X POST http://127.0.0.1:8000/payments/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "provider": "apple",
    "receipt": "valid_base64_apple_receipt_here",
    "bundle_id": "com.example.vpn",
    "currency": "USD"
  }'
```

#### 2. Test Subscription Endpoint (Authenticated)
```bash
# With valid JWT token
curl -X GET http://127.0.0.1:8000/auth/me/subscription \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..."
```

#### 3. Verify Payment Record Created
```bash
curl -X GET http://127.0.0.1:8000/payments/?user_id=1 \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..."
```

### Unit Tests to Add

**File**: `test/test_payments_webhook.py`

```python
import pytest
from unittest.mock import patch
from vpn_api import models, schemas
from vpn_api.iap_validator import IapValidator

@patch('vpn_api.payments.IapValidator.validate_apple_receipt')
def test_webhook_valid_apple_receipt(mock_validate, client, db):
    """Test successful Apple receipt validation and payment creation"""
    mock_validate.return_value = {
        'transaction_id': 'trans_123',
        'product_id': 'com.example.vpn.annual',
        'purchase_date': datetime.now(UTC),
        'expiry_date': datetime.now(UTC) + timedelta(days=365),
    }
    
    response = client.post('/payments/webhook', json={
        'user_id': 1,
        'provider': 'apple',
        'receipt': 'test_receipt',
        'bundle_id': 'com.example.vpn',
    })
    
    assert response.status_code == 200
    assert response.json()['payment_id']
    
    # Verify Payment created
    payment = db.query(models.Payment).filter_by(provider_payment_id='trans_123').first()
    assert payment.status == models.PaymentStatus.completed
    
    # Verify UserTariff created
    user_tariff = db.query(models.UserTariff).filter_by(user_id=1, tariff_id=2).first()
    assert user_tariff is not None
```

---

## Integration with Production

### Deployment Steps

1. **Commit changes to backend repo**:
```bash
cd "C:\Users\ravin\OneDrive\Рабочий стол\vpn api"
git add vpn_api/iap_validator.py vpn_api/payments.py vpn_api/auth.py vpn_api/schemas.py
git commit -m "Phase 4.1: Add IAP webhook and subscription endpoints"
git push origin main
```

2. **Deploy to production server** (146.103.99.70):
```bash
ssh root@146.103.99.70 "cd /srv/vpn-api && git pull origin main && docker-compose restart api"
```

3. **Verify endpoints are accessible**:
```bash
ssh root@146.103.99.70 "curl -s http://127.0.0.1:8000/docs | grep -i payment"
```

---

## Environment Variables Required

Add to `.env` file on production:

```env
# Apple IAP
APPLE_RECEIPT_URL=https://buy.itunes.apple.com/verifyReceipt  # or sandbox
APPLE_APP_SECRET=your_app_secret_from_app_store_connect

# Google Play (for Phase 4.2)
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=/path/to/service_account.json
```

---

## Progress Tracking

| Phase | Task | Status |
|-------|------|--------|
| 4.1.1 | iap_validator.py | ✅ DONE |
| 4.1.2 | payments.py webhook | ✅ DONE |
| 4.1.3 | schemas.py updates | ✅ DONE |
| 4.1.4 | auth.py subscription | ✅ DONE |
| 4.1.5 | Testing & validation | ⏳ NEXT |
| 4.2 | Flutter IAP client | ⏳ TODO |
| 4.3 | Subscription UI widget | ⏳ TODO |
| 4.4 | E2E testing & deploy | ⏳ TODO |

---

## Next Steps (Phase 4.2)

### Flutter In-App Purchase Implementation

**Tasks**:
1. Add `in_app_purchase` package to pubspec.yaml
2. Create `IapManager` service for iOS/Android
3. Implement receipt transmission to backend webhook
4. Handle receipt validation errors and retries
5. Update UI to show subscription status

**Start**: Phase 4.2 - Flutter IAP Client Integration

---

## Files Modified Summary

```
✅ C:\Users\ravin\OneDrive\Рабочий стол\vpn api\vpn_api\iap_validator.py (NEW, 170 lines)
✅ C:\Users\ravin\OneDrive\Рабочий стол\vpn api\vpn_api\payments.py (+100 lines)
✅ C:\Users\ravin\OneDrive\Рабочий стол\vpn api\vpn_api\auth.py (+45 lines)
✅ C:\Users\ravin\OneDrive\Рабочий стол\vpn api\vpn_api\schemas.py (+10 lines)
```

Total backend changes: 325 lines of production code

---

## Critical Notes

⚠️ **Before Production Deployment**:

1. **Apple App Secret**: Required in `.env` - obtain from App Store Connect
2. **Test with Sandbox**: Use sandbox URLs for initial testing
3. **Receipt Validation**: Implement request timeout in IapValidator (currently no timeout)
4. **Error Logging**: Add logging for failed receipt validation attempts
5. **Idempotency**: Webhook is idempotent - safe to retry with same transaction_id

✅ **Security Checks Implemented**:
- User ownership validation on subscription endpoint
- Transaction ID uniqueness enforced (no duplicate billing)
- Receipt validation via Apple official API
- Background task for subscription lifecycle management

---

Generated: 2025-12-03  
Session: Phase 4.1 Backend Implementation
