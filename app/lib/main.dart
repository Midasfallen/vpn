import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'config/environment.dart';
import 'api/client_instance.dart';
// import 'api/iap_manager.dart';  // Disabled for now — testing backend subscription only
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'subscription_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment based on build flavor
  // For development: flutter run --flavor dev
  // For staging: flutter run --flavor staging
  // For production: flutter run --flavor prod
  const String buildFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  Environment.initialize(flavor: buildFlavor);
  
  await EasyLocalization.ensureInitialized();
  await initApi();

  // IAP initialization disabled for now — testing backend subscription only
  // final iapManager = IapManager();
  // try {
  //   await iapManager.initialize(vpnService);
  // } catch (_) {
  //   // IAP not available or initialization failed — app still usable.
  // }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ru')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      child: const VpnApp(),
    ),
  );
}

class VpnApp extends StatelessWidget {
  const VpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incamp VPN',
      theme: AppTheme.darkTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const AuthScreen(key: Key('login-screen')),
        '/home': (_) => const HomeScreen(),
        '/subscription': (_) => SubscriptionScreen(vpnService: vpnService),
      },
    );
  }
}

