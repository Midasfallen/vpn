# Building & Running with Flavors

This app supports three build flavors for different environments:
- **dev** — Local development with debug logging
- **staging** — Test environment with full logging and certificate pinning
- **prod** — Production build with minimal logging

## Running with Flavors

### Development (Local API)
```bash
# Android
flutter run --flavor dev -t lib/main.dart

# iOS
flutter run --flavor dev -t lib/main.dart
```

### Staging (Test Server)
```bash
flutter run --flavor staging -t lib/main.dart
```

### Production
```bash
flutter run --flavor prod -t lib/main.dart
flutter build apk --flavor prod      # Build APK for release
flutter build appbundle --flavor prod # Build App Bundle for Google Play
```

## Configuration Details

### Environment-Specific Settings

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| API Base URL | `http://10.0.2.2:8000` | `https://staging-api.vpn.local:8000` | `https://api.vpn.prod:8000` |
| Debug Logging | ✅ Enabled | ✅ Enabled | ❌ Disabled |
| Certificate Pinning | ❌ Disabled | ✅ Enabled | ✅ Enabled |
| Connection Timeout | 60s | 30s | 30s |

### Android Manifest Changes

Each flavor has its own application ID suffix:
- **dev**: `com.example.vpn.dev`
- **staging**: `com.example.vpn.staging`
- **prod**: `com.example.vpn` (default)

This allows all three variants to be installed simultaneously on one device.

## Modifying Environment Configuration

Edit `lib/config/environment.dart` to:
1. Change API endpoints
2. Enable/disable debug logging
3. Adjust timeout values
4. Configure certificate pinning

All changes affect all build configurations simultaneously.

## Checking Current Environment at Runtime

```dart
import 'package:vpn/config/environment.dart';

// In any widget/service:
print('Current environment: ${Environment.current.name}');
print('API URL: ${Environment.current.apiBaseUrl}');
print('Debug logging: ${Environment.current.enableDebugLogging}');
```

## Next Steps

1. **Update Backend URLs** — Replace placeholder URLs in `environment.dart`
2. **Add Certificate Pinning** — See CERTIFICATE_PINNING.md
3. **Configure Build Signing** — Update Android signing configs for release builds
