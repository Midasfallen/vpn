import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:easy_localization/easy_localization.dart';
import 'api/client_instance.dart';
import 'api/error_mapper.dart';
import 'api/models.dart';
import 'api/token_storage.dart';
import 'api/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initApi();
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
        '/subscription': (_) => const SubscriptionScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
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
    return Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)));
  }
}

// -------------------- PasswordField --------------------
class PasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final String? errorText;
  const PasswordField({this.controller, this.validator, this.errorText, super.key});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        errorText: widget.errorText,
        labelText: 'Пароль',
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscure = !_obscure;
            });
          },
        ),
      ),
      validator: widget.validator,
    );
  }
}

// -------------------- Stubs --------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _connected = false;
  bool _isOnline = true;
  final bool _hasActiveSubscription = false;
  final bool _hasTrial = true;
  final DateTime _subscriptionEnd = DateTime.now().add(Duration(days: 10));
  final DateTime _trialEnd = DateTime.now().add(Duration(days: 3));

  @override
  void initState() {
    super.initState();
    // Попытаться найти существующий peer у пользователя
    _loadPeer();
    // Слушаем изменения подключения к интернету
    connectivityService.addListener(_onConnectivityChanged);
    _checkConnectivity();
  }

  @override
  void dispose() {
    connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    setState(() {
      _isOnline = connectivityService.isOnline;
    });
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await connectivityService.hasConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _loadPeer() async {
    try {
      final peers = await vpnService.listPeers(skip: 0, limit: 10);
      if (peers.isNotEmpty) {
        // We discovered peers but don't auto-connect here; toggling will handle creation/connection.
      }
    } catch (_) {
      // Игнорируем ошибки загрузки peer'ов при старте
    }
  }

  Future<void> _toggleVpn() async {
    if (_connected) {
      setState(() {
        _connected = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VPN отключен')));
      return;
    }

    setState(() {
      _connected = true; // оптимистично
    });

    try {
      // Проверяем, есть ли peer у пользователя
      final existing = await vpnService.getUserPeerId();
      int pid;
      if (existing == null) {
        final created = await vpnService.createPeer();
        pid = created.id;
      } else {
        pid = existing;
      }

      // Подключаем (получаем информацию о peer)
      final peerInfo = await vpnService.connectPeer(pid);

      // Устанавливаем флаг подключено
      if (!mounted) return;
      setState(() {
        _connected = true;
      });

      final statusText = peerInfo.active ? 'active' : 'inactive';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('VPN подключен: $statusText')));
    } catch (e) {
      setState(() {
        _connected = false;
      });
      final msg = mapErrorToMessage(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _getStatusText() {
    final now = DateTime.now();
    if (_hasActiveSubscription && _subscriptionEnd.isAfter(now)) {
      return 'Подписка активна до ${_formatDate(_subscriptionEnd)}';
    } else if (_hasTrial && _trialEnd.isAfter(now)) {
      return 'Пробный период до ${_formatDate(_trialEnd)}';
    } else if (_hasActiveSubscription && _subscriptionEnd.isBefore(now)) {
      return 'Подписка истекла';
    } else if (_hasTrial && _trialEnd.isBefore(now)) {
      return 'Пробный период завершён';
    } else {
      return 'Нет активной подписки';
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  bool _isExpired() {
    final now = DateTime.now();
    return (_hasActiveSubscription && _subscriptionEnd.isBefore(now)) || (_hasTrial && _trialEnd.isBefore(now));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: null,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Offline banner
            if (!_isOnline)
              Container(
                color: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 20, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      'offline_mode'.tr(),
                      style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Card(
                elevation: 0,
                color: _isExpired()
                    ? Colors.red.withAlpha(20)
                    : (_hasActiveSubscription
                        ? Color(0xFFD6E6FB)
                        : (_hasTrial && _trialEnd.isAfter(DateTime.now()) ? Color(0xFFD6E6FB) : Color(0xFFF3F4F6))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: Center(
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _isExpired() ? Colors.red : (_hasActiveSubscription ? Color(0xFF3B82F6) : (_hasTrial && _trialEnd.isAfter(DateTime.now()) ? Color(0xFF3B82F6) : Colors.grey[700])),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/subscription');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart, size: 24),
                      SizedBox(width: 10),
                      Text('Купить подписку'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _toggleVpn,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _connected ? [Color(0xFF6366F1), Color(0xFF4F46E5)] : [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_connected ? Color(0xFF6366F1) : Color(0xFFCBD5E1)).withAlpha(60),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(_connected ? Icons.lock_open : Icons.lock, size: 54, color: Colors.white),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.tune),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF6366F1),
                    elevation: 0,
                    side: BorderSide(color: Color(0xFF6366F1), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    // Заглушка: позже реализуем platform channel для открытия системного окна Android
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Выбор приложений — заглушка')));
                  },
                  label: Text('Выбрать приложения'),
                ),
              ),
            ],
          ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: OutlinedButton.icon(
          key: const Key('logout-button'),
          icon: Icon(Icons.logout),
          label: Text('Выйти из профиля'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFFEF4444),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            await _logout();
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Удаляем токен из безопасного хранилища
      await TokenStorage.deleteToken();
      await TokenStorage.deleteRefreshToken();
    } catch (e) {
      // Логируем ошибку удаления токена, но не мешаем процессу выхода
      // Ошибка игнорируется, чтобы не мешать логауту
    }

    try {
      // Очищаем токен в ApiClient
      apiClient.clearToken();
    } catch (e) {
      // ignore
    }

    // Навигация: очистить стек и показать экран логина
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<List<TariffOut>> _futureTariffs;

  @override
  void initState() {
    super.initState();
    _futureTariffs = vpnService.listTariffs(skip: 0, limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Выберите тариф', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<TariffOut>>(
                future: _futureTariffs,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Не удалось загрузить тарифы: ${snapshot.error}'),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: _reload, child: const Text('Повторить')),
                        ],
                      ),
                    );
                  }
                  final tariffs = snapshot.data ?? [];
                  if (tariffs.isEmpty) {
                    return Center(child: Text('Тарифы не найдены'));
                  }
                  return ListView.separated(
                    itemCount: tariffs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = tariffs[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                  Text(t.price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(t.description),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _onBuy(context, t),
                                    child: const Text('Купить'),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('При нажатии "Купить" в будущем откроется телеграм-бот для оформления покупки. Сейчас — заглушка.', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _futureTariffs = vpnService.listTariffs(skip: 0, limit: 50);
    });
  }

  void _onBuy(BuildContext context, TariffOut tariff) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покупка'),
        content: Text('В будущем будет открыт телеграм-бот для оформления подписки "${tariff.name}" (${tariff.price}).\n\nЭто заглушка.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Открытие телеграм-бота для ${tariff.name} — заглушка')));
            },
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }
}

// Новый экран авторизации на основе flutter_login
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
      key: const Key('login-screen'), // <- добавили ключ для теста
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
