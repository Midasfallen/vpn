import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable loading indicators for different contexts
class LoadingWidget {
  /// Full-screen loading overlay
  static Widget fullScreen({
    String? message,
    bool dismissible = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
            strokeWidth: 3,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Circular loading indicator (small)
  static Widget circular({
    double size = 24,
    Color color = AppColors.accentCyan,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(color),
        strokeWidth: 2,
      ),
    );
  }

  /// Linear progress bar (for bottom sheet, streaming)
  static Widget linear({
    double value = 0,
    Color color = AppColors.accentCyan,
  }) {
    return LinearProgressIndicator(
      value: value > 0 ? value : null,
      valueColor: AlwaysStoppedAnimation<Color>(color),
      backgroundColor: AppColors.darkBgSecondary,
      minHeight: 4,
    );
  }

  /// Shimmer skeleton loader
  static Widget shimmer({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const ShimmerEffect(),
    );
  }
}

/// Shimmer animation effect for skeleton loaders
class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({super.key});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-2.0 + _controller.value * 4.0, 0),
              end: Alignment(-2.0 + _controller.value * 4.0 + 1, 0),
              colors: const [
                AppColors.darkBgSecondary,
                AppColors.darkBg,
                AppColors.darkBgSecondary,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
