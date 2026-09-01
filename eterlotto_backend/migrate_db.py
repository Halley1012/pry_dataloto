import asyncio
import asyncpg

DATABASE_URL = 'postgresql://postgres.plrgbnzsvenpbibrqyqw:LuferHalley0011..@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require'

async def execute_and_verify():
    conn = await asyncpg.connect(DATABASE_URL)
    
    async with conn.transaction():
        # 1. Backup
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS user_subscriptions_replay_backup AS
            SELECT * FROM user_subscriptions;
        ''')
        
        # 2. Delete orphans
        await conn.execute('''
            DELETE FROM user_subscriptions us
            WHERE NOT EXISTS (
                SELECT 1
                FROM users u
                WHERE u.id = us.user_id
            );
        ''')
        
        # 3. Add FK
        # First drop if exists just in case
        await conn.execute('''
            ALTER TABLE user_subscriptions
            DROP CONSTRAINT IF EXISTS fk_user_subscriptions_user;
            
            ALTER TABLE user_subscriptions
            ADD CONSTRAINT fk_user_subscriptions_user
            FOREIGN KEY (user_id)
            REFERENCES users(id)
            ON DELETE CASCADE;
        ''')
        
        # 4. Add Unique Index
        await conn.execute('''
            DROP INDEX IF EXISTS uq_user_subscriptions_purchase_token;
            
            CREATE UNIQUE INDEX uq_user_subscriptions_purchase_token
            ON user_subscriptions (purchase_token)
            WHERE purchase_token IS NOT NULL;
        ''')
        
    print('--- TRANSACTION COMMITTED ---\n')
    
    # Verifications
    count = await conn.fetchval('SELECT COUNT(*) FROM user_subscriptions;')
    print(f'1. Count of user_subscriptions: {count}')
    
    rows = await conn.fetch('''
        SELECT id, user_id, product_id, order_id, status, created_at, expires_at 
        FROM user_subscriptions 
        ORDER BY id;
    ''')
    print('2. Remaining subscriptions:')
    for r in rows:
        print(dict(r))
        
    orphans = await conn.fetchval('''
        SELECT COUNT(*)
        FROM user_subscriptions us
        LEFT JOIN users u ON u.id = us.user_id
        WHERE u.id IS NULL;
    ''')
    print(f'3. Orphaned rows count: {orphans}')
    
    dupes = await conn.fetchval('''
        SELECT COUNT(*)
        FROM (
            SELECT purchase_token
            FROM user_subscriptions
            WHERE purchase_token IS NOT NULL
            GROUP BY purchase_token
            HAVING COUNT(*) > 1
        ) sub;
    ''')
    print(f'4. Duplicated tokens count: {dupes}')

    await conn.close()

asyncio.run(execute_and_verify())
