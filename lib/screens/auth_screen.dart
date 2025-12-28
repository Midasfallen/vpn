import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:easy_localization/easy_localization.dart';

import '../api/client_instance.dart';
import '../api/error_mapper.dart';
import '../widgets/oauth_buttons.dart';

/// AuthScreen - экран аутентификации с использованием flutter_login и OAuth
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {

  Future<String?> _authUser(LoginData data) async {
    final email = data.name.trim();
    final password = data.password;
    try {
      await vpnService.login(email, password);
      return null;
    } catch (e) {
      return mapErrorToMessage(e);
    }
  }

  Future<String?> _signupUser(SignupData data) async {
    final email = (data.name ?? '').trim();
    final password = data.password ?? '';
    try {
      await vpnService.register(email, password);
      try {
        await vpnService.login(email, password);
        // НЕ создаём peer здесь — только при явном запросе из HomeScreen
        return null;
      } catch (_) {
        return 'Регистрация успешна, но автоматический вход не выполнен.';
      }
    } catch (e) {
      final parsed = parseFieldErrors(e);
      if (parsed.isNotEmpty) {
        String? em;
        if (parsed['email'] != null && parsed['email']!.isNotEmpty) {
          em = parsed['email']!.first;
        } else if (parsed['_form'] != null && parsed['_form']!.isNotEmpty) {
          em = parsed['_form']!.first;
        }
        return em ?? mapErrorToMessage(e);
      }
      return mapErrorToMessage(e);
    }
  }

  Future<String?> _recoverPassword(String name) async {
    // Заглушка — в API нет реализации восстановления
    return 'Функция восстановления пароля не реализована.';
  }

  void _handleOAuthSuccess() {
    // После успешного OAuth входа перенаправляем на главный экран
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _handleOAuthError(String error) {
    // Показываем ошибку OAuth
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      key: const Key('login-screen'),
      title: 'Incamp VPN',
      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,
      messages: LoginMessages(
        userHint: 'email_hint'.tr(),
        passwordHint: 'password_hint'.tr(),
        confirmPasswordHint: 'password_hint'.tr(),
        loginButton: 'login'.tr(),
        signupButton: 'signup'.tr(),
        forgotPasswordButton: 'forgot_password'.tr(),
        recoverPasswordButton: 'recover_password'.tr(),
        goBackButton: 'go_back'.tr(),
        confirmPasswordError: 'confirm_password_error'.tr(),
        recoverPasswordIntro: 'recover_password'.tr(),
        recoverPasswordDescription: 'recover_password_description'.tr(),
        recoverPasswordSuccess: 'recover_password_success'.tr(),
        flushbarTitleError: 'login_error_title'.tr(),
        flushbarTitleSuccess: 'registration_auto_login_failed'.tr(),
      ),
      theme: LoginTheme(
        primaryColor: const Color(0xFFFCD34D),
        accentColor: const Color(0xFFFCD34D),
        buttonTheme: const LoginButtonTheme(backgroundColor: Color(0xFFFCD34D)),
        titleStyle: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      onSubmitAnimationCompleted: () {
        Navigator.pushReplacementNamed(context, '/home');
      },
      footer: 'Incamp VPN',
      children: [
        // OAuth кнопки внизу экрана
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: OAuthButtons(
            onSuccess: _handleOAuthSuccess,
            onError: _handleOAuthError,
          ),
        ),
      ],
    );
  }
}
