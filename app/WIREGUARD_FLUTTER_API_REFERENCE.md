# WireGuard Flutter Plugin API Reference v0.1.3

## Location in Project
Package installed at: `C:\Users\ravin\AppData\Local\Pub\Cache\hosted\pub.dev\wireguard_flutter-0.1.3`
Symlinked in workspace: `c:\vpn\windows\flutter\ephemeral\.plugin_symlinks\wireguard_flutter\`

## 📋 WireGuardFlutter Class - Complete API

### Singleton Access Pattern
```dart
import 'package:wireguard_flutter/wireguard_flutter.dart';

final wireguard = WireGuardFlutter.instance;
```

### Available Methods

#### 1. `initialize({required String interfaceName})` → `Future<void>`
**Purpose**: Initialize WireGuard tunnel with a name

**Parameters**:
- `interfaceName` (String): The name of the WireGuard interface (e.g., `'my_wg_vpn'`)

**Platform Implementation**:
- **Android/iOS**: Passes `interfaceName` as `localizedDescription` to native layer
- **Windows/Linux**: Uses as service name and localized description

**Example**:
```dart
await wireguard.initialize(interfaceName: 'my_vpn');
```

**Error Handling**: Throws exception if initialization fails on native side

---

#### 2. `startVpn({required String serverAddress, required String wgQuickConfig, required String providerBundleIdentifier})` → `Future<void>`
**Purpose**: Start the VPN connection with WireGuard configuration

**Parameters**:
- `serverAddress` (String): VPN server endpoint (format: `IP:PORT`, e.g., `'167.235.55.239:51820'`)
- `wgQuickConfig` (String): Complete wg-quick configuration file content (multi-line string)
- `providerBundleIdentifier` (String): Platform-specific identifier:
  - **iOS**: Bundle ID of VPN extension (e.g., `'com.billion.wireguardvpn.WGExtension'`)
  - **Android**: Can be any identifier, often app package name
  - **Windows/Linux**: Not used, can be empty or app ID

**Example**:
```dart
const wgConfig = '''[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.8.0.4/32
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 167.235.55.239:51820
PersistentKeepalive = 0''';

await wireguard.startVpn(
  serverAddress: '167.235.55.239:51820',
  wgQuickConfig: wgConfig,
  providerBundleIdentifier: 'com.example.app.WGExtension',
);
```

**Error Handling**: Throws exception on connection failure

---

#### 3. `stopVpn()` → `Future<void>`
**Purpose**: Stop the active VPN connection and disconnect

**Parameters**: None

**Example**:
```dart
await wireguard.stopVpn();
```

**Error Handling**: Throws exception if disconnection fails

---

#### 4. `refreshStage()` → `Future<void>`
**Purpose**: Force refresh of current VPN stage/status

**Parameters**: None

**Example**:
```dart
await wireguard.refreshStage();
```

**Note**: Usually called before reading stage if you need immediate state update

---

#### 5. `stage()` → `Future<VpnStage>`
**Purpose**: Get current VPN connection stage synchronously

**Returns**: `VpnStage` enum value (see enum reference below)

**Example**:
```dart
final stage = await wireguard.stage();
if (stage == VpnStage.connected) {
  print('VPN is connected');
}
```

**Error Handling**: Returns `VpnStage.disconnected` if stage cannot be determined

---

#### 6. `isConnected()` → `Future<bool>` (Provided by Abstract Class)
**Purpose**: Check if VPN is currently connected

**Returns**: `true` if stage == VpnStage.connected, else `false`

**Example**:
```dart
final isConnected = await wireguard.isConnected();
```

---

#### 7. `vpnStageSnapshot` → `Stream<VpnStage>` (Property)
**Purpose**: Real-time stream of VPN stage changes

**Returns**: Broadcast stream emitting VpnStage updates whenever connection state changes

**Example**:
```dart
wireguard.vpnStageSnapshot.listen((stage) {
  print('VPN Stage Changed: $stage');
  switch(stage) {
    case VpnStage.connected:
      print('Connected!');
      break;
    case VpnStage.connecting:
      print('Connecting...');
      break;
    case VpnStage.disconnected:
      print('Disconnected');
      break;
    default:
      print('Other state: $stage');
  }
});
```

**Note**: Should be listened to in `initState()` or similar lifecycle method

---

## 🔄 VpnStage Enum - All Values

```dart
enum VpnStage {
  connected('connected'),          // ✅ VPN is active and connected
  connecting('connecting'),        // ⏳ Connection in progress
  disconnecting('disconnecting'),  // ⏳ Disconnection in progress
  disconnected('disconnected'),    // ⛔ VPN is disconnected
  waitingConnection('wait_connection'),  // ⏳ Waiting for connection
  authenticating('authenticating'),      // 🔐 Authenticating
  reconnect('reconnect'),          // 🔄 Reconnecting
  noConnection('no_connection'),   // ❌ No network connection
  preparing('prepare'),            // 🛠️ Preparing VPN
  denied('denied'),                // 🚫 Connection denied
  exiting('exiting');              // 🚪 VPN is exiting

  final String code;
  const VpnStage(this.code);
}
```

---

## ⚠️ Important Implementation Notes

### 1. **Always Call `initialize()` Before `startVpn()`**
The plugin requires initialization before starting:
```dart
await wireguard.initialize(interfaceName: 'my_vpn');
await wireguard.startVpn(...);  // After initialize
```

### 2. **wg-quick Config Format**
The `wgQuickConfig` parameter expects a complete wg-quick format configuration:
```
[Interface]
PrivateKey = ...
Address = ...
DNS = ...

[Peer]
PublicKey = ...
AllowedIPs = ...
Endpoint = ...
```

**Must include**:
- `[Interface]` section with PrivateKey, Address
- `[Peer]` section with PublicKey, AllowedIPs, Endpoint
- DNS (optional but recommended)

### 3. **Stream Listening**
The `vpnStageSnapshot` stream is broadcast, so:
- Multiple listeners are supported
- You get status changes automatically
- Always unsubscribe in disposal to prevent memory leaks

```dart
late StreamSubscription<VpnStage> _vpnSubscription;

@override
void initState() {
  super.initState();
  _vpnSubscription = wireguard.vpnStageSnapshot.listen((stage) {
    setState(() => _vpnStage = stage);
  });
}

@override
void dispose() {
  _vpnSubscription.cancel();  // ✅ Always cancel
  super.dispose();
}
```

### 4. **Exception Handling**
All methods can throw exceptions - wrap in try/catch:
```dart
try {
  await wireguard.startVpn(...);
} on PlatformException catch (e) {
  print('Platform error: ${e.code} - ${e.message}');
} catch (e) {
  print('General error: $e');
}
```

### 5. **Platform-Specific Considerations**

**Android**:
- Requires VPN permissions in AndroidManifest.xml
- User must approve VPN connection
- Service name used for notification

**iOS**:
- Requires NetworkExtension entitlements
- `providerBundleIdentifier` must match VPN extension bundle ID
- User must approve VPN in Settings

**Windows**:
- Requires WireGuard service installed
- May require admin privileges
- Supports multiple interfaces

**Linux**:
- Uses native WireGuard implementation
- Requires `wg` and `ip` commands available

---

## 📝 Example: Complete VPN Manager Implementation

```dart
import 'package:flutter/services.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

class VpnManager {
  static final instance = VpnManager._();
  
  late final _wg = WireGuardFlutter.instance;
  StreamSubscription<VpnStage>? _statusSubscription;
  VpnStage _currentStage = VpnStage.disconnected;
  
  VpnManager._();
  
  // Getters
  bool get isConnected => _currentStage == VpnStage.connected;
  VpnStage get currentStage => _currentStage;
  Stream<VpnStage> get stageChanges => _wg.vpnStageSnapshot;
  
  // Initialize listening
  void initializeListener() {
    _statusSubscription = _wg.vpnStageSnapshot.listen((stage) {
      _currentStage = stage;
      print('[VPN] Stage changed: $stage');
    });
  }
  
  // Connect to VPN
  Future<void> connect({
    required String serverAddress,
    required String wgQuickConfig,
    required String interfaceName,
    required String bundleId,
  }) async {
    try {
      print('[VPN] Initializing with interface: $interfaceName');
      await _wg.initialize(interfaceName: interfaceName);
      
      print('[VPN] Starting VPN with server: $serverAddress');
      await _wg.startVpn(
        serverAddress: serverAddress,
        wgQuickConfig: wgQuickConfig,
        providerBundleIdentifier: bundleId,
      );
      
      print('[VPN] VPN started, waiting for connection...');
    } on PlatformException catch (e) {
      throw 'Platform error (${e.code}): ${e.message}';
    } catch (e) {
      throw 'Connection failed: $e';
    }
  }
  
  // Disconnect from VPN
  Future<void> disconnect() async {
    try {
      print('[VPN] Stopping VPN...');
      await _wg.stopVpn();
      print('[VPN] VPN stopped');
    } on PlatformException catch (e) {
      throw 'Platform error (${e.code}): ${e.message}';
    } catch (e) {
      throw 'Disconnection failed: $e';
    }
  }
  
  // Get current stage
  Future<VpnStage> getStage() async {
    try {
      return await _wg.stage();
    } catch (e) {
      print('[VPN] Error getting stage: $e');
      return VpnStage.disconnected;
    }
  }
  
  // Cleanup
  void dispose() {
    _statusSubscription?.cancel();
  }
}
```

---

## 🔗 Related Files in This Project

- **Usage**: `lib/api/vpn_manager.dart` - Should implement above patterns
- **Service Layer**: `lib/api/vpn_service.dart` - Calls VpnManager
- **UI**: `lib/screens/home_screen.dart` - Displays VPN status and controls
- **Models**: `lib/api/models.dart` - VPN peer and config models

---

## 📚 External Resources

- **GitHub**: https://github.com/Caqil/wireguard_flutter
- **Pub.dev**: https://pub.dev/packages/wireguard_flutter
- **WireGuard Quick Format**: https://man.archlinux.org/man/wg-quick.8

---

## ✅ Verification Checklist

- [ ] `WireGuardFlutter.instance` can be accessed globally
- [ ] `initialize()` called before `startVpn()`
- [ ] `wgQuickConfig` is valid wg-quick format
- [ ] `vpnStageSnapshot` listener added in initState
- [ ] Stream subscription cancelled in dispose
- [ ] Try/catch blocks around all async calls
- [ ] serverAddress format is correct (IP:PORT)
- [ ] Bundle ID matches iOS VPN extension

---

**Generated**: December 12, 2025  
**Package Version**: wireguard_flutter ^0.1.3  
**Source**: Actual package files from C:\Users\ravin\AppData\Local\Pub\Cache\
