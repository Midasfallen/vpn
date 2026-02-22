import 'package:connectivity_plus/connectivity_plus.dart';

/// Сервис для мониторинга подключения к интернету
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  final List<Function()> _listeners = [];

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal() {
    // Инициализируем монитор подключения
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      // result это List<ConnectivityResult>
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
      if (wasOnline != _isOnline) {
        _notifyListeners();
      }
    });
  }

  /// Проверить, есть ли интернет прямо сейчас
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    // result это List<ConnectivityResult>
    _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
    return _isOnline;
  }

  /// Получить текущий статус (без async проверки)
  bool get isOnline => _isOnline;

  /// Подписаться на изменения подключения
  void addListener(Function() callback) {
    _listeners.add(callback);
  }

  /// Отписаться от изменений подключения
  void removeListener(Function() callback) {
    _listeners.remove(callback);
  }

  /// Уведомить всех слушателей об изменении подключения
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

final connectivityService = ConnectivityService();
