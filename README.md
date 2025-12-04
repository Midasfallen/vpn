# VPN Flutter Project — In-App Purchase Integration & API Client

Полная документация по интеграции In-App Purchase (IAP) для iOS и Android, API client архитектуре и deployment процессу.

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


