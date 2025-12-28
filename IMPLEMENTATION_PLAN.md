# Incamp VPN - Implementation Plan

## 📋 Overview
This document outlines the complete implementation plan for enhancing the Incamp VPN Flutter application based on requirements from Gleb.

---

## ✅ Phase 1: Critical Fixes (COMPLETED)

### 1.1 Subscription End Date Display ✅
**Status**: Implemented
**Files Modified**:
- `lib/screens/home_screen.dart`
- `assets/langs/en.json`
- `assets/langs/ru.json`

**Changes**:
- Added formatted end date display (e.g., "28 Dec 2025")
- Added days remaining counter
- Enhanced subscription card UI with calendar icon
- Added localization keys: `ends_on`, `days_remaining`, `subscription_ends_today`, `subscription_ended`

**Result**: The subscription widget now shows both the end date and remaining days.

---

### 1.2 Splash Screen Improvements ✅
**Status**: Implemented
**Files Modified**:
- `lib/screens/splash_screen.dart`

**Changes**:
- Removed bottom CircularProgressIndicator
- Added smooth fade-in animation
- Added scale animation with bounce effect
- Added glow effect around logo
- Added app name with shadow effect
- Used TickerProviderStateMixin for animation controllers

**Result**: Professional, animated splash screen without intrusive loader.

---

### 1.3 Push Notifications for Subscription Expiry ✅
**Status**: Implemented
**Files Modified**:
- `pubspec.yaml` (added `flutter_local_notifications: ^18.0.1`)
- `lib/api/notification_service.dart` (new file)
- `lib/screens/home_screen.dart`

**Changes**:
- Created NotificationService singleton
- Implemented automatic notification scheduling
- Notifications trigger at:
  - 7 days before expiry
  - 3 days before expiry
  - 1 day before expiry (subscription ends today)
  - On expiry day (subscription ended)
- Integrated with home screen to check subscription status
- Android and iOS support with permission requests

**Result**: Users receive timely notifications about subscription expiry.

---

## 🔄 Phase 2: Authentication & Session (Next Priority)

### 2.1 Persistent Session Storage
**Status**: Partially Implemented
**Current State**:
- TokenStorage already exists using flutter_secure_storage
- Auto-login implemented in `client_instance.dart`
- Session persists across app restarts

**Remaining Work**:
- ✅ No additional work needed - already functional
- Consider adding session expiry handling
- Optional: Add "Remember Me" toggle

**Estimated Effort**: 1-2 hours (optional enhancements)

---

### 2.2 Google Sign-In Integration
**Status**: Planned
**Priority**: High

**Required Dependencies**:
```yaml
google_sign_in: ^6.2.2
```

**Implementation Steps**:

1. **Add dependencies** (pubspec.yaml)
   ```yaml
   google_sign_in: ^6.2.2
   ```

2. **Android Configuration** (android/app/build.gradle)
   - Add OAuth client ID from Google Cloud Console
   - Configure SHA-1 fingerprints

3. **iOS Configuration** (ios/Runner/Info.plist)
   - Add URL schemes
   - Configure OAuth client ID

4. **Create GoogleAuthService** (lib/api/google_auth_service.dart)
   - Implement signInWithGoogle()
   - Handle Google token exchange with backend
   - Map Google user to app user

5. **Backend API Endpoint** (Required)
   - Endpoint: `POST /auth/google`
   - Request: `{ "id_token": "..." }`
   - Response: `{ "access_token": "...", "refresh_token": "..." }`

6. **Update AuthScreen** (lib/screens/auth_screen.dart)
   - Add "Sign in with Google" button
   - Handle Google sign-in flow
   - Show error messages

**Estimated Effort**: 6-8 hours (frontend + backend coordination)

**Blockers**:
- Requires backend endpoint for Google OAuth token verification
- Requires Google Cloud Console project setup

---

### 2.3 Apple Sign-In Integration
**Status**: Planned
**Priority**: High

**Required Dependencies**:
```yaml
sign_in_with_apple: ^6.1.4
```

**Implementation Steps**:

1. **Add dependencies** (pubspec.yaml)
   ```yaml
   sign_in_with_apple: ^6.1.4
   ```

2. **iOS Configuration**
   - Enable "Sign in with Apple" capability in Xcode
   - Configure Apple Developer account
   - Add entitlements

3. **Android Configuration** (optional)
   - Configure web-based Apple Sign-In for Android
   - Add redirect URI

4. **Create AppleAuthService** (lib/api/apple_auth_service.dart)
   - Implement signInWithApple()
   - Handle Apple token exchange with backend
   - Map Apple user to app user

5. **Backend API Endpoint** (Required)
   - Endpoint: `POST /auth/apple`
   - Request: `{ "id_token": "...", "authorization_code": "..." }`
   - Response: `{ "access_token": "...", "refresh_token": "..." }`

6. **Update AuthScreen** (lib/screens/auth_screen.dart)
   - Add "Sign in with Apple" button (iOS only)
   - Handle Apple sign-in flow
   - Show error messages

**Estimated Effort**: 6-8 hours (frontend + backend coordination)

**Blockers**:
- Requires backend endpoint for Apple OAuth token verification
- Requires Apple Developer account with paid membership ($99/year)
- iOS only (Android support is limited)

**Important Notes**:
- Apple Sign-In is REQUIRED for apps offering other third-party sign-in options (per Apple App Store Review Guidelines)
- Must be prominently displayed if Google Sign-In is available

---

## 📊 Phase 3: Server Info & Analytics (Medium Priority)

### 3.1 Server Information Display
**Status**: Planned
**Priority**: Medium

**Features to Add**:
- Server location (country, city)
- Server flag icon
- Connection speed (Mbps)
- Ping/Latency (ms)
- Server load indicator

**Implementation Steps**:

1. **Backend API Enhancement** (Required)
   - Add server metadata endpoint: `GET /vpn_servers/`
   - Response schema:
     ```json
     {
       "id": 1,
       "address": "62.84.98.109:51820",
       "country": "Germany",
       "country_code": "DE",
       "city": "Frankfurt",
       "latitude": 50.1109,
       "longitude": 8.6821,
       "load_percentage": 45,
       "max_speed_mbps": 1000,
       "protocol": "wireguard"
     }
     ```

2. **Add Server Model** (lib/api/models.dart)
   ```dart
   class VpnServerOut {
     final int id;
     final String address;
     final String country;
     final String countryCode;
     final String city;
     final double latitude;
     final double longitude;
     final int loadPercentage;
     final int maxSpeedMbps;
     final String protocol;
     // ...
   }
   ```

3. **Add Dependencies** (pubspec.yaml)
   ```yaml
   country_flags: ^3.0.0  # For country flag icons
   ```

4. **Create Server Info Widget** (lib/widgets/server_info_card.dart)
   - Display country flag
   - Show server location
   - Display ping (requires measurement logic)
   - Show connection speed
   - Add visual indicators

5. **Implement Ping Measurement** (lib/api/network_diagnostics.dart)
   - Use ICMP ping or HTTP head request
   - Measure latency to server
   - Update UI in real-time

6. **Update Home Screen** (lib/screens/home_screen.dart)
   - Add server info card below subscription card
   - Load server data on init
   - Show server selection (if multiple servers available)

**Estimated Effort**: 8-12 hours

**Blockers**:
- Requires backend API for server metadata
- Requires accurate ping measurement implementation

---

### 3.2 Traffic Analytics Screen
**Status**: Planned
**Priority**: Medium

**Features to Add**:
- Total data usage (all-time)
- Daily data usage
- Weekly/Monthly charts
- Upload/Download breakdown
- Data usage by app (advanced)

**Implementation Steps**:

1. **Add Dependencies** (pubspec.yaml)
   ```yaml
   fl_chart: ^0.70.1  # For beautiful charts
   ```

2. **Backend API Enhancement** (Required)
   - Add traffic logging to WireGuard peer
   - Endpoint: `GET /vpn_peers/self/stats`
   - Response schema:
     ```json
     {
       "total_bytes_sent": 1234567890,
       "total_bytes_received": 9876543210,
       "daily_stats": [
         {
           "date": "2025-12-28",
           "bytes_sent": 123456,
           "bytes_received": 654321
         }
       ],
       "last_handshake": "2025-12-28T10:30:00Z"
     }
     ```

3. **Create Traffic Models** (lib/api/models.dart)
   ```dart
   class TrafficStats {
     final int totalBytesSent;
     final int totalBytesReceived;
     final List<DailyTrafficStats> dailyStats;
     final DateTime? lastHandshake;
     // ...
   }
   ```

4. **Create Analytics Screen** (lib/screens/analytics_screen.dart)
   - Total usage summary card
   - Daily usage chart (line chart)
   - Weekly comparison (bar chart)
   - Upload/Download pie chart
   - Time range selector (24h, 7d, 30d, all-time)

5. **Add Navigation** (lib/main.dart)
   - Add route: `/analytics`
   - Add button on home screen

6. **Implement Data Formatting**
   - Convert bytes to KB/MB/GB
   - Format dates for charts
   - Calculate percentages

**Estimated Effort**: 12-16 hours

**Blockers**:
- Requires backend traffic logging implementation
- WireGuard stats collection needs server-side setup
- May require wg-easy API extension

---

### 3.3 Auto-Renewal Planning
**Status**: Planned
**Priority**: Medium

**Implementation Approach**:

Since the app uses in-app purchases (IAP), auto-renewal is typically handled by the platform:

1. **Apple App Store**: Auto-renewable subscriptions
   - Configure subscriptions in App Store Connect
   - Use StoreKit 2 for subscription management
   - Handle subscription states (active, expired, grace period, etc.)

2. **Google Play Store**: Recurring subscriptions
   - Configure subscriptions in Google Play Console
   - Use Google Play Billing Library
   - Handle subscription states

**Required Changes**:

1. **Update IAP Configuration**
   - Create subscription products (not consumable products)
   - Configure auto-renewal periods
   - Set up pricing and trials

2. **Update IapManager** (lib/api/iap_manager.dart)
   - Detect subscription type (auto-renewable vs. one-time)
   - Handle subscription renewal events
   - Sync with backend on renewal

3. **Backend API Enhancement** (Required)
   - Endpoint: `POST /payments/iap_verify`
   - Handle subscription renewal receipts
   - Extend subscription end date automatically

4. **Add Subscription Management UI**
   - Show auto-renewal status
   - Add "Manage Subscription" button (opens App Store/Play Store)
   - Display renewal date
   - Add cancellation warning

**Estimated Effort**: 10-14 hours

**Blockers**:
- Requires App Store Connect and Google Play Console configuration
- Requires testing with real subscriptions (can't test in sandbox easily)

---

## 🔒 Phase 4: DPI Bypass / Obfuscation (Advanced Feature)

### 4.1 AmneziaWG Research Summary

**What is AmneziaWG?**
- Fork of WireGuard-Go with obfuscation capabilities
- Eliminates identifiable network signatures
- Effective in heavily censored regions (Russia, China, Iran)

**Key Obfuscation Techniques**:
1. **Randomized Headers**: Replace fixed headers with randomized ones
2. **Junk Packets**: Add random data between real packets
   - Parameters: Jc (junk count), Jmin/Jmax (size), S1/S2 (sleep intervals)
3. **Protocol Masking**: Mimic QUIC, DNS, SIP protocols
4. **Handshake Obfuscation**: Add pseudorandom prefixes (0-64 bytes)

**Current Development (2025)**:
- AmneziaWG 2.0 in testing
- Version 1.5 allows traffic disguised as UDP protocols

**Important Limitation**:
⚠️ **Cannot use standard WireGuard apps** - Only WG Tunnel and Amnezia VPN support AmneziaWG 1.5/2.0

---

### 4.2 AmneziaWG Integration Plan

**Status**: Planned
**Priority**: Low (Advanced Feature)
**Complexity**: High

**Implementation Challenges**:

1. **No Native Flutter Plugin**
   - `wireguard_flutter` package doesn't support AmneziaWG
   - Would need custom platform channels (Android/iOS native code)

2. **Platform-Specific Implementation Required**
   - **Android**: Integrate AmneziaWG-Android library
   - **iOS**: Integrate AmneziaWG-Apple framework

3. **Server-Side Changes**
   - Must deploy AmneziaWG server (not standard WireGuard)
   - Configure obfuscation parameters
   - Update wg-easy or use Amnezia server

**Recommended Approach**:

### Option A: Full AmneziaWG Integration (Complex)

**Steps**:

1. **Server Setup**
   - Deploy AmneziaWG server alongside/instead of standard WireGuard
   - Configure obfuscation parameters in server config
   - Update backend to generate AmneziaWG configs

2. **Android Native Integration**
   - Create platform channel in Flutter
   - Integrate AmneziaWG-Android library
   - Implement VPN service using AmneziaWG
   - Handle permissions and VPN profile

3. **iOS Native Integration**
   - Create platform channel in Flutter
   - Integrate AmneziaWG-Apple framework
   - Implement Network Extension
   - Handle permissions and VPN profile

4. **Flutter Bridge**
   - Create unified API for both platforms
   - Handle obfuscation config parameters
   - Update VpnManager to support both WireGuard and AmneziaWG

5. **UI Changes**
   - Add "Obfuscation" toggle in settings
   - Display obfuscation status
   - Allow users to choose standard WireGuard or AmneziaWG

**Estimated Effort**: 40-60 hours

**Blockers**:
- Requires deep knowledge of Android/iOS native development
- No existing Flutter plugin
- Requires server-side AmneziaWG deployment
- Testing in restricted network environments

---

### Option B: Hybrid Approach (Recommended)

**Concept**: Use standard WireGuard but add simple obfuscation layer

**Steps**:

1. **Simple Proxy Layer**
   - Add lightweight proxy (e.g., obfs4proxy, stunnel)
   - Wrap WireGuard traffic in TLS or QUIC
   - Deploy proxy on server-side

2. **Server Setup**
   - Keep standard WireGuard server
   - Add obfuscation proxy in front
   - Route traffic: Client → Proxy → WireGuard

3. **Client Changes**
   - Minimal Flutter changes
   - Connect to proxy endpoint instead of direct WireGuard
   - Proxy forwards traffic to WireGuard

4. **UI Changes**
   - Add "Stealth Mode" toggle
   - Switch between direct and proxied connection

**Estimated Effort**: 15-20 hours

**Advantages**:
- No native code required
- Works with existing wireguard_flutter plugin
- Easier to maintain
- Server-side focused

**Disadvantages**:
- Not as effective as true AmneziaWG
- Adds latency
- Proxy could be blocked

---

### Option C: Alternative Obfuscation (Simplest)

**Concept**: Use established tools like Shadowsocks + V2Ray

**Steps**:

1. **Add Shadowsocks Support**
   - Use existing Flutter Shadowsocks plugins
   - Deploy Shadowsocks server
   - Use V2Ray for additional obfuscation

2. **Dual Protocol Support**
   - Keep WireGuard for normal users
   - Add Shadowsocks for censored regions
   - Let users switch protocols

**Estimated Effort**: 10-15 hours

**Advantages**:
- Proven technology
- Wide adoption
- Easier implementation

**Disadvantages**:
- Not WireGuard-based
- Different protocol stack
- May require separate subscription logic

---

### 4.3 Recommendation

**For Production (Short-term)**:
→ **Option B (Hybrid Approach)** or **Option C (Shadowsocks)**

**For Long-term (Advanced)**:
→ **Option A (Full AmneziaWG)** if DPI bypass is critical business requirement

**Decision Factors**:
1. Target market (is DPI bypass essential?)
2. Development resources available
3. Time to market requirements
4. Maintenance complexity tolerance

---

## 📱 Android & iOS Configuration Requirements

### Push Notifications Setup

**Android** (android/app/src/main/AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**iOS** (ios/Runner/Info.plist):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Google Sign-In Setup

**Android** (android/app/build.gradle):
```gradle
dependencies {
    implementation 'com.google.android.gms:play-services-auth:21.2.0'
}
```

**iOS** (ios/Podfile):
```ruby
pod 'GoogleSignIn'
```

### Apple Sign-In Setup

**iOS** (Xcode):
- Enable "Sign in with Apple" capability
- Add entitlement: `com.apple.developer.applesignin`

---

## 🧪 Testing Checklist

### Phase 1 (Completed)
- ✅ Subscription end date displays correctly
- ✅ Days remaining calculation accurate
- ✅ Splash screen animation smooth
- ✅ Notifications trigger at correct times
- ✅ Localization works for EN/RU

### Phase 2 (Pending)
- [ ] Google Sign-In flow works end-to-end
- [ ] Apple Sign-In flow works end-to-end
- [ ] Session persists after app restart
- [ ] OAuth token refresh works correctly

### Phase 3 (Pending)
- [ ] Server info displays correctly
- [ ] Ping measurement accurate
- [ ] Traffic analytics chart renders
- [ ] Data usage calculations correct
- [ ] Auto-renewal updates subscription

### Phase 4 (Pending)
- [ ] Obfuscation toggle works
- [ ] DPI bypass effective in test environment
- [ ] No performance degradation
- [ ] Fallback to standard WireGuard works

---

## 📚 Additional Resources

### AmneziaWG
- [AmneziaWG Documentation](https://docs.amnezia.org/documentation/amnezia-wg/)
- [AmneziaWG GitHub](https://github.com/amnezia-vpn/amneziawg-go)
- [WireGuard DPI Converter](https://github.com/fevid/wireguard-dpi-circumvention-converter)
- [Medium: Bypassing VPN Blocks with AmneziaWG](https://medium.com/@unkownpersonwithnull/bypassing-vpn-blocks-how-to-set-up-amneziawg-to-defeat-deep-packet-inspection-2749ea15005a)

### Flutter Notifications
- [FlutterFire Messaging Docs](https://firebase.flutter.dev/docs/messaging/notifications/)
- [flutter_local_notifications Package](https://pub.dev/packages/flutter_local_notifications)
- [Firebase FCM Flutter Guide 2025](https://medium.com/@AlexCodeX/mastering-push-notifications-in-flutter-a-complete-2025-guide-to-firebase-cloud-messaging-fcm-589e1e16e144)

### OAuth Integration
- [Google Sign-In Flutter](https://pub.dev/packages/google_sign_in)
- [Sign in with Apple Flutter](https://pub.dev/packages/sign_in_with_apple)

---

## 🎯 Next Steps

1. **Review this plan with Gleb** ✅
2. **Commit Phase 1 changes** (next action)
3. **Coordinate with backend team** for Phase 2/3 API endpoints
4. **Set up Google Cloud Console & Apple Developer Account** for OAuth
5. **Begin Phase 2 implementation** (Google/Apple Sign-In)
6. **Deploy server info & analytics APIs**
7. **Evaluate DPI bypass requirement** and choose implementation approach

---

**Document Version**: 1.0
**Last Updated**: 2025-12-28
**Author**: Claude (Sonnet 4.5)
