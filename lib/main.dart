import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:easy_localization/easy_localization.dart';
import 'api/client_instance.dart';
import 'api/error_mapper.dart';

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
      theme: ThemeData(primarySwatch: Colors.indigo),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const AuthScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/subscription': (_) => const SubscriptionScreen(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 1), () {
      if (!Navigator.canPop(context)) Navigator.pushReplacementNamed(context, '/login');
    });
    return Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)));
  }
}

// -------------------- RegisterScreen --------------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, List<String>> _fieldErrors = {};
  String? _formError;
  bool _isLoading = false;
  final ValueNotifier<bool> _canSubmit = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateCanSubmit);
    _passwordController.addListener(_updateCanSubmit);
    _updateCanSubmit();
  }

  @override
  void dispose() {
    _canSubmit.dispose();
    _emailController.removeListener(_updateCanSubmit);
    _passwordController.removeListener(_updateCanSubmit);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateCanSubmit() {
    final email = _emailController.text.trim();
    final pw = _passwordController.text;
    final emailReg = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+");
    final can = email.isNotEmpty && emailReg.hasMatch(email) && pw.length >= 8;
    if (_canSubmit.value != can) _canSubmit.value = can;
  }

  Future<void> _doRegister() async {
    setState(() {
      _fieldErrors.clear();
      _formError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, исправьте ошибки в форме')));
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      // попытка зарегистрировать
      await vpnService.register(email, password);
      // если регистрация успешна, пробуем авто-вход отдельно
      try {
        await vpnService.login(email, password);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      } catch (loginErr) {
        // авто-вход после регистрации не удался — сообщим и предложим перейти на экран входа
        final loginMsg = mapErrorToMessage(loginErr);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('login_error_title')),
            content: Text('${tr('registration_auto_login_failed')}\n$loginMsg'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('ok'))),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(tr('yes')),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final parsed = parseFieldErrors(e);
      if (parsed.isNotEmpty) {
        setState(() {
          _fieldErrors.addAll(parsed);
          _formError = _fieldErrors['_form']?.join('\n');
        });
        final summary = _fieldErrors.entries.expand((kv) => kv.value.map((m) => '${kv.key == '_form' ? '' : kv.key + ': '}$m')).join('\n');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
        // Если среди ошибок есть информация что email уже зарегистрирован, предложим перейти на вход
        final emailErrors = parsed['email'] ?? parsed['Email'] ?? parsed['e-mail'];
        if (emailErrors != null && emailErrors.any((m) => m.toLowerCase().contains('email уже зарегистрирован') || m.toLowerCase().contains('already'))) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr('email_already_registered')),
              content: Text(tr('email_registered_prompt')),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('no'))),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Text(tr('yes')),
                ),
              ],
            ),
          );
        }
      } else {
        final msg = mapErrorToMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email', errorText: _fieldErrors['email']?.first),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Введите email';
                  final emailReg = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+");
                  if (!emailReg.hasMatch(s)) return 'Введите корректный email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _passwordController,
                errorText: _fieldErrors['password']?.first,
                validator: (v) {
                  final s = v ?? '';
                  if (s.isEmpty) return 'Введите пароль';
                  if (s.length < 8) return 'Пароль должен быть не менее 8 символов';
                  return null;
                },
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(_formError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: _canSubmit,
                builder: (_, can, __) => ElevatedButton(
                  onPressed: (_isLoading || !can) ? null : _doRegister,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Зарегистрироваться'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('Уже есть аккаунт? Войти')),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- LoginScreen --------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, List<String>> _fieldErrors = {};
  String? _formError;
  bool _isLoading = false;
  final ValueNotifier<bool> _canSubmit = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateCanSubmit);
    _passwordController.addListener(_updateCanSubmit);
    _updateCanSubmit();
  }

  @override
  void dispose() {
    _canSubmit.dispose();
    _emailController.removeListener(_updateCanSubmit);
    _passwordController.removeListener(_updateCanSubmit);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateCanSubmit() {
    final email = _emailController.text.trim();
    final pw = _passwordController.text;
    final emailReg = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+");
    final can = email.isNotEmpty && emailReg.hasMatch(email) && pw.length >= 8;
    if (_canSubmit.value != can) _canSubmit.value = can;
  }

  Future<void> _doLogin() async {
    setState(() {
      _fieldErrors.clear();
      _formError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, исправьте ошибки в форме')));
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await vpnService.login(email, password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      final parsed = parseFieldErrors(e);
      if (parsed.isNotEmpty) {
        setState(() {
          _fieldErrors.addAll(parsed);
          _formError = _fieldErrors['_form']?.join('\n');
        });
        final summary = _fieldErrors.entries.expand((kv) => kv.value.map((m) => '${kv.key == '_form' ? '' : kv.key + ': '}$m')).join('\n');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
      } else {
        final msg = mapErrorToMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        // Предложить восстановление пароля при неверных учетных данных
        if (msg.toLowerCase().contains('неверный логин') || msg.toLowerCase().contains('логин или пароль')) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr('login_error_title')),
              content: Text('${tr('invalid_credentials')} ${tr('recover_password')}?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('cancel'))),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('recover_password'))));
                  },
                  child: Text(tr('recover_password')),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email', errorText: _fieldErrors['email']?.first),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Введите email';
                  final emailReg = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+");
                  if (!emailReg.hasMatch(s)) return 'Введите корректный email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _passwordController,
                errorText: _fieldErrors['password']?.first,
                validator: (v) {
                  final s = v ?? '';
                  if (s.isEmpty) return 'Введите пароль';
                  if (s.length < 8) return 'Пароль должен быть не менее 8 символов';
                  return null;
                },
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(_formError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: _canSubmit,
                builder: (_, can, __) => ElevatedButton(
                  onPressed: (_isLoading || !can) ? null : _doLogin,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Войти'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
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

class _AppInfo {
  final String name;
  final IconData icon;
  _AppInfo(this.name, this.icon);
}

class HomeScreenState extends State<HomeScreen> {
  final List<_AppInfo> _apps = [
    _AppInfo('WhatsApp', Icons.message),
    _AppInfo('Instagram', Icons.camera_alt),
    _AppInfo('YouTube', Icons.ondemand_video),
    _AppInfo('Telegram', Icons.send),
    _AppInfo('Facebook', Icons.facebook),
    _AppInfo('TikTok', Icons.music_note),
    _AppInfo('Gmail', Icons.email),
    _AppInfo('Chrome', Icons.language),
    _AppInfo('Spotify', Icons.music_note_outlined),
    _AppInfo('Twitter', Icons.alternate_email),
  ];

  final Map<String, bool> _selectedApps = {};
  bool _connected = false;
  final bool _hasActiveSubscription = false;
  final bool _hasTrial = true;
  final DateTime _subscriptionEnd = DateTime.now().add(Duration(days: 10));
  final DateTime _trialEnd = DateTime.now().add(Duration(days: 3));

  void _toggleVpn() {
    setState(() {
      _connected = !_connected;
    });
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
        child: Padding(
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
                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setStateDialog) => AlertDialog(
                          title: Text('Выберите приложения для VPN'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setStateDialog(() {
                                          for (var app in _apps) {
                                            _selectedApps[app.name] = true;
                                          }
                                        });
                                        setState(() {
                                          for (var app in _apps) {
                                            _selectedApps[app.name] = true;
                                          }
                                        });
                                      },
                                      child: Text('Включить все'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setStateDialog(() {
                                          for (var app in _apps) {
                                            _selectedApps[app.name] = false;
                                          }
                                        });
                                        setState(() {
                                          for (var app in _apps) {
                                            _selectedApps[app.name] = false;
                                          }
                                        });
                                      },
                                      child: Text('Выключить все'),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _apps.length,
                                    itemBuilder: (context, i) {
                                      final app = _apps[i];
                                      final enabled = _selectedApps[app.name] ?? true;
                                      return ListTile(
                                        leading: Icon(app.icon, color: Color(0xFF6366F1)),
                                        title: Text(app.name),
                                        trailing: Switch(
                                          value: enabled,
                                          onChanged: (val) {
                                            setStateDialog(() {
                                              _selectedApps[app.name] = val;
                                            });
                                            setState(() {
                                              _selectedApps[app.name] = val;
                                            });
                                          },
                                          activeColor: Color(0xFF6366F1),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Готово')),
                          ],
                        ),
                      ),
                    );
                  },
                  label: Text('Выбрать приложения'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: OutlinedButton.icon(
          icon: Icon(Icons.logout),
          label: Text('Выйти из профиля'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFFEF4444),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            // TODO: Реализовать выход из профиля
          },
        ),
      ),
    );
  }
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Subscription')), body: const Center(child: Text('Subscription')));
}

// Новый экран авторизации на основе flutter_login
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  Duration get loginTime => const Duration(milliseconds: 2250);

  Future<String?> _authUser(LoginData data) async {
    final email = data.name.trim();
    final password = data.password;
    try {
      await vpnService.login(email, password);
      return null; // success
    } catch (e) {
      // отдаём сообщение flutter_login для отображения
      return mapErrorToMessage(e);
    }
  }

  Future<String?> _signupUser(SignupData data) async {
    final email = (data.name ?? '').trim();
    final password = data.password ?? '';
    try {
      await vpnService.register(email, password);
      // попытка авто-входа
      try {
        await vpnService.login(email, password);
        return null;
      } catch (le) {
        return 'Регистрация успешна, но автоматический вход не выполнен.';
      }
    } catch (e) {
      final parsed = parseFieldErrors(e);
      if (parsed.isNotEmpty) {
        // предпочитаем показывать ошибку поля email если есть
        final em = parsed['email']?.first ?? parsed['_form']?.first;
        return em ?? mapErrorToMessage(e);
      }
      return mapErrorToMessage(e);
    }
  }

  Future<String?> _recoverPassword(String name) async {
    // В проекте нет endpoint для восстановления — пока заглушка
    return 'Функция восстановления пароля не реализована.';
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
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
        recoverPasswordDescription: 'recover_password_description'.tr() ?? '',
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
