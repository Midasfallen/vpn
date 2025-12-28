# Backend API Requirements for OAuth Integration

## Обзор

Для поддержки аутентификации через Google и Apple в мобильном приложении необходимо реализовать два новых endpoint'а в backend API.

---

## 1. Google OAuth Endpoint

### `POST /auth/google`

Endpoint для аутентификации пользователя через Google OAuth.

#### Request

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjdlM..."
}
```

**Параметры:**
- `id_token` (string, required) - Google ID Token, полученный от Google Sign-In SDK

#### Response

**Success (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

**Error (400 Bad Request):**
```json
{
  "detail": "Invalid Google ID token"
}
```

**Error (401 Unauthorized):**
```json
{
  "detail": "Google token verification failed"
}
```

#### Логика обработки

1. **Верификация Google ID Token**:
   ```python
   from google.auth.transport import requests
   from google.oauth2 import id_token

   # Верифицировать токен
   try:
       idinfo = id_token.verify_oauth2_token(
           token,
           requests.Request(),
           "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
       )

       # Проверить issuer
       if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
           raise ValueError('Wrong issuer.')

       # Получить данные пользователя
       google_user_id = idinfo['sub']
       email = idinfo['email']
       email_verified = idinfo.get('email_verified', False)
       name = idinfo.get('name')
       picture = idinfo.get('picture')

   except ValueError:
       # Invalid token
       raise HTTPException(status_code=400, detail="Invalid Google ID token")
   ```

2. **Проверка существования пользователя**:
   - Проверить, существует ли пользователь с таким email
   - Если существует - использовать существующего пользователя
   - Если не существует - создать нового пользователя

3. **Сохранение OAuth связи**:
   - Сохранить связь между пользователем и Google account (google_user_id)
   - Сохранить email, имя, фото профиля

4. **Генерация JWT токенов**:
   - Создать access_token и refresh_token для пользователя
   - Вернуть токены клиенту

#### Зависимости

**Python:**
```bash
pip install google-auth google-auth-oauthlib google-auth-httplib2
```

**Конфигурация:**
- Создать проект в [Google Cloud Console](https://console.cloud.google.com/)
- Включить Google Sign-In API
- Создать OAuth 2.0 Client ID (для Android и iOS)
- Получить Client ID и указать в коде

---

## 2. Apple OAuth Endpoint

### `POST /auth/apple`

Endpoint для аутентификации пользователя через Apple Sign-In.

#### Request

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "identity_token": "eyJraWQiOiJmaDZCczhDIiwiYWxnIjoiUlMyNTYifQ...",
  "authorization_code": "c1f2e3d4c5b6a7891011121314151617...",
  "user_identifier": "001234.56789abcdef.0123"
}
```

**Параметры:**
- `identity_token` (string, optional) - Apple Identity Token (JWT)
- `authorization_code` (string, optional) - Apple Authorization Code
- `user_identifier` (string, required) - Apple User Identifier (уникальный ID пользователя)

**Note**: Apple может вернуть либо `identity_token`, либо `authorization_code`, либо оба. Backend должен обрабатывать все случаи.

#### Response

**Success (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

**Error (400 Bad Request):**
```json
{
  "detail": "Invalid Apple credentials"
}
```

**Error (401 Unauthorized):**
```json
{
  "detail": "Apple token verification failed"
}
```

#### Логика обработки

1. **Верификация Apple Identity Token** (если есть):
   ```python
   import jwt
   import requests
   from datetime import datetime

   # Получить публичные ключи Apple
   apple_keys_url = "https://appleid.apple.com/auth/keys"
   apple_keys = requests.get(apple_keys_url).json()

   # Верифицировать JWT токен
   try:
       # Декодировать header для получения kid
       header = jwt.get_unverified_header(identity_token)
       kid = header['kid']

       # Найти соответствующий ключ
       key = None
       for k in apple_keys['keys']:
           if k['kid'] == kid:
               key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(k))
               break

       if not key:
           raise ValueError("Public key not found")

       # Верифицировать токен
       claims = jwt.decode(
           identity_token,
           key,
           algorithms=['RS256'],
           audience="your.app.bundle.id",  # Bundle ID приложения
           issuer="https://appleid.apple.com"
       )

       # Получить данные пользователя
       apple_user_id = claims['sub']
       email = claims.get('email')
       email_verified = claims.get('email_verified', False)

   except Exception as e:
       raise HTTPException(status_code=400, detail=f"Invalid Apple token: {str(e)}")
   ```

2. **Альтернативный способ - использование Authorization Code**:
   - Если `identity_token` отсутствует, но есть `authorization_code`
   - Обменять code на токены через Apple API
   - Верифицировать полученный токен

3. **Проверка существования пользователя**:
   - Проверить, существует ли пользователь с таким `user_identifier` (Apple User ID)
   - Если существует - использовать существующего пользователя
   - Если не существует - создать нового пользователя
   - **Важно**: Apple может НЕ предоставлять email при повторных входах

4. **Сохранение OAuth связи**:
   - Сохранить связь между пользователем и Apple account (user_identifier)
   - Сохранить email (если доступен), имя

5. **Генерация JWT токенов**:
   - Создать access_token и refresh_token для пользователя
   - Вернуть токены клиенту

#### Зависимости

**Python:**
```bash
pip install pyjwt cryptography requests
```

**Конфигурация:**
- Зарегистрироваться в [Apple Developer Program](https://developer.apple.com/) ($99/год)
- Создать App ID с включенным "Sign in with Apple"
- Создать Service ID для backend
- Получить Team ID, Key ID, Private Key
- Указать Bundle ID приложения

---

## 3. Модель базы данных

### Таблица `oauth_accounts`

Для хранения связей между пользователями и OAuth провайдерами:

```sql
CREATE TABLE oauth_accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,  -- 'google' или 'apple'
    provider_user_id VARCHAR(255) NOT NULL,  -- Google sub или Apple user_identifier
    email VARCHAR(255),
    display_name VARCHAR(255),
    photo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(provider, provider_user_id)
);

CREATE INDEX idx_oauth_user_id ON oauth_accounts(user_id);
CREATE INDEX idx_oauth_provider_user ON oauth_accounts(provider, provider_user_id);
```

### Обновление таблицы `users`

Добавить поле для хранения источника регистрации (опционально):

```sql
ALTER TABLE users ADD COLUMN registration_method VARCHAR(50) DEFAULT 'email';
-- Возможные значения: 'email', 'google', 'apple'
```

---

## 4. Логика создания пользователя

### При регистрации через OAuth

1. **Если email уже существует**:
   - Проверить, зарегистрирован ли пользователь через email/password
   - Если да - добавить OAuth связь к существующему пользователю
   - Если нет - вернуть ошибку "Email already registered"

2. **Если email не существует**:
   - Создать нового пользователя
   - Email: взять из OAuth провайдера
   - Password: НЕ устанавливать (пользователь без пароля)
   - Status: 'active' (OAuth пользователи автоматически активны)
   - Создать запись в `oauth_accounts`

3. **Если email отсутствует** (Apple может не предоставлять):
   - Создать пользователя с email = NULL
   - Или использовать fake email: `{provider_user_id}@appleid.local`

---

## 5. Пример реализации (FastAPI + Python)

### Файл: `app/routers/auth.py`

```python
from fastapi import APIRouter, Depends, HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
import jwt
import requests
from datetime import datetime, timedelta
from typing import Optional

from app.database import get_db
from app.models import User, OAuthAccount
from app.security import create_access_token, create_refresh_token
from app.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


class GoogleLoginRequest(BaseModel):
    id_token: str


class AppleLoginRequest(BaseModel):
    identity_token: Optional[str] = None
    authorization_code: Optional[str] = None
    user_identifier: str


@router.post("/google")
async def google_login(
    request: GoogleLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Аутентификация через Google OAuth
    """
    try:
        # 1. Верифицировать Google ID Token
        idinfo = google_id_token.verify_oauth2_token(
            request.id_token,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID
        )

        if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            raise ValueError('Invalid issuer')

        google_user_id = idinfo['sub']
        email = idinfo['email']
        email_verified = idinfo.get('email_verified', False)
        name = idinfo.get('name')
        picture = idinfo.get('picture')

        # 2. Проверить существование OAuth аккаунта
        oauth_account = db.query(OAuthAccount).filter(
            OAuthAccount.provider == 'google',
            OAuthAccount.provider_user_id == google_user_id
        ).first()

        if oauth_account:
            # Существующий пользователь
            user = oauth_account.user
        else:
            # Новый пользователь
            # Проверить существование email
            existing_user = db.query(User).filter(User.email == email).first()

            if existing_user:
                # Email уже зарегистрирован - добавить OAuth связь
                user = existing_user
            else:
                # Создать нового пользователя
                user = User(
                    email=email,
                    status='active',
                    registration_method='google'
                )
                db.add(user)
                db.flush()

            # Создать OAuth связь
            oauth_account = OAuthAccount(
                user_id=user.id,
                provider='google',
                provider_user_id=google_user_id,
                email=email,
                display_name=name,
                photo_url=picture
            )
            db.add(oauth_account)
            db.commit()

        # 3. Генерировать JWT токены
        access_token = create_access_token(user_id=user.id)
        refresh_token = create_refresh_token(user_id=user.id)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 3600
        }

    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid Google token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")


@router.post("/apple")
async def apple_login(
    request: AppleLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Аутентификация через Apple Sign-In
    """
    try:
        email = None
        apple_user_id = request.user_identifier

        # 1. Верифицировать Apple Identity Token (если есть)
        if request.identity_token:
            # Получить публичные ключи Apple
            apple_keys_response = requests.get("https://appleid.apple.com/auth/keys")
            apple_keys = apple_keys_response.json()

            # Декодировать header
            header = jwt.get_unverified_header(request.identity_token)
            kid = header['kid']

            # Найти ключ
            key = None
            for k in apple_keys['keys']:
                if k['kid'] == kid:
                    key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(k))
                    break

            if not key:
                raise ValueError("Apple public key not found")

            # Верифицировать токен
            claims = jwt.decode(
                request.identity_token,
                key,
                algorithms=['RS256'],
                audience=settings.APPLE_BUNDLE_ID,
                issuer="https://appleid.apple.com"
            )

            email = claims.get('email')
            apple_user_id = claims['sub']

        # 2. Проверить существование OAuth аккаунта
        oauth_account = db.query(OAuthAccount).filter(
            OAuthAccount.provider == 'apple',
            OAuthAccount.provider_user_id == apple_user_id
        ).first()

        if oauth_account:
            # Существующий пользователь
            user = oauth_account.user
        else:
            # Новый пользователь
            if email:
                existing_user = db.query(User).filter(User.email == email).first()
                if existing_user:
                    user = existing_user
                else:
                    user = User(
                        email=email,
                        status='active',
                        registration_method='apple'
                    )
                    db.add(user)
                    db.flush()
            else:
                # Apple не предоставил email - создать пользователя без email
                user = User(
                    email=f"{apple_user_id}@appleid.local",
                    status='active',
                    registration_method='apple'
                )
                db.add(user)
                db.flush()

            # Создать OAuth связь
            oauth_account = OAuthAccount(
                user_id=user.id,
                provider='apple',
                provider_user_id=apple_user_id,
                email=email
            )
            db.add(oauth_account)
            db.commit()

        # 3. Генерировать JWT токены
        access_token = create_access_token(user_id=user.id)
        refresh_token = create_refresh_token(user_id=user.id)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 3600
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid Apple credentials: {str(e)}")
```

---

## 6. Конфигурация (.env)

Добавить в `.env` файл:

```env
# Google OAuth
GOOGLE_CLIENT_ID=123456789-abcdefghijklmnop.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxxx

# Apple OAuth
APPLE_BUNDLE_ID=com.example.vpn
APPLE_TEAM_ID=ABCD1234EF
APPLE_KEY_ID=KEY1234567
APPLE_PRIVATE_KEY_PATH=/path/to/AuthKey_KEY1234567.p8
```

---

## 7. Тестирование

### Тестирование Google OAuth:

1. Получить test Google ID Token через Google OAuth Playground
2. Отправить POST запрос:
   ```bash
   curl -X POST http://localhost:8000/auth/google \
     -H "Content-Type: application/json" \
     -d '{"id_token": "eyJhbGciOi..."}'
   ```

### Тестирование Apple OAuth:

1. Использовать реальное iOS устройство (Simulator не поддерживает Apple Sign-In)
2. Получить identity_token из приложения
3. Отправить POST запрос:
   ```bash
   curl -X POST http://localhost:8000/auth/apple \
     -H "Content-Type: application/json" \
     -d '{
       "identity_token": "eyJraWQ...",
       "user_identifier": "001234.56789"
     }'
   ```

---

## 8. Безопасность

### Рекомендации:

1. **Валидация токенов**:
   - Всегда верифицировать подпись токенов
   - Проверять `iss` (issuer), `aud` (audience), `exp` (expiration)

2. **HTTPS**:
   - Использовать HTTPS для всех API запросов
   - Не принимать OAuth токены через HTTP

3. **Rate Limiting**:
   - Ограничить количество попыток входа (например, 5 попыток/минуту)

4. **Логирование**:
   - Логировать все попытки OAuth аутентификации
   - Логировать неудачные попытки для мониторинга атак

5. **Обработка email конфликтов**:
   - Если пользователь зарегистрирован через email, а потом пытается войти через OAuth с тем же email - требовать подтверждение связки аккаунтов

---

## 9. Дополнительные материалы

- [Google Sign-In for Server-Side Apps](https://developers.google.com/identity/sign-in/web/backend-auth)
- [Apple Sign In REST API](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
- [Verifying a User](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/verifying_a_user)

---

**Документ создан**: 2025-12-28
**Версия**: 1.0
**Автор**: Claude (Sonnet 4.5)
