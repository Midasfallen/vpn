#!/usr/bin/env python3
import urllib.request
import json
import random

email = f'fluttertest_{random.randint(100000, 999999)}@test.com'
password = 'TestPassword123'

data = json.dumps({'email': email, 'password': password}).encode()
req = urllib.request.Request('http://146.103.99.70:8000/auth/register', 
                             data=data, 
                             method='POST', 
                             headers={'Content-Type': 'application/json'})

with urllib.request.urlopen(req) as resp:
    result = json.loads(resp.read().decode())
    print(f'Email: {result["email"]}')
    print(f'Password: {password}')
    print('Please use these credentials in the app')
