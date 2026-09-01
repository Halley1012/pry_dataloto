import asyncio
import asyncpg
import datetime

DATABASE_URL = 'postgresql://postgres.plrgbnzsvenpbibrqyqw:LuferHalley0011..@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require'

async def diagnostics():
    conn = await asyncpg.connect(DATABASE_URL)
    
    # 3. All duplicated tokens
    dupes = await conn.fetch('''
        SELECT purchase_token, COUNT(*) AS cantidad
        FROM user_subscriptions
        WHERE purchase_token IS NOT NULL
        GROUP BY purchase_token
        HAVING COUNT(*) > 1
        ORDER BY cantidad DESC;
    ''')
    
    print('--- DUPLICATED TOKENS ---')
    for d in dupes:
        print(f"{d['purchase_token']}: {d['cantidad']}")
        
    print('\n--- ROWS FOR DUPLICATED TOKENS ---')
    for d in dupes:
        rows = await conn.fetch('''
            SELECT id, user_id, product_id, order_id, status, created_at, expires_at
            FROM user_subscriptions
            WHERE purchase_token = $1
            ORDER BY expires_at DESC NULLS LAST, created_at DESC, id DESC;
        ''', d['purchase_token'])
        for r in rows:
            print(dict(r))
            
    print('\n--- ORPHANED SUBSCRIPTIONS ---')
    orphans = await conn.fetch('''
        SELECT us.*
        FROM user_subscriptions us
        LEFT JOIN users u ON u.id = us.user_id
        WHERE u.id IS NULL;
    ''')
    for o in orphans:
        print(dict(o))
        
    await conn.close()

asyncio.run(diagnostics())
