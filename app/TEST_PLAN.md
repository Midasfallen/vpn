## Comprehensive Test Plan - Subscription Flow

### Test User Credentials
- Email: testuser_746154@test.com
- Password: TestPassword123

### Expected Behavior

#### 1. **LOGIN SCREEN**
- Action: Enter credentials and tap Login
- Expected: Navigate to Home screen
- Log check: Look for "[DEBUG] HomeScreen._loadSubscriptionStatus() starting..."

#### 2. **HOME SCREEN (Fresh User - NO Subscription)**
- Expected: 
  - Status card shows "No active subscription"
  - "Buy subscription" button visible
  - NO "Subscription active until {0}" message
- Logs should show:
  - "[DEBUG] SubscriptionScreen: NO active subscription (null)"
  - "[DEBUG] HomeScreen loaded subscription: null"
  - "[DEBUG] Setting _hasActiveSubscription = false"

#### 3. **SUBSCRIPTION SCREEN**
- Action: Tap "Buy subscription" button from Home
- Expected:
  - Current subscription card: Shows "No active subscription" (orange card)
  - Available plans: Shows 8 tariffs including "Test 7 Days Free"
- Logs should show:
  - "[DEBUG] SubscriptionScreen: NO active subscription (null)"
  - "[DEBUG] SubscriptionScreen: Loaded 8 tariffs from backend"

#### 4. **SELECT TEST 7 DAYS FREE**
- Action: Tap "Select Plan" for "Test 7 Days Free"
- Expected:
  - "Subscribing to..." notification appears
  - Green success notification: "Successfully activated Test 7 Days Free!"
  - Subscription screen updates to show active subscription
  - Navigation pops back to Home (may take 1-2 seconds)
- Logs should show:
  - "[DEBUG] Selecting tariff: id=17, name=Test 7 Days Free..."
  - "[DEBUG] Subscribe response: {...}"

#### 5. **HOME SCREEN (After Activation)**
- Expected:
  - Status card shows: "Subscription active until 2025-12-17" (or similar future date)
  - Card background is blue (not red, not gray)
  - Text is blue (not red, not gray)
  - "Buy subscription" button still visible
- Logs should show:
  - "[DEBUG] HomeScreen._loadSubscriptionStatus() starting..."
  - "[DEBUG] Subscription found:"
  - "[DEBUG]   - status: active"
  - "[DEBUG]   - endedAt: 2025-12-17T..."
  - "[DEBUG] Setting _hasActiveSubscription = true"
  - "[DEBUG] Parsed subscription end date: 2025-12-17..."

#### 6. **CONSISTENCY CHECK**
- Switch between Home and Subscription screens multiple times
- Expected: Both show same subscription status
- Logs: Should show same "[DEBUG] Subscription found:" data in both screens

### Potential Issues to Watch For

1. **Issue: Home shows "{0}" instead of date**
   - Cause: Localization key not found or date parsing failed
   - Check: Flutter logs for "[DEBUG] Parsed subscription end date"

2. **Issue: Subscription never updates after activation**
   - Cause: Navigator.pop() not called, or _loadSubscriptionStatus() not triggered
   - Check: Logs for "Subscription found" after pop

3. **Issue: Old subscription status shows up**
   - Cause: Cached data or previous test user still has active subscription
   - Fix: Use fresh test user from prepare_test.py

4. **Issue: Both screens show different status**
   - Cause: Race condition or different API responses
   - Check: Timestamp of logs - should be within 1-2 seconds

### How to Read Logs

```bash
# While app is running, in another terminal:
Get-Content C:\vpn\flutter_logs.txt -Tail 50  # Last 50 lines
Get-Content C:\vpn\flutter_logs.txt -Tail 50 -Wait  # Tail -f equivalent
```

### Success Criteria

- [ ] Fresh user on Home shows "No active subscription"
- [ ] Subscription screen shows "No active subscription" card
- [ ] After Test 7 Days activation, Home shows "Subscription active until..."
- [ ] Subscription screen also shows active subscription
- [ ] Date is correctly parsed and displayed
- [ ] Status is NOT "{0}" placeholder
- [ ] All logs show expected debug messages
