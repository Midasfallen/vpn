# VPN Backend API

FastAPI-based backend for VPN service with WireGuard integration.

## Features

- User authentication (JWT-based)
- Subscription management
- WireGuard peer management with **wg-easy integration**
- Tariff plans
- In-app purchase validation (Apple & Google)
- Email notifications
- Config encryption

## Critical Configuration

### ⚠️ IMPORTANT: wg-easy Integration Required

For VPN to work properly with internet access, you **MUST** configure wg-easy integration:

```bash
# In .env.production:
WG_KEY_POLICY=wg-easy                # CRITICAL! Without this, VPN connects but has no internet
WG_EASY_URL=http://62.84.98.109:8588/
WG_EASY_PASSWORD=<your_wg_easy_password>
```

**Why this is critical:**
- Without `WG_KEY_POLICY=wg-easy`, the backend creates peers locally but doesn't register them on the WireGuard server
- The WireGuard server (managed by wg-easy) only routes traffic for registered peers
- Result: VPN connects successfully but has no internet access

## Environment Setup

### Production (.env.production)

Copy `c:\vpn\backend_api\.env.production.example` to `/srv/vpn-api/.env.production` on your server and configure:

#### Required Variables

```bash
# Database
DATABASE_URL=postgresql+psycopg2://user:password@host:5432/dbname

# Security & JWT
SECRET_KEY=<generate with: openssl rand -base64 32>
CONFIG_ENCRYPTION_KEY=<generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())">

# WireGuard Server Configuration (CRITICAL)
WG_SERVER_PUBLIC_KEY=<your_server_public_key>
WG_ENDPOINT=<your_server_ip>:51821
WG_DNS=1.1.1.1
WG_MTU=1420
WG_APPLY_ENABLED=1

# wg-easy Integration (CRITICAL FOR INTERNET ACCESS)
WG_KEY_POLICY=wg-easy
WG_EASY_URL=http://<your_server>:8588/
WG_EASY_PASSWORD=<your_wg_easy_password>

# Workers
UVICORN_WORKERS=2
```

#### Optional Variables

```bash
# Email (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@example.com
SMTP_PASSWORD=<your_smtp_password>

# In-App Purchases (optional)
APPLE_TEAM_ID=<your_apple_team_id>
APPLE_KEY_ID=<your_apple_key_id>
APPLE_PRIVATE_KEY=<base64_encoded_private_key>
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=/path/to/google-play-key.json
```

## Installation

### Local Development

```bash
cd backend_api
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

### Production Deployment

```bash
# On production server
cd /srv/vpn-api
docker-compose up -d
```

## Running

### Local Development

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Production

The backend runs automatically via Docker Compose with Uvicorn workers.

## Testing

```bash
# Run all tests
pytest

# Run specific test file
pytest test_peers.py -v

# Run with coverage
pytest --cov=. --cov-report=html
```

### Test Results

- **34/34 backend unit tests passing** ✅
- **WireGuard config generation validated** ✅
- **wg-easy integration tested** ✅

## API Endpoints

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login user
- `POST /auth/subscribe` - Create subscription
- `GET /auth/me` - Get current user

### VPN Peers
- `POST /vpn_peers/self` - Create VPN peer
- `GET /vpn_peers/self` - Get user's peers
- `GET /vpn_peers/self/config` - Get WireGuard configuration
- `DELETE /vpn_peers/{peer_id}` - Delete peer

### Tariffs
- `GET /tariffs/` - List available tariffs
- `POST /tariffs/` - Create tariff (admin)

### Payments
- `POST /payments/verify-apple` - Verify Apple IAP
- `POST /payments/verify-google` - Verify Google IAP

## Architecture

### WireGuard Integration Modes

1. **wg-easy mode (RECOMMENDED for production)**
   - Creates peers via wg-easy HTTP API
   - Peers are automatically registered on WireGuard server
   - Internet access works correctly
   - Includes PresharedKey for additional security

2. **db mode (for development only)**
   - Generates keys locally
   - Does NOT register peers on server
   - VPN connects but NO internet access
   - Only for testing without server

### Key Components

- **[auth.py](auth.py)** - Authentication & user management
- **[peers.py](peers.py)** - VPN peer management & WireGuard config generation
- **[wg_easy_adapter.py](wg_easy_adapter.py)** - wg-easy API client
- **[wg_host.py](wg_host.py)** - WireGuard server SSH integration
- **[models.py](models.py)** - Database models
- **[schemas.py](schemas.py)** - Pydantic schemas
- **[crypto.py](crypto.py)** - Config encryption utilities

## Database Schema

- **users** - User accounts
- **tariffs** - Subscription plans
- **subscriptions** - User subscriptions
- **vpn_peers** - WireGuard peers
- **payments** - Payment records
- **promo_codes** - Promotional codes

## Troubleshooting

### Issue: VPN connects but no internet

**Symptom:** VPN status shows "Connected" but websites don't load

**Cause:** `WG_KEY_POLICY` not set to `wg-easy`, peers are created locally but not registered on WireGuard server

**Solution:**
1. Add `WG_KEY_POLICY=wg-easy` to `.env.production`
2. Configure `WG_EASY_URL` and `WG_EASY_PASSWORD`
3. Restart Docker containers: `docker-compose down && docker-compose up -d`
4. Delete old peers and create new ones through the app

### Issue: Database connection error

**Symptom:** Backend logs show database connection errors

**Cause:** Malformed `.env.production` file (literal `\n` characters)

**Solution:**
1. Ensure `.env.production` has proper line breaks
2. Recreate containers: `docker-compose down && docker-compose up -d`

### Issue: Authentication fails

**Symptom:** Cannot login or register users

**Solution:**
1. Check database is running: `docker ps`
2. Verify `DATABASE_URL` in `.env.production`
3. Check backend logs: `docker logs vpn-api-web-1`

## Production Checklist

- [ ] Configure `.env.production` with all required variables
- [ ] Set `WG_KEY_POLICY=wg-easy`
- [ ] Generate strong `SECRET_KEY` and `CONFIG_ENCRYPTION_KEY`
- [ ] Configure wg-easy URL and password
- [ ] Set correct `WG_SERVER_PUBLIC_KEY` from your WireGuard server
- [ ] Set correct `WG_ENDPOINT` (server IP and port)
- [ ] Start Docker containers
- [ ] Run tests to verify setup
- [ ] Test VPN connection on real device
- [ ] Verify internet access works through VPN

## License

Proprietary

## Support

For issues and questions, refer to the main project [README](../README.md) and [E2E_TEST_RESULTS.md](../E2E_TEST_RESULTS.md).
