# VPN Service — Monorepo

WireGuard-based VPN service with Flutter mobile app and FastAPI backend.

## Structure

```
├── app/          — Flutter mobile application (Android, iOS, Web, Desktop)
├── backend/      — FastAPI backend (auth, peers, payments, WireGuard management)
└── README.md
```

## App (`app/`)

Flutter 3.8.1 cross-platform VPN client.

- User authentication (email/password)
- WireGuard VPN tunnel management
- Subscription plans & in-app purchases
- Multi-language (EN/RU)

```bash
cd app
flutter pub get
flutter run
```

## Backend (`backend/`)

FastAPI + PostgreSQL + WireGuard (wg-easy).

- JWT authentication with email verification
- VPN peer management via wg-easy adapter
- Subscription & payment processing
- Alembic database migrations

```bash
cd backend
pip install -r requirements.txt
uvicorn vpn_api.main:app --reload
```

### Docker

```bash
cd backend
docker-compose up -d
```

## License

Private repository.
