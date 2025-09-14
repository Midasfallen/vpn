import 'dart:async';
import 'dart:io';

import '../api/client_instance.dart';

Future<void> main() async {
  // Ensure init
  await initApi();
  final svc = vpnService;

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'test_user_$timestamp@example.com';
  final password = 'Password123!';

  stdout.writeln('Registering user: $email');
  try {
    final user = await svc.register(email, password);
    stdout.writeln('Registered user id=${user.id} email=${user.email}');
  } catch (e) {
    stdout.writeln('Register failed: $e');
    exit(1);
  }

  stdout.writeln('Logging in...');
  try {
    final token = await svc.login(email, password);
    stdout.writeln('Login success token length=${token.length}');
  } catch (e) {
    stdout.writeln('Login failed: $e');
    exit(1);
  }

  stdout.writeln('Calling /auth/me...');
  try {
    final me = await svc.me();
    stdout.writeln('Me: id=${me.id} email=${me.email} status=${me.status}');
  } catch (e) {
    stdout.writeln('/auth/me failed: $e');
  }

  stdout.writeln('Listing peers...');
  try {
    final peers = await svc.listPeers();
    stdout.writeln('Peers count=${peers.length}');
    for (final p in peers) {
      stdout.writeln('- peer id=${p.id} user_id=${p.userId} ip=${p.wgIp}');
    }
  } catch (e) {
    stdout.writeln('listPeers failed: $e');
  }

  stdout.writeln('Smoke test finished');
}
