# VPN Flutter App — AI Coding Agent Instructions

## Architecture Overview

This is a **Flutter VPN client** (Dart) with a layered architecture designed for clean separation of concerns and testability:

- **Presentation Layer** (`lib/main.dart`): Flutter UI — splash screen, auth (flutter_login), home screen with VPN toggle, subscription management. Uses Material3 design.
- **Business Logic Layer** (`lib/api/vpn_service.dart`): VpnService orchestrates API calls (login, register, peer management, tariffs). Handles auth token persistence via TokenStorage.
- **Network Layer** (`lib/api/api_client.dart`): Generic HTTP wrapper with retry logic, JWT token validation, centralized logging, and automatic 401 refresh-token flow.
- **Data Models** (`lib/api/models.dart`): Plain Dart classes (UserOut, VpnPeerOut, TariffOut) with fromJson factories — NO code generation.
- **Cross-cutting Concerns**: TokenStorage (flutter_secure_storage), error mapping (easy_localization), and centralized logging.

**Key Design Decision**: ApiClient stores tokens in-memory only; TokenStorage handles persisted secure storage. This separates transport from state management.

## Critical Developer Workflows

### Running Tests
```bash
flutter pub get
flutter test                    # Run all unit tests
flutter test --coverage         # Generate coverage report (lcov.info)
```

### Building & Running
```bash
flutter run                     # Debug on connected emulator/device
flutter run --release          # Production build
flutter analyze                # Lint checks (configured in analysis_options.yaml)
```

### Local API Setup
The app connects to `http://146.103.99.70:8000` (hardcoded in `client_instance.dart`). For local dev, modify the baseUrl and ensure the backend is running.

### CI/CD Pipeline
GitHub Actions (`.github/workflows/ci.yaml`):
1. Checkout + setup Flutter (stable)
2. `flutter pub get`
3. `flutter analyze`
4. `flutter test --coverage`

## Project-Specific Patterns

### 1. Error Handling via Error Mapper
All exceptions → user-friendly localized messages through `error_mapper.dart`:
- **ApiException** (status 401, 422, 400, etc.) parsed to field-level errors or single message
- **Field Errors**: `parseFieldErrors()` extracts structured errors from FastAPI-style detail arrays (`loc`, `msg`)
- **Translation**: All error strings are `.tr()` localized (assets/langs/{en,ru}.json)

**Example**: If backend returns 422 with `{"detail": [{"loc": ["body", "email"], "msg": "already registered"}]}`, the mapper extracts field="email", translates, and feeds to UI.

### 2. Token Lifecycle & Refresh Flow
1. Login → ApiClient receives token, calls `setToken()`, and persists via TokenStorage.saveToken()
2. Each request includes `Authorization: Bearer <token>` header
3. On 401 → ApiClient calls `onRefreshToken()` callback (defined in `client_instance.dart`)
4. Callback uses refresh_token to call `/auth/refresh`, updates both access_token and refresh_token in TokenStorage
5. Original request retried once with new token
6. If refresh fails → return null and propagate 401 to UI

**Files involved**: `api_client.dart` (retry logic), `client_instance.dart` (refresh handler), `token_storage.dart` (secure persistence)

### 3. Mapper Pattern for JSON Deserialization
ApiClient.get/post use **mapper functions** (dynamic → domain object):
```dart
final users = await api.get<List<UserOut>>(
  '/users/', 
  (json) => (json as List).map((e) => UserOut.fromJson(e as Map)).toList()
);
```
- Mapper receives raw parsed JSON (Map/List/null/String)
- Mapper exceptions wrapped in ApiException
- Empty 204 responses pass `null` to mapper

### 4. Localization with easy_localization
All user-facing strings use `.tr()`:
- Supported locales: `en`, `ru` (fallback: `en`)
- Asset files: `assets/langs/{en,ru}.json`
- Initialized in main() before runApp

**Keys used**: 'invalid_credentials', 'password_min_length', 'email_already_registered', 'network_error', 'server_error', etc.

### 5. VPN Peer Management
- **Creation**: POST `/vpn_peers/self` → returns VpnPeerOut with wgPublicKey, wgIp, wgPrivateKey (once)
- **Discovery**: GET `/vpn_peers/?skip=0&limit=10` → list user's peers
- **Status**: GET `/vpn_peers/{id}/` → returns active flag
- **Config**: GET `/vpn_peers/self/config` → returns wg-quick format (not yet fully implemented)

**Flow in UI**: HomeScreen._toggleVpn() checks for existing peer, creates if needed, fetches info, shows status.

## Testing Strategy

- **Unit Tests** (`test/` directory): Mock http.Client via `package:http/testing.dart`
- **Coverage**: flutter_test + lcov.info in build/
- **Test Patterns**:
  - ApiClient tests: GET/POST, retry behavior, 401 refresh, empty bodies
  - VpnService tests (raw_*_test.dart): Integration with mocked ApiClient
  - Widget tests: UI rendering with flutter_login, localization

**Example**: `api_client_test.dart` mocks responses, simulates network errors, verifies retry count and header updates.

## Multi-platform Considerations

- **Android**: build.gradle.kts (Kotlin), WireGuard integration via `wireguard_flutter` plugin
- **iOS**: Swift (Runner.xcodeproj), same plugin
- **Plugins Used**: flutter_secure_storage (platform-specific secure storage), flutter_login (platform-agnostic auth UI), wireguard_flutter (WireGuard config)

**Platform Channel Communication**: Plugins use method channels; not exposed directly in ApiClient layer. VPN toggle UI calls platform layer separately (currently stubbed).

## External Dependencies & Integration Points

| Package | Purpose | Notes |
|---------|---------|-------|
| `http: ^0.13.6` | HTTP requests | Wrapped by ApiClient |
| `flutter_secure_storage: ^9.0.0` | Token persistence | Platform-specific backends |
| `flutter_login: ^4.0.0` | Login/signup UI | Pre-built widget with easy_localization integration |
| `easy_localization: ^3.0.1` | i18n | Assets in `assets/langs/` |
| `wireguard_flutter: ^0.1.3` | WireGuard integration | Not yet fully wired (VPN toggle is UI stub) |

## Code Style & Conventions

- **Dart Lints**: flutter_lints package (Material3 + standard rules in analysis_options.yaml)
- **Naming**: camelCase for variables/methods, PascalCase for classes
- **Null Safety**: Full null-safety enabled (SDK ^3.8.1)
- **Comments**: Russian in code (matches codebase convention), describe *why* not *what*
- **Logging**: ApiLogger (centralized) logs masked tokens, requests, responses for debugging

## Common Tasks & Code Locations

| Task | File(s) |
|------|---------|
| Add new API endpoint | `vpn_service.dart` (method), `models.dart` (response class) |
| Modify error handling | `error_mapper.dart`, update i18n keys in `assets/langs/` |
| Change auth flow | `client_instance.dart` (onRefreshToken), `vpn_service.dart` (login/register) |
| Add/fix tests | `test/api_client_test.dart` or new test file using MockClient |
| Localization strings | `assets/langs/{en,ru}.json`, reference in code via `.tr()` |
| UI screens | `lib/main.dart` (screens are inlined or moved to separate files) |

## Known Limitations & TODOs

- WireGuard config generation from peer info incomplete (GET /vpn_peers/self/config)
- Password recovery not implemented (server-side missing)
- App selection for VPN bypass (Android) currently a UI stub
- No persistent logging or remote error reporting (Sentry integration suggested in README)
