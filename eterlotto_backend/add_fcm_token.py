import psycopg2
import sys
import os

# Añadir el directorio actual al path para importar app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core import config

def add_fcm_token_column():
    conn = None
    try:
        print(f"Connecting to DB...")
        conn = psycopg2.connect(config.DATABASE_URL, sslmode="require")
        cur = conn.cursor()
        print("Checking/Adding fcm_token column to users table...")
        cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;")
        conn.commit()
        print("✅ Column fcm_token added successfully (or already exists).")
    except Exception as e:
        print(f"❌ Error adding column: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    add_fcm_token_column()
