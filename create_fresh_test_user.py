#!/usr/bin/env python3
"""Create a fresh test user for testing subscription flow"""
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

# Generate random email
email = f"testuser_{random.randint(100000, 999999)}@test.com"
password = "TestPassword123"

print(f"Creating fresh test user:")
print(f"  Email: {email}")
print(f"  Password: {password}")

try:
    user_data = api_call("POST", "/auth/register", {"email": email, "password": password})
    print(f"\n[OK] User registered successfully!")
    print(f"[OK] Ready to test - use these credentials in the app:")
    print(f"     Email: {email}")
    print(f"     Password: {password}")
except Exception as e:
    print(f"[ERROR] Failed to register: {e}")
    exit(1)
