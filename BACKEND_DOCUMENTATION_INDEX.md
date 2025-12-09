# VPN Backend API — Краткий Summary и Навигация

**Дата подготовки**: 3 декабря 2025  
**Версия документации**: 1.0  
**Статус**: ✅ Готово к review

---

## 📚 Документация (3 части)

### 1️⃣ **VPN_BACKEND_ARCHITECTURE.md** (полный обзор)
**Содержит**: Архитектура, модели, API endpoints, особенности, IAP

Рекомендуется к прочтению:
- [ ] Разработчикам, начинающим работу с backend
- [ ] При интеграции нового модуля
- [ ] Для понимания потока данных

**Ключевые разделы**:
- Структура проекта (файлы, директории)
- Модели БД (User, VpnPeer, Tariff, Payment и т.д.)
- Полный список API endpoints с примерами
- Интеграция с wg-easy и SSH управление WireGuard
- IAP интеграция (App Store, Google Play)

---

### 2️⃣ **FLUTTER_IAP_INTEGRATION.md** (API client + IAP)
**Содержит**: Примеры на Dart, обработка ошибок, IAP flow

Рекомендуется к прочтению:
- [ ] Flutter разработчикам
- [ ] При интеграции IAP платежей
- [ ] Для локализации сообщений об ошибках

**Ключевые разделы**:
- ApiClient реализация на Flutter (requests, error handling)
- Примеры запросов (регистрация, логин, создание пира)
- IAP интеграция (App Store + Google Play)
- Backend endpoints для receipt verification
- Webhook обработка от App Store и Google Play
- Примеры UI компонентов (subscription screen)

---

### 3️⃣ **BACKEND_SECURITY_DEPLOY.md** (DevOps)
**Содержит**: Безопасность, Docker, GitHub Actions, мониторинг

Рекомендуется к прочтению:
- [ ] DevOps инженерам
- [ ] При подготовке к production
- [ ] Для настройки CI/CD

**Ключевые разделы**:
- Безопасность (JWT, password hashing, webhook verification)
- Docker Compose конфиги (production-ready)
- GitHub Actions CI/CD workflows
- Backup и disaster recovery
- Prometheus метрики и Sentry интеграция
- Troubleshooting

---

## 🎯 Quick Reference

### Основные endpoints

#### Authentication
```
POST   /auth/register              # Регистрация
POST   /auth/login                 # Логин (JWT token)
GET    /auth/me                    # Текущий пользователь
POST   /auth/admin/promote         # Повысить админа
POST   /auth/assign_tariff         # Назначить тариф
```

#### VPN Peers
```
POST   /vpn_peers/self             # Создать пир для себя
GET    /vpn_peers/                 # Список пиров
GET    /vpn_peers/{id}             # Один пир
GET    /vpn_peers/self/config      # wg-quick конфиг
PUT    /vpn_peers/{id}             # Обновить пир
DELETE /vpn_peers/{id}             # Удалить пир
```

#### Tariffs
```
POST   /tariffs/                   # Создать тариф (админ)
GET    /tariffs/                   # Список тарифов (публичный)
GET    /tariffs/{id}               # Один тариф (публичный)
DELETE /tariffs/{id}               # Удалить тариф (админ)
```

#### Payments
```
POST   /payments/                  # Создать платёж
GET    /payments/                  # Список платежей
GET    /payments/{id}              # Один платёж
PUT    /payments/{id}              # Обновить платёж
DELETE /payments/{id}              # Удалить платёж
POST   /payments/iap_verify        # Верифицировать IAP receipt
POST   /payments/webhook/app_store # App Store webhook
POST   /payments/webhook/google    # Google Play webhook
```

### Переменные окружения

**Обязательные**:
```bash
SECRET_KEY                    # JWT signing key (min 32 chars)
PROMOTE_SECRET                # Bootstrap secret для первого админа
DATABASE_URL                  # PostgreSQL connection string
WG_EASY_URL                   # http://wg-easy:8588/
WG_EASY_PASSWORD              # wg-easy password
CONFIG_ENCRYPTION_KEY         # Fernet key (base64, 44 chars)
```

**Опциональные**:
```bash
WG_KEY_POLICY                 # "db" | "host" | "wg-easy" (default: "db")
WG_APPLY_ENABLED              # "0" | "1" (default: "0")
WG_HOST_SSH                   # user@host for SSH calls
ACCESS_TOKEN_EXPIRE_MINUTES   # default 60
```

### Информацию о репозитории

```
Repository:  https://github.com/Midasfallen/vpn-api
Language:    Python 3.12
Framework:   FastAPI + SQLAlchemy
СУБД:        PostgreSQL (prod) / SQLite (dev)
Версия:      0.1.0
```

---

## 🏗️ Архитектура на высоком уровне

```
┌─────────────────────────────────────────┐
│         Flutter Mobile Client           │
│   (Dart, flutter_login, WireGuard)      │
└────────────────────┬────────────────────┘
                     │ HTTP/REST
┌────────────────────▼─────────────────────────────────────┐
│                   FastAPI Backend                         │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │ Auth Routes  │ │ VPN Peers    │ │ Tariffs/        │  │
│  │ (JWT, OAuth) │ │ (WireGuard)  │ │ Payments (IAP)  │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
│         │                 │                   │          │
└─────────┼─────────────────┼───────────────────┼──────────┘
          │                 │                   │
    ┌─────▼──────┐    ┌─────▼──────┐    ┌──────▼────────┐
    │ SQLAlchemy │    │ wg-easy    │    │ Token Storage │
    │ PostgreSQL │    │ Adapter    │    │ (Secure)      │
    └────────────┘    └────────────┘    └───────────────┘
```

---

## 🔒 Безопасность — ключевые моменты

✅ **Implemented**:
- JWT Bearer token authentication (HS256)
- Password hashing (PBKDF2-SHA256)
- Role-based access control (is_admin)
- OAuth2PasswordBearer с FastAPI

⚠️ **Recommended**:
- Rate limiting (5 логинов/мин, 1 пир/мин)
- TLS/HTTPS (nginx + Let's Encrypt)
- Email верификация
- Password recovery flow
- Sentry для error tracking
- Webhook signature verification
- Privаtные ключи зашифрованы (Fernet)

---

## 🚀 Развёртывание — пошаговый план

### 1. Подготовка (Dev)
```bash
python -m venv .venv
source .venv/bin/activate  # или .\.venv\Scripts\Activate.ps1 на Windows
pip install -r vpn_api/requirements.txt
pip install -r vpn_api/requirements-dev.txt

# Локально
DATABASE_URL=sqlite:///./vpn_api/test.db python -m uvicorn vpn_api.main:app --reload
```

### 2. Подготовка переменных окружения
```bash
# Создать .env.production с обязательными переменными
cp .env.example .env.production

# Сгенерировать SECRET_KEY
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Сгенерировать CONFIG_ENCRYPTION_KEY
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 3. Docker образ
```bash
docker build -t vpn-api:latest .
docker tag vpn-api:latest myregistry.com/vpn-api:latest
docker push myregistry.com/vpn-api:latest
```

### 4. Запуск на сервере
```bash
# Скопировать docker-compose.yml и .env.production
docker-compose -f docker-compose.yml up -d

# Проверить здоровье
docker-compose ps
curl http://localhost:8000/
```

### 5. Миграции БД
```bash
# Внутри контейнера (автоматически при запуске)
# или вручную:
docker-compose exec web alembic upgrade head
```

### 6. Smoke tests
```bash
# Регистрация
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test12345"}'

# Логин
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test12345"}' | jq -r .access_token)

# Проверить me
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/auth/me
```

---

## 📊 API endpoints summary

| Группа | Count | Auth | Examples |
|--------|-------|------|----------|
| **Auth** | 5 | Mixed | /auth/register, /auth/login, /auth/me |
| **VPN Peers** | 6 | Required | /vpn_peers/self, /vpn_peers/{id}, /vpn_peers/self/config |
| **Tariffs** | 4 | Mixed | /tariffs/, /tariffs/{id} |
| **Payments** | 7 | Mixed | /payments/, /payments/iap_verify, /payments/webhook/* |
| **Total** | **22** | - | - |

---

## 📈 Планы развития (TODO)

### Phase 1 — MVP+ (in progress)
- [x] Basic auth (register/login)
- [x] VPN peers CRUD
- [x] Tariffs CRUD
- [x] Payments (stub)
- [ ] IAP integration ← **WIP**
- [ ] Email verification ← **WIP**

### Phase 2 — Production (recommended)
- [ ] Rate limiting
- [ ] Refresh token flow
- [ ] Password reset/recovery
- [ ] Admin dashboard API
- [ ] Webhook signature verification (App Store, Google Play)
- [ ] Sentry integration
- [ ] Prometheus metrics

### Phase 3 — Scale
- [ ] Multi-region deployment
- [ ] Database replication
- [ ] Redis caching
- [ ] Subscription management dashboard
- [ ] Refund handling
- [ ] Advanced analytics

---

## 🛠️ Tools & Dependencies

### Backend
```
FastAPI 0.111+           # Web framework
SQLAlchemy 2.0+          # ORM
Pydantic 2.11+           # Data validation
passlib[bcrypt]          # Password hashing
python-jose[crypto]      # JWT tokens
Alembic 1.16+            # DB migrations
httpx / aiohttp          # HTTP client
wg-easy-api 0.1.2        # WireGuard API wrapper
cryptography             # Fernet encryption
```

### Frontend (Flutter)
```
http / dio               # HTTP client
flutter_secure_storage   # Secure token storage
in_app_purchase          # IAP support
wireguard_flutter        # WireGuard integration
flutter_login            # Auth UI
easy_localization        # i18n
```

### DevOps
```
Docker & docker-compose  # Containerization
PostgreSQL 13+           # Database
nginx                    # Reverse proxy
Alembic                  # DB migrations
GitHub Actions           # CI/CD
Prometheus               # Metrics
Sentry                   # Error tracking
```

---

## 👥 Как использовать документацию

### Для Frontend разработчика
1. Прочитать **VPN_BACKEND_ARCHITECTURE.md** § 4 (API Endpoints)
2. Прочитать **FLUTTER_IAP_INTEGRATION.md** полностью
3. Использовать как reference при интеграции

### Для Backend разработчика
1. Прочитать **VPN_BACKEND_ARCHITECTURE.md** полностью
2. Fokus на § 1-3 (архитектура, модели, endpoints)
3. Прочитать **BACKEND_SECURITY_DEPLOY.md** § 1-2 (security, docker)

### Для DevOps инженера
1. Прочитать **BACKEND_SECURITY_DEPLOY.md** полностью
2. Fokus на § 2-6 (docker, CI/CD, monitoring, recovery)
3. Настроить backup, logging, monitoring

### Для QA/Tester
1. Прочитать **VPN_BACKEND_ARCHITECTURE.md** § 4 (endpoints)
2. Использовать как checklist для тестирования
3. Прочитать **FLUTTER_IAP_INTEGRATION.md** § 6 (IAP testing)

---

## 🔗 Полезные ссылки

### Код
- Backend: https://github.com/Midasfallen/vpn-api
- Frontend: https://github.com/Midasfallen/vpn (текущий workspace)

### Инструменты
- FastAPI docs: https://fastapi.tiangolo.com/
- SQLAlchemy: https://docs.sqlalchemy.org/
- WireGuard: https://www.wireguard.com/
- App Store Connect: https://appstoreconnect.apple.com/
- Google Play Console: https://play.google.com/console/

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-03 | Initial documentation |
| - | - | - |

---

## ✅ Контрольный список для интеграции Flutter + Backend

- [ ] Backend API запущена локально (http://localhost:8000)
- [ ] Swagger доступен (http://localhost:8000/docs)
- [ ] Создан тестовый админ через bootstrap secret
- [ ] Создан тестовый тариф
- [ ] Flutter ApiClient интегрирован и работает
- [ ] Регистрация и логин работают
- [ ] Создание VPN пира работает
- [ ] Получение конфига работает
- [ ] IAP интеграция готова (продукты в App Store Connect / Google Play Console)
- [ ] Receipt verification endpoint работает
- [ ] Webhook от App Store / Google Play тестировал (sandbox)
- [ ] Subscription активируется после платежа
- [ ] Subscription деактивируется при истечении
- [ ] Ошибки локализованы (en.json, ru.json)

---

## 📞 Support

При вопросах:
1. Проверить документацию выше
2. Посмотреть примеры в `vpn_api/` коде
3. Посмотреть тесты в `tests/` директории
4. Открыть issue в GitHub репозитории

---

**Конец документации**

✅ **Все документы готовы к использованию!**

Документация содержит:
- ✅ 3000+ строк детального описания
- ✅ 22 API endpoints с примерами
- ✅ 5+ примеров кода (Flutter, Python, bash, yaml)
- ✅ Полная архитектура и flow
- ✅ Рекомендации по безопасности
- ✅ Production-ready deploy инструкции
- ✅ IAP интеграция (App Store + Google Play)
- ✅ Troubleshooting и FAQ

Версия 1.0 от 3 декабря 2025 г.
