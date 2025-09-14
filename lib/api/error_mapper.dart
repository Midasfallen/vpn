import 'dart:convert';
import 'api_client.dart';
import 'package:easy_localization/easy_localization.dart';

/// Преобразует ApiException/Exception в локализованное сообщение для пользователя.
String mapErrorToMessage(Object e) {
  try {
    if (e is ApiException) {
      final status = e.statusCode;
      final body = e.body;
      // Попробуем распарсить JSON тело, если оно JSON
      dynamic parsed;
      try {
        parsed = jsonDecode(body);
      } catch (_) {
        parsed = body;
      }

      // 401 Unauthorized
      if (status == 401) return 'invalid_credentials'.tr();

      // 422 Unprocessable Entity — часто ошибки валидации (FastAPI)
      if (status == 422) {
        // parsed может быть объектом с полем detail: [ {"loc": [...], "msg": "..."}, ... ]
        try {
          if (parsed is Map && parsed['detail'] is List && parsed['detail'].isNotEmpty) {
            final first = parsed['detail'][0];
            if (first is Map && first['msg'] != null) {
              final msg = first['msg'].toString();
              if (msg.toLowerCase().contains('email')) return 'Введите корректный email.';
              return 'Ошибка данных: $msg';
            }
          }
        } catch (_) {}
        // fallback
        return 'server_error'.tr();
      }

      // 400 Bad Request — например длина пароля
      if (status == 400) {
        try {
          if (parsed is Map && parsed['detail'] is String) {
            final detail = parsed['detail'] as String;
            if (detail.toLowerCase().contains('password') && detail.contains('8')) {
              return 'password_min_length'.tr();
            }
            if (detail.toLowerCase().contains('email') && detail.toLowerCase().contains('already')) {
              return 'email_already_registered'.tr();
            }
            return detail;
          }
        } catch (_) {}
        if (body.toLowerCase().contains('password') && body.contains('8')) {
          return 'password_min_length'.tr();
        }
        if (body.toLowerCase().contains('email') && body.toLowerCase().contains('already')) {
          return 'email_already_registered'.tr();
        }
        return 'server_error'.tr();
      }

      // По умолчанию возвращаем тело ошибки в удобной форме
      if (body.isNotEmpty) {
        // translate some common server messages
        final lower = body.toLowerCase();
        if (lower.contains('invalid credentials')) return 'invalid_credentials'.tr();
        if (lower.contains('email') && lower.contains('already')) return 'email_already_registered'.tr();
        return '${'server_error'.tr()}: $body';
      }
      return 'server_error'.tr();
    }

    // Если это не ApiException — обычный Exception
    if (e is Exception) {
      final s = e.toString();
      if (s.toLowerCase().contains('socket') || s.toLowerCase().contains('socketexception')) {
        return 'network_error'.tr();
      }
      return '${'server_error'.tr()}: $s';
    }
  } catch (_) {}
  return 'server_error'.tr();
}

/// Парсит структуру ошибок от API и возвращает карту field -> list of messages.
Map<String, List<String>> parseFieldErrors(Object e) {
  final Map<String, List<String>> out = {};

  String translate(String msg) {
    final low = msg.toLowerCase();
    if (low.contains('invalid credentials')) return 'invalid_credentials'.tr();
    if (low.contains('email') && low.contains('already')) return 'email_already_registered'.tr();
    if (low.contains('password') && low.contains('8')) return 'password_min_length'.tr();
    // common phrase variations
    if (low.contains('already registered') || low.contains('already regist')) return 'email_already_registered'.tr();
    return msg;
  }

  try {
    if (e is ApiException) {
      dynamic parsed;
      try {
        parsed = jsonDecode(e.body);
      } catch (_) {
        parsed = null;
      }

      if (parsed is Map) {
        // FastAPI style: {"detail": [{"loc": ["body","email"], "msg": "..."}, ... ]}
        if (parsed['detail'] is List) {
          for (final item in parsed['detail']) {
            try {
              if (item is Map) {
                final loc = item['loc'];
                String field = '';
                if (loc is List && loc.isNotEmpty) {
                  // try to find a likely field name in loc
                  for (final part in loc.reversed) {
                    if (part is String && part != 'body') {
                      field = part;
                      break;
                    }
                  }
                  if (field.isEmpty && loc.isNotEmpty) field = loc.last.toString();
                }
                final rawMsg = (item['msg'] ?? item['detail'] ?? '').toString();
                final msg = translate(rawMsg);
                if (field.isEmpty) {
                  out.putIfAbsent('_form', () => []).add(msg);
                } else {
                  out.putIfAbsent(field, () => []).add(msg);
                }
              }
            } catch (_) {}
          }
        }

        // alternative format: {"errors": {"email": ["..."], "password": ["..."]}}
        if (parsed['errors'] is Map) {
          final errMap = parsed['errors'] as Map;
          errMap.forEach((k, v) {
            try {
              if (v is List) {
                for (final msgRaw in v) {
                  final msg = translate(msgRaw.toString());
                  out.putIfAbsent(k.toString(), () => []).add(msg);
                }
              } else if (v is String) {
                out.putIfAbsent(k.toString(), () => []).add(translate(v));
              }
            } catch (_) {}
          });
        }

        // if there is a string detail
        if (out.isEmpty && parsed['detail'] is String) {
          out.putIfAbsent('_form', () => []).add(translate(parsed['detail'].toString()));
        }
      } else {
        // parsed not map — try to translate raw body string
        final rawString = e.body.toString();
        if (rawString.isNotEmpty) {
          final t = translate(rawString);
          out.putIfAbsent('_form', () => []).add(t);
        }
      }
    }
  } catch (_) {}
  return out;
}
