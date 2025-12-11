import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../api/client_instance.dart';
import '../api/error_mapper.dart';
import '../api/token_storage.dart';
import '../api/connectivity_service.dart';
import '../api/models.dart';

/// HomeScreen - главный экран приложения с переключателем VPN и управлением подписками
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _connected = false;
  bool _isOnline = true;
  bool _hasActiveSubscription = false;
  DateTime? _subscriptionEnd;
  UserSubscriptionOut? _subscription; // Сохраняем полный объект подписки

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
      setState(() {
        _connected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('vpn_disconnected'.tr())),
        );
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('vpn_connected'.tr(args: [statusText])),
        ),
      );
    } catch (e) {
      setState(() {
        _connected = false;
      });
      final msg = mapErrorToMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  bool _isExpired() {
    final now = DateTime.now();
    return _hasActiveSubscription && (_subscriptionEnd == null || _subscriptionEnd!.isBefore(now));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
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
                    const Icon(Icons.wifi_off, size: 20, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      'offline_mode'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Карточка подписки
                  if (_hasActiveSubscription && _subscription != null)
                    _buildSubscriptionCard()
                  else
                    _buildNoSubscriptionCard(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                          Text('buy_subscription'.tr()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: GestureDetector(
                      onTap: _toggleVpn,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _connected
                                ? const [Color(0xFF6366F1), Color(0xFF4F46E5)]
                                : const [
                                    Color(0xFFCBD5E1),
                                    Color(0xFF94A3B8),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_connected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFFCBD5E1))
                                  .withAlpha(60),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            _connected ? Icons.lock_open : Icons.lock,
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.tune),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                        elevation: 0,
                        side: const BorderSide(
                          color: Color(0xFF6366F1),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        // Заглушка: позже реализуем platform channel для открытия системного окна Android
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('select_apps_stub'.tr()),
                          ),
                        );
                      },
                      label: Text('select_apps'.tr()),
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
          icon: const Icon(Icons.logout),
          label: Text('logout'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            await _logout();
          },
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    if (_subscription == null) {
      return _buildNoSubscriptionCard();
    }

    final durationDays = _subscription!.durationDays;
    final isLifetime = _subscription!.endedAt == null;
    final tariffName = _subscription!.tariffName;

    return Card(
      elevation: 0,
      color: const Color(0xFFD6E6FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'subscription_active'.tr(),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tariffName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isLifetime)
                  Text(
                    '$durationDays ${'days'.tr()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                      fontSize: 15,
                    ),
                  )
                else
                  Text(
                    'lifetime_access'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
            if (!isLifetime && durationDays < 7)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'subscription_expiring_soon'.tr(),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Center(
          child: Text(
            'no_active_subscription'.tr(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
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
