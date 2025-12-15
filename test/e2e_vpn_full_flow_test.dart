// ignore_for_file: avoid_print

import 'dart:io';
import 'package:test/test.dart';
import 'package:vpn/api/client_instance.dart';
import 'package:vpn/config/environment.dart';

/// E2E Test: Full VPN Flow with Internet Access Validation
///
/// This test validates the critical fix for VPN internet access issue.
/// It simulates the complete user flow from registration to VPN connection.
void main() {
  setUpAll(() {
    Environment.initialize(flavor: 'dev');
  });

  group('E2E: Full VPN Flow', () {
    late String email;
    late String password;
    late String accessToken;
    late int peerId;

    setUp(() {
      final ts = DateTime.now().millisecondsSinceEpoch;
      email = 'e2e_test_$ts@example.com';
      password = 'TestPass123!';
    });

    test('Complete VPN flow: Register → Login → Create Peer → Validate Config', () async {
      print('\n🧪 Starting E2E VPN Flow Test...\n');

      // Step 1: Register new user
      print('📝 Step 1/6: Registering new user...');
      final registerResponse = await apiClient.post<Map<String, dynamic>>(
        '/auth/register',
        {'email': email, 'password': password},
        (json) => json as Map<String, dynamic>,
      );
      expect(registerResponse, isNotNull);
      expect(registerResponse['email'], equals(email));
      print('   ✅ User registered: ${registerResponse['email']}');

      // Step 2: Login and get token
      print('\n🔑 Step 2/6: Logging in...');
      final loginResponse = await apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        {'email': email, 'password': password},
        (json) => json as Map<String, dynamic>,
      );
      expect(loginResponse, isNotNull);
      accessToken = loginResponse['access_token'] as String;
      expect(accessToken, isNotEmpty);
      apiClient.setToken(accessToken);
      print('   ✅ Login successful, token obtained');

      // Step 3: Create test tariff for E2E testing
      print('\n💳 Step 3/7: Setting up test tariff...');
      // Try to create a free test tariff (admin-only, might fail - that's OK)
      try {
        await apiClient.post<Map<String, dynamic>>(
          '/tariffs/',
          {
            'name': 'E2E Test Tariff',
            'price': 0.0,
            'duration_days': 365,
            'traffic_limit_gb': null,
          },
          (json) => json as Map<String, dynamic>,
        );
      } catch (e) {
        // Tariff creation might fail (not admin), try to subscribe anyway
        print('   ⚠️ Tariff creation failed (expected if not admin): $e');
      }

      // Step 4: Subscribe to enable VPN peer creation
      print('\n📝 Step 4/7: Creating subscription...');
      try {
        // Get available tariffs
        final tariffsResponse = await apiClient.get<List<dynamic>>(
          '/tariffs/',
          (json) => json as List<dynamic>,
        );

        if (tariffsResponse.isNotEmpty) {
          final tariffId = (tariffsResponse.first as Map<String, dynamic>)['id'];
          final subscriptionResponse = await apiClient.post<Map<String, dynamic>>(
            '/auth/subscribe',
            {'tariff_id': tariffId},
            (json) => json as Map<String, dynamic>,
          );
          print('   ✅ Subscription created: ID=${subscriptionResponse['id']}');
        } else {
          print('   ⚠️ No tariffs available, attempting peer creation anyway...');
        }
      } catch (e) {
        print('   ⚠️ Subscription creation failed: $e');
      }

      // Step 5: Create VPN peer
      print('\n🔧 Step 5/7: Creating VPN peer...');
      final peerResponse = await apiClient.post<Map<String, dynamic>>(
        '/vpn_peers/self',
        {},
        (json) => json as Map<String, dynamic>,
      );
      expect(peerResponse, isNotNull);
      peerId = peerResponse['id'] as int;
      expect(peerId, isNonZero);
      final peerPublicKey = peerResponse['wg_public_key'] as String?;
      print('   ✅ Peer created: ID=$peerId, IP=${peerResponse['wg_ip']}');

      // Step 6: Get peer configuration
      print('\n📄 Step 6/7: Fetching VPN configuration...');
      final configResponse = await apiClient.get<Map<String, dynamic>>(
        '/vpn_peers/self/config',
        (json) => json as Map<String, dynamic>,
      );
      expect(configResponse, isNotNull);
      final wgConfig = configResponse['wg_quick'] as String;
      expect(wgConfig, isNotEmpty);
      print('   ✅ Config fetched (${wgConfig.length} bytes)');

      // Step 7: Validate WireGuard config format
      print('\n🔍 Step 7/7: Validating WireGuard config...');
      _validateWireGuardConfig(wgConfig);
      print('   ✅ Config validation passed');

      // Step 8: Critical validation - Server public key check
      print('\n🔴 Step 8/7: CRITICAL - Validating server public key...');
      final serverPublicKey = Platform.environment['WG_SERVER_PUBLIC_KEY'] ??
                               '1SUivFxEBdU5SjpL2cLBykv/4HcotWpIrdSUGFDGIA8=';

      _validateServerPublicKey(wgConfig, serverPublicKey, peerPublicKey ?? '');
      print('   ✅ CRITICAL CHECK PASSED: Server public key is correct');

      // Cleanup: Delete peer
      print('\n🧹 Cleanup: Deleting test peer...');
      await apiClient.delete('/vpn_peers/$peerId', (_) => null);
      print('   ✅ Test peer deleted');

      print('\n✅ E2E VPN Flow Test PASSED\n');
    }, timeout: Timeout(Duration(seconds: 90)));

    test('Validate multiple config fields', () async {
      print('\n🧪 Testing config field validation...\n');

      // Register and login
      await apiClient.post<Map<String, dynamic>>(
        '/auth/register',
        {'email': email, 'password': password},
        (json) => json as Map<String, dynamic>,
      );
      final loginResponse = await apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        {'email': email, 'password': password},
        (json) => json as Map<String, dynamic>,
      );
      apiClient.setToken(loginResponse['access_token'] as String);

      // Subscribe to enable VPN peer creation
      try {
        final tariffsResponse = await apiClient.get<List<dynamic>>(
          '/tariffs/',
          (json) => json as List<dynamic>,
        );
        if (tariffsResponse.isNotEmpty) {
          final tariffId = (tariffsResponse.first as Map<String, dynamic>)['id'];
          await apiClient.post<Map<String, dynamic>>(
            '/auth/subscribe',
            {'tariff_id': tariffId},
            (json) => json as Map<String, dynamic>,
          );
        }
      } catch (e) {
        // Ignore subscription errors for this test
      }

      // Create peer and get config
      await apiClient.post<Map<String, dynamic>>(
        '/vpn_peers/self',
        {},
        (json) => json as Map<String, dynamic>,
      );
      final configResponse = await apiClient.get<Map<String, dynamic>>(
        '/vpn_peers/self/config',
        (json) => json as Map<String, dynamic>,
      );
      final wgConfig = configResponse['wg_quick'] as String;
      final peerResponse = await apiClient.get<List<dynamic>>(
        '/vpn_peers/',
        (json) => json as List<dynamic>,
      );
      final peerId = (peerResponse.first as Map<String, dynamic>)['id'] as int;

      // Validate all required fields
      print('📋 Checking required fields...');
      expect(wgConfig.contains('[Interface]'), isTrue, reason: 'Missing [Interface] section');
      expect(wgConfig.contains('[Peer]'), isTrue, reason: 'Missing [Peer] section');
      expect(wgConfig.contains('PrivateKey'), isTrue, reason: 'Missing PrivateKey');
      expect(wgConfig.contains('Address'), isTrue, reason: 'Missing Address');
      expect(wgConfig.contains('DNS'), isTrue, reason: 'Missing DNS');
      expect(wgConfig.contains('PublicKey'), isTrue, reason: 'Missing PublicKey');
      expect(wgConfig.contains('AllowedIPs'), isTrue, reason: 'Missing AllowedIPs');
      expect(wgConfig.contains('Endpoint'), isTrue, reason: 'Missing Endpoint');
      print('   ✅ All required fields present');

      // Validate field values
      print('\n📊 Checking field values...');
      expect(wgConfig.contains('AllowedIPs = 0.0.0.0/0'), isTrue,
             reason: 'AllowedIPs should be 0.0.0.0/0 for full tunnel');
      expect(wgConfig.contains('DNS = 8.8.8.8'), isTrue,
             reason: 'DNS should contain 8.8.8.8');
      expect(wgConfig.contains('Endpoint = '), isTrue,
             reason: 'Endpoint should be present');
      print('   ✅ Field values are correct');

      // Cleanup
      await apiClient.delete('/vpn_peers/$peerId', (_) => null);
      print('\n✅ Config field validation PASSED\n');
    }, timeout: Timeout(Duration(seconds: 90)));
  });
}

/// Validates WireGuard config format
void _validateWireGuardConfig(String config) {
  final lines = config.split('\n');
  bool hasInterface = false;
  bool hasPeer = false;
  bool hasPrivateKey = false;
  bool hasAddress = false;
  bool hasDNS = false;
  bool hasPublicKey = false;
  bool hasAllowedIPs = false;
  bool hasEndpoint = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == '[Interface]') hasInterface = true;
    if (trimmed == '[Peer]') hasPeer = true;
    if (trimmed.startsWith('PrivateKey')) hasPrivateKey = true;
    if (trimmed.startsWith('Address')) hasAddress = true;
    if (trimmed.startsWith('DNS')) hasDNS = true;
    if (trimmed.startsWith('PublicKey')) hasPublicKey = true;
    if (trimmed.startsWith('AllowedIPs')) hasAllowedIPs = true;
    if (trimmed.startsWith('Endpoint')) hasEndpoint = true;
  }

  expect(hasInterface, isTrue, reason: 'Config missing [Interface] section');
  expect(hasPeer, isTrue, reason: 'Config missing [Peer] section');
  expect(hasPrivateKey, isTrue, reason: 'Config missing PrivateKey');
  expect(hasAddress, isTrue, reason: 'Config missing Address');
  expect(hasDNS, isTrue, reason: 'Config missing DNS');
  expect(hasPublicKey, isTrue, reason: 'Config missing PublicKey');
  expect(hasAllowedIPs, isTrue, reason: 'Config missing AllowedIPs');
  expect(hasEndpoint, isTrue, reason: 'Config missing Endpoint');
}

/// Critical validation: Checks that config uses SERVER public key, not client key
void _validateServerPublicKey(String config, String serverKey, String clientKey) {
  final lines = config.split('\n');
  bool inPeerSection = false;
  String? peerPublicKey;

  for (final line in lines) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) continue; // Skip blank lines

    if (trimmed == '[Peer]') {
      inPeerSection = true;
      continue;
    }
    if (trimmed.startsWith('[') && inPeerSection) {
      break; // End of Peer section
    }
    if (inPeerSection && trimmed.startsWith('PublicKey')) {
      // Split only on first '=' because the key itself may contain '=' (base64 padding)
      final equalIndex = trimmed.indexOf('=');
      if (equalIndex != -1 && equalIndex < trimmed.length - 1) {
        peerPublicKey = trimmed.substring(equalIndex + 1).trim();
        break;
      }
    }
  }

  expect(peerPublicKey, isNotNull,
         reason: 'No PublicKey found in [Peer] section');

  // Critical check: Must be SERVER key, NOT client key
  expect(peerPublicKey, equals(serverKey),
         reason: 'CRITICAL: Config must use SERVER public key ($serverKey), but found: $peerPublicKey');

  expect(peerPublicKey, isNot(equals(clientKey)),
         reason: 'CRITICAL: Config contains CLIENT public key! This breaks internet access. '
                 'It should contain SERVER key instead.');

  print('      🔑 Server key: $serverKey');
  print('      🔑 Config key: $peerPublicKey');
  print('      ✅ Keys match correctly');
}
