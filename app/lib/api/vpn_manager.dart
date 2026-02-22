import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'logging.dart';
import 'vpn_service.dart';
import 'api_client.dart';

/// VPN менеджер с интеграцией WireGuard
/// Использует реальное API wireguard_flutter 0.1.3:
/// - initialize(interfaceName) → настройка интерфейса
/// - startVpn(serverAddress, wgQuickConfig, providerBundleIdentifier) → запуск
/// - stopVpn() → остановка
/// - isConnected() → проверка статуса
/// - stage() → получить VpnStage (connected/connecting/disconnected и т.д.)
/// - vpnStageSnapshot → Stream с изменениями статуса
class VpnManager {
  final VpnService vpnService;
  
  bool _isConnected = false;
  String? _currentServerAddress;
  
  // Константы для WireGuard конфига
  static const String _interfaceName = 'wg0';
  static const String _providerBundleIdentifier = 'com.example.vpn';

  bool get isConnected => _isConnected;
  String? get currentServerAddress => _currentServerAddress;

  VpnManager({required this.vpnService});

  /// Инициализировать WireGuard интерфейс
  /// Должна быть вызвана один раз перед первым подключением
  Future<bool> initialize() async {
    try {
      ApiLogger.info('VpnManager: Инициализирую WireGuard интерфейс $_interfaceName');
      await WireGuardFlutter.instance.initialize(
        interfaceName: _interfaceName,
      );
      ApiLogger.info('VpnManager: WireGuard интерфейс инициализирован успешно');
      return true;
    } catch (e) {
      ApiLogger.error('VpnManager: Ошибка инициализации WireGuard: $e', null, null);
      return false;
    }
  }

  /// Подключиться к VPN с конфигом WireGuard
  /// Требует: initialize() вызван предварительно
  Future<bool> connect(String serverAddress) async {
    try {
      ApiLogger.info('VpnManager: Подключение к серверу: $serverAddress');
      
      // 1. Получить конфиг с сервера
      final wgQuickConfig = await vpnService.fetchWgQuick();
      if (wgQuickConfig.isEmpty) {
        ApiLogger.error('VpnManager: Получен пустой конфиг WireGuard', null, null);
        return false;
      }
      
      ApiLogger.debug('VpnManager: Конфиг получен, размер=${wgQuickConfig.length} байт');
      ApiLogger.debug('VpnManager: Конфиг:\n$wgQuickConfig');
      
      // 2. Проверить формат конфига
      if (!wgQuickConfig.contains('[Interface]') || !wgQuickConfig.contains('[Peer]')) {
        ApiLogger.error('VpnManager: Некорректный формат wg-quick конфига', null, null);
        return false;
      }

      // 3. Запустить VPN через WireGuard
      ApiLogger.info('VpnManager: Запускаю VPN с конфигом');
      await WireGuardFlutter.instance.startVpn(
        serverAddress: serverAddress,
        wgQuickConfig: wgQuickConfig,
        providerBundleIdentifier: _providerBundleIdentifier,
      );
      
      _currentServerAddress = serverAddress;
      _isConnected = true;
      ApiLogger.info('VpnManager: VPN успешно запущен');
      
      return true;
    } on ApiException catch (e) {
      ApiLogger.error('VpnManager: Ошибка API при подключении: ${e.statusCode}', e, null);
      _isConnected = false;
      return false;
    } catch (e) {
      ApiLogger.error('VpnManager: Ошибка подключения VPN: $e', null, null);
      _isConnected = false;
      return false;
    }
  }

  /// Отключиться от VPN
  Future<bool> disconnect() async {
    try {
      if (!_isConnected) {
        ApiLogger.debug('VpnManager: VPN уже отключен');
        return true;
      }

      ApiLogger.info('VpnManager: Отключаюсь от VPN');
      
      try {
        await WireGuardFlutter.instance.stopVpn();
        ApiLogger.info('VpnManager: VPN успешно остановлен');
      } catch (e) {
        ApiLogger.error('VpnManager: Ошибка при остановке VPN: $e', null, null);
        // Продолжаем очистку несмотря на ошибку
      }

      _isConnected = false;
      _currentServerAddress = null;
      
      return true;
    } catch (e) {
      ApiLogger.error('VpnManager: Ошибка отключения VPN: $e', null, null);
      return false;
    }
  }

  /// Получить текущий статус подключения
  Future<bool> getStatus() async {
    try {
      // Используем isConnected() для быстрой проверки
      final connected = await WireGuardFlutter.instance.isConnected();
      
      if (connected != _isConnected) {
        ApiLogger.debug('VpnManager: Статус изменился на $connected');
        _isConnected = connected;
      }
      return connected;
    } catch (e) {
      ApiLogger.debug('VpnManager: Ошибка проверки статуса: $e');
      return _isConnected;
    }
  }

  /// Получить детальный статус VPN (VpnStage)
  /// Возвращает одно из значений:
  /// connected, connecting, disconnecting, disconnected, waitingConnection,
  /// authenticating, reconnect, noConnection, preparing, denied, exiting
  Future<VpnStage?> getStage() async {
    try {
      final stage = await WireGuardFlutter.instance.stage();
      ApiLogger.debug('VpnManager: VPN stage=$stage');
      return stage;
    } catch (e) {
      ApiLogger.debug('VpnManager: Ошибка получения stage: $e');
      return null;
    }
  }

  /// Получить Stream с изменениями статуса VPN
  /// Слушает изменения в реальном времени:
  /// vpnManager.watchStageChanges().listen((stage) {
  ///   print('VPN статус: $stage');
  /// });
  Stream<VpnStage> watchStageChanges() {
    try {
      return WireGuardFlutter.instance.vpnStageSnapshot;
    } catch (e) {
      ApiLogger.error('VpnManager: Ошибка при подписке на изменения stage: $e', null, null);
      // Возвращаем пустой stream в случае ошибки
      return Stream.empty();
    }
  }

  /// Обновить статус VPN (если нужна синхронизация)
  Future<void> refreshStage() async {
    try {
      await WireGuardFlutter.instance.refreshStage();
      ApiLogger.debug('VpnManager: Stage обновлена');
    } catch (e) {
      ApiLogger.debug('VpnManager: Ошибка при refresh stage: $e');
    }
  }

  /// Очистить ресурсы при выходе из приложения
  Future<void> cleanup() async {
    try {
      if (_isConnected) {
        ApiLogger.info('VpnManager: Выполняю очистку, отключаюсь от VPN');
        await disconnect();
      }
    } catch (e) {
      ApiLogger.error('VpnManager: Ошибка при очистке: $e', null, null);
    }
  }
}
