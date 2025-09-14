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

  VpnPeerOut({required this.id, required this.userId, required this.wgPublicKey, required this.wgIp, this.allowedIps, required this.active, required this.createdAt});

  factory VpnPeerOut.fromJson(Map<String, dynamic> json) => VpnPeerOut(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    wgPublicKey: json['wg_public_key'] as String,
    wgIp: json['wg_ip'] as String,
    allowedIps: json['allowed_ips']?.toString(),
    active: json['active'] as bool,
    createdAt: json['created_at'] as String,
  );
}
