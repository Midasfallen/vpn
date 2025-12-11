#!/usr/bin/env python3
"""Create test user and validate subscription flow"""
import json
import random
import urllib.request
import urllib.error

BASE_URL = "http://146.103.99.70:8000"

def api_call(method, path, data=None, token=None):
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, method=method, headers=headers)
    if data:
        req.data = json.dumps(data).encode()
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode()
            if body.strip() == 'null':
                return None
            return json.loads(body)
    except urllib.error.HTTPError as e:
        code = e.code
        body = e.read().decode()
        if body.strip() == 'null':
            return None
        print(f"[ERROR HTTP {code}] {body}")
        exit(1)

# Create fresh user
email = f"testuser_{random.randint(100000, 999999)}@test.com"
password = "TestPassword123"

print("=" * 60)
print("CREATING FRESH TEST USER")
print("=" * 60)

try:
    user_data = api_call("POST", "/auth/register", {"email": email, "password": password})
    print(f"\n[OK] User registered: {email}")
except Exception as e:
    print(f"\n[ERROR] Registration failed: {e}")
    exit(1)

# Login
try:
    login_data = api_call("POST", "/auth/login", {"email": email, "password": password})
    token = login_data.get("access_token")
    print(f"[OK] Logged in successfully")
except Exception as e:
    print(f"[ERROR] Login failed: {e}")
    exit(1)

# Check initial subscription status
try:
    sub = api_call("GET", "/auth/me/subscription", token=token)
    if sub is None:
        print(f"[OK] Initial subscription: NONE (correct!)")
    else:
        print(f"[ERROR] Initial subscription should be None, got: {sub}")
except Exception as e:
    print(f"[ERROR] Failed to check subscription: {e}")
    exit(1)

print("\n" + "=" * 60)
print("USE THESE CREDENTIALS IN THE APP:")
print("=" * 60)
print(f"Email:    {email}")
print(f"Password: {password}")
print("=" * 60)
