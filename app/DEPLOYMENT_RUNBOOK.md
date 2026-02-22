# Deployment Runbook

## Emergency Procedures

### Critical Issue Response (5 minutes)

**Step 1: Acknowledge Issue**
- [ ] Check Play Store reviews and crash reports
- [ ] Verify issue reproduction
- [ ] Assess severity (critical/high/medium/low)
- [ ] Create GitHub issue with `[CRITICAL]` label

**Step 2: Pause Deployment**
```bash
# In Google Play Console:
# - Go to Internal Testing → Release
# - Click "Pause rollout" (if in progress)
# - Do NOT delete release yet
```

**Step 3: Gather Information**
- [ ] Collect user reports and screenshots
- [ ] Review Sentry crash data
- [ ] Check API logs and server health
- [ ] Identify affected versions/users

**Step 4: Triage**
- **Critical**: Immediate fix required (app-breaking)
- **High**: Hot fix this week
- **Medium**: Include in next release
- **Low**: Add to backlog

### Rollback Procedure (if needed)

```bash
# Option 1: Revert to Previous Version (Fastest)
# Go to Google Play Console > Internal Testing
# - Find previous stable version
# - Click "Promote release" to Production
# - Select users affected (10% → 25% → 50% → 100%)

# Option 2: Build Hotfix Version
# 1. Identify bug fix
# 2. Create hotfix branch
git checkout -b hotfix/1.0.1
# 3. Apply fix
# 4. Bump version: 1.0.1
# 5. Tag release
git tag v1.0.1
# 6. Build and deploy
flutter build appbundle --flavor prod --release
```

## Release Deployment Steps

### Pre-Release Checklist (1 week before)

```bash
# 1. Update version
sed -i 's/version: 1.0.0/version: 1.1.0/' pubspec.yaml

# 2. Run full test suite
flutter test --coverage

# 3. Verify coverage >= 80%
lcov --summary coverage/lcov.info

# 4. Build release APK locally
flutter build apk --flavor prod --release

# 5. Manual testing on devices
flutter install --release

# 6. Create release notes
echo "## Version 1.1.0
- Feature: New VPN server selection
- Fix: Connection timeout on weak networks
- Improvement: Better error messages" > RELEASE_NOTES.md

# 7. Commit everything
git add -A
git commit -m "chore: prepare for v1.1.0 release"
```

### Release Process (Release Day)

**Morning Standup:**
- [ ] Confirm release readiness with team
- [ ] Assign release engineer
- [ ] Have hotfix engineer on standby

**Tag Release:**
```bash
git tag v1.1.0
git push origin v1.1.0
# This triggers GitHub Actions CI/CD
```

**Monitor Build:**
```bash
# Watch GitHub Actions workflow
# URL: https://github.com/yourorg/vpn/actions

# Check logs for:
# - All tests passing ✓
# - Code analysis passing ✓
# - APK/IPA built successfully ✓
# - Artifact uploaded ✓
```

**Manual Testing on Staging:**
```bash
# Download APK from GitHub Actions
# Install on test devices
adb install build/app/outputs/flutter-apk/app-prod-release.apk

# Test critical flows:
# - Login/Register
# - Subscription purchase
# - VPN connection
# - Error recovery
# - Offline mode
```

**Approve Play Store Upload:**
1. Go to Google Play Console
2. Navigate to "Internal Testing"
3. Review release (version, notes, screenshots)
4. Click "Promote to Alpha" (first)
5. Wait 24 hours for stability
6. Promote to "Beta"
7. Wait 48 hours for feedback
8. Promote to "Production" (staged rollout)

**Staged Rollout (Production):**
```
Day 1: 10% of users
Day 2: 25% of users (if no issues)
Day 3: 50% of users
Day 4: 100% of users
```

**Post-Release Monitoring (first 48 hours):**
```bash
# Check every 4 hours:
# 1. Crash rate < 0.5%
# 2. No spike in error logs
# 3. API latency normal
# 4. User reviews/feedback positive
# 5. VPN success rate > 98%

# If any issues:
# - Pause rollout immediately
# - Escalate to critical response
# - Begin root cause investigation
```

## Hotfix Release Process

**When:** Critical bug discovered in production

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/1.0.1

# 2. Fix bug (minimal changes)
# - Only fix the specific issue
# - Don't refactor or optimize
# - Test thoroughly

# 3. Increment patch version
sed -i 's/version: 1.0.0/version: 1.0.1/' pubspec.yaml

# 4. Commit fix
git add -A
git commit -m "fix(critical): [description of fix]"

# 5. Tag and push
git tag v1.0.1
git push origin v1.0.1
git push origin hotfix/1.0.1

# 6. Create pull request to main
# - Title: "[HOTFIX] v1.0.1"
# - Description: Explain issue and fix
# - Require 1+ approval before merge

# 7. Merge to main after approval
git checkout main
git pull origin main
git merge --no-ff hotfix/1.0.1
git push origin main

# 8. Delete hotfix branch
git branch -d hotfix/1.0.1
git push origin --delete hotfix/1.0.1
```

## Monitoring During Release

### Critical Metrics Dashboard

Create spreadsheet or use monitoring tool to track:

| Time | Crash Rate | ANR Rate | API Latency | VPN Success | Notes |
|------|-----------|----------|------------|------------|-------|
| 9:00 | 0.2% | 0.05% | 250ms | 98.5% | Release started |
| 13:00 | 0.3% | 0.08% | 280ms | 98.2% | Scaling to 25% |
| 17:00 | 0.45% | 0.12% | 320ms | 97.8% | ⚠️ Pause & investigate |

### Alert Triggers

**Pause Rollout If:**
- Crash rate exceeds 1%
- ANR rate exceeds 0.5%
- API latency > 2 seconds
- VPN success rate < 95%
- Critical security issue reported

### Communication Templates

**Pause Notification (to team):**
```
🚨 RELEASE PAUSED

Version: 1.1.0
Reason: Crash rate spiked to 1.2%
Action: Investigating root cause
Timeline: Update in 30 minutes

Do NOT merge any PRs until cleared.
Hotfix engineer: on standby
```

**All Clear Notification (to team):**
```
✅ RELEASE RESUMED

Version: 1.1.0
Issue: Fixed in hotfix v1.0.1
Status: Promoted to 50% users
Next: 100% rollout in 24 hours

Carry on with normal deployments.
```

## Post-Release Cleanup

**After successful full rollout:**

```bash
# 1. Create release branch (for future reference)
git checkout -b release/1.1.0
git push origin release/1.1.0

# 2. Archive release notes
cp RELEASE_NOTES.md docs/releases/v1.1.0.md

# 3. Update main branch version for next dev
git checkout main
sed -i 's/version: 1.1.0/version: 1.1.1-dev/' pubspec.yaml
git commit -m "chore: bump version for development"
git push origin main

# 4. Document lessons learned
# - What went well?
# - What could be improved?
# - Update runbook if needed

# 5. Close release-related issues
# - Mark as released
# - Reference release tag in comments
```

## Disaster Recovery

### Complete Rollback Procedure

**If production is broken and rollback not possible:**

```bash
# 1. Stop accepting new traffic (disable login)
# - Set maintenance flag in API
# - Show "App Under Maintenance" splash

# 2. Immediate remediation
# - Fix issue
# - Test thoroughly
# - Increment version

# 3. Emergency hotfix release
# - Build new APK
# - Bypass normal approval (with manager sign-off)
# - Do controlled rollout (10% first)

# 4. Communicate status
# - Post on social media
# - Notify active users via in-app message
# - Email status page: https://status.example.com
```

### Data Loss Prevention

**Backup critical data before release:**
```bash
# Backup user database
pg_dump vpn_production > backup_pre_1.1.0.sql

# Backup user files (if any)
tar -czf user_files_pre_1.1.0.tar.gz /data/users/

# Verify backup integrity
pg_restore -d backup_test backup_pre_1.1.0.sql
```

## Contacts & Escalation

**Release Engineer:** @alice  
**Backup Release Engineer:** @bob  
**On-Call:** @charlie (weekdays), @diana (weekends)  
**Manager:** @eve  
**Slack Channel:** #vpn-releases  

**Escalation Path:**
1. Release Engineer → On-Call
2. On-Call → Manager
3. Manager → VP Engineering
4. VP Engineering → CEO (if critical)

## Checklists (Copy & Paste)

### Pre-Release (1 week before)
- [ ] All PRs merged to main
- [ ] All tests passing
- [ ] Coverage >= 80%
- [ ] Code review completed
- [ ] Release notes written
- [ ] Screenshots updated
- [ ] Version bumped
- [ ] Commit tagged

### Release Day
- [ ] Team notified
- [ ] Build started
- [ ] APK/IPA verified
- [ ] Manual testing passed
- [ ] Play Store approved
- [ ] 10% rollout started
- [ ] Monitoring dashboard open
- [ ] Alert system armed

### Post-Release
- [ ] Crash rate stable
- [ ] No critical issues
- [ ] User feedback positive
- [ ] 100% rollout complete
- [ ] Release branch created
- [ ] Lessons learned documented
- [ ] Team debriefing held
- [ ] Next version planned

## References

- [Google Play Deployment Guide](https://play.google.com/console/developers)
- [Flutter Release Guide](https://flutter.dev/docs/deployment)
- [Semantic Versioning](https://semver.org/)
