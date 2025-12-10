#!/usr/bin/env python3
"""
Script to setup clean tariff list:
1. 1 month: $9.99
2. 6 months: $49.99
3. 1 year: $99.99
4. 7 days test: $0.99 (for testing subscriptions)
"""

import requests
import json
from typing import Optional

API_BASE = "http://146.103.99.70:8000"

# Admin credentials - get token first
ADMIN_EMAIL = "admin@example.com"
ADMIN_PASSWORD = "password123"

def get_admin_token() -> Optional[str]:
    """Get admin JWT token"""
    try:
        r = requests.post(
            f"{API_BASE}/auth/login",
            json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
            timeout=5
        )
        if r.status_code == 200:
            return r.json().get("access_token")
        print(f"❌ Failed to get admin token: {r.status_code} {r.text}")
        return None
    except Exception as e:
        print(f"❌ Error getting token: {e}")
        return None

def list_tariffs() -> list:
    """List all current tariffs"""
    try:
        r = requests.get(f"{API_BASE}/tariffs/", timeout=5)
        if r.status_code == 200:
            return r.json()
        return []
    except Exception as e:
        print(f"❌ Error listing tariffs: {e}")
        return []

def delete_tariff(tariff_id: int, token: str) -> bool:
    """Delete tariff (if not assigned to any user)"""
    try:
        headers = {"Authorization": f"Bearer {token}"}
        r = requests.delete(
            f"{API_BASE}/tariffs/{tariff_id}",
            headers=headers,
            timeout=5
        )
        if r.status_code == 200:
            print(f"✅ Deleted tariff {tariff_id}")
            return True
        elif r.status_code == 400:
            print(f"⚠️  Cannot delete tariff {tariff_id}: assigned to users")
            return False
        else:
            print(f"❌ Failed to delete tariff {tariff_id}: {r.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error deleting tariff {tariff_id}: {e}")
        return False

def create_tariff(name: str, description: str, price: float, duration_days: int, token: str) -> bool:
    """Create new tariff"""
    try:
        headers = {"Authorization": f"Bearer {token}"}
        r = requests.post(
            f"{API_BASE}/tariffs/",
            json={
                "name": name,
                "description": description,
                "price": price,
                "duration_days": duration_days
            },
            headers=headers,
            timeout=5
        )
        if r.status_code in (200, 201):
            result = r.json()
            print(f"✅ Created tariff: {name} (id={result.get('id')})")
            return True
        else:
            print(f"❌ Failed to create tariff {name}: {r.status_code} {r.text}")
            return False
    except Exception as e:
        print(f"❌ Error creating tariff {name}: {e}")
        return False

def main():
    print("🔧 VPN Tariffs Setup Script\n")

    # Get admin token
    print("1️⃣  Getting admin token...")
    token = get_admin_token()
    if not token:
        print("❌ Cannot proceed without admin token")
        return

    # List current tariffs
    print("\n2️⃣  Current tariffs:")
    current = list_tariffs()
    for t in current:
        print(f"  - {t['id']}: {t['name']} ({t['duration_days']} days, ${t['price']})")

    # Define desired tariffs
    desired_tariffs = [
        {
            "name": "Monthly",
            "description": "1 month VPN access",
            "price": 9.99,
            "duration_days": 30
        },
        {
            "name": "Half Year",
            "description": "6 months VPN access",
            "price": 49.99,
            "duration_days": 180
        },
        {
            "name": "Yearly",
            "description": "12 months VPN access",
            "price": 99.99,
            "duration_days": 365
        },
        {
            "name": "Test 7 Days",
            "description": "7 days test access - for testing subscriptions",
            "price": 0.99,
            "duration_days": 7
        },
    ]

    # Delete old tariffs (except ones we want to keep)
    print("\n3️⃣  Cleaning up old tariffs...")
    existing_names = {t['name'] for t in current}
    desired_names = {t['name'] for t in desired_tariffs}
    
    for t in current:
        if t['name'] not in desired_names:
            # Try to delete old tariff
            delete_tariff(t['id'], token)

    # Create missing tariffs
    print("\n4️⃣  Creating desired tariffs...")
    current = list_tariffs()
    existing_names = {t['name'] for t in current}
    
    for desired in desired_tariffs:
        if desired['name'] not in existing_names:
            create_tariff(
                desired['name'],
                desired['description'],
                desired['price'],
                desired['duration_days'],
                token
            )
        else:
            print(f"⏭️  Tariff '{desired['name']}' already exists, skipping")

    # Final list
    print("\n5️⃣  Final tariff list:")
    final = list_tariffs()
    for t in final:
        print(f"  - {t['id']}: {t['name']} ({t['duration_days']} days, ${t['price']})")

    print("\n✅ Tariffs setup complete!")

if __name__ == "__main__":
    main()
