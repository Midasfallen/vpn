from typing import List, Optional
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session

from vpn_api import models, schemas
from vpn_api.auth import get_current_user
from vpn_api.database import get_db
from vpn_api.iap_validator import IapValidator, ProductIdToTariffMapper

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("/", response_model=schemas.PaymentOut)
def create_payment(
    payload: schemas.PaymentCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Only admin or owner can create payment
    if (
        payload.user_id
        and not getattr(current_user, "is_admin", False)
        and current_user.id != payload.user_id
    ):
        raise HTTPException(status_code=403, detail="Not allowed")
    payment = models.Payment(
        user_id=payload.user_id,
        amount=payload.amount,
        currency=payload.currency,
        provider=payload.provider,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return payment


@router.get("/", response_model=List[schemas.PaymentOut])
def list_payments(
    user_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    q = db.query(models.Payment)
    if user_id:
        if not getattr(current_user, "is_admin", False) and current_user.id != user_id:
            raise HTTPException(status_code=403, detail="Not allowed")
        q = q.filter(models.Payment.user_id == user_id)
    elif not getattr(current_user, "is_admin", False):
        q = q.filter(models.Payment.user_id == current_user.id)
    return q.offset(skip).limit(limit).all()


@router.get("/{payment_id}", response_model=schemas.PaymentOut)
def get_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    payment = db.query(models.Payment).filter(models.Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if not getattr(current_user, "is_admin", False) and payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")
    return payment


@router.put("/{payment_id}", response_model=schemas.PaymentOut)
def update_payment(
    payment_id: int,
    payload: schemas.PaymentCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    payment = db.query(models.Payment).filter(models.Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if not getattr(current_user, "is_admin", False) and payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")
    payment.amount = payload.amount
    payment.currency = payload.currency
    payment.provider = payload.provider
    db.commit()
    db.refresh(payment)
    return payment


@router.delete("/{payment_id}")
def delete_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    payment = db.query(models.Payment).filter(models.Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if not getattr(current_user, "is_admin", False) and payment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")
    db.delete(payment)
    db.commit()
    return {"msg": "deleted"}


@router.post("/webhook")
def webhook_payment(
    payload: schemas.PaymentWebhookIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    Handle IAP webhook from Apple or Google Play.
    
    Accepts receipt data, validates it via IapValidator, and automatically
    creates/updates Payment and UserTariff records on success.
    
    Flow:
    1. Validate receipt (Apple/Google)
    2. Extract product_id and transaction_id
    3. Find or create Payment record
    4. Map product_id to tariff_id
    5. Create UserTariff with appropriate duration
    6. Schedule cleanup of expired subscriptions
    """
    if not payload.receipt:
        raise HTTPException(status_code=400, detail="Receipt is required")
    
    if not payload.user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    # Validate user exists
    db_user = db.query(models.User).filter(models.User.id == payload.user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Validate receipt based on provider
    receipt_data = None
    if payload.provider == "apple":
        receipt_data = IapValidator.validate_apple_receipt(
            receipt=payload.receipt,
            bundle_id=payload.bundle_id or "com.example.vpn"
        )
    elif payload.provider == "google":
        receipt_data = IapValidator.validate_google_receipt(
            package_name=payload.bundle_id or "com.example.vpn",
            product_id=payload.product_id or "",
            token=payload.receipt
        )
    else:
        raise HTTPException(status_code=400, detail=f"Unknown provider: {payload.provider}")
    
    if not receipt_data:
        raise HTTPException(status_code=400, detail="Invalid receipt")
    
    # Extract data from validated receipt
    transaction_id = receipt_data.get("transaction_id")
    product_id = receipt_data.get("product_id")
    purchase_date = receipt_data.get("purchase_date")
    expiry_date = receipt_data.get("expiry_date")
    
    if not transaction_id or not product_id:
        raise HTTPException(status_code=400, detail="Receipt missing transaction_id or product_id")
    
    # Check if payment already exists
    existing_payment = (
        db.query(models.Payment)
        .filter(models.Payment.provider_payment_id == transaction_id)
        .first()
    )
    
    if existing_payment:
        # Payment already processed
        return {"msg": "Payment already processed", "payment_id": existing_payment.id}
    
    # Get tariff_id from product_id
    tariff_id = ProductIdToTariffMapper.get_tariff_id(product_id)
    if not tariff_id:
        raise HTTPException(status_code=400, detail=f"Unknown product: {product_id}")
    
    # Verify tariff exists
    db_tariff = db.query(models.Tariff).filter(models.Tariff.id == tariff_id).first()
    if not db_tariff:
        raise HTTPException(status_code=404, detail=f"Tariff {tariff_id} not found")
    
    # Create payment record
    payment = models.Payment(
        user_id=payload.user_id,
        amount=db_tariff.price,
        currency=payload.currency or "USD",
        status=models.PaymentStatus.completed,
        provider=payload.provider,
        provider_payment_id=transaction_id,
    )
    db.add(payment)
    db.flush()
    
    # Create UserTariff record with subscription duration
    duration_days = ProductIdToTariffMapper.get_duration_days(tariff_id)
    user_tariff = models.UserTariff(
        user_id=payload.user_id,
        tariff_id=tariff_id,
        started_at=purchase_date or datetime.now(UTC),
        status="active"
    )
    
    # Set end date if not lifetime
    if duration_days and duration_days < 36500:  # Not lifetime (>=100 years)
        user_tariff.ended_at = datetime.now(UTC) + timedelta(days=duration_days)
    
    db.add(user_tariff)
    db.commit()
    db.refresh(payment)
    
    # Schedule cleanup of expired subscriptions
    background_tasks.add_task(mark_expired_subscriptions, db)
    
    return {
        "msg": "Payment processed successfully",
        "payment_id": payment.id,
        "user_tariff_id": user_tariff.id,
        "tariff_id": tariff_id,
    }


def mark_expired_subscriptions(db: Session):
    """
    Mark expired UserTariff records as 'expired'.
    Called as background task after payment processing.
    """
    now = datetime.now(UTC)
    expired = (
        db.query(models.UserTariff)
        .filter(
            models.UserTariff.status == "active",
            models.UserTariff.ended_at <= now
        )
        .all()
    )
    for record in expired:
        record.status = "expired"
    db.commit()
