#!/usr/bin/env python3
"""Fix auth.py verify_password function."""

with open('/app/vpn_api/auth.py', 'r') as f:
    content = f.read()

# Fix the messed up line from sed
content = content.replace(
    "def verify_password(plain, hashed):\\n    # Bcrypt 72-byte limit; truncate password\n    return pwd_context.verify(plain, hashed)",
    "def verify_password(plain, hashed):\n    return pwd_context.verify(plain[:72], hashed)"
)

with open('/app/vpn_api/auth.py', 'w') as f:
    f.write(content)

print('OK')
