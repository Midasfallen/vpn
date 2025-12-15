# VPN Flutter Project — Production Ready

🎉 **Status: FULLY WORKING AND TESTED ON REAL DEVICE**

Complete VPN solution with Flutter mobile app, FastAPI backend, and WireGuard integration.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Docker & Docker Compose
- WireGuard server with wg-easy
- PostgreSQL database

### Backend Setup
```bash
cd backend_api
cp .env.production.example /srv/vpn-api/.env.production
# Configure .env.production (see backend_api/README.md)
docker-compose up -d
```

### Frontend Setup
```bash
flutter pub get
flutter run --flavor prod
```

## ✅ Production Status

**Last Updated:** December 15, 2025

### Test Results
- ✅ **34/34 Backend Unit Tests** passing
- ✅ **16/16 Flutter Tests** passing
- ✅ **2/2 E2E Automated Tests** passing
- ✅ **Manual Testing** on Samsung SM-S938B - SUCCESS
- ✅ **Internet Access** through VPN verified

See detailed results in [E2E_TEST_RESULTS.md](E2E_TEST_RESULTS.md)

### Critical Fixes Applied

1. **WireGuard Config Generation** - Fixed server public key, Endpoint, DNS
2. **wg-easy Integration** - Peers now registered on WireGuard server for internet access
3. **Environment Configuration** - Fixed .env.production format issues

## 📁 Project Structure

```
vpn/
├── lib/                    # Flutter app source
│   ├── api/               # API client & services
│   ├── screens/           # UI screens
│   └── main.dart          # App entry point
├── backend_api/           # FastAPI backend
│   ├── auth.py           # Authentication
│   ├── peers.py          # VPN peer management
│   ├── wg_easy_adapter.py # wg-easy integration
│   └── README.md         # Backend documentation
├── test/                  # Flutter tests
├── E2E_TEST_RESULTS.md   # E2E test results
└── README.md             # This file
```

## 🔑 Key Features

### Mobile App (Flutter)
- ✅ User authentication (JWT-based)
- ✅ WireGuard VPN connection
- ✅ Subscription management
- ✅ In-App Purchase integration (iOS & Android)
- ✅ Tariff plans
- ✅ Secure token storage
- ✅ Offline mode support

### Backend (FastAPI)
- ✅ RESTful API
- ✅ WireGuard peer management
- ✅ **wg-easy integration** (CRITICAL for internet access)
- ✅ JWT authentication
- ✅ PostgreSQL database
- ✅ Config encryption
- ✅ IAP validation (Apple & Google)
- ✅ Email notifications

### Infrastructure
- ✅ Docker Compose deployment
- ✅ WireGuard server (62.84.98.109:51821)
- ✅ wg-easy management UI (port 8588)
- ✅ PostgreSQL database
- ✅ Automated CI/CD pipeline

## ⚠️ Critical Configuration

### wg-easy Integration (REQUIRED)

For VPN to work with internet access, you **MUST** configure wg-easy integration in backend `.env.production`:

```bash
WG_KEY_POLICY=wg-easy                # CRITICAL! Without this, VPN connects but has no internet
WG_EASY_URL=http://62.84.98.109:8588/
WG_EASY_PASSWORD=<your_password>
WG_SERVER_PUBLIC_KEY=1SUivFxEBdU5SjpL2cLBykv/4HcotWpIrdSUGFDGIA8=
WG_ENDPOINT=62.84.98.109:51821
WG_DNS=1.1.1.1
WG_MTU=1420
```

**Why this is critical:**
- Without `WG_KEY_POLICY=wg-easy`, backend creates peers locally but doesn't register them on the WireGuard server
- WireGuard server only routes traffic for registered peers
- Result: VPN connects successfully but has **no internet access**

See [backend_api/README.md](backend_api/README.md) for detailed configuration.

## 📚 Documentation

- [E2E_TEST_RESULTS.md](E2E_TEST_RESULTS.md) - Complete E2E test results and manual testing guide
- [backend_api/README.md](backend_api/README.md) - Backend setup, API endpoints, troubleshooting
- [MANUAL_TESTING_GUIDE.md](MANUAL_TESTING_GUIDE.md) - Manual testing instructions

## 🧪 Testing

### Backend Tests
```bash
cd backend_api
pytest
```

### Flutter Tests
```bash
flutter test
```

### E2E Tests
```bash
flutter test test/e2e_vpn_full_flow_test.dart
```

## 🐛 Troubleshooting

### VPN connects but no internet

**Cause:** `WG_KEY_POLICY` not set to `wg-easy`

**Solution:**
1. Add `WG_KEY_POLICY=wg-easy` to backend `.env.production`
2. Configure `WG_EASY_URL` and `WG_EASY_PASSWORD`
3. Restart: `docker-compose down && docker-compose up -d`
4. Delete old VPN peers in app and create new ones

### Authentication fails

**Cause:** Backend database connection issues or malformed `.env.production`

**Solution:**
1. Check backend logs: `docker logs vpn-api-web-1`
2. Verify `.env.production` has proper line breaks (no literal `\n`)
3. Restart containers

See [backend_api/README.md](backend_api/README.md#troubleshooting) for more issues.

## 🚀 Deployment

### Production Checklist
- [ ] Configure backend `.env.production` with all required variables
- [ ] Set `WG_KEY_POLICY=wg-easy`
- [ ] Generate strong keys (`SECRET_KEY`, `CONFIG_ENCRYPTION_KEY`)
- [ ] Configure wg-easy URL and password
- [ ] Set correct `WG_SERVER_PUBLIC_KEY` and `WG_ENDPOINT`
- [ ] Start Docker containers
- [ ] Run all tests
- [ ] Test on real device
- [ ] Verify internet access through VPN

### CI/CD

GitHub Actions workflow automatically runs on push:
- Flutter analyze
- Flutter tests
- Backend tests

See [.github/workflows/](. github/workflows/) for pipeline configuration.

---

## 📋 Phase History

## Phase 4: In-App Purchase (IAP) Integration ✅

### Phase 4.1: Backend IAP Webhook ✅
- **Status**: COMPLETE
- **Files**: `backend_api/iap_validator.py`, `backend_api/payments.py`, `backend_api/auth.py`
- **Details**: [PHASE_4_1_IMPLEMENTATION.md](./PHASE_4_1_IMPLEMENTATION.md)

**Реализовано**:
- ✅ Apple receipt validation via iTunes API
- ✅ `POST /payments/webhook` endpoint для приёма платежей
- ✅ `GET /auth/me/subscription` endpoint для получения статуса подписки
- ✅ Automatic UserTariff creation and subscription lifecycle management

### Phase 4.2: Flutter IAP Client ✅
- **Status**: COMPLETE
- **Files**: `lib/api/iap_manager.dart`, `lib/subscription_screen.dart`, `pubspec.yaml`
- **Details**: [PHASE_4_2_IMPLEMENTATION.md](./PHASE_4_2_IMPLEMENTATION.md)

**Реализовано**:
- ✅ IapManager singleton для управления IAP lifecycle
- ✅ Product queries from App Store/Google Play
- ✅ Purchase handling и receipt transmission
- ✅ SubscriptionScreen UI с list доступных планов и статусом подписки

### Phase 4.3: Subscription UI (In Progress)
- **Status**: PLANNED
- **Focus**: Subscription management, plan upgrades, cancellation

### Phase 4.4: Testing & Deployment (Planned)
- **Status**: TODO
- **Focus**: E2E testing, production deployment, monitoring

---

## Что сделано (Phases 1-3)
- Добавлен централизованный логгер `lib/api/logging.dart` (ApiLogger) для консольного и developer.log логирования.
- ApiClient (`lib/api/api_client.dart`):
  - Валидация входных параметров (path, mapper, params).
  - Retry-механизм для transient ошибок (SocketException, HttpException, TimeoutException и http.ClientException) с экспоненциальной задержкой.
  - Автоматическое обновление токена при получении 401 через callback `onRefreshToken`.
  - Проверка валидности JWT-токена (`isTokenValid`).
  - Обработка пустого/невалидного JSON в теле ответа — mapper получает `null` или raw string.
  - Центральные исключения `ApiException`.
- Unit-тесты: `test/api_client_test.dart` — покрывают get/post, retry, пустое тело и refresh-token логику.
- .gitattributes для унификации окончаний строк (LF и бинарные файлы).
- CI: GitHub Actions workflow для запуска `flutter pub get` и `flutter test`.

## Архитектура и взаимодействие модулей
- lib/api/api_client.dart — лёгкая обёртка над `package:http`.
  - Не хранит токен в безопасном хранилище — предоставляет `setToken` и опциональный `onRefreshToken` callback.
- lib/api/token_storage.dart — абстракция для сохранения токена (на базе flutter_secure_storage). Слой авторизации (VpnService) отвечает за вызовы `TokenStorage`.
- lib/api/vpn_service.dart — использует ApiClient для реализации конкретных API-вызовов (login/register/me и т.д.). При логине сохраняет токен в TokenStorage и вызывает `api.setToken`.

Межъязыковое взаимодействие
- Приложение — Flutter (Dart). Нативные плагины используются через платформенные каналы (например, flutter_secure_storage) и не зависят от ApiClient.
- Архитектура разделяет:
  - сетевой слой (ApiClient),
  - бизнес-логику (VpnService),
  - хранение секретов (TokenStorage).

Это позволяет тестировать сетевой слой независимо, мокая http.Client (используется в тестах MockClient).

## Как использовать ApiClient
Пример инициализации:

```dart
final api = ApiClient(
  baseUrl: 'https://api.example.com',
  onRefreshToken: () async {
    // вызвать refresh у авторизационного сервиса, сохранить новый токен и вернуть его
    return await AuthService.refreshToken();
  },
);

// После логина
api.setToken(token);

// Вызов
final user = await api.get<Map<String, dynamic>>('/auth/me', (json) => json as Map<String, dynamic>);
```

Mapper
- Mapper — функция, которая принимает dynamic (Map/List/null/String) и возвращает доменную модель или примитив.
- ApiClient оборачивает ошибки mapper в ApiException чтобы верхние слои могли корректно реагировать.

## Тесты
Запуск локально:

```
flutter pub get
flutter test
```

В тестах используется `package:http/testing` (MockClient) для контроля ответов и симуляции ошибок.

## CI / CD
Добавлен GitHub Actions workflow в `.github/workflows/ci.yaml`, который запускает:
- setup flutter
- flutter pub get
- flutter analyze
- flutter test

При желании добавить сборку APK/IPA или публикацию — расширьте workflow соответствующими шагами.

## Советы по безопасности
- ApiClient хранит токен только в памяти. Сохраняйте токен в `flutter_secure_storage` (TokenStorage) при логине.
- Не логируйте полный токен — ApiClient логирует маскированную версию.

## Дальнейшие улучшения (необязательно)
- Поддержка refresh токена с использованием refresh-token flow (восстановление через эндпоинт).
- Интеграция с Sentry/Crashlytics для централизованной отправки ошибок.
- Перенос логики retry в отдельный interceptor/плагин.


