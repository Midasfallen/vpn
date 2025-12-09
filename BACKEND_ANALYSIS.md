# Backend VPN API — Детальный Анализ

**Дата:** 3 декабря 2025 г.  
**Сервер:** http://146.103.99.70:8000  
**Репозиторий:** https://github.com/Midasfallen/vpn-api

---

## 1. АРХИТЕКТУРА ПРИЛОЖЕНИЯ

### Технологический стек
- **Framework:** FastAPI (Python 3.12)
- **ORM:** SQLAlchemy 2.x
- **Database:** PostgreSQL (production), SQLite (test/local)
- **Authentication:** JWT (HS256, pbkdf2_sha256)
- **WireGuard Integration:** wg-easy API + SSH scripts + Host-based key generation

### Структура приложения

```
vpn_api/
├── main.py                 # FastAPI app entry point
├── database.py             # SQLAlchemy session factory, Base
├── models.py               # ORM models (User, Tariff, VpnPeer, Payment, UserTariff)
├── schemas.py              # Pydantic input/output schemas
├── auth.py                 # Authentication endpoints (register, login, me, promote)
├── tariffs.py              # Tariff CRUD endpoints
├── peers.py                # VPN Peer CRUD endpoints
├── payments.py             # Payment CRUD endpoints
├── wg_easy_adapter.py      # wg-easy HTTP API client (async)
├── wg_host.py              # SSH/local WireGuard key generation and peer management
├── crypto.py               # Encryption/decryption for wg-quick configs
├── requirements.txt        # Python dependencies
└── test.db                 # Test SQLite database
```

### Модели данных (SQLAlchemy ORM)

#### **User**
```python
class User(Base):
    id: int (PK)
    email: str (UNIQUE)
    hashed_password: str (nullable) # pbkdf2_sha256 or bcrypt_sha256
    google_id: str (nullable, UNIQUE) # future OAuth2
    status: UserStatus (enum: pending/active/blocked)
    is_admin: bool
    created_at: datetime
    
    # Verification fields (for email-based signup)
    is_verified: bool
    verification_code: str (nullable)
    verification_expires_at: datetime (nullable)
    
    # Relationships
    tariffs: List[UserTariff]
    vpn_peers: List[VpnPeer]
    payments: List[Payment]
```

#### **Tariff**
```python
class Tariff(Base):
    id: int (PK)
    name: str (UNIQUE)
    description: str (nullable)
    duration_days: int (default: 30)
    price: Decimal(10,2)
    created_at: datetime
    
    # Relationships
    user_tariffs: List[UserTariff]
```

#### **UserTariff** (subscription assignment)
```python
class UserTariff(Base):
    id: int (PK)
    user_id: int (FK → User, cascade delete)
    tariff_id: int (FK → Tariff, restrict delete)
    started_at: datetime
    ended_at: datetime (nullable)
    status: str (default: "active")
    
    # Unique constraint: (user_id, tariff_id, started_at)
    # Relationships
    user: User
    tariff: Tariff
```

#### **VpnPeer**
```python
class VpnPeer(Base):
    id: int (PK)
    user_id: int (FK → User, cascade delete)
    wg_private_key: str # Should be encrypted in production
    wg_public_key: str (UNIQUE)
    wg_client_id: str (nullable) # wg-easy remote client ID (if created via API)
    wg_ip: str (UNIQUE)
    allowed_ips: str (nullable) # e.g., "0.0.0.0/0, ::/0"
    wg_config_encrypted: str (nullable) # Encrypted wg-quick config
    active: bool (default: True)
    created_at: datetime
    
    # Relationships
    user: User
```

#### **Payment**
```python
class Payment(Base):
    id: int (PK)
    user_id: int (FK → User, set null on delete)
    amount: Decimal(10,2)
    currency: str (default: "USD")
    status: PaymentStatus (enum: pending/completed/failed/refunded)
    provider: str (nullable) # e.g., "telegram_bot", "stripe", "apple"
    provider_payment_id: str (nullable, indexed) # External payment reference
    created_at: datetime
    
    # Relationships
    user: User
```

---

## 2. API ENDPOINTS (ПОЛНЫЙ СПРАВОЧНИК)

### Базовый URL
```
http://146.103.99.70:8000
http://127.0.0.1:8000  # Локально
```

### Swagger UI
```
http://146.103.99.70:8000/docs
```

---

## 2.1. AUTHENTICATION (`/auth`)

### `POST /auth/register`
**Описание:** Регистрация пользователя с email и паролем

**Параметры (JSON Body):**
```json
{
  "email": "user@example.com",
  "password": "password123"  // Мин. 8 символов
}
```

**Ответ (200):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "status": "active",
  "is_admin": false,
  "created_at": "2025-12-03T10:00:00Z"
}
```

**Ошибки:**
- `400`: Email already registered / Password too short / Validation error

---

### `POST /auth/register/email`
**Описание:** Регистрация по email (упрощённый flow, без пароля)

**Параметры (JSON Body):**
```json
{
  "email": "user@example.com"
}
```

**Ответ (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

---

### `POST /auth/login`
**Описание:** Логин и получение JWT токена

**Параметры (JSON Body):**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Ответ (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**Заголовок ответа:**
- Нет `refresh_token`; JWT действует `ACCESS_TOKEN_EXPIRE_MINUTES` (default: 60 минут)

**Ошибки:**
- `401`: Invalid credentials

---

### `GET /auth/me`
**Описание:** Получить информацию о текущем пользователе

**Заголовок:**
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ (200):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "status": "active",
  "is_admin": false,
  "created_at": "2025-12-03T10:00:00Z"
}
```

**Ошибки:**
- `401`: Could not validate credentials
- `403`: User not active

---

### `POST /auth/assign_tariff`
**Описание:** Назначить тариф пользователю (ТОЛЬКО АДМИНИСТРАТОР)

**Параметры:**
- Query: `user_id` (int)
- JSON Body:
```json
{
  "tariff_id": 1
}
```

**Ответ (200):**
```json
{
  "msg": "tariff assigned",
  "user_id": 1,
  "tariff_id": 1
}
```

**Ошибки:**
- `403`: Admin privileges required
- `404`: User not found / Tariff not found
- `400`: Tariff already assigned to user

---

### `POST /auth/admin/promote`
**Описание:** Повысить пользователя до администратора

**Параметры:**
- Query: `user_id` (int), `secret` (str, optional)

**Способ 1: Bootstrap (с PROMOTE_SECRET)**
```bash
curl -X POST "http://146.103.99.70:8000/auth/admin/promote?user_id=1&secret=bootstrap-secret"
```

**Способ 2: Администратор (требуется JWT)**
```bash
curl -X POST "http://146.103.99.70:8000/auth/admin/promote?user_id=2" \
  -H "Authorization: Bearer <ADMIN_TOKEN>"
```

**Ответ (200):**
```json
{
  "msg": "user promoted",
  "user_id": 1
}
```

**Ошибки:**
- `403`: Admin privileges required (если неправильный secret)
- `404`: User not found

---

## 2.2. VPN PEERS (`/vpn_peers`)

### `POST /vpn_peers/self`
**Описание:** Создать WireGuard peer для текущего пользователя

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Параметры (JSON Body, опционально):**
```json
{
  "device_name": "my-phone",
  "wg_public_key": null,      // Auto-generated if omitted
  "wg_ip": null,              // Auto-allocated if omitted
  "allowed_ips": null,        // Default: "0.0.0.0/0, ::/0"
  "user_id": null             // Игнорируется, используется текущий пользователь
}
```

**Ответ (200 — ОДИН РАЗ возвращает приватный ключ):**
```json
{
  "id": 6,
  "user_id": 40,
  "wg_public_key": "db:abc123...",
  "wg_private_key": "private-key-content",  // ⚠️ ТОЛЬКО при создании
  "wg_ip": "10.10.75.66/32",
  "allowed_ips": "0.0.0.0/0, ::/0",
  "active": true,
  "created_at": "2025-12-03T12:34:56Z"
}
```

**Важно:**
- Приватный ключ возвращается **ТОЛЬКО** при создании
- При последующих GET запросах `wg_private_key` вернётся как `null` по соображениям безопасности
- Ключи могут генерироваться тремя способами:
  - `db` — ключи в базе данных
  - `host` — ключи на сервере (SSH)
  - `wg-easy` — ключи через wg-easy API

**Ошибки:**
- `401`: Unauthorized
- `403`: User not active
- `502`: Failed to create remote wg-easy client

---

### `GET /vpn_peers/self/config`
**Описание:** Получить wg-quick конфигурацию (расшифрованную) для активного peer

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Ответ (200):**
```json
{
  "wg_quick": "[Interface]\nPrivateKey = ...\nAddress = 10.10.75.66/32\n\n[Peer]\nPublicKey = ...\nAllowedIPs = 0.0.0.0/0\n"
}
```

**Ошибки:**
- `404`: No peer found / No stored config
- `500`: Failed to decrypt stored config

---

### `GET /vpn_peers/`
**Описание:** Список всех peers пользователя (admin может фильтровать по user_id)

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Query параметры:**
- `user_id` (int, optional) — фильтр по пользователю (только для admin)
- `skip` (int, default: 0)
- `limit` (int, default: 100, max: 100)

**Пример запроса:**
```bash
curl "http://146.103.99.70:8000/vpn_peers/?skip=0&limit=50" \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

**Ответ (200):**
```json
[
  {
    "id": 6,
    "user_id": 40,
    "wg_public_key": "...",
    "wg_private_key": null,  // Никогда не возвращается в GET
    "wg_ip": "10.10.75.66/32",
    "allowed_ips": "0.0.0.0/0, ::/0",
    "active": true,
    "created_at": "2025-12-03T12:34:56Z"
  }
]
```

---

### `GET /vpn_peers/{peer_id}`
**Описание:** Получить информацию о конкретном peer

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>` (own peer или admin)

**Ответ (200):**
```json
{
  "id": 6,
  "user_id": 40,
  "wg_public_key": "...",
  "wg_private_key": null,
  "wg_ip": "10.10.75.66/32",
  "allowed_ips": "0.0.0.0/0, ::/0",
  "active": true,
  "created_at": "2025-12-03T12:34:56Z"
}
```

**Ошибки:**
- `404`: Peer not found
- `403`: Not allowed

---

### `PUT /vpn_peers/{peer_id}`
**Описание:** Обновить информацию о peer (public key, IP, allowed IPs)

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>` (own peer или admin)

**Параметры (JSON Body):**
```json
{
  "wg_public_key": "new-public-key",
  "wg_ip": "10.10.75.67/32",
  "allowed_ips": "192.168.1.0/24"
}
```

**Ответ (200):**
```json
{
  "id": 6,
  "user_id": 40,
  "wg_public_key": "new-public-key",
  "wg_ip": "10.10.75.67/32",
  "allowed_ips": "192.168.1.0/24",
  "active": true,
  "created_at": "2025-12-03T12:34:56Z"
}
```

---

### `DELETE /vpn_peers/{peer_id}`
**Описание:** Удалить peer (удаляет из БД и пытается удалить из wg-easy/wg)

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>` (own peer или admin)

**Ответ (200):**
```json
{
  "msg": "deleted"
}
```

**Ошибки:**
- `404`: Peer not found
- `403`: Not allowed

---

## 2.3. TARIFFS (`/tariffs`)

### `POST /tariffs/`
**Описание:** Создать новый тариф (ТОЛЬКО АДМИНИСТРАТОР)

**Требует:** `Authorization: Bearer <ADMIN_TOKEN>`

**Параметры (JSON Body):**
```json
{
  "name": "Pro Plan",
  "description": "Unlimited bandwidth, 5 peers",
  "duration_days": 30,
  "price": "9.99"
}
```

**Ответ (200):**
```json
{
  "id": 1,
  "name": "Pro Plan",
  "description": "Unlimited bandwidth, 5 peers",
  "duration_days": 30,
  "price": "9.99",
  "created_at": "2025-12-03T10:00:00Z"
}
```

**Ошибки:**
- `400`: Tariff already exists
- `403`: Admin privileges required (если попытается обычный пользователь)

---

### `GET /tariffs/`
**Описание:** Список всех доступных тарифов (публичный)

**Query параметры:**
- `skip` (int, default: 0)
- `limit` (int, default: 10, max: 100)

**Ответ (200):**
```json
[
  {
    "id": 1,
    "name": "Pro Plan",
    "description": "Unlimited bandwidth, 5 peers",
    "duration_days": 30,
    "price": "9.99",
    "created_at": "2025-12-03T10:00:00Z"
  }
]
```

---

### `DELETE /tariffs/{tariff_id}`
**Описание:** Удалить тариф (если не назначен ни одному пользователю)

**Требует:** `Authorization: Bearer <ADMIN_TOKEN>`

**Ответ (200):**
```json
{
  "msg": "tariff deleted",
  "tariff_id": 1
}
```

**Ошибки:**
- `404`: Tariff not found
- `400`: Tariff is assigned to users and cannot be deleted

---

## 2.4. PAYMENTS (`/payments`)

### `POST /payments/`
**Описание:** Создать запись платежа

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Параметры (JSON Body):**
```json
{
  "user_id": 1,           // Опционально; если опущен = текущий пользователь
  "amount": "9.99",
  "currency": "USD",
  "provider": "apple",    // Например: "apple", "google", "stripe", "telegram"
  "provider_payment_id": null  // Опционально
}
```

**Ответ (200):**
```json
{
  "id": 1,
  "user_id": 1,
  "amount": "9.99",
  "currency": "USD",
  "status": "pending",
  "provider": "apple",
  "provider_payment_id": null,
  "created_at": "2025-12-03T12:00:00Z"
}
```

**Ошибки:**
- `403`: Not allowed (если пытается создать платёж для другого пользователя без прав)

---

### `GET /payments/`
**Описание:** Список платежей текущего пользователя (admin может фильтровать)

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Query параметры:**
- `user_id` (int, optional) — фильтр по пользователю (только для admin)
- `skip` (int, default: 0)
- `limit` (int, default: 100)

**Ответ (200):**
```json
[
  {
    "id": 1,
    "user_id": 1,
    "amount": "9.99",
    "currency": "USD",
    "status": "pending",
    "provider": "apple",
    "provider_payment_id": null,
    "created_at": "2025-12-03T12:00:00Z"
  }
]
```

---

### `GET /payments/{payment_id}`
**Описание:** Получить информацию о конкретном платеже

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Ответ (200):**
```json
{
  "id": 1,
  "user_id": 1,
  "amount": "9.99",
  "currency": "USD",
  "status": "pending",
  "provider": "apple",
  "provider_payment_id": null,
  "created_at": "2025-12-03T12:00:00Z"
}
```

**Ошибки:**
- `404`: Payment not found
- `403`: Not allowed

---

### `PUT /payments/{payment_id}`
**Описание:** Обновить платёж (обычно используется webhook'ом)

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Параметры (JSON Body):**
```json
{
  "amount": "9.99",
  "currency": "USD",
  "provider": "apple",
  "provider_payment_id": "com.apple.receipt.xxx"
}
```

**Ответ (200):** Обновлённая запись Payment

---

### `DELETE /payments/{payment_id}`
**Описание:** Удалить платёж

**Требует:** `Authorization: Bearer <ACCESS_TOKEN>`

**Ответ (200):**
```json
{
  "msg": "deleted"
}
```

---

### `POST /payments/webhook` ⚠️ (НЕ РЕАЛИЗОВАН)
**Описание:** Получить webhook от платёжного провайдера (Apple IAP, Google Play и т.д.)

**Планируемая логика:**
1. Провайдер отправляет webhook с `provider_payment_id` и `status` (completed/failed)
2. Backend находит Payment по `provider_payment_id`
3. Обновляет `status` на `completed` или `failed`
4. Если `completed` — создаёт/активирует UserTariff
5. Возвращает 200 OK для подтверждения приёма

**⚠️ Требуется реализация для полной IAP интеграции**

---

## 3. ВАЖНЫЕ ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ

```bash
# Database
DATABASE_URL=postgresql://vpnuser:password@127.0.0.1:5432/vpndb

# JWT
SECRET_KEY=your-very-long-random-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
PROMOTE_SECRET=bootstrap-secret  # Для первоначальной promoción администратора

# WireGuard
WG_KEY_POLICY=wg-easy            # Опции: db, host, wg-easy
WG_EASY_URL=http://62.84.98.109:8588
WG_EASY_PASSWORD=supersecret      # raw password для wg-easy API

# SSH для host-based key generation
WG_APPLY_ENABLED=0                # 1 = apply peers automatically (be careful!)
WG_HOST_SSH=root@62.84.98.109
WG_INTERFACE=wg0
WG_APPLY_SCRIPT=/srv/vpn-api/scripts/wg_apply.sh
WG_REMOVE_SCRIPT=/srv/vpn-api/scripts/wg_remove.sh
WG_GEN_SCRIPT=/srv/vpn-api/scripts/wg_gen_key.sh

# Config encryption (for wg-quick storage)
CONFIG_ENCRYPTION_KEY=your-encryption-key-32-bytes

# Development
DEV_INIT_DB=1  # Create tables on startup (for local dev only)
```

---

## 4. ИНТЕГРАЦИЯ С FLUTTER МОБИЛЬНЫМ КЛИЕНТОМ

### Требуемые endpoints для Flutter app

#### 1. **Аутентификация**
```dart
// Регистрация
POST /auth/register
Body: {"email": "...", "password": "..."}
Response: User object with id

// Логин
POST /auth/login
Body: {"email": "...", "password": "..."}
Response: {"access_token": "...", "token_type": "bearer"}

// Получить текущего пользователя
GET /auth/me
Headers: {"Authorization": "Bearer <token>"}
Response: User object
```

#### 2. **VPN Peers**
```dart
// Создать peer
POST /vpn_peers/self
Headers: {"Authorization": "Bearer <token>"}
Body: {"device_name": "iPhone"}
Response: VpnPeer (с wg_private_key в первый раз)

// Получить список peers
GET /vpn_peers/?skip=0&limit=50
Headers: {"Authorization": "Bearer <token>"}
Response: List<VpnPeer>

// Получить конфигурацию wg-quick
GET /vpn_peers/self/config
Headers: {"Authorization": "Bearer <token>"}
Response: {"wg_quick": "...wg-quick config text..."}
```

#### 3. **Subscription/Tariffs**
```dart
// Получить доступные тарифы
GET /tariffs/?skip=0&limit=10
Response: List<Tariff>

// Ассигнировать тариф (требуется admin)
POST /auth/assign_tariff?user_id=1
Body: {"tariff_id": 1}
Response: {"msg": "tariff assigned", ...}
```

#### 4. **Payments (для In-App Purchase)**
```dart
// Создать запись платежа
POST /payments/
Headers: {"Authorization": "Bearer <token>"}
Body: {
  "user_id": 1,
  "amount": "9.99",
  "currency": "USD",
  "provider": "apple",
  "provider_payment_id": "com.apple.receipt.xxx"
}
Response: Payment object

// Получить статус платежа
GET /payments/{payment_id}
Headers: {"Authorization": "Bearer <token>"}
Response: Payment object with status

// Список платежей
GET /payments/?skip=0&limit=50
Headers: {"Authorization": "Bearer <token>"}
Response: List<Payment>
```

### Пример Flutter flow

```dart
// 1. Login
final loginResponse = await apiClient.post('/auth/login', 
  body: {'email': 'user@example.com', 'password': 'pass123'}
);
final token = loginResponse['access_token'];

// 2. Create VPN peer
final peerResponse = await apiClient.post('/vpn_peers/self',
  headers: {'Authorization': 'Bearer $token'},
  body: {'device_name': 'My Phone'}
);
final wgPrivateKey = peerResponse['wg_private_key'];
final wgIp = peerResponse['wg_ip'];

// 3. Get WireGuard config
final configResponse = await apiClient.get('/vpn_peers/self/config',
  headers: {'Authorization': 'Bearer $token'}
);
final wgQuickConfig = configResponse['wg_quick'];

// 4. Import config to WireGuard (platform channel)
await platformChannel.invokeMethod('importWgConfig', {
  'config': wgQuickConfig
});
```

---

## 5. IN-APP PURCHASE (IAP) ИНТЕГРАЦИЯ

### Текущее состояние
- ✅ Backend поддерживает Payment CRUD операции
- ✅ Поля для `provider` и `provider_payment_id`
- ❌ Webhook для приёма платежей от Apple IAP / Google Play **НЕ реализован**
- ❌ Автоматическое создание/активирование UserTariff при успешном платеже **НЕ реализовано**

### Требуемая реализация для IAP

#### Шаг 1: Создать endpoint для webhook
```python
@router.post("/webhook")
async def payment_webhook(payload: dict, request: Request):
    """
    Получает webhook от Apple IAP или Google Play.
    
    Apple IAP webhook структура:
    {
        "transactionId": "...",
        "bundleId": "com.example.vpn",
        "productId": "com.example.vpn.pro",
        "original_transaction_id": "...",
        "status": "completed" | "failed" | "refunded"
    }
    
    Google Play webhook структура:
    {
        "packageName": "com.example.vpn",
        "subscriptionId": "com.example.vpn.pro",
        "orderId": "...",
        "purchaseToken": "...",
        "status": "completed" | "expired"
    }
    """
    # 1. Валидировать подпись webhook'а
    # 2. Найти Payment по provider_payment_id
    # 3. Обновить status Payment
    # 4. Если completed — создать UserTariff для пользователя
    # 5. Вернуть 200 OK
```

#### Шаг 2: Маппинг product_id → tariff_id
```python
PRODUCT_ID_TO_TARIFF = {
    "com.example.vpn.monthly": 1,      # Monthly Pro Plan
    "com.example.vpn.annual": 2,       # Annual Pro Plan
    "com.example.vpn.lifetime": 3,     # Lifetime Plan
}
```

#### Шаг 3: Создание UserTariff при успехе
```python
def activate_subscription(user_id: int, tariff_id: int, db: Session):
    user_tariff = models.UserTariff(
        user_id=user_id,
        tariff_id=tariff_id,
        started_at=datetime.now(UTC),
        ended_at=None if is_subscription else datetime.now(UTC) + timedelta(days=365),
        status="active"
    )
    db.add(user_tariff)
    db.commit()
```

#### Шаг 4: Flutter client sends receipt
```dart
// After successful purchase via platform channel
final receipt = await platformChannel.invokeMethod('getAppleReceipt');

// Send to backend for verification
final paymentResponse = await apiClient.post('/payments/',
  headers: {'Authorization': 'Bearer $token'},
  body: {
    'user_id': currentUser.id,
    'amount': tariff.price,
    'currency': 'USD',
    'provider': 'apple',  // or 'google'
    'provider_payment_id': receipt.transactionId
  }
);
```

---

## 6. БЕЗОПАСНОСТЬ И ЗАМЕЧАНИЯ

### 🔒 Критические проблемы в production

1. **Private key в БД (не шифрован)**
   - Рекомендуется: Зашифровать `wg_private_key` в БД или хранить только на сервере
   - Текущий статус: `wg_config_encrypted` уже реализован для wg-quick configs

2. **Webhook validation**
   - Требуется: Валидация подписи от Apple/Google для payment webhooks
   - Текущий статус: Не реализовано

3. **Rate limiting**
   - Требуется: Добавить rate limiting на API endpoints
   - Текущий статус: Не реализовано

4. **HTTPS обязателен**
   - JWT токены передаются в заголовке — требуется HTTPS
   - Используйте nginx + Letsencrypt

5. **Email verification**
   - Текущий статус: Структура есть, но отключено
   - Рекомендуется: Включить для production

### 📝 Рекомендуемые улучшения

1. **Async calls в wg-easy adapter**
   - Текущий: Использует `asyncio.run()` в синхронном коде
   - Рекомендуется: Переделать endpoints на async

2. **Integration tests с реальным wg-easy**
   - Текущий: Только unit тесты
   - Рекомендуется: Smoke tests в CI на staging

3. **Мониторинг и логирование**
   - Требуется: Sentry integration для error tracking
   - Требуется: Структурированное логирование (JSON)

---

## 7. ИНСТРУКЦИИ ДЛЯ DEPLOYMENT

### На App host (146.103.99.70)

```bash
# 1. Клонировать репозиторий
cd /srv
git clone https://github.com/Midasfallen/vpn-api.git
cd vpn-api

# 2. Установить зависимости
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r vpn_api/requirements.txt

# 3. Настроить .env.production
cat > .env.production <<'EOF'
DATABASE_URL=postgresql://vpnuser:password@127.0.0.1:5432/vpndb
SECRET_KEY=your-very-long-secret
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
PROMOTE_SECRET=bootstrap-secret
WG_KEY_POLICY=wg-easy
WG_EASY_URL=http://62.84.98.109:8588
WG_EASY_PASSWORD=supersecret
WG_HOST_SSH=root@62.84.98.109
WG_INTERFACE=wg0
WG_APPLY_ENABLED=0
EOF

# 4. Запустить миграции
DATABASE_URL=postgresql://... alembic upgrade head

# 5. Запустить сервис (uvicorn)
python -m uvicorn vpn_api.main:app --host 0.0.0.0 --port 8000
```

### Через Docker Compose

```yaml
version: '3.9'
services:
  web:
    build: .
    command: uvicorn vpn_api.main:app --host 0.0.0.0 --port 8000
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://vpnuser:password@db:5432/vpndb
      SECRET_KEY: your-secret-key
      # ... остальные переменные
    depends_on:
      - db
  
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: vpnuser
      POSTGRES_PASSWORD: password
      POSTGRES_DB: vpndb
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

---

## 8. ПРИМЕРЫ CURL ЗАПРОСОВ

```bash
# 1. Регистрация
curl -X POST http://146.103.99.70:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 2. Логин
curl -X POST http://146.103.99.70:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 3. Получить текущего пользователя
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
curl http://146.103.99.70:8000/auth/me \
  -H "Authorization: Bearer $TOKEN"

# 4. Создать peer
curl -X POST http://146.103.99.70:8000/vpn_peers/self \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"device_name":"my-phone"}'

# 5. Получить список тарифов
curl http://146.103.99.70:8000/tariffs/

# 6. Создать платёж
curl -X POST http://146.103.99.70:8000/payments/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "amount": "9.99",
    "currency": "USD",
    "provider": "apple",
    "provider_payment_id": "com.apple.receipt.xxx"
  }'
```

---

## 📋 РЕЗЮМЕ ДЛЯ FLUTTER РАЗРАБОТЧИКА

**Что нужно знать:**

1. **Все запросы требуют `Authorization: Bearer <token>`** (кроме `/auth/register`, `/auth/login`, `/tariffs/`)

2. **Private key возвращается только при создании peer** — сохраните его сразу!

3. **Для IAP интеграции:**
   - Создайте Payment запись с `provider="apple"` и `provider_payment_id`
   - Webhook автоматически активирует подписку (когда реализован)

4. **Error responses:**
   - 401: Токен истёк или невалиден → требуется перелогин
   - 403: Нет прав на ресурс
   - 422: Validation error → проверьте JSON
   - 502: Ошибка wg-easy интеграции

5. **Тестирование локально:**
   ```bash
   python -m uvicorn vpn_api.main:app --reload
   # Откройте http://127.0.0.1:8000/docs для Swagger
   ```

---

**Дата обновления:** 3 декабря 2025 г.
