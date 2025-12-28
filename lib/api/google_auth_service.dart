import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;

/// Сервис для аутентификации через Google Sign-In
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  /// Вход через Google
  ///
  /// Возвращает Google ID Token для отправки на backend
  /// Backend должен верифицировать этот токен и вернуть access_token
  Future<GoogleSignInResult?> signInWithGoogle() async {
    try {
      developer.log('[GoogleAuth] Начинаем вход через Google...', name: 'GoogleAuthService');

      // Пытаемся войти
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        developer.log('[GoogleAuth] Пользователь отменил вход', name: 'GoogleAuthService');
        return null;
      }

      developer.log('[GoogleAuth] Успешный вход: ${account.email}', name: 'GoogleAuthService');

      // Получаем аутентификационные данные
      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.idToken == null) {
        developer.log('[GoogleAuth] Ошибка: ID token отсутствует', name: 'GoogleAuthService');
        throw Exception('Не удалось получить Google ID Token');
      }

      developer.log('[GoogleAuth] Получен ID token', name: 'GoogleAuthService');

      return GoogleSignInResult(
        idToken: auth.idToken!,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } catch (e, stackTrace) {
      developer.log(
        '[GoogleAuth] Ошибка входа через Google: $e',
        name: 'GoogleAuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Проверка, вошёл ли пользователь
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Получить текущего пользователя
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  /// Выход из Google аккаунта
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      developer.log('[GoogleAuth] Выход из Google аккаунта успешен', name: 'GoogleAuthService');
    } catch (e) {
      developer.log('[GoogleAuth] Ошибка выхода: $e', name: 'GoogleAuthService');
      rethrow;
    }
  }

  /// Отключить доступ (revoke)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      developer.log('[GoogleAuth] Отключение Google аккаунта успешно', name: 'GoogleAuthService');
    } catch (e) {
      developer.log('[GoogleAuth] Ошибка отключения: $e', name: 'GoogleAuthService');
      // Игнорируем ошибки отключения
    }
  }
}

/// Результат Google Sign-In
class GoogleSignInResult {
  final String idToken;
  final String email;
  final String? displayName;
  final String? photoUrl;

  GoogleSignInResult({
    required this.idToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
    'id_token': idToken,
    'email': email,
    if (displayName != null) 'display_name': displayName,
    if (photoUrl != null) 'photo_url': photoUrl,
  };
}

/// Глобальный экземпляр сервиса Google Auth
final googleAuthService = GoogleAuthService();
