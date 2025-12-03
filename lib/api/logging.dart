// ...existing code...
import 'dart:developer' as developer;

/// Простой централизованный логгер для API-клиента и других модулей.
/// В продакшене можно подменить реализацию на более мощную (sentry, firebase, file).
class ApiLogger {
  static void info(String message, [Map<String, Object?>? context]) {
    final msg = _format('INFO', message, context);
    developer.log(msg, name: 'ApiClient');
  }

  static void debug(String message, [Map<String, Object?>? context]) {
    final msg = _format('DEBUG', message, context);
    developer.log(msg, name: 'ApiClient');
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = _format('ERROR', message, null);
    developer.log(msg, error: error, stackTrace: stack, name: 'ApiClient');
  }

  static String _format(String level, String message, Map<String, Object?>? context) {
    final ctx = (context == null || context.isEmpty)
        ? ''
        : ' | context: ${context.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    return '[$level] ${DateTime.now().toIso8601String()} - $message$ctx';
  }
}

