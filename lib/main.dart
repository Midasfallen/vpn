import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'api/client_instance.dart';
import 'api/iap_manager.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initApi();

  // Initialize IAP manager (best-effort). Failure should not block app start.
  final iapManager = IapManager();
  try {
    await iapManager.initialize(vpnService);
  } catch (_) {
    // IAP not available or initialization failed — app still usable.
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ru')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      child: VpnApp(iapManager: iapManager),
    ),
  );
}

class VpnApp extends StatelessWidget {
  final IapManager iapManager;

  const VpnApp({super.key, required this.iapManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
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

