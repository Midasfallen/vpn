# Руководство Claude по работе с VPN проектом

## ОБЩИЕ ПРАВИЛА РАБОТЫ

1. **Язык общения**: ТОЛЬКО русский язык во всех ответах и комментариях
2. **Автономность**: Делать все самостоятельно, без лишних вопросов пользователю
3. **Инициативность**: Проверять результаты, исправлять ошибки, доводить задачи до конца
4. **Логирование**: Использовать ASCII символы [OK], [ERROR], [DEBUG] (не ✓, ✗ - проблемы с Windows)

## АРХИТЕКТУРА ПРОЕКТА

### Flutter Frontend (C:\vpn\)
- **Репозиторий**: Локальная разработка без GitHub
- **API**: `http://146.103.99.70:8000` (production backend)
- **Архитектура**:
  - UI: `lib/screens/` (home_screen.dart, subscription_screen.dart)
  - API клиент: `lib/api/api_client.dart` (HTTP wrapper с retry, 401 refresh)
  - Сервисы: `lib/api/vpn_service.dart` (бизнес-логика)
  - Модели: `lib/api/models.dart` (UserOut, VpnPeerOut, TariffOut - БЕЗ кодогенерации)
- **Ключевые зависимости**:
  - `flutter_secure_storage` - хранение токенов
  - `easy_localization` - i18n (en/ru)
  - `wireguard_flutter` - WireGuard интеграция

### Python Backend (C:\vpn-backend\vpn_api\)
- **Репозиторий**: https://github.com/Midasfallen/vpn-api
- **Деплой**: Автоматический из GitHub на сервер 146.103.99.70
- **Ключевые файлы**:
  - `vpn_api/auth.py` - регистрация, логин, подписки
  - `vpn_api/peers.py` - управление WireGuard peer'ами
  - `vpn_api/models.py` - SQLAlchemy модели
- **База данных**: PostgreSQL на 146.103.99.70:5432

### Серверная инфраструктура

**Backend сервер**: `ssh root@146.103.99.70`
- Docker контейнер: `vpn-api-web-1`
- Деплой: `cd /srv/vpn-api && git reset --hard HEAD && git pull origin main && docker compose up -d --no-deps --build web`
- Логи: `docker logs vpn-api-web-1 --tail 30`

**WireGuard VPN сервер**: `ssh root@62.84.98.109`
- **OS**: Ubuntu 22.04.5 LTS (Linux 5.15.0-134-generic)
- **WG-Easy UI**: http://62.84.98.109:8588/
- **WireGuard порт**: 51821 (не 51820!)
- **Server Public Key**: `1SUivFxEBdU5SjpL2cLBykv/4HcotWpIrdSUGFDGIA8=`
- **Server Private Key**: `KBkdZlfktuWoW08beynJEB82lDPZiKHhc9+W3xzvZFQ=`
- **VPN подсеть**: 10.8.0.0/24 (клиенты получают IP 10.8.0.2-10.8.0.254)
- **Сетевой интерфейс**: ens3 (62.84.98.109/24, gateway 62.84.98.1)
- **Конфигурация хранится**: `/root/wg-easy/etc/wg0.conf`
- **Docker контейнер**: `wg-easy` (ghcr.io/wg-easy/wg-easy:latest)
- **WG-Easy запускается**:
  ```bash
  docker run --name=wg-easy \
    --volume /root/wg-easy/etc:/etc/wireguard \
    --volume /root/wg-easy/lib:/var/lib/wireguard \
    --env=WG_HOST=62.84.98.109 \
    --env=WG_PORT=51821 \
    --env=WG_MTU=1420 \
    --env='PASSWORD_HASH=$2b$12$BFf.9DOxi4aNrLsYjv1jU.TPHVTq6TvHoYDbz2tgvV5caUFHygbyW' \
    --network=host \
    --privileged \
    --restart unless-stopped \
    --detach \
    ghcr.io/wg-easy/wg-easy:latest
  ```

**КРИТИЧЕСКИЕ iptables правила для VPN** (добавлены вручную, не через WG-Easy):
```bash
# NAT для интернета через VPN (обязательно!)
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens3 -j MASQUERADE

# FORWARD rules для трафика VPN клиентов (обязательно!)
iptables -I FORWARD 1 -i wg0 -o ens3 -j ACCEPT
iptables -I FORWARD 2 -i ens3 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранение правил (если установлен iptables-persistent)
iptables-save > /etc/iptables/rules.v4
```

**ВАЖНО**: WG-Easy автоматически добавляет правила через PostUp/PostDown в wg0.conf,
НО они используют `eth0` вместо `ens3`, поэтому не работают! Нужны ручные правила выше.

**Пароль для серверов**: `fwPSsiYwd2x1`

**Тестовые аккаунты**:
- fluttertest_861883@test.com / TestPassword123
- mrpenis@mail.com / testtest1

## КРИТИЧЕСКИЕ ПАТТЕРНЫ КОДА

### 1. Обработка null в JSON десериализации
**ОБЯЗАТЕЛЬНО**: Все `fromJson()` методы должны обрабатывать null:

```dart
// ПРАВИЛЬНО
factory TariffOut.fromJson(Map<String, dynamic> json) => TariffOut(
  id: json['id'] as int? ?? -1,
  name: json['name'] as String? ?? 'Unknown',
  durationDays: (json['duration_days'] as int?) ?? 30,
);

// НЕПРАВИЛЬНО - упадет на null
factory TariffOut.fromJson(Map<String, dynamic> json) => TariffOut(
  id: json['id'] as int,  // ERROR!
);
```

### 2. Mapper паттерн для API запросов
```dart
// Всегда проверять на null в mapper
final res = await api.get<Map<String, dynamic>?>('/endpoint', (json) {
  if (json == null) return null;
  return json as Map<String, dynamic>;
});
if (res == null) return null;
```

### 3. Обработка ошибок подписки
Backend возвращает специальные коды ошибок:
- `404` - подписка не найдена (нормально, если нет активной)
- `400` + `already_has_active_subscription` - попытка купить повторную подписку
- `403` + `no_active_subscription` - попытка подключиться к VPN без подписки

### 4. WireGuard конфигурация

**ВАЖНО**: В конфигах клиента использовать СЕРВЕРНЫЙ публичный ключ, а не клиентский!

```python
# ПРАВИЛЬНО (backend_api/peers.py)
def _build_wg_quick_config(private_key: str, address: str, allowed_ips: str) -> str:
    WG_SERVER_PUBLIC_KEY = os.getenv("WG_SERVER_PUBLIC_KEY")  # Серверный ключ!
    return (
        "[Interface]\n"
        f"PrivateKey = {private_key}\n"
        f"Address = {address}\n"
        f"DNS = {WG_DNS}\n\n"
        "[Peer]\n"
        f"PublicKey = {WG_SERVER_PUBLIC_KEY}\n"  # НЕ peer.wg_public_key!
        f"Endpoint = {WG_ENDPOINT}\n"
        f"AllowedIPs = {allowed_ips}\n"
        "PersistentKeepalive = 25\n"
    )
```

### 5. Проверка активной подписки

**Backend** (peers.py, auth.py):
```python
def _check_active_subscription(user_id: int, db: Session) -> bool:
    now = datetime.now(UTC)
    active = db.query(models.UserTariff).filter(
        models.UserTariff.user_id == user_id,
        models.UserTariff.status == "active",
        (models.UserTariff.ended_at.is_(None)) | (models.UserTariff.ended_at > now)
    ).first()
    return active is not None
```

**Frontend** (home_screen.dart):
```dart
Future<void> _toggleVpn() async {
  if (!_hasActiveSubscription) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('no_active_subscription'.tr()),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  // Продолжить подключение...
}
```

## РАБОЧИЕ ПРОЦЕССЫ

### Разработка Flutter
```bash
# Сборка и запуск
flutter clean
flutter pub get
flutter run -d <device> --flavor dev

# Тестирование
flutter test
flutter analyze

# Hot reload в консоли
r  # перезагрузка
R  # полный рестарт
```

### Деплой backend на production

**ВАЖНО**: НЕ загружать файлы напрямую через SSH! Использовать Git workflow:

1. **Редактировать код в C:\vpn-backend\vpn_api\**
2. **Коммит и пуш**:
```bash
cd /c/vpn-backend
git add .
git commit -m "описание изменений

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push origin main
```

3. **Деплой на сервер**:
```bash
ssh root@146.103.99.70 "cd /srv/vpn-api && git reset --hard HEAD && git pull origin main && docker compose up -d --no-deps --build web"
```

4. **Проверка логов**:
```bash
ssh root@146.103.99.70 "docker logs vpn-api-web-1 --tail 30"
```

### Загрузка .env файлов на production
```bash
scp /c/vpn/.env.production root@146.103.99.70:/srv/vpn-api/.env.production
```

### Настройка WireGuard сервера

**NAT для интернета через VPN**:
```bash
ssh root@62.84.98.109 "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens3 -j MASQUERADE"
```

**Проверка конфигурации**:
```bash
ssh root@62.84.98.109 "wg show && iptables -t nat -L POSTROUTING -n -v"
```

## РЕШЕННЫЕ ПРОБЛЕМЫ (НЕ ПОВТОРЯТЬ)

### ❌ Проблема 1: Неверный публичный ключ в конфигах
**Симптом**: VPN подключается, но интернет не работает
**Причина**: Использовался `peer.wg_public_key` вместо серверного ключа
**Решение**: Переменная окружения `WG_SERVER_PUBLIC_KEY=1SUivFxEBdU5SjpL2cLBykv/4HcotWpIrdSUGFDGIA8=`

### ❌ Проблема 2: Отсутствие NAT на VPN сервере
**Симптом**: VPN подключается, но сайты не открываются
**Причина**: Нет MASQUERADE правила для 10.8.0.0/24
**Решение**: `iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens3 -j MASQUERADE`

### ❌ Проблема 3: Дублирование подписок
**Симптом**: Пользователь может купить несколько одинаковых подписок
**Причина**: Нет проверки на существующую активную подписку
**Решение**: Проверка в `/auth/subscribe` endpoint перед созданием

### ❌ Проблема 4: Подключение VPN без подписки
**Симптом**: Пользователь может подключиться без активной подписки
**Причина**: Нет проверки в frontend и backend
**Решение**:
- Backend: проверка в `/vpn_peers/self` и `/vpn_peers/self/config`
- Frontend: проверка `_hasActiveSubscription` перед `_toggleVpn()`

## ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (.env.production)

```bash
# Backend сервер
DATABASE_URL=postgresql+psycopg2://midas:112358@146.103.99.70:5432/vpn
UVICORN_WORKERS=2
SECRET_KEY=w6T9s8xFQh2Z7mLsk3Vb1uYp4Rj6Nq0cXyA8Zf3Bv9Pd2Lj5Hk7Gm1Sx0Qe4Rt2U
CONFIG_ENCRYPTION_KEY=pCGs3jOgkL6XX97cSnFv0qPDByH7pVlEv-C-pewDBHE=
PASSWORD_HASH='$2b$12$BFf.9DOxi4aNrLsYjv1jU.TPHVTq6TvHoYDbz2tgvV5caUFHygbyW'

# WG-Easy интеграция
WG_EASY_URL=http://62.84.98.109:8588/
WG_EASY_PASSWORD=fwPSsiYwd2x1
WG_APPLY_ENABLED=1

# WireGuard конфигурация для клиентов
WG_SERVER_PUBLIC_KEY=1SUivFxEBdU5SjpL2cLBykv/4HcotWpIrdSUGFDGIA8=
WG_ENDPOINT=62.84.98.109:51821
WG_DNS=8.8.8.8,1.1.1.1
```

## API ЭНДПОИНТЫ

### Аутентификация
- `POST /auth/register` - регистрация (возвращает UserOut, БЕЗ токена)
- `POST /auth/login` - логин (возвращает access_token, refresh_token)
- `POST /auth/refresh` - обновление токена
- `GET /auth/me` - информация о пользователе
- `GET /auth/me/subscription` - активная подписка (404 если нет)
- `POST /auth/subscribe` - покупка подписки (проверяет дубликаты)

### VPN Peer'ы
- `POST /vpn_peers/self` - создать peer (проверяет подписку, возвращает wgPrivateKey один раз)
- `GET /vpn_peers/self/config` - получить wg-quick конфиг (проверяет подписку)
- `GET /vpn_peers/?skip=0&limit=10` - список peer'ов пользователя
- `DELETE /vpn_peers/{id}` - удалить peer

### Тарифы
- `GET /tariffs/` - список доступных тарифов

## ЛОКАЛИЗАЦИЯ (i18n)

**Файлы**: `assets/langs/{en,ru}.json`

**Ключевые строки**:
```json
{
  "no_active_subscription": "У вас нет активного тарифа",
  "already_has_active_subscription": "У вас уже есть активная подписка",
  "invalid_credentials": "Неверный email или пароль",
  "email_already_registered": "Email уже зарегистрирован",
  "network_error": "Ошибка сети",
  "server_error": "Ошибка сервера"
}
```

**Использование в коде**:
```dart
Text('no_active_subscription'.tr())
```

## ТИПИЧНЫЕ ОШИБКИ И РЕШЕНИЯ

### SQLAlchemy: `E711: comparison to None should be 'is None'`
```python
# НЕПРАВИЛЬНО
.filter(UserTariff.ended_at == None)

# ПРАВИЛЬНО
.filter(UserTariff.ended_at.is_(None))
```

### Flutter: `type 'Null' is not a subtype of type 'Map<String, dynamic>'`
```dart
// Добавить null check в mapper
final res = await api.get('/endpoint', (json) {
  if (json == null) return null;  // ✅
  return json as Map<String, dynamic>;
});
```

### Git pre-commit hook fails
```bash
# Если нужно срочно закоммитить (использовать осторожно)
git commit --no-verify -m "message"

# Лучше - исправить код согласно линтеру
```

## ЧЕКЛИСТ ПЕРЕД ДЕПЛОЕМ

- [ ] Код прошел `flutter analyze` (frontend)
- [ ] Код прошел `ruff check` и `black --check` (backend)
- [ ] Все изменения закоммичены в правильный репозиторий
- [ ] `.env.production` обновлен на сервере (если нужно)
- [ ] Деплой прошел успешно (проверить логи docker)
- [ ] Протестировать на реальном устройстве

## ТЕСТИРОВАНИЕ

### Backend
```bash
cd /c/vpn-backend
python test_subscription.py  # Полный flow подписки
pytest tests/                # Unit tests
```

### Frontend
```bash
cd /c/vpn
flutter test --coverage
flutter analyze
```

### Ручное тестирование на телефоне
1. Регистрация нового пользователя
2. Попытка подключения VPN БЕЗ подписки → должна быть ошибка
3. Покупка подписки "Test 7 Days"
4. Повторная попытка покупки → должна быть ошибка "already_has_active_subscription"
5. Подключение VPN → создается peer, подключается
6. Открыть браузер → проверить доступ в интернет

## ПОЛЕЗНЫЕ КОМАНДЫ

### Git
```bash
git status
git diff
git log --oneline -5
git reset --hard HEAD  # Откатить все изменения
```

### Docker на backend сервере
```bash
docker ps                              # Список контейнеров
docker logs vpn-api-web-1 --tail 30   # Логи
docker compose up -d --no-deps --build web  # Пересобрать и перезапустить
docker exec -it vpn-api-web-1 bash    # Зайти внутрь контейнера
```

### WireGuard
```bash
wg show                    # Статус WireGuard
wg show wg0 peers         # Список подключенных peer'ов
iptables -t nat -L -n -v  # Проверка NAT правил
```

### Flutter
```bash
flutter devices           # Список устройств
flutter run -d <id>       # Запуск на устройстве
flutter clean             # Очистка build кэша
flutter pub get           # Обновить зависимости
```

## КОПИРОВАНИЕ WG СЕРВЕРА (если IP заблокируют)

### 1. Подготовка нового VPS сервера
Требования:
- Ubuntu 22.04 LTS или новее
- Минимум 1 CPU, 1GB RAM, 10GB диск
- Публичный IP адрес
- Открытые порты: 51821/UDP (WireGuard), 8588/TCP (опционально - WG-Easy UI)

### 2. Установка Docker на новом сервере
```bash
# Обновление системы
apt update && apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Включение IP forwarding (обязательно для VPN!)
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Установка WireGuard tools (опционально, для отладки)
apt install -y wireguard-tools
```

### 3. Копирование конфигурации со старого сервера
```bash
# На локальной машине - скачать конфиги
scp -r root@62.84.98.109:/root/wg-easy /tmp/wg-easy-backup

# Загрузить на новый сервер (замените NEW_SERVER_IP)
scp -r /tmp/wg-easy-backup root@NEW_SERVER_IP:/root/wg-easy
```

### 4. Запуск WG-Easy на новом сервере
```bash
# SSH на новый сервер
ssh root@NEW_SERVER_IP

# ВАЖНО: Обновить IP адрес в конфигурации
# Замените OLD_IP на новый IP сервера в переменной WG_HOST
export NEW_IP="ваш_новый_ip"
export OLD_IP="62.84.98.109"

# Запуск контейнера с НОВЫМ IP
docker run --name=wg-easy \
  --volume /root/wg-easy/etc:/etc/wireguard \
  --volume /root/wg-easy/lib:/var/lib/wireguard \
  --env=WG_HOST=$NEW_IP \
  --env=WG_PORT=51821 \
  --env=WG_MTU=1420 \
  --env='PASSWORD_HASH=$2b$12$BFf.9DOxi4aNrLsYjv1jU.TPHVTq6TvHoYDbz2tgvV5caUFHygbyW' \
  --network=host \
  --privileged \
  --restart unless-stopped \
  --detach \
  ghcr.io/wg-easy/wg-easy:latest

# Проверка запуска
docker logs wg-easy --tail 50
wg show wg0
```

### 5. Настройка iptables (КРИТИЧНО!)
```bash
# Проверка имени сетевого интерфейса
ip addr show

# Если интерфейс называется eth0, ens3, или другое - запомните имя
# Замените ens3 на ваш интерфейс в командах ниже

# NAT для интернета через VPN
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens3 -j MASQUERADE

# FORWARD rules для VPN трафика
iptables -I FORWARD 1 -i wg0 -o ens3 -j ACCEPT
iptables -I FORWARD 2 -i ens3 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранение правил (установить iptables-persistent)
apt install -y iptables-persistent
iptables-save > /etc/iptables/rules.v4
```

### 6. Обновление переменных окружения на Backend
Обновить `.env.production` на backend сервере (146.103.99.70):
```bash
WG_ENDPOINT=NEW_SERVER_IP:51821
WG_EASY_URL=http://NEW_SERVER_IP:8588/
```

Затем перезапустить backend:
```bash
ssh root@146.103.99.70 "cd /srv/vpn-api && docker compose up -d --no-deps --build web"
```

### 7. Проверка работоспособности
```bash
# На WG сервере
wg show wg0  # Должен показать интерфейс и peers
docker logs wg-easy --tail 20  # Не должно быть ошибок

# Проверка NAT
iptables -t nat -L POSTROUTING -n -v  # Должна быть строка с MASQUERADE для 10.8.0.0/24

# Проверка FORWARD
iptables -L FORWARD -n -v  # Должны быть правила для wg0

# Проверка IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Должно быть 1
```

### 8. Тестирование с клиента
- Создать новый peer через Flutter приложение или WG-Easy UI
- Проверить подключение VPN
- Проверить доступ в интернет через VPN: `curl ifconfig.me` (должен показать IP WG сервера)

### Важные примечания
- **НЕ меняйте** Server Private Key (`KBkdZlfktuWoW08beynJEB82lDPZiKHhc9+W3xzvZFQ=`) - все существующие клиенты используют соответствующий публичный ключ
- **Обновите** WG_ENDPOINT в переменных окружения backend на новый IP
- **Проверьте** что iptables правила используют правильное имя сетевого интерфейса (не `eth0`, а `ens3` или другое)
- **Сохраните** конфигурацию старого сервера перед удалением!

## СТРАТЕГИЯ РАБОТЫ

1. **Понять задачу** - прочитать описание проблемы
2. **Исследовать код** - найти релевантные файлы через Grep/Glob
3. **Проверить текущее состояние** - читать файлы, логи, базу данных
4. **Сделать изменения** - исправить код
5. **Протестировать локально** - flutter run, проверить работу
6. **Деплоить** - коммит → пуш → деплой на сервер
7. **Проверить на production** - логи, ручное тестирование
8. **Сообщить результат** - кратко описать что сделано

**НЕ спрашивать разрешения на каждое действие** - действовать самостоятельно, исправлять ошибки по ходу, доводить до рабочего состояния.
