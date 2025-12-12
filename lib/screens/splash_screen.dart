import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Splash screen показывается при загрузке приложения
/// Переводит на экран логина через 1 секунду
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      if (!Navigator.canPop(context)) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Полноэкранное изображение
          Positioned.fill(
            child: Image.asset(
              'assets/ea866ac6-8957-42ea-a843-e4eda0e6d9b7-removebg-preview (1).png',
              fit: BoxFit.cover,
            ),
          ),
          // Прогресс-бар внизу экрана
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
