# Production Readiness Checklist

## Pre-Launch Requirements

### 1. Version Management

**Update pubspec.yaml:**
```yaml
version: 1.0.0+1  # semantic: MAJOR.MINOR.PATCH+buildNumber
```

**Version Increment Strategy:**
- `MAJOR`: Breaking changes or major feature releases
- `MINOR`: New features, backward compatible
- `PATCH`: Bug fixes
- `buildNumber`: Automatic for each build

**Example:**
- `1.0.0+1` → Initial release
- `1.0.1+2` → Bug fix
- `1.1.0+3` → New feature
- `2.0.0+4` → Breaking changes

### 2. Build Configuration

**Android (android/app/build.gradle.kts):**
```kotlin
android {
    compileSdk = 34  // Latest stable SDK
    
    defaultConfig {
        applicationId = "com.example.vpn"
        minSdk = 21     // Support Android 5.0+
        targetSdk = 34  // Target latest Android
        versionCode = 1
        versionName = "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.release
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**iOS (ios/Runner/Info.plist):**
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
<key>NSMinimumOSVersion</key>
<string>12.0</string>
```

### 3. App Signing

**Android Keystore Setup:**
```bash
# Create keystore (one-time)
keytool -genkey -v -keystore my-release-key.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release-key

# Reference in build.gradle.kts
signingConfigs {
    release {
        storeFile = file("my-release-key.keystore")
        storePassword = System.getenv("KEYSTORE_PASSWORD")
        keyAlias = System.getenv("KEY_ALIAS")
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
```

**Store in GitHub Secrets:**
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

### 4. Security Checks

**Required:**
- [ ] Certificate pinning configured for production
- [ ] API endpoints use HTTPS only
- [ ] No hardcoded credentials in code
- [ ] No debug logging in production
- [ ] Flutter build in release mode
- [ ] Obfuscation enabled (Android)
- [ ] No sensitive data in app logs

**Verify:**
```bash
# Check for hardcoded secrets
grep -r "password\|secret\|token\|api_key" lib/ \
  --include="*.dart" | grep -v "TODO\|FIXME"

# Ensure release build
flutter build apk --flavor prod --release
```

### 5. Performance Optimization

**Image Optimization:**
```bash
# Compress assets
convert image.png -quality 85 image.png
```

**Code Optimization:**
- Enable code shrinking (Android ProGuard)
- Enable resource shrinking (unused resources)
- Use const constructors everywhere
- Lazy-load large images

**Test Performance:**
```bash
flutter build apk --release --analyze-size
```

### 6. Testing Checklist

**Unit Tests:**
- [ ] Run all tests: `flutter test`
- [ ] Check coverage: `flutter test --coverage`
- [ ] Coverage goal: 80%+ overall

**Integration Tests:**
- [ ] Login flow
- [ ] Subscription purchase flow
- [ ] VPN connection
- [ ] Error recovery
- [ ] Offline mode

**Manual Testing:**
- [ ] Test on multiple Android versions (API 21+)
- [ ] Test on iOS 12.0+
- [ ] Test on low-end devices
- [ ] Test on slow networks (3G)
- [ ] Test offline behavior

### 7. Documentation

**Create/Update:**
- [ ] README.md with setup instructions
- [ ] DEPLOYMENT_GUIDE.md with CI/CD pipeline
- [ ] API documentation
- [ ] Architecture overview
- [ ] Troubleshooting guide

### 8. Localization

**Verify All Strings:**
- [ ] en.json: All keys present
- [ ] ru.json: All keys translated
- [ ] No missing translations
- [ ] No hardcoded strings in code

**Test:**
```bash
# Change app locale to test translations
flutter run -d emulator-5554 --locale=ru_RU
```

## Deployment Pipeline

### GitHub Actions CI/CD

**.github/workflows/build.yml:**
```yaml
name: Build & Release
on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Build APK
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: flutter build apk --flavor prod --release
      
      - name: Upload to Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJson: ${{ secrets.PLAY_CONSOLE_JSON }}
          packageName: com.example.vpn
          releaseFiles: 'build/app/outputs/flutter-apk/app-prod-release.apk'
          track: internal  # internal, alpha, beta, production
          whatsNewDir: whats-new
```

### Release Branches

**Version 1.0.0:**
```bash
git checkout -b release/1.0.0
# Update version in pubspec.yaml
# Commit changes
git commit -m "chore: bump version to 1.0.0"
# Tag release
git tag v1.0.0
git push origin release/1.0.0
git push origin v1.0.0
```

### Play Store Submission

1. **Create app on Google Play Console**
   - Create listing
   - Add screenshots & description
   - Set privacy policy URL

2. **Staging Release (Internal Testing)**
   ```bash
   flutter build appbundle --flavor prod --release
   # Upload to Play Console > Testing > Internal
   ```

3. **Beta Release (Early Access)**
   - Invite testers
   - Gather feedback
   - Fix issues

4. **Production Release**
   - Staged rollout: 10% → 25% → 50% → 100%
   - Monitor crash reports
   - Be ready to hotfix

## Production Monitoring

### Error Tracking

**Setup Sentry (recommended):**
```dart
import 'package:sentry/sentry.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://YOUR_DSN@sentry.io/PROJECT_ID';
      options.tracesSampleRate = 0.1; // 10% of requests
      options.enableUserInteractionTracing = true;
    },
    appRunner: () => runApp(const VpnApp()),
  );
}
```

**Capture Errors:**
```dart
try {
  await vpnService.connectVpn();
} catch (e, stackTrace) {
  await Sentry.captureException(
    e,
    stackTrace: stackTrace,
    hint: Hint.withMap({'user_id': userId}),
  );
}
```

### Analytics

**Track Important Events:**
```dart
// User logged in
analytics.logEvent(name: 'login', parameters: {
  'method': 'email',
});

// Subscription purchased
analytics.logEvent(name: 'purchase', parameters: {
  'item_id': tariffId,
  'value': price,
  'currency': 'USD',
});

// VPN connected
analytics.logEvent(name: 'vpn_connected', parameters: {
  'peer_id': peerId,
  'country': 'US',
});
```

### Logging

**Production Logging Levels:**
```dart
// In production, disable debug logs
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

if (!kReleaseMode) {
  ApiLogger.debug('Debug message'); // Only in dev
}

ApiLogger.info('Important event'); // In all builds
ApiLogger.error('Error occurred', e, stackTrace); // In all builds
```

## Post-Launch Monitoring

### Critical Metrics to Watch

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Crash Rate | <0.5% | >1% |
| ANR Rate (Android) | <0.1% | >0.5% |
| 99th Percentile Latency | <2s | >5s |
| API Success Rate | >99.5% | <95% |
| VPN Connection Success | >98% | <95% |

### Feedback Loops

1. **Monitor Play Store Reviews** — Respond to user feedback
2. **Track Bug Reports** — High-priority vs. low-priority
3. **Analyze Crash Reports** — Fix top crashes immediately
4. **Collect Usage Analytics** — Identify unused features
5. **User Surveys** — Quarterly satisfaction checks

## Rollback Procedures

**If Critical Issue Found:**

1. **Immediate Actions:**
   - Pause Play Store release (pause 100% rollout)
   - File incident report
   - Begin debugging

2. **Investigation:**
   - Review recent changes
   - Check error logs/crashes
   - Identify affected users

3. **Fix & Validation:**
   - Implement fix
   - Run full test suite
   - Test on staging environment

4. **Rollback Release:**
   - Option 1: Revert to previous version (fastest)
   - Option 2: Push hotfix version (if pre-release fix needed)

5. **Communication:**
   - Post-mortem with team
   - Document what went wrong
   - Update processes

## Maintenance Schedule

**Daily:**
- Monitor error rate and crashes
- Review critical logs
- Check API health

**Weekly:**
- Review performance metrics
- Analyze user feedback
- Plan hotfixes

**Monthly:**
- Full audit of dependencies
- Security update checks
- Feature usage analysis

**Quarterly:**
- Plan major feature release
- Update version roadmap
- Conduct user surveys

## Sign-Off Checklist

Before submission to Play Store:

- [ ] Version bumped in pubspec.yaml
- [ ] All tests passing with 80%+ coverage
- [ ] Release notes written
- [ ] Screenshots & preview updated
- [ ] Privacy policy reviewed and current
- [ ] Terms of service reviewed
- [ ] Crash rate <0.5% on staging
- [ ] All critical features tested manually
- [ ] Performance baseline established
- [ ] Logging configured for production
- [ ] Error tracking (Sentry) configured
- [ ] Analytics configured
- [ ] CI/CD pipeline verified
- [ ] Deployment runbook created
- [ ] Emergency contact list prepared
- [ ] Monitoring alerts configured

## Resources

- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Store Connect Help](https://help.apple.com/app-store-connect)
- [Flutter Release Build Guide](https://flutter.dev/docs/deployment)
- [Android Security & Privacy](https://developer.android.com/studio/write/permissions)
- [Sentry Documentation](https://docs.sentry.io/platforms/flutter)
