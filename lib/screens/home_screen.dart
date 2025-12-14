import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../api/client_instance.dart';
import '../api/error_mapper.dart';
import '../api/token_storage.dart';
import '../api/connectivity_service.dart';
import '../api/models.dart';
import '../theme/colors.dart';

/// HomeScreen - главный экран приложения с переключателем VPN и управлением подписками
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _connected = false;
  bool _isOnline = true;
  bool _hasActiveSubscription = false;
  DateTime? _subscriptionEnd;
  UserSubscriptionOut? _subscription; // Сохраняем полный объект подписки
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    // Попытаться найти существующий peer у пользователя
    _loadPeer();
    // Загружаем статус подписки
    _loadSubscriptionStatus();
    // Слушаем изменения подключения к интернету
    connectivityService.addListener(_onConnectivityChanged);
    _checkConnectivity();
    // Инициализируем контроллер расширения (анимация растекания цвета)
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _expandAnimation = CurvedAnimation(parent: _expandController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _expandController.dispose();
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

  Future<void> _loadSubscriptionStatus() async {
    try {
      print('[DEBUG] HomeScreen._loadSubscriptionStatus() starting...');
      final subscription = await vpnService.getActiveSubscription();
      print('[DEBUG] HomeScreen loaded subscription: $subscription');
      
      if (subscription == null) {
        print('[DEBUG] Subscription is NULL - no active subscription');
      } else {
        print('[DEBUG] Subscription found:');
        print('[DEBUG]   - status: ${subscription.status}');
        print('[DEBUG]   - endedAt: ${subscription.endedAt}');
        print('[DEBUG]   - tariffName: ${subscription.tariffName}');
        print('[DEBUG]   - durationDays: ${subscription.durationDays}');
      }
      
      if (mounted) {
        setState(() {
          _subscription = subscription;
          if (subscription != null && subscription.status == 'active') {
            _hasActiveSubscription = true;
            print('[DEBUG] Setting _hasActiveSubscription = true');
            // Parse endedAt to DateTime if it's not null and not empty
            if (subscription.endedAt != null && subscription.endedAt!.isNotEmpty) {
              try {
                _subscriptionEnd = DateTime.parse(subscription.endedAt!);
                print('[DEBUG] Parsed subscription end date: $_subscriptionEnd');
              } catch (e) {
                print('[DEBUG] Failed to parse endedAt date: $e');
                _subscriptionEnd = null;
              }
            } else {
              _subscriptionEnd = null;
            }
          } else {
            _hasActiveSubscription = false;
            _subscriptionEnd = null;
            print('[DEBUG] Setting _hasActiveSubscription = false (subscription is null or not active)');
          }
        });
      }
    } catch (e, stackTrace) {
      print('[ERROR] Failed to load subscription status: $e');
      print('[ERROR] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _hasActiveSubscription = false;
          _subscriptionEnd = null;
          _subscription = null;
        });
      }
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
      // Отключаемся от VPN
      setState(() {
        _connected = false;
      });
      _expandController.reverse();
      
      try {
        // Отключаем VPN через VpnManager
        await vpnService.vpnManager.disconnect();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('vpn_disconnected'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          final msg = mapErrorToMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
      return;
    }

    // Подключаемся к VPN
    setState(() {
      _connected = true; // оптимистично
    });

    try {
      // 1. Проверяем, есть ли peer у пользователя и создаём если нужно
      final existing = await vpnService.getUserPeerId();
      if (existing == null) {
        await vpnService.createPeer();
      }

      // 2. Инициализируем WireGuard интерфейс (один раз перед первым подключением)
      // Это можно вызвать один раз при запуске приложения, но обычно безопасно вызывать несколько раз
      final initSuccess = await vpnService.vpnManager.initialize();
      if (!initSuccess) {
        throw Exception('VPN initialization failed');
      }

      // 3. ГЛАВНОЕ: Подключаемся через VpnManager с использованием wireguard_flutter
      // Адрес сервера WireGuard (IP:PORT фиксированный для всех пользователей)
      const serverAddress = '62.84.98.109:51820';
      final connected = await vpnService.vpnManager.connect(serverAddress);
      
      if (!connected) {
        throw Exception('Failed to activate WireGuard VPN');
      }

      if (!mounted) return;
      setState(() {
        _connected = true;
      });
      _expandController.forward();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('vpn_connected'.tr(args: ['active'])),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _connected = false;
      });
      final msg = mapErrorToMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // TODO: Implement VPN expiration warning in future

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final progress = _expandAnimation.value;
        final bgColor = Color.lerp(
          AppColors.darkBg,
          AppColors.accentGold,
          _connected ? progress : 0.0,
        ) ?? AppColors.darkBg;

        return Scaffold(
          backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Incamp VPN'),
        backgroundColor: AppColors.darkBgSecondary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Offline banner
            if (!_isOnline)
              Container(
                color: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 20, color: AppColors.darkBg),
                    const SizedBox(width: 8),
                    Text(
                      'offline_mode'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.darkBg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Карточка подписки (с дизайном свечения)
                  if (_hasActiveSubscription && _subscription != null)
                    _buildSubscriptionCard()
                  else
                    _buildNoSubscriptionCard(),
                  const SizedBox(height: 28),
                  
                  // Кнопка "Купить подписку" - золотая изначально, чёрная при подключении
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _connected ? Colors.black : AppColors.accentGold,
                      foregroundColor: _connected ? AppColors.accentGold : AppColors.darkBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final refreshNeeded = await Navigator.pushNamed(context, '/subscription');
                      // Если пользователь активировал подписку, обновляем статус
                      if (refreshNeeded == true && mounted) {
                        await _loadSubscriptionStatus();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'buy_subscription'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Кнопка "Выбрать приложения" - золотая изначально, чёрная при подключении
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _connected ? Colors.black : AppColors.accentGold,
                      side: BorderSide(
                        color: _connected ? Colors.black : AppColors.accentGold,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('select_apps_stub'.tr()),
                          backgroundColor: AppColors.info,
                        ),
                      );
                    },
                    label: Text(
                      'select_apps'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // VPN Toggle Button - золотой фон с чёрной иконкой, при подключении: чёрный фон с золотой иконкой
                  Center(
                    child: GestureDetector(
                      onTap: _toggleVpn,
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: _connected ? Colors.black : AppColors.accentGold,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_connected ? Colors.black : AppColors.accentGold).withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/ea866ac6-8957-42ea-a843-e4eda0e6d9b7-removebg-preview (1).png',
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                                color: _connected ? AppColors.accentGold : Colors.black,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 8, bottom: 12),
          child: OutlinedButton.icon(
            key: const Key('logout-button'),
            icon: const Icon(Icons.logout),
            label: Text(
              'logout'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await _logout();
            },
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard() {
    if (_subscription == null) {
      return _buildNoSubscriptionCard();
    }

    final durationDays = _subscription!.durationDays;
    final isLifetime = _subscription!.endedAt == null;
    final tariffName = _subscription!.tariffName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'subscription_active'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tariff name
            Text(
              tariffName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            // Duration
            Text(
              isLifetime
                  ? 'lifetime_access'.tr()
                  : '$durationDays ${'days'.tr()}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            // Warning if expiring soon
            if (!isLifetime && durationDays < 7)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    'subscription_expiring_soon'.tr(),
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.card_giftcard,
                size: 32,
                color: AppColors.textTertiary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                'no_active_subscription'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
