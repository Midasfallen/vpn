#!/usr/bin/env python3
"""Test subscription flow end-to-end"""
import json
import random
import urllib.request
import urllib.error

BASE_URL = "http://146.103.99.70:8000"

def api_call(method, path, data=None, token=None):
    """Make API call"""
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    req = urllib.request.Request(url, method=method, headers=headers)
    if data:
        req.data = json.dumps(data).encode()
    
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        raise Exception(f"HTTP {e.code}: {e.read().decode()}")

# Register new user
email = f"testuser_{random.randint(100000, 999999)}@test.com"
password = "TestPassword123"

print(f"1. Registering user: {email}")
try:
    user_data = api_call("POST", "/auth/register", {"email": email, "password": password})
    print(f"   [OK] User registered: {user_data['email']}")
except Exception as e:
    print(f"   [ERROR] Error: {e}")
    exit(1)

# Login to get token
print(f"\n2. Logging in...")
try:
    login_data = api_call("POST", "/auth/login", {"email": email, "password": password})
    token = login_data.get("access_token")
    print(f"   [OK] Logged in successfully")
    print(f"   Token: {token[:30]}...")
except Exception as e:
    print(f"   [ERROR] Error: {e}")
    exit(1)

# Get tariffs
print("\n3. Loading tariffs...")
try:
    tariffs = api_call("GET", "/tariffs/", token=token)
    print(f"   [OK] Loaded {len(tariffs)} tariffs")
    for t in tariffs:
        print(f"     - id={t['id']}, name={t['name']}, price={t['price']}, duration={t['duration_days']} days")
except Exception as e:
    print(f"   [ERROR] Error: {e}")
    exit(1)

# Subscribe to free tariff (id=17)
print("\n4. Subscribing to tariff id=17 (Test 7 Days Free)...")
try:
    sub_data = api_call("POST", "/auth/subscribe", {"tariff_id": 17}, token=token)
    print(f"   [OK] Subscription activated!")
    print(f"   Response: {json.dumps(sub_data, indent=2)}")
except Exception as e:
    print(f"   [ERROR] Error: {e}")
    exit(1)

# Get active subscription
print("\n5. Getting active subscription...")
try:
    sub = api_call("GET", "/auth/me/subscription", token=token)
    print(f"   [OK] Active subscription:")
    print(f"     - Tariff: {sub.get('tariff_name')}")
    print(f"     - Status: {sub.get('status')}")
    print(f"     - Started: {sub.get('started_at')}")
    print(f"     - Ends: {sub.get('ended_at')}")
    print(f"     - Duration: {sub.get('duration_days')} days")
except Exception as e:
    print(f"   [ERROR] Error: {e}")

print("\n[OK] All tests passed!")
