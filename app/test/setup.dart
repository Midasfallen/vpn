import 'package:vpn/config/environment.dart';

void setUpAll() {
  // Инициализируем Environment для тестов
  Environment.initialize(flavor: 'dev');
}
