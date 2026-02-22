import 'models.dart';
import 'vpn_service.dart';

/// IAP Service — интеграция с платежными системами (Apple App Store, Google Play)
/// и верификация платежей на бэкенде.
///
/// Поток:
/// 1. Загрузить список тарифов с бэкенда (VpnService.listTariffs())
/// 2. Инициировать покупку через in-app billing систему (не в этом классе)
/// 3. Получить receipt от системы (in-app billing SDK)
/// 4. Отправить receipt на верификацию (verifyReceipt)
/// 5. На успех: бэкенд активирует подписку, возвращает детали
class IapService {
  final VpnService vpnService;

  IapService({required this.vpnService});

  /// Проверить и активировать платёж через App Store (iOS)
  /// 
  /// receipt — Base64-encoded App Store receipt (получен из SKPaymentQueue)
  /// productId — ID продукта, которые покупал пользователь
  Future<IapReceiptVerificationResponse> verifyAppStoreReceipt(
    String receipt,
    String productId,
  ) async {
    try {
      return await vpnService.verifyIapReceipt(
        receipt: receipt,
        provider: 'apple',
        productId: productId,
      );
    } catch (e) {
      throw Exception('Apple receipt verification failed: $e');
    }
  }

  /// Проверить и активировать платёж через Google Play (Android)
  /// 
  /// receipt — Base64-encoded Google Play receipt
  /// packageName — package name приложения
  /// productId — ID продукта
  Future<IapReceiptVerificationResponse> verifyGooglePlayReceipt(
    String receipt,
    String packageName,
    String productId,
  ) async {
    try {
      return await vpnService.verifyIapReceipt(
        receipt: receipt,
        provider: 'google',
        packageName: packageName,
        productId: productId,
      );
    } catch (e) {
      throw Exception('Google Play receipt verification failed: $e');
    }
  }

  /// Получить текущее состояние подписки пользователя
  /// 
  /// Возвращает null если подписка не активна
  Future<UserSubscriptionOut?> getCurrentSubscription() async {
    return await vpnService.getActiveSubscription();
  }

  /// Получить историю платежей пользователя
  /// 
  /// Полезно для отладки и отображения в профиле
  Future<List<PaymentOut>> getPaymentHistory({int limit = 50}) async {
    return await vpnService.listPayments(limit: limit);
  }

  /// Проверить, активна ли текущая подписка
  /// 
  /// true если подписка активна и не истекла
  Future<bool> isSubscriptionActive() async {
    final subscription = await getCurrentSubscription();
    return subscription?.isActive ?? false;
  }

  /// Получить дату окончания текущей подписки
  /// 
  /// null если подписка не активна или не найдена
  Future<DateTime?> getSubscriptionExpiryDate() async {
    final subscription = await getCurrentSubscription();
    if (subscription?.endedAt == null) return null;
    return DateTime.tryParse(subscription!.endedAt!);
  }
}
