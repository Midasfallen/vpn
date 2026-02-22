/// Environment configuration for different build flavors
/// Usage: Environment.current.apiBaseUrl
class Environment {
  final String name; // 'dev', 'staging', 'prod'
  final String apiBaseUrl;
  final String apiKey; // Optional: for API authentication
  final bool enableDebugLogging;
  final bool enableCertificatePinning;
  final Duration connectionTimeout;
  final Duration receiveTimeout;

  const Environment({
    required this.name,
    required this.apiBaseUrl,
    required this.apiKey,
    required this.enableDebugLogging,
    required this.enableCertificatePinning,
    this.connectionTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
  });

  /// Development environment (local/emulator)
  static const dev = Environment(
    name: 'dev',
    apiBaseUrl: 'http://146.103.99.70:8000', // Single backend server
    apiKey: 'dev-key-not-used',
    enableDebugLogging: true,
    enableCertificatePinning: false,
    connectionTimeout: Duration(seconds: 60),
    receiveTimeout: Duration(seconds: 60),
  );

  /// Staging environment (test server)
  static const staging = Environment(
    name: 'staging',
    apiBaseUrl: 'http://146.103.99.70:8000', // Single backend server
    apiKey: '', // Set via environment variable at build time
    enableDebugLogging: true,
    enableCertificatePinning: false,
    connectionTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  );

  /// Production environment
  static const prod = Environment(
    name: 'prod',
    apiBaseUrl: 'http://146.103.99.70:8000', // Single backend server
    apiKey: '', // Set via environment variable at build time
    enableDebugLogging: false,
    enableCertificatePinning: false,
    connectionTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  );

  /// Current environment (set at app startup)
  static late Environment current;

  /// Initialize environment based on build flavor
  /// Call this in main() before runApp()
  /// Example: Environment.initialize(flavor: 'prod');
  static void initialize({required String flavor}) {
    current = switch (flavor) {
      'dev' => dev,
      'staging' => staging,
      'prod' => prod,
      _ => prod, // Default to production for safety
    };
  }

  @override
  String toString() => 'Environment($name)';
}
