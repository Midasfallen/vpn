import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

/// Сервис для аутентификации через Apple Sign-In
class AppleAuthService {
  static final AppleAuthService _instance = AppleAuthService._internal();
  factory AppleAuthService() => _instance;
  AppleAuthService._internal();

  /// Проверка доступности Apple Sign-In на платформе
  Future<bool> isAvailable() async {
    // Apple Sign-In доступен только на iOS 13+ и macOS 10.15+
    // На Android доступен через web-based flow
    if (Platform.isIOS) {
      return await SignInWithApple.isAvailable();
    }
    // На Android можно использовать web-based flow, но это опционально
    return false;
  }

  /// Вход через Apple
  ///
  /// Возвращает Apple ID Token и Authorization Code для отправки на backend
  /// Backend должен верифицировать эти данные и вернуть access_token
  Future<AppleSignInResult?> signInWithApple() async {
    try {
      developer.log('[AppleAuth] Начинаем вход через Apple...', name: 'AppleAuthService');

      // Проверяем доступность
      final available = await isAvailable();
      if (!available) {
        developer.log('[AppleAuth] Apple Sign-In недоступен на этой платформе', name: 'AppleAuthService');
        throw UnsupportedError('Apple Sign-In недоступен на этой платформе');
      }

      // Запрашиваем авторизацию
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      developer.log('[AppleAuth] Успешный вход', name: 'AppleAuthService');
      developer.log('[AppleAuth] User ID: ${credential.userIdentifier}', name: 'AppleAuthService');

      // Формируем полное имя если доступно
      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        fullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
        if (fullName.isEmpty) fullName = null;
      }

      return AppleSignInResult(
        userIdentifier: credential.userIdentifier ?? '',
        identityToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        email: credential.email,
        fullName: fullName,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } catch (e, stackTrace) {
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          developer.log('[AppleAuth] Пользователь отменил вход', name: 'AppleAuthService');
          return null;
        }
        developer.log('[AppleAuth] Ошибка авторизации: ${e.message}', name: 'AppleAuthService');
      } else {
        developer.log(
          '[AppleAuth] Ошибка входа через Apple: $e',
          name: 'AppleAuthService',
          error: e,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  /// Получить состояние credential
  Future<CredentialState> getCredentialState(String userIdentifier) async {
    try {
      return await SignInWithApple.getCredentialState(userIdentifier);
    } catch (e) {
      developer.log('[AppleAuth] Ошибка получения состояния credential: $e', name: 'AppleAuthService');
      return CredentialState.notFound;
    }
  }
}

/// Результат Apple Sign-In
class AppleSignInResult {
  final String userIdentifier;
  final String? identityToken;
  final String? authorizationCode;
  final String? email;
  final String? fullName;
  final String? givenName;
  final String? familyName;

  AppleSignInResult({
    required this.userIdentifier,
    this.identityToken,
    this.authorizationCode,
    this.email,
    this.fullName,
    this.givenName,
    this.familyName,
  });

  Map<String, dynamic> toJson() => {
    'user_identifier': userIdentifier,
    if (identityToken != null) 'identity_token': identityToken,
    if (authorizationCode != null) 'authorization_code': authorizationCode,
    if (email != null) 'email': email,
    if (fullName != null) 'full_name': fullName,
    if (givenName != null) 'given_name': givenName,
    if (familyName != null) 'family_name': familyName,
  };
}

/// Глобальный экземпляр сервиса Apple Auth
final appleAuthService = AppleAuthService();
