# Testing Guide

## Overview

The VPN app includes comprehensive unit tests for:
- **VpnManager**: WireGuard lifecycle management
- **ApiClient**: HTTP retry logic and JWT token handling
- **ErrorMapper**: API error parsing and localization
- **Network Layer**: Certificate pinning validation

## Running Tests

### Run All Tests
```bash
flutter pub get
flutter test
```

### Run Specific Test File
```bash
flutter test test/vpn_manager_test.dart
flutter test test/api_client_retry_test.dart
flutter test test/error_mapper_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
# Report saved to coverage/lcov.info
```

### Run Tests in Watch Mode
```bash
flutter test --watch
```

## Test Structure

### VpnManager Tests (`test/vpn_manager_test.dart`)

**Coverage:**
- ✅ Successful VPN connection with valid peer ID
- ✅ Connection failure handling
- ✅ Configuration storage
- ✅ VPN disconnection
- ✅ Status checking
- ✅ Resource cleanup
- ✅ Error handling for malformed configs

**Example:**
```dart
test('successfully connects to VPN with valid peer ID', () async {
  const peerId = 123;
  final mockConfig = '[Interface]\nPrivateKey = test_key\n...';
  
  when(mockVpnService.fetchWgQuick(peerId))
    .thenAnswer((_) async => mockConfig);
  
  final result = await vpnManager.connect(peerId);
  expect(result, isTrue);
});
```

### ApiClient Tests (`test/api_client_retry_test.dart`)

**Coverage:**
- ✅ Retry on 5xx errors (500, 503)
- ✅ No retry on 4xx errors (400, 401, 422)
- ✅ JWT token injection in headers
- ✅ Token update handling
- ✅ Empty 204 responses
- ✅ Malformed JSON handling
- ✅ Max retry limit enforcement

**Example:**
```dart
test('retries request on 500 Internal Server Error', () async {
  int callCount = 0;
  final client = MockClient((request) async {
    callCount++;
    if (callCount == 1) {
      return http.Response('Server error', 500);
    } else {
      return http.Response('{"success": true}', 200);
    }
  });
  
  final result = await apiClient.get('/test', ...);
  expect(callCount, 2); // Should have retried
});
```

### ErrorMapper Tests (`test/error_mapper_test.dart`)

**Coverage:**
- ✅ 401 Unauthorized mapping
- ✅ 422 Validation error parsing
- ✅ 500+ Server error handling
- ✅ Field-level error extraction
- ✅ FastAPI detail array parsing
- ✅ Null safety
- ✅ I18n key mapping

**Example:**
```dart
test('extracts field-level errors from FastAPI detail array', () {
  final detail = [
    {
      'loc': ['body', 'email'],
      'msg': 'already registered'
    }
  ];
  
  final errors = ErrorMapper.parseFieldErrors(detail);
  expect(errors, containsPair('email', 'already registered'));
});
```

## Adding New Tests

### Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn/[module]/[class].dart';

void main() {
  group('[ClassName]', () {
    late [ClassName] instance;

    setUp(() {
      instance = [ClassName](...);
    });

    test('describes what should happen', () async {
      // Arrange
      final input = ...;

      // Act
      final result = await instance.method(input);

      // Assert
      expect(result, expectedValue);
    });
  });
}
```

### Test Naming Convention

- **Method being tested**: `connect()`, `disconnect()`, `parse()`
- **Input condition**: `withValidToken`, `onNetworkError`, `withNullResponse`
- **Expected behavior**: `returnsSuccess`, `throwsException`, `logsError`

**Examples:**
- ✅ `connect_withValidPeerId_returnsTrue()`
- ✅ `retry_onServerError_attemptsAgain()`
- ✅ `parseFieldErrors_withEmptyArray_returnsEmpty()`

## Mocking & Test Doubles

### Using Mockito

```dart
import 'package:mockito/mockito.dart';

class MockVpnService extends Mock implements VpnService {}

// In test
when(mockVpnService.fetchWgQuick(123))
  .thenAnswer((_) async => 'config');
```

### Using http/testing

```dart
import 'package:http/testing.dart';

final client = MockClient((request) async {
  return http.Response('{"data": "ok"}', 200);
});
```

## Coverage Goals

| Component | Target | Status |
|---|---|---|
| VpnManager | 90%+ | ✅ In Progress |
| ApiClient | 85%+ | ✅ In Progress |
| ErrorMapper | 95%+ | ✅ In Progress |
| Models | 80%+ | 📋 Pending |
| VpnService | 80%+ | 📋 Pending |

## CI/CD Integration

GitHub Actions runs tests automatically:

```yaml
- name: Run tests
  run: flutter test --coverage

- name: Upload coverage
  run: |
    flutter pub global activate coverage
    genhtml coverage/lcov.info -o coverage/html
```

## Troubleshooting

### Tests Timeout

**Cause**: Async operations not completing  
**Solution**: Add timeout to test:
```dart
test('my test', () async {
  // test code
}, timeout: Timeout(Duration(seconds: 10)));
```

### MockClient Returns Wrong Status

**Cause**: Multiple clients in test  
**Solution**: Create fresh client for each test:
```dart
setUp(() {
  final client = MockClient(handler);
  apiClient = ApiClient(..., client: client);
});
```

### Import Errors

**Cause**: mockito not in pubspec.yaml  
**Solution**: Add dev dependencies:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.3.1
```

## Next Steps

1. **Run existing tests**: `flutter test`
2. **Add widget tests**: UI component rendering
3. **Integration tests**: Full app flows
4. **Performance tests**: Connection speed, battery drain

## Resources

- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [http/testing Package](https://pub.dev/packages/http#testing)
