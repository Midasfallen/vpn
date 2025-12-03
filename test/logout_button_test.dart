// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, unused_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Logout navigates to login', (WidgetTester tester) async {
    // Ключ для экрана логина
    const loginScreenKey = Key('login-screen');

    // Строим MaterialApp с маршрутами
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/home',
      routes: {
        '/home': (_) => Scaffold(
          body: ElevatedButton(
            key: const Key('logout-button'),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  tester.element(find.byType(ElevatedButton)), '/login', (route) => false);
            },
            child: const Text('Купить подписку'),
          ),
        ),
        '/login': (_) => const Scaffold(
          key: loginScreenKey,
          body: Center(child: Text('Login Screen')),
        ),
      },
    ));

    await tester.pumpAndSettle();

    // Проверяем, что главный экран загрузился
    expect(find.text('Купить подписку'), findsOneWidget);

    // Нажимаем кнопку выхода
    final logoutButton = find.byKey(const Key('logout-button'));
    expect(logoutButton, findsOneWidget);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle(); // Ждём завершения навигации

    // Проверяем, что экран логина появился
    expect(find.byKey(const Key('login-screen')), findsOneWidget);
  });
}
