#!/usr/bin/env python3
import sys
sys.path.insert(0, '/app')
from vpn_api.database import SessionLocal
from vpn_api.models import User

db = SessionLocal()
user = db.query(User).filter(User.email == 'testuser@mail.com').first()
if user:
    db.delete(user)
    db.commit()
    print('User deleted')
else:
    print('User not found')
db.close()
