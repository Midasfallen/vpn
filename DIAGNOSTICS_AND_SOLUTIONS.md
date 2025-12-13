# 🔍 VPN Project — Диагностика двух проблем

**Дата:** 12 декабря 2025  
**Автор:** AI Assistant  
**Статус:** АНАЛИЗ ЗАВЕРШЕН, РЕШЕНИЯ ГОТОВЫ

---

## 📋 Содержание

1. [Проблема #1: Подписка всегда 7 дней](#проблема-1-подписка-всегда-7-дней)
2. [Проблема #2: VPN не включается фактически](#проблема-2-vpn-не-включается-фактически)
3. [Рекомендуемые исправления](#рекомендуемые-исправления)
4. [План реализации](#план-реализации)

---

## 🔴 Проблема #1: Подписка всегда 7 дней

### Анализ Бэка

**Файл:** `/srv/vpn-api/vpn_api/auth.py`  
**Функция:** `get_user_subscription()`

✅ **Статус:** БЭК РАБОТАЕТ КОРРЕКТНО

```python
# Бэк возвращает ПРАВИЛЬНЫЕ данные:
def get_user_subscription(...):
    # ... получает active UserTariff ...
    
    # Вычисляет оставшиеся дни:
    delta = (user_tariff.ended_at - now).days
    days_remaining = max(0, delta)
    
    return {
        "user_id": current_user.id,
        "tariff_id": tariff.id,
        "tariff_name": tariff.name,
        "tariff_duration_days": tariff.duration_days,  # ← Срок ТАРИФА
        "tariff_price": tariff.price,
        "started_at": user_tariff.started_at,
        "ended_at": user_tariff.ended_at,
        "days_remaining": days_remaining,  # ← ОСТАВШИЕСЯ дни
        "is_lifetime": user_tariff.ended_at is None,
    }
```

**Вывод:** Бэк возвращает `days_remaining` правильно!

---

### Анализ Фронта

**Файл:** `lib/api/models.dart`  
**Класс:** `UserSubscriptionOut`

❌ **НАЙДЕНА ПРОБЛЕМА:**

```dart
class UserSubscriptionOut {
  final int id;
  final int userId;
  final int tariffId;
  final String tariffName;
  final String startedAt;
  final String? endedAt;
  final String status;
  final int durationDays;  // ← БЭГ! Это ДЛИТЕЛЬНОСТЬ тарифа, не остаток!
  final String price;

  factory UserSubscriptionOut.fromJson(Map<String, dynamic> json) => UserSubscriptionOut(
    // ...
    durationDays: _calculateDurationDays(json),  // ← Парсит DURATION, не DAYS_REMAINING
    // ...
  );
  
  static int _calculateDurationDays(Map<String, dynamic> json) {
    // Попытается найти 'duration_days' (это 7 дней по умолчанию из тарифа)
    final durationDays = json['duration_days'] as int?;
    if (durationDays != null && durationDays > 0) {
      return durationDays;  // ← ВОЗВРАЩАЕТ 7!
    }
    // ... fallbacks ...
    return 30;  // Default fallback
  }
}
```

**Проблема:** 
- Модель ищет поле `duration_days` (это 7, 30, 365 дней - ДЛИТЕЛЬНОСТЬ тарифа)
- Игнорирует поле `days_remaining` (оставшиеся дни - то, что нужно показывать)
- Результат: всегда показывает 7 дней

**Где отображается:** `lib/subscription_screen.dart` использует `subscription.durationDays`

---

### 🔧 РЕШЕНИЕ #1

Нужно добавить поле `daysRemaining` в модель `UserSubscriptionOut`:

**Файл для изменения:** `lib/api/models.dart`

```dart
class UserSubscriptionOut {
  final int id;
  final int userId;
  final int tariffId;
  final String tariffName;
  final String startedAt;
  final String? endedAt;
  final String status;
  final int durationDays;      // Длительность тарифа (7, 30, 365)
  final int daysRemaining;     // ← НОВОЕ! Оставшиеся дни подписки
  final String price;

  UserSubscriptionOut({
    required this.id,
    required this.userId,
    required this.tariffId,
    required this.tariffName,
    required this.startedAt,
    this.endedAt,
    required this.status,
    required this.durationDays,
    required this.daysRemaining,  // ← НОВОЕ
    required this.price,
  });

  factory UserSubscriptionOut.fromJson(Map<String, dynamic> json) => UserSubscriptionOut(
    id: (json['id'] as int?) ?? -1,
    userId: (json['user_id'] as int?) ?? -1,
    tariffId: (json['tariff_id'] as int?) ?? -1,
    tariffName: json['tariff_name'] as String? ?? 'Unknown',
    startedAt: json['started_at'] as String? ?? '',
    endedAt: json['ended_at'] as String?,
    status: _determineStatus(json),
    durationDays: _calculateDurationDays(json),
    daysRemaining: _calculateDaysRemaining(json),  // ← НОВОЕ
    price: json['price']?.toString() ?? 
           json['tariff_price']?.toString() ?? 
           '0',
  );

  /// Вычислить ОСТАВШИЕСЯ дни подписки
  static int _calculateDaysRemaining(Map<String, dynamic> json) {
    // Попробовать явное поле days_remaining из бэка
    final daysRemaining = json['days_remaining'] as int?;
    if (daysRemaining != null) {
      return daysRemaining;
    }

    // Fallback: вычислить из ended_at
    final endedAt = json['ended_at'] as String?;
    if (endedAt != null && endedAt.isNotEmpty) {
      try {
        final ended = DateTime.parse(endedAt);
        final now = DateTime.now();
        final days = ended.difference(now).inDays;
        return max(0, days);
      } catch (_) {
        // Не могли спарсить дату
      }
    }

    // Fallback: если is_lifetime == true, вернуть большое число
    final isLifetime = json['is_lifetime'] as bool? ?? false;
    if (isLifetime) {
      return 36500;  // ~100 лет
    }

    // Default: нет информации
    return 0;
  }

  // ... остальные методы остаются ...
}
```

Дополнительно, обновить в `subscription_screen.dart` или другом месте, где отображается:

```dart
// БЫЛО:
Text('Days: ${subscription.durationDays}')

// СТАЛО:
Text('Days Remaining: ${subscription.daysRemaining}')
```

---

## 🔴 Проблема #2: VPN не включается фактически

### Анализ Бэка

**Файл:** `/srv/vpn-api/vpn_api/peers.py`

✅ **СТАТУС: БЭК РАБОТАЕТ КОРРЕКТНО**

1. **Создание peer:** `POST /vpn_peers/self`
   - ✅ Создает VpnPeer в БД
   - ✅ Генерирует WireGuard ключи (private, public)
   - ✅ Присваивает IP адрес (wg_ip)
   - ✅ **Генерирует и шифрует конфиг** (`wg_quick`)
   - ✅ Сохраняет конфиг в БД (поле `wg_config_encrypted`)

2. **Получение конфига:** `GET /vpn_peers/self/config`
   - ✅ Находит active peer пользователя
   - ✅ Расшифровывает `wg_config_encrypted`
   - ✅ Возвращает `{"wg_quick": "...конфиг..."}`

**Конфиг выглядит так:**
```
[Interface]
PrivateKey = <private_key>
Address = <wg_ip>

[Peer]
PublicKey = <server_public_key>
AllowedIPs = 0.0.0.0/0
```

---

### Анализ Фронта

**Файл:** `lib/screens/home_screen.dart`  
**Функция:** `_toggleVpn()`

❌ **НАЙДЕНА ПРОБЛЕМА:**

```dart
Future<void> _toggleVpn() async {
  if (_connected) {
    setState(() {
      _connected = false;  // ← UI изменяется
    });
    _expandController.reverse();
    return;  // ← STOP! VPN на самом деле не отключается!
  }

  setState(() {
    _connected = true;  // ← Оптимистичное обновление UI
  });

  try {
    // 1. Получить или создать peer
    final existing = await vpnService.getUserPeerId();
    int pid;
    if (existing == null) {
      final created = await vpnService.createPeer();
      pid = created.id;
    } else {
      pid = existing;
    }

    // 2. "Подключить" (только получить информацию)
    final peerInfo = await vpnService.connectPeer(pid);

    // ❌ STOP! На этом месте заканчивается логика!
    // Нет:
    // - Получения конфига с сервера
    // - Импорта конфига в WireGuard
    // - Фактического включения VPN

    if (!mounted) return;
    setState(() {
      _connected = true;  // ← Только UI говорит что подключено!
    });
    _expandController.forward();
  } catch (e) {
    setState(() {
      _connected = false;
    });
    // ...
  }
}
```

**Проблемы:**
1. ❌ **Нет получения конфига:** `vpnService.fetchWgQuick()` никогда не вызывается
2. ❌ **Нет использования wireguard_flutter:** Плагин вообще не используется
3. ❌ **Это просто UI симуляция:** Переключатель меняет только локальное состояние
4. ❌ **Нет нативной интеграции:** Android/iOS WireGuard не включаются

**Проверка VpnManager:**

```dart
class VpnManager {
  Future<bool> connect(int peerId) async {
    // 1. Получает конфиг ✓
    final config = await vpnService.fetchWgQuick();
    
    // 2. Генерирует имя конфига
    _currentConfigName = 'vpn_flutter_$peerId';
    
    // ❌ НО! Не использует wireguard_flutter плагин!
    // Нет вызова типа:
    // await WireGuardFlutter.instance.create(name: ..., config: ...);
    // await WireGuardFlutter.instance.activate(...);
    
    _isConnected = true;  // ← Только flag в памяти
    return true;
  }
}
```

---

### 🔧 РЕШЕНИЕ #2

Нужна реальная интеграция с `wireguard_flutter` плагином. Вот полный workflow:

#### Шаг 1: Обновить VpnManager для реальной работы

**Файл:** `lib/api/vpn_manager.dart`

```dart
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'logging.dart';
import 'vpn_service.dart';
import 'api_client.dart';

class VpnManager {
  final VpnService vpnService;
  
  bool _isConnected = false;
  String? _currentConfigName;

  bool get isConnected => _isConnected;
  String? get currentConfigName => _currentConfigName;

  VpnManager({required this.vpnService});

  /// Подключиться к VPN с фактическим WireGuard
  Future<bool> connect(int peerId) async {
    try {
      ApiLogger.info('VpnManager: Connecting to peer $peerId');
      
      // 1. Получить конфиг с сервера
      final config = await vpnService.fetchWgQuick();
      if (config.isEmpty) {
        ApiLogger.error('VpnManager: Empty WireGuard config received', null, null);
        return false;
      }
      
      ApiLogger.debug('VpnManager: Config received, length=${config.length}');

      // 2. Сгенерировать уникальное имя конфига
      _currentConfigName = 'vpn_flutter_$peerId';
      
      // 3. Импортировать конфиг в WireGuard
      final configName = _currentConfigName!;
      final tunnel = Tunnel(
        name: configName,
        textConfig: config,
      );
      
      await WireGuardFlutter.instance.create(tunnel: tunnel);
      ApiLogger.info('VpnManager: Config imported as "$configName"');

      // 4. Активировать VPN
      await WireGuardFlutter.instance.activate(tunnel: tunnel);
      ApiLogger.info('VpnManager: VPN tunnel activated');
      
      _isConnected = true;
      return true;
    } on ApiException catch (e) {
      ApiLogger.error('VpnManager: API error: ${e.statusCode}', e, null);
      return false;
    } catch (e) {
      ApiLogger.error('VpnManager: Connection error', e, null);
      return false;
    }
  }

  /// Отключиться от VPN
  Future<bool> disconnect() async {
    try {
      if (_currentConfigName == null) {
        ApiLogger.debug('VpnManager: No active connection to disconnect');
        return true;
      }

      final configName = _currentConfigName!;
      ApiLogger.info('VpnManager: Disconnecting from $configName');
      
      // 1. Деактивировать VPN
      try {
        await WireGuardFlutter.instance.deactivate();
        ApiLogger.info('VpnManager: VPN tunnel deactivated');
      } catch (e) {
        ApiLogger.error('VpnManager: Error deactivating tunnel', e, null);
        // Continue to cleanup even if deactivate fails
      }

      // 2. Удалить конфиг
      try {
        await WireGuardFlutter.instance.delete(tunnelName: configName);
        ApiLogger.info('VpnManager: Config deleted');
      } catch (e) {
        ApiLogger.error('VpnManager: Error deleting config', e, null);
      }

      _isConnected = false;
      _currentConfigName = null;
      
      ApiLogger.info('VpnManager: VPN deactivated successfully');
      return true;
    } catch (e) {
      ApiLogger.debug('VpnManager: Disconnect error: $e');
      return false;
    }
  }

  /// Получить статус подключения
  Future<bool> getStatus() async {
    try {
      // Получить текущий активный туннель
      final activeTunnel = await WireGuardFlutter.instance.activeTunnel();
      final isActive = activeTunnel != null && activeTunnel.name == _currentConfigName;
      
      _isConnected = isActive;
      return isActive;
    } catch (e) {
      ApiLogger.debug('VpnManager: Status check failed: $e');
      return false;
    }
  }

  /// Очистить ресурсы
  Future<void> cleanup() async {
    try {
      if (_isConnected) {
        await disconnect();
      }
    } catch (e) {
      ApiLogger.debug('VpnManager: Cleanup error: $e');
    }
  }
}
```

#### Шаг 2: Обновить HomeScreen для использования VpnManager

**Файл:** `lib/screens/home_screen.dart`

```dart
Future<void> _toggleVpn() async {
  if (_connected) {
    // Отключить VPN
    setState(() {
      _connected = false;
    });
    _expandController.reverse();
    
    try {
      await vpnService.vpnManager?.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('vpn_disconnected'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = mapErrorToMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
    return;
  }

  // Включить VPN
  setState(() {
    _connected = true; // оптимистично
  });

  try {
    // 1. Проверяем, есть ли peer
    final existing = await vpnService.getUserPeerId();
    int pid;
    if (existing == null) {
      ApiLogger.info('HomeScreen: Creating new peer');
      final created = await vpnService.createPeer();
      pid = created.id;
    } else {
      ApiLogger.info('HomeScreen: Using existing peer $existing');
      pid = existing;
    }

    // 2. Получаем информацию о peer (для проверки)
    final peerInfo = await vpnService.connectPeer(pid);
    ApiLogger.info('HomeScreen: Peer info - active=${peerInfo.active}, ip=${peerInfo.wgIp}');

    // 3. ГЛАВНОЕ: Подключаемся через VpnManager
    final vpnManager = vpnService.vpnManager;
    if (vpnManager == null) {
      throw Exception('VPN Manager not initialized');
    }

    final connected = await vpnManager.connect(pid);
    if (!connected) {
      throw Exception('Failed to activate WireGuard');
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
    ApiLogger.error('HomeScreen: VPN connection failed: $e', e, null);
  }
}
```

#### Шаг 3: Инициализировать VpnManager в VpnService

**Файл:** `lib/api/vpn_service.dart`

```dart
class VpnService {
  final ApiClient api;
  late final VpnManager vpnManager;  // ← ДОБАВИТЬ

  VpnService({required this.api}) {
    vpnManager = VpnManager(vpnService: this);  // ← Инициализировать
  }

  // ... остальные методы ...
}
```

---

## 📋 Рекомендуемые исправления

### Приоритет 1 (Критично)

| # | Проблема | Решение | Файл | Строки |
|---|----------|---------|------|--------|
| 1 | Подписка всегда 7 дней | Добавить `daysRemaining` поле в модель | `lib/api/models.dart` | ~110-180 |
| 2 | VPN не включается | Реальная интеграция с `wireguard_flutter` | `lib/api/vpn_manager.dart` | Весь файл |

### Приоритет 2 (Высокий)

| # | Проблема | Решение | Файл |
|---|----------|---------|------|
| 1 | UI не обновляется при отключении | Добавить статус проверку | `lib/screens/home_screen.dart` |
| 2 | Нет обработки ошибок WireGuard | Try-catch на вызовы плагина | `lib/api/vpn_manager.dart` |

---

## 🚀 План реализации

### Фаза 1: Исправление подписки (15 минут)

1. ✏️ Добавить `daysRemaining` в `UserSubscriptionOut`
2. ✏️ Реализовать `_calculateDaysRemaining()` метод
3. ✏️ Обновить UI для показа `daysRemaining` вместо `durationDays`
4. ✅ Тестирование через UI

### Фаза 2: Интеграция VPN (30-45 минут)

1. ✏️ Обновить `vpn_manager.dart` с реальными вызовами `wireguard_flutter`
2. ✏️ Добавить VpnManager в `vpn_service.dart`
3. ✏️ Обновить `_toggleVpn()` в `home_screen.dart`
4. ✅ Тестирование подключения VPN на эмуляторе/устройстве

### Фаза 3: Проверка (15 минут)

1. ✅ Включить/выключить VPN несколько раз
2. ✅ Проверить сетевой трафик через VPN
3. ✅ Проверить логи VPN подключения

---

## ✅ Чек-лист

- [ ] `UserSubscriptionOut.daysRemaining` добавлено
- [ ] `_calculateDaysRemaining()` реализовано
- [ ] `vpn_manager.dart` обновлен с wireguard_flutter
- [ ] `VpnManager` инициализирован в `VpnService`
- [ ] `_toggleVpn()` вызывает `vpnManager.connect()`
- [ ] Error handling добавлен
- [ ] UI тестирование пройдено
- [ ] VPN подключение тестировано на устройстве

---

## 📝 Замечания

### О подписке:
- Бэк уже возвращает правильное значение `days_remaining`
- Проблема только в парсинге на фронте
- После исправления будет работать динамически в зависимости от срока подписки

### О VPN:
- Бэк правильно генерирует и хранит конфиги
- Фронт получает конфиг правильно через `fetchWgQuick()`
- Нужна только интеграция с нативным WireGuard плагином
- После этого VPN будет работать как полноценный туннель

---

## 📞 Вопросы?

Если возникнут проблемы при реализации:
1. Проверьте версию `wireguard_flutter` в `pubspec.yaml`
2. Убедитесь что плагин установлен: `flutter pub get`
3. Проверьте синтаксис импорта класса `Tunnel`
4. Используйте `flutter analyze` для проверки ошибок

