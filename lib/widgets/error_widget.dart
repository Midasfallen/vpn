import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable error display widgets with recovery options
class ErrorWidget extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData icon;
  final EdgeInsets padding;

  const ErrorWidget({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppColors.warning,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel ?? 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.darkBg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline error message (for form fields, etc.)
class ErrorMessage extends StatelessWidget {
  final String message;
  final EdgeInsets padding;

  const ErrorMessage(
    this.message, {
    super.key,
    this.padding = const EdgeInsets.only(left: 16, right: 16, top: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network error state with offline indicator
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      icon: Icons.wifi_off,
      message: 'No Internet Connection',
      details: 'Check your network and try again',
      onRetry: onRetry,
      retryLabel: 'Try Again',
    );
  }
}

/// Server error state
class ServerErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? statusCode;

  const ServerErrorWidget({
    super.key,
    this.onRetry,
    this.statusCode,
  });

  @override
  Widget build(BuildContext context) {
    final status = statusCode != null ? ' (Error $statusCode)' : '';
    return ErrorWidget(
      icon: Icons.cloud_off,
      message: 'Server Error$status',
      details: 'Something went wrong on the server',
      onRetry: onRetry,
      retryLabel: 'Retry',
    );
  }
}

/// Timeout error state
class TimeoutErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const TimeoutErrorWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      icon: Icons.schedule,
      message: 'Request Timeout',
      details: 'Connection took too long. Check your network.',
      onRetry: onRetry,
      retryLabel: 'Retry',
    );
  }
}
