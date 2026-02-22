#!/usr/bin/env python3
import json
import random
import urllib.request
import urllib.error

BASE_URL = "http://146.103.99.70:8000"
email = f"testuser_{random.randint(100000, 999999)}@test.com"
password = "TestPassword123"

print(f"Registering: {email}")

data = json.dumps({"email": email, "password": password}).encode()
req = urllib.request.Request(f"{BASE_URL}/auth/register", data=data, method="POST", headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        response = resp.read().decode()
        print(f"Status: {resp.status}")
        print(f"Response: {response}")
        parsed = json.loads(response)
        print(f"Parsed: {json.dumps(parsed, indent=2)}")
except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}: {e.read().decode()}")
