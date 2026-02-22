# 🔐 GitHub Secrets для Production Deployment

## ✅ Секреты готовы к добавлению

Ниже приведены значения для двух GitHub secrets, которые требуются для работы Deploy workflow.

---

## 📋 Secret #1: PROD_SSH_KEY

**Назначение**: Приватный SSH ключ для подключения к production серверу (146.103.99.70)

**Значение** (скопируй весь блок ниже включая -----BEGIN и -----END):

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC3i8P2rIBO3c74qHlvFEIrKWyhG/S8oBTA64xA0V/AHwAAAJCe8/zmnvP8
5gAAAAtzc2gtZWQyNTUxOQAAACC3i8P2rIBO3c74qHlvFEIrKWyhG/S8oBTA64xA0V/AHw
AAAECwiKPhkUFKPZQTL94s2PyoqcxvPeQaOh0WsGZOUFTq7reLw/asgE7dzrioeW8UQisp
bKEb9LygFMDrjEDRX8AfAAAACnZwbi1kZXBsb3kBAgM=
-----END OPENSSH PRIVATE KEY-----
```

---

## 📋 Secret #2: PROD_ENV_FILE

**Назначение**: Production переменные окружения для backend сервера

**Значение** (скопируй весь блок ниже):

```
# Production environment file - DO NOT COMMIT
# Replace placeholders with real production values on the server.
DATABASE_URL=postgresql+psycopg2://midas:112358@146.103.99.70:5432/vpn
UVICORN_WORKERS=2
# SECRET_KEY must be a strong random string. Do NOT use private keys or sensitive credentials.
# Generated here for local use; rotate/regenerate on the server if needed.
SECRET_KEY=w6T9s8xFQh2Z7mLsk3Vb1uYp4Rj6Nq0cXyA8Zf3Bv9Pd2Lj5Hk7Gm1Sx0Qe4Rt2U
WG_EASY_URL=http://62.84.98.109:8588/
WG_EASY_PASSWORD=fwPSsiYwd2x1
PASSWORD_HASH='$2b$12$BFf.9DOxi4aNrLsYjv1jU.TPHVTq6TvHoYDbz2tgvV5caUFHygbyW'

# Важно включить WG_APPLY_ENABLED=1   !!! чтобы запросы на вг сервер проходили корректно.
WG_APPLY_ENABLED=1

CONFIG_ENCRYPTION_KEY=pCGs3jOgkL6XX97cSnFv0qPDByH7pVlEv-C-pewDBHE=
```

---

## 🚀 Как добавить секреты в GitHub

### Способ 1️⃣: Через веб-интерфейс (рекомендуется)

1. Откройте репозиторий: **https://github.com/Midasfallen/vpn**
2. Перейдите: **Settings** → **Secrets and variables** → **Actions**
3. Нажмите **"New repository secret"**

#### Добавляем первый секрет:
- **Name**: `PROD_SSH_KEY`
- **Value**: Вставьте значение из Secret #1 (весь блок с -----BEGIN и -----END)
- Нажмите **Add secret**

#### Добавляем второй секрет:
- **Name**: `PROD_ENV_FILE`
- **Value**: Вставьте значение из Secret #2 (весь блок выше)
- Нажмите **Add secret**

### Способ 2️⃣: Через GitHub CLI

Если установлен `gh` CLI:

```powershell
# 1. PROD_SSH_KEY
@"
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC3i8P2rIBO3c74qHlvFEIrKWyhG/S8oBTA64xA0V/AHwAAAJCe8/zmnvP8
5gAAAAtzc2gtZWQyNTUxOQAAACC3i8P2rIBO3c74qHlvFEIrKWyhG/S8oBTA64xA0V/AHw
AAAECwiKPhkUFKPZQTL94s2PyoqcxvPeQaOh0WsGZOUFTq7reLw/asgE7dzrioeW8UQisp
bKEb9LygFMDrjEDRX8AfAAAACnZwbi1kZXBsb3kBAgM=
-----END OPENSSH PRIVATE KEY-----
"@ | gh secret set PROD_SSH_KEY

# 2. PROD_ENV_FILE
@"
# Production environment file - DO NOT COMMIT
# Replace placeholders with real production values on the server.
DATABASE_URL=postgresql+psycopg2://midas:112358@146.103.99.70:5432/vpn
UVICORN_WORKERS=2
# SECRET_KEY must be a strong random string. Do NOT use private keys or sensitive credentials.
# Generated here for local use; rotate/regenerate on the server if needed.
SECRET_KEY=w6T9s8xFQh2Z7mLsk3Vb1uYp4Rj6Nq0cXyA8Zf3Bv9Pd2Lj5Hk7Gm1Sx0Qe4Rt2U
WG_EASY_URL=http://62.84.98.109:8588/
WG_EASY_PASSWORD=fwPSsiYwd2x1
PASSWORD_HASH='$2b$12$BFf.9DOxi4aNrLsYjv1jU.TPHVTq6TvHoYDbz2tgvV5caUFHygbyW'

# Важно включить WG_APPLY_ENABLED=1   !!! чтобы запросы на вг сервер проходили корректно.
WG_APPLY_ENABLED=1

CONFIG_ENCRYPTION_KEY=pCGs3jOgkL6XX97cSnFv0qPDByH7pVlEv-C-pewDBHE=
"@ | gh secret set PROD_ENV_FILE
```

---

## ✅ Проверка

После добавления секретов в GitHub:

1. Откройте: **Settings** → **Secrets and variables** → **Actions**
2. Вы должны увидеть:
   ```
   ✓ PROD_ENV_FILE     (updated a few seconds ago)
   ✓ PROD_SSH_KEY      (updated a few seconds ago)
   ```

---

## 🧪 Тестирование Deploy

После добавления секретов:

1. Перейдите: **Actions** → **Deploy to Production**
2. Нажмите: **Run workflow** → **Branch: main** → **Run workflow**
3. Ожидайте результат:
   - ✅ **quality-check** — flutter analyze + tests
   - ✅ **build-artifacts** — APK build
   - ✅ **deploy-backend** — SSH deployment
   - ✅ **notify** — Status notification

Если все успешно → Deploy готов к автоматическому запуску на каждый `git push` в `main`!

---

## ⚠️ Безопасность

- ❌ **НИКОГДА** не коммитить эти значения в git
- ❌ **НИКОГДА** не делиться этими ключами в чатах/документах
- ✅ Хранить только в GitHub Secrets
- ✅ Регулярно ротировать ключи (раз в 90 дней)

---

## 🆘 Если что-то не работает

### Ошибка: "ssh-private-key argument is empty"
→ Проверить что PROD_SSH_KEY добавлен и содержит текст

### Ошибка: "Permission denied (publickey)"
→ Публичный ключ не авторизован на сервере. Нужно добавить на 146.103.99.70:
```bash
# На сервере:
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC3i8P2rIBO3c74qHlvFEIrKWyhG/S8oBTA64xA0V/AHw vpn-deploy
EOF
chmod 600 ~/.ssh/authorized_keys
```

### Ошибка: "docker compose: command not found"
→ На сервере не установлен docker-compose. Установить:
```bash
ssh root@146.103.99.70 "apt-get update && apt-get install -y docker-compose"
```

---

## 📞 Документация

- Deploy workflow файл: `.github/workflows/deploy.yaml`
- Backend .env пример: `backend_api/.env.production.example`
- Инструкции по setup: `GITHUB_SECRETS_SETUP.md`

