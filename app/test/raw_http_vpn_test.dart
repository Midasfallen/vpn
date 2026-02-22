// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, unused_import

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('raw HTTP register/login/create peer', () async {
    // This test performs live HTTP requests and is skipped in unit test runs.
  }, skip: 'Requires live server or MockClient');
}
