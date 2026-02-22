# 🚀 GitHub Actions Deployment Guide

## Overview

This guide explains how to set up and use the automated GitHub Actions CI/CD pipeline for production deployment. Once configured, a simple `git push` to the `main` branch will automatically:

1. ✅ Run code quality checks (Flutter analyze, tests)
2. ✅ Deploy backend changes to production
3. ✅ Build APK and iOS artifacts
4. ✅ Validate deployment health
5. ✅ Notify of results

---

## Prerequisites

Before starting, ensure you have:

- ✅ GitHub repository with GitHub Actions enabled
- ✅ Production server (146.103.99.70) with Docker Compose
- ✅ SSH access to production server (root user)
- ✅ GitHub CLI installed (`gh` command)
- ✅ `git` configured locally

---

## Initial Setup (One-time)

### Step 1: Generate SSH Key for Deployment

Run the automated setup script:

```bash
bash scripts/setup-github-deploy.sh
```

This script will:
1. Generate a new RSA 4096-bit key pair
2. Display the public key
3. Show the server command to authorize it
4. Copy the private key to clipboard (macOS)

### Step 2: Authorize Public Key on Production Server

SSH into the production server and authorize the public key:

```bash
# On production server (146.103.99.70)
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAA... (paste public key from Step 1)
EOF
chmod 600 ~/.ssh/authorized_keys
```

Test SSH access (you should NOT need a password):

```bash
ssh -i ~/.ssh/github_deploy_key root@146.103.99.70 "echo Connected!"
```

### Step 3: Add GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets → Actions):

#### Secret 1: `PROD_SSH_KEY`

**Value**: Private key from Step 1 (entire file content)

```bash
# Display on macOS (or manually from ~/.ssh/github_deploy_key)
cat ~/.ssh/github_deploy_key | pbcopy
# Then paste into GitHub Secrets
```

#### Secret 2: `PROD_ENV_FILE`

**Value**: Production environment variables

```bash
# Get current .env from server
ssh root@146.103.99.70 "cat /srv/vpn-api/.env.production"
```

**Content example**:
```
DATABASE_URL=postgresql://user:password@db:5432/vpn_db
SECRET_KEY=your-secret-key-here
DEBUG=False
ALLOWED_HOSTS=146.103.99.70,example.com
STRIPE_API_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
APPLE_TEAM_ID=XXXXXXXXXX
APPLE_KEY_ID=XXXXXXXXXX
APPLE_PRIVATE_KEY=...
GOOGLE_PLAY_KEY_PATH=/srv/vpn-api/google-play-key.json
```

**How to add to GitHub**:

```bash
# Via GitHub CLI
gh secret set PROD_ENV_FILE < /path/to/.env.production

# Or manually in GitHub UI:
# Settings → Secrets → Actions → New repository secret
# Name: PROD_ENV_FILE
# Value: (paste entire .env.production content)
```

---

## Deployment Process

### Automatic Deployment (Recommended)

Simply commit and push to `main`:

```bash
git add .
git commit -m "feat: Add new VPN feature"
git push origin main
```

GitHub Actions will automatically:
1. Run quality checks
2. Deploy changes
3. Notify you of results

### Manual Deployment Trigger

If you want to redeploy without code changes:

```bash
# Using GitHub CLI
gh workflow run deploy.yaml

# Or open GitHub UI:
# Actions → Deploy to Production → Run workflow → Run workflow
```

---

## Workflow Stages Explained

### 1️⃣ Quality Check (`quality-check` job)

**What it does**:
- Checks Dart code style with `flutter analyze`
- Runs all unit tests
- Generates coverage report

**Fails if**:
- Code style issues found
- Any test fails
- Coverage below threshold

**Duration**: ~2 minutes

**Logs**: Check in GitHub Actions UI under "Quality Check"

### 2️⃣ Backend Deployment (`deploy-backend` job)

**Runs only if**: Quality checks passed ✅

**What it does**:
1. Sets up SSH authentication using PROD_SSH_KEY
2. Transfers `.env.production` file to server via SCP
3. SSH into production server
4. Moves `.env.production` to `/srv/vpn-api/`
5. Runs `docker compose up -d --no-deps --build web`
6. Waits for health endpoint to respond

**Health Check**: Polls `http://146.103.99.70:8000/docs` (30 attempts, 2-sec intervals)

**Fails if**:
- SSH connection fails
- .env file transfer fails
- Docker restart fails
- Health check fails

**Duration**: ~1-2 minutes

**Logs**: Check in GitHub Actions UI under "Deploy Backend"

### 3️⃣ Build Artifacts (`build-artifacts` job)

**Runs only if**: All previous jobs passed ✅

**What it does**:
- Builds Android APK: `flutter build apk`
- Builds iOS app: `flutter build ios`
- Uploads APKs to GitHub as artifacts (7-day retention)

**Duration**: ~5 minutes

**Artifacts**: Downloaded from GitHub Actions UI → Run Details

### 4️⃣ Notification (`notify` job)

**Always runs** (even if previous jobs fail)

**What it does**:
- Displays pipeline summary
- Shows deployment status
- Lists any failed jobs

---

## Environment Variables Reference

The `.env.production` file should contain:

```env
# Database Configuration
DATABASE_URL=postgresql://vpn_user:password@localhost:5432/vpn_db

# Flask Configuration
SECRET_KEY=your-secure-random-key-32-chars-minimum
DEBUG=False
FLASK_ENV=production

# Server Configuration
HOST=0.0.0.0
PORT=8000
ALLOWED_HOSTS=146.103.99.70,yourdomain.com
WORKERS=4

# Authentication
JWT_SECRET_KEY=your-jwt-secret-key
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Email Configuration
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=True
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password

# Stripe (Payment Processing)
STRIPE_API_KEY=sk_live_your_stripe_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Apple IAP
APPLE_TEAM_ID=XXXXXXXXXX
APPLE_KEY_ID=XXXXXXXXXX
APPLE_BUNDLE_ID=com.example.vpnapp
APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----

# Google Play IAP
GOOGLE_PLAY_PACKAGE_NAME=com.example.vpnapp
GOOGLE_PLAY_KEY_PATH=/srv/vpn-api/google-play-key.json

# Logging
LOG_LEVEL=INFO
```

---

## Monitoring & Troubleshooting

### View Pipeline Status

1. **GitHub UI**:
   - Go to repository → Actions
   - Click on workflow run
   - View each job's logs

2. **GitHub CLI**:
```bash
# List recent workflow runs
gh run list --workflow=deploy.yaml

# View specific run details
gh run view <run-id>

# View run logs
gh run view <run-id> --log
```

### Common Issues & Solutions

#### ❌ "SSH key permission denied"

**Cause**: PROD_SSH_KEY secret is incorrect or public key not authorized

**Solution**:
```bash
# Regenerate SSH key
bash scripts/setup-github-deploy.sh

# Re-add public key to server
# Test locally first
ssh -i ~/.ssh/github_deploy_key root@146.103.99.70 "echo ok"
```

#### ❌ ".env file transfer failed"

**Cause**: PROD_ENV_FILE secret missing or malformed

**Solution**:
```bash
# Check current .env on server
ssh root@146.103.99.70 "cat /srv/vpn-api/.env.production"

# Update GitHub secret
gh secret set PROD_ENV_FILE < /srv/vpn-api/.env.production
```

#### ❌ "Health check failed (30 retries)"

**Cause**: Docker container didn't start or API is crashing

**Solution**:
```bash
# SSH to server and check status
ssh root@146.103.99.70 "cd /srv/vpn-api && docker compose logs web"

# Check for errors
docker compose ps
docker compose logs

# Manually restart
docker compose up -d --no-deps --build web
```

#### ❌ "Tests failed"

**Cause**: Code changes broke existing tests

**Solution**:
```bash
# Run tests locally
flutter test

# Fix issues and commit
git add .
git commit -m "fix: Correct test failures"
git push origin main
```

#### ❌ "Flutter analyze found issues"

**Cause**: Code style or lint violations

**Solution**:
```bash
# Run analyze locally
flutter analyze

# Auto-fix if possible
dart fix --apply

# Or manually fix issues in code
# Then commit and push
```

---

## Security Best Practices

### 🔐 SSH Key Security

- ✅ SSH keys are stored as GitHub Secrets (encrypted)
- ✅ Private key never appears in logs
- ✅ Key permissions enforced (600)
- ❌ Never commit private keys to git
- ❌ Never paste keys in chat/email

### 🔐 Environment Variables

- ✅ .env.production stored as GitHub Secret
- ✅ No secrets in code or git history
- ✅ Separate dev/prod environments
- ❌ Never commit .env files
- ❌ Rotate API keys periodically

### 🔐 GitHub Actions

- ✅ Workflow file is version controlled
- ✅ Runs on official GitHub runners
- ✅ Logs are accessible only to authorized users
- ✅ Deployment requires push to main (branch protection)
- ❌ Never hardcode secrets in workflow files

---

## Workflow Visualization

```
Developer commits code
         ↓
git push origin main
         ↓
GitHub Actions triggered
         ↓
┌─────────────────────────────┐
│   Quality Check Job         │
│ ✓ flutter analyze           │
│ ✓ flutter test              │
│ ✓ Coverage report           │
└─────────────────────────────┘
         ↓ (if passed)
┌─────────────────────────────┐
│  Deploy Backend Job         │
│ ✓ SSH auth                  │
│ ✓ Transfer .env             │
│ ✓ Docker restart            │
│ ✓ Health check              │
└─────────────────────────────┘
         ↓ (if passed)
┌─────────────────────────────┐
│  Build Artifacts Job        │
│ ✓ flutter build apk         │
│ ✓ flutter build ios         │
│ ✓ Upload to GitHub          │
└─────────────────────────────┘
         ↓
┌─────────────────────────────┐
│  Notify Job                 │
│ ✓ Pipeline summary          │
│ ✓ Status report             │
└─────────────────────────────┘
         ↓
✅ Deployment Complete
Production API updated
Artifacts available for download
```

---

## Testing Deployment Locally

Before deploying, test the setup:

```bash
# 1. Test SSH connection
ssh -i ~/.ssh/github_deploy_key root@146.103.99.70 "echo 'SSH working'"

# 2. Test .env file
cat .env.production | ssh root@146.103.99.70 "cat > /tmp/.env.test"

# 3. Test Docker restart (dry-run)
ssh root@146.103.99.70 "cd /srv/vpn-api && docker compose config > /dev/null"

# 4. Check API health
curl http://146.103.99.70:8000/docs
```

---

## Rollback Procedures

If deployment causes issues:

### Quick Rollback

```bash
# SSH to production
ssh root@146.103.99.70

# Check Docker history
docker compose logs web

# Revert to previous container
docker compose down
docker compose up -d --no-deps --build web

# Verify
curl http://146.103.99.70:8000/docs
```

### Git Rollback

```bash
# Revert last commit
git revert HEAD
git push origin main

# This triggers new deployment with reverted code
```

---

## Advanced Configuration

### Custom Deployment Triggers

Edit `.github/workflows/deploy.yaml` to change trigger conditions:

```yaml
on:
  push:
    branches: [main]          # Deploy on main push
    paths:                    # Only if these files changed
      - 'lib/**'
      - 'backend_api/**'
      - 'pubspec.yaml'
      - '.github/workflows/deploy.yaml'
  
  workflow_dispatch:          # Manual trigger
  
  schedule:                   # Nightly backup deploy
    - cron: '0 2 * * *'
```

### Conditional Job Execution

```yaml
jobs:
  deploy-backend:
    if: github.ref == 'refs/heads/main'  # Only on main
    # OR
    if: contains(github.event.head_commit.message, '[deploy]')  # Commit message trigger
```

### Environment-Specific Variables

Create separate workflow files:
- `.github/workflows/deploy-prod.yaml` (main branch)
- `.github/workflows/deploy-staging.yaml` (staging branch)

Each with different server IPs and secrets.

---

## Support & Debugging

### View Detailed Logs

```bash
# GitHub CLI
gh run view <run-id> --log

# Or in GitHub UI:
# Actions → Workflow run → Job name → Step logs
```

### Enable Debug Logging

Add to GitHub Secrets:
```bash
gh secret set ACTIONS_STEP_DEBUG true
```

Then re-run workflow for verbose output.

### Contact Support

- 🐛 **Bug Report**: Create GitHub Issue with workflow logs
- 💬 **Discussion**: Use GitHub Discussions
- 📧 **Email**: Include workflow run ID and logs

---

## Maintenance

### Regular Tasks

- [ ] **Weekly**: Check workflow logs for errors
- [ ] **Monthly**: Rotate SSH keys
- [ ] **Quarterly**: Update Flutter SDK version in workflow
- [ ] **Yearly**: Review and update security policies

### Dependency Updates

When updating packages:

1. Update locally: `flutter pub get`
2. Run tests: `flutter test`
3. Commit: `git commit -m "deps: Update dependencies"`
4. Push: `git push origin main`
5. Monitor deployment

---

## Migration Checklist

Before going live with automated deployment:

- [ ] SSH key generated and authorized on production
- [ ] PROD_SSH_KEY added to GitHub Secrets
- [ ] PROD_ENV_FILE added to GitHub Secrets
- [ ] Local tests passing: `flutter test`
- [ ] Code analysis passing: `flutter analyze`
- [ ] Manual deployment tested successfully
- [ ] Health check endpoint working
- [ ] Rollback procedure documented and tested
- [ ] Team informed of deployment changes
- [ ] GitHub Actions logs reviewed and understood

---

## Quick Reference

### Useful Commands

```bash
# View current deployment status
gh run list --workflow=deploy.yaml

# Trigger manual deployment
gh workflow run deploy.yaml

# View latest deployment logs
gh run view $(gh run list --workflow=deploy.yaml -L 1 --json databaseId --jq '.[0].databaseId') --log

# Check GitHub Secrets
gh secret list

# Update a secret
gh secret set PROD_ENV_FILE < /path/to/.env.production

# SSH to production
ssh root@146.103.99.70

# Check API health
curl http://146.103.99.70:8000/docs

# View Docker logs on production
ssh root@146.103.99.70 "cd /srv/vpn-api && docker compose logs -f web"
```

### File Locations

- Workflow definition: `.github/workflows/deploy.yaml`
- Setup script: `scripts/setup-github-deploy.sh`
- This guide: `DEPLOYMENT_GUIDE.md`
- Production .env: `/srv/vpn-api/.env.production` (on server)
- Local SSH key: `~/.ssh/github_deploy_key`

---

**Last Updated**: 2024  
**Version**: 1.0  
**Status**: Production Ready ✅
