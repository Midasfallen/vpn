import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:easy_localization/easy_localization.dart';

import '../api/client_instance.dart';
import '../api/error_mapper.dart';

/// AuthScreen - экран аутентификации с использованием flutter_login
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      key: const Key('login-screen'),
      title: 'VPN',
      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,
      messages: LoginMessages(
        userHint: 'email_hint'.tr(),
        passwordHint: 'password_hint'.tr(),
        confirmPasswordHint: 'confirm_password_error'.tr(),
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
        primaryColor: Theme.of(context).colorScheme.primary,
        accentColor: Colors.indigoAccent,
        buttonTheme: const LoginButtonTheme(backgroundColor: Colors.indigo),
      ),
      onSubmitAnimationCompleted: () {
        Navigator.pushReplacementNamed(context, '/home');
      },
    );
  }
}
