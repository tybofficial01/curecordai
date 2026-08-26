"""
Run this once to set up the development environment.
Usage: python scripts/setup_dev.py
"""
import subprocess
import sys
import os
from pathlib import Path

def run(cmd, check=True):
    print(f"\n>>> {cmd}")
    result = subprocess.run(cmd, shell=True, check=check)
    return result

def main():
    print("=== CurecordAI Backend Dev Setup ===\n")

    # 1. Check .env exists
    if not Path(".env").exists():
        print("Creating .env from .env.example...")
        if Path(".env.example").exists():
            import shutil
            shutil.copy(".env.example", ".env")
            print("✅ .env created. Fill in DATABASE_URL and SECRET_KEY before running the server.")
        else:
            print("❌ .env.example not found")
            sys.exit(1)

    # 2. Generate RSA keys if missing
    keys_dir = Path("keys")
    keys_dir.mkdir(exist_ok=True)

    if not (keys_dir / "private.pem").exists():
        print("\nGenerating RSA keys for JWT...")
        run("openssl genrsa -out keys/private.pem 2048")
        run("openssl rsa -in keys/private.pem -pubout -out keys/public.pem")
        print("✅ RSA keys generated in keys/")
    else:
        print("✅ RSA keys already exist")

    # 3. Generate SECRET_KEY hint
    import base64
    import secrets
    print(f"\n📋 Suggested SECRET_KEY (copy to .env):")
    print(f"   {secrets.token_hex(32)}")

    print(f"\n📋 Suggested FIELD_ENCRYPTION_KEY (copy to .env):")
    print(f"   {base64.b64encode(secrets.token_bytes(32)).decode()}")

    print("\n=== Setup Complete ===")
    print("Next steps:")
    print("1. Fill in DATABASE_URL in .env (your Neon connection string)")
    print("2. Fill in SECRET_KEY and FIELD_ENCRYPTION_KEY in .env (use the values above)")
    print("3. Fill in GOOGLE_CLIENT_ID in .env")
    print("4. Run: alembic upgrade head")
    print("5. Run: uvicorn app.main:app --reload --port 8000")

if __name__ == "__main__":
    main()
