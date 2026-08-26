"""
Seeds the default roles (patient, doctor, admin) into the database.
Run AFTER alembic upgrade head.
Usage: python scripts/seed_roles.py
"""
import asyncio
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.rbac import Role

ROLES = [
    {"name": "patient", "display_name": "Patient", "description": "Regular app user - personal health records"},
    {"name": "doctor", "display_name": "Doctor", "description": "Healthcare provider - can view shared records"},
    {"name": "admin", "display_name": "Administrator", "description": "Platform administrator"},
]

async def seed():
    async with AsyncSessionLocal() as db:
        for role_data in ROLES:
            existing = await db.scalar(select(Role).where(Role.name == role_data["name"]))
            if not existing:
                db.add(Role(**role_data))
                print(f"✅ Created role: {role_data['name']}")
            else:
                print(f"⏭️  Role already exists: {role_data['name']}")
        await db.commit()
    print("\nDone. Roles seeded.")

if __name__ == "__main__":
    asyncio.run(seed())
