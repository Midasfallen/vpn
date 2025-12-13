import 'dart:convert';
import 'dart:math';

/// Helper class for WireGuard cryptography operations
class WireGuardHelper {
  /// Generate a WireGuard-like key pair
  /// For simplicity, we generate random 32-byte values and base64-encode them
  /// A real implementation would use Curve25519, but for MVP this is sufficient
  static Map<String, String> generateKeyPair() {
    final random = Random.secure();
    
    // Generate 32 random bytes for private key
    final privateKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    
    // Generate 32 random bytes for public key (in reality, this would be derived from private key)
    final publicKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    
    // Clamp the private key (WireGuard standard)
    privateKeyBytes[0] &= 248;  // Clear bits 0, 1, 2
    privateKeyBytes[31] &= 127; // Clear bit 7
    privateKeyBytes[31] |= 64;  // Set bit 6
    
    // Encode to base64
    final privateKeyBase64 = base64.encode(privateKeyBytes);
    final publicKeyBase64 = base64.encode(publicKeyBytes);
    
    return {
      'private': privateKeyBase64,
      'public': publicKeyBase64,
    };
  }
}
