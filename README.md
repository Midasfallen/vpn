# vpn

Подробная информация по проекту Flutter "vpn".

## Краткое описание
vpn — Flutter-приложение с приоритетной поддержкой Android. В проекте заложена структура для кроссплатформенной сборки (iOS, Windows, macOS, Linux, Web), но в настоящий момент основная рабочая версия — Android.

## Структура проекта (важные файлы и папки)
- lib/ — основной код приложения.
  - Главный файл приложения: [`VpnApp`](lib/main.dart) и точка входа [`main`](lib/main.dart) — [lib/main.dart](lib/main.dart).
  - UI и логика находятся в [lib/main.dart](lib/main.dart) (есть экраны входа, регистрации, подписки и основной экран с кнопкой VPN).
- android/ — Android-проект.
  - Основная активность: [`MainActivity`](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt) — [android/app/src/main/kotlin/com/example/vpn/MainActivity.kt](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt).
  - Конфигурация сборки: [android/app/build.gradle.kts](android/app/build.gradle.kts).
- ios/ — проект iOS (шаблон Xcode).
  - Основной Info.plist: [ios/Runner/Info.plist](ios/Runner/Info.plist).
  - Xcode-проекты и конфигурации находятся в ios/Runner.xcodeproj.
- windows/, linux/, macos/ — шаблоны для десктопов.
  - Windows: конфигурация CMake — [windows/CMakeLists.txt](windows/CMakeLists.txt) и раннер — [windows/runner/main.cpp](windows/runner/main.cpp).
  - Linux: [linux/CMakeLists.txt](linux/CMakeLists.txt).
  - macOS: Xcode-проект в macos/.
- web/ — веб-ресурсы:
  - Точка входа: [web/index.html](web/index.html) и [web/manifest.json](web/manifest.json).
- pubspec.yaml — зависимости, версия приложения и метаданные — [pubspec.yaml](pubspec.yaml).

## Как запустить (локально)
1. Установить Flutter SDK и настроить окружение.
2. В корне проекта выполнить (Android-устройство или эмулятор):
   - Проверка: flutter doctor
   - Запуск: flutter run -d <device-id>
3. Сборка релизной APK:
   - flutter build apk --release
4. Запуск на других платформах:
   - iOS: требуется Xcode; собрать из каталога ios (учесть bundle identifier в [ios/Runner/Info.plist](ios/Runner/Info.plist)).
   - Windows/Linux/macOS: доступны CMake-конфигурации в соответствующих папках ([windows/CMakeLists.txt](windows/CMakeLists.txt), [linux/CMakeLists.txt](linux/CMakeLists.txt)).

## Где править что
- Логика и UI: [lib/main.dart](lib/main.dart) — здесь расположены основные виджеты, состояние VPN, экран подписки и диалоги выбора приложений.
- Метаданные приложения:
  - Версия и номер сборки: [pubspec.yaml](pubspec.yaml).
  - Android: [android/app/build.gradle.kts](android/app/build.gradle.kts) (applicationId, minSdk, targetSdk, versionCode/name).
  - iOS: [ios/Runner/Info.plist](ios/Runner/Info.plist) и настройки Xcode.
- Платформенные расширения и плагины:
  - Генерация и подключение плагинов для Windows: [windows/flutter/CMakeLists.txt](windows/flutter/CMakeLists.txt) и [windows/runner/CMakeLists.txt](windows/runner/CMakeLists.txt).
  - Регистрация плагинов во время сборки — см. include flutter/generated_plugins.cmake в CMake-файлах.

## Замечания по коду
- В UI есть заглушки и TODO:
  - Регистрация: в [lib/main.dart](lib/main.dart) отмечена TODO для реализации регистрации.
  - Apple Sign-In: пометка TODO в соответствующей кнопке в [lib/main.dart](lib/main.dart).
- Локализация: интерфейс частично на русском — при необходимости вынести в l10n.
- Подписки/платежи: реализовано отображение триала и подписки в UI, но реальная интеграция платежей/серверной логики отсутствует.

## Рекомендации по развитию
- Реализовать бэкенд (планируется на FastAPI) и API для управления подписками и распределения серверов.
- Добавить обработку состояния VPN на уровне платформ (Android VpnService и соответствующие native-модули).
- Настроить CI/CD (сборка релизов Android и тесты UI).
- Добавить локализацию и разделение конфигураций для production/dev.

## Полезные ссылки в проекте
- Главный код: [`VpnApp`](lib/main.dart) — [lib/main.dart](lib/main.dart)
- Точка входа Android: [`MainActivity`](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt) — [android/app/src/main/kotlin/com/example/vpn/MainActivity.kt](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt)
- Сборки: [android/app/build.gradle.kts](android/app/build.gradle.kts), [pubspec.yaml](pubspec.yaml)
- iOS: [ios/Runner/Info.plist](ios/Runner/Info.plist)
- Десктоп: [windows/CMakeLists.txt](windows/CMakeLists.txt), [linux/CMakeLists.txt](linux/CMakeLists.txt)
- Веб: [web/index.html](web/index.html)

Если требуется, можно подготовить:
- Конкретную инструкцию по сборке и выпуску APK/AAB.
- План миграции кода в модули и выделения бизнес-логики.
- Примеры интеграции native VPN на Android.

## Backend API (интеграция)

Проект может взаимодействовать с бэкендом, доступным по адресу http://146.103.99.70:8000/ — он предоставляет OpenAPI спецификацию (Swagger) по /docs и /openapi.json.

Ключевые моменты API:
- Аутентификация: OAuth2 password flow (security scheme `OAuth2PasswordBearer`, tokenUrl: `/auth/login`). После получения токена его следует передавать в заголовке Authorization: Bearer <token>.
- Пользователи: `/auth/register` (POST), `/auth/login` (POST), `/auth/me` (GET).
- Тарифы: `/tariffs/` (GET, POST), `/tariffs/{tariff_id}` (DELETE).
- VPN peers: `/vpn_peers/` (GET, POST), `/vpn_peers/{peer_id}` (GET, PUT, DELETE).
- Платежи: `/payments/` (GET, POST), `/payments/{payment_id}` (GET, PUT, DELETE).

Модели (частично):
- UserCreate, UserLogin, UserOut
- TariffCreate, TariffOut
- VpnPeerCreate, VpnPeerOut
- PaymentCreate, PaymentOut

Быстрый пример использования (файлы в проекте: `lib/api/api_client.dart`, `lib/api/models.dart`, `lib/api/vpn_service.dart`):

1) Инициализация клиента:

```dart
final api = ApiClient(baseUrl: 'http://146.103.99.70:8000');
final vpnService = VpnService(api: api);
```

2) Логин и получение текущего пользователя:

```dart
final token = await vpnService.login('user@example.com', 'password');
final me = await vpnService.me();
print('Logged in user: ${me.email}');
```

3) Получение списка тарифов / peers:

```dart
final tariffs = await vpnService.listTariffs();
final peers = await vpnService.listPeers(userId: me.id);
```

Замечания:
- Клиент в `lib/api` — минимальный лёгковесный обёртка над HTTP и ручной сериализацией. Можно безопасно расширить её (обработка ошибок, рефреш токена, retry, таймауты).
- Для production рекомендуется добавить безопасное хранение токена (secure_storage), обработку ошибок и unit-тесты для сервиса.

```// filepath: c:\Users\ravin\OneDrive\Рабочий стол\vpn\README.md
# vpn

Подробная информация по проекту Flutter "vpn".

## Краткое описание
vpn — Flutter-приложение с приоритетной поддержкой Android. В проекте заложена структура для кроссплатформенной сборки (iOS, Windows, macOS, Linux, Web), но в настоящий момент основная рабочая версия — Android.

## Структура проекта (важные файлы и папки)
- lib/ — основной код приложения.
  - Главный файл приложения: [`VpnApp`](lib/main.dart) и точка входа [`main`](lib/main.dart) — [lib/main.dart](lib/main.dart).
  - UI и логика находятся в [lib/main.dart](lib/main.dart) (есть экраны входа, регистрации, подписки и основной экран с кнопкой VPN).
- android/ — Android-проект.
  - Основная активность: [`MainActivity`](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt) — [android/app/src/main/kotlin/com/example/vpn/MainActivity.kt](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt).
  - Конфигурация сборки: [android/app/build.gradle.kts](android/app/build.gradle.kts).
- ios/ — проект iOS (шаблон Xcode).
  - Основной Info.plist: [ios/Runner/Info.plist](ios/Runner/Info.plist).
  - Xcode-проекты и конфигурации находятся в ios/Runner.xcodeproj.
- windows/, linux/, macos/ — шаблоны для десктопов.
  - Windows: конфигурация CMake — [windows/CMakeLists.txt](windows/CMakeLists.txt) и раннер — [windows/runner/main.cpp](windows/runner/main.cpp).
  - Linux: [linux/CMakeLists.txt](linux/CMakeLists.txt).
  - macOS: Xcode-проект в macos/.
- web/ — веб-ресурсы:
  - Точка входа: [web/index.html](web/index.html) и [web/manifest.json](web/manifest.json).
- pubspec.yaml — зависимости, версия приложения и метаданные — [pubspec.yaml](pubspec.yaml).

## Как запустить (локально)
1. Установить Flutter SDK и настроить окружение.
2. В корне проекта выполнить (Android-устройство или эмулятор):
   - Проверка: flutter doctor
   - Запуск: flutter run -d <device-id>
3. Сборка релизной APK:
   - flutter build apk --release
4. Запуск на других платформах:
   - iOS: требуется Xcode; собрать из каталога ios (учесть bundle identifier в [ios/Runner/Info.plist](ios/Runner/Info.plist)).
   - Windows/Linux/macOS: доступны CMake-конфигурации в соответствующих папках ([windows/CMakeLists.txt](windows/CMakeLists.txt), [linux/CMakeLists.txt](linux/CMakeLists.txt)).

## Где править что
- Логика и UI: [lib/main.dart](lib/main.dart) — здесь расположены основные виджеты, состояние VPN, экран подписки и диалоги выбора приложений.
- Метаданные приложения:
  - Версия и номер сборки: [pubspec.yaml](pubspec.yaml).
  - Android: [android/app/build.gradle.kts](android/app/build.gradle.kts) (applicationId, minSdk, targetSdk, versionCode/name).
  - iOS: [ios/Runner/Info.plist](ios/Runner/Info.plist) и настройки Xcode.
- Платформенные расширения и плагины:
  - Генерация и подключение плагинов для Windows: [windows/flutter/CMakeLists.txt](windows/flutter/CMakeLists.txt) и [windows/runner/CMakeLists.txt](windows/runner/CMakeLists.txt).
  - Регистрация плагинов во время сборки — см. include flutter/generated_plugins.cmake в CMake-файлах.

## Замечания по коду
- В UI есть заглушки и TODO:
  - Регистрация: в [lib/main.dart](lib/main.dart) отмечена TODO для реализации регистрации.
  - Apple Sign-In: пометка TODO в соответствующей кнопке в [lib/main.dart](lib/main.dart).
- Локализация: интерфейс частично на русском — при необходимости вынести в l10n.
- Подписки/платежи: реализовано отображение триала и подписки в UI, но реальная интеграция платежей/серверной логики отсутствует.

## Рекомендации по развитию
- Реализовать бэкенд (планируется на FastAPI) и API для управления подписками и распределения серверов.
- Добавить обработку состояния VPN на уровне платформ (Android VpnService и соответствующие native-модули).
- Настроить CI/CD (сборка релизов Android и тесты UI).
- Добавить локализацию и разделение конфигураций для production/dev.

## Полезные ссылки в проекте
- Главный код: [`VpnApp`](lib/main.dart) — [lib/main.dart](lib/main.dart)
- Точка входа Android: [`MainActivity`](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt) — [android/app/src/main/kotlin/com/example/vpn/MainActivity.kt](android/app/src/main/kotlin/com/example/vpn/MainActivity.kt)
- Сборки: [android/app/build.gradle.kts](android/app/build.gradle.kts), [pubspec.yaml](pubspec.yaml)
- iOS: [ios/Runner/Info.plist](ios/Runner/Info.plist)
- Десктоп: [windows/CMakeLists.txt](windows/CMakeLists.txt), [linux/CMakeLists.txt](linux/CMakeLists.txt)
- Веб: [web/index.html](web/index.html)

Если требуется, можно подготовить:
- Конкретную инструкцию по сборке и выпуску APK/AAB.
- План миграции кода в модули и выделения бизнес-логики.
- Примеры интеграции native VPN на Android.
