import asyncio
import os
import sys
from dotenv import load_dotenv

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.infrastructure import db_connection

async def clean():
    load_dotenv()
    await db_connection.init_pool()
    pool = db_connection.get_pool()
    async with pool.acquire() as conn:
        dupes = await conn.fetch("""
            SELECT purchase_token, COUNT(*) 
            FROM user_subscriptions 
            WHERE purchase_token IS NOT NULL
            GROUP BY purchase_token 
            HAVING COUNT(*) > 1
        """)
        for dupe in dupes:
            token = dupe['purchase_token']
            print(f"Found duplicate token: {token}")
            rows = await conn.fetch("SELECT id FROM user_subscriptions WHERE purchase_token = $1 ORDER BY created_at DESC", token)
            keep_id = rows[0]['id']
            delete_ids = [r['id'] for r in rows[1:]]
            if delete_ids:
                print(f"Keeping {keep_id}, deleting {delete_ids}")
                await conn.execute("DELETE FROM user_subscriptions WHERE id = ANY($1)", delete_ids)
        
        await conn.execute("""
            ALTER TABLE user_subscriptions DROP CONSTRAINT IF EXISTS user_subscriptions_purchase_token_key;
            ALTER TABLE user_subscriptions ADD CONSTRAINT user_subscriptions_purchase_token_key UNIQUE (purchase_token);
        """)
        print("Constraint applied successfully.")

if __name__ == "__main__":
    asyncio.run(clean())
