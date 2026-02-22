#!/usr/bin/env python3
"""Create test user in VPN backend database."""
import sys
import os

# Add backend to path
sys.path.insert(0, '/app/vpn_api')

from vpn_api.database import SessionLocal
from vpn_api.models import User
from passlib.context import CryptContext

def create_test_user(email: str, password: str):
    """Create test user if doesn't exist."""
    db = SessionLocal()
    pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
    
    try:
        # Check if user exists
        user = db.query(User).filter(User.email == email).first()
        if user:
            print(f'User already exists: {user.email}')
            return False
        
        # Create user
        user = User(
            email=email,
            password_hash=pwd_context.hash(password)
        )
        db.add(user)
        db.commit()
        print(f'User created: {user.email}')
        return True
    except Exception as e:
        print(f'Error: {e}')
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == '__main__':
    create_test_user('testuser@mail.com', 'testtest1')
