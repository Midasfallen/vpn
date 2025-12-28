import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io' show Platform;

import '../api/google_auth_service.dart';
import '../api/apple_auth_service.dart';
import '../api/client_instance.dart';
import '../theme/colors.dart';

/// Виджет с кнопками OAuth (Google/Apple Sign-In)
class OAuthButtons extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const OAuthButtons({
    super.key,
    this.onSuccess,
    this.onError,
  });

  @override
  State<OAuthButtons> createState() => _OAuthButtonsState();
}

class _OAuthButtonsState extends State<OAuthButtons> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Вход через Google
      final result = await googleAuthService.signInWithGoogle();

      if (result == null) {
        // Пользователь отменил
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onError?.call('oauth_cancelled'.tr());
        }
        return;
      }

      // Отправляем ID token на backend
      await vpnService.loginWithGoogle(result.idToken);

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onError?.call('oauth_error'.tr(args: [e.toString()]));
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Проверка доступности
      final available = await appleAuthService.isAvailable();
      if (!available) {
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onError?.call('oauth_unavailable'.tr());
        }
        return;
      }

      // Вход через Apple
      final result = await appleAuthService.signInWithApple();

      if (result == null) {
        // Пользователь отменил
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onError?.call('oauth_cancelled'.tr());
        }
        return;
      }

      // Отправляем данные на backend
      await vpnService.loginWithApple(
        identityToken: result.identityToken,
        authorizationCode: result.authorizationCode,
        userIdentifier: result.userIdentifier,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onError?.call('oauth_error'.tr(args: [e.toString()]));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accentGold,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Разделитель "или продолжить с"
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              const Expanded(child: Divider(color: AppColors.borderLight)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or_continue_with'.tr(),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.borderLight)),
            ],
          ),
        ),

        // Google Sign-In кнопка
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.borderLight, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.darkBgSecondary,
            ),
            icon: Image.asset(
              'assets/google_logo.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                // Fallback если нет иконки
                return const Icon(Icons.g_mobiledata, size: 24);
              },
            ),
            label: Text(
              'sign_in_with_google'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Apple Sign-In кнопка (только на iOS)
        if (Platform.isIOS) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _handleAppleSignIn,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.borderLight, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppColors.darkBgSecondary,
              ),
              icon: const Icon(Icons.apple, size: 24),
              label: Text(
                'sign_in_with_apple'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
