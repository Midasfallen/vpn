#!/usr/bin/env python3
"""Fix verify_password to truncate password to 72 bytes for bcrypt."""

with open('/app/vpn_api/auth.py', 'r') as f:
    content = f.read()

old_func = '''def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)'''

new_func = '''def verify_password(plain, hashed):
    return pwd_context.verify(plain[:72], hashed)'''

if old_func in content:
    content = content.replace(old_func, new_func)
    with open('/app/vpn_api/auth.py', 'w') as f:
        f.write(content)
    print('verify_password fixed')
else:
    print('verify_password pattern not found')
