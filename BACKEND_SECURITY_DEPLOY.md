# VPN API — Безопасность, Deploy и DevOps

---

## 1. Безопасность

### 1.1 Аутентификация и авторизация

#### JWT Implementation
- **Алгоритм**: HS256 (HMAC-SHA256)
- **Secret Key**: Минимум 32 символа, хранится в `SECRET_KEY` env var
- **Token lifetime**: 60 минут (настраивается через `ACCESS_TOKEN_EXPIRE_MINUTES`)
- **Payload**: `{"sub": user_email, "exp": expiry_timestamp}`

#### Рекомендации
```python
# ✅ Good
SECRET_KEY = os.getenv("SECRET_KEY", "")
if len(SECRET_KEY) < 32:
    raise RuntimeError("SECRET_KEY must be at least 32 characters")

# ✌ Better: Use secrets.token_urlsafe(32)
import secrets
SECRET_KEY = secrets.token_urlsafe(32)
```

#### Password Storage
- **Алгоритм**: PBKDF2-SHA256 (primary), bcrypt как fallback
- **Migrations**: Старые bcrypt хэши остаются совместимы
- **Валидация**: Минимум 8 символов (добавить сложность)

```python
# Улучшенная валидация пароля
def validate_password(password: str):
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not any(c.isupper() for c in password):
        raise ValueError("Password must contain uppercase letter")
    if not any(c.isdigit() for c in password):
        raise ValueError("Password must contain digit")
    return True
```

### 1.2 Приватные ключи WireGuard

#### ⚠️ Проблема
- Приватные ключи сохраняются в открытом виде в БД
- Возвращаются при создании пира, но не при GET запросах

#### ✅ Рекомендуемое решение
```python
from cryptography.fernet import Fernet

# Зашифровать приватный ключ как конфиг
def store_peer(peer: VpnPeer):
    # Зашифровать приватный ключ
    if peer.wg_private_key:
        from vpn_api.crypto import encrypt_text
        peer.wg_private_key_encrypted = encrypt_text(peer.wg_private_key)
        peer.wg_private_key = None  # Не сохранять в открытом виде
    db.add(peer)
    db.commit()

# При возврате при создании
@router.post("/vpn_peers/self")
def create_peer_self(...):
    peer = create_peer(...)
    # Вернуть приватный ключ один раз в ответе
    response = peer.to_dict()
    if peer.wg_private_key_encrypted:
        response['wg_private_key'] = decrypt_text(peer.wg_private_key_encrypted)
    return response
```

### 1.3 Защита Webhook-ов

#### App Store Server Notifications
```python
import jwt
from cryptography.hazmat.primitives import serialization

async def verify_app_store_webhook(signed_payload: str):
    """Verify JWT signature from Apple."""
    try:
        # Загрузить Apple public key
        cert = await _fetch_apple_root_certificate()
        
        payload = jwt.decode(
            signed_payload,
            cert,
            algorithms=["ES256"],
            audience="YOUR_APP_ID",
        )
        
        # Проверить timestamp (предотвращение replay attacks)
        import time
        timestamp = payload.get("signedDate")
        if abs(time.time() - timestamp / 1000) > 3600:  # 1 hour
            raise ValueError("Webhook too old")
        
        return payload
    except jwt.InvalidSignatureError:
        raise HTTPException(status_code=401, detail="Invalid signature")
```

#### Google Play Pub/Sub
```python
from google.auth.transport.requests import Request
from google.oauth2 import service_account

async def verify_google_play_webhook(message: dict):
    """Verify Pub/Sub message from Google Play."""
    try:
        # Загрузить Google Service Account credentials
        creds = service_account.Credentials.from_service_account_file(
            "google-service-account.json"
        )
        
        # Проверить подпись
        from google.auth import jwt as google_jwt
        payload = google_jwt.decode(
            message['signedMessage'],
            certs_url="https://www.googleapis.com/robot/v1/metadata/x509/..."
        )
        
        # Декодировать подписку
        subscription_update = json.loads(
            base64.b64decode(message['subscriptionNotification']['message']['data'])
        )
        
        return subscription_update
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid message: {e}")
```

### 1.4 Rate Limiting

#### Реализация с `slowapi`
```python
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Per-endpoint limits
@app.post("/auth/login")
@limiter.limit("5/minute")  # 5 логинов в минуту
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    ...

@app.post("/vpn_peers/self")
@limiter.limit("1/minute")  # 1 пир в минуту
def create_peer_self(...):
    ...
```

### 1.5 SQL Injection Protection

```python
# ✅ SQLAlchemy параметризированные запросы (защищены по умолчанию)
user = db.query(User).filter(User.email == email).first()

# ❌ Никогда не делайте
user = db.query(User).filter(f"email = '{email}'").first()  # VULNERABLE!
```

### 1.6 CORS Configuration

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # React dev
        "https://myapp.com",      # Production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ❌ Никогда не используйте
# allow_origins=["*"]  # Security risk!
```

### 1.7 TLS/HTTPS

```bash
# Nginx + Let's Encrypt
sudo apt-get install certbot python3-certbot-nginx

# Получить сертификат
sudo certbot certonly --nginx -d api.myapp.com

# Nginx конфиг
server {
    listen 443 ssl http2;
    server_name api.myapp.com;
    
    ssl_certificate /etc/letsencrypt/live/api.myapp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.myapp.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Authorization $http_authorization;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Редирект HTTP на HTTPS
server {
    listen 80;
    server_name api.myapp.com;
    return 301 https://$server_name$request_uri;
}
```

### 1.8 Логирование безопасности

```python
import logging
from datetime import datetime

logger = logging.getLogger("security")

# Логировать попытки входа
@router.post("/auth/login")
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        logger.warning(f"Failed login attempt for {user.email} from {request.client.host}")
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    logger.info(f"Successful login for {user.email} from {request.client.host}")
    ...

# Логировать операции админа
@router.post("/auth/admin/promote")
def promote_user(user_id: int, ...):
    logger.warning(f"User {current_user.id} promoted user {user_id} to admin")
    ...
```

---

## 2. Развёртывание (Docker + Compose)

### 2.1 Build и запуск

#### Build образ
```bash
# Production
docker build -t vpn-api:latest .

# Tagирование для registry
docker tag vpn-api:latest myregistry.com/vpn-api:latest
docker push myregistry.com/vpn-api:latest
```

#### Docker Compose (Production)
```yaml
version: '3.8'

services:
  web:
    image: vpn-api:latest
    container_name: vpn_api
    restart: always
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      SECRET_KEY: ${SECRET_KEY}
      ALGORITHM: HS256
      ACCESS_TOKEN_EXPIRE_MINUTES: 60
      PROMOTE_SECRET: ${PROMOTE_SECRET}
      WG_KEY_POLICY: wg-easy
      WG_EASY_URL: ${WG_EASY_URL}
      WG_EASY_PASSWORD: ${WG_EASY_PASSWORD}
      CONFIG_ENCRYPTION_KEY: ${CONFIG_ENCRYPTION_KEY}
      APP_VERSION: "0.1.0"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./logs:/app/logs
    networks:
      - vpn-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  db:
    image: postgres:15
    container_name: vpn_db
    restart: always
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=en_US.UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - vpn-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Опциональный nginx reverse proxy
  nginx:
    image: nginx:alpine
    container_name: vpn_nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./logs:/var/log/nginx
    depends_on:
      - web
    networks:
      - vpn-network

volumes:
  postgres_data:
    driver: local

networks:
  vpn-network:
    driver: bridge
```

#### .env.production
```bash
# Database
DB_USER=vpnuser
DB_PASSWORD=very_strong_password_min_32_chars
DB_NAME=vpndb

# JWT
SECRET_KEY=generate_with_secrets.token_urlsafe(32)
PROMOTE_SECRET=bootstrap_secret_for_first_admin

# WG/wg-easy
WG_EASY_URL=http://wg-easy:8588/
WG_EASY_PASSWORD=wg_easy_password
CONFIG_ENCRYPTION_KEY=base64_fernet_key_44_chars

# SSH (опционально)
WG_APPLY_ENABLED=0
WG_HOST_SSH=root@wg-easy-host
```

### 2.2 Миграции перед запуском

```bash
#!/bin/bash
# scripts/migrate.sh

set -e

echo "Waiting for database..."
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c '\q'; do
  echo "Database is unavailable - sleeping"
  sleep 1
done

echo "Running migrations..."
alembic upgrade head

echo "Migrations complete!"
```

**В docker-compose.yml**:
```yaml
services:
  web:
    command: >
      bash -c "
        chmod +x /app/scripts/migrate.sh &&
        /app/scripts/migrate.sh &&
        uvicorn vpn_api.main:app --host 0.0.0.0 --port 8000
      "
```

### 2.3 Backup БД перед деплоем

```bash
#!/bin/bash
# scripts/backup-db.sh

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vpndb_$TIMESTAMP.dump"

mkdir -p $BACKUP_DIR

echo "Starting database backup..."
PGPASSWORD=$DB_PASSWORD pg_dump \
  -h $DB_HOST \
  -U $DB_USER \
  -d $DB_NAME \
  -F c \
  -f $BACKUP_FILE \
  -v

if [ $? -eq 0 ]; then
  echo "Backup successful: $BACKUP_FILE"
  
  # Удалить старые бэкапы (старше 7 дней)
  find $BACKUP_DIR -name "*.dump" -mtime +7 -delete
else
  echo "Backup failed!"
  exit 1
fi
```

**Cron job** (ежедневный бэкап):
```bash
# /etc/cron.d/vpn-api-backup
0 2 * * * /srv/vpn-api/scripts/backup-db.sh >> /var/log/vpn-backup.log 2>&1
```

---

## 3. GitHub Actions CI/CD

### 3.1 Lint и тесты (.github/workflows/ci.yml)

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r vpn_api/requirements.txt
          pip install -r vpn_api/requirements-dev.txt
      
      - name: Lint with ruff
        run: ruff check vpn_api/
      
      - name: Format with black
        run: black --check vpn_api/
      
      - name: Sort imports with isort
        run: isort --check-only vpn_api/
      
      - name: Run tests with coverage
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db
          SECRET_KEY: test_secret_key_at_least_32_chars
          CONFIG_ENCRYPTION_KEY: fernet_key_here
        run: |
          pytest --cov=vpn_api --cov-report=xml --cov-report=html
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
```

### 3.2 Миграции перед деплоем (.github/workflows/deploy.yml)

```yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Confirm deployment'
        required: true
        default: 'no'

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.event.inputs.confirm == 'yes'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Backup database
        env:
          DB_HOST: ${{ secrets.DB_HOST }}
          DB_USER: ${{ secrets.DB_USER }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          DB_NAME: ${{ secrets.DB_NAME }}
        run: |
          BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).dump"
          PGPASSWORD=$DB_PASSWORD pg_dump \
            -h $DB_HOST \
            -U $DB_USER \
            -d $DB_NAME \
            -F c \
            -f $BACKUP_FILE
          echo "BACKUP_FILE=$BACKUP_FILE" >> $GITHUB_ENV
      
      - name: Upload backup to S3
        uses: aws-actions/aws-cli@v1
        with:
          args: s3 cp ${{ env.BACKUP_FILE }} s3://vpn-backups/
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: us-east-1
      
      - name: Run migrations
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          pip install alembic sqlalchemy
          alembic upgrade head
      
      - name: Deploy to production
        run: |
          docker-compose -f docker-compose.yml pull
          docker-compose -f docker-compose.yml up -d
      
      - name: Smoke tests
        run: |
          sleep 10
          curl -f http://localhost:8000/ || exit 1
          echo "Deployment successful!"
```

---

## 4. Monitoring и Observability

### 4.1 Prometheus метрики

```python
from prometheus_client import Counter, Histogram, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware
import time

# Метрики
request_count = Counter(
    'vpn_api_requests_total',
    'Total API requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'vpn_api_request_duration_seconds',
    'API request duration',
    ['method', 'endpoint']
)

login_attempts = Counter(
    'vpn_api_login_attempts_total',
    'Total login attempts',
    ['status']
)

# Middleware
class PrometheusMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        start_time = time.time()
        
        response = await call_next(request)
        
        duration = time.time() - start_time
        
        request_count.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        
        request_duration.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        return response

app.add_middleware(PrometheusMiddleware)

# Endpoint для Prometheus
@app.get("/metrics")
def metrics():
    return generate_latest()
```

### 4.2 Sentry для error tracking

```python
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    integrations=[
        FastApiIntegration(),
        SqlalchemyIntegration(),
    ],
    traces_sample_rate=0.1,
    environment=os.getenv("ENVIRONMENT", "development"),
)
```

### 4.3 Structured logging с Python logging

```python
import logging
import json
from pythonjsonlogger import jsonlogger

# JSON formatter
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)

logger = logging.getLogger()
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# Использование
logger.info("User login", extra={
    "user_id": user.id,
    "email": user.email,
    "ip": request.client.host,
})
```

---

## 5. Контрольный список безопасности (Security Audit)

### API Security

- [ ] Все endpoints требуют HTTPS
- [ ] CORS правильно настроен (не `allow_origins=["*"]`)
- [ ] Rate limiting включен (5 логинов/мин, 1 пир/мин)
- [ ] CSRF protection (если есть cookies)
- [ ] SQL injection protection (SQLAlchemy параметризация)
- [ ] XSS protection (JSON responses, не HTML)
- [ ] Headers security (Strict-Transport-Security, X-Content-Type-Options)

### Authentication & Authorization

- [ ] JWT токены подписаны SECRET_KEY (min 32 chars)
- [ ] Пароли хэшируются PBKDF2-SHA256
- [ ] Пароли валидируются (min 8 chars, сложность)
- [ ] Role-based access control (is_admin flag)
- [ ] MFA рассмотрена (рекомендуется)
- [ ] Logout очищает токены
- [ ] Refresh token механизм (если есть долгоживущие токены)

### Data Protection

- [ ] Приватные ключи WireGuard зашифрованы (Fernet)
- [ ] wg-quick конфиги зашифрованы
- [ ] БД пароль сильный (min 32 chars)
- [ ] БД регулярно бэкапится (ежедневно)
- [ ] БД шифруется (TDE или encrypted volumes)
- [ ] Чувствительные логи не записываются (tokens, passwords)

### Webhook Security

- [ ] Подписи webhook-ов верифицируются (HMAC/JWT)
- [ ] Timestamps проверяются (prevention replay attacks)
- [ ] Provider payment IDs логируются (idempotency)
- [ ] Webhook endpoints имеют rate limiting

### Infrastructure

- [ ] Firewall правильно настроен
- [ ] SSH доступ только по ключам (не password)
- [ ] OS регулярно обновляется
- [ ] Docker образ базируется на slim версии
- [ ] Чувствительные env vars в Secrets Manager (не .env)
- [ ] Логи отправляются в centralized store (ELK, Loki)
- [ ] Monitoring и alerting настроены

---

## 6. Disaster Recovery Plan

### 3-2-1 Backup Strategy

```bash
# 1 копия: основная БД (PostgreSQL)
# 2 типа хранилища: local + S3
# 1 offsite: daily push to S3

# Daily backup
0 2 * * * /srv/vpn-api/scripts/backup-db.sh

# Upload to S3
0 3 * * * aws s3 sync /backups s3://vpn-backups/ --region us-east-1
```

### Восстановление из backup

```bash
#!/bin/bash
# scripts/restore-db.sh

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Restoring from: $BACKUP_FILE"

PGPASSWORD=$DB_PASSWORD pg_restore \
  -h $DB_HOST \
  -U $DB_USER \
  -d $DB_NAME \
  -F c \
  --clean \
  --if-exists \
  "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  echo "Restore successful!"
else
  echo "Restore failed!"
  exit 1
fi
```

---

## 7. Troubleshooting

### Connection to wg-easy fails

```bash
# Проверить доступность
curl -I http://wg-easy:8588/

# Проверить логи wg-easy
docker logs wg-easy

# Проверить сетевые настройки
docker network inspect vpn-network
```

### Migration fails

```bash
# Проверить текущее состояние
alembic current

# Показать историю миграций
alembic history

# Откатить на один шаг назад
alembic downgrade -1

# Запустить определённую миграцию
alembic upgrade <revision>
```

### Database locks

```bash
# На PostgreSQL
SELECT pid, usename, application_name, state
FROM pg_stat_activity
WHERE state != 'idle';

# Kill zombie connection
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'vpnuser' AND state = 'idle' AND query_start < now() - interval '1 hour';
```

---

**Конец документации**

Версия 1.0 — Полное руководство по безопасности, развёртыванию и DevOps для VPN API.
