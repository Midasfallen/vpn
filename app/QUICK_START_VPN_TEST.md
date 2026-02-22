# 🎯 QUICK START - VPN Testing

## ✅ Что было развернуто

```
✅ Backend: peers.py с обязательной валидацией wg_public_key
✅ Client: wireguard_helper.dart для генерации ключей на устройстве  
✅ API: Docker контейнер работает на 146.103.99.70:8000
✅ App: APK установлен и работает на Samsung S938B
```

---

## 🧪 КАК ПРОТЕСТИРОВАТЬ VPN

### Шаг 1: Авторизуйтесь
```
Email: test-user@example.com
Password: TestPassword123
```

### Шаг 2: Запустите мониторинг логов (в терминале)
```powershell
cd c:\vpn
python monitor_vpn_test.py
```

### Шаг 3: На устройстве нажмите кнопку VPN

Вы должны увидеть в логах:
```
[DEBUG] Generated WireGuard key pair
[DEBUG] Creating peer with key
[INFO] ✅ WireGuard connected!
```

---

## 🚨 Если не работает

**Проверьте сервер**:
```bash
# 1. Версия кода правильная?
ssh root@146.103.99.70 "sed -n '54,57p' /srv/vpn-api/vpn_api/peers.py"
# Должно быть: raise HTTPException(status_code=400, ...)

# 2. Docker работает?
ssh root@146.103.99.70 "docker compose ps web"
# STATUS должно быть: Up ...

# 3. Логи ошибок?
ssh root@146.103.99.70 "docker compose logs web --tail 50"
```

**Пересоберите APK**:
```powershell
flutter clean
flutter pub get
flutter build apk --flavor dev --debug
flutter install
```

---

## 📊 Документация

- `DEPLOYMENT_FINAL.md` - Полный чеклист
- `DEPLOYMENT_STATUS.md` - Отладка и диагностика
- `DEPLOYMENT_COMPLETE.md` - Что изменилось

---

## ⚡ Быстрые команды

```bash
# Перезагрузить сервис
ssh root@146.103.99.70 "cd /srv/vpn-api && docker compose restart web"

# Посмотреть логи
ssh root@146.103.99.70 "docker compose logs web -f"

# Проверить API
curl -v http://146.103.99.70:8000/docs | head -c 100
```

---

**Готово! Нажмите VPN и проверьте логи 🚀**
