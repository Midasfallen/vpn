# VPN Backend API — Полный Технический Обзор

**Дата**: 3 декабря 2025  
**Версия проекта**: 0.1.0  
**Основной язык**: Python 3.12  
**Фреймворк**: FastAPI + SQLAlchemy  
**СУБД**: PostgreSQL (production), SQLite (dev/test)

---

## Содержание

1. [Архитектура приложения](#архитектура-приложения)
2. [Структура проекта](#структура-проекта)
3. [Модели данных](#модели-данных)
4. [API Endpoints](#api-endpoints)
5. [Ключевые особенности](#ключевые-особенности)
6. [Безопасность](#безопасность)
7. [Интеграция с Flutter](#интеграция-с-flutter)
8. [IAP интеграция](#iap-интеграция)
9. [Развёртывание](#развёртывание)

---

## 1. Архитектура приложения

### 1.1 Общая структура

```
┌─────────────────────────────────────────────────────────────┐
│                      FastAPI (main.py)                      │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    ┌───▼───┐          ┌──────▼──────┐      ┌──────▼──────┐
    │ Auth  │          │  VPN Peers  │      │  Tariffs /  │
    │Router │          │   Router    │      │  Payments   │
    └───┬───┘          └──────┬──────┘      └──────┬──────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                  ┌───────────▼────────────┐
                  │   SQLAlchemy ORM       │
                  │  (models.py)           │
                  └───────────┬────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
        ┌───▼──┐      ┌───────▼────────┐  ┌────▼────┐
        │ User │      │   WG/VPN       │  │ Payment │
        │ Model│      │   Models       │  │ Models  │
        └──────┘      └────────────────┘  └─────────┘
                              │
    ┌─────────────────────────┼─────────────────────┐
    │                         │                     │
┌───▼────────┐      ┌─────────▼───────┐    ┌───────▼───┐
│  wg-easy   │      │   WG Host       │    │ Crypto    │
│  Adapter   │      │   Management    │    │ (Fernet)  │
└────────────┘      │   (SSH/HTTP)    │    └───────────┘
                    └─────────────────┘
```

### 1.2 Слои архитектуры

**Presentation Layer (API Routes)**:
- `vpn_api/auth.py` — аутентификация и управление пользователями
- `vpn_api/peers.py` — CRUD операции с VPN пирами
- `vpn_api/tariffs.py` — управление тарифами
- `vpn_api/payments.py` — платежи и webhooks

**Business Logic Layer**:
- `vpn_api/wg_easy_adapter.py` — интеграция с wg-easy API
- `vpn_api/wg_host.py` — управление WireGuard через SSH/скрипты
- `vpn_api/crypto.py` — шифрование конфигураций

**Data Layer**:
- `vpn_api/models.py` — SQLAlchemy ORM модели
- `vpn_api/schemas.py` — Pydantic валидация
- `vpn_api/database.py` — подключение к БД

---

## 2. Структура проекта

```
vpn-api/
├── vpn_api/                          # Основной пакет приложения
│   ├── __init__.py
│   ├── main.py                       # Точка входа (FastAPI app)
│   ├── database.py                   # SQLAlchemy setup
│   ├── models.py                     # ORM модели (User, VpnPeer, Tariff, Payment, etc.)
│   ├── schemas.py                    # Pydantic валидация
│   ├── auth.py                       # Аутентификация, JWT, promote
│   ├── peers.py                      # VPN Peers CRUD
│   ├── tariffs.py                    # Tariffs CRUD
│   ├── payments.py                   # Payments CRUD + webhook
│   ├── wg_easy_adapter.py            # Async адаптер для wg-easy API
│   ├── wg_host.py                    # SSH управление WireGuard
│   ├── crypto.py                     # Fernet шифрование
│   ├── requirements.txt              # Python зависимости
│   ├── requirements-dev.txt          # Dev зависимости
│   └── test.db                       # SQLite БД для тестов
├── alembic/                          # Миграции БД
│   ├── env.py                        # Конфигурация Alembic
│   ├── script.py.mako                # Шаблон миграции
│   └── versions/                     # История миграций
├── tests/                            # Тесты pytest
│   ├── conftest.py                   # Конфигурация тестов
│   └── test_*.py                     # Тесты API
├── scripts/                          # Скрипты управления WireGuard
│   ├── wg_apply.sh                   # Применение конфигурации
│   ├── wg_remove.sh                  # Удаление пира
│   └── wg_gen_key.sh                 # Генерация ключей
├── .github/workflows/                # GitHub Actions CI
│   ├── ci.yaml                       # Lint, test, coverage
│   └── run_migrations.yml            # Миграции перед деплоем
├── Dockerfile                        # Docker образ Python 3.12
├── docker-compose.yml                # Production compose
├── docker-compose.dev.yml            # Dev compose
├── alembic.ini                       # Конфиг Alembic
├── pyproject.toml                    # Конфиг Black, Ruff, isort
├── README.md                         # Документация
└── .env.example                      # Пример переменных окружения

```

---

## 3. Модели данных

### 3.1 Структура таблиц

#### **User**
```python
class User(Base):
    __tablename__ = "users"
    
    id: int                           # Primary key
    email: str (unique)               # Email пользователя
    hashed_password: str | None       # Пароль (pbkdf2_sha256)
    google_id: str | None             # OAuth2 Google ID (резерв)
    status: UserStatus                # "pending" | "active" | "blocked"
    is_admin: bool                    # Флаг админа
    is_verified: bool                 # Email верификация
    verification_code: str | None     # Код верификации
    verification_expires_at: datetime # Срок кода
    created_at: datetime              # Timestamp создания
    
    # Relationships
    tariffs: [UserTariff]             # Назначенные тарифы
    vpn_peers: [VpnPeer]              # VPN пиры пользователя
    payments: [Payment]               # Платежи пользователя
```

#### **Tariff**
```python
class Tariff(Base):
    __tablename__ = "tariffs"
    
    id: int                           # Primary key
    name: str (unique)                # Название (e.g., "Pro Monthly")
    description: str | None           # Описание
    duration_days: int (default=30)   # Длительность в днях
    price: Decimal(10,2)              # Цена
    created_at: datetime              # Когда создан
    
    # Relationships
    user_tariffs: [UserTariff]        # Назначения пользователям
```

#### **UserTariff** (Junction Table)
```python
class UserTariff(Base):
    __tablename__ = "user_tariffs"
    __table_args__ = (
        UniqueConstraint("user_id", "tariff_id", "started_at"),
    )
    
    id: int                           # Primary key
    user_id: int (FK User.id)         # ID пользователя
    tariff_id: int (FK Tariff.id)     # ID тарифа
    started_at: datetime              # Когда назначен
    ended_at: datetime | None         # Когда истекает
    status: str (default="active")    # "active" | "expired" | "cancelled"
    
    # Relationships
    user: User                        # Назад к пользователю
    tariff: Tariff                    # Назад к тарифу
```

#### **VpnPeer**
```python
class VpnPeer(Base):
    __tablename__ = "vpn_peers"
    
    id: int                           # Primary key
    user_id: int (FK User.id)         # ID владельца
    wg_private_key: str               # Приватный ключ (DB/Host/wg-easy)
    wg_public_key: str (unique)       # Публичный ключ
    wg_client_id: str | None          # ID клиента в wg-easy (если remote)
    wg_ip: str (unique)               # IP адрес пира (10.10.x.y/32)
    allowed_ips: str | None           # AllowedIPs (0.0.0.0/0 по умолчанию)
    wg_config_encrypted: str | None   # Зашифрованная wg-quick конфиг
    active: bool (default=True)       # Активен ли пир
    created_at: datetime              # Когда создан
    
    # Relationships
    user: User                        # Владелец пира
```

#### **Payment**
```python
class Payment(Base):
    __tablename__ = "payments"
    
    id: int                           # Primary key
    user_id: int (FK User.id)         # ID пользователя (может быть NULL)
    amount: Decimal(10,2)             # Сумма платежа
    currency: str (default="USD")     # Валюта (USD, EUR, RUB)
    status: PaymentStatus             # "pending" | "completed" | "failed" | "refunded"
    provider: str | None              # Провайдер (Telegram, Stripe, etc.)
    provider_payment_id: str | None   # ID платежа у провайдера (уникален для идемпотентности)
    created_at: datetime              # Timestamp платежа
    
    # Relationships
    user: User                        # Пользователь
```

### 3.2 Pydantic Schemas

**Входные (Request)**:
- `UserCreate` — email + password для регистрации
- `UserLogin` — email + password для входа
- `RegisterIn` — только email (для email-flow)
- `VpnPeerCreate` — опциональные user_id, wg_public_key, wg_ip, device_name
- `TariffCreate` — name, price, duration_days, description
- `PaymentCreate` — amount, currency, provider, user_id
- `AssignTariff` — tariff_id (для назначения тарифа)

**Выходные (Response)**:
- `UserOut` — id, email, status, is_admin, created_at
- `VpnPeerOut` — id, user_id, wg_public_key, wg_private_key (только на create), wg_ip, allowed_ips, active, created_at
- `TariffOut` — id, name, duration_days, price, description
- `PaymentOut` — id, user_id, amount, currency, status, provider, provider_payment_id, created_at
- `TokenOut` — access_token, token_type

---

## 4. API Endpoints

### 4.1 Authentication (`/auth`)

#### `POST /auth/register`
**Описание**: Регистрация нового пользователя (email + пароль)

**Запрос**:
```json
{
  "email": "alice@example.com",
  "password": "SecurePassword123"
}
```

**Ответ** (200):
```json
{
  "id": 12,
  "email": "alice@example.com",
  "status": "active",
  "is_admin": false,
  "created_at": "2025-09-28T12:00:00Z"
}
```

**Ошибки**:
- `400` — Email уже зарегистрирован, пароль < 8 символов
- `422` — Validation error

**Требования к паролю**:
- Минимум 8 символов
- Хранится как PBKDF2-SHA256 хэш (для совместимости с bcrypt как fallback)

---

#### `POST /auth/login`
**Описание**: Получить JWT access token

**Запрос**:
```json
{
  "email": "alice@example.com",
  "password": "SecurePassword123"
}
```

**Ответ** (200):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**Ошибки**:
- `401` — Invalid credentials

**Token Expiry**: По умолчанию 60 минут (переменная `ACCESS_TOKEN_EXPIRE_MINUTES`)

---

#### `GET /auth/me`
**Описание**: Получить информацию о текущем пользователе

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
{
  "id": 40,
  "email": "alice@example.com",
  "status": "active",
  "is_admin": false,
  "created_at": "2025-09-28T12:00:00Z"
}
```

**Ошибки**:
- `401` — Token invalid/expired
- `403` — User not active (status != "active")

---

#### `POST /auth/admin/promote`
**Описание**: Повысить пользователя до администратора (bootstrap или админ-только)

**Параметры**:
```
user_id: int (query)
secret: str | None (query) — PROMOTE_SECRET для bootstrap
```

**Запрос**:
```
POST /auth/admin/promote?user_id=5&secret=bootstrap-secret
```

**Ответ** (200):
```json
{
  "msg": "user promoted",
  "user_id": 5
}
```

**Логика**:
- Если `secret == PROMOTE_SECRET` (env var) — разрешить без auth
- Иначе требуется текущий пользователь быть админом
- При успехе пользователь становится админом и активным

**Ошибки**:
- `403` — Not admin, invalid secret
- `404` — User not found

---

#### `POST /auth/assign_tariff`
**Описание**: Назначить тариф пользователю (только админ)

**Параметры**:
```
user_id: int (query)
```

**Headers**:
```
Authorization: Bearer <ADMIN_TOKEN>
```

**Запрос**:
```json
{
  "tariff_id": 3
}
```

**Ответ** (200):
```json
{
  "msg": "tariff assigned",
  "user_id": 5,
  "tariff_id": 3
}
```

**Логика**:
- Только админ может вызвать
- Создаёт запись UserTariff с текущей датой
- Активирует пользователя (status = "active")

**Ошибки**:
- `403` — Not admin
- `400` — Tariff already assigned
- `404` — User или Tariff not found

---

### 4.2 VPN Peers (`/vpn_peers`)

#### `POST /vpn_peers/self`
**Описание**: Создать VPN пир для текущего пользователя

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Запрос**:
```json
{
  "device_name": "my-phone",
  "wg_public_key": null,
  "wg_ip": null,
  "allowed_ips": null
}
```

**Ответ** (200):
```json
{
  "id": 6,
  "user_id": 40,
  "wg_public_key": "db:abc123...",
  "wg_private_key": "private-key-base64",
  "wg_ip": "10.10.75.66/32",
  "allowed_ips": null,
  "active": true,
  "created_at": "2025-09-28T12:34:56Z"
}
```

**WG_KEY_POLICY** (environment переменная):
- **"db"** (default) — ключи генерируются локально в коде (детерминированные)
- **"host"** — ключи генерируются на хосте через SSH скрипт `wg_gen_key.sh`
- **"wg-easy"** — ключи генерируются через wg-easy API

**Процесс создания**:
1. Проверить, что пользователь активен (status = "active")
2. Генерировать/получить public и private ключи согласно WG_KEY_POLICY
3. Создать VpnPeer запись в БД
4. Если WG_EASY_URL задан — создать клиента в wg-easy контейнере
5. Если WG_APPLY_ENABLED=1 — применить конфиг на host через SSH
6. Зашифровать wg-quick конфиг и сохранить в БД (если возможно)
7. Вернуть объект с приватным ключом (единственный раз!)

**Ошибки**:
- `403` — User not active
- `502` — Failed to create on wg-easy
- `400` — Validation error

---

#### `GET /vpn_peers/`
**Описание**: Список VPN пиров (пользователя или всех, если админ)

**Параметры**:
```
user_id: int | None (query) — фильтр по пользователю (только админ или свой)
skip: int (default=0)
limit: int (default=100, max=unlimited)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
[
  {
    "id": 6,
    "user_id": 40,
    "wg_public_key": "db:abc123...",
    "wg_private_key": null,
    "wg_ip": "10.10.75.66/32",
    "allowed_ips": null,
    "active": true,
    "created_at": "2025-09-28T12:34:56Z"
  }
]
```

**Логика**:
- Если user_id не указан — вернуть пиры текущего пользователя
- Если user_id указан и пользователь не админ и не владелец — ошибка 403
- Приватный ключ **никогда** не возвращается в GET запросах

---

#### `GET /vpn_peers/{peer_id}`
**Описание**: Получить один пир по ID

**Параметры**:
```
peer_id: int (path)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
{
  "id": 6,
  "user_id": 40,
  "wg_public_key": "db:abc123...",
  "wg_private_key": null,
  "wg_ip": "10.10.75.66/32",
  "allowed_ips": null,
  "active": true,
  "created_at": "2025-09-28T12:34:56Z"
}
```

**Ошибки**:
- `403` — Not allowed (не админ и не владелец)
- `404` — Peer not found

---

#### `GET /vpn_peers/self/config`
**Описание**: Получить расшифрованную wg-quick конфигурацию для текущего пользователя

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
{
  "wg_quick": "[Interface]\nPrivateKey = <key>\nAddress = 10.10.75.66/32\n\n[Peer]\nPublicKey = <key>\nAllowedIPs = 0.0.0.0/0\n"
}
```

**Логика**:
- Найти самый свежий активный пир пользователя
- Вернуть его расшифрованную конфигурацию (если сохранена)
- Конфиг может использоваться для импорта в WireGuard на клиенте

**Ошибки**:
- `404` — No peer found
- `500` — Failed to decrypt config

---

#### `PUT /vpn_peers/{peer_id}`
**Описание**: Обновить пир (например, allowed_ips)

**Параметры**:
```
peer_id: int (path)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Запрос**:
```json
{
  "wg_public_key": "db:abc123...",
  "wg_ip": "10.10.75.66/32",
  "allowed_ips": "0.0.0.0/0,::/0"
}
```

**Ответ** (200):
```json
{
  "id": 6,
  "user_id": 40,
  "wg_public_key": "db:abc123...",
  "wg_private_key": null,
  "wg_ip": "10.10.75.66/32",
  "allowed_ips": "0.0.0.0/0,::/0",
  "active": true,
  "created_at": "2025-09-28T12:34:56Z"
}
```

**Ошибки**:
- `403` — Not allowed
- `404` — Peer not found

---

#### `DELETE /vpn_peers/{peer_id}`
**Описание**: Удалить пир (удалить из БД, из wg-easy и с хоста)

**Параметры**:
```
peer_id: int (path)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
{
  "msg": "deleted"
}
```

**Процесс удаления**:
1. Найти пир в БД
2. Удалить из БД
3. Если был создан в wg-easy (wg_client_id != null) — удалить из wg-easy API
4. Если WG_APPLY_ENABLED=1 — выполнить wg_remove.sh скрипт на хосте
5. Все операции удаления best-effort (не падают, если одна из них не сработает)

**Ошибки**:
- `403` — Not allowed
- `404` — Peer not found

---

### 4.3 Tariffs (`/tariffs`)

#### `POST /tariffs/`
**Описание**: Создать новый тариф (только админ)

**Headers**:
```
Authorization: Bearer <ADMIN_TOKEN>
```

**Запрос**:
```json
{
  "name": "Pro Monthly",
  "description": "Unlimited bandwidth",
  "duration_days": 30,
  "price": 9.99
}
```

**Ответ** (200):
```json
{
  "id": 3,
  "name": "Pro Monthly",
  "description": "Unlimited bandwidth",
  "duration_days": 30,
  "price": 9.99
}
```

**Ошибки**:
- `400` — Tariff already exists
- `422` — Validation error

---

#### `GET /tariffs/`
**Описание**: Список всех тарифов (публичный, не требует auth)

**Параметры**:
```
skip: int (default=0)
limit: int (default=10, max=100)
```

**Ответ** (200):
```json
[
  {
    "id": 1,
    "name": "Free",
    "description": null,
    "duration_days": 30,
    "price": 0.00
  },
  {
    "id": 3,
    "name": "Pro Monthly",
    "description": "Unlimited bandwidth",
    "duration_days": 30,
    "price": 9.99
  }
]
```

---

#### `GET /tariffs/{tariff_id}`
**Описание**: Получить один тариф

**Параметры**:
```
tariff_id: int (path)
```

**Ответ** (200):
```json
{
  "id": 3,
  "name": "Pro Monthly",
  "description": "Unlimited bandwidth",
  "duration_days": 30,
  "price": 9.99
}
```

**Ошибки**:
- `404` — Tariff not found

---

#### `DELETE /tariffs/{tariff_id}`
**Описание**: Удалить тариф (только если не назначен ни одному пользователю)

**Headers**:
```
Authorization: Bearer <ADMIN_TOKEN>
```

**Параметры**:
```
tariff_id: int (path)
```

**Ответ** (200):
```json
{
  "msg": "tariff deleted",
  "tariff_id": 3
}
```

**Ошибки**:
- `400` — Tariff is assigned to users
- `403` — Not admin
- `404` — Tariff not found

---

### 4.4 Payments (`/payments`)

#### `POST /payments/`
**Описание**: Создать новый платёж (очередь для обработки)

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Запрос**:
```json
{
  "user_id": 40,
  "amount": 9.99,
  "currency": "USD",
  "provider": "telegram_bot"
}
```

**Ответ** (200):
```json
{
  "id": 42,
  "user_id": 40,
  "amount": 9.99,
  "currency": "USD",
  "status": "pending",
  "provider": "telegram_bot",
  "provider_payment_id": null,
  "created_at": "2025-09-28T12:34:56Z"
}
```

**Логика**:
- Только админ или владелец пользователя может создать платёж для других
- Статус изначально "pending"

**Ошибки**:
- `403` — Not allowed
- `422` — Validation error

---

#### `GET /payments/`
**Описание**: Список платежей (своих или всех, если админ)

**Параметры**:
```
user_id: int | None (query) — фильтр по пользователю
skip: int (default=0)
limit: int (default=100)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
[
  {
    "id": 42,
    "user_id": 40,
    "amount": 9.99,
    "currency": "USD",
    "status": "pending",
    "provider": "telegram_bot",
    "provider_payment_id": null,
    "created_at": "2025-09-28T12:34:56Z"
  }
]
```

---

#### `GET /payments/{payment_id}`
**Описание**: Получить один платёж

**Параметры**:
```
payment_id: int (path)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
{
  "id": 42,
  "user_id": 40,
  "amount": 9.99,
  "currency": "USD",
  "status": "pending",
  "provider": "telegram_bot",
  "provider_payment_id": null,
  "created_at": "2025-09-28T12:34:56Z"
}
```

**Ошибки**:
- `403` — Not allowed (не админ и не владелец)
- `404` — Payment not found

---

#### `PUT /payments/{payment_id}`
**Описание**: Обновить платёж (например, обновить статус вручную)

**Параметры**:
```
payment_id: int (path)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Запрос**:
```json
{
  "amount": 9.99,
  "currency": "USD",
  "provider": "telegram_bot"
}
```

**Ответ** (200):
```json
{
  "id": 42,
  "user_id": 40,
  "amount": 9.99,
  "currency": "USD",
  "status": "pending",
  "provider": "telegram_bot",
  "provider_payment_id": null,
  "created_at": "2025-09-28T12:34:56Z"
}
```

**Ошибки**:
- `403` — Not allowed
- `404` — Payment not found

---

#### `DELETE /payments/{payment_id}`
**Описание**: Удалить платёж

**Параметры**:
```
payment_id: int (path)
```

**Headers**:
```
Authorization: Bearer <ACCESS_TOKEN>
```

**Ответ** (200):
```json
{
  "msg": "deleted"
}
```

**Ошибки**:
- `403` — Not allowed
- `404` — Payment not found

---

### 4.5 Webhook (Placeholder)

**Примечание**: Webhook для платёжных провайдеров (Telegram Bot, IAP) пока не полностью реализован в коде. Требуется:

```python
@router.post("/payments/webhook")
def payments_webhook(
    payload: dict,
    signature: str,  # Подпись от провайдера
    db: Session = Depends(get_db)
):
    # 1. Валидировать подпись
    # 2. Извлечь provider_payment_id для идемпотентности
    # 3. Найти Payment запись
    # 4. Обновить status -> "completed" или "failed"
    # 5. Если completed -> создать/активировать UserTariff
    # 6. Вернуть 200 для подтверждения приёма
```

**Идемпотентность**: Используется `provider_payment_id` для предотвращения дублирования платежей при повторной отправке webhook-а.

---

## 5. Ключевые особенности

### 5.1 Интеграция с wg-easy

**wg-easy** — веб-интерфейс для управления WireGuard. Наш API может:

1. **Создавать клиентов** через wg-easy REST API:
   ```
   POST http://wg-easy:8588/api/wireguard/client
   {
     "name": "peer-40-abc123"
   }
   ```

2. **Получать конфиги** (wg-quick формат):
   ```
   GET http://wg-easy:8588/api/wireguard/client/{client_id}/configuration
   ```

3. **Удалять клиентов**:
   ```
   DELETE http://wg-easy:8588/api/wireguard/client/{client_id}
   ```

**Адаптер**: `vpn_api/wg_easy_adapter.py`
- Использует `wg-easy-api` пакет (async wrapper)
- Fallback на прямые HTTP запросы через `aiohttp`
- Поддерживает Authorization через `WG_EASY_PASSWORD` или `WG_API_KEY`

**Процесс создания пира через wg-easy**:
1. API вызывает `WgEasyAdapter.create_client(name)`
2. Адаптер отправляет POST запрос к wg-easy
3. wg-easy генерирует пару ключей и конфиг
4. API получает publicKey и client_id
5. API получает конфиг (который содержит privateKey)
6. API сохраняет publicKey, private_key (из конфига), и wg_client_id в БД
7. Конфиг шифруется и сохраняется для последующего получения

---

### 5.2 SSH управление WireGuard

Если `WG_APPLY_ENABLED=1` и `WG_HOST_SSH` установлен:

**Структура скриптов**:
- `scripts/wg_apply.sh` — добавить пира в wg интерфейс
  ```bash
  sudo wg set wg0 peer <pubkey> allowed-ips <allowed_ips>
  ```

- `scripts/wg_remove.sh` — удалить пира
  ```bash
  sudo wg set wg0 peer <pubkey> remove
  ```

- `scripts/wg_gen_key.sh` — сгенерировать keypair
  ```bash
  wg genkey | tee /etc/wg-keys/<name>_private | wg pubkey > /etc/wg-keys/<name>_public
  ```

**Вызов через SSH**:
```python
ssh root@62.84.98.109 'sudo /srv/vpn-api/scripts/wg_apply.sh wg0 <publicKey> <allowed_ips>'
```

---

### 5.3 Шифрование конфигураций

**Fernet (symmetric encryption)** используется для хранения wg-quick конфигов в БД:

```python
# Encrypt
from cryptography.fernet import Fernet
f = Fernet(os.getenv("CONFIG_ENCRYPTION_KEY"))
encrypted = f.encrypt(config_text.encode())

# Decrypt
config_text = f.decrypt(encrypted).decode()
```

**Ключ**: `CONFIG_ENCRYPTION_KEY` (base64-encoded, длина 44 символа)

Генерация:
```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

---

### 5.4 JWT токены

**Алгоритм**: HS256 (HMAC-SHA256)  
**Срок**: 60 минут (переменная `ACCESS_TOKEN_EXPIRE_MINUTES`)  
**Payload**: `{"sub": user_email, "exp": expiration_time}`

**Механизм обновления** (не реализован в текущей версии, но рекомендуется):
- Добавить `refresh_token` (долгоживущий, например на 7 дней)
- Эндпоинт `POST /auth/refresh` для получения нового `access_token`
- Клиент должен перехватывать 401 и пытаться рефреш

---

### 5.5 Миграции Alembic

**Инициализация**:
```bash
alembic init alembic
```

**Создать новую миграцию**:
```bash
alembic revision --autogenerate -m "add user table"
```

**Применить миграции**:
```bash
DATABASE_URL=postgresql://... alembic upgrade head
```

**Откат** (не рекомендуется в production):
```bash
alembic downgrade -1
```

**Структура миграций** в `alembic/versions/`:
- `001_initial_schema.py` — create tables
- `002_add_email_verification.py` — add is_verified, verification_code
- и т.д.

---

## 6. Безопасность

### 6.1 Аутентификация и авторизация

✅ **Implemented**:
- JWT Bearer tokens (HS256)
- Пароли хранятся как PBKDF2-SHA256 хэши
- Role-based access control (is_admin flag)
- OAuth2PasswordBearer с FastAPI

❌ **Not Implemented**:
- Email верификация (только структура в моделях)
- Password reset (функционал в планах)
- Refresh token механизм
- Rate limiting на endpoints
- CORS конфигурация

### 6.2 Защита приватных ключей

⚠️ **Текущее состояние**:
- Приватные ключи WireGuard сохраняются в открытом виде в БД
- Возвращаются только на создание пира (в POST)
- Никогда не возвращаются в GET запросах

✅ **Рекомендации**:
- Зашифровать приватные ключи в БД (как делается с конфигами)
- Использовать CONFIG_ENCRYPTION_KEY для обоих
- Развертывать с TLS для всех endpoints

### 6.3 Защита webhook-ов

⚠️ **Текущее состояние**:
- Webhook не реализован, но нужна подпись
- Используется `provider_payment_id` для идемпотентности

✅ **Рекомендации**:
- Валидировать подпись HMAC (используя secret от провайдера)
- Проверять timestamp (предотвращение replay attacks)
- Логировать все webhook запросы
- Мониторить 2xx ответы (webhook должен быть идемпотентным)

### 6.4 Секреты в окружении

**Обязательные переменные**:
```bash
SECRET_KEY                    # JWT signing key (min 32 символа)
PROMOTE_SECRET                # Bootstrap secret для первого админа
DATABASE_URL                  # PostgreSQL URI
WG_EASY_URL                   # http://wg-easy:8588/
WG_EASY_PASSWORD              # Пароль wg-easy
CONFIG_ENCRYPTION_KEY         # Fernet ключ (Cryptography)
```

**Опциональные**:
```bash
WG_KEY_POLICY                 # "db" | "host" | "wg-easy" (default: "db")
WG_APPLY_ENABLED              # "1" | "0" (default: "0")
WG_HOST_SSH                   # "user@host" для SSH вызовов
WG_INTERFACE                  # "wg0" (default)
ACCESS_TOKEN_EXPIRE_MINUTES   # 60 (default)
```

---

## 7. Интеграция с Flutter

### 7.1 Основные endpoints для мобильного клиента

**Обязательные**:

1. **Регистрация и вход**
   ```
   POST /auth/register
   POST /auth/login
   GET /auth/me
   ```

2. **Создание VPN пира**
   ```
   POST /vpn_peers/self
   GET /vpn_peers/
   GET /vpn_peers/{peer_id}
   GET /vpn_peers/self/config
   DELETE /vpn_peers/{peer_id}
   ```

3. **Тарифы**
   ```
   GET /tariffs/
   ```

4. **Платежи**
   ```
   POST /payments/
   GET /payments/
   GET /payments/{payment_id}
   ```

### 7.2 Заголовки и авторизация

**Все защищённые endpoints требуют**:
```
Authorization: Bearer <ACCESS_TOKEN>
Content-Type: application/json
```

**Обработка ошибок в Flutter**:
- `401` → Токен истёк, требуется re-login
- `403` → Доступ запрещён
- `400`/`422` → Validation error, показать пользователю
- `500` → Server error, retry или показать сообщение

### 7.3 Данные, возвращаемые API

**UserOut** (при регистрации, логине, me):
```json
{
  "id": 1,
  "email": "user@example.com",
  "status": "active",
  "is_admin": false,
  "created_at": "2025-09-28T12:00:00Z"
}
```

**VpnPeerOut** (при создании):
```json
{
  "id": 1,
  "user_id": 1,
  "wg_public_key": "base64_string",
  "wg_private_key": "base64_string",  // только при создании!
  "wg_ip": "10.10.0.1/32",
  "allowed_ips": "0.0.0.0/0",
  "active": true,
  "created_at": "2025-09-28T12:00:00Z"
}
```

**Config** (при GET /vpn_peers/self/config):
```json
{
  "wg_quick": "[Interface]\nPrivateKey = ...\nAddress = ...\n\n[Peer]\n..."
}
```

### 7.4 Rate limiting

⚠️ **Не реализовано**, рекомендуется добавить:
- Per-user rate limit (например, 100 req/min)
- Per-endpoint rate limit (создание пира — 1 в 10 сек)
- Возвращать `429 Too Many Requests` при превышении

**Пакеты для FastAPI**:
- `slowapi` — Rate limiting middleware
- `fastapi-limiter` — Alternative

---

## 8. IAP интеграция

### 8.1 Текущее состояние

❌ **Не реализовано**, требует:

1. **Backend endpoint для receipt verification**
2. **Webhook от IAP провайдера**
3. **Mapping receipt ↔ subscription**

### 8.2 Рекомендуемый flow

**На мобильном клиенте** (Flutter):
```dart
// 1. Пользователь выбирает subscription
// 2. initStoreKit() инициирует платёж
// 3. Получаем receipt или transaction ID
// 4. Отправляем на backend:

POST /payments/iap_verify
{
  "receipt": "base64_receipt_data",
  "provider": "app_store" // или "google_play"
}
```

**На backend-е**:
```python
@router.post("/payments/iap_verify")
def verify_iap_receipt(payload: IAP_VerifyIn, 
                       db: Session,
                       current_user: User = Depends(get_current_user)):
    # 1. Валидировать receipt на Apple/Google servers
    # 2. Извлечь product_id, expiration_date
    # 3. Создать/обновить Payment в БД (status = "completed")
    # 4. Найти соответствующий Tariff и создать UserTariff
    # 5. Вернуть {"status": "verified", "expires_at": ...}
```

### 8.3 Структура данных для IAP

**Добавить в Payment**:
```python
class Payment(Base):
    ...
    iap_receipt: str | None       # Base64 receipt от App Store/Google Play
    iap_product_id: str | None    # "premium_monthly" и т.д.
    subscription_expires_at: datetime | None
```

**Добавить в UserTariff**:
```python
class UserTariff(Base):
    ...
    iap_transaction_id: str | None  # Transaction ID от IAP
    auto_renewing: bool           # Автопролонгация включена?
```

### 8.4 Webhook от IAP провайдера

**App Store Server-to-Server Notifications**:
```
POST /payments/webhook/app_store
{
  "signedPayload": "base64_jwt_signed"
}
```

**Google Play Pub/Sub**:
```
POST /payments/webhook/google_play
{
  "message": {
    "data": "base64_subscription_update"
  }
}
```

---

## 9. Развёртывание

### 9.1 Требования

- Python 3.12
- PostgreSQL 13+ (для production)
- Docker & docker-compose
- SSH доступ к wg-easy host (если используется WG_HOST_SSH)

### 9.2 Переменные окружения (`.env.production`)

```bash
# Database
DATABASE_URL=postgresql://vpnuser:strongpass@localhost:5432/vpndb

# JWT
SECRET_KEY=very-long-random-secret-min-32-chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
PROMOTE_SECRET=bootstrap-secret

# WG / wg-easy
WG_KEY_POLICY=wg-easy
WG_EASY_URL=http://wg-easy-host:8588/
WG_EASY_PASSWORD=wg-easy-admin-password

# WG Host SSH (опционально)
WG_APPLY_ENABLED=0
WG_HOST_SSH=root@wg-easy-host
WG_INTERFACE=wg0
WG_APPLY_SCRIPT=/srv/vpn-api/scripts/wg_apply.sh
WG_REMOVE_SCRIPT=/srv/vpn-api/scripts/wg_remove.sh
WG_GEN_SCRIPT=/srv/vpn-api/scripts/wg_gen_key.sh

# Encryption
CONFIG_ENCRYPTION_KEY=<base64-fernet-key>

# Dev options
DEV_INIT_DB=0
APP_VERSION=0.1.0
```

### 9.3 Docker Compose (production)

```yaml
version: '3.8'

services:
  web:
    image: vpn-api:latest
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://vpnuser:pass@db:5432/vpndb
      - SECRET_KEY=${SECRET_KEY}
      - WG_EASY_URL=${WG_EASY_URL}
      - WG_EASY_PASSWORD=${WG_EASY_PASSWORD}
      - CONFIG_ENCRYPTION_KEY=${CONFIG_ENCRYPTION_KEY}
    depends_on:
      - db
    command: uvicorn vpn_api.main:app --host 0.0.0.0 --port 8000

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=vpnuser
      - POSTGRES_PASSWORD=strongpass
      - POSTGRES_DB=vpndb
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 9.4 Миграции перед деплоем

```bash
# 1. Бэкап БД
pg_dump postgresql://vpnuser:pass@localhost:5432/vpndb -F c > backup.dump

# 2. Применить миграции
DATABASE_URL=postgresql://vpnuser:pass@localhost:5432/vpndb \
  alembic upgrade head

# 3. Проверить Swagger
curl http://localhost:8000/docs
```

### 9.5 Smoke tests после деплоя

```bash
# 1. Health check
curl http://localhost:8000/

# 2. Регистрация
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test12345"}'

# 3. Логин
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test12345"}' | jq -r .access_token)

# 4. Получить пользователя
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/auth/me

# 5. Создать пира
curl -X POST http://localhost:8000/vpn_peers/self \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### 9.6 Мониторинг и логирование

**Базовое логирование уже включено**:
- `vpn_api/wg_host.py` использует `logger` для SSH операций
- FastAPI по умолчанию логирует все запросы в Uvicorn

**Рекомендуется добавить**:
- Sentry для error tracking
- ELK stack или Loki для centralized logging
- Prometheus для метрик
- Systemd unit для запуска на Linux

---

## 10. Полезные команды

### Локальная разработка (Windows)

```powershell
# Создать venv
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Установить зависимости
python -m pip install -r vpn_api/requirements.txt
python -m pip install -r vpn_api/requirements-dev.txt

# Запустить сервер
python -m uvicorn vpn_api.main:app --reload

# Запустить тесты
python -m pytest -v

# Lint
python -m ruff check vpn_api/
python -m black vpn_api/
python -m isort vpn_api/

# Миграции
alembic revision --autogenerate -m "описание"
alembic upgrade head
```

### CI/CD (GitHub Actions)

```bash
# Тесты
python -m pytest --cov=vpn_api

# Lint
python -m ruff check vpn_api/
python -m black --check vpn_api/
python -m isort --check vpn_api/

# Миграции
DATABASE_URL=... alembic upgrade head
```

### Docker

```bash
# Собрать образ
docker build -t vpn-api:latest .

# Запустить контейнер
docker run -p 8000:8000 \
  -e DATABASE_URL=... \
  -e SECRET_KEY=... \
  vpn-api:latest

# Docker compose
docker-compose -f docker-compose.yml up -d
docker-compose logs -f web
```

---

## 11. Часто задаваемые вопросы

### Q: Как сгенерировать CONFIG_ENCRYPTION_KEY?

```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### Q: Как сгенерировать bcrypt PASSWORD_HASH для wg-easy?

```bash
python3 -c "from passlib.hash import bcrypt; print(bcrypt.hash('supersecret'))"
```

### Q: Как reset пароль пользователю?

```bash
# 1. В БД (через psql):
UPDATE users SET hashed_password = NULL WHERE email = 'user@example.com';

# 2. Или через API endpoint (требуется создать):
POST /auth/reset_password
{
  "email": "user@example.com",
  "new_password": "NewPassword123"
}
```

### Q: Как изменить срок действия JWT токена?

```bash
# В .env
ACCESS_TOKEN_EXPIRE_MINUTES=120
```

### Q: Как отключить WG_APPLY (SSH операции)?

```bash
# В .env
WG_APPLY_ENABLED=0
```

Это безопасный режим по умолчанию. Включайте только когда тестируете SSH вызовы.

### Q: Как логировать все SQL запросы?

```python
# В database.py добавить:
import logging
logging.basicConfig()
logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)
```

---

## 12. Структура API summary

| Метод | Endpoint | Auth | Описание |
|-------|----------|------|---------|
| POST | /auth/register | ❌ | Регистрация пользователя |
| POST | /auth/login | ❌ | Получить JWT token |
| GET | /auth/me | ✅ | Информация о себе |
| POST | /auth/admin/promote | ⚡ | Повысить админа (bootstrap или админ) |
| POST | /auth/assign_tariff | ✅ (admin) | Назначить тариф пользователю |
| POST | /vpn_peers/ | ✅ (admin) | Создать пир для пользователя |
| POST | /vpn_peers/self | ✅ | Создать пир для себя |
| GET | /vpn_peers/ | ✅ | Список пиров |
| GET | /vpn_peers/{id} | ✅ | Один пир |
| GET | /vpn_peers/self/config | ✅ | wg-quick конфиг |
| PUT | /vpn_peers/{id} | ✅ | Обновить пир |
| DELETE | /vpn_peers/{id} | ✅ | Удалить пир |
| POST | /tariffs/ | ✅ (admin) | Создать тариф |
| GET | /tariffs/ | ❌ | Список тарифов |
| GET | /tariffs/{id} | ❌ | Один тариф |
| DELETE | /tariffs/{id} | ✅ (admin) | Удалить тариф |
| POST | /payments/ | ✅ | Создать платёж |
| GET | /payments/ | ✅ | Список платежей |
| GET | /payments/{id} | ✅ | Один платёж |
| PUT | /payments/{id} | ✅ | Обновить платёж |
| DELETE | /payments/{id} | ✅ | Удалить платёж |

**Легенда**: ✅ требуется; ❌ не требуется; ⚡ спец. логика

---

## 13. Контрольный список для продакшена

- [ ] Все переменные окружения установлены (SECRET_KEY, DATABASE_URL и т.д.)
- [ ] PostgreSQL база данных создана и доступна
- [ ] Запущены миграции Alembic (`alembic upgrade head`)
- [ ] wg-easy контейнер запущен и доступен по сети
- [ ] SSH доступ к wg-easy host настроен (если используется WG_APPLY_ENABLED=1)
- [ ] TLS/HTTPS настроен (nginx с certbot)
- [ ] Firewall открыты нужные порты (8000 для API, 51820 для WireGuard)
- [ ] Логирование настроено (Sentry, ELK, Loki)
- [ ] Бэкапы БД настроены (pg_dump cronjob)
- [ ] Мониторинг настроен (Prometheus, Grafana)
- [ ] Rate limiting включен
- [ ] CORS настроен для мобильного клиента
- [ ] Swagger доступен для документации (/docs)
- [ ] Health check endpoint работает
- [ ] Smoke tests пройдены

---

**Конец документации**

Версия 1.0 — Полный обзор VPN Backend API для мобильного клиента Flutter и интеграций платежей.
