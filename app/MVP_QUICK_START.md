# 🚀 MVP Implementation Quick Start

**Created:** December 3, 2025  
**Total Estimated Time:** 4-6 weeks (full-time)  
**Total Tasks:** 58 actionable items  
**Documentation:** See `MVP_IMPLEMENTATION_PLAN.md`

---

## 📊 At a Glance

### Phases Overview

| Phase | Focus | Duration | Status |
|-------|-------|----------|--------|
| **1** | Security & Compliance | 1 week | 🔴 CRITICAL |
| **2** | Network Robustness | 1 week | 🟡 HIGH |
| **3** | Localization & Cleanup | 1 week | 🟡 MEDIUM |
| **4** | API Architecture (IAP) | 1 week | 🟡 HIGH |
| **5** | In-App Purchase & Privacy | 1 week | 🟡 HIGH |
| **6** | Testing, Monitoring, Release | 1 week | 🟡 HIGH |

---

## 🔥 START HERE (This Week)

### Tasks to Complete First (Priority Order)

```
TODAY:
□ 1.1 Remove print() & secure logging        (4 hours)
□ 1.3 Delete refresh token on logout         (0.5 hours)

TOMORROW:
□ 1.2 Declare VPN permissions                (2 hours)
□ 1.4 Handle 403 Forbidden status            (1 hour)

END OF WEEK:
□ 2.1 Add connectivity_plus package          (1 hour)
□ 2.2 Configure API timeouts                 (1.5 hours)
□ 2.3 Add offline banner to UI               (1.5 hours)
```

**Time This Week:** ~12 hours (doable in 1-2 days if focused)

---

## 📋 Detailed Phase Breakdown

### PHASE 1: Security & Compliance (CRITICAL - Do First!)

Why: **App will be rejected without these**

#### 1.1 Remove print() - Secure Logging (4 hours)

**Files to Update:**
- `lib/main.dart` - Replace all `print()` with `ApiLogger`
- `lib/api/api_client.dart` - Add data sanitization
- `test/raw_auth_vpn_test.dart` - Remove debug prints
- `lib/tools/smoke_test.dart` - Use logger instead

**Quick Fix Template:**
```dart
// BEFORE ❌
print('Login successful: $res');

// AFTER ✅
ApiLogger.debug('Login successful', {'userId': res['id']});
```

**Action:** Search codebase for `print(` and replace with ApiLogger

---

#### 1.2 VPN Permissions (2 hours)

**Android:** Add to `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.BIND_VPN_SERVICE" />
```

**iOS:** Create/update `ios/Runner/Runner.entitlements`
```xml
<key>com.apple.developer.networking.vpn</key>
<true/>
```

**Checklist:**
- [ ] Android manifest updated
- [ ] iOS entitlements created
- [ ] Compiled successfully on both platforms

---

#### 1.3 Delete Refresh Token (0.5 hours)

**File:** `lib/main.dart` → `HomeScreen._logout()`

**Current:**
```dart
await TokenStorage.deleteToken();
// ❌ Missing: deleteRefreshToken()
```

**Fix:**
```dart
await TokenStorage.deleteToken();
await TokenStorage.deleteRefreshToken(); // ✅ ADD THIS
```

---

#### 1.4 Handle 403 Forbidden (1 hour)

**File:** `lib/api/error_mapper.dart`

**Add:**
```dart
if (status == 403) {
  return 'subscription_required'.tr();
}
```

**Add to localization:**
```json
// assets/langs/en.json
{
  "subscription_required": "Your subscription has expired."
}
```

---

### PHASE 2: Network Robustness (HIGH Priority)

#### 2.1 Add Connectivity Detection (1 hour)

```bash
flutter pub add connectivity_plus
```

**Create:** `lib/services/connectivity_service.dart`
```dart
class ConnectivityService {
  Stream<bool> get connectionStatusStream {
    // Implementation in full plan
  }
}
```

---

#### 2.2 Configure Timeouts (1.5 hours)

**File:** `lib/api/api_client.dart`

Add parameter:
```dart
final Duration requestTimeout = const Duration(seconds: 30);
```

Apply to all requests (get, post, put, delete)

---

#### 2.3 Offline Banner (1.5 hours)

**Create:** `lib/widgets/offline_banner.dart`

**Add to main UI:**
```dart
Column(
  children: [
    OfflineBanner(), // ✅ NEW
    Expanded(child: body),
  ],
)
```

---

### PHASE 3: Localization (MEDIUM Priority)

#### 3.1 Create Constants (0.5 hours)

**Create:** `lib/constants/app_strings.dart`

```dart
class AppStrings {
  static const passwordLabel = 'password_label';
  static const vpnConnected = 'vpn_connected';
  // ... all string keys
}
```

---

#### 3.2-3.4 Localize UI (2.5 hours)

Replace all hardcoded strings:
```dart
// ❌ BEFORE
Text('Пароль')

// ✅ AFTER
Text(AppStrings.passwordLabel.tr())
```

**Update language files:** `assets/langs/{en,ru}.json`

---

### PHASE 4-5: In-App Purchase & Backend

**Note:** Requires backend API changes. Coordinate with backend team.

#### Backend Requirements:
- [ ] `POST /subscriptions/verify-receipt` - Validate receipts
- [ ] `GET /subscriptions/me` - Get user subscription status
- [ ] Database: Add `subscriptions` table
- [ ] Google Play / App Store API integration

**Frontend:**
- [ ] Add `in_app_purchase` package
- [ ] Create `PurchaseService`
- [ ] Create `SubscriptionOut` model
- [ ] Integrate into `SubscriptionScreen`

---

### PHASE 6: Privacy & Compliance

#### Documents Needed:
1. **Privacy Policy** (publish on website)
2. **Terms of Service** (publish on website)
3. **Privacy Agreement Screen** (in-app)

**Quick Template:**
```markdown
# Privacy Policy

## Information We Collect
- Email (for auth)
- VPN connection logs (temporary)

## How We Use It
- Authentication
- Service delivery
- Analytics (aggregated, anonymous)

## Your Rights
- Access
- Deletion
- Portability (GDPR/CCPA)
```

---

### PHASE 7: Testing

**Minimum Coverage Target: 80%**

#### Test Types:
1. **Unit Tests** (auth, error mapping, token storage)
2. **Widget Tests** (screens, buttons, navigation)
3. **Integration Tests** (full auth → purchase flow)

**Quick Test Template:**
```dart
test('login failure returns error message', () async {
  when(mockService.login(any, any))
      .thenThrow(ApiException(401, 'Unauthorized'));
  
  final result = await _authUser(LoginData(...));
  expect(result, isNotEmpty);
});
```

---

### PHASE 8: Firebase & Monitoring

#### Setup:
1. Create Firebase project
2. Download `google-services.json` (Android)
3. Download `GoogleService-Info.plist` (iOS)
4. Add to project directories

#### Integration:
```dart
await Firebase.initializeApp();
FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
```

---

### PHASE 9: CI/CD

**GitHub Actions Workflow:**
- [ ] Lint check (`flutter analyze`)
- [ ] Format check (`dart format`)
- [ ] Unit tests (`flutter test --coverage`)
- [ ] Code coverage tracking (codecov)
- [ ] Build APK/IPA (on main branch)

---

### PHASE 10: Release Preparation

#### App Store Requirements:

**Android (Google Play):**
- [ ] App title, description, screenshots
- [ ] Privacy Policy URL
- [ ] Contact email
- [ ] Comply with VPN policy
- [ ] Target Android 14+

**iOS (App Store Connect):**
- [ ] App name, description, screenshots
- [ ] Privacy Policy URL
- [ ] Request VPN capability
- [ ] Provide privacy details in App Store

**Both Platforms:**
- [ ] High-quality icons (1024x1024)
- [ ] 5+ screenshots per platform
- [ ] Accurate content rating
- [ ] No false claims

---

## 🎯 Day-by-Day Execution Plan

### Week 1: Security Foundation

**Monday:**
- [ ] Remove all print() - use ApiLogger (3h)
- [ ] Add TokenStorage.deleteRefreshToken() (0.5h)

**Tuesday:**
- [ ] Declare VPN permissions (2h)
- [ ] Handle 403 status code (1h)

**Wednesday-Friday:**
- [ ] Test changes across Android & iOS (2h)
- [ ] Buffer for issues & iterations (3h)

**Total: 11.5 hours**

---

### Week 2: Network Robustness

**Monday:**
- [ ] Add connectivity_plus (1h)
- [ ] Create ConnectivityService (1h)

**Tuesday:**
- [ ] Configure API timeouts (1.5h)
- [ ] Add offline banner to UI (1h)

**Wednesday-Friday:**
- [ ] Test offline mode (2h)
- [ ] Fine-tune error messages (2h)

**Total: 8.5 hours**

---

### Week 3: Localization

**Monday-Wednesday:**
- [ ] Create AppStrings constants (1h)
- [ ] Localize PasswordField (1h)
- [ ] Localize all screens (3h)

**Thursday-Friday:**
- [ ] Clean up logging (1h)
- [ ] Fix SplashScreen navigation (0.5h)
- [ ] Testing & QA (2h)

**Total: 8.5 hours**

---

### Week 4: Backend API for IAP

**Coordinate with Backend Team:**
- [ ] Design receipt verification endpoint
- [ ] Design subscription status endpoint
- [ ] Database schema for subscriptions

**Frontend Meanwhile:**
- [ ] Design SubscriptionOut model
- [ ] Plan PurchaseService architecture
- [ ] Plan backend integration points

**Total: 10-15 hours (depends on backend)**

---

### Week 5: IAP Integration & Privacy

**Monday-Wednesday:**
- [ ] Implement PurchaseService (3h)
- [ ] Integrate into SubscriptionScreen (2h)
- [ ] Handle pending purchases (1h)

**Thursday-Friday:**
- [ ] Write Privacy Policy (2h)
- [ ] Add privacy agreement screen (1h)
- [ ] Backend integration testing (2h)

**Total: 11 hours**

---

### Week 6: Testing & Release

**Monday-Tuesday:**
- [ ] Unit tests (10h)

**Wednesday:**
- [ ] Widget tests (8h)

**Thursday:**
- [ ] Firebase setup (3h)
- [ ] CI/CD pipeline (3h)

**Friday:**
- [ ] Release assets & store listing (5h)
- [ ] Final QA & bug fixes (5h)

**Total: 34 hours**

---

## ✅ Pre-Submission Checklist

Before submitting to app stores:

### Code Quality
- [ ] All tests passing
- [ ] Coverage >80%
- [ ] No lint warnings
- [ ] `flutter analyze` clean
- [ ] `dart format` applied

### Security
- [ ] No hardcoded tokens/secrets
- [ ] No print() of sensitive data
- [ ] TLS enabled for all requests
- [ ] Secure token storage verified

### Functionality
- [ ] Auth flow works (register → login → logout)
- [ ] VPN toggle works or is properly stubbed
- [ ] Purchase flow works end-to-end
- [ ] Offline banner shows correctly
- [ ] Error messages are localized

### Compliance
- [ ] Privacy Policy published
- [ ] Terms of Service published
- [ ] VPN permissions declared
- [ ] Privacy agreement in signup
- [ ] App Icons created
- [ ] Screenshots prepared

### Testing
- [ ] Tested on Android 10, 12, 14
- [ ] Tested on iOS 15, 16, 17
- [ ] Network error handling works
- [ ] Timeout handling works
- [ ] Logout clears all tokens

---

## 🐛 Common Pitfalls to Avoid

1. **Forgetting to delete refresh_token on logout** → Security issue
2. **Not handling 403 status** → Poor UX for expired subscriptions
3. **Hardcoded strings in Russian** → App store rejection (localization required)
4. **No Privacy Policy link** → Cannot publish
5. **print() statements leaking tokens** → Security audit failure
6. **Testing only on simulator** → VPN won't work (use real device)
7. **Not validating receipts server-side** → Easy to bypass payments

---

## 📞 Quick Reference

### Critical Files to Update
- `lib/main.dart` - UI, remove print(), add offline banner
- `lib/api/api_client.dart` - Timeouts, error handling
- `lib/api/error_mapper.dart` - 403 handling, graceful errors
- `lib/api/vpn_service.dart` - New subscription methods
- `pubspec.yaml` - New packages (connectivity_plus, in_app_purchase, firebase_*)

### New Files to Create
- `lib/services/connectivity_service.dart`
- `lib/api/purchase_service.dart`
- `lib/constants/app_strings.dart`
- `lib/firebase_init.dart`
- `privacy_policy.md`
- `terms_of_service.md`

### Configuration Files
- `android/app/src/main/AndroidManifest.xml` - VPN permissions
- `ios/Runner/Runner.entitlements` - VPN capability
- `.github/workflows/ci.yaml` - CI/CD pipeline

---

## 💡 Pro Tips

1. **Start with Phase 1 immediately** - These are blocking issues
2. **Parallelize where possible** - Backend can work on IAP while frontend does testing
3. **Test early and often** - Don't wait until the end
4. **Use git branches** - Create feature branches for each phase
5. **Document as you go** - Keep README updated
6. **Get feedback from users** - TestFlight beta before launch
7. **Monitor after launch** - Set up alerts for crashes and errors

---

## 📞 Support

- **Copilot Instructions:** See `.github/copilot-instructions.md`
- **Full Implementation Plan:** See `MVP_IMPLEMENTATION_PLAN.md`
- **API Documentation:** See README.md (to be created)

---

**Next Step:** Start with Phase 1, Task 1.1 (Remove print() & secure logging)

**Estimated Time to First Store Submission:** 4-6 weeks
