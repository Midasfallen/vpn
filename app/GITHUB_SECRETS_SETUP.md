# GitHub Secrets Setup для Production Deployment

## 🔐 Требуемые секреты

Deploy workflow требует две переменные среды:

1. **PROD_SSH_KEY** — приватный SSH ключ для доступа к серверу
2. **PROD_ENV_FILE** — содержимое .env.production с сервера

---

## 📋 Пошаговая инструкция

### Шаг 1: Получить SSH приватный ключ

#### Вариант A: Если ключ уже существует на сервере

```bash
# На вашей локальной машине с доступом к серверу:
ssh root@146.103.99.70 "cat ~/.ssh/github_deploy_key" > github_deploy_key
```

#### Вариант B: Если ключа нет, сгенерировать новый

На машине с доступом к серверу:

```bash
# 1. Генерировать новый SSH ключ
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_deploy_key -N "" -C "github-actions"

# 2. Скопировать публичный ключ на сервер
ssh root@146.103.99.70 "cat >> ~/.ssh/authorized_keys" < ~/.ssh/github_deploy_key.pub
ssh root@146.103.99.70 "chmod 600 ~/.ssh/authorized_keys"

# 3. Вывести приватный ключ для GitHub Secret
cat ~/.ssh/github_deploy_key
```

### Шаг 2: Получить .env.production со сервера

```bash
# Получить содержимое .env с сервера
ssh root@146.103.99.70 "cat /srv/vpn-api/.env.production" > .env.production.local

# Или вывести напрямую для копирования:
ssh root@146.103.99.70 "cat /srv/vpn-api/.env.production"
```

**Если .env.production не существует на сервере**, создать новый на основе `backend_api/requirements.txt` и конфига:

```bash
# На сервере создать базовый .env:
cat > /srv/vpn-api/.env.production << 'EOF'
# Database
DATABASE_URL=postgresql://vpn_user:vpn_password@db:5432/vpn_db

# JWT / Security
SECRET_KEY=$(openssl rand -base64 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# WireGuard
WG_INTERFACE=wg0
WG_HOST_SSH=root@62.84.98.109
WG_APPLY_SCRIPT=/srv/vpn-api/scripts/wg_apply.sh
WG_REMOVE_SCRIPT=/srv/vpn-api/scripts/wg_remove.sh
WG_GEN_SCRIPT=/srv/vpn-api/scripts/wg_gen_key.sh
WG_APPLY_ENABLED=true

# Debug
DEBUG=False
LOG_LEVEL=INFO

# Allowed hosts
ALLOWED_HOSTS=146.103.99.70,api.vpn.example.com

# Email (optional)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=noreply@example.com
SMTP_PASSWORD=your_password

# IAP Integration
APPLE_TEAM_ID=your_apple_team_id
APPLE_KEY_ID=your_apple_key_id
APPLE_PRIVATE_KEY=your_apple_private_key
APPLE_BUNDLE_ID=com.vpn.example

GOOGLE_PLAY_PACKAGE=com.vpn.example
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=/srv/vpn-api/google-play-key.json

# Stripe (if using Stripe for payments)
STRIPE_API_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

# Sentry (optional, for error tracking)
SENTRY_DSN=

# WireGuard Host Info (for peer config generation)
WG_SERVER_IP=146.103.99.70
WG_ENDPOINT=146.103.99.70:51820
WG_DNS=8.8.8.8,8.8.4.4
EOF
```

### Шаг 3: Добавить секреты в GitHub

#### Способ 1: Через веб-интерфейс

1. Перейти: **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions**
2. Нажать **"New repository secret"**

**Secret 1: `PROD_SSH_KEY`**
- Name: `PROD_SSH_KEY`
- Value: Вставить содержимое приватного ключа (вывод из шага 1)
- Нажать **Add secret**

**Secret 2: `PROD_ENV_FILE`**
- Name: `PROD_ENV_FILE`
- Value: Вставить содержимое .env.production (вывод из шага 2)
- Нажать **Add secret**

#### Способ 2: Через GitHub CLI

```bash
# Если установлен 'gh' CLI

# 1. PROD_SSH_KEY
gh secret set PROD_SSH_KEY < github_deploy_key

# 2. PROD_ENV_FILE
gh secret set PROD_ENV_FILE < .env.production.local
```

### Шаг 4: Проверить секреты

В GitHub Settings → Secrets вы должны увидеть:

```
✓ PROD_ENV_FILE
✓ PROD_SSH_KEY
```

---

## ✅验证

После добавления секретов:

1. Перейти на **Actions** tab
2. Выбрать **Deploy to Production** workflow
3. Нажать **Run workflow** → **main** → **Run workflow**
4. Проверить логи в job **deploy-backend**

Если deploy прошёл успешно:
- ✅ SSH ключ корректный
- ✅ .env.production валиден
- ✅ Backend обновлен на сервере

Если ошибка:
- Проверить логи job'a
- Убедиться что SSH ключ имеет правильный формат (начинается с `-----BEGIN RSA PRIVATE KEY-----`)
- Убедиться что .env.production не содержит ошибок синтаксиса

---

## 🔑 Формат приватного SSH ключа

Должен выглядеть так:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
...
-----END RSA PRIVATE KEY-----
```

**Не забыть**: Включить пустую строку в конце файла.

---

## 📝 Пример workflow run

После добавления секретов, Deploy workflow будет:

1. ✅ **quality-check** — Flutter analyze + tests
2. ✅ **build-artifacts** — Собрать APK
3. ✅ **deploy-backend** — SSH на сервер, скопировать .env, запустить `docker compose up`
4. ✅ **notify** — Отправить уведомление о статусе

---

## ⚠️ Безопасность

- ❌ Никогда не коммитить приватные ключи в git
- ❌ Никогда не паст приватные ключи в чат/документы (только в GitHub Secrets)
- ✅ Регулярно ротировать SSH ключи
- ✅ Использовать разные ключи для разных сервисов
- ✅ Логировать SSH доступ на сервере

---

## 🆘 Troubleshooting

### "ssh-private-key argument is empty"

→ PROD_SSH_KEY секрет не установлен или пуст. Проверить в GitHub Settings.

### "Permission denied (publickey)"

→ Публичный ключ не авторизован на сервере. Добавить:
```bash
ssh root@146.103.99.70
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAA... (ваш публичный ключ)
EOF
chmod 600 ~/.ssh/authorized_keys
```

### ".env.production: No such file or directory"

→ PROD_ENV_FILE секрет не установлен или пуст. Проверить в GitHub Settings.

### "docker compose: command not found"

→ На сервере не установлен docker-compose. Установить:
```bash
ssh root@146.103.99.70
apt-get update && apt-get install -y docker-compose
```

---

## 📞 Дополнительная помощь

- GitHub Actions docs: https://docs.github.com/en/actions
- SSH key setup: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
- Deploy workflow file: `.github/workflows/deploy.yaml`
