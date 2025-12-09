class UserCreate {
  final String email;
  final String password;
  UserCreate({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class UserLogin {
  final String email;
  final String password;
  UserLogin({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class UserOut {
  final int id;
  final String email;
  final String status;
  final bool isAdmin;
  final String createdAt;

  UserOut({required this.id, required this.email, required this.status, required this.isAdmin, required this.createdAt});

  factory UserOut.fromJson(Map<String, dynamic> json) => UserOut(
    id: json['id'] as int,
    email: json['email'] as String,
    status: json['status'] as String,
    isAdmin: json['is_admin'] as bool? ?? false,
    createdAt: json['created_at'] as String,
  );
}

class TariffOut {
  final int id;
  final String name;
  final String description;
  final int durationDays;
  final String price;

  TariffOut({required this.id, required this.name, required this.description, required this.durationDays, required this.price});

  factory TariffOut.fromJson(Map<String, dynamic> json) => TariffOut(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description']?.toString() ?? '',
    durationDays: json['duration_days'] as int,
    price: json['price'].toString(),
  );
}

class VpnPeerOut {
  final int id;
  final int userId;
  final String wgPublicKey;
  final String wgIp;
  final String? allowedIps;
  final bool active;
  final String createdAt;
  final String? wgPrivateKey; // returned once on creation

  VpnPeerOut({required this.id, required this.userId, required this.wgPublicKey, required this.wgIp, this.allowedIps, required this.active, required this.createdAt, this.wgPrivateKey});

  factory VpnPeerOut.fromJson(Map<String, dynamic> json) => VpnPeerOut(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    wgPublicKey: json['wg_public_key'] as String,
    wgIp: json['wg_ip'] as String,
    allowedIps: json['allowed_ips']?.toString(),
    active: json['active'] as bool,
    createdAt: json['created_at'] as String,
    wgPrivateKey: json['wg_private_key']?.toString(),
  );
}

// === IAP & Payment Models ===

class PaymentOut {
  final int id;
  final int? userId;
  final String amount;
  final String currency;
  final String status; // pending, completed, failed, refunded
  final String? provider; // apple, google, stripe, etc
  final String? providerPaymentId;
  final String createdAt;

  PaymentOut({
    required this.id,
    this.userId,
    required this.amount,
    required this.currency,
    required this.status,
    this.provider,
    this.providerPaymentId,
    required this.createdAt,
  });

  factory PaymentOut.fromJson(Map<String, dynamic> json) => PaymentOut(
    id: json['id'] as int,
    userId: json['user_id'] as int?,
    amount: json['amount']?.toString() ?? '0',
    currency: json['currency'] as String? ?? 'USD',
    status: json['status'] as String,
    provider: json['provider'] as String?,
    providerPaymentId: json['provider_payment_id'] as String?,
    createdAt: json['created_at'] as String,
  );
}

class UserSubscriptionOut {
  final int id;
  final int userId;
  final int tariffId;
  final String tariffName;
  final String startedAt;
  final String? endedAt;
  final String status; // active, expired, cancelled
  final int durationDays;
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
    required this.price,
  });

  factory UserSubscriptionOut.fromJson(Map<String, dynamic> json) => UserSubscriptionOut(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    tariffId: json['tariff_id'] as int,
    tariffName: json['tariff_name'] as String? ?? 'Unknown',
    startedAt: json['started_at'] as String,
    endedAt: json['ended_at'] as String?,
    status: json['status'] as String,
    durationDays: json['duration_days'] as int? ?? 30,
    price: json['price']?.toString() ?? '0',
  );

  bool get isActive {
    if (status != 'active') return false;
    if (endedAt == null) return true;
    final ended = DateTime.tryParse(endedAt ?? '');
    return ended != null && ended.isAfter(DateTime.now());
  }
}

class IapReceiptVerificationRequest {
  final String receipt; // Base64-encoded receipt from device
  final String provider; // 'apple' or 'google'
  final String? packageName; // For Google Play
  final String? productId;

  IapReceiptVerificationRequest({
    required this.receipt,
    required this.provider,
    this.packageName,
    this.productId,
  });

  Map<String, dynamic> toJson() => {
    'receipt': receipt,
    'provider': provider,
    if (packageName != null) 'package_name': packageName,
    if (productId != null) 'product_id': productId,
  };
}

class IapReceiptVerificationResponse {
  final bool valid;
  final int? userId;
  final int? paymentId;
  final String? message;
  final PaymentOut? payment;
  final UserSubscriptionOut? subscription;

  IapReceiptVerificationResponse({
    required this.valid,
    this.userId,
    this.paymentId,
    this.message,
    this.payment,
    this.subscription,
  });

  factory IapReceiptVerificationResponse.fromJson(Map<String, dynamic> json) => IapReceiptVerificationResponse(
    valid: json['valid'] as bool? ?? false,
    userId: json['user_id'] as int?,
    paymentId: json['payment_id'] as int?,
    message: json['message'] as String?,
    payment: json['payment'] != null ? PaymentOut.fromJson(json['payment'] as Map<String, dynamic>) : null,
    subscription: json['subscription'] != null ? UserSubscriptionOut.fromJson(json['subscription'] as Map<String, dynamic>) : null,
  );
}
