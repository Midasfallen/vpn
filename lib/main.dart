
import 'package:flutter/material.dart';

// Класс для информации о приложении


void main() {
  runApp(VpnApp());
}

class VpnApp extends StatelessWidget {
  const VpnApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN App',
      theme: ThemeData(
        primaryColor: Color(0xFF4F46E5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF4F46E5),
          secondary: Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Color(0xFFF3F4F6),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF4F46E5)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF6366F1)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Color(0xFF4F46E5)),
            foregroundColor: Color(0xFF4F46E5),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: SplashScreen(),
      routes: {
        '/login': (_) => LoginScreen(),
        '/home': (_) => HomeScreen(),
        // '/split': (_) => SplitTunnelingScreen(), // Экран не реализован
        '/subscription': (_) => SubscriptionScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.vpn_lock, size: 48, color: Theme.of(context).colorScheme.secondary),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Вход'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Добро пожаловать!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Войдите в свой аккаунт, чтобы продолжить',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                SizedBox(height: 16),
                _PasswordField(),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: Text('Войти'),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('или'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 1,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                    height: 24,
                  ),
                  label: Text('Войти через Google'),
                  onPressed: () {
                    // TODO: Реализовать Google Sign-In
                  },
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 1,
                  ),
                  icon: Icon(Icons.apple, size: 24),
                  label: Text('Войти через Apple'),
                  onPressed: () {
                    // TODO: Реализовать Apple Sign-In
                  },
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Нет аккаунта?'),
                    TextButton(
                      onPressed: () {
                        // TODO: Реализовать регистрацию
                      },
                      child: Text('Зарегистрироваться'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Поле пароля с возможностью показать/скрыть
class _PasswordField extends StatefulWidget {
  const _PasswordField();
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: _obscure,
      decoration: InputDecoration(
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
    );
  }
}
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
  // Моковые данные популярных приложений
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
  // Состояние выбранных приложений
  final Map<String, bool> _selectedApps = {};

  bool _connected = false;
  bool _hasActiveSubscription = false;
  bool _hasTrial = true;
  DateTime _subscriptionEnd = DateTime.now().add(Duration(days: 10));
  DateTime _trialEnd = DateTime.now().add(Duration(days: 3));

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
    return (_hasActiveSubscription && _subscriptionEnd.isBefore(now)) ||
        (_hasTrial && _trialEnd.isBefore(now));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text('Главная'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Статус/пробный период
              Card(
                elevation: 0,
                color: _isExpired()
                    ? Colors.red.withAlpha(20)
                    : (_hasActiveSubscription
                        ? Color(0xFFD6E6FB)
                        : (_hasTrial && _trialEnd.isAfter(DateTime.now())
                            ? Color(0xFFD6E6FB)
                            : Color(0xFFF3F4F6))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                  child: Center(
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isExpired()
                            ? Colors.red
                            : (_hasActiveSubscription
                                ? Color(0xFF3B82F6)
                                : (_hasTrial && _trialEnd.isAfter(DateTime.now())
                                    ? Color(0xFF3B82F6)
                                    : Colors.grey[700])),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              // Кнопка купить подписку
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: EdgeInsets.symmetric(vertical: 20),
                  textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/subscription');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, size: 26),
                    SizedBox(width: 12),
                    Text('Купить подписку'),
                  ],
                ),
              ),
              SizedBox(height: 36),
              // Кнопка подключения
              Center(
                child: GestureDetector(
                  onTap: _toggleVpn,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _connected
                            ? [Color(0xFF6366F1), Color(0xFF4F46E5)]
                            : [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_connected ? Color(0xFF6366F1) : Color(0xFFCBD5E1)).withAlpha(60),
                          blurRadius: 36,
                          offset: Offset(0, 18),
                        ),
                      ],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _connected ? Icons.lock_open : Icons.lock,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18),
              // Кнопка "Выбрать приложения"
              ElevatedButton.icon(
                icon: Icon(Icons.tune),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF6366F1),
                  elevation: 0,
                  side: BorderSide(color: Color(0xFF6366F1), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.symmetric(vertical: 18),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Готово'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                label: Text('Выбрать приложения'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Подписка'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 0),
              padding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              decoration: BoxDecoration(
                color: Color(0xFFD6E6FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Пробный период', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                  SizedBox(height: 4),
                  Text('7 дней бесплатного доступа', style: TextStyle(fontSize: 15, color: Color(0xFF60A5FA))),
                ],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.shopping_cart),
              label: Text('Купить подписку'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                // TODO: обработка покупки подписки
              },
            ),
            SizedBox(height: 32),
            SubscriptionCard(
              title: '1 месяц',
              price: '100 ⭐',
              onTap: () {},
            ),
            SubscriptionCard(
              title: '6 месяцев',
              price: '500 ⭐',
              onTap: () {},
            ),
            SubscriptionCard(
              title: '1 год',
              price: '900 ⭐',
              onTap: () {},
            ),
            Spacer(),
            Center(
              child: OutlinedButton.icon(
                icon: Icon(Icons.logout),
                onPressed: () {},
                label: Text('Выйти'),
                style: OutlinedButton.styleFrom(foregroundColor: Color(0xFFEF4444)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SubscriptionCard extends StatelessWidget {
  final String title;
  final String price;
  final VoidCallback onTap;

  const SubscriptionCard({super.key, required this.title, required this.price, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 20),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(price, style: TextStyle(fontSize: 16, color: Color(0xFF6366F1))),
              ],
            ),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: Text('Купить'),
            ),
          ],
        ),
      ),
    );
  }
}
