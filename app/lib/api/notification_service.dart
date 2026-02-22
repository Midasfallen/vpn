import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io' show Platform;

/// Сервис для управления локальными уведомлениями о подписке
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Запрос разрешений для iOS
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Запрос разрешений для Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Обработчик нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to subscription screen or handle notification action
    // This can be implemented when navigation service is available
  }

  /// Запланировать уведомление об истечении подписки
  ///
  /// [daysRemaining] - количество дней до истечения подписки
  Future<void> scheduleSubscriptionExpiryNotification({
    required int daysRemaining,
    required DateTime expiryDate,
  }) async {
    await initialize();

    // Уведомление за 7 дней
    if (daysRemaining == 7) {
      await _showNotification(
        id: 1,
        title: 'subscription_expiring_soon'.tr(),
        body: 'days_remaining'.tr(args: ['7']),
      );
    }

    // Уведомление за 3 дня
    if (daysRemaining == 3) {
      await _showNotification(
        id: 2,
        title: 'subscription_expiring_soon'.tr(),
        body: 'days_remaining'.tr(args: ['3']),
      );
    }

    // Уведомление за 1 день
    if (daysRemaining == 1) {
      await _showNotification(
        id: 3,
        title: 'subscription_ends_today'.tr(),
        body: 'subscription_expiring_soon'.tr(),
      );
    }

    // Уведомление при истечении
    if (daysRemaining == 0) {
      await _showNotification(
        id: 4,
        title: 'subscription_ended'.tr(),
        body: 'subscription_expired'.tr(),
      );
    }
  }

  /// Показать уведомление сразу
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'subscription_channel',
      'Subscription Notifications',
      channelDescription: 'Notifications about subscription expiry',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
    );
  }

  /// Проверить статус подписки и показать уведомление если нужно
  Future<void> checkAndNotify({
    required int daysRemaining,
    required DateTime? expiryDate,
  }) async {
    if (expiryDate == null) return;

    // Показываем уведомления только для критических дат
    if (daysRemaining <= 7 && daysRemaining >= 0) {
      await scheduleSubscriptionExpiryNotification(
        daysRemaining: daysRemaining,
        expiryDate: expiryDate,
      );
    }
  }

  /// Отменить все уведомления
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Отменить конкретное уведомление
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}

/// Глобальный экземпляр сервиса уведомлений
final notificationService = NotificationService();
